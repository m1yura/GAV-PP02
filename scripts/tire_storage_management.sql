USE TireServiceDB;
GO

-- =============================================
-- ПРОЦЕДУРА: Прием шин на хранение
-- =============================================
CREATE OR ALTER PROCEDURE sp_ReceiveTires
    @ClientPhone NVARCHAR(20),
    @PlateNumber NVARCHAR(15),
    @TireCount INT,
    @CellNumber NVARCHAR(20),
    @PhotoPath NVARCHAR(500) = NULL
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

        -- Генерируем уникальный QR-код
        DECLARE @MarkingCode NVARCHAR(100);
        SET @MarkingCode = 'TS-' + CONVERT(NVARCHAR, @ClientID) + '-' +
                          CONVERT(NVARCHAR, @CarID) + '-' +
                          FORMAT(GETDATE(), 'yyyyMMddHHmmss');

        -- Создаем запись хранения
        INSERT INTO TireStorage (
            ClientID, CarID, TireCount, MarkingCode,
            PhotoPath, CellNumber, MonthlyFee, LastPaymentDate, Status
        ) VALUES (
            @ClientID, @CarID, @TireCount, @MarkingCode,
            @PhotoPath, @CellNumber, 500, GETDATE(), 'Хранится'
        );

        COMMIT TRANSACTION;
        SELECT @MarkingCode AS QRCode;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Выдача шин со склада
-- =============================================
CREATE OR ALTER PROCEDURE sp_IssueTires
    @MarkingCode NVARCHAR(100)
AS
BEGIN
    UPDATE TireStorage
    SET Status = 'Выдана',
        IssuedDate = GETDATE()
    WHERE MarkingCode = @MarkingCode AND Status = 'Хранится';

    IF @@ROWCOUNT = 0
        THROW 50000, 'Шины не найдены или уже выданы', 1;
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Оплата хранения
-- =============================================
CREATE OR ALTER PROCEDURE sp_PayStorage
    @StorageID INT,
    @Amount DECIMAL(10,2),
    @PaymentMethod NVARCHAR(50),
    @EmployeeID INT
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Фиксируем платеж
        INSERT INTO StoragePayments (StorageID, Amount, PaymentMethod, EmployeeID)
        VALUES (@StorageID, @Amount, @PaymentMethod, @EmployeeID);

        -- Обновляем дату последнего платежа
        UPDATE TireStorage
        SET LastPaymentDate = GETDATE()
        WHERE StorageID = @StorageID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO