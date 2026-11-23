-- ============================================================================
-- Experiment 10: Advanced Query Optimization, Indexing & EXPLAIN Execution Plans
-- Course Outcome: CO5
-- Database System: Standard SQL (MySQL 8.0+ / PostgreSQL)
-- Target: 10,000+ Records Dataset
-- ============================================================================

-- Drop pre-existing tables
DROP TABLE IF EXISTS Customer_Orders CASCADE;
DROP TABLE IF EXISTS Customer_Account CASCADE;

-- ============================================================================
-- 1. DATABASE SCHEMA SETUP
-- ============================================================================

CREATE TABLE Customer_Account (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    city VARCHAR(50) NOT NULL,
    account_status VARCHAR(20) DEFAULT 'ACTIVE'
);

CREATE TABLE Customer_Orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATETIME NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    shipping_city VARCHAR(50) NOT NULL,
    shipping_address VARCHAR(255) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES Customer_Account(customer_id) ON DELETE CASCADE
);


-- ============================================================================
-- 2. DATASET GENERATION: 1,000 CUSTOMERS & 10,000 ORDERS
-- ============================================================================

DELIMITER //

CREATE PROCEDURE GenerateOptimizationDataset(IN p_num_orders INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    
    -- Insert 1,000 Customers
    WHILE i <= 1000 DO
        INSERT INTO Customer_Account (customer_id, customer_name, email, city, account_status)
        VALUES (
            i,
            CONCAT('Customer_', i),
            CONCAT('user_', i, '@ecommerce.com'),
            CASE (i % 5)
                WHEN 0 THEN 'Bengaluru'
                WHEN 1 THEN 'Mumbai'
                WHEN 2 THEN 'Delhi'
                WHEN 3 THEN 'Hyderabad'
                ELSE 'Chennai'
            END,
            CASE (i % 10) WHEN 0 THEN 'INACTIVE' ELSE 'ACTIVE' END
        );
        SET i = i + 1;
    END WHILE;

    -- Insert 10,000 Orders
    SET i = 1;
    START TRANSACTION;
    
    WHILE i <= p_num_orders DO
        INSERT INTO Customer_Orders (
            customer_id, order_date, order_status, shipping_city,
            shipping_address, total_amount
        ) VALUES (
            1 + (i % 1000),
            DATE_ADD('2026-01-01 08:00:00', INTERVAL (i % 120) DAY),
            CASE (i % 5)
                WHEN 0 THEN 'Completed'
                WHEN 1 THEN 'Pending'
                WHEN 2 THEN 'Processing'
                WHEN 3 THEN 'Shipped'
                ELSE 'Cancelled'
            END,
            CASE (i % 5)
                WHEN 0 THEN 'Bengaluru'
                WHEN 1 THEN 'Mumbai'
                WHEN 2 THEN 'Delhi'
                WHEN 3 THEN 'Hyderabad'
                ELSE 'Chennai'
            END,
            CONCAT('Door No ', (i % 500), ', Tech Sector, ', 
                   CASE (i % 5)
                       WHEN 0 THEN 'Bengaluru'
                       WHEN 1 THEN 'Mumbai'
                       WHEN 2 THEN 'Delhi'
                       WHEN 3 THEN 'Hyderabad'
                       ELSE 'Chennai'
                   END),
            25.00 + ((i % 100) * 17.50)
        );
        SET i = i + 1;
    END WHILE;
    
    COMMIT;
END //

DELIMITER ;

-- Populate 10,000 Order rows
CALL GenerateOptimizationDataset(10000);

-- Confirm row counts
SELECT COUNT(*) AS total_customers FROM Customer_Account;
SELECT COUNT(*) AS total_orders FROM Customer_Orders;


-- ============================================================================
-- 3. SLOW QUERY 1: NON-SARGABLE FUNCTION ON DATE COLUMN
-- ============================================================================

-- [ANTI-PATTERN] Calling functions YEAR() and MONTH() on column invalidates B-Tree index
EXPLAIN
SELECT order_id, customer_id, order_date, total_amount
FROM Customer_Orders
WHERE YEAR(order_date) = 2026 AND MONTH(order_date) = 3;
-- Result: type = ALL, rows = 10000, key = NULL (Full Table Scan)

-- OPTIMIZATION:
-- 1. Create B-Tree index on order_date
CREATE INDEX idx_order_date ON Customer_Orders(order_date);

-- 2. Query Rewriting: SARGable date range predicate
EXPLAIN
SELECT order_id, customer_id, order_date, total_amount
FROM Customer_Orders
WHERE order_date >= '2026-03-01 00:00:00' 
  AND order_date < '2026-04-01 00:00:00';
-- Result: type = range, key = idx_order_date, rows scanned ~ 2500


-- ============================================================================
-- 4. SLOW QUERY 2: INNEFICIENT NOT IN SUBQUERY vs NOT EXISTS ANTI-JOIN
-- ============================================================================

-- [ANTI-PATTERN] NOT IN with nested subquery causes materialization & NULL-trapping overhead
EXPLAIN
SELECT customer_id, customer_name
FROM Customer_Account
WHERE customer_id NOT IN (
    SELECT customer_id 
    FROM Customer_Orders 
    WHERE order_status = 'Completed'
);
-- Result: Dependent subquery, scanning entire orders table repeatedly

-- OPTIMIZATION:
-- 1. Create composite index on (customer_id, order_status)
CREATE INDEX idx_cust_status ON Customer_Orders(customer_id, order_status);

-- 2. Query Rewriting: NOT EXISTS construct
EXPLAIN
SELECT C.customer_id, C.customer_name
FROM Customer_Account C
WHERE NOT EXISTS (
    SELECT 1 
    FROM Customer_Orders O
    WHERE O.customer_id = C.customer_id 
      AND O.order_status = 'Completed'
);
-- Result: Correlated subquery transformed into indexed semi-join seek


-- ============================================================================
-- 5. SLOW QUERY 3: LEADING WILDCARD PATTERN vs NORMALIZED COLUMN LOOKUP
-- ============================================================================

-- [ANTI-PATTERN] Leading wildcard '%Bengaluru%' forces full table scan of 10,000 text fields
EXPLAIN
SELECT order_id, customer_id, total_amount, shipping_address
FROM Customer_Orders
WHERE shipping_address LIKE '%Bengaluru%';
-- Result: type = ALL, rows = 10000

-- OPTIMIZATION:
-- 1. Create index on dedicated normalized column shipping_city
CREATE INDEX idx_shipping_city ON Customer_Orders(shipping_city);

-- 2. Query Rewriting: Direct indexed column predicate
EXPLAIN
SELECT order_id, customer_id, total_amount, shipping_address
FROM Customer_Orders
WHERE shipping_city = 'Bengaluru';
-- Result: type = ref, key = idx_shipping_city, rows ~ 2000


-- ============================================================================
-- 6. SLOW QUERY 4: DEEP PAGINATION (LIMIT / OFFSET) vs DEFERRED JOIN
-- ============================================================================

-- [ANTI-PATTERN] Deep offset reads and discards 8,500 payload rows using filesort
EXPLAIN
SELECT * 
FROM Customer_Orders
ORDER BY order_date DESC
LIMIT 10 OFFSET 8500;
-- Result: type = ALL, Extra: Using filesort, reads all 8,510 complete records from disk

-- OPTIMIZATION:
-- 1. Create composite index on (order_date, order_id)
CREATE INDEX idx_order_date_id ON Customer_Orders(order_date, order_id);

-- 2. Query Rewriting: Deferred Join (late row lookup)
EXPLAIN
SELECT O.*
FROM Customer_Orders O
INNER JOIN (
    SELECT order_id
    FROM Customer_Orders
    ORDER BY order_date DESC
    LIMIT 10 OFFSET 8500
) AS Sub ON O.order_id = Sub.order_id;
-- Result: The inner subquery performs an INDEX-ONLY scan over index leaf blocks.
-- Only the final 10 matched rows are fetched from data pages!


-- ============================================================================
-- 7. SLOW QUERY 5: REPEATED CORRELATED SUBQUERIES (N+1) vs JOIN AGGREGATION
-- ============================================================================

-- [ANTI-PATTERN] 2 correlated scalar subqueries per customer = 2,000 query evaluations!
EXPLAIN
SELECT 
    C.customer_id, 
    C.customer_name,
    (SELECT COUNT(*) FROM Customer_Orders O WHERE O.customer_id = C.customer_id) AS total_orders,
    (SELECT SUM(total_amount) FROM Customer_Orders O WHERE O.customer_id = C.customer_id) AS total_spent
FROM Customer_Account C;
-- Result: 1000 customer loops x 2 dependent subqueries

-- OPTIMIZATION:
-- 1. Create composite index on (customer_id, total_amount)
CREATE INDEX idx_cust_total ON Customer_Orders(customer_id, total_amount);

-- 2. Query Rewriting: Single Left Join with GROUP BY
EXPLAIN
SELECT 
    C.customer_id, 
    C.customer_name,
    COALESCE(COUNT(O.order_id), 0) AS total_orders,
    COALESCE(SUM(O.total_amount), 0.00) AS total_spent
FROM Customer_Account C
LEFT JOIN Customer_Orders O ON C.customer_id = O.customer_id
GROUP BY C.customer_id, C.customer_name;
-- Result: Single hash join / stream aggregate pass over indexed relation!

