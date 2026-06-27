#!/usr/bin/env python3
"""
Hindsight Memory Purge Script
==============================
Scans the Hindsight API for purgeable memories in a bank and invalidates them.

Purge criteria (all three are independent):
  1. OLDER-AND-RARE:  age > 30 days AND proof_count <= 1
  2. BROKEN-CONSOLIDATION:  consolidation_failed_at is not null
  3. ALREADY-INVALIDATED:  state == 'invalidated'  (stale invalidated cleanup)

Because Hindsight has no per-memory hard-DELETE endpoint, the script uses PATCH
to set state='invalidated'. This is the API's supported soft-delete: invalidated
memories are excluded from recall, consolidation, and graph, and it's reversible
via PATCH with state='valid'.

Usage:
  python3 hindsight_memory_purge.py                  # dry-run (default)
  python3 hindsight_memory_purge.py --confirm        # actually invalidate
  python3 hindsight_memory_purge.py --max-age 14     # override 30-day threshold
  python3 hindsight_memory_purge.py --bank mybank    # override bank id
  python3 hindsight_memory_purge.py --max-purge 1000 # cap invalidations per run

Cron example (weekly Sunday at 3 AM):
  0 3 * * 0 /home/ubuntu/.hermes/scripts/hindsight_memory_purge.py --confirm --max-purge 5000 >> /home/ubuntu/.hermes/scripts/logs/cron.log 2>&1
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

# ── Configuration ──────────────────────────────────────────────────────────
DEFAULT_API_BASE = os.environ.get("HINDSIGHT_API_URL", "http://localhost:8890")
DEFAULT_BANK_ID = os.environ.get("HINDSIGHT_BANK_ID", "hermes")
DEFAULT_MAX_AGE_DAYS = int(os.environ.get("HINDSIGHT_MAX_AGE_DAYS", "30"))
DEFAULT_BATCH_SIZE = 500  # API max supported page size
DEFAULT_MAX_PURGE = 5000
FETCH_WORKERS = 2  # parallel page fetches (keep low — Hindsight chokes on 4+)
FETCH_DELAY_BETWEEN_BATCHES = 0.3  # seconds between parallel batch submissions

LOG_DIR = Path(os.environ.get("HINDSIGHT_LOG_DIR", str(Path(__file__).parent / "logs")))

# ── Logging ────────────────────────────────────────────────────────────────


def setup_logging(dry_run: bool) -> logging.Logger:
    """Configure file + console logging."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    tag = "dryrun" if dry_run else "purge"
    log_file = LOG_DIR / f"memory_purge_{tag}_{ts}.log"

    logger = logging.getLogger("hindsight_purge")
    logger.setLevel(logging.DEBUG)
    # Clear any prior handlers (important if called multiple times in tests)
    logger.handlers.clear()

    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.DEBUG)
    fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)-8s %(message)s"))

    ch = logging.StreamHandler(sys.stdout)
    ch.setLevel(logging.INFO)
    ch.setFormatter(logging.Formatter("%(asctime)s %(levelname)-8s %(message)s"))

    logger.addHandler(fh)
    logger.addHandler(ch)
    logger.info("Log file: %s", log_file)
    return logger


# ── HTTP helpers (stdlib only, zero external deps) ─────────────────────────


def _request(url: str, method: str = "GET", body: dict | None = None, retries: int = 3) -> dict:
    """Make an HTTP request with retry logic. Returns parsed JSON."""
    for attempt in range(1, retries + 1):
        try:
            data = json.dumps(body).encode() if body else None
            req = Request(url, data=data, method=method)
            req.add_header("Accept", "application/json")
            if body:
                req.add_header("Content-Type", "application/json")
            with urlopen(req, timeout=90) as resp:
                return json.loads(resp.read().decode())
        except (HTTPError, URLError) as exc:
            if attempt < retries:
                time.sleep(2 * attempt)
            else:
                raise


# ── Memory fetching with parallel pagination ───────────────────────────────


