package com.dbsl.ims.repository;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.List;
import java.util.Map;

@Repository
public class InventoryRepository {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    // ACTION: Calls the PL/SQL Package to process a sale
    public void processSale(Long userId, Long productId, int quantity, String notes) {
        String sql = "CALL PKG_USER_OPS.Process_Sale(?, ?, ?, ?)";
        // jdbcTemplate.update() is used for INSERT, UPDATE, DELETE, and PROCEDURE CALLS
        jdbcTemplate.update(sql, userId, productId, quantity, notes);
    }

    // ACTION: Admin restocking a product
    public void restockProduct(Long userId, Long productId, int quantity) {
        String sql = "CALL PKG_ADMIN_OPS.Restock_Product(?, ?, ?)";
        jdbcTemplate.update(sql, userId, productId, quantity);
    }

    // FETCH: Gets the live restocking alerts for the React dashboard
    public List<Map<String, Object>> getRestockAlerts() {
        // This is query R1 copied straight from your teammate's system_flow.sql
        String sql = "SELECT p.Name AS Product, c.Name AS Category, sm.Quantity AS Current_Stock, " +
                "sm.Restock_Level, (sm.Restock_Level - sm.Quantity) AS Units_Needed, " +
                "s.Name AS Supplier, s.Contact AS Supplier_Contact " +
                "FROM Products p " +
                "JOIN Stock_Management sm ON p.ProductID = sm.ProductID " +
                "JOIN Category c ON p.CategoryID = c.CategoryID " +
                "JOIN Suppliers s ON p.SupplierID = s.SupplierID " +
                "WHERE sm.Quantity < sm.Restock_Level AND c.IS_ACTIVE = 1 " +
                "ORDER BY Units_Needed DESC";

        // queryForList automatically turns the SQL rows into a list of JSON-like maps!
        return jdbcTemplate.queryForList(sql);
    }

    // --- FETCH QUERIES (GET) ---

    // Gets the full product list for the dashboards
    public List<Map<String, Object>> getAllProducts() {
        String sql = "SELECT p.ProductID, c.CategoryID, p.Name AS Product, c.Name AS Category, c.IS_ACTIVE AS Cat_Active, " +
                "s.Name AS Supplier, p.Unit_Price, sm.Quantity AS Stock_Qty, sm.Restock_Level " +
                "FROM Products p " +
                "JOIN Category c ON p.CategoryID = c.CategoryID " +
                "JOIN Suppliers s ON p.SupplierID = s.SupplierID " +
                "JOIN Stock_Management sm ON p.ProductID = sm.ProductID " +
                "ORDER BY c.Name, p.Name";
        return jdbcTemplate.queryForList(sql);
    }

    // Gets transaction history for a specific user
    public List<Map<String, Object>> getTransactionHistory(Long userId) {
        String sql = "SELECT t.TransactionID, t.Trans_Type, p.Name AS Product_Name, " +
                "ti.Quantity, ti.Subtotal, t.Trans_Date " +
                "FROM Transactions t " +
                "JOIN Transaction_Items ti ON t.TransactionID = ti.TransactionID " +
                "JOIN Products p ON ti.ProductID = p.ProductID " +
                "WHERE t.UserID = ? ORDER BY t.Trans_Date DESC";
        return jdbcTemplate.queryForList(sql, userId);
    }


    // --- USER OPERATIONS (POST) ---

    public void processReturn(Long userId, Long productId, int quantity, String notes) {
        jdbcTemplate.update("CALL PKG_USER_OPS.Process_Return(?, ?, ?, ?)", userId, productId, quantity, notes);
    }


    // --- ADMIN OPERATIONS (POST/PUT) ---

    public void addProduct(String name, Long categoryId, Long supplierId, double price, int initStock, int restockLvl) {
        jdbcTemplate.update("CALL PKG_ADMIN_OPS.Add_Product(?, ?, ?, ?, ?, ?)",
                name, categoryId, supplierId, price, initStock, restockLvl);
    }

