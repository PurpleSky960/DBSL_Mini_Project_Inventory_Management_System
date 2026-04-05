-- ============================================================
-- FILE: 04_procedures.sql
-- PROJECT: Inventory Management System
-- DESCRIPTION: PL/SQL Stored Procedures
--   1. Process_Transaction_Proc  — handles SALE / RETURN
--   2. Restock_Product_Proc      — blocks if category inactive
--   3. Soft_Delete_Category_Proc — sets IS_ACTIVE = 0
-- DATABASE: Oracle SQL Developer
-- RUN: F5 (Run Script)
-- ============================================================


-- ============================================================
-- PROCEDURE 1: Process_Transaction_Proc
-- Handles SALE and RETURN transactions
-- Steps:
--   a) Validate product exists
--   b) For SALE  : check sufficient stock → deduct stock
--   c) For RETURN: add stock back
--   d) Insert into Transactions + Transaction_Items
--   e) Log to Audit_Log
-- ============================================================
CREATE OR REPLACE PROCEDURE Process_Transaction_Proc (
    p_user_id    IN  Users.UserID%TYPE,
    p_product_id IN  Products.ProductID%TYPE,
    p_quantity   IN  NUMBER,
    p_trans_type IN  VARCHAR2,   -- 'SALE' or 'RETURN'
    p_notes      IN  VARCHAR2 DEFAULT NULL
)
AS
    v_unit_price     Products.Unit_Price%TYPE;
    v_current_stock  Stock_Management.Quantity%TYPE;
    v_total_amount   NUMBER(12,2);
    v_trans_id       Transactions.TransactionID%TYPE;
    v_product_name   Products.Name%TYPE;
BEGIN
    -- Step 1: Validate product exists and get price
    BEGIN
        SELECT Unit_Price, Name
        INTO   v_unit_price, v_product_name
        FROM   Products
        WHERE  ProductID = p_product_id
        AND    Is_Active = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001,
                'ERROR: Product ID ' || p_product_id ||
                ' not found or inactive.');
    END;

    -- Step 2: Get current stock
    BEGIN
        SELECT Quantity
        INTO   v_current_stock
        FROM   Stock_Management
        WHERE  ProductID = p_product_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002,
                'ERROR: No stock record found for Product ID '
                || p_product_id);
    END;

    -- Step 3: For SALE — check sufficient stock
    IF p_trans_type = 'SALE' THEN
        IF v_current_stock < p_quantity THEN
            RAISE_APPLICATION_ERROR(-20003,
                'ERROR: Insufficient stock. Available: '
                || v_current_stock || ', Requested: ' || p_quantity);
        END IF;
        -- Deduct stock
        UPDATE Stock_Management
        SET    Quantity     = Quantity - p_quantity,
               Last_Updated = SYSTIMESTAMP
        WHERE  ProductID    = p_product_id;

    -- Step 4: For RETURN — add stock back
    ELSIF p_trans_type = 'RETURN' THEN
        UPDATE Stock_Management
        SET    Quantity     = Quantity + p_quantity,
               Last_Updated = SYSTIMESTAMP
        WHERE  ProductID    = p_product_id;
    ELSE
        RAISE_APPLICATION_ERROR(-20004,
            'ERROR: Invalid transaction type. Use SALE or RETURN.');
    END IF;

    -- Step 5: Calculate total amount
    v_total_amount := p_quantity * v_unit_price;

    -- Step 6: Insert into Transactions
    INSERT INTO Transactions (
        TransactionID, UserID, Trans_Type, Total_Amount, Notes
    )
    VALUES (
        seq_transactions.NEXTVAL,
        p_user_id,
        p_trans_type,
        v_total_amount,
        p_notes
    )
    RETURNING TransactionID INTO v_trans_id;

    -- Step 7: Insert into Transaction_Items
    INSERT INTO Transaction_Items (
        ItemID, TransactionID, ProductID, Quantity, Unit_Price
    )
    VALUES (
        seq_items.NEXTVAL,
        v_trans_id,
        p_product_id,
        p_quantity,
        v_unit_price
    );

    -- Step 8: Log to Audit_Log
    INSERT INTO Audit_Log (
        LogID, Table_Name, Operation, Record_ID,
        Changed_By, New_Value, Description
    )
    VALUES (
        seq_auditlog.NEXTVAL,
        'TRANSACTIONS', 'INSERT', v_trans_id,
        USER,
        'Type=' || p_trans_type ||
        ' Product=' || v_product_name ||
        ' Qty=' || p_quantity,
        'Transaction processed by procedure'
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: ' || p_trans_type ||
        ' processed. TransactionID = ' || v_trans_id ||
        ' | Product: ' || v_product_name ||
        ' | Qty: ' || p_quantity ||
        ' | Total: ' || v_total_amount);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('FAILED: ' || SQLERRM);
        RAISE;
