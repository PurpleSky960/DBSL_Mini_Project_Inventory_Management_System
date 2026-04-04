-- ============================================================
-- FILE: 06_packages.sql
-- PROJECT: Inventory Management System
-- DESCRIPTION: PL/SQL Packages
--   1. PKG_ADMIN_OPS — Add_Product, Add_Supplier,
--                      Restock_Product, Soft_Delete_Category
--   2. PKG_USER_OPS  — Process_Sale, Process_Return,
--                      View_Transactions
-- DATABASE: Oracle SQL Developer
-- RUN: F5 (Run Script)
-- ============================================================


-- ============================================================
-- PACKAGE 1: PKG_ADMIN_OPS
-- For ADMIN / MANAGER role operations
-- ============================================================

-- ------------------------------------------------------------
-- PACKAGE SPEC — declares all public procedures/functions
-- ------------------------------------------------------------
CREATE OR REPLACE PACKAGE PKG_ADMIN_OPS AS

    -- Add a new product to the system
    PROCEDURE Add_Product (
        p_name        IN Products.Name%TYPE,
        p_category_id IN Products.CategoryID%TYPE,
        p_supplier_id IN Products.SupplierID%TYPE,
        p_unit_price  IN Products.Unit_Price%TYPE,
        p_init_stock  IN NUMBER DEFAULT 0,
        p_restock_lvl IN NUMBER DEFAULT 10
    );

    -- Add a new supplier
    PROCEDURE Add_Supplier (
        p_name    IN Suppliers.Name%TYPE,
        p_contact IN Suppliers.Contact%TYPE,
        p_email   IN Suppliers.Email%TYPE,
        p_address IN Suppliers.Address%TYPE DEFAULT NULL
    );

    -- Restock a product (blocked if category inactive)
    PROCEDURE Restock_Product (
        p_user_id    IN Users.UserID%TYPE,
        p_product_id IN Products.ProductID%TYPE,
        p_quantity   IN NUMBER
    );

    -- Soft delete a category (IS_ACTIVE = 0)
    PROCEDURE Soft_Delete_Category (
        p_category_id IN Category.CategoryID%TYPE
    );

END PKG_ADMIN_OPS;
/


