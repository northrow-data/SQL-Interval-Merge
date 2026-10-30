/*
    01_schema.sql
    Demo tables for the hold-merge example. Runs on SQL Server 2012 and later.

    Ticket            one row per ticket (a support case, a work order, a claim...)
    TicketHold        periods when the ticket was paused (waiting on parts, customer, approval)
    BusinessCalendar  one row per date, flagging business days (weekends + holidays off)
*/

SET NOCOUNT ON;

IF OBJECT_ID('dbo.TicketHold', 'U') IS NOT NULL DROP TABLE dbo.TicketHold;
IF OBJECT_ID('dbo.Ticket', 'U') IS NOT NULL DROP TABLE dbo.Ticket;
IF OBJECT_ID('dbo.BusinessCalendar', 'U') IS NOT NULL DROP TABLE dbo.BusinessCalendar;

CREATE TABLE dbo.Ticket (
    TicketID   int  NOT NULL PRIMARY KEY,
    OpenDate   date NOT NULL,
    CloseDate  date NULL                      -- NULL = still open
);

CREATE TABLE dbo.TicketHold (
    HoldID     int IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    TicketID   int         NOT NULL REFERENCES dbo.Ticket (TicketID),
    HoldType   varchar(30) NOT NULL,
    StartDate  date        NOT NULL,
    EndDate    date        NULL               -- NULL = still on hold
);

CREATE INDEX IX_TicketHold_Ticket_Start
    ON dbo.TicketHold (TicketID, StartDate, EndDate);

CREATE TABLE dbo.BusinessCalendar (
    CalendarDate   date NOT NULL PRIMARY KEY,
    IsBusinessDay  bit  NOT NULL
);

/*
    Calendar covers 2025 only, on purpose: 04_cycle_time.sql shows what happens
    when a ticket falls outside the calendar's range.

    Weekend test uses day number since 1900-01-01 (a Monday), so it does not
    depend on the server's DATEFIRST or language settings.
*/
WITH Days AS (
    SELECT CAST('2025-01-01' AS date) AS CalendarDate
    UNION ALL
    SELECT DATEADD(day, 1, CalendarDate) FROM Days WHERE CalendarDate < '2025-12-31'
)
INSERT dbo.BusinessCalendar (CalendarDate, IsBusinessDay)
SELECT
    CalendarDate,
    CASE
        WHEN DATEDIFF(day, '19000101', CalendarDate) % 7 IN (5, 6) THEN 0          -- Sat, Sun
        WHEN CalendarDate IN ('2025-01-01', '2025-05-26', '2025-07-04',
                              '2025-09-01', '2025-11-27', '2025-12-25') THEN 0     -- holidays
        ELSE 1
    END
FROM Days
OPTION (MAXRECURSION 400);
