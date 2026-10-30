/*
    04_cycle_time.sql
    Business-day cycle time per ticket, net of merged hold time.

        CycleBizDays      business days from OpenDate to CloseDate (or @AsOfDate), inclusive
        NaiveHoldBizDays  plain SUM over raw hold rows: overlaps double-counted (shown for contrast)
        HoldBizDays       business days inside merged hold islands (never double-counted)
        NetBizDays    CycleBizDays - HoldBizDays

    Guard against a silent wrong answer:
    Counting business days by joining to a calendar table quietly returns 0 (or
    too few) for any date the calendar does not cover. A 0 looks like a real
    result and flows straight into averages. So if a ticket's dates fall outside
    the calendar's range, this query returns NULL with a note instead.
    NULL is honest: "we can't compute this yet." 0 is a lie.
*/

SET NOCOUNT ON;

DECLARE @AsOfDate date = '2025-12-31';
DECLARE @CalStart date, @CalEnd date;

SELECT @CalStart = MIN(CalendarDate), @CalEnd = MAX(CalendarDate)
FROM dbo.BusinessCalendar;

WITH Tickets AS (
    SELECT
        TicketID,
        OpenDate,
        COALESCE(CloseDate, @AsOfDate)               AS EndDate,
        CASE WHEN CloseDate IS NULL THEN 1 ELSE 0 END AS IsOpen
    FROM dbo.Ticket
),
Cycle AS (
    SELECT t.TicketID, SUM(CAST(c.IsBusinessDay AS int)) AS CycleBizDays
    FROM Tickets AS t
    JOIN dbo.BusinessCalendar AS c
        ON c.CalendarDate BETWEEN t.OpenDate AND t.EndDate
    GROUP BY t.TicketID
),
Holds AS (
    SELECT m.TicketID, SUM(CAST(c.IsBusinessDay AS int)) AS HoldBizDays
    FROM dbo.fn_MergedHolds(@AsOfDate) AS m
    JOIN dbo.BusinessCalendar AS c
        ON c.CalendarDate BETWEEN m.HoldStart AND m.HoldEnd
    GROUP BY m.TicketID
),
Naive AS (                       -- what a plain SUM of raw holds would report
    SELECT h.TicketID, SUM(CAST(c.IsBusinessDay AS int)) AS NaiveHoldBizDays
    FROM dbo.TicketHold AS h
    JOIN dbo.BusinessCalendar AS c
        ON c.CalendarDate BETWEEN h.StartDate AND COALESCE(h.EndDate, @AsOfDate)
    GROUP BY h.TicketID
)
SELECT
    t.TicketID,
    t.OpenDate,
    t.EndDate,
    t.IsOpen,
    CASE WHEN g.OutOfRange = 1 THEN NULL ELSE COALESCE(cy.CycleBizDays, 0) END  AS CycleBizDays,
    CASE WHEN g.OutOfRange = 1 THEN NULL ELSE COALESCE(n.NaiveHoldBizDays, 0) END AS NaiveHoldBizDays,
    CASE WHEN g.OutOfRange = 1 THEN NULL ELSE COALESCE(h.HoldBizDays, 0) END    AS HoldBizDays,
    CASE WHEN g.OutOfRange = 1 THEN NULL
         ELSE COALESCE(cy.CycleBizDays, 0) - COALESCE(h.HoldBizDays, 0) END     AS NetBizDays,
    CASE WHEN g.OutOfRange = 1
         THEN 'Dates outside BusinessCalendar range; extend the calendar' END   AS Note
FROM Tickets AS t
CROSS APPLY (
    SELECT CASE WHEN t.OpenDate < @CalStart OR t.EndDate > @CalEnd THEN 1 ELSE 0 END AS OutOfRange
) AS g
LEFT JOIN Cycle AS cy ON cy.TicketID = t.TicketID
LEFT JOIN Holds AS h  ON h.TicketID  = t.TicketID
LEFT JOIN Naive AS n  ON n.TicketID  = t.TicketID
ORDER BY t.TicketID;
