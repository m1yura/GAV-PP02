USE TireServiceDB;
GO

-- =============================================
-- ТАБЛИЦА: Журнал аудита действий сотрудников
-- =============================================
CREATE TABLE AuditLog (
    AuditID INT PRIMARY KEY IDENTITY(1,1),
    EmployeeID INT FOREIGN KEY REFERENCES Employees(EmployeeID),
    ActionType NVARCHAR(50), -- 'CREATE', 'UPDATE', 'DELETE', 'LOGIN'
    TableName NVARCHAR(50),
    RecordID INT,
    OldValue NVARCHAR(MAX),
    NewValue NVARCHAR(MAX),
    ActionDate DATETIME DEFAULT GETDATE(),
    IPAddress NVARCHAR(45)
);
GO

-- =============================================
-- ТРИГГЕР: Аудит изменений в заказах
-- =============================================
CREATE OR ALTER TRIGGER tr_Orders_Audit
ON Orders
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EmployeeID INT;
    SET @EmployeeID = 1; -- В реальности берется из контекста сессии

    -- Логирование INSERT
    INSERT INTO AuditLog (EmployeeID, ActionType, TableName, RecordID, NewValue)
    SELECT @EmployeeID, 'CREATE', 'Orders', i.OrderID,
           (SELECT * FROM inserted i2 WHERE i2.OrderID = i.OrderID FOR JSON AUTO)
    FROM inserted i;

    -- Логирование DELETE
    INSERT INTO AuditLog (EmployeeID, ActionType, TableName, RecordID, OldValue)
    SELECT @EmployeeID, 'DELETE', 'Orders', d.OrderID,
           (SELECT * FROM deleted d2 WHERE d2.OrderID = d.OrderID FOR JSON AUTO)
    FROM deleted d
    WHERE d.OrderID NOT IN (SELECT OrderID FROM inserted);

    -- Логирование UPDATE
    INSERT INTO AuditLog (EmployeeID, ActionType, TableName, RecordID, OldValue, NewValue)
    SELECT @EmployeeID, 'UPDATE', 'Orders', i.OrderID,
           (SELECT * FROM deleted d2 WHERE d2.OrderID = i.OrderID FOR JSON AUTO),
           (SELECT * FROM inserted i2 WHERE i2.OrderID = i.OrderID FOR JSON AUTO)
    FROM inserted i
    JOIN deleted d ON i.OrderID = d.OrderID;
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Мониторинг доступности постов
-- =============================================
CREATE OR ALTER PROCEDURE sp_CheckWorkstations
AS
BEGIN
    DECLARE @WorkstationID INT, @IP NVARCHAR(15);
    DECLARE cur CURSOR FOR
    SELECT WorkstationID, IPAddress FROM Workstations WHERE IsActive = 1;

    OPEN cur;
    FETCH NEXT FROM cur INTO @WorkstationID, @IP;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Проверка ping (в реальности - xp_cmdshell)
        DECLARE @Status BIT = 1; -- Имитация успешного пинга
        DECLARE @ResponseTime INT = 15; -- Имитация времени отклика

        -- В реальном коде используется:
        -- EXEC xp_cmdshell 'ping -n 1 ' + @IP

        INSERT INTO MonitoringLog (WorkstationID, Status, ResponseTime)
        VALUES (@WorkstationID, @Status, @ResponseTime);

        FETCH NEXT FROM cur INTO @WorkstationID, @IP;
    END

    CLOSE cur;
    DEALLOCATE cur;
END;
GO

-- =============================================
-- ПРЕДСТАВЛЕНИЕ: Статистика недоступности постов
-- =============================================
CREATE OR ALTER VIEW v_WorkstationUptime AS
SELECT
    w.WorkstationName,
    w.IPAddress,
    COUNT(*) AS TotalChecks,
    SUM(CASE WHEN ml.Status = 1 THEN 1 ELSE 0 END) AS SuccessfulChecks,
    SUM(CASE WHEN ml.Status = 0 THEN 1 ELSE 0 END) AS FailedChecks,
    CAST(SUM(CASE WHEN ml.Status = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS UptimePercent,
    AVG(ml.ResponseTime) AS AvgResponseTime
FROM Workstations w
LEFT JOIN MonitoringLog ml ON w.WorkstationID = ml.WorkstationID
WHERE ml.CheckTime >= DATEADD(day, -7, GETDATE())
GROUP BY w.WorkstationName, w.IPAddress;
GO