def _fetch_page(bank_id: str, api_base: str, offset: int, limit: int,
                extra_params: dict | None = None) -> tuple[list[dict], int]:
    """Fetch a single page of memories. Returns (items, total)."""
    base_url = f"{api_base}/v1/default/banks/{bank_id}/memories/list"
    params = {"limit": limit, "offset": offset}
    if extra_params:
        params.update(extra_params)
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    data = _request(f"{base_url}?{qs}")
    return data.get("items", []), data.get("total", 0)


def fetch_memories(
    bank_id: str,
    api_base: str,
    batch_size: int,
    logger: logging.Logger,
    extra_params: dict | None = None,
) -> list[dict]:
    """Paginate through the list endpoint using parallel fetches with retry.

    Uses 2 workers and small delays between submissions to avoid
    overwhelming the Hindsight API (502 errors under high concurrency).
    Failed pages are retried up to 3 times with exponential backoff.
    """
    # First request to learn the total
    first_items, total = _fetch_page(bank_id, api_base, 0, batch_size, extra_params)
    logger.info("  Total memories matching query: %d", total)

    if total <= batch_size:
        return first_items

    # Schedule remaining pages
    all_items = list(first_items)
    offsets = list(range(batch_size, total, batch_size))
    logger.info("  Fetching %d additional pages with %d workers …", len(offsets), FETCH_WORKERS)

    # Retry loop: submit pages, collect results, retry failures
    remaining_offsets = list(offsets)
    max_retries = 3

    for retry_round in range(max_retries):
        if not remaining_offsets:
            break

        label = f"  (attempt {retry_round + 1})" if retry_round > 0 else ""
        failed_offsets: list[int] = []

        with ThreadPoolExecutor(max_workers=FETCH_WORKERS) as pool:
            # Submit with small delays to avoid burst
            futures: dict = {}
            for off in remaining_offsets:
                futures[pool.submit(_fetch_page, bank_id, api_base, off, batch_size, extra_params)] = off
                time.sleep(FETCH_DELAY_BETWEEN_BATCHES)

            for future in as_completed(futures):
                off = futures[future]
                try:
                    items, _ = future.result()
                    all_items.extend(items)
                except Exception as exc:
                    if retry_round < max_retries - 1:
                        logger.warning("  Page offset %d failed (%s), will retry", off, exc)
                        failed_offsets.append(off)
                    else:
                        logger.error("  Page offset %d failed after %d attempts: %s", off, max_retries, exc)

        remaining_offsets = failed_offsets
        if remaining_offsets:
            wait = 2 ** (retry_round + 1)
            logger.info("  Retrying %d failed pages in %ds …", len(remaining_offsets), wait)
            time.sleep(wait)

    logger.info("  Fetched %d items total", len(all_items))
    return all_items


# ── Candidate selection ────────────────────────────────────────────────────


