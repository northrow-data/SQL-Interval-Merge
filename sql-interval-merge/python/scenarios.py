"""
The 15 test scenarios, shared by the Python tests.
sql/05_test_harness.sql contains the same scenarios as INSERT statements.

Each scenario is one ticket with its open window, its holds, and the expected
result after merging: number of islands and total hold days (inclusive).
"""

from datetime import date

AS_OF = date(2025, 3, 31)


def d(day: int, month: int = 3) -> date:
    return date(2025, month, day)


# (ticket_id, name, open_date, close_date, [(start, end), ...], expected_islands, expected_days)
SCENARIOS = [
    (1, "No holds", d(1), d(31), [], 0, 0),
    (2, "Single hold", d(1), d(31), [(d(3), d(5))], 1, 3),
    (3, "Two separate holds", d(1), d(31), [(d(3), d(5)), (d(10), d(11))], 2, 5),
    (4, "Partial overlap", d(1), d(31), [(d(3), d(7)), (d(5), d(10))], 1, 8),
    (5, "Nested hold", d(1), d(31), [(d(3), d(12)), (d(5), d(7))], 1, 10),
    (6, "Adjacent holds (touching days)", d(1), d(31), [(d(3), d(5)), (d(6), d(8))], 1, 6),
    (7, "Exact duplicate", d(1), d(31), [(d(3), d(5)), (d(3), d(5))], 1, 3),
    (8, "Bad row (end before start) is excluded", d(1), d(31), [(d(10), d(5)), (d(3), d(4))], 1, 2),
    (9, "Chain of overlaps", d(1), d(31), [(d(1), d(4)), (d(4), d(8)), (d(8), d(12))], 1, 12),
    (10, "Long hold swallows later short holds", d(1), d(31),
     [(d(1), d(20)), (d(5), d(6)), (d(10), d(12))], 1, 20),
    (11, "One-day hold", d(1), d(31), [(d(15), d(15))], 1, 1),
    (12, "Open hold runs to as-of date", d(1), None, [(d(25), None)], 1, 7),
    (13, "Hold starts before ticket opens (clipped)", d(10), d(31), [(d(1), d(12))], 1, 3),
    (14, "Hold ends after ticket closes (clipped)", d(1), d(20), [(d(18), d(28))], 1, 3),
    (15, "Hold entirely outside ticket window", d(1), d(15), [(d(20), d(25))], 0, 0),
]
