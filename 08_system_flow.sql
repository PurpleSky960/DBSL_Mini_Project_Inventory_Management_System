-- ============================================================
-- FILE: 08_system_flow.sql
-- PROJECT: Inventory Management System
-- DESCRIPTION: Phase 9 — Final System Flow, Validation Queries,
--              and Complete System Summary
-- DATABASE: Oracle SQL Developer
-- RUN: F5 (Run Script) or run sections individually with F9
-- ============================================================


-- ============================================================
-- SECTION 1: COMPLETE OBJECT INVENTORY
-- Verify every database object created across all phases
-- ============================================================

-- All Tables
SELECT 'TABLE' AS Type, Table_Name AS Name, 'Phase 1' AS Phase
FROM   User_Tables
WHERE  Table_Name IN (
    'USERS','CATEGORY','SUPPLIERS','PRODUCTS',
    'STOCK_MANAGEMENT','TRANSACTIONS',
    'TRANSACTION_ITEMS','REPORTS','AUDIT_LOG'
)
ORDER BY Table_Name;

-- All Sequences
SELECT 'SEQUENCE' AS Type, Sequence_Name AS Name, 'Phase 1' AS Phase
FROM   User_Sequences
WHERE  Sequence_Name IN (
    'SEQ_USERS','SEQ_CATEGORY','SEQ_SUPPLIERS',
    'SEQ_PRODUCTS','SEQ_STOCK','SEQ_TRANSACTIONS',
    'SEQ_ITEMS','SEQ_REPORTS','SEQ_AUDITLOG'
)
ORDER BY Sequence_Name;

-- All Procedures
SELECT 'PROCEDURE' AS Type, Object_Name AS Name, Status, 'Phase 4' AS Phase
FROM   User_Objects
WHERE  Object_Type = 'PROCEDURE'
AND    Object_Name IN (
    'PROCESS_TRANSACTION_PROC',
    'RESTOCK_PRODUCT_PROC',
    'SOFT_DELETE_CATEGORY_PROC'
)
ORDER BY Object_Name;

-- All Functions
SELECT 'FUNCTION' AS Type, Object_Name AS Name, Status, 'Phase 5' AS Phase
FROM   User_Objects
WHERE  Object_Type = 'FUNCTION'
AND    Object_Name IN (
    'CALCULATE_TOTAL_PRICE',
    'GET_STOCK_STATUS',
    'IS_CATEGORY_ACTIVE',
    'GET_TOTAL_SALES_BY_PRODUCT'
)
ORDER BY Object_Name;

-- All Packages
SELECT 'PACKAGE' AS Type, Object_Name AS Name, Status, 'Phase 7' AS Phase
FROM   User_Objects
WHERE  Object_Type IN ('PACKAGE','PACKAGE BODY')
AND    Object_Name IN ('PKG_ADMIN_OPS','PKG_USER_OPS')
ORDER BY Object_Name, Object_Type;

-- All Triggers
SELECT 'TRIGGER' AS Type, Trigger_Name AS Name, Status, 'Phase 8' AS Phase
FROM   User_Triggers
WHERE  Trigger_Name IN (
    'TRG_UPDATE_STOCK',
    'TRG_AUDIT_PRODUCTS',
    'TRG_AUDIT_CATEGORY',
    'TRG_AUDIT_STOCK',
    'TRG_BLOCK_RESTOCK'
)
ORDER BY Trigger_Name;


-- ============================================================
-- SECTION 2: SYSTEM HEALTH DASHBOARD
-- Single query showing current state of entire system
-- ============================================================
SELECT * FROM (
    SELECT 'Total Users'              AS Metric,
           TO_CHAR(COUNT(*))          AS Value
    FROM   Users
    UNION ALL
    SELECT 'Active Users',
           TO_CHAR(COUNT(*))
    FROM   Users WHERE Is_Active = 1
    UNION ALL
    SELECT 'Total Categories',
           TO_CHAR(COUNT(*))
    FROM   Category
    UNION ALL
    SELECT 'Active Categories',
           TO_CHAR(COUNT(*))
    FROM   Category WHERE IS_ACTIVE = 1
    UNION ALL
    SELECT 'Inactive Categories (Soft Deleted)',
           TO_CHAR(COUNT(*))
    FROM   Category WHERE IS_ACTIVE = 0
    UNION ALL
    SELECT 'Total Suppliers',
           TO_CHAR(COUNT(*))
    FROM   Suppliers
    UNION ALL
    SELECT 'Total Products',
           TO_CHAR(COUNT(*))
    FROM   Products
    UNION ALL
    SELECT 'Products Needing Restock (Active Cat)',
           TO_CHAR(COUNT(*))
    FROM   Products p
    JOIN   Stock_Management sm ON p.ProductID  = sm.ProductID
    JOIN   Category         c  ON p.CategoryID = c.CategoryID
    WHERE  sm.Quantity < sm.Restock_Level AND c.IS_ACTIVE = 1
    UNION ALL
    SELECT 'Total Transactions',
           TO_CHAR(COUNT(*))
    FROM   Transactions
    UNION ALL
    SELECT 'Total Sales Revenue (Rs.)',
           TO_CHAR(SUM(Total_Amount))
    FROM   Transactions WHERE Trans_Type = 'SALE'
    UNION ALL
    SELECT 'Total Returns (Rs.)',
           TO_CHAR(SUM(Total_Amount))
    FROM   Transactions WHERE Trans_Type = 'RETURN'
    UNION ALL
    SELECT 'Total Audit Log Entries',
           TO_CHAR(COUNT(*))
    FROM   Audit_Log
    UNION ALL
    SELECT 'Total Stock Alerts Logged',
           TO_CHAR(COUNT(*))
    FROM   Reports WHERE Report_Type = 'STOCK_ALERT'
);