    public void addSupplier(String name, String contact, String email, String address) {
        jdbcTemplate.update("CALL PKG_ADMIN_OPS.Add_Supplier(?, ?, ?, ?)", name, contact, email, address);
    }

    public void softDeleteCategory(Long categoryId) {
        jdbcTemplate.update("CALL PKG_ADMIN_OPS.Soft_Delete_Category(?)", categoryId);
    }

    // Reactivate a soft-deleted category
    public void reactivateCategory(Long categoryId) {
        String sql = "UPDATE Category SET IS_ACTIVE = 1 WHERE CategoryID = ?";
        jdbcTemplate.update(sql, categoryId);
    }

    // --- AUTHENTICATION ---
    public Map<String, Object> login(String email, String password) {
        // Checking if the user exists, matches the password, and is active
        String sql = "SELECT UserID, Username, Role FROM Users WHERE Email = ? AND Password = ? AND Is_Active = 1";
        try {
            // queryForMap expects exactly ONE row. If it finds 0, it throws an exception.
            return jdbcTemplate.queryForMap(sql, email, password);
        } catch (EmptyResultDataAccessException e) {
            throw new RuntimeException("Invalid email or password, or account is disabled.");
        }
    }

    // --- PASSWORD MANAGEMENT ---
    public boolean changePassword(Long userId, String oldPassword, String newPassword) {
        // First check if the old password matches
        String checkSql = "SELECT COUNT(*) FROM Users WHERE UserID = ? AND Password = ?";
        Integer count = jdbcTemplate.queryForObject(checkSql, Integer.class, userId, oldPassword);

        if (count != null && count > 0) {
            // If it matches, update to the new password
            String updateSql = "UPDATE Users SET Password = ? WHERE UserID = ?";
            jdbcTemplate.update(updateSql, newPassword, userId);
            return true;
        }
        return false;
    }

    // Gets suppliers for the Add Product dropdown
    public List<Map<String, Object>> getSuppliers() {
        return jdbcTemplate.queryForList("SELECT SupplierID, Name FROM Suppliers WHERE Is_Active = 1");
    }

    // Gets all categories directly from the table (including empty ones)
    public List<Map<String, Object>> getAllCategories() {
        return jdbcTemplate.queryForList("SELECT CategoryID, Name, IS_ACTIVE FROM Category ORDER BY Name");
    }

    // Creates a brand new category
    public void addCategory(String name, String description) {
        String sql = "INSERT INTO Category (CategoryID, Name, Description, IS_ACTIVE) VALUES (seq_category.NEXTVAL, ?, ?, 1)";
        jdbcTemplate.update(sql, name, description);
    }

    // --- USER MANAGEMENT ---
    public List<Map<String, Object>> getAllUsers() {
        return jdbcTemplate.queryForList("SELECT UserID, Username, Email, Role, Is_Active FROM Users ORDER BY UserID");
    }

    public void addUser(String username, String password, String email, String role) {
        String sql = "INSERT INTO Users (UserID, Username, Password, Email, Role, Is_Active) VALUES (seq_users.NEXTVAL, ?, ?, ?, ?, 1)";
        jdbcTemplate.update(sql, username, password, email, role);
    }

    public void toggleUserStatus(Long userId, int status) {
        jdbcTemplate.update("UPDATE Users SET Is_Active = ? WHERE UserID = ?", status, userId);
    }

    // --- AUDIT REPORTS ---
    public List<Map<String, Object>> getAuditLog() {
        String sql = "SELECT LogID, Table_Name, Operation, Changed_By, Old_Value, New_Value, " +
                "TO_CHAR(Change_Date, 'YYYY-MM-DD HH24:MI:SS') AS Change_Date, Description " +
                "FROM Audit_Log ORDER BY LogID DESC FETCH FIRST 50 ROWS ONLY";
        return jdbcTemplate.queryForList(sql);
    }
}