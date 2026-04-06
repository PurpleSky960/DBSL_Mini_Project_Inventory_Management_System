package com.dbsl.ims.controller;

import com.dbsl.ims.repository.InventoryRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/inventory")
@CrossOrigin(origins = "http://localhost:5173") // Allows React to talk to this API
public class InventoryController {

    @Autowired
    private InventoryRepository inventoryRepository;

    @PostMapping("/sale")
    public ResponseEntity<?> processSale(@RequestBody Map<String, Object> payload) {
        try {
            // Extract data from the incoming React JSON
            Long userId = Long.valueOf(payload.get("userId").toString());
            Long productId = Long.valueOf(payload.get("productId").toString());
            int quantity = Integer.parseInt(payload.get("quantity").toString());
            String notes = (String) payload.get("notes");

            // Send it to the Oracle DB
            inventoryRepository.processSale(userId, productId, quantity, notes);

            return ResponseEntity.ok().body(Map.of("message", "Sale processed successfully"));
        } catch (Exception e) {
            // Oracle's RAISE_APPLICATION_ERROR messages will be caught right here
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // POST request for Admins to restock
    @PostMapping("/restock")
    public ResponseEntity<?> restockProduct(@RequestBody Map<String, Object> payload) {
        try {
            Long userId = Long.valueOf(payload.get("userId").toString());
            Long productId = Long.valueOf(payload.get("productId").toString());
            int quantity = Integer.parseInt(payload.get("quantity").toString());

            inventoryRepository.restockProduct(userId, productId, quantity);
            return ResponseEntity.ok().body(Map.of("message", "Product restocked successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // GET request to fetch the alerts for the dashboard table
    @GetMapping("/alerts")
    public ResponseEntity<?> getRestockAlerts() {
        try {
            List<Map<String, Object>> alerts = inventoryRepository.getRestockAlerts();
            return ResponseEntity.ok(alerts);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    // --- FETCH ENDPOINTS ---

    @GetMapping("/products")
    public ResponseEntity<?> getAllProducts() {
        try {
            return ResponseEntity.ok(inventoryRepository.getAllProducts());
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/transactions/{userId}")
    public ResponseEntity<?> getTransactionHistory(@PathVariable Long userId) {
        try {
            return ResponseEntity.ok(inventoryRepository.getTransactionHistory(userId));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    // --- USER ENDPOINTS ---

    @PostMapping("/return")
    public ResponseEntity<?> processReturn(@RequestBody Map<String, Object> payload) {
        try {
            Long userId = Long.valueOf(payload.get("userId").toString());
            Long productId = Long.valueOf(payload.get("productId").toString());
            int quantity = Integer.parseInt(payload.get("quantity").toString());
            String notes = (String) payload.get("notes");

            inventoryRepository.processReturn(userId, productId, quantity, notes);
            return ResponseEntity.ok().body(Map.of("message", "Return processed successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // --- ADMIN ENDPOINTS ---

    @PostMapping("/admin/add-product")
    public ResponseEntity<?> addProduct(@RequestBody Map<String, Object> payload) {
        try {
            String name = payload.get("name").toString();
            Long categoryId = Long.valueOf(payload.get("categoryId").toString());
            Long supplierId = Long.valueOf(payload.get("supplierId").toString());
            double price = Double.parseDouble(payload.get("price").toString());
            int initStock = Integer.parseInt(payload.get("initStock").toString());
            int restockLvl = Integer.parseInt(payload.get("restockLvl").toString());

            inventoryRepository.addProduct(name, categoryId, supplierId, price, initStock, restockLvl);
            return ResponseEntity.ok().body(Map.of("message", "Product added successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/admin/category/{id}/deactivate")
    public ResponseEntity<?> softDeleteCategory(@PathVariable Long id) {
        try {
            inventoryRepository.softDeleteCategory(id);
            return ResponseEntity.ok().body(Map.of("message", "Category deactivated successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> credentials) {
        try {
            Map<String, Object> userData = inventoryRepository.login(
                    credentials.get("email"),
                    credentials.get("password")
            );
            return ResponseEntity.ok(userData);
        } catch (Exception e) {
            // Return 401 Unauthorized if login fails
            return ResponseEntity.status(401).body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/change-password")
    public ResponseEntity<?> changePassword(@RequestBody Map<String, Object> payload) {
        try {
            Long userId = Long.valueOf(payload.get("userId").toString());
            String oldPassword = payload.get("oldPassword").toString();
            String newPassword = payload.get("newPassword").toString();

            boolean success = inventoryRepository.changePassword(userId, oldPassword, newPassword);

            if (success) {
                return ResponseEntity.ok().body(Map.of("message", "Password updated successfully"));
            } else {
                return ResponseEntity.status(401).body(Map.of("error", "Incorrect old password"));
            }
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/admin/category/{id}/reactivate")
    public ResponseEntity<?> reactivateCategory(@PathVariable Long id) {
        try {
            inventoryRepository.reactivateCategory(id);
            return ResponseEntity.ok().body(Map.of("message", "Category reactivated successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/suppliers")
    public ResponseEntity<?> getSuppliers() {
        try {
            return ResponseEntity.ok(inventoryRepository.getSuppliers());
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/categories")
    public ResponseEntity<?> getAllCategories() {
        try {
            return ResponseEntity.ok(inventoryRepository.getAllCategories());
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/admin/add-supplier")
    public ResponseEntity<?> addSupplier(@RequestBody Map<String, String> payload) {
        try {
            inventoryRepository.addSupplier(payload.get("name"), payload.get("contact"), payload.get("email"), payload.get("address"));
            return ResponseEntity.ok(Map.of("message", "Supplier added successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/admin/add-category")
    public ResponseEntity<?> addCategory(@RequestBody Map<String, String> payload) {
        try {
            inventoryRepository.addCategory(payload.get("name"), payload.get("description"));
            return ResponseEntity.ok(Map.of("message", "Category added successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // --- USER MANAGEMENT ENDPOINTS ---
    @GetMapping("/admin/users")
    public ResponseEntity<?> getAllUsers() {
        try {
            return ResponseEntity.ok(inventoryRepository.getAllUsers());
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/admin/add-user")
    public ResponseEntity<?> addUser(@RequestBody Map<String, String> payload) {
        try {
            inventoryRepository.addUser(payload.get("username"), payload.get("password"), payload.get("email"), payload.get("role"));
            return ResponseEntity.ok(Map.of("message", "User created successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/admin/user/{id}/status/{status}")
    public ResponseEntity<?> toggleUserStatus(@PathVariable Long id, @PathVariable int status) {
        try {
            inventoryRepository.toggleUserStatus(id, status);
            return ResponseEntity.ok(Map.of("message", "User status updated"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // --- AUDIT ENDPOINT ---
    @GetMapping("/admin/audit")
    public ResponseEntity<?> getAuditLog() {
        try {
            return ResponseEntity.ok(inventoryRepository.getAuditLog());
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }
}
