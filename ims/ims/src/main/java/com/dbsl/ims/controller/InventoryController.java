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

    @PutMapping("/admin/category/{id}/reactivate")
    public ResponseEntity<?> reactivateCategory(@PathVariable Long id) {
        try {
            inventoryRepository.reactivateCategory(id);
            return ResponseEntity.ok().body(Map.of("message", "Category reactivated successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
