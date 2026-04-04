-- ============================================================
-- FILE: 07_triggers.sql
-- PROJECT: Inventory Management System
-- DESCRIPTION: PL/SQL Triggers
--   1. TRG_UPDATE_STOCK      — AFTER INSERT on Transaction_Items
--                              Auto-updates stock on SALE/RETURN/RESTOCK
--   2. TRG_AUDIT_PRODUCTS    — AFTER INSERT/UPDATE/DELETE on Products
--   3. TRG_AUDIT_CATEGORY    — AFTER UPDATE on Category
--   4. TRG_AUDIT_STOCK       — AFTER UPDATE on Stock_Management
--   5. TRG_BLOCK_RESTOCK     — BEFORE INSERT on Transaction_Items
--                              (ADVANCED) Prevents restock if category inactive
-- DATABASE: Oracle SQL Developer
-- RUN: F5 (Run Script)
-- NOTE: Run scripts 01-06 first
-- ============================================================


-- ============================================================
-- TRIGGER 1: TRG_UPDATE_STOCK
-- AFTER INSERT on Transaction_Items
-- Automatically updates Stock_Management based on Trans_Type
--   SALE    → decrease stock
--   RETURN  → increase stock
--   RESTOCK → increase stock
-- ============================================================
CREATE OR REPLACE TRIGGER TRG_UPDATE_STOCK
AFTER INSERT ON Transaction_Items
FOR EACH ROW
DECLARE
    v_trans_type Transactions.Trans_Type%TYPE;
    v_curr_stock Stock_Management.Quantity%TYPE;
BEGIN
    -- Get the transaction type for this item
    SELECT Trans_Type
    INTO   v_trans_type
    FROM   Transactions
    WHERE  TransactionID = :NEW.TransactionID;

    -- Get current stock for validation
    SELECT Quantity
    INTO   v_curr_stock
    FROM   Stock_Management
    WHERE  ProductID = :NEW.ProductID;

    IF v_trans_type = 'SALE' THEN
        -- Check stock before deducting
        IF v_curr_stock < :NEW.Quantity THEN
            RAISE_APPLICATION_ERROR(-20040,
                'TRIGGER ERROR: Insufficient stock. ' ||
                'Available: ' || v_curr_stock ||
                ', Requested: ' || :NEW.Quantity);
        END IF;
        UPDATE Stock_Management
        SET    Quantity     = Quantity - :NEW.Quantity,
               Last_Updated = SYSTIMESTAMP
        WHERE  ProductID    = :NEW.ProductID;

    ELSIF v_trans_type IN ('RETURN', 'RESTOCK') THEN
        UPDATE Stock_Management
        SET    Quantity     = Quantity + :NEW.Quantity,
               Last_Updated = SYSTIMESTAMP
        WHERE  ProductID    = :NEW.ProductID;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20041,
            'TRG_UPDATE_STOCK ERROR: ' || SQLERRM);
END TRG_UPDATE_STOCK;
/


