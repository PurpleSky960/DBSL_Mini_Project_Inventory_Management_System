-- ============================================================
-- FILE: 01_create_tables.sql
-- PROJECT: Inventory Management System
-- DATABASE: Oracle SQL Developer
-- FIX: Safe DROP order + CREATE order respecting FK dependencies
-- RUN: Press F5 (Run Script) — NOT F9 (Run Statement)
-- ============================================================

-- ------------------------------------------------------------
-- STEP 1: DROP TABLES in reverse FK dependency order
--         Child tables first, parent tables last
--         EXCEPTION WHEN OTHERS → skip if table doesn't exist
-- ------------------------------------------------------------
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Audit_Log        CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Reports           CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Transaction_Items CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Transactions      CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Stock_Management  CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Products          CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Suppliers         CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Category          CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE Users             CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- DROP SEQUENCES (if re-running)
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_users';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_category';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_suppliers';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_products';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_stock';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_transactions'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_items';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_reports';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_auditlog';     EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ============================================================
-- STEP 2: CREATE TABLES — parent tables first, children last
-- ============================================================

-- ------------------------------------------------------------
-- TABLE 1: USERS  (no FK — parent table)
-- ------------------------------------------------------------
CREATE TABLE Users (
    UserID      NUMBER(10)    PRIMARY KEY,
    Username    VARCHAR2(50)  NOT NULL,
    Password    VARCHAR2(255) NOT NULL,
    Email       VARCHAR2(100) NOT NULL UNIQUE,
    Role        VARCHAR2(20)  NOT NULL
                              CHECK (Role IN ('ADMIN','MANAGER','STAFF')),
    Is_Active   NUMBER(1)     DEFAULT 1 NOT NULL
                              CHECK (Is_Active IN (0,1)),
    Created_At  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);
/

CREATE SEQUENCE seq_users START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 2: CATEGORY  (no FK — parent table)
-- SOFT DELETE RULE:
--   IS_ACTIVE = 1 → Active:   products can be sold AND restocked
--   IS_ACTIVE = 0 → Inactive: products can be sold, CANNOT be restocked
-- ------------------------------------------------------------
CREATE TABLE Category (
    CategoryID  NUMBER(10)    PRIMARY KEY,
    Name        VARCHAR2(100) NOT NULL UNIQUE,
    Description VARCHAR2(255),
    IS_ACTIVE   NUMBER(1)     DEFAULT 1 NOT NULL
                              CHECK (IS_ACTIVE IN (0,1)),
    Created_At  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);
/

CREATE SEQUENCE seq_category START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 3: SUPPLIERS  (no FK — parent table)
-- ------------------------------------------------------------
CREATE TABLE Suppliers (
    SupplierID  NUMBER(10)    PRIMARY KEY,
    Name        VARCHAR2(100) NOT NULL,
    Contact     VARCHAR2(15)  NOT NULL,
    Email       VARCHAR2(100) UNIQUE,
    Address     VARCHAR2(255),
    Is_Active   NUMBER(1)     DEFAULT 1 NOT NULL
                              CHECK (Is_Active IN (0,1)),
    Created_At  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);
/

CREATE SEQUENCE seq_suppliers START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 4: PRODUCTS  (FK → Category, Suppliers)
-- ------------------------------------------------------------
CREATE TABLE Products (
    ProductID   NUMBER(10)    PRIMARY KEY,
    Name        VARCHAR2(100) NOT NULL,
    CategoryID  NUMBER(10)    NOT NULL,
    SupplierID  NUMBER(10)    NOT NULL,
    Unit_Price  NUMBER(10,2)  NOT NULL CHECK (Unit_Price > 0),
    Is_Active   NUMBER(1)     DEFAULT 1 NOT NULL
                              CHECK (Is_Active IN (0,1)),
    Created_At  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT fk_prod_category FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID),
    CONSTRAINT fk_prod_supplier FOREIGN KEY (SupplierID) REFERENCES Suppliers(SupplierID)
);
/