END Process_Transaction_Proc;
/


-- ============================================================
-- PROCEDURE 2: Restock_Product_Proc
-- Adds stock to a product
-- BUSINESS RULE: BLOCKS restocking if category IS_ACTIVE = 0
-- ============================================================
CREATE OR REPLACE PROCEDURE Restock_Product_Proc (
    p_user_id    IN  Users.UserID%TYPE,
    p_product_id IN  Products.ProductID%TYPE,
    p_quantity   IN  NUMBER
)
AS
    v_cat_active   Category.IS_ACTIVE%TYPE;
    v_cat_name     Category.Name%TYPE;
    v_prod_name    Products.Name%TYPE;
    v_trans_id     Transactions.TransactionID%TYPE;
    v_old_qty      Stock_Management.Quantity%TYPE;
    v_new_qty      Stock_Management.Quantity%TYPE;
BEGIN
    -- Step 1: Check product + category status in one query
    BEGIN
        SELECT p.Name, c.Name, c.IS_ACTIVE
        INTO   v_prod_name, v_cat_name, v_cat_active
        FROM   Products p
        JOIN   Category c ON p.CategoryID = c.CategoryID
        WHERE  p.ProductID = p_product_id
        AND    p.Is_Active = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20005,
                'ERROR: Product ID ' || p_product_id ||
                ' not found or inactive.');
    END;

    -- Step 2: *** CORE BUSINESS RULE CHECK ***
    -- Block restock if category is inactive (IS_ACTIVE = 0)
    IF v_cat_active = 0 THEN
        RAISE_APPLICATION_ERROR(-20006,
            'ERROR: Cannot restock product "' || v_prod_name ||
            '". Category "' || v_cat_name ||
            '" is inactive (IS_ACTIVE=0). ' ||
            'Restock is only allowed for active categories.');
    END IF;

    -- Step 3: Get current stock
    SELECT Quantity
    INTO   v_old_qty
    FROM   Stock_Management
    WHERE  ProductID = p_product_id
    FOR UPDATE;

    -- Step 4: Update stock
    UPDATE Stock_Management
    SET    Quantity     = Quantity + p_quantity,
           Last_Updated = SYSTIMESTAMP
    WHERE  ProductID    = p_product_id;

    v_new_qty := v_old_qty + p_quantity;

    -- Step 5: Insert Restock Transaction
    INSERT INTO Transactions (
        TransactionID, UserID, Trans_Type, Total_Amount, Notes
    )
    VALUES (
        seq_transactions.NEXTVAL,
        p_user_id,
        'RESTOCK',
        0,
        'Restock: ' || v_prod_name || ' +' || p_quantity || ' units'
    )
    RETURNING TransactionID INTO v_trans_id;

    -- Step 6: Insert Transaction Item
    INSERT INTO Transaction_Items (
        ItemID, TransactionID, ProductID, Quantity, Unit_Price
    )
    VALUES (
        seq_items.NEXTVAL, v_trans_id,
        p_product_id, p_quantity, 0
    );

    -- Step 7: Audit log
    INSERT INTO Audit_Log (
        LogID, Table_Name, Operation, Record_ID,
        Changed_By, Old_Value, New_Value, Description
    )
    VALUES (
        seq_auditlog.NEXTVAL,
        'STOCK_MANAGEMENT', 'UPDATE', p_product_id,
        USER,
        'Qty=' || v_old_qty,
        'Qty=' || v_new_qty,
        'Restock by procedure for product: ' || v_prod_name
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Restocked "' || v_prod_name ||
        '" | Added: ' || p_quantity ||
        ' | Old Stock: ' || v_old_qty ||
        ' | New Stock: ' || v_new_qty);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('FAILED: ' || SQLERRM);
        RAISE;