-- ------------------------------------------------------------
-- PACKAGE BODY — implements all procedures
-- ------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PKG_ADMIN_OPS AS

    -- ----------------------------------------------------------
    -- Add_Product
    -- Inserts product + initial stock row
    -- Validates category IS_ACTIVE before allowing add
    -- ----------------------------------------------------------
    PROCEDURE Add_Product (
        p_name        IN Products.Name%TYPE,
        p_category_id IN Products.CategoryID%TYPE,
        p_supplier_id IN Products.SupplierID%TYPE,
        p_unit_price  IN Products.Unit_Price%TYPE,
        p_init_stock  IN NUMBER DEFAULT 0,
        p_restock_lvl IN NUMBER DEFAULT 10
    )
    AS
        v_cat_active  Category.IS_ACTIVE%TYPE;
        v_cat_name    Category.Name%TYPE;
        v_new_pid     Products.ProductID%TYPE;
    BEGIN
        -- Validate category exists and is active
        BEGIN
            SELECT IS_ACTIVE, Name
            INTO   v_cat_active, v_cat_name
            FROM   Category
            WHERE  CategoryID = p_category_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20020,
                    'ERROR: Category ID ' || p_category_id ||
                    ' does not exist.');
        END;

        IF v_cat_active = 0 THEN
            RAISE_APPLICATION_ERROR(-20021,
                'ERROR: Cannot add product to inactive category "' ||
                v_cat_name || '". Activate the category first.');
        END IF;

        -- Validate supplier exists
        DECLARE
            v_sup_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_sup_count
            FROM   Suppliers
            WHERE  SupplierID = p_supplier_id
            AND    Is_Active  = 1;

            IF v_sup_count = 0 THEN
                RAISE_APPLICATION_ERROR(-20022,
                    'ERROR: Supplier ID ' || p_supplier_id ||
                    ' not found or inactive.');
            END IF;
        END;

        -- Insert product
        INSERT INTO Products (
            ProductID, Name, CategoryID, SupplierID, Unit_Price
        )
        VALUES (
            seq_products.NEXTVAL,
            p_name, p_category_id, p_supplier_id, p_unit_price
        )
        RETURNING ProductID INTO v_new_pid;

        -- Insert initial stock row
        INSERT INTO Stock_Management (
            StockID, ProductID, Quantity, Restock_Level
        )
        VALUES (
            seq_stock.NEXTVAL, v_new_pid,
            p_init_stock, p_restock_lvl
        );

        -- Audit log
        INSERT INTO Audit_Log (
            LogID, Table_Name, Operation, Record_ID,
            Changed_By, New_Value, Description
        )
        VALUES (
            seq_auditlog.NEXTVAL,
            'PRODUCTS', 'INSERT', v_new_pid, USER,
            'Name=' || p_name || ' Price=' || p_unit_price,
            'New product added via PKG_ADMIN_OPS.Add_Product'
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Product "' || p_name ||
            '" added. ProductID=' || v_new_pid ||
            ' | Init Stock=' || p_init_stock);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('FAILED Add_Product: ' || SQLERRM);
            RAISE;
    END Add_Product;


    -- ----------------------------------------------------------
    -- Add_Supplier
    -- Inserts a new supplier record
    -- ----------------------------------------------------------
    PROCEDURE Add_Supplier (
        p_name    IN Suppliers.Name%TYPE,
        p_contact IN Suppliers.Contact%TYPE,
        p_email   IN Suppliers.Email%TYPE,
        p_address IN Suppliers.Address%TYPE DEFAULT NULL
    )
    AS
        v_new_sid Suppliers.SupplierID%TYPE;
    BEGIN
        -- Check duplicate name
        DECLARE
            v_count NUMBER;
        BEGIN
            SELECT COUNT(*) INTO v_count
            FROM   Suppliers WHERE Name = p_name;
            IF v_count > 0 THEN
                RAISE_APPLICATION_ERROR(-20023,
                    'ERROR: Supplier "' || p_name ||
                    '" already exists.');
            END IF;
        END;

        INSERT INTO Suppliers (
            SupplierID, Name, Contact, Email, Address
        )
        VALUES (
            seq_suppliers.NEXTVAL,
            p_name, p_contact, p_email, p_address
        )
        RETURNING SupplierID INTO v_new_sid;

        -- Audit log
        INSERT INTO Audit_Log (
            LogID, Table_Name, Operation, Record_ID,
            Changed_By, New_Value, Description
        )
        VALUES (
            seq_auditlog.NEXTVAL,
            'SUPPLIERS', 'INSERT', v_new_sid, USER,
            'Name=' || p_name,
            'New supplier added via PKG_ADMIN_OPS.Add_Supplier'
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Supplier "' || p_name ||
            '" added. SupplierID=' || v_new_sid);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('FAILED Add_Supplier: ' || SQLERRM);
            RAISE;
    END Add_Supplier;


    -- ----------------------------------------------------------
    -- Restock_Product
    -- Delegates to standalone procedure logic
    -- Blocks restock if category IS_ACTIVE = 0
    -- ----------------------------------------------------------
    PROCEDURE Restock_Product (
        p_user_id    IN Users.UserID%TYPE,
        p_product_id IN Products.ProductID%TYPE,
        p_quantity   IN NUMBER
    )
    AS
        v_cat_active  Category.IS_ACTIVE%TYPE;
        v_cat_name    Category.Name%TYPE;
        v_prod_name   Products.Name%TYPE;
        v_old_qty     Stock_Management.Quantity%TYPE;
        v_new_qty     Stock_Management.Quantity%TYPE;
        v_trans_id    Transactions.TransactionID%TYPE;
    BEGIN
        -- Fetch product + category info
        BEGIN
            SELECT p.Name, c.Name, c.IS_ACTIVE
            INTO   v_prod_name, v_cat_name, v_cat_active
            FROM   Products p
            JOIN   Category c ON p.CategoryID = c.CategoryID
            WHERE  p.ProductID = p_product_id
            AND    p.Is_Active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20024,
                    'ERROR: Product ID ' || p_product_id ||
                    ' not found or inactive.');
        END;

        -- Core business rule: block if inactive category
        IF v_cat_active = 0 THEN
            RAISE_APPLICATION_ERROR(-20025,
                'ERROR: Cannot restock "' || v_prod_name ||
                '". Category "' || v_cat_name ||
                '" is inactive (IS_ACTIVE=0).');
        END IF;

        -- Get and lock current stock
        SELECT Quantity INTO v_old_qty
        FROM   Stock_Management
        WHERE  ProductID = p_product_id
        FOR UPDATE;

        -- Update stock
        UPDATE Stock_Management
        SET    Quantity     = Quantity + p_quantity,
               Last_Updated = SYSTIMESTAMP
        WHERE  ProductID    = p_product_id;

        v_new_qty := v_old_qty + p_quantity;

        -- Insert transaction
        INSERT INTO Transactions (
            TransactionID, UserID, Trans_Type, Total_Amount, Notes
        )
        VALUES (
            seq_transactions.NEXTVAL, p_user_id,
            'RESTOCK', 0,
            'PKG Restock: ' || v_prod_name || ' +' || p_quantity
        )
        RETURNING TransactionID INTO v_trans_id;

        INSERT INTO Transaction_Items (
            ItemID, TransactionID, ProductID, Quantity, Unit_Price
        )
        VALUES (
            seq_items.NEXTVAL, v_trans_id,
            p_product_id, p_quantity, 0
        );

        -- Audit log
        INSERT INTO Audit_Log (
            LogID, Table_Name, Operation, Record_ID,
            Changed_By, Old_Value, New_Value, Description
        )
        VALUES (
            seq_auditlog.NEXTVAL,
            'STOCK_MANAGEMENT', 'UPDATE', p_product_id, USER,
            'Qty=' || v_old_qty, 'Qty=' || v_new_qty,
            'Restock via PKG_ADMIN_OPS for: ' || v_prod_name
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Restocked "' || v_prod_name ||
            '" | +' || p_quantity ||
            ' | New Stock: ' || v_new_qty);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('FAILED Restock_Product: ' || SQLERRM);
            RAISE;
    END Restock_Product;


    -- ----------------------------------------------------------
    -- Soft_Delete_Category
    -- Sets IS_ACTIVE = 0 — does NOT delete the row
    -- ----------------------------------------------------------
    PROCEDURE Soft_Delete_Category (
        p_category_id IN Category.CategoryID%TYPE
    )
    AS
        v_cat_name   Category.Name%TYPE;
        v_is_active  Category.IS_ACTIVE%TYPE;
        v_prod_count NUMBER;
    BEGIN
        BEGIN
            SELECT Name, IS_ACTIVE
            INTO   v_cat_name, v_is_active
            FROM   Category
            WHERE  CategoryID = p_category_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20026,
                    'ERROR: Category ID ' || p_category_id ||
                    ' does not exist.');
        END;

        IF v_is_active = 0 THEN
            DBMS_OUTPUT.PUT_LINE('INFO: Category "' || v_cat_name ||
                '" is already inactive.');
            RETURN;
        END IF;

        SELECT COUNT(*) INTO v_prod_count
        FROM   Products
        WHERE  CategoryID = p_category_id AND Is_Active = 1;

        UPDATE Category
        SET    IS_ACTIVE = 0
        WHERE  CategoryID = p_category_id;

        INSERT INTO Audit_Log (
            LogID, Table_Name, Operation, Record_ID,
            Changed_By, Old_Value, New_Value, Description
        )
        VALUES (
            seq_auditlog.NEXTVAL,
            'CATEGORY', 'UPDATE', p_category_id, USER,
            'IS_ACTIVE=1', 'IS_ACTIVE=0',
            'Soft delete via PKG_ADMIN_OPS: "' || v_cat_name ||
            '" | ' || v_prod_count || ' product(s) affected'
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: Category "' || v_cat_name ||
            '" deactivated. ' || v_prod_count ||
            ' product(s) — sale OK, restock BLOCKED.');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('FAILED Soft_Delete_Category: ' || SQLERRM);
            RAISE;
    END Soft_Delete_Category;

