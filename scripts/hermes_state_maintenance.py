#!/usr/bin/env python3
"""
Hermes state.db Maintenance — Vacuum + Old Message Cleanup
===========================================================
Periodic maintenance for the Hermes SQLite state database:
1. Marks pre-compression messages as compacted=1
2. Deletes orphaned tool output >30 days old
3. Runs VACUUM to reclaim disk space
4. Prunes empty/old sessions

Usage:
  python3 hermes_state_maintenance.py              # dry-run
  python3 hermes_state_maintenance.py --confirm      # execute
  python3 hermes_state_maintenance.py --vacuum-only  # just VACUUM
"""
import argparse
import os
import sqlite3
import sys
import time
from pathlib import Path

STATE_DB = Path(os.getenv("HERMES_STATE_DB", Path.home() / ".hermes" / "state.db"))
MAX_AGE_DAYS = int(os.getenv("HERMES_STATE_MAX_AGE_DAYS", "30"))

def get_db_size_mb():
    return os.path.getsize(STATE_DB) / 1024 / 1024

def main():
    parser = argparse.ArgumentParser(description="Hermes state.db maintenance")
    parser.add_argument("--confirm", action="store_true", help="Execute changes (default: dry-run)")
    parser.add_argument("--vacuum-only", action="store_true", help="Only run VACUUM")
    parser.add_argument("--max-age", type=int, default=MAX_AGE_DAYS, help="Max age in days for cleanup")
    args = parser.parse_args()

    dry_run = not args.confirm
    mode = "DRY-RUN" if dry_run else "LIVE"
    
    print(f"=" * 60)
    print(f"Hermes state.db Maintenance — {mode}")
    print(f"  DB: {STATE_DB} ({get_db_size_mb():.0f} MB)")
    print(f"  Max age: {args.max_age} days")
    print(f"=" * 60)

    conn = sqlite3.connect(str(STATE_DB))
    conn.execute("PRAGMA journal_mode=WAL")
    c = conn.cursor()

    changes = 0

    # ── 1. Mark pre-compression messages as compacted ─────────
    if not args.vacuum_only:
        # Find messages from sessions that have been compressed (parent_session_id exists)
        c.execute("""
            SELECT count(*) FROM messages m
            JOIN sessions s ON m.session_id = s.id
            WHERE s.end_reason = 'compression'
              AND m.compacted = 0
        """)
        unmarked = c.fetchone()[0]
        print(f"\n[1] Messages in compressed sessions not marked compacted: {unmarked:,}")
        
        if unmarked > 0:
            if dry_run:
                print(f"    Would mark {unmarked:,} messages as compacted=1")
            else:
                c.execute("""
                    UPDATE messages SET compacted = 1
                    WHERE session_id IN (
                        SELECT id FROM sessions WHERE end_reason = 'compression'
                    ) AND compacted = 0
                """)
                print(f"    ✅ Marked {c.rowcount:,} messages as compacted=1")
                changes += c.rowcount

        # ── 2. Delete old tool output blobs ────────────────────
        # Tool messages >30 days with content >10KB (likely curl/docker output)
        c.execute("""
            SELECT count(*), sum(length(content)) 
            FROM messages 
            WHERE role = 'tool'
              AND compacted = 1
              AND length(content) > 10240
              AND session_id IN (
                  SELECT id FROM sessions 
                  WHERE started_at < datetime('now', ? || ' days')
              )
        """, (str(-args.max_age),))
        r = c.fetchone()
        old_tools = r[0]
        old_tools_bytes = r[1] or 0
        
        print(f"\n[2] Old compacted tool messages (>{args.max_age}d, >10KB): {old_tools:,} ({old_tools_bytes/1024/1024:.1f} MB)")
        
        if old_tools > 0 and not dry_run:
            # Truncate content instead of deleting (preserve message metadata)
            c.execute("""
                UPDATE messages SET content = '<compacted>'
                WHERE role = 'tool'
                  AND compacted = 1
                  AND length(content) > 10240
                  AND session_id IN (
                      SELECT id FROM sessions 
                      WHERE started_at < datetime('now', ? || ' days')
                  )
            """, (str(-args.max_age),))
            print(f"    ✅ Truncated {c.rowcount:,} old tool messages ({old_tools_bytes/1024/1024:.1f} MB freed)")
            changes += c.rowcount
        elif old_tools > 0:
            print(f"    Would truncate {old_tools:,} old tool messages")

        # ── 3. Delete very old compacted reasoning ──────────────
        c.execute("""
            SELECT count(*), sum(length(reasoning))
            FROM messages
            WHERE compacted = 1
              AND length(COALESCE(reasoning, '')) > 0
              AND session_id IN (
                  SELECT id FROM sessions 
                  WHERE started_at < datetime('now', ? || ' days')
              )
        """, (str(-args.max_age),))
        r = c.fetchone()
        old_reason = r[0]
        old_reason_bytes = r[1] or 0
        
        print(f"\n[3] Old compacted reasoning (>{args.max_age}d): {old_reason:,} ({old_reason_bytes/1024/1024:.1f} MB)")
        
        if old_reason > 0 and not dry_run:
            c.execute("""
                UPDATE messages SET reasoning = NULL, reasoning_content = NULL
                WHERE compacted = 1
                  AND length(COALESCE(reasoning, '')) > 0
                  AND session_id IN (
                      SELECT id FROM sessions 
                      WHERE started_at < datetime('now', ? || ' days')
                  )
            """, (str(-args.max_age),))
            print(f"    ✅ Cleared {c.rowcount:,} old reasoning blobs ({old_reason_bytes/1024/1024:.1f} MB freed)")
            changes += c.rowcount
        elif old_reason > 0:
            print(f"    Would clear {old_reason:,} old reasoning blobs")

    # ── 4. VACUUM ──────────────────────────────────────────────
    before_mb = get_db_size_mb()
    print(f"\n[4] VACUUM (reclaim freed space)")
    print(f"    DB before: {before_mb:.0f} MB")
    
    if not dry_run:
        print("    Running VACUUM... (this may take a minute)")
        c.execute("VACUUM")
        after_mb = get_db_size_mb()
        print(f"    ✅ DB after: {after_mb:.0f} MB (saved {before_mb - after_mb:.0f} MB)")
    else:
        print(f"    Would run VACUUM (estimated ~{before_mb * 0.3:.0f} MB reclaimable)")

    if not dry_run:
        conn.commit()
    
    conn.close()

    # ── Summary ────────────────────────────────────────────────
    print(f"\n{'=' * 60}")
    print(f"Final DB size: {get_db_size_mb():.0f} MB")
    print(f"Mode: {mode}")
    if dry_run:
        print("Run with --confirm to execute changes")
    print(f"{'=' * 60}")

if __name__ == "__main__":
    main()