-- ============================================================
-- TRIGGER 2: TRG_AUDIT_PRODUCTS
-- AFTER INSERT, UPDATE, DELETE on Products
-- Logs every change to Audit_Log automatically
-- ============================================================
CREATE OR REPLACE TRIGGER TRG_AUDIT_PRODUCTS
AFTER INSERT OR UPDATE OR DELETE ON Products
FOR EACH ROW
DECLARE
    v_operation  VARCHAR2(10);
    v_record_id  NUMBER;
    v_old_val    VARCHAR2(4000);
    v_new_val    VARCHAR2(4000);
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_record_id := :NEW.ProductID;
        v_old_val   := NULL;
        v_new_val   := 'Name='       || :NEW.Name       ||
                       ' Price='     || :NEW.Unit_Price  ||
                       ' CatID='     || :NEW.CategoryID  ||
                       ' Active='    || :NEW.Is_Active;

    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_record_id := :NEW.ProductID;
        v_old_val   := 'Name='       || :OLD.Name       ||
                       ' Price='     || :OLD.Unit_Price  ||
                       ' Active='    || :OLD.Is_Active;
        v_new_val   := 'Name='       || :NEW.Name       ||
                       ' Price='     || :NEW.Unit_Price  ||
                       ' Active='    || :NEW.Is_Active;

    ELSIF DELETING THEN
        v_operation := 'DELETE';
        v_record_id := :OLD.ProductID;
        v_old_val   := 'Name='       || :OLD.Name       ||
                       ' Price='     || :OLD.Unit_Price;
        v_new_val   := NULL;
    END IF;

    INSERT INTO Audit_Log (
        LogID, Table_Name, Operation, Record_ID,
        Changed_By, Old_Value, New_Value, Description
    )
    VALUES (
        seq_auditlog.NEXTVAL,
        'PRODUCTS', v_operation, v_record_id,
        USER, v_old_val, v_new_val,
        'Auto-logged by TRG_AUDIT_PRODUCTS'
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Never let audit failure block the main operation
        NULL;
END TRG_AUDIT_PRODUCTS;
/


-- ============================================================
-- TRIGGER 3: TRG_AUDIT_CATEGORY
-- AFTER UPDATE on Category
-- Specifically watches IS_ACTIVE changes (soft delete events)
-- ============================================================
CREATE OR REPLACE TRIGGER TRG_AUDIT_CATEGORY
AFTER UPDATE ON Category
FOR EACH ROW
DECLARE
    v_desc VARCHAR2(255);
BEGIN
    -- Build a meaningful description based on what changed
    IF :OLD.IS_ACTIVE = 1 AND :NEW.IS_ACTIVE = 0 THEN
        v_desc := 'SOFT DELETE: Category "' || :NEW.Name ||
                  '" deactivated. Products can sell, NOT restock.';
    ELSIF :OLD.IS_ACTIVE = 0 AND :NEW.IS_ACTIVE = 1 THEN
        v_desc := 'REACTIVATED: Category "' || :NEW.Name ||
                  '" is now active. Restocking allowed.';
    ELSE
        v_desc := 'UPDATE on Category "' || :NEW.Name || '"';
    END IF;

    INSERT INTO Audit_Log (
        LogID, Table_Name, Operation, Record_ID,
        Changed_By, Old_Value, New_Value, Description
    )
    VALUES (
        seq_auditlog.NEXTVAL,
        'CATEGORY', 'UPDATE', :NEW.CategoryID,
        USER,
        'Name=' || :OLD.Name || ' IS_ACTIVE=' || :OLD.IS_ACTIVE,
        'Name=' || :NEW.Name || ' IS_ACTIVE=' || :NEW.IS_ACTIVE,
        v_desc
    );

EXCEPTION
    WHEN OTHERS THEN
        NULL;
END TRG_AUDIT_CATEGORY;
/


-- ============================================================
-- TRIGGER 4: TRG_AUDIT_STOCK
-- AFTER UPDATE on Stock_Management
-- Logs every stock quantity change automatically
-- ============================================================
CREATE OR REPLACE TRIGGER TRG_AUDIT_STOCK
AFTER UPDATE ON Stock_Management
FOR EACH ROW
DECLARE
    v_prod_name Products.Name%TYPE;
BEGIN
    -- Get product name for readable log
    SELECT Name INTO v_prod_name
    FROM   Products
    WHERE  ProductID = :NEW.ProductID;

    INSERT INTO Audit_Log (
        LogID, Table_Name, Operation, Record_ID,
        Changed_By, Old_Value, New_Value, Description
    )
    VALUES (
        seq_auditlog.NEXTVAL,
        'STOCK_MANAGEMENT', 'UPDATE', :NEW.ProductID,
        USER,
        'Qty=' || :OLD.Quantity,
        'Qty=' || :NEW.Quantity,
        'Stock change for "' || v_prod_name ||
        '" | Delta: ' ||
        CASE WHEN :NEW.Quantity > :OLD.Quantity
             THEN '+' || (:NEW.Quantity - :OLD.Quantity)
             ELSE '-' || (:OLD.Quantity - :NEW.Quantity)
        END
    );

EXCEPTION
    WHEN OTHERS THEN
        NULL;
END TRG_AUDIT_STOCK;
/


-- ============================================================
-- TRIGGER 5: TRG_BLOCK_RESTOCK (ADVANCED)
-- BEFORE INSERT on Transaction_Items
-- Prevents RESTOCK transaction items if category is inactive
-- Acts as a database-level safety net
-- ============================================================
CREATE OR REPLACE TRIGGER TRG_BLOCK_RESTOCK
BEFORE INSERT ON Transaction_Items
FOR EACH ROW
DECLARE
    v_trans_type  Transactions.Trans_Type%TYPE;
    v_cat_active  Category.IS_ACTIVE%TYPE;
    v_cat_name    Category.Name%TYPE;
    v_prod_name   Products.Name%TYPE;
BEGIN
    -- Only check RESTOCK transactions
    SELECT Trans_Type
    INTO   v_trans_type
    FROM   Transactions
    WHERE  TransactionID = :NEW.TransactionID;

    IF v_trans_type = 'RESTOCK' THEN
        -- Check the product's category IS_ACTIVE status
        SELECT c.IS_ACTIVE, c.Name, p.Name
        INTO   v_cat_active, v_cat_name, v_prod_name
        FROM   Products  p
        JOIN   Category  c ON p.CategoryID = c.CategoryID
        WHERE  p.ProductID = :NEW.ProductID;

        IF v_cat_active = 0 THEN
            RAISE_APPLICATION_ERROR(-20050,
                'TRIGGER BLOCKED: Cannot restock "' || v_prod_name ||
                '". Category "' || v_cat_name ||
                '" is inactive (IS_ACTIVE=0). ' ||
                'This is enforced at database trigger level.');
        END IF;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20051,
            'TRG_BLOCK_RESTOCK: Product or Transaction not found.');
    WHEN OTHERS THEN
        RAISE;