END PKG_ADMIN_OPS;
/


-- ============================================================
-- PACKAGE 2: PKG_USER_OPS
-- For STAFF role operations
-- ============================================================

-- ------------------------------------------------------------
-- PACKAGE SPEC
-- ------------------------------------------------------------
CREATE OR REPLACE PACKAGE PKG_USER_OPS AS

    -- Process a sale transaction
    PROCEDURE Process_Sale (
        p_user_id    IN Users.UserID%TYPE,
        p_product_id IN Products.ProductID%TYPE,
        p_quantity   IN NUMBER,
        p_notes      IN VARCHAR2 DEFAULT NULL
    );

    -- Process a return transaction
    PROCEDURE Process_Return (
        p_user_id    IN Users.UserID%TYPE,
        p_product_id IN Products.ProductID%TYPE,
        p_quantity   IN NUMBER,
        p_notes      IN VARCHAR2 DEFAULT NULL
    );

    -- View transactions for a user (cursor-based report)
    PROCEDURE View_Transactions (
        p_user_id    IN Users.UserID%TYPE,
        p_trans_type IN VARCHAR2 DEFAULT NULL  -- NULL = all types
    );

END PKG_USER_OPS;
/


-- ------------------------------------------------------------
-- PACKAGE BODY
-- ------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PKG_USER_OPS AS

    -- ----------------------------------------------------------
    -- Process_Sale
    -- Validates stock → deducts → records transaction
    -- ----------------------------------------------------------
    PROCEDURE Process_Sale (
        p_user_id    IN Users.UserID%TYPE,
        p_product_id IN Products.ProductID%TYPE,
        p_quantity   IN NUMBER,
        p_notes      IN VARCHAR2 DEFAULT NULL
    )
    AS
        v_unit_price  Products.Unit_Price%TYPE;
        v_prod_name   Products.Name%TYPE;
        v_curr_stock  Stock_Management.Quantity%TYPE;
        v_total       NUMBER(12,2);
        v_trans_id    Transactions.TransactionID%TYPE;
    BEGIN
        -- Validate product
        BEGIN
            SELECT Unit_Price, Name INTO v_unit_price, v_prod_name
            FROM   Products
            WHERE  ProductID = p_product_id AND Is_Active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20030,
                    'ERROR: Product ID ' || p_product_id ||
                    ' not found or inactive.');
        END;

        -- Check and lock stock
        SELECT Quantity INTO v_curr_stock
        FROM   Stock_Management
        WHERE  ProductID = p_product_id
        FOR UPDATE;

        -- Validate sufficient stock
        IF v_curr_stock < p_quantity THEN
            RAISE_APPLICATION_ERROR(-20031,
                'ERROR: Insufficient stock for "' || v_prod_name ||
                '". Available: ' || v_curr_stock ||
                ', Requested: ' || p_quantity);
        END IF;

        -- Deduct stock
        UPDATE Stock_Management
        SET    Quantity     = Quantity - p_quantity,
               Last_Updated = SYSTIMESTAMP
        WHERE  ProductID    = p_product_id;

        v_total := v_unit_price * p_quantity;

        -- Insert transaction
        INSERT INTO Transactions (
            TransactionID, UserID, Trans_Type, Total_Amount, Notes
        )
        VALUES (
            seq_transactions.NEXTVAL, p_user_id,
            'SALE', v_total,
            NVL(p_notes, 'Sale: ' || v_prod_name)
        )
        RETURNING TransactionID INTO v_trans_id;

        INSERT INTO Transaction_Items (
            ItemID, TransactionID, ProductID, Quantity, Unit_Price
        )
        VALUES (
            seq_items.NEXTVAL, v_trans_id,
            p_product_id, p_quantity, v_unit_price
        );

        -- Audit
        INSERT INTO Audit_Log (
            LogID, Table_Name, Operation, Record_ID,
            Changed_By, New_Value, Description
        )
        VALUES (
            seq_auditlog.NEXTVAL,
            'TRANSACTIONS', 'INSERT', v_trans_id, USER,
            'SALE Qty=' || p_quantity || ' Total=' || v_total,
            'Sale via PKG_USER_OPS: ' || v_prod_name
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: SALE — "' || v_prod_name ||
            '" x' || p_quantity ||
            ' | Total: Rs.' || v_total ||
            ' | TxnID: ' || v_trans_id);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('FAILED Process_Sale: ' || SQLERRM);
            RAISE;
    END Process_Sale;


    -- ----------------------------------------------------------
    -- Process_Return
    -- Adds stock back → records return transaction
    -- ----------------------------------------------------------
    PROCEDURE Process_Return (
        p_user_id    IN Users.UserID%TYPE,
        p_product_id IN Products.ProductID%TYPE,
        p_quantity   IN NUMBER,
        p_notes      IN VARCHAR2 DEFAULT NULL
    )
    AS
        v_unit_price Products.Unit_Price%TYPE;
        v_prod_name  Products.Name%TYPE;
        v_total      NUMBER(12,2);
        v_trans_id   Transactions.TransactionID%TYPE;
    BEGIN
        BEGIN
            SELECT Unit_Price, Name INTO v_unit_price, v_prod_name
            FROM   Products
            WHERE  ProductID = p_product_id AND Is_Active = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20032,
                    'ERROR: Product ID ' || p_product_id ||
                    ' not found or inactive.');
        END;

        -- Add stock back
        UPDATE Stock_Management
        SET    Quantity     = Quantity + p_quantity,
               Last_Updated = SYSTIMESTAMP
        WHERE  ProductID    = p_product_id;

        v_total := v_unit_price * p_quantity;

        INSERT INTO Transactions (
            TransactionID, UserID, Trans_Type, Total_Amount, Notes
        )
        VALUES (
            seq_transactions.NEXTVAL, p_user_id,
            'RETURN', v_total,
            NVL(p_notes, 'Return: ' || v_prod_name)
        )
        RETURNING TransactionID INTO v_trans_id;

        INSERT INTO Transaction_Items (
            ItemID, TransactionID, ProductID, Quantity, Unit_Price
        )
        VALUES (
            seq_items.NEXTVAL, v_trans_id,
            p_product_id, p_quantity, v_unit_price
        );

        INSERT INTO Audit_Log (
            LogID, Table_Name, Operation, Record_ID,
            Changed_By, New_Value, Description
        )
        VALUES (
            seq_auditlog.NEXTVAL,
            'TRANSACTIONS', 'INSERT', v_trans_id, USER,
            'RETURN Qty=' || p_quantity || ' Total=' || v_total,
            'Return via PKG_USER_OPS: ' || v_prod_name
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('SUCCESS: RETURN — "' || v_prod_name ||
            '" x' || p_quantity ||
            ' | Refund: Rs.' || v_total ||
            ' | TxnID: ' || v_trans_id);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('FAILED Process_Return: ' || SQLERRM);
            RAISE;
    END Process_Return;


    -- ----------------------------------------------------------
    -- View_Transactions
    -- Cursor-based report — filter by user and optional type
    -- ----------------------------------------------------------
    PROCEDURE View_Transactions (
        p_user_id    IN Users.UserID%TYPE,
        p_trans_type IN VARCHAR2 DEFAULT NULL
    )
    AS
        CURSOR c_user_trans IS
            SELECT  t.TransactionID,
                    t.Trans_Type,
                    p.Name          AS Product_Name,
                    ti.Quantity,
                    ti.Subtotal,
                    t.Trans_Date
            FROM    Transactions      t
            JOIN    Transaction_Items ti ON t.TransactionID = ti.TransactionID
            JOIN    Products          p  ON ti.ProductID    = p.ProductID
            WHERE   t.UserID = p_user_id
            AND    (p_trans_type IS NULL OR t.Trans_Type = p_trans_type)
            ORDER BY t.Trans_Date DESC;

        v_username   Users.Username%TYPE;
        v_count      NUMBER := 0;
        v_total      NUMBER := 0;
    BEGIN
        SELECT Username INTO v_username
        FROM   Users WHERE UserID = p_user_id;

        DBMS_OUTPUT.PUT_LINE('==============================================');
        DBMS_OUTPUT.PUT_LINE('  TRANSACTIONS FOR: ' || v_username ||
            CASE WHEN p_trans_type IS NOT NULL
                 THEN ' [' || p_trans_type || ']'
                 ELSE ' [ALL]' END);
        DBMS_OUTPUT.PUT_LINE('==============================================');

        FOR v_rec IN c_user_trans LOOP
            v_count := v_count + 1;
            v_total := v_total + NVL(v_rec.Subtotal, 0);
            DBMS_OUTPUT.PUT_LINE(
                'TxnID:'    || RPAD(v_rec.TransactionID, 5) ||
                ' Type:'    || RPAD(v_rec.Trans_Type,     9) ||
                ' Product:' || RPAD(v_rec.Product_Name,  23) ||
                ' Qty:'     || RPAD(v_rec.Quantity,        5) ||
                ' Amount: Rs.' || NVL(v_rec.Subtotal, 0)
            );
        END LOOP;

        DBMS_OUTPUT.PUT_LINE('----------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Total Transactions: ' || v_count ||
            ' | Total Value: Rs.' || v_total);

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: User ID ' ||
                p_user_id || ' not found.');
    END View_Transactions;

