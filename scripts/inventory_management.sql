USE TireServiceDB;
GO

-- =============================================
-- ПРОЦЕДУРА: Списание материалов в заказ
-- =============================================
CREATE OR ALTER PROCEDURE sp_WriteOffMaterials
    @OrderID INT,
    @ProductID INT,
    @Quantity DECIMAL(10,2),
    @EmployeeID INT
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Проверка остатка
        DECLARE @CurrentStock DECIMAL(10,2);
        SELECT @CurrentStock = StockBalance FROM Products WHERE ProductID = @ProductID;

        IF @CurrentStock < @Quantity
            THROW 50000, 'Недостаточно материалов на складе', 1;

        -- Списание
        INSERT INTO WriteOffs (OrderID, ProductID, Quantity, EmployeeID)
        VALUES (@OrderID, @ProductID, @Quantity, @EmployeeID);

        -- Уменьшение остатка
        UPDATE Products
        SET StockBalance = StockBalance - @Quantity
        WHERE ProductID = @ProductID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Поступление товаров на склад
-- =============================================
CREATE OR ALTER PROCEDURE sp_ReceiveProducts
    @ProductID INT,
    @Quantity DECIMAL(10,2),
    @PurchasePrice DECIMAL(10,2) = NULL
AS
BEGIN
    UPDATE Products
    SET StockBalance = StockBalance + @Quantity,
        PurchasePrice = ISNULL(@PurchasePrice, PurchasePrice)
    WHERE ProductID = @ProductID;

    PRINT '✅ Товар оприходован';
END;
GO

-- =============================================
-- ПРОЦЕДУРА: Инвентаризация склада
-- =============================================
CREATE OR ALTER PROCEDURE sp_InventoryCheck
    @ExpectedDiscrepancyThreshold DECIMAL(10,2) = 0.01 -- 1% погрешности
AS
BEGIN
    -- Временная таблица для результатов инвентаризации
    CREATE TABLE #InventoryResult (
        ProductID INT,
        ProductName NVARCHAR(100),
        ExpectedBalance DECIMAL(10,2),
        ActualBalance DECIMAL(10,2),
        Discrepancy DECIMAL(10,2),
        DiscrepancyPercent DECIMAL(5,2),
        Status NVARCHAR(20)
    );

    -- Здесь должна быть вставка фактических данных сканирования
    -- Для примера берем текущие остатки
    INSERT INTO #InventoryResult
    SELECT
        ProductID,
        ProductName,
        StockBalance AS ExpectedBalance,
        StockBalance AS ActualBalance, -- В реальности - из сканера
        0 AS Discrepancy,
        0 AS DiscrepancyPercent,
        'OK'
    FROM Products;

    -- Отбор расхождений
    UPDATE #InventoryResult
    SET Status = 'DISCREPANCY'
    WHERE ABS(DiscrepancyPercent) > @ExpectedDiscrepancyThreshold * 100;

    SELECT * FROM #InventoryResult ORDER BY Status DESC, DiscrepancyPercent DESC;

    DROP TABLE #InventoryResult;
END;
GO