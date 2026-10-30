"""
Reference implementation of the hold-merge logic in plain Python.

The SQL version (sql/03_fn_merged_holds.sql) does the same thing with
window functions. This file exists to explain the algorithm step by step
and to give the SQL an independent result to be checked against.

Rules (same as the SQL):
  * Dates are inclusive: a hold from Mar 3 to Mar 5 is 3 days.
  * An open hold (no end date) runs through the as-of date.
  * Holds are clipped to the ticket's open window [open_date, close_date].
    An open ticket (no close date) runs through the as-of date.
  * Holds with end < start are bad data: excluded and reported, never guessed at.
  * Holds that overlap OR touch (end + 1 day == next start) merge into one island.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Iterable, List, Optional, Tuple

ONE_DAY = timedelta(days=1)


@dataclass(frozen=True)
class Hold:
    hold_id: int
    start: date
    end: Optional[date]  # None = still on hold


@dataclass(frozen=True)
class Island:
    start: date
    end: date

    @property
    def days(self) -> int:
        return (self.end - self.start).days + 1


def merge_holds(
    holds: Iterable[Hold],
    open_date: date,
    close_date: Optional[date],
    as_of: date,
) -> Tuple[List[Island], List[Hold]]:
    """Return (merged islands, holds rejected as bad data)."""
    window_end = close_date or as_of
    rejected: List[Hold] = []
    clipped: List[Tuple[date, date, int]] = []

    # Step 1: drop bad rows, fill open ends, clip to the ticket window.
    for h in holds:
        if h.end is not None and h.end < h.start:
            rejected.append(h)
            continue
        start = max(h.start, open_date)
        end = min(h.end or as_of, window_end)
        if start <= end:  # anything left after clipping?
            clipped.append((start, end, h.hold_id))

    # Step 2: sort by start (then end, then id, so ties are deterministic).
    clipped.sort()

    # Step 3: walk the list, tracking the furthest end seen so far.
    # A new island starts only when a hold begins after that furthest end + 1 day.
    # Tracking the running MAX (not just the previous row's end) is what makes
    # a long hold correctly swallow later, shorter holds.
    islands: List[Island] = []
    for start, end, _ in clipped:
        if islands and start <= islands[-1].end + ONE_DAY:
            last = islands[-1]
            islands[-1] = Island(last.start, max(last.end, end))
        else:
            islands.append(Island(start, end))

    return islands, rejected


def total_hold_days(islands: Iterable[Island]) -> int:
    return sum(i.days for i in islands)