END PKG_USER_OPS;
/


-- ============================================================
-- VERIFY: Both packages compiled
-- ============================================================
SELECT Object_Name, Object_Type, Status
FROM   User_Objects
WHERE  Object_Type IN ('PACKAGE', 'PACKAGE BODY')
AND    Object_Name IN ('PKG_ADMIN_OPS', 'PKG_USER_OPS')
ORDER BY Object_Name, Object_Type;

-- Expected: 4 rows — PACKAGE + PACKAGE BODY for each, all VALID


-- ============================================================
-- SAMPLE EXECUTIONS
-- ============================================================
SET SERVEROUTPUT ON;

-- ------------------------------------------------------------
-- TEST 1: Add a new supplier
-- ------------------------------------------------------------
BEGIN
    PKG_ADMIN_OPS.Add_Supplier(
        p_name    => 'QuickShip Traders',
        p_contact => '9111222333',
        p_email   => 'quickship@mail.com',
        p_address => 'Pune, Maharashtra'
    );
END;
/
-- Expected: SUCCESS: Supplier "QuickShip Traders" added. SupplierID=5

-- ------------------------------------------------------------
-- TEST 2: Add a new product (active category)
-- ------------------------------------------------------------
DECLARE
    v_cid NUMBER;
    v_sid NUMBER;
