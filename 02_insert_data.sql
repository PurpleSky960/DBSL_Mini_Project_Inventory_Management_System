-- ============================================================
-- FILE: 02_insert_data.sql
-- PROJECT: Inventory Management System
-- DATABASE: Oracle SQL Developer
-- FIX: Use INSERT INTO...SELECT for FK lookups (Oracle requires this)
-- RUN: Press F5 (Run Script)
-- NOTE: Run 01_create_tables.sql FIRST
-- ============================================================

-- ------------------------------------------------------------
-- 1. USERS
-- ------------------------------------------------------------
INSERT INTO Users (UserID, Username, Password, Email, Role)
VALUES (seq_users.NEXTVAL, 'admin_raj',     'hashed_pass_1', 'raj@inventory.com',   'ADMIN');

INSERT INTO Users (UserID, Username, Password, Email, Role)
VALUES (seq_users.NEXTVAL, 'manager_priya', 'hashed_pass_2', 'priya@inventory.com', 'MANAGER');

INSERT INTO Users (UserID, Username, Password, Email, Role)
VALUES (seq_users.NEXTVAL, 'staff_arjun',   'hashed_pass_3', 'arjun@inventory.com', 'STAFF');

INSERT INTO Users (UserID, Username, Password, Email, Role)
VALUES (seq_users.NEXTVAL, 'staff_meera',   'hashed_pass_4', 'meera@inventory.com', 'STAFF');

-- ------------------------------------------------------------
-- 2. CATEGORY
-- ------------------------------------------------------------
INSERT INTO Category (CategoryID, Name, Description, IS_ACTIVE)
VALUES (seq_category.NEXTVAL, 'Electronics',  'Gadgets and electronic devices',   1);

INSERT INTO Category (CategoryID, Name, Description, IS_ACTIVE)
VALUES (seq_category.NEXTVAL, 'Stationery',   'Office and school supplies',       1);

INSERT INTO Category (CategoryID, Name, Description, IS_ACTIVE)
VALUES (seq_category.NEXTVAL, 'Grocery',      'Daily use food and grocery items', 1);

INSERT INTO Category (CategoryID, Name, Description, IS_ACTIVE)
VALUES (seq_category.NEXTVAL, 'Discontinued', 'Phased out product lines',         0);

-- ------------------------------------------------------------
-- 3. SUPPLIERS
-- ------------------------------------------------------------
INSERT INTO Suppliers (SupplierID, Name, Contact, Email, Address)
VALUES (seq_suppliers.NEXTVAL, 'TechSource Pvt Ltd', '9876543210',
        'techsource@mail.com', 'Bengaluru, Karnataka');

INSERT INTO Suppliers (SupplierID, Name, Contact, Email, Address)
VALUES (seq_suppliers.NEXTVAL, 'PaperWorld Co.',     '9123456780',
        'paperworld@mail.com', 'Mumbai, Maharashtra');

INSERT INTO Suppliers (SupplierID, Name, Contact, Email, Address)
VALUES (seq_suppliers.NEXTVAL, 'FreshMart Traders',  '9988776655',
        'freshmart@mail.com',  'Chennai, Tamil Nadu');

INSERT INTO Suppliers (SupplierID, Name, Contact, Email, Address)
VALUES (seq_suppliers.NEXTVAL, 'OldStock Suppliers', '9000011111',
        'oldstock@mail.com',   'Hyderabad, Telangana');

-- ------------------------------------------------------------
-- 4. PRODUCTS  (INSERT INTO...SELECT — subqueries work here)
-- ------------------------------------------------------------
INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'Wireless Mouse',
       c.CategoryID, s.SupplierID, 599.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Electronics' AND s.Name = 'TechSource Pvt Ltd';

INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'USB-C Hub',
       c.CategoryID, s.SupplierID, 1299.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Electronics' AND s.Name = 'TechSource Pvt Ltd';

INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'Bluetooth Headphones',
       c.CategoryID, s.SupplierID, 2499.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Electronics' AND s.Name = 'TechSource Pvt Ltd';

INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'A4 Notebook',
       c.CategoryID, s.SupplierID, 85.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Stationery' AND s.Name = 'PaperWorld Co.';

INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'Ballpoint Pen Pack',
       c.CategoryID, s.SupplierID, 45.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Stationery' AND s.Name = 'PaperWorld Co.';

INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'Basmati Rice 5kg',
       c.CategoryID, s.SupplierID, 320.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Grocery' AND s.Name = 'FreshMart Traders';

INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'Sunflower Oil 1L',
       c.CategoryID, s.SupplierID, 180.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Grocery' AND s.Name = 'FreshMart Traders';

INSERT INTO Products (ProductID, Name, CategoryID, SupplierID, Unit_Price)
SELECT seq_products.NEXTVAL, 'Old CRT Monitor',
       c.CategoryID, s.SupplierID, 999.00
FROM   Category c, Suppliers s
WHERE  c.Name = 'Discontinued' AND s.Name = 'OldStock Suppliers';

-- ------------------------------------------------------------
-- 5. STOCK_MANAGEMENT (INSERT INTO...SELECT — ProductID by name)
-- ------------------------------------------------------------
INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 5, 15
FROM   Products WHERE Name = 'Wireless Mouse';

INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 20, 10
FROM   Products WHERE Name = 'USB-C Hub';

INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 8, 10
FROM   Products WHERE Name = 'Bluetooth Headphones';

INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 50, 20
FROM   Products WHERE Name = 'A4 Notebook';

INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 3, 25
FROM   Products WHERE Name = 'Ballpoint Pen Pack';

INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 30, 15
FROM   Products WHERE Name = 'Basmati Rice 5kg';

INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 12, 10
FROM   Products WHERE Name = 'Sunflower Oil 1L';

INSERT INTO Stock_Management (StockID, ProductID, Quantity, Restock_Level)
SELECT seq_stock.NEXTVAL, ProductID, 2, 20
FROM   Products WHERE Name = 'Old CRT Monitor';

-- ------------------------------------------------------------
-- 6. TRANSACTIONS (INSERT INTO...SELECT — UserID by username)
-- ------------------------------------------------------------
INSERT INTO Transactions (TransactionID, UserID, Trans_Type, Total_Amount, Notes)
SELECT seq_transactions.NEXTVAL, UserID, 'SALE', 1198.00, 'Sale of 2x Wireless Mouse'
FROM   Users WHERE Username = 'staff_arjun';

INSERT INTO Transactions (TransactionID, UserID, Trans_Type, Total_Amount, Notes)
SELECT seq_transactions.NEXTVAL, UserID, 'RESTOCK', 0.00, 'Restocked Bluetooth Headphones'
FROM   Users WHERE Username = 'manager_priya';

INSERT INTO Transactions (TransactionID, UserID, Trans_Type, Total_Amount, Notes)
SELECT seq_transactions.NEXTVAL, UserID, 'RETURN', 85.00, 'Return of 1x A4 Notebook'
FROM   Users WHERE Username = 'staff_meera';

INSERT INTO Transactions (TransactionID, UserID, Trans_Type, Total_Amount, Notes)
SELECT seq_transactions.NEXTVAL, UserID, 'SALE', 225.00, 'Sale of 5x Ballpoint Pen Pack'
FROM   Users WHERE Username = 'staff_arjun';

-- ------------------------------------------------------------
-- 7. TRANSACTION_ITEMS (INSERT INTO...SELECT — all FKs by name)
-- ------------------------------------------------------------
-- 2x Wireless Mouse — Sale transaction
INSERT INTO Transaction_Items (ItemID, TransactionID, ProductID, Quantity, Unit_Price)
SELECT seq_items.NEXTVAL, t.TransactionID, p.ProductID, 2, 599.00
FROM   Transactions t, Products p
WHERE  t.Notes = 'Sale of 2x Wireless Mouse'
AND    p.Name  = 'Wireless Mouse';

