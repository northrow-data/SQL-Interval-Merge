/*
    05_test_harness.sql
    15 edge-case scenarios for dbo.fn_MergedHolds, with PASS/FAIL output.

    Runs inside a transaction and rolls back at the end, so it never leaves
    test rows behind. Safe to run as often as you like.

    The same scenarios live in python/scenarios.py, so the SQL and the Python
    reference implementation are checked against identical cases.
*/

SET NOCOUNT ON;
BEGIN TRANSACTION;

DECLARE @AsOfDate date = '2025-03-31';

INSERT dbo.Ticket (TicketID, OpenDate, CloseDate) VALUES
    (9001, '2025-03-01', '2025-03-31'),
    (9002, '2025-03-01', '2025-03-31'),
    (9003, '2025-03-01', '2025-03-31'),
    (9004, '2025-03-01', '2025-03-31'),
    (9005, '2025-03-01', '2025-03-31'),
    (9006, '2025-03-01', '2025-03-31'),
    (9007, '2025-03-01', '2025-03-31'),
    (9008, '2025-03-01', '2025-03-31'),
    (9009, '2025-03-01', '2025-03-31'),
    (9010, '2025-03-01', '2025-03-31'),
    (9011, '2025-03-01', '2025-03-31'),
    (9012, '2025-03-01', NULL),
    (9013, '2025-03-10', '2025-03-31'),
    (9014, '2025-03-01', '2025-03-20'),
    (9015, '2025-03-01', '2025-03-15');

INSERT dbo.TicketHold (TicketID, HoldType, StartDate, EndDate) VALUES
    (9002, 'Test', '2025-03-03', '2025-03-05'),
    (9003, 'Test', '2025-03-03', '2025-03-05'),
    (9003, 'Test', '2025-03-10', '2025-03-11'),
    (9004, 'Test', '2025-03-03', '2025-03-07'),
    (9004, 'Test', '2025-03-05', '2025-03-10'),
    (9005, 'Test', '2025-03-03', '2025-03-12'),
    (9005, 'Test', '2025-03-05', '2025-03-07'),
    (9006, 'Test', '2025-03-03', '2025-03-05'),
    (9006, 'Test', '2025-03-06', '2025-03-08'),
    (9007, 'Test', '2025-03-03', '2025-03-05'),
    (9007, 'Test', '2025-03-03', '2025-03-05'),
    (9008, 'Test', '2025-03-10', '2025-03-05'),
    (9008, 'Test', '2025-03-03', '2025-03-04'),
    (9009, 'Test', '2025-03-01', '2025-03-04'),
    (9009, 'Test', '2025-03-04', '2025-03-08'),
    (9009, 'Test', '2025-03-08', '2025-03-12'),
    (9010, 'Test', '2025-03-01', '2025-03-20'),
    (9010, 'Test', '2025-03-05', '2025-03-06'),
    (9010, 'Test', '2025-03-10', '2025-03-12'),
    (9011, 'Test', '2025-03-15', '2025-03-15'),
    (9012, 'Test', '2025-03-25', NULL),
    (9013, 'Test', '2025-03-01', '2025-03-12'),
    (9014, 'Test', '2025-03-18', '2025-03-28'),
    (9015, 'Test', '2025-03-20', '2025-03-25');

DECLARE @Expected TABLE (
    TicketID    int PRIMARY KEY,
    Scenario    varchar(60),
    ExpIslands  int,
    ExpDays     int
);

INSERT @Expected (TicketID, Scenario, ExpIslands, ExpDays) VALUES
    (9001, 'No holds', 0, 0),
    (9002, 'Single hold', 1, 3),
    (9003, 'Two separate holds', 2, 5),
    (9004, 'Partial overlap', 1, 8),
    (9005, 'Nested hold', 1, 10),
    (9006, 'Adjacent holds (touching days)', 1, 6),
    (9007, 'Exact duplicate', 1, 3),
    (9008, 'Bad row (end before start) is excluded', 1, 2),
    (9009, 'Chain of overlaps', 1, 12),
    (9010, 'Long hold swallows later short holds', 1, 20),
    (9011, 'One-day hold', 1, 1),
    (9012, 'Open hold runs to as-of date', 1, 7),
    (9013, 'Hold starts before ticket opens (clipped)', 1, 3),
    (9014, 'Hold ends after ticket closes (clipped)', 1, 3),
    (9015, 'Hold entirely outside ticket window', 0, 0);

DECLARE @Results TABLE (
    ScenarioNo  int,
    Scenario    varchar(60),
    ExpIslands  int,
    ActIslands  int,
    ExpDays     int,
    ActDays     int,
    Result      char(4)
);

INSERT @Results
SELECT
    e.TicketID - 9000,
    e.Scenario,
    e.ExpIslands,
    COALESCE(a.Islands, 0),
    e.ExpDays,
    COALESCE(a.Days, 0),
    CASE WHEN e.ExpIslands = COALESCE(a.Islands, 0)
          AND e.ExpDays    = COALESCE(a.Days, 0)
         THEN 'PASS' ELSE 'FAIL' END
FROM @Expected AS e
LEFT JOIN (
    SELECT TicketID, COUNT(*) AS Islands, SUM(HoldDays) AS Days
    FROM dbo.fn_MergedHolds(@AsOfDate)
    WHERE TicketID BETWEEN 9001 AND 9015
    GROUP BY TicketID
) AS a ON a.TicketID = e.TicketID;

SELECT * FROM @Results ORDER BY ScenarioNo;

SELECT
    COUNT(*)                                          AS Scenarios,
    SUM(CASE WHEN Result = 'PASS' THEN 1 ELSE 0 END)  AS Passed,
    SUM(CASE WHEN Result = 'FAIL' THEN 1 ELSE 0 END)  AS Failed
FROM @Results;

ROLLBACK TRANSACTION;