BEGIN
    SELECT CategoryID INTO v_cid FROM Category  WHERE Name = 'Electronics';
    SELECT SupplierID INTO v_sid FROM Suppliers WHERE Name = 'QuickShip Traders';
    PKG_ADMIN_OPS.Add_Product(
        p_name        => 'Mechanical Keyboard',
        p_category_id => v_cid,
        p_supplier_id => v_sid,
        p_unit_price  => 3499.00,
        p_init_stock  => 15,
        p_restock_lvl => 5
    );
END;
/
-- Expected: SUCCESS: Product "Mechanical Keyboard" added.

-- ------------------------------------------------------------
-- TEST 3: Add product to INACTIVE category (should FAIL)
-- ------------------------------------------------------------
DECLARE
    v_cid NUMBER;
    v_sid NUMBER;
BEGIN
    SELECT CategoryID INTO v_cid FROM Category  WHERE Name = 'Discontinued';
    SELECT SupplierID INTO v_sid FROM Suppliers WHERE Name = 'OldStock Suppliers';
    PKG_ADMIN_OPS.Add_Product(
        p_name        => 'Old VGA Cable',
        p_category_id => v_cid,
        p_supplier_id => v_sid,
        p_unit_price  => 99.00
    );
END;
/
-- Expected: FAILED: ORA-20021: Cannot add product to inactive category