-- 10x Bluetooth Headphones — Restock transaction
INSERT INTO Transaction_Items (ItemID, TransactionID, ProductID, Quantity, Unit_Price)
SELECT seq_items.NEXTVAL, t.TransactionID, p.ProductID, 10, 0.00
FROM   Transactions t, Products p
WHERE  t.Notes = 'Restocked Bluetooth Headphones'
AND    p.Name  = 'Bluetooth Headphones';

-- 1x A4 Notebook — Return transaction
INSERT INTO Transaction_Items (ItemID, TransactionID, ProductID, Quantity, Unit_Price)
SELECT seq_items.NEXTVAL, t.TransactionID, p.ProductID, 1, 85.00
FROM   Transactions t, Products p
WHERE  t.Notes = 'Return of 1x A4 Notebook'
AND    p.Name  = 'A4 Notebook';

-- 5x Ballpoint Pen Pack — Sale transaction
INSERT INTO Transaction_Items (ItemID, TransactionID, ProductID, Quantity, Unit_Price)
SELECT seq_items.NEXTVAL, t.TransactionID, p.ProductID, 5, 45.00
FROM   Transactions t, Products p
WHERE  t.Notes = 'Sale of 5x Ballpoint Pen Pack'
AND    p.Name  = 'Ballpoint Pen Pack';

-- ------------------------------------------------------------
-- 8. AUDIT_LOG
-- ------------------------------------------------------------
INSERT INTO Audit_Log (LogID, Table_Name, Operation, Record_ID,
                       Changed_By, Old_Value, New_Value, Description)
SELECT seq_auditlog.NEXTVAL, 'CATEGORY', 'UPDATE', CategoryID,
       'admin_raj', 'IS_ACTIVE=1', 'IS_ACTIVE=0',
       'Soft delete: Discontinued category deactivated'
FROM   Category WHERE Name = 'Discontinued';

-- ------------------------------------------------------------
-- COMMIT
-- ------------------------------------------------------------
COMMIT;

-- ============================================================
-- VERIFY 1: Row counts
-- ============================================================
SELECT 'Users'             AS Table_Name, COUNT(*) AS Row_Count FROM Users            UNION ALL
SELECT 'Category',                        COUNT(*)              FROM Category          UNION ALL
SELECT 'Suppliers',                       COUNT(*)              FROM Suppliers         UNION ALL
SELECT 'Products',                        COUNT(*)              FROM Products          UNION ALL
SELECT 'Stock_Management',                COUNT(*)              FROM Stock_Management  UNION ALL
SELECT 'Transactions',                    COUNT(*)              FROM Transactions      UNION ALL
SELECT 'Transaction_Items',               COUNT(*)              FROM Transaction_Items UNION ALL
SELECT 'Audit_Log',                       COUNT(*)              FROM Audit_Log;

-- Expected:
-- Users              4
-- Category           4
-- Suppliers          4
-- Products           8
-- Stock_Management   8
-- Transactions       4
-- Transaction_Items  4
-- Audit_Log          1

-- ============================================================
-- VERIFY 2: Stock with product names
-- ============================================================
SELECT p.Name AS Product, sm.Quantity, sm.Restock_Level
FROM   Products p
JOIN   Stock_Management sm ON p.ProductID = sm.ProductID
ORDER BY p.Name;

-- ============================================================
-- VERIFY 3: Restock alert — active categories ONLY
-- ============================================================
SELECT  p.Name              AS Product,
        c.Name              AS Category,
        sm.Quantity         AS Current_Stock,
        sm.Restock_Level,
        (sm.Restock_Level - sm.Quantity) AS Units_Needed
FROM    Products         p
JOIN    Stock_Management sm ON p.ProductID  = sm.ProductID
JOIN    Category         c  ON p.CategoryID = c.CategoryID
WHERE   sm.Quantity < sm.Restock_Level
  AND   c.IS_ACTIVE   = 1
ORDER BY Units_Needed DESC;

-- Expected 3 rows:
-- Ballpoint Pen Pack    Stationery    3   25   22
-- Wireless Mouse        Electronics   5   15   10
-- Bluetooth Headphones  Electronics   8   10    2