def find_purge_candidates(
    bank_id: str,
    api_base: str,
    batch_size: int,
    max_age_days: int,
    logger: logging.Logger,
) -> dict[str, list[dict]]:
    """Identify all purge candidates using a combination of API filters and
    client-side classification.

    Strategy:
    - Broken consolidation: use API filter consolidation_state=failed (fast, ~36 items)
    - Older-and-rare: must scan all valid memories client-side (no age/proof_count API filter)
    - Already invalidated: use API filter state=invalidated (fast)
    """
    candidates: dict[str, list[dict]] = {
        "older_and_rare": [],
        "broken_consolidation": [],
        "already_invalidated": [],
    }

    # ── Criterion 2: Failed consolidation (API-filtered, small set) ────
    logger.info("Phase 1a: Fetching memories with failed consolidation …")
    failed_memories = fetch_memories(
        bank_id, api_base, batch_size, logger,
        extra_params={"consolidation_state": "failed"},
    )
    candidates["broken_consolidation"] = failed_memories
    logger.info("  Broken consolidation: %d", len(failed_memories))

    # ── Criterion 3: Already invalidated (API-filtered, usually small) ─
    logger.info("Phase 1b: Fetching already-invalidated memories …")
    invalidated_memories = fetch_memories(
        bank_id, api_base, batch_size, logger,
        extra_params={"state": "invalidated"},
    )
    candidates["already_invalidated"] = invalidated_memories
    logger.info("  Already invalidated: %d", len(invalidated_memories))

    # ── Criterion 1: Older-and-rare (must scan all valid memories) ──────
    logger.info("Phase 2: Scanning all valid memories for older-and-rare criterion …")
    valid_memories = fetch_memories(
        bank_id, api_base, batch_size, logger,
        extra_params={"state": "valid"},
    )
    logger.info("  Scanning %d valid memories …", len(valid_memories))

    cutoff = datetime.now(timezone.utc) - timedelta(days=max_age_days)
    older_and_rare: list[dict] = []
    for m in valid_memories:
        date_str = m.get("date") or m.get("mentioned_at")
        if not date_str:
            continue
        try:
            mem_date = datetime.fromisoformat(date_str)
            if mem_date.tzinfo is None:
                mem_date = mem_date.replace(tzinfo=timezone.utc)
            if mem_date < cutoff and (m.get("proof_count") or 0) <= 1:
                older_and_rare.append(m)
        except (ValueError, TypeError):
            pass

    candidates["older_and_rare"] = older_and_rare
    logger.info("  Older-and-rare (>%d days, proof≤1): %d", max_age_days, len(older_and_rare))

    return candidates


def deduplicate_candidates(candidates: dict[str, list[dict]]) -> list[tuple[str, dict]]:
    """Merge categories into a deduplicated list of (reason, memory) tuples."""
    seen: set[str] = set()
    merged: list[tuple[str, dict]] = []
    # Priority order: broken_consolidation first (these are definitely bad),
    # then older_and_rare, then already_invalidated (no-op but logged)
    for category in ("broken_consolidation", "older_and_rare", "already_invalidated"):
        for m in candidates.get(category, []):
            mid = m["id"]
            if mid not in seen:
                seen.add(mid)
                merged.append((category, m))
    return merged


# ── Invalidation (purge action) ────────────────────────────────────────────


def invalidate_memory(
    bank_id: str,
    api_base: str,
    memory_id: str,
    reason: str,
    logger: logging.Logger,
) -> bool:
    """PATCH a memory to state='invalidated'. Returns True on success."""
    url = f"{api_base}/v1/default/banks/{bank_id}/memories/{memory_id}"
    body = {"state": "invalidated", "reason": reason}

    try:
        result = _request(url, method="PATCH", body=body)
        logger.debug("Invalidated %s → state=%s", memory_id, result.get("state"))
        return True
    except Exception as exc:
        logger.error("FAILED to invalidate %s: %s", memory_id, exc)
        return False


