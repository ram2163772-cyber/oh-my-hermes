#!/usr/bin/env bash
#
# chrome_orphan_killer.sh — Auto-kill orphaned Chrome/Playwright headless processes
#
# Finds Chrome/Playwright headless processes older than 30 minutes and kills
# them gracefully (SIGTERM, then SIGKILL after 5s). Skips processes belonging
# to recently-active browser sessions.
#
# Designed to run as a cron job every 15 minutes:
#   */15 * * * * /home/ubuntu/.hermes/scripts/chrome_orphan_killer.sh
#
# Configurable via environment variables:
#   MAX_AGE_MINUTES   — process age threshold in minutes (default: 30)
#   GRACE_SECONDS     — seconds to wait after SIGTERM before SIGKILL (default: 5)
#   LOG_FILE          — path to log file (default: ~/.hermes/logs/chrome_orphan_killer.log)
#   DRY_RUN           — set to "1" to only log what would be killed without killing

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
MAX_AGE_MINUTES="${MAX_AGE_MINUTES:-30}"
GRACE_SECONDS="${GRACE_SECONDS:-5}"
LOG_FILE="${LOG_FILE:-$HOME/.hermes/logs/chrome_orphan_killer.log}"
DRY_RUN="${DRY_RUN:-0}"
MAX_AGE_SECONDS=$((MAX_AGE_MINUTES * 60))

# ── Setup ──────────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" | tee -a "$LOG_FILE"
}

# ── Determine the PID of the active Hermes agent browser session ──────────────
# The active agent turn typically has a browser launched with a user-data-dir
# or specific debugging port. We identify "active" sessions as those whose
# parent process tree is still alive and was accessed recently.
#
# Strategy: find Playwright-chromium processes whose /proc/PID/fd still has
# an active socket (meaning a live client is connected), or whose command line
# references a --user-data-dir that was modified in the last 5 minutes.

get_active_pids() {
    local active_pids=""
    local now
    now="$(date +%s)"

    # Method 1: processes with connected debugging sockets (DevToolsActivePort)
    # Playwright connects to Chrome via CDP; if the socket is warm, it's active.
    for pid_dir in /proc/[0-9]*; do
        pid="${pid_dir#/proc/}"
        pid="${pid%/}"

        # Skip if not a chrome process
        cmdline=""
        cmdline_path="/proc/$pid/cmdline"
        [[ -f "$cmdline_path" ]] || continue
        cmdline="$(tr '\0' ' ' < "$cmdline_path" 2>/dev/null)" || continue

        # Must be a chromium/chrome process
        [[ "$cmdline" == *chromium* ]] || [[ "$cmdline" == *chrome* ]] || continue

        # Check for DevToolsActivePort file — means a debug session is established
        # Also check /proc/$pid/fd for active unix sockets to playwright
        devtools="/proc/$pid/root/.config/chromium/DevToolsActivePort"
        # Try to find DevToolsActivePort from the process's fd list
        if ls -la "/proc/$pid/fd/" 2>/dev/null | grep -q "DevToolsActivePort"; then
            echo "$pid"
            continue
        fi

        # Method 2: check if the user-data-dir was modified in the last 5 minutes
        # Extract user-data-dir from cmdline
        user_data_dir=""
        if [[ "$cmdline" =~ --user-data-dir=([^ ]+) ]]; then
            user_data_dir="${BASH_REMATCH[1]}"
        elif [[ "$cmdline" =~ --user-data-dir[[:space:]]+([^ ]+) ]]; then
            user_data_dir="${BASH_REMATCH[1]}"
        fi

        if [[ -n "$user_data_dir" && -d "$user_data_dir" ]]; then
            # Check if any file in user-data-dir was modified in the last 5 minutes
            if find "$user_data_dir" -maxdepth 2 -newermt "$(date -d @$((now - 300)) '+%Y-%m-%d %H:%M:%S')" -print -quit 2>/dev/null | grep -q .; then
                echo "$pid"
                continue
            fi
        fi

        # Method 3: check if the process has active TCP sockets (CDP connection)
        # A process with an ESTABLISHED TCP connection is likely actively used
        if ls "/proc/$pid/fd/" 2>/dev/null | while read -r fd; do
            link="$(readlink "/proc/$pid/fd/$fd" 2>/dev/null)" || continue
            if [[ "$link" == socket* ]]; then
                # Check if this socket is ESTABLISHED from /proc/net/tcp
                inode="${link#socket:[}"
                inode="${inode%/}"
                if grep -q "$inode" /proc/net/tcp 2>/dev/null; then
                    # Check socket state (01=ESTABLISHED)
                    if grep -w "$inode" /proc/net/tcp 2>/dev/null | awk '{print $4}' | grep -q "01"; then
                        echo "active"
                        break
                    fi
                fi
            fi
        done | grep -q "active"; then
            echo "$pid"
        fi
    done
}