-- ============================================================
-- SECTION 3: FULL SYSTEM FLOW DEMONSTRATION
-- End-to-end walkthrough of all key scenarios
-- ============================================================
SET SERVEROUTPUT ON;

-- ------------------------------------------------------------
-- FLOW 1: ADMIN adds a new category + product + supplier
-- ------------------------------------------------------------
DECLARE
    v_new_cid NUMBER;
    v_new_sid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== FLOW 1: Admin Setup ======');

    -- Add new active category
    INSERT INTO Category (CategoryID, Name, Description, IS_ACTIVE)
    VALUES (seq_category.NEXTVAL, 'Furniture', 'Office furniture', 1)
    RETURNING CategoryID INTO v_new_cid;
    DBMS_OUTPUT.PUT_LINE('New Category created: Furniture (ID=' || v_new_cid || ')');

    -- Add supplier via package
    PKG_ADMIN_OPS.Add_Supplier(
        p_name    => 'WoodCraft Suppliers',
        p_contact => '9777888999',
        p_email   => 'woodcraft@mail.com',
        p_address => 'Mysuru, Karnataka'
    );

    -- Add product via package
    SELECT SupplierID INTO v_new_sid
    FROM   Suppliers WHERE Name = 'WoodCraft Suppliers';

    PKG_ADMIN_OPS.Add_Product(
        p_name        => 'Ergonomic Chair',
        p_category_id => v_new_cid,
        p_supplier_id => v_new_sid,
        p_unit_price  => 8999.00,
        p_init_stock  => 10,
        p_restock_lvl => 3
    );
END;
/


-- ------------------------------------------------------------
-- FLOW 2: STAFF processes a SALE via package
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== FLOW 2: Staff Processes Sale ======');
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'staff_arjun';
    SELECT ProductID INTO v_pid FROM Products WHERE Name    = 'Ergonomic Chair';
    PKG_USER_OPS.Process_Sale(v_uid, v_pid, 2, 'Sale of 2x Ergonomic Chair');
END;
/
-- Expected: SUCCESS: SALE — "Ergonomic Chair" x2 | Total: Rs.17998


-- ------------------------------------------------------------
-- FLOW 3: STAFF processes a RETURN
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== FLOW 3: Staff Processes Return ======');
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'staff_meera';
    SELECT ProductID INTO v_pid FROM Products WHERE Name    = 'Ergonomic Chair';
    PKG_USER_OPS.Process_Return(v_uid, v_pid, 1, 'Return of 1x Ergonomic Chair');
END;
/
-- Expected: SUCCESS: RETURN — "Ergonomic Chair" x1 | Refund: Rs.8999


-- ------------------------------------------------------------
-- FLOW 4: MANAGER restocks a product
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== FLOW 4: Manager Restocks Product ======');
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'manager_priya';
    SELECT ProductID INTO v_pid FROM Products WHERE Name    = 'Ergonomic Chair';
    PKG_ADMIN_OPS.Restock_Product(v_uid, v_pid, 20);
END;
/
-- Expected: SUCCESS: Restocked "Ergonomic Chair" | +20


-- ------------------------------------------------------------
-- FLOW 5: ADMIN soft-deletes Furniture category
--         Then attempts restock (should be BLOCKED)
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
    v_cid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== FLOW 5: Soft Delete + Restock Block ======');
    SELECT CategoryID INTO v_cid FROM Category WHERE Name = 'Furniture';

    -- Soft delete the category
    PKG_ADMIN_OPS.Soft_Delete_Category(v_cid);

    -- Attempt restock — should be blocked
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'manager_priya';
    SELECT ProductID INTO v_pid FROM Products WHERE Name    = 'Ergonomic Chair';

    BEGIN
        PKG_ADMIN_OPS.Restock_Product(v_uid, v_pid, 5);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('BLOCKED as expected: ' || SQLERRM);
    END;
END;
/
-- Expected:
-- SUCCESS: Category "Furniture" deactivated.
-- BLOCKED as expected: ORA-20025: Cannot restock...