END TRG_BLOCK_RESTOCK;
/


-- ============================================================
-- VERIFY: All 5 triggers created and enabled
-- ============================================================
SELECT Trigger_Name,
       Triggering_Event  AS Event,
       Table_Name,
       Trigger_Type      AS Type,
       Status
FROM   User_Triggers
WHERE  Trigger_Name IN (
    'TRG_UPDATE_STOCK',
    'TRG_AUDIT_PRODUCTS',
    'TRG_AUDIT_CATEGORY',
    'TRG_AUDIT_STOCK',
    'TRG_BLOCK_RESTOCK'
)
ORDER BY Trigger_Name;

-- Expected: 5 rows — all ENABLED


-- ============================================================
-- SAMPLE EXECUTIONS — TRIGGERS
-- ============================================================
SET SERVEROUTPUT ON;

-- ------------------------------------------------------------
-- TEST 1: TRG_AUDIT_PRODUCTS fires on product UPDATE
-- Update a product price and see audit log entry appear
-- ------------------------------------------------------------
DECLARE
    v_pid NUMBER;
BEGIN
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'USB-C Hub';
    UPDATE Products
    SET    Unit_Price = 1399.00
    WHERE  ProductID  = v_pid;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Updated USB-C Hub price to 1399.00');
END;
/

-- Verify audit log captured it
SELECT LogID, Operation, Old_Value, New_Value, Description
FROM   Audit_Log
WHERE  Table_Name = 'PRODUCTS'
ORDER BY LogID DESC
FETCH FIRST 1 ROWS ONLY;

-- Expected: UPDATE row showing old price 1299 → new price 1399


-- ------------------------------------------------------------
-- TEST 2: TRG_AUDIT_CATEGORY fires on soft delete
-- Soft delete Electronics and check audit log
-- ------------------------------------------------------------
DECLARE
    v_cid NUMBER;
BEGIN
    SELECT CategoryID INTO v_cid FROM Category WHERE Name = 'Electronics';
    UPDATE Category SET IS_ACTIVE = 0 WHERE CategoryID = v_cid;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Electronics category soft deleted via direct UPDATE');
END;
/

-- Verify audit log captured it
SELECT LogID, Operation, Old_Value, New_Value, Description
FROM   Audit_Log
WHERE  Table_Name = 'CATEGORY'
ORDER BY LogID DESC
FETCH FIRST 1 ROWS ONLY;

