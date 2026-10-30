# Merging overlapping hold periods in SQL Server

When a ticket waits on two things at once (parts *and* the customer, say), a plain `SUM` of hold time counts the overlap twice. Cycle times come out too short, and nobody notices because the numbers look reasonable.

This repo merges overlapping date ranges in T-SQL with a **gaps-and-islands** window-function pattern. It proves the logic against **15 edge cases** with a PASS/FAIL test harness and uses the result to compute an honest **business-day cycle time**. A plain-Python version of the same algorithm is included for explanation and cross-checking.

All data is made up. Runs on **SQL Server 2012 and later**.

## The payoff

Output of `sql/04_cycle_time.sql` on the sample data (business days):

| Ticket | Cycle | Naive hold (SUM) | Merged hold | Net working days | Note |
|---:|---:|---:|---:|---:|---|
| 101 | 20 | 5 | 5 | 15 | |
| 102 | 30 | **20** | **15** | 15 | parts and customer holds overlap |
| 103 | 39 | **31** | **25** | 14 | short holds inside a long one |
| 104 | 20 | 0 | 0 | 20 | no holds |
| 105 | 33 | 10 | 10 | 23 | holds touch end-to-start |
| 106 | 34 | 5 | 5 | 29 | bad row excluded, listed by `06_data_quality.sql` |
| 107 | 61 | 41 | 41 | 20 | still open, still on hold (as of Dec 31) |
| 108 | NULL | NULL | NULL | NULL | dates outside the calendar: **NULL, not 0** |

For tickets 102 and 103, the naive sum overstates hold time by 5–6 business days, which understates real working time by the same amount.

## How the merge works

`sql/03_fn_merged_holds.sql` is an inline table-valued function, `dbo.fn_MergedHolds(@AsOfDate)`:

1. **Clean.** Drop rows that end before they start, treat a missing end date as "still on hold through the as-of date", and clip each hold to the ticket's open window.
2. **Order** each ticket's holds by start date.
3. **Compare.** For each hold, find the furthest end date among all *earlier* holds using `MAX(...) OVER (... ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)`.
4. **Flag** a new island when a hold starts more than one day after that furthest end. Overlapping and touching holds merge.
5. **Number** the islands with a running `SUM` of the flags.
6. **Collapse** with `GROUP BY` island.

### Why a running MAX and not LAG

```
Hold A  |=========================|        Mar 1 - Mar 20
Hold B       |==|                          Mar 5 - Mar 6
Hold C               |===|                 Mar 10 - Mar 12
```

With `LAG`, hold C is compared only to hold B (ends Mar 6), so it looks like a new island and the total comes out too high. With a running `MAX`, C is compared to A's Mar 20 end and correctly merges. That's test scenario 10.

## Design choices

- **Inclusive dates.** A hold from Mar 3 to Mar 5 is 3 days. Choose one rule, write it down, and test it.
- **Bad data is excluded and reported, never guessed at.** `06_data_quality.sql` lists rows that end before they start, orphans, join fan-out, out-of-window holds, duplicates and open holds.
- **NULL instead of a wrong zero.** Business-day counts come from a calendar table. If a ticket's dates fall outside the calendar's range, a join quietly returns 0 or too few days, and that bad number flows into averages. The query returns NULL with a note instead.
- **Weekends are found without relying on server settings.** It uses the day count since 1900-01-01 (a Monday), so the result doesn't depend on `DATEFIRST` or language.

## Run it

**SQL Server** (SSMS or Azure Data Studio), in order:

| File | What it does |
|---|---|
| `sql/01_schema.sql` | Tables and a 2025 business calendar |
| `sql/02_sample_data.sql` | 8 made-up tickets with messy holds |
| `sql/03_fn_merged_holds.sql` | The merge function |
| `sql/04_cycle_time.sql` | Business-day cycle time, naive vs merged |
| `sql/05_test_harness.sql` | 15 scenarios with PASS/FAIL output; rolls back afterward |
| `sql/06_data_quality.sql` | Data checks to run before trusting the numbers |

**Python** (no dependencies; Python 3.8+):

```
cd python
python -m unittest -v
```

`python/scenarios.py` holds the same 15 scenarios as the SQL harness, so both implementations are checked against identical cases.

## Test scenarios

No holds · single hold · two separate holds · partial overlap · nested hold · adjacent (touching) holds · exact duplicate · bad row (end before start) · chain of overlaps · long hold swallowing later short holds · one-day hold · open hold · hold starting before the ticket opens · hold ending after the ticket closes · hold entirely outside the ticket window.

---

Brandon Watson · Reporting analyst (SQL Server, SSRS, Python) · [LinkedIn](https://www.linkedin.com/in/brandonjwatson)