-- ------------------------------------------------------------
-- FLOW 6: Confirm existing stock of Ergonomic Chair
--         CAN still be sold (IS_ACTIVE=0 only blocks restock)
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== FLOW 6: Selling from Inactive Category ======');
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'staff_arjun';
    SELECT ProductID INTO v_pid FROM Products WHERE Name    = 'Ergonomic Chair';
    PKG_USER_OPS.Process_Sale(v_uid, v_pid, 1, 'Selling remaining stock — inactive category');
END;
/
-- Expected: SUCCESS — selling IS allowed even from inactive category


-- ------------------------------------------------------------
-- FLOW 7: View all transactions for staff_arjun
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('====== FLOW 7: User Transaction History ======');
    SELECT UserID INTO v_uid FROM Users WHERE Username = 'staff_arjun';
    PKG_USER_OPS.View_Transactions(v_uid);
END;
/


-- ============================================================
-- SECTION 4: FINAL REPORTING QUERIES
-- ============================================================

-- ------------------------------------------------------------
-- R1. Live Restock Alert Dashboard
-- Products needing restock — active categories only
-- ------------------------------------------------------------
SELECT  p.Name                              AS Product,
        c.Name                              AS Category,
        sm.Quantity                         AS Current_Stock,
        sm.Restock_Level,
        (sm.Restock_Level - sm.Quantity)    AS Units_Needed,
        s.Name                              AS Supplier,
        s.Contact                           AS Supplier_Contact
FROM    Products         p
JOIN    Stock_Management sm ON p.ProductID  = sm.ProductID
JOIN    Category         c  ON p.CategoryID = c.CategoryID
JOIN    Suppliers        s  ON p.SupplierID = s.SupplierID
WHERE   sm.Quantity  < sm.Restock_Level
AND     c.IS_ACTIVE  = 1
ORDER BY Units_Needed DESC;


-- ------------------------------------------------------------
-- R2. Sales Performance Summary
-- ------------------------------------------------------------
SELECT  p.Name                              AS Product,
        c.Name                              AS Category,
        COUNT(ti.ItemID)                    AS Times_Sold,
        SUM(ti.Quantity)                    AS Total_Units_Sold,
        SUM(ti.Subtotal)                    AS Total_Revenue,
        ROUND(AVG(ti.Subtotal), 2)          AS Avg_Sale_Value
FROM    Transaction_Items ti
JOIN    Transactions      t  ON ti.TransactionID = t.TransactionID
JOIN    Products          p  ON ti.ProductID     = p.ProductID
JOIN    Category          c  ON p.CategoryID     = c.CategoryID
WHERE   t.Trans_Type = 'SALE'
GROUP BY p.Name, c.Name
ORDER BY Total_Revenue DESC;


-- ------------------------------------------------------------
-- R3. Category Health Report (Active vs Inactive)
-- ------------------------------------------------------------
SELECT  c.Name                              AS Category,
        c.IS_ACTIVE,
        COUNT(p.ProductID)                  AS Products,
        SUM(sm.Quantity)                    AS Total_Stock,
        CASE WHEN c.IS_ACTIVE = 1
             THEN 'Sell + Restock Allowed'
             ELSE 'Sell Only — Restock BLOCKED'
        END                                 AS Policy
FROM    Category         c
LEFT JOIN Products         p  ON c.CategoryID = p.CategoryID
LEFT JOIN Stock_Management sm ON p.ProductID  = sm.ProductID
GROUP BY c.Name, c.IS_ACTIVE
ORDER BY c.IS_ACTIVE DESC, c.Name;


-- ------------------------------------------------------------
-- R4. Full Audit Trail (last 20 entries)
-- ------------------------------------------------------------
SELECT LogID,
       Table_Name,
       Operation,
       Record_ID,
       Changed_By,
       Old_Value,
       New_Value,
       TO_CHAR(Change_Date, 'DD-MON-YY HH24:MI:SS') AS Changed_At
FROM   Audit_Log
ORDER BY LogID DESC
FETCH FIRST 20 ROWS ONLY;


-- ------------------------------------------------------------
-- R5. User Activity Report
-- ------------------------------------------------------------
SELECT  u.Username,
        u.Role,
        COUNT(t.TransactionID)              AS Total_Transactions,
        SUM(CASE WHEN t.Trans_Type='SALE'
                 THEN 1 ELSE 0 END)         AS Sales,
        SUM(CASE WHEN t.Trans_Type='RETURN'
                 THEN 1 ELSE 0 END)         AS Returns,
        SUM(CASE WHEN t.Trans_Type='RESTOCK'
                 THEN 1 ELSE 0 END)         AS Restocks,
        NVL(SUM(t.Total_Amount), 0)         AS Total_Value_Handled
FROM    Users        u
LEFT JOIN Transactions t ON u.UserID = t.UserID
GROUP BY u.Username, u.Role
ORDER BY Total_Transactions DESC;