-- Expected: UPDATE row with SOFT DELETE description


-- ------------------------------------------------------------
-- TEST 3: TRG_BLOCK_RESTOCK fires when restocking
--         a product under now-inactive Electronics category
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
    v_tid NUMBER;
BEGIN
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'manager_priya';
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'Wireless Mouse';

    -- Insert transaction header manually to test trigger
    INSERT INTO Transactions (
        TransactionID, UserID, Trans_Type, Total_Amount, Notes
    )
    VALUES (
        seq_transactions.NEXTVAL, v_uid,
        'RESTOCK', 0, 'Trigger block test — restock inactive category'
    )
    RETURNING TransactionID INTO v_tid;

    -- This INSERT should be BLOCKED by TRG_BLOCK_RESTOCK
    INSERT INTO Transaction_Items (
        ItemID, TransactionID, ProductID, Quantity, Unit_Price
    )
    VALUES (
        seq_items.NEXTVAL, v_tid, v_pid, 10, 0
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ERROR: Should have been blocked!');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('BLOCKED by TRG_BLOCK_RESTOCK: ' || SQLERRM);
END;
/
-- Expected:
-- BLOCKED by TRG_BLOCK_RESTOCK: ORA-20050: TRIGGER BLOCKED:
-- Cannot restock "Wireless Mouse". Category "Electronics" is inactive.


-- ------------------------------------------------------------
-- TEST 4: TRG_UPDATE_STOCK fires on valid SALE
-- Sell 2x Basmati Rice — watch stock auto-update via trigger
-- ------------------------------------------------------------
DECLARE
    v_uid  NUMBER;
    v_pid  NUMBER;
    v_tid  NUMBER;
    v_qty_before NUMBER;
    v_qty_after  NUMBER;
BEGIN
    SELECT UserID    INTO v_uid FROM Users    WHERE Username  = 'staff_arjun';
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'Basmati Rice 5kg';

    SELECT Quantity INTO v_qty_before
    FROM   Stock_Management WHERE ProductID = v_pid;

    -- Insert transaction
    INSERT INTO Transactions (
        TransactionID, UserID, Trans_Type, Total_Amount, Notes
    )
    VALUES (
        seq_transactions.NEXTVAL, v_uid,
        'SALE', 640.00, 'Trigger test sale — 2x Basmati Rice'
    )
    RETURNING TransactionID INTO v_tid;

    -- TRG_UPDATE_STOCK fires here automatically
    INSERT INTO Transaction_Items (
        ItemID, TransactionID, ProductID, Quantity, Unit_Price
    )
    VALUES (seq_items.NEXTVAL, v_tid, v_pid, 2, 320.00);

    COMMIT;

    SELECT Quantity INTO v_qty_after
    FROM   Stock_Management WHERE ProductID = v_pid;

    DBMS_OUTPUT.PUT_LINE('Stock BEFORE sale: ' || v_qty_before);
    DBMS_OUTPUT.PUT_LINE('Stock AFTER  sale: ' || v_qty_after);
    DBMS_OUTPUT.PUT_LINE('Difference: -' || (v_qty_before - v_qty_after));
END;
/
-- Expected:
-- Stock BEFORE sale: 30
-- Stock AFTER  sale: 28
-- Difference: -2

-- TRG_AUDIT_STOCK also fires here — verify:
SELECT LogID, Old_Value, New_Value, Description
FROM   Audit_Log
WHERE  Table_Name = 'STOCK_MANAGEMENT'
ORDER BY LogID DESC
FETCH FIRST 1 ROWS ONLY;

-- Expected: Qty=30 → Qty=28 | Delta: -2


-- ------------------------------------------------------------
-- FINAL: Full Audit Log Review
-- ------------------------------------------------------------
SELECT LogID,
       Table_Name,
       Operation,
       Record_ID,
       Changed_By,
       Old_Value,
       New_Value,
       TO_CHAR(Change_Date, 'DD-MON HH24:MI:SS') AS Changed_At
FROM   Audit_Log
ORDER BY LogID;