END Restock_Product_Proc;
/


-- ============================================================
-- PROCEDURE 3: Soft_Delete_Category_Proc
-- Sets IS_ACTIVE = 0 for a category (soft delete)
-- Does NOT physically delete the row
-- Products under it can still be sold, NOT restocked
-- ============================================================
CREATE OR REPLACE PROCEDURE Soft_Delete_Category_Proc (
    p_category_id IN Category.CategoryID%TYPE
)
AS
    v_cat_name     Category.Name%TYPE;
    v_is_active    Category.IS_ACTIVE%TYPE;
    v_prod_count   NUMBER;
BEGIN
    -- Step 1: Check category exists
    BEGIN
        SELECT Name, IS_ACTIVE
        INTO   v_cat_name, v_is_active
        FROM   Category
        WHERE  CategoryID = p_category_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20007,
                'ERROR: Category ID ' || p_category_id ||
                ' does not exist.');
    END;

    -- Step 2: Check if already inactive
    IF v_is_active = 0 THEN
        DBMS_OUTPUT.PUT_LINE('INFO: Category "' || v_cat_name ||
            '" is already inactive. No changes made.');
        RETURN;
    END IF;

    -- Step 3: Count products affected
    SELECT COUNT(*)
    INTO   v_prod_count
    FROM   Products
    WHERE  CategoryID = p_category_id
    AND    Is_Active  = 1;

    -- Step 4: Soft delete — set IS_ACTIVE = 0
    UPDATE Category
    SET    IS_ACTIVE = 0
    WHERE  CategoryID = p_category_id;

    -- Step 5: Audit log
    INSERT INTO Audit_Log (
        LogID, Table_Name, Operation, Record_ID,
        Changed_By, Old_Value, New_Value, Description
    )
    VALUES (
        seq_auditlog.NEXTVAL,
        'CATEGORY', 'UPDATE', p_category_id,
        USER,
        'IS_ACTIVE=1',
        'IS_ACTIVE=0',
        'Soft delete: Category "' || v_cat_name ||
        '" deactivated. ' || v_prod_count ||
        ' product(s) affected (sale allowed, restock blocked).'
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Category "' || v_cat_name ||
        '" soft deleted (IS_ACTIVE=0).');
    DBMS_OUTPUT.PUT_LINE('INFO: ' || v_prod_count ||
        ' product(s) affected — sales allowed, restocking BLOCKED.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('FAILED: ' || SQLERRM);
        RAISE;
END Soft_Delete_Category_Proc;
/


-- ============================================================
-- VERIFY: All 3 procedures compiled successfully
-- ============================================================
SELECT Object_Name, Object_Type, Status
FROM   User_Objects
WHERE  Object_Type = 'PROCEDURE'
AND    Object_Name IN (
    'PROCESS_TRANSACTION_PROC',
    'RESTOCK_PRODUCT_PROC',
    'SOFT_DELETE_CATEGORY_PROC'
)
ORDER BY Object_Name;

-- Expected:
-- PROCESS_TRANSACTION_PROC    PROCEDURE   VALID
-- RESTOCK_PRODUCT_PROC        PROCEDURE   VALID
-- SOFT_DELETE_CATEGORY_PROC   PROCEDURE   VALID


-- ============================================================
-- SAMPLE EXECUTIONS
-- ============================================================

-- Enable output
SET SERVEROUTPUT ON;

-- ------------------------------------------------------------
-- TEST 1: SALE — sell 2x Wireless Mouse (ProductID lookup by name)
-- ------------------------------------------------------------
DECLARE
    v_pid NUMBER;
    v_uid NUMBER;
BEGIN
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'Wireless Mouse';
    SELECT UserID   INTO v_uid FROM Users    WHERE Username = 'staff_arjun';
    Process_Transaction_Proc(v_uid, v_pid, 2, 'SALE', 'Test sale - 2x Wireless Mouse');
END;
/
-- Expected output:
-- SUCCESS: SALE processed. TransactionID = X | Product: Wireless Mouse | Qty: 2 | Total: 1198

-- ------------------------------------------------------------
-- TEST 2: SALE — try to sell more than available stock (should FAIL)
-- ------------------------------------------------------------
DECLARE
    v_pid NUMBER;
    v_uid NUMBER;
BEGIN
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'Ballpoint Pen Pack';
    SELECT UserID   INTO v_uid FROM Users    WHERE Username = 'staff_meera';
    Process_Transaction_Proc(v_uid, v_pid, 999, 'SALE', 'Test oversell');
END;
/
-- Expected output:
-- FAILED: ORA-20003: ERROR: Insufficient stock. Available: 3, Requested: 999

-- ------------------------------------------------------------
-- TEST 3: RETURN — return 1x A4 Notebook
-- ------------------------------------------------------------
DECLARE
    v_pid NUMBER;
    v_uid NUMBER;
BEGIN
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'A4 Notebook';
    SELECT UserID   INTO v_uid FROM Users    WHERE Username = 'staff_meera';
    Process_Transaction_Proc(v_uid, v_pid, 1, 'RETURN', 'Test return - 1x A4 Notebook');
END;
/
-- Expected output:
-- SUCCESS: RETURN processed. TransactionID = X | Product: A4 Notebook | Qty: 1 | Total: 85

-- ------------------------------------------------------------
-- TEST 4: RESTOCK — restock Wireless Mouse (active category = OK)
-- ------------------------------------------------------------
DECLARE
    v_pid NUMBER;
    v_uid NUMBER;
BEGIN
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'Wireless Mouse';
    SELECT UserID   INTO v_uid FROM Users    WHERE Username = 'manager_priya';
    Restock_Product_Proc(v_uid, v_pid, 20);
END;
/
-- Expected output:
-- SUCCESS: Restocked "Wireless Mouse" | Added: 20 | Old Stock: X | New Stock: X+20

-- ------------------------------------------------------------
-- TEST 5: RESTOCK — try to restock Old CRT Monitor (INACTIVE category = BLOCKED)
-- ------------------------------------------------------------
DECLARE
    v_pid NUMBER;
    v_uid NUMBER;
BEGIN
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'Old CRT Monitor';
    SELECT UserID   INTO v_uid FROM Users    WHERE Username = 'manager_priya';
    Restock_Product_Proc(v_uid, v_pid, 10);
END;
/
-- Expected output:
-- FAILED: ORA-20006: ERROR: Cannot restock product "Old CRT Monitor".
--         Category "Discontinued" is inactive (IS_ACTIVE=0).

-- ------------------------------------------------------------
-- TEST 6: SOFT DELETE — deactivate Grocery category
-- ------------------------------------------------------------
DECLARE
    v_cid NUMBER;
BEGIN
    SELECT CategoryID INTO v_cid FROM Category WHERE Name = 'Grocery';
    Soft_Delete_Category_Proc(v_cid);
END;
/
-- Expected output:
-- SUCCESS: Category "Grocery" soft deleted (IS_ACTIVE=0).
-- INFO: 2 product(s) affected — sales allowed, restocking BLOCKED.

-- ------------------------------------------------------------
-- TEST 7: SOFT DELETE — try to deactivate already inactive category
-- ------------------------------------------------------------
DECLARE
    v_cid NUMBER;
BEGIN
    SELECT CategoryID INTO v_cid FROM Category WHERE Name = 'Discontinued';
    Soft_Delete_Category_Proc(v_cid);
END;
/
-- Expected output:
-- INFO: Category "Discontinued" is already inactive. No changes made.

-- ------------------------------------------------------------
-- VERIFY: Check stock levels after tests
-- ------------------------------------------------------------
SELECT p.Name AS Product, sm.Quantity, sm.Restock_Level
FROM   Products p
JOIN   Stock_Management sm ON p.ProductID = sm.ProductID
ORDER BY p.Name;

-- ------------------------------------------------------------
-- VERIFY: Check audit log entries
-- ------------------------------------------------------------
SELECT LogID, Table_Name, Operation, Changed_By,
       Old_Value, New_Value, Description
FROM   Audit_Log
ORDER BY LogID;