# ── Find orphan Chrome/Playwright processes ────────────────────────────────────
find_orphan_processes() {
    local now
    now="$(date +%s)"
    local boot_time
    boot_time="$(awk '/btime/{print $2}' /proc/stat)"

    # Get set of active PIDs to skip
    local active_pid_set
    active_pid_set="$(get_active_pids 2>/dev/null | sort -u | grep -v '^$' || true)"

    if [[ -n "$active_pid_set" ]]; then
        log "Active browser PIDs to preserve: $(echo $active_pid_set | tr '\n' ' ')"
    fi

    # Iterate over all processes looking for Chrome/Playwright headless
    for pid_dir in /proc/[0-9]*; do
        pid="${pid_dir#/proc/}"
        pid="${pid%/}"

        # Read cmdline
        cmdline_path="/proc/$pid/cmdline"
        [[ -f "$cmdline_path" ]] || continue
        cmdline="$(tr '\0' ' ' < "$cmdline_path" 2>/dev/null)" || continue

        # Must be a chromium/chrome process under the Playwright cache
        [[ "$cmdline" == */.cache/ms-playwright/* ]] || \
        [[ "$cmdline" == *--headless* ]] && [[ "$cmdline" == *chromium* || "$cmdline" == *chrome* ]] || \
        [[ "$cmdline" == *--ozone-platform=headless* ]] || continue

        # Skip the type=utility subprocesses unless they're also old
        # (renderer, GPU, etc. — we kill the whole tree from the main process,
        #  but also catch orphans whose parent died)

        # Skip if this PID is in the active set
        if echo "$active_pid_set" | grep -qw "$pid"; then
            continue
        fi

        # Check process age via /proc/$pid/stat
        stat_path="/proc/$pid/stat"
        [[ -f "$stat_path" ]] || continue

        # Field 22 in /proc/PID/stat is starttime (clock ticks since boot)
        starttime="$(awk '{print $22}' "$stat_path" 2>/dev/null)" || continue
        [[ "$starttime" =~ ^[0-9]+$ ]] || continue

        # Get clock ticks per second
        clk_tck="$(getconf CLK_TCK 2>/dev/null || echo 100)"
        if [[ "$clk_tck" -eq 0 ]]; then
            clk_tck=100
        fi

        # Calculate process start time in seconds since epoch
        start_seconds=$((boot_time + starttime / clk_tck))
        age_seconds=$((now - start_seconds))

        # Skip processes younger than MAX_AGE_MINUTES
        if [[ "$age_seconds" -lt "$MAX_AGE_SECONDS" ]]; then
            continue
        fi

        # This is an orphan candidate — report it
        # Get a short description of the process for logging
        short_cmd="$(echo "$cmdline" | cut -c1-120)"
        echo "${pid}:${age_seconds}:${short_cmd}"
    done
}

# ── Kill a process gracefully ──────────────────────────────────────────────────
kill_process() {
    local pid="$1"
    local age="$2"
    local desc="$3"

    if [[ "$DRY_RUN" == "1" ]]; then
        log "[DRY RUN] Would kill PID=$pid (age=${age}s): $desc"
        return 0
    fi

    log "Killing PID=$pid (age=${age}s): SIGTERM -> $desc"

    # Send SIGTERM
    if ! kill -TERM "$pid" 2>/dev/null; then
        log "  PID=$pid already gone"
        return 0
    fi

    # Wait up to GRACE_SECONDS for the process to exit
    local waited=0
    while [[ "$waited" -lt "$GRACE_SECONDS" ]]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            log "  PID=$pid terminated gracefully after ${waited}s"
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done

    # Still alive — send SIGKILL
    if kill -0 "$pid" 2>/dev/null; then
        log "  PID=$pid still alive after ${GRACE_SECONDS}s — sending SIGKILL"
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then
            log "  PID=$pid survived SIGKILL (!) — skipping"
        else
            log "  PID=$pid killed with SIGKILL"
        fi
    fi
}

# ── Also kill child processes of the orphan ────────────────────────────────────
# When we kill a main Chrome process, its children (renderer, GPU, etc.) become
# orphaned too. We kill the entire process tree.
kill_tree() {
    local ppid="$1"
    local age="$2"
    local desc="$3"

    # Find child PIDs
    local children
    children="$(pgrep -P "$ppid" 2>/dev/null || true)"

    # Kill the parent first
    kill_process "$ppid" "$age" "$desc"

    # Then kill children
    if [[ -n "$children" ]]; then
        for child in $children; do
            # Recursively kill child trees
            kill_tree "$child" "$age" "child of $ppid"
        done
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    log "--- chrome_orphan_killer started (max_age=${MAX_AGE_MINUTES}m, grace=${GRACE_SECONDS}s, dry_run=${DRY_RUN}) ---"

    local orphans
    orphans="$(find_orphan_processes)" || true

    if [[ -z "$orphans" ]]; then
        log "No orphan Chrome/Playwright processes found"
        log "--- chrome_orphan_killer finished ---"
        exit 0
    fi

    local count
    count="$(echo "$orphans" | wc -l)"
    log "Found $count orphan process(es)"

    # Process each orphan — kill parent processes first (trees)
    # Sort by age descending so we kill the oldest first
    local killed=0
    echo "$orphans" | while IFS=: read -r pid age desc; do
        [[ -z "$pid" ]] && continue

        # Skip if process is already gone
        [[ -d "/proc/$pid" ]] || continue

        # Skip child processes — we kill the whole tree from the parent
        # Check if this PID's parent is also in our orphan list
        ppid="$(awk '{print $4}' "/proc/$pid/stat" 2>/dev/null)" || continue
        if echo "$orphans" | cut -d: -f1 | grep -qw "$ppid"; then
            log "  Skipping PID=$pid (child of $ppid, will be killed with parent)"
            continue
        fi

        kill_tree "$pid" "$age" "$desc"
        killed=$((killed + 1))
    done

    log "Processed orphan processes"
    log "--- chrome_orphan_killer finished ---"
}

main "$@"
