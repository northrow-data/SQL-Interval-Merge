/*
    02_sample_data.sql
    A small, made-up data set with the kinds of mess real hold data has:
    overlapping holds of different types, open holds, a bad row, and one
    ticket that runs past the end of the business calendar.
*/

SET NOCOUNT ON;

DELETE dbo.TicketHold;
DELETE dbo.Ticket;

INSERT dbo.Ticket (TicketID, OpenDate, CloseDate) VALUES
    (101, '2025-02-03', '2025-02-28'),   -- clean: one hold
    (102, '2025-03-03', '2025-04-11'),   -- parts + customer holds overlap
    (103, '2025-04-07', '2025-05-30'),   -- one long hold with short holds inside it
    (104, '2025-06-02', '2025-06-27'),   -- no holds at all
    (105, '2025-07-01', '2025-08-15'),   -- holds touch end-to-start
    (106, '2025-09-02', '2025-10-17'),   -- contains a bad row (end before start)
    (107, '2025-10-06', NULL),           -- still open, still on hold
    (108, '2025-12-08', '2026-01-09');   -- closes after the calendar ends

INSERT dbo.TicketHold (TicketID, HoldType, StartDate, EndDate) VALUES
    (101, 'Customer', '2025-02-10', '2025-02-14'),

    (102, 'Parts',    '2025-03-10', '2025-03-21'),
    (102, 'Customer', '2025-03-17', '2025-03-26'),
    (102, 'Approval', '2025-04-01', '2025-04-02'),

    (103, 'Parts',    '2025-04-14', '2025-05-16'),
    (103, 'Customer', '2025-04-21', '2025-04-23'),
    (103, 'Approval', '2025-05-05', '2025-05-07'),

    (105, 'Parts',    '2025-07-07', '2025-07-11'),
    (105, 'Parts',    '2025-07-12', '2025-07-18'),

    (106, 'Customer', '2025-09-15', '2025-09-19'),
    (106, 'Parts',    '2025-10-03', '2025-09-29'),   -- bad row: ends before it starts

    (107, 'Parts',    '2025-11-03', NULL),

    (108, 'Customer', '2025-12-15', '2025-12-19');
