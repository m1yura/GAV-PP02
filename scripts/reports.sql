USE TireServiceDB;
GO

-- =============================================
-- ОТЧЕТ 1: Выручка за период с группировкой по услугам
-- =============================================
CREATE OR ALTER VIEW v_RevenueByService AS
SELECT
    s.ServiceName,
    s.Category,
    COUNT(os.OrderServiceID) AS ServiceCount,
    SUM(os.Price * os.Quantity) AS TotalRevenue,
    AVG(os.Price) AS AvgPrice
FROM OrderServices os
JOIN Services s ON os.ServiceID = s.ServiceID
JOIN Orders o ON os.OrderID = o.OrderID
WHERE o.IsPaid = 1
GROUP BY s.ServiceName, s.Category;
GO

-- =============================================
-- ОТЧЕТ 2: Загрузка мастеров (КТУ - коэффициент трудового участия)
-- =============================================
CREATE OR ALTER VIEW v_MasterPerformance AS
SELECT
    e.EmployeeID,
    e.FullName AS MasterName,
    COUNT(DISTINCT o.OrderID) AS OrdersCompleted,
    SUM(s.NormHours) AS TotalNormHours,
    SUM(os.Price * os.Quantity) AS TotalWorkAmount,
    SUM(os.Price * os.Quantity) * (e.SalaryRate / 100) AS SalaryAccrued
FROM Employees e
JOIN Orders o ON e.EmployeeID = o.EmployeeID
JOIN OrderServices os ON o.OrderID = os.OrderID
JOIN Services s ON os.ServiceID = s.ServiceID
WHERE o.StatusID = 4 -- Статус "Выдан"
  AND o.CompletedAt >= DATEADD(month, -1, GETDATE())
GROUP BY e.EmployeeID, e.FullName, e.SalaryRate;
GO

-- =============================================
-- ОТЧЕТ 3: Склад - остатки ниже нормы (пора закупать)
-- =============================================
CREATE OR ALTER VIEW v_NeedPurchase AS
SELECT
    ProductName,
    CategoryName,
    StockBalance,
    CriticalNorm,
    PurchasePrice,
    Supplier,
    Location
FROM Products p
JOIN ProductCategories pc ON p.CategoryID = pc.CategoryID
WHERE StockBalance <= CriticalNorm
  AND StockBalance > 0
ORDER BY (StockBalance - CriticalNorm) ASC;
GO

-- =============================================
-- ОТЧЕТ 4: Шины на хранении (просрочка оплаты)
-- =============================================
CREATE OR ALTER VIEW v_OverdueStorage AS
SELECT
    ts.StorageID,
    c.FullName AS ClientName,
    c.Phone,
    ts.TireCount,
    ts.CellNumber,
    ts.MarkingCode,
    ts.MonthlyFee,
    DATEDIFF(day, ts.LastPaymentDate, GETDATE()) AS DaysOverdue,
    DATEDIFF(month, ts.LastPaymentDate, GETDATE()) * ts.MonthlyFee AS DebtAmount
FROM TireStorage ts
JOIN Clients c ON ts.ClientID = c.ClientID
WHERE ts.Status = 'Хранится'
  AND (ts.LastPaymentDate < DATEADD(month, -1, GETDATE()) OR ts.LastPaymentDate IS NULL);
GO

-- =============================================
-- ОТЧЕТ 5: Итоги дня (кассовый отчет)
-- =============================================
CREATE OR ALTER PROCEDURE sp_DailyReport
    @ReportDate DATE = NULL
AS
BEGIN
    IF @ReportDate IS NULL
        SET @ReportDate = CAST(GETDATE() AS DATE);

    SELECT
        COUNT(DISTINCT o.OrderID) AS OrdersCount,
        COUNT(DISTINCT o.ClientID) AS ClientsCount,
        SUM(o.TotalAmount) AS TotalRevenue,
        SUM(CASE WHEN o.PaymentMethod = 'Наличные' THEN o.TotalAmount ELSE 0 END) AS CashRevenue,
        SUM(CASE WHEN o.PaymentMethod = 'Карта' THEN o.TotalAmount ELSE 0 END) AS CardRevenue,
        AVG(o.TotalAmount) AS AverageCheck
    FROM Orders o
    WHERE CAST(o.CreatedAt AS DATE) = @ReportDate
      AND o.StatusID = 4; -- Выдан
END;
GO