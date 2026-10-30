/*
    06_data_quality.sql
    Checks to run before trusting any hold-time number.

    In a clean demo database these mostly return nothing, because the foreign
    key is enforced. In real legacy databases, keys are often declared loosely
    or not at all, so every join gets proven before it is trusted.
*/

SET NOCOUNT ON;

-- 1. Bad rows: hold ends before it starts. fn_MergedHolds excludes these;
--    this lists them so someone can fix them at the source.
SELECT 'End before start' AS Issue, h.*
FROM dbo.TicketHold AS h
WHERE h.EndDate < h.StartDate;

-- 2. Orphans: holds pointing at a ticket that does not exist.
SELECT 'Orphan hold' AS Issue, h.*
FROM dbo.TicketHold AS h
WHERE NOT EXISTS (SELECT 1 FROM dbo.Ticket AS t WHERE t.TicketID = h.TicketID);

-- 3. Fan-out check: does joining holds to tickets change the row count?
--    If the "one" side of a one-to-many join is not unique, totals inflate silently.
SELECT
    (SELECT COUNT(*) FROM dbo.TicketHold)                         AS HoldRows,
    (SELECT COUNT(*) FROM dbo.TicketHold AS h
         JOIN dbo.Ticket AS t ON t.TicketID = h.TicketID)        AS JoinedRows;

-- 4. Holds entirely outside their ticket's open window (excluded by clipping).
SELECT 'Outside ticket window' AS Issue, h.*, t.OpenDate, t.CloseDate
FROM dbo.TicketHold AS h
JOIN dbo.Ticket     AS t ON t.TicketID = h.TicketID
WHERE h.EndDate < t.OpenDate
   OR (t.CloseDate IS NOT NULL AND h.StartDate > t.CloseDate);

-- 5. Exact duplicate holds (harmless to the merge, but worth knowing about).
SELECT 'Duplicate hold' AS Issue, TicketID, HoldType, StartDate, EndDate, COUNT(*) AS Copies
FROM dbo.TicketHold
GROUP BY TicketID, HoldType, StartDate, EndDate
HAVING COUNT(*) > 1;

-- 6. Still-open holds, oldest first.
SELECT 'Open hold' AS Issue, h.*, DATEDIFF(day, h.StartDate, GETDATE()) AS DaysOpen
FROM dbo.TicketHold AS h
WHERE h.EndDate IS NULL
ORDER BY h.StartDate;
