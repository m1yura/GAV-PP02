-- =============================================
-- БАЗА ДАННЫХ: TireServiceDB
-- Шиномонтажный сервис ООО "Автошип Сервис"
-- =============================================

CREATE DATABASE TireServiceDB;
GO

USE TireServiceDB;
GO

-- 1. Справочник ролей сотрудников
CREATE TABLE Roles (
    RoleID INT PRIMARY KEY IDENTITY(1,1),
    RoleName NVARCHAR(50) NOT NULL UNIQUE -- 'Администратор', 'Мастер', 'Кладовщик'
);
GO

-- 2. Сотрудники
CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY IDENTITY(1,1),
    FullName NVARCHAR(100) NOT NULL,
    Username NVARCHAR(50) UNIQUE,
    RoleID INT FOREIGN KEY REFERENCES Roles(RoleID),
    Phone NVARCHAR(20),
    HireDate DATE DEFAULT GETDATE(),
    IsActive BIT DEFAULT 1,
    SalaryRate DECIMAL(10,2), -- % от выработки или ставка
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- 3. Клиенты
CREATE TABLE Clients (
    ClientID INT PRIMARY KEY IDENTITY(1,1),
    FullName NVARCHAR(100),
    Phone NVARCHAR(20) NOT NULL UNIQUE,
    Email NVARCHAR(100),
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- 4. Автомобили
CREATE TABLE Cars (
    CarID INT PRIMARY KEY IDENTITY(1,1),
    ClientID INT FOREIGN KEY REFERENCES Clients(ClientID),
    PlateNumber NVARCHAR(15) NOT NULL UNIQUE,
    Brand NVARCHAR(50),
    Model NVARCHAR(50),
    Year INT,
    VIN NVARCHAR(17),
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- 5. Статусы заказов
CREATE TABLE OrderStatuses (
    StatusID INT PRIMARY KEY IDENTITY(1,1),
    StatusName NVARCHAR(50) UNIQUE -- 'Принят', 'В работе', 'Готов', 'Выдан', 'Отменен'
);
GO

-- 6. Заказы (наряд-заказы)
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY IDENTITY(1,1),
    OrderNumber NVARCHAR(20) UNIQUE, -- НР-2026-0001
    ClientID INT FOREIGN KEY REFERENCES Clients(ClientID),
    CarID INT FOREIGN KEY REFERENCES Cars(CarID),
    EmployeeID INT FOREIGN KEY REFERENCES Employees(EmployeeID), -- Мастер
    StatusID INT FOREIGN KEY REFERENCES OrderStatuses(StatusID),
    CreatedAt DATETIME DEFAULT GETDATE(),
    CompletedAt DATETIME NULL,
    TotalAmount DECIMAL(10,2) DEFAULT 0,
    IsPaid BIT DEFAULT 0,
    PaymentMethod NVARCHAR(50), -- 'Наличные', 'Карта', 'Перевод'
    Notes NVARCHAR(500)
);
GO

-- 7. Справочник услуг шиномонтажа
CREATE TABLE Services (
    ServiceID INT PRIMARY KEY IDENTITY(1,1),
    ServiceName NVARCHAR(100) NOT NULL,
    ServiceCode NVARCHAR(20) UNIQUE,
    Price DECIMAL(10,2) NOT NULL,
    NormHours DECIMAL(5,2), -- Нормо-часы для расчета ЗП
    Category NVARCHAR(50) -- 'Замена', 'Балансировка', 'Ремонт', 'Правка дисков'
);
GO

-- 8. Услуги в заказе
CREATE TABLE OrderServices (
    OrderServiceID INT PRIMARY KEY IDENTITY(1,1),
    OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
    ServiceID INT FOREIGN KEY REFERENCES Services(ServiceID),
    Quantity INT DEFAULT 1,
    Price DECIMAL(10,2), -- Фиксация цены на момент оказания
    EmployeeID INT FOREIGN KEY REFERENCES Employees(EmployeeID) -- Кто делал
);
GO

-- 9. Категории расходных материалов
CREATE TABLE ProductCategories (
    CategoryID INT PRIMARY KEY IDENTITY(1,1),
    CategoryName NVARCHAR(50) UNIQUE -- 'Грузики', 'Вентили', 'Ремкомплекты', 'Химия'
);
GO

-- 10. Расходные материалы (склад)
CREATE TABLE Products (
    ProductID INT PRIMARY KEY IDENTITY(1,1),
    ProductName NVARCHAR(100) NOT NULL,
    CategoryID INT FOREIGN KEY REFERENCES ProductCategories(CategoryID),
    Unit NVARCHAR(20), -- 'шт', 'г', 'кг', 'уп'
    StockBalance DECIMAL(10,2) DEFAULT 0, -- Текущий остаток
    CriticalNorm DECIMAL(10,2) DEFAULT 5, -- Минимальный остаток для заказа
    PurchasePrice DECIMAL(10,2), -- Закупочная цена
    SellingPrice DECIMAL(10,2), -- Цена продажи клиенту
    Supplier NVARCHAR(100),
    Location NVARCHAR(50) -- Место на складе (стеллаж/ячейка)
);
GO

-- 11. Списание расходных материалов в заказ
CREATE TABLE WriteOffs (
    WriteOffID INT PRIMARY KEY IDENTITY(1,1),
    OrderID INT FOREIGN KEY REFERENCES Orders(OrderID),
    ProductID INT FOREIGN KEY REFERENCES Products(ProductID),
    Quantity DECIMAL(10,2) NOT NULL,
    WriteOffDate DATETIME DEFAULT GETDATE(),
    EmployeeID INT FOREIGN KEY REFERENCES Employees(EmployeeID) -- Кто списал
);
GO

-- 12. Сезонное хранение шин
CREATE TABLE TireStorage (
    StorageID INT PRIMARY KEY IDENTITY(1,1),
    ClientID INT FOREIGN KEY REFERENCES Clients(ClientID),
    CarID INT FOREIGN KEY REFERENCES Cars(CarID),
    ReceivedDate DATETIME DEFAULT GETDATE(),
    TireCount INT NOT NULL, -- 4 или 5 колес
    MarkingCode NVARCHAR(100) UNIQUE, -- QR-код/штрих-код
    PhotoPath NVARCHAR(500), -- Путь к фото состояния шин
    CellNumber NVARCHAR(20), -- Номер ячейки на стеллаже
    MonthlyFee DECIMAL(10,2) DEFAULT 500, -- Плата за хранение в месяц
    LastPaymentDate DATE,
    Status NVARCHAR(20) DEFAULT 'Хранится', -- 'Хранится', 'Выдана', 'Просрочена'
    IssuedDate DATETIME NULL,
    Notes NVARCHAR(500)
);
GO

-- 13. Платежи за хранение
CREATE TABLE StoragePayments (
    PaymentID INT PRIMARY KEY IDENTITY(1,1),
    StorageID INT FOREIGN KEY REFERENCES TireStorage(StorageID),
    Amount DECIMAL(10,2) NOT NULL,
    PaymentDate DATETIME DEFAULT GETDATE(),
    PaymentMethod NVARCHAR(50),
    EmployeeID INT FOREIGN KEY REFERENCES Employees(EmployeeID)
);
GO

-- 14. Посты/Оборудование
CREATE TABLE Workstations (
    WorkstationID INT PRIMARY KEY IDENTITY(1,1),
    WorkstationName NVARCHAR(50) UNIQUE, -- 'Пост 1', 'Балансировка', 'Правка'
    IPAddress NVARCHAR(15),
    IsActive BIT DEFAULT 1,
    LastPingTime DATETIME NULL
);
GO

-- 15. Журнал мониторинга постов
CREATE TABLE MonitoringLog (
    LogID INT PRIMARY KEY IDENTITY(1,1),
    WorkstationID INT FOREIGN KEY REFERENCES Workstations(WorkstationID),
    Status BIT, -- 1 - доступен, 0 - недоступен
    CheckTime DATETIME DEFAULT GETDATE(),
    ResponseTime INT -- мс
);
GO

-- ========== ИНДЕКСЫ ==========
CREATE INDEX IX_Orders_ClientID ON Orders(ClientID);
CREATE INDEX IX_Orders_CarID ON Orders(CarID);
CREATE INDEX IX_Orders_EmployeeID ON Orders(EmployeeID);
CREATE INDEX IX_Orders_StatusID ON Orders(StatusID);
CREATE INDEX IX_Cars_PlateNumber ON Cars(PlateNumber);
CREATE INDEX IX_TireStorage_ClientID ON TireStorage(ClientID);
CREATE INDEX IX_TireStorage_MarkingCode ON TireStorage(MarkingCode);
CREATE INDEX IX_WriteOffs_OrderID ON WriteOffs(OrderID);
CREATE INDEX IX_WriteOffs_ProductID ON WriteOffs(ProductID);
GO