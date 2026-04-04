-- ============================================================
-- FILE: 03_sql_queries.sql
-- PROJECT: Inventory Management System
-- DESCRIPTION: SQL Queries — JOINs, GROUP BY, HAVING,
--              Subqueries, UNION / INTERSECT / MINUS
-- DATABASE: Oracle SQL Developer
-- RUN: F5 (Run Script) — each query ends with semicolon
-- ============================================================


-- ============================================================
-- SECTION A: JOIN QUERIES
-- ============================================================

-- A1. Full Product Dashboard
SELECT p.ProductID,
       p.Name                                   AS Product,
       c.Name                                   AS Category,
       c.IS_ACTIVE                              AS Cat_Active,
       s.Name                                   AS Supplier,
       p.Unit_Price,
       sm.Quantity                              AS Stock_Qty,
       sm.Restock_Level,
       CASE WHEN sm.Quantity < sm.Restock_Level
            THEN 'LOW STOCK' ELSE 'OK'
       END                                      AS Stock_Status
FROM   Products p
JOIN   Category         c  ON p.CategoryID  = c.CategoryID
JOIN   Suppliers        s  ON p.SupplierID  = s.SupplierID
JOIN   Stock_Management sm ON p.ProductID   = sm.ProductID
ORDER BY c.Name, p.Name;

-- Expected: 8 rows — all products with stock status

-- A2. Transaction History with User and Product Details
SELECT t.TransactionID,
       t.Trans_Type,
       u.Username,
       u.Role,
       p.Name                                   AS Product,
       ti.Quantity,
       ti.Unit_Price,
       ti.Subtotal,
       t.Trans_Date
FROM   Transactions      t
JOIN   Users             u  ON t.UserID       = u.UserID
JOIN   Transaction_Items ti ON t.TransactionID = ti.TransactionID
JOIN   Products          p  ON ti.ProductID   = p.ProductID
ORDER BY t.Trans_Date DESC;

-- Expected: 4 rows — full transaction breakdown

-- A3. *** CORE BUSINESS RULE: Restocking Alert Query ***
-- Only products under ACTIVE categories appear here
SELECT p.ProductID,
       p.Name                                   AS Product,
       c.Name                                   AS Category,
       sm.Quantity                              AS Current_Stock,
       sm.Restock_Level,
       (sm.Restock_Level - sm.Quantity)         AS Units_Needed
FROM   Products         p
JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
JOIN   Category         c  ON p.CategoryID = c.CategoryID
WHERE  sm.Quantity  < sm.Restock_Level
AND    c.IS_ACTIVE  = 1
ORDER BY Units_Needed DESC;

-- Expected: 3 rows — Old CRT Monitor EXCLUDED (IS_ACTIVE=0)
-- Ballpoint Pen Pack  Stationery    3  25  22
-- Wireless Mouse      Electronics   5  15  10
-- Bluetooth Headphones Electronics  8  10   2

-- A4. Supplier-wise Product Count and Price Range
SELECT s.Name                                   AS Supplier,
       s.Contact,
       COUNT(p.ProductID)                       AS Total_Products,
       MIN(p.Unit_Price)                        AS Min_Price,
       MAX(p.Unit_Price)                        AS Max_Price,
       ROUND(AVG(p.Unit_Price), 2)              AS Avg_Price
FROM   Suppliers s
JOIN   Products  p ON s.SupplierID = p.SupplierID
GROUP BY s.Name, s.Contact
ORDER BY Total_Products DESC;

-- Expected: 4 rows — one per supplier


-- ============================================================
-- SECTION B: GROUP BY, HAVING, ORDER BY
-- ============================================================

-- B1. Total Sales Revenue per Category
SELECT c.Name                                   AS Category,
       COUNT(DISTINCT t.TransactionID)          AS Total_Transactions,
       SUM(ti.Subtotal)                         AS Total_Revenue
FROM   Transactions      t
JOIN   Transaction_Items ti ON t.TransactionID = ti.TransactionID
JOIN   Products          p  ON ti.ProductID    = p.ProductID
JOIN   Category          c  ON p.CategoryID    = c.CategoryID
WHERE  t.Trans_Type = 'SALE'
GROUP BY c.Name
ORDER BY Total_Revenue DESC;

-- Expected: Electronics 1198.00 / Stationery 225.00

-- B2. Categories with Revenue greater than 500 (HAVING clause)
SELECT c.Name                                   AS Category,
       SUM(ti.Subtotal)                         AS Total_Revenue
FROM   Transactions      t
JOIN   Transaction_Items ti ON t.TransactionID = ti.TransactionID
JOIN   Products          p  ON ti.ProductID    = p.ProductID
JOIN   Category          c  ON p.CategoryID    = c.CategoryID
WHERE  t.Trans_Type = 'SALE'
GROUP BY c.Name
HAVING SUM(ti.Subtotal) > 500
ORDER BY Total_Revenue DESC;

-- Expected: 1 row — Electronics 1198.00

-- B3. Stock Summary per Category
SELECT c.Name                                   AS Category,
       c.IS_ACTIVE,
       COUNT(p.ProductID)                       AS Product_Count,
       SUM(sm.Quantity)                         AS Total_Stock,
       MIN(sm.Quantity)                         AS Min_Stock,
       MAX(sm.Quantity)                         AS Max_Stock,
       ROUND(AVG(sm.Quantity), 2)               AS Avg_Stock
FROM   Category         c
JOIN   Products         p  ON c.CategoryID = p.CategoryID
JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
GROUP BY c.Name, c.IS_ACTIVE
ORDER BY c.IS_ACTIVE DESC, Total_Stock DESC;

-- Expected: 4 rows — one per category

-- B4. Top Users by Transaction Volume
SELECT u.Username,
       u.Role,
       COUNT(t.TransactionID)                   AS Total_Transactions,
       NVL(SUM(t.Total_Amount), 0)              AS Total_Amount_Handled
FROM   Users         u
LEFT JOIN Transactions t ON u.UserID = t.UserID
GROUP BY u.Username, u.Role
ORDER BY Total_Transactions DESC, Total_Amount_Handled DESC;

-- Expected: 4 rows — admin_raj shows 0 transactions

-- B5. Monthly Transaction Summary
SELECT TO_CHAR(t.Trans_Date, 'YYYY-MM')         AS Month,
       t.Trans_Type,
       COUNT(*)                                 AS Transaction_Count,
       SUM(t.Total_Amount)                      AS Total_Amount
FROM   Transactions t
GROUP BY TO_CHAR(t.Trans_Date, 'YYYY-MM'), t.Trans_Type
ORDER BY Month, t.Trans_Type;

-- Expected: grouped rows by month and type


-- ============================================================
-- SECTION C: SUBQUERIES
-- ============================================================

-- C1. Products with Below-Average Stock Quantity
SELECT p.Name                                   AS Product,
       c.Name                                   AS Category,
       sm.Quantity,
       sm.Restock_Level
FROM   Products         p
JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
JOIN   Category         c  ON p.CategoryID = c.CategoryID
WHERE  sm.Quantity < (SELECT AVG(Quantity) FROM Stock_Management)
ORDER BY sm.Quantity;

-- Expected: products below average stock quantity

-- C2. Products Never Sold (NOT IN subquery)
SELECT p.ProductID,
       p.Name                                   AS Product,
       c.Name                                   AS Category,
       sm.Quantity                              AS Current_Stock
FROM   Products         p
JOIN   Category         c  ON p.CategoryID = c.CategoryID
JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
WHERE  p.ProductID NOT IN (
           SELECT DISTINCT ti.ProductID
           FROM   Transaction_Items ti
           JOIN   Transactions      t ON ti.TransactionID = t.TransactionID
           WHERE  t.Trans_Type = 'SALE'
       )
ORDER BY p.ProductID;

-- Expected: USB-C Hub, Basmati Rice, Sunflower Oil, Old CRT Monitor

-- C3. Most Expensive Product per Category (Correlated Subquery)
SELECT p.ProductID,
       p.Name                                   AS Product,
       c.Name                                   AS Category,
       p.Unit_Price
FROM   Products  p
JOIN   Category  c ON p.CategoryID = c.CategoryID
WHERE  p.Unit_Price = (
           SELECT MAX(p2.Unit_Price)
           FROM   Products p2
           WHERE  p2.CategoryID = p.CategoryID
       )
ORDER BY p.Unit_Price DESC;

-- Expected: 4 rows — top-priced product per category

-- C4. Users Who Processed More Than Average Transactions
SELECT u.Username,
       u.Role,
       COUNT(t.TransactionID)                   AS Trans_Count
FROM   Users         u
JOIN   Transactions  t ON u.UserID = t.UserID
GROUP BY u.Username, u.Role
HAVING COUNT(t.TransactionID) > (
           SELECT AVG(cnt)
           FROM (
               SELECT COUNT(TransactionID) AS cnt
               FROM   Transactions
               GROUP BY UserID
           )
       )
ORDER BY Trans_Count DESC;

-- Expected: staff_arjun (2 transactions)

-- C5. Low Stock Products in Active Categories (EXISTS)
SELECT p.Name                                   AS Product,
       sm.Quantity,
       sm.Restock_Level
FROM   Products         p
JOIN   Stock_Management sm ON p.ProductID = sm.ProductID
WHERE  sm.Quantity < sm.Restock_Level
AND    EXISTS (
           SELECT 1
           FROM   Category c
           WHERE  c.CategoryID = p.CategoryID
           AND    c.IS_ACTIVE  = 1
       )
ORDER BY sm.Quantity;

-- Expected: 3 rows — Ballpoint Pen Pack, Wireless Mouse, Bluetooth Headphones


-- ============================================================
-- SECTION D: UNION / INTERSECT / MINUS
-- FIX: Each set operation wrapped in SELECT * FROM (...) 
--      so Oracle script runner handles them correctly
-- ============================================================

-- D1. UNION — Products: Low Stock OR Under Inactive Category
SELECT * FROM (
    SELECT p.ProductID, p.Name AS Product, 'LOW STOCK' AS Flag
    FROM   Products         p
    JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
    WHERE  sm.Quantity < sm.Restock_Level
    UNION
    SELECT p.ProductID, p.Name, 'INACTIVE CATEGORY'
    FROM   Products  p
    JOIN   Category  c ON p.CategoryID = c.CategoryID
    WHERE  c.IS_ACTIVE = 0
)
ORDER BY ProductID, Flag;

-- Expected: 5 rows
-- Old CRT Monitor appears twice (LOW STOCK + INACTIVE CATEGORY)

-- D2. UNION ALL — Sales and Returns combined
SELECT * FROM (
    SELECT 'SALE'   AS Trans_Type,
           p.Name   AS Product,
           ti.Quantity,
           ti.Subtotal
    FROM   Transactions      t
    JOIN   Transaction_Items ti ON t.TransactionID = ti.TransactionID
    JOIN   Products          p  ON ti.ProductID    = p.ProductID
    WHERE  t.Trans_Type = 'SALE'
    UNION ALL
    SELECT 'RETURN',
           p.Name,
           ti.Quantity,
           ti.Subtotal
    FROM   Transactions      t
    JOIN   Transaction_Items ti ON t.TransactionID = ti.TransactionID
    JOIN   Products          p  ON ti.ProductID    = p.ProductID
    WHERE  t.Trans_Type = 'RETURN'
)
ORDER BY Trans_Type, Product;

-- Expected: 3 rows (2 SALE + 1 RETURN)

-- D3. INTERSECT — Low Stock AND Inactive Category
-- These products are stuck: low stock but CANNOT be restocked
SELECT * FROM (
    SELECT p.ProductID, p.Name
    FROM   Products         p
    JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
    WHERE  sm.Quantity < sm.Restock_Level
    INTERSECT
    SELECT p.ProductID, p.Name
    FROM   Products  p
    JOIN   Category  c ON p.CategoryID = c.CategoryID
    WHERE  c.IS_ACTIVE = 0
)
ORDER BY ProductID;

-- Expected: 1 row — Old CRT Monitor (low stock AND inactive)

-- D4. MINUS — Actionable Restock List (exclude inactive categories)
SELECT * FROM (
    SELECT p.ProductID, p.Name
    FROM   Products         p
    JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
    WHERE  sm.Quantity < sm.Restock_Level
    MINUS
    SELECT p.ProductID, p.Name
    FROM   Products  p
    JOIN   Category  c ON p.CategoryID = c.CategoryID
    WHERE  c.IS_ACTIVE = 0
)
ORDER BY ProductID;

-- Expected: 3 rows
-- Wireless Mouse, Bluetooth Headphones, Ballpoint Pen Pack

-- D5. MINUS — Users who have NOT processed any SALE
SELECT * FROM (
    SELECT u.UserID, u.Username, u.Role
    FROM   Users u
    WHERE  u.Role IN ('STAFF', 'MANAGER', 'ADMIN')
    MINUS
    SELECT DISTINCT u.UserID, u.Username, u.Role
    FROM   Users        u
    JOIN   Transactions t ON u.UserID = t.UserID
    WHERE  t.Trans_Type = 'SALE'
)
ORDER BY UserID;

-- Expected: admin_raj, manager_priya, staff_meera
-- staff_arjun excluded (he processed 2 sales)