-- ------------------------------------------------------------
-- TEST 4: Restock via package (active category)
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
BEGIN
    SELECT UserID   INTO v_uid FROM Users    WHERE Username  = 'manager_priya';
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'Bluetooth Headphones';
    PKG_ADMIN_OPS.Restock_Product(v_uid, v_pid, 25);
END;
/
-- Expected: SUCCESS: Restocked "Bluetooth Headphones" | +25

-- ------------------------------------------------------------
-- TEST 5: Soft delete Stationery category via package
-- ------------------------------------------------------------
DECLARE
    v_cid NUMBER;
BEGIN
    SELECT CategoryID INTO v_cid FROM Category WHERE Name = 'Stationery';
    PKG_ADMIN_OPS.Soft_Delete_Category(v_cid);
END;
/
-- Expected: SUCCESS: Category "Stationery" deactivated. 2 product(s) affected.

-- ------------------------------------------------------------
-- TEST 6: Process a SALE via PKG_USER_OPS
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
BEGIN
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'staff_arjun';
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'USB-C Hub';
    PKG_USER_OPS.Process_Sale(v_uid, v_pid, 3, 'Sale of 3x USB-C Hub');
END;
/
-- Expected: SUCCESS: SALE — "USB-C Hub" x3 | Total: Rs.3897

-- ------------------------------------------------------------
-- TEST 7: Process a RETURN via PKG_USER_OPS
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
    v_pid NUMBER;
BEGIN
    SELECT UserID    INTO v_uid FROM Users    WHERE Username = 'staff_meera';
    SELECT ProductID INTO v_pid FROM Products WHERE Name = 'USB-C Hub';
    PKG_USER_OPS.Process_Return(v_uid, v_pid, 1, 'Return of 1x USB-C Hub');
END;
/
-- Expected: SUCCESS: RETURN — "USB-C Hub" x1 | Refund: Rs.1299

-- ------------------------------------------------------------
-- TEST 8: View transactions for staff_arjun (all types)
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
BEGIN
    SELECT UserID INTO v_uid FROM Users WHERE Username = 'staff_arjun';
    PKG_USER_OPS.View_Transactions(v_uid);
END;
/

-- ------------------------------------------------------------
-- TEST 9: View only SALE transactions for staff_arjun
-- ------------------------------------------------------------
DECLARE
    v_uid NUMBER;
BEGIN
    SELECT UserID INTO v_uid FROM Users WHERE Username = 'staff_arjun';
    PKG_USER_OPS.View_Transactions(v_uid, 'SALE');
END;
/