# ── Main ────────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Purge stale/rarely-referenced memories from Hindsight"
    )
    parser.add_argument(
        "--confirm",
        action="store_true",
        help="Actually invalidate memories (default is dry-run)",
    )
    parser.add_argument(
        "--bank",
        default=DEFAULT_BANK_ID,
        help=f"Bank ID (default: {DEFAULT_BANK_ID})",
    )
    parser.add_argument(
        "--api-base",
        default=DEFAULT_API_BASE,
        help=f"Hindsight API base URL (default: {DEFAULT_API_BASE})",
    )
    parser.add_argument(
        "--max-age",
        type=int,
        default=DEFAULT_MAX_AGE_DAYS,
        help=f"Max age in days for older-and-rare criterion (default: {DEFAULT_MAX_AGE_DAYS})",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=DEFAULT_BATCH_SIZE,
        help=f"API page size (default: {DEFAULT_BATCH_SIZE})",
    )
    parser.add_argument(
        "--max-purge",
        type=int,
        default=DEFAULT_MAX_PURGE,
        help=f"Max memories to invalidate per run (default: {DEFAULT_MAX_PURGE})",
    )
    args = parser.parse_args()

    dry_run = not args.confirm
    logger = setup_logging(dry_run)

    mode_label = "DRY-RUN" if dry_run else "LIVE PURGE"
    logger.info("=" * 60)
    logger.info("Hindsight Memory Purge — %s", mode_label)
    logger.info("  Bank:       %s", args.bank)
    logger.info("  API base:   %s", args.api_base)
    logger.info("  Max age:    %d days", args.max_age)
    logger.info("  Batch size: %d", args.batch_size)
    logger.info("  Max purge:  %d", args.max_purge)
    logger.info("=" * 60)

    # ── Find candidates ────────────────────────────────────────────────
    candidates = find_purge_candidates(
        args.bank, args.api_base, args.batch_size, args.max_age, logger
    )

    logger.info("-" * 40)
    logger.info("Candidate summary:")
    logger.info("  Older-and-rare (>%d days, proof≤1): %d", args.max_age, len(candidates["older_and_rare"]))
    logger.info("  Broken consolidation:               %d", len(candidates["broken_consolidation"]))
    logger.info("  Already invalidated:                 %d", len(candidates["already_invalidated"]))

    merged = deduplicate_candidates(candidates)
    logger.info("  Unique purgeable memories:          %d", len(merged))

    if not merged:
        logger.info("No purgeable memories found. Done.")
        return 0

    # ── Write audit trail ──────────────────────────────────────────────
    to_process = merged[: args.max_purge]
    ts_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    audit_path = LOG_DIR / f"purge_candidates_{ts_str}.json"

    audit_data = [
        {
            "id": m["id"],
            "reason": reason,
            "text": (m.get("text") or "")[:200],
            "proof_count": m.get("proof_count"),
            "date": m.get("date"),
            "state": m.get("state"),
            "consolidation_failed_at": m.get("consolidation_failed_at"),
        }
        for reason, m in to_process
    ]
    with open(audit_path, "w") as f:
        json.dump(audit_data, f, indent=2)
    logger.info("Audit trail: %s", audit_path)

    if dry_run:
        # ── Dry-run: just report ────────────────────────────────────────
        by_reason: dict[str, int] = {}
        for reason, _ in to_process:
            by_reason[reason] = by_reason.get(reason, 0) + 1

        print(f"\n{'='*70}")
        print(f"DRY-RUN SUMMARY — {len(to_process)} memories would be invalidated")
        print(f"{'='*70}")
        for reason, count in sorted(by_reason.items()):
            print(f"  {reason}: {count}")
        print(f"{'='*70}")
        skipped = max(0, len(merged) - args.max_purge)
        if skipped:
            print(f"  ({skipped} additional candidates beyond --max-purge not shown)")
        print("Re-run with --confirm to actually invalidate these memories.")
        print(f"Full candidate list: {audit_path}")
        return 0

    # ── Live purge ─────────────────────────────────────────────────────
    logger.info("Phase 3: Invalidating %d memories …", len(to_process))
    success_count = 0
    fail_count = 0

    for i, (reason, m) in enumerate(to_process, 1):
        mid = m["id"]
        logger.info("[%d/%d] Invalidating %s (%s)", i, len(to_process), mid, reason)
        ok = invalidate_memory(args.bank, args.api_base, mid, f"purge:{reason}", logger)
        if ok:
            success_count += 1
        else:
            fail_count += 1

        # Progress checkpoint every 100
        if i % 100 == 0:
            logger.info("  Progress: %d/%d (ok=%d fail=%d)", i, len(to_process), success_count, fail_count)
        # Small throttle to avoid API overload
        if i % 50 == 0:
            time.sleep(0.5)

    logger.info("=" * 60)
    logger.info("PURGE COMPLETE")
    logger.info("  Invalidated: %d", success_count)
    logger.info("  Failed:      %d", fail_count)
    skipped = max(0, len(merged) - args.max_purge)
    if skipped:
        logger.info("  Skipped:     %d (beyond --max-purge)", skipped)
    logger.info("=" * 60)
    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
