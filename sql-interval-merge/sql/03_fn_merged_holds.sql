/*
    03_fn_merged_holds.sql
    dbo.fn_MergedHolds(@AsOfDate): one row per merged hold period ("island") per ticket.

    The problem: holds overlap. A ticket can wait on parts AND on the customer
    at the same time. Summing hold durations counts those days twice and makes
    the ticket look like it spent less time in progress than it did.

    The fix is a gaps-and-islands merge:
      1. Clean up:  drop bad rows (end before start), treat a NULL end as
                    "still on hold through @AsOfDate", clip each hold to the
                    ticket's open window.
      2. Order:     sort each ticket's holds by start date.
      3. Compare:   for each hold, find the furthest end date of all EARLIER holds
                    (running MAX, not LAG: a long early hold must keep covering
                    later short ones, which LAG would miss).
      4. Flag:      a hold starts a new island if it begins more than one day after
                    that furthest end. Overlapping and touching holds merge.
      5. Number:    a running SUM of the flags gives every hold its island number.
      6. Collapse:  GROUP BY island.

    Dates are inclusive: a hold from Mar 3 to Mar 5 is 3 days.
    Rows excluded as bad data are listed by 06_data_quality.sql.

    SQL Server 2012+ (window frames on aggregates). No STRING_AGG, TRIM, etc.
*/

IF OBJECT_ID('dbo.fn_MergedHolds', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_MergedHolds;
GO

CREATE FUNCTION dbo.fn_MergedHolds (@AsOfDate date)
RETURNS TABLE
AS
RETURN
WITH Clipped AS (                                   -- step 1
    SELECT
        h.TicketID,
        h.HoldID,
        CASE WHEN h.StartDate > t.OpenDate THEN h.StartDate ELSE t.OpenDate END AS StartDate,
        CASE WHEN COALESCE(h.EndDate, @AsOfDate) < COALESCE(t.CloseDate, @AsOfDate)
             THEN COALESCE(h.EndDate, @AsOfDate)
             ELSE COALESCE(t.CloseDate, @AsOfDate)
        END AS EndDate
    FROM dbo.TicketHold AS h
    JOIN dbo.Ticket     AS t ON t.TicketID = h.TicketID
    WHERE h.EndDate IS NULL OR h.EndDate >= h.StartDate
),
Kept AS (                                           -- anything left after clipping?
    SELECT TicketID, HoldID, StartDate, EndDate
    FROM Clipped
    WHERE StartDate <= EndDate
),
Compared AS (                                       -- steps 2-3
    SELECT
        TicketID, HoldID, StartDate, EndDate,
        MAX(EndDate) OVER (
            PARTITION BY TicketID
            ORDER BY StartDate, EndDate, HoldID
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS PrevMaxEnd
    FROM Kept
),
Flagged AS (                                        -- step 4
    SELECT
        TicketID, HoldID, StartDate, EndDate,
        CASE WHEN PrevMaxEnd IS NULL OR StartDate > DATEADD(day, 1, PrevMaxEnd)
             THEN 1 ELSE 0
        END AS IsNewIsland
    FROM Compared
),
Numbered AS (                                       -- step 5
    SELECT
        TicketID, StartDate, EndDate,
        SUM(IsNewIsland) OVER (
            PARTITION BY TicketID
            ORDER BY StartDate, EndDate, HoldID
            ROWS UNBOUNDED PRECEDING
        ) AS IslandNo
    FROM Flagged
)
SELECT                                              -- step 6
    TicketID,
    IslandNo,
    MIN(StartDate)                                  AS HoldStart,
    MAX(EndDate)                                    AS HoldEnd,
    DATEDIFF(day, MIN(StartDate), MAX(EndDate)) + 1 AS HoldDays,
    COUNT(*)                                        AS SourceHolds
FROM Numbered
GROUP BY TicketID, IslandNo;
GO