CREATE SEQUENCE seq_products START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 5: STOCK_MANAGEMENT  (FK → Products)
-- ------------------------------------------------------------
CREATE TABLE Stock_Management (
    StockID       NUMBER(10)  PRIMARY KEY,
    ProductID     NUMBER(10)  NOT NULL UNIQUE,
    Quantity      NUMBER(10)  DEFAULT 0  NOT NULL CHECK (Quantity >= 0),
    Restock_Level NUMBER(10)  DEFAULT 10 NOT NULL CHECK (Restock_Level >= 0),
    Last_Updated  TIMESTAMP   DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT fk_stock_product FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
/

CREATE SEQUENCE seq_stock START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 6: TRANSACTIONS  (FK → Users)
-- ------------------------------------------------------------
CREATE TABLE Transactions (
    TransactionID NUMBER(10)   PRIMARY KEY,
    UserID        NUMBER(10)   NOT NULL,
    Trans_Type    VARCHAR2(10) NOT NULL
                               CHECK (Trans_Type IN ('SALE','RETURN','RESTOCK')),
    Trans_Date    TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    Total_Amount  NUMBER(12,2) DEFAULT 0 NOT NULL CHECK (Total_Amount >= 0),
    Notes         VARCHAR2(255),
    CONSTRAINT fk_trans_user FOREIGN KEY (UserID) REFERENCES Users(UserID)
);
/

CREATE SEQUENCE seq_transactions START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 7: TRANSACTION_ITEMS  (FK → Transactions, Products)
-- ------------------------------------------------------------
CREATE TABLE Transaction_Items (
    ItemID        NUMBER(10)   PRIMARY KEY,
    TransactionID NUMBER(10)   NOT NULL,
    ProductID     NUMBER(10)   NOT NULL,
    Quantity      NUMBER(10)   NOT NULL CHECK (Quantity > 0),
    Unit_Price    NUMBER(10,2) NOT NULL CHECK (Unit_Price >= 0),
    Subtotal      NUMBER(12,2) GENERATED ALWAYS AS (Quantity * Unit_Price) VIRTUAL,
    CONSTRAINT fk_item_trans   FOREIGN KEY (TransactionID) REFERENCES Transactions(TransactionID),
    CONSTRAINT fk_item_product FOREIGN KEY (ProductID)     REFERENCES Products(ProductID)
);
/

CREATE SEQUENCE seq_items START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 8: REPORTS  (FK → Users)
-- ------------------------------------------------------------
CREATE TABLE Reports (
    ReportID     NUMBER(10)   PRIMARY KEY,
    Report_Type  VARCHAR2(50) NOT NULL
                              CHECK (Report_Type IN (
                                  'DAILY_SALES','STOCK_ALERT',
                                  'RESTOCK_SUMMARY','CATEGORY_SUMMARY'
                              )),
    Generated_By NUMBER(10)   NOT NULL,
    Generated_At TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    Report_Data  CLOB,
    CONSTRAINT fk_report_user FOREIGN KEY (Generated_By) REFERENCES Users(UserID)
);
/

CREATE SEQUENCE seq_reports START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ------------------------------------------------------------
-- TABLE 9: AUDIT_LOG  (no FK — standalone)
-- ------------------------------------------------------------
CREATE TABLE Audit_Log (
    LogID       NUMBER(10)    PRIMARY KEY,
    Table_Name  VARCHAR2(50)  NOT NULL,
    Operation   VARCHAR2(10)  NOT NULL
                              CHECK (Operation IN ('INSERT','UPDATE','DELETE','SELECT')),
    Record_ID   NUMBER(10),
    Changed_By  VARCHAR2(50)  DEFAULT USER NOT NULL,
    Change_Date TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    Old_Value   VARCHAR2(4000),
    New_Value   VARCHAR2(4000),
    Description VARCHAR2(255)
);
/

CREATE SEQUENCE seq_auditlog START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
/

-- ============================================================
-- STEP 3: VERIFY — Must return exactly 9 rows
-- ============================================================
SELECT Table_Name
FROM   User_Tables
WHERE  Table_Name IN (
    'USERS','CATEGORY','SUPPLIERS','PRODUCTS',
    'STOCK_MANAGEMENT','TRANSACTIONS',
    'TRANSACTION_ITEMS','REPORTS','AUDIT_LOG'
)
ORDER BY Table_Name;

-- Expected output:
-- AUDIT_LOG
-- CATEGORY
-- PRODUCTS
-- REPORTS
-- STOCK_MANAGEMENT
-- SUPPLIERS
-- TRANSACTION_ITEMS
-- TRANSACTIONS
-- USERS
-- 9 rows selected.
