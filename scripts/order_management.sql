USE TireServiceDB;
GO

-- =============================================
-- ПРОЦЕДУРА: Создание нового заказа
-- =============================================
CREATE OR ALTER PROCEDURE sp_CreateOrder
    @ClientPhone NVARCHAR(20),
    @PlateNumber NVARCHAR(15),
    @EmployeeID INT,
    @Notes NVARCHAR(500) = NULL
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Получаем или создаем клиента
        DECLARE @ClientID INT;
        SELECT @ClientID = ClientID FROM Clients WHERE Phone = @ClientPhone;

        IF @ClientID IS NULL
        BEGIN
            INSERT INTO Clients (Phone) VALUES (@ClientPhone);
            SET @ClientID = SCOPE_IDENTITY();
        END

        -- Получаем или создаем авто
        DECLARE @CarID INT;
        SELECT @CarID = CarID FROM Cars WHERE PlateNumber = @PlateNumber;

        IF @CarID IS NULL
        BEGIN
            INSERT INTO Cars (ClientID, PlateNumber) VALUES (@ClientID, @PlateNumber);
            SET @CarID = SCOPE_IDENTITY();
        END

        -- Генерируем номер заказа
        DECLARE @OrderNumber NVARCHAR(20);
        SET @OrderNumber = 'НР-' + FORMAT(GETDATE(), 'yyyyMMdd') + '-' +
                          RIGHT('0000' + CAST(NEXT VALUE FOR Seq_OrderNumber AS NVARCHAR), 4);

        -- Создаем заказ
        INSERT INTO Orders (OrderNumber, ClientID, CarID, EmployeeID, StatusID, Notes)
        VALUES (@OrderNumber, @ClientID, @CarID, @EmployeeID, 1, @Notes); -- Статус 1 = 'Принят'

        SELECT @OrderNumber AS OrderNumber, SCOPE_IDENTITY() AS OrderID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Добавление услуги в заказ
-- =============================================
CREATE OR ALTER PROCEDURE sp_AddServiceToOrder
    @OrderID INT,
    @ServiceID INT,
    @Quantity INT = 1,
    @EmployeeID INT
AS
BEGIN
    DECLARE @ServicePrice DECIMAL(10,2);
    SELECT @ServicePrice = Price FROM Services WHERE ServiceID = @ServiceID;

    INSERT INTO OrderServices (OrderID, ServiceID, Quantity, Price, EmployeeID)
    VALUES (@OrderID, @ServiceID, @Quantity, @ServicePrice, @EmployeeID);

    -- Пересчет общей суммы заказа
    UPDATE Orders
    SET TotalAmount = (
        SELECT SUM(Price * Quantity)
        FROM OrderServices
        WHERE OrderID = @OrderID
    )
    WHERE OrderID = @OrderID;
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Смена статуса заказа
-- =============================================
CREATE OR ALTER PROCEDURE sp_UpdateOrderStatus
    @OrderID INT,
    @StatusName NVARCHAR(50)
AS
BEGIN
    DECLARE @StatusID INT;
    SELECT @StatusID = StatusID FROM OrderStatuses WHERE StatusName = @StatusName;

    UPDATE Orders
    SET StatusID = @StatusID,
        CompletedAt = CASE WHEN @StatusName = 'Выдан' THEN GETDATE() ELSE CompletedAt END
    WHERE OrderID = @OrderID;
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Получение текущей очереди
-- =============================================
CREATE OR ALTER VIEW v_CurrentQueue AS
SELECT
    o.OrderID,
    o.OrderNumber,
    c.Phone AS ClientPhone,
    car.PlateNumber,
    car.Brand + ' ' + car.Model AS CarName,
    os.StatusName AS Status,
    o.CreatedAt,
    DATEDIFF(minute, o.CreatedAt, GETDATE()) AS WaitTimeMinutes,
    e.FullName AS MasterName,
    o.TotalAmount
FROM Orders o
JOIN Clients c ON o.ClientID = c.ClientID
JOIN Cars car ON o.CarID = car.CarID
JOIN OrderStatuses os ON o.StatusID = os.StatusID
LEFT JOIN Employees e ON o.EmployeeID = e.EmployeeID
WHERE o.StatusID IN (1, 2) -- Принят, В работе
ORDER BY
    CASE WHEN o.StatusID = 2 THEN 1 ELSE 2 END, -- Сначала "в работе"
    o.CreatedAt ASC;
GO