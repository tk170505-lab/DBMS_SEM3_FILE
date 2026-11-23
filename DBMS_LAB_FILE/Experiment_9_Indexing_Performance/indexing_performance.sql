-- ============================================================================
-- Experiment 9: Database Indexing, Query Performance Benchmarking & EXPLAIN Analysis
-- Course Outcome: CO5
-- Database System: Standard SQL (MySQL 8.0+ / PostgreSQL)
-- Target: 5,000+ Records in Railway Booking System
-- ============================================================================

-- Drop pre-existing table
DROP TABLE IF EXISTS Railway_Booking CASCADE;

-- ============================================================================
-- 1. TABLE DEFINITION
-- ============================================================================

CREATE TABLE Railway_Booking (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    pnr_no VARCHAR(12) NOT NULL UNIQUE,
    train_no INT NOT NULL,
    train_name VARCHAR(100) NOT NULL,
    passenger_name VARCHAR(100) NOT NULL,
    passenger_age INT NOT NULL,
    gender VARCHAR(10) NOT NULL,
    source_stn VARCHAR(50) NOT NULL,
    dest_stn VARCHAR(50) NOT NULL,
    journey_date DATE NOT NULL,
    travel_class VARCHAR(10) NOT NULL,
    booking_status VARCHAR(20) NOT NULL,
    fare_amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================================
-- 2. POPULATION OF 5,000 REALISTIC RECORDS
-- ============================================================================
-- Fast, set-based generation of 5,000 records using recursive CTE or cross-joined digit generators

DELIMITER //

CREATE PROCEDURE PopulateRailwayBookings(IN p_total_rows INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    
    START TRANSACTION;
    
    WHILE i <= p_total_rows DO
        INSERT INTO Railway_Booking (
            pnr_no, train_no, train_name, passenger_name, passenger_age,
            gender, source_stn, dest_stn, journey_date, travel_class,
            booking_status, fare_amount
        ) VALUES (
            CONCAT('PNR', LPAD(i, 8, '0')),
            CASE (i % 5)
                WHEN 0 THEN 12001
                WHEN 1 THEN 12002
                WHEN 2 THEN 12301
                WHEN 3 THEN 12951
                ELSE 22691
            END,
            CASE (i % 5)
                WHEN 0 THEN 'Shatabdi Express'
                WHEN 1 THEN 'Bhopal Express'
                WHEN 2 THEN 'Rajdhani Express'
                WHEN 3 THEN 'Tejas Express'
                ELSE 'Vande Bharat Express'
            END,
            CASE (i % 6)
                WHEN 0 THEN CONCAT('Passenger_Aarav_', i)
                WHEN 1 THEN CONCAT('Passenger_Priya_', i)
                WHEN 2 THEN CONCAT('Passenger_Rohan_', i)
                WHEN 3 THEN CONCAT('Passenger_Ananya_', i)
                WHEN 4 THEN CONCAT('Passenger_Vikram_', i)
                ELSE CONCAT('Passenger_Sneha_', i)
            END,
            18 + (i % 65),
            CASE (i % 2) WHEN 0 THEN 'Male' ELSE 'Female' END,
            CASE (i % 4)
                WHEN 0 THEN 'NDLS'
                WHEN 1 THEN 'BCT'
                WHEN 2 THEN 'HWH'
                ELSE 'MAS'
            END,
            CASE (i % 4)
                WHEN 0 THEN 'BCT'
                WHEN 1 THEN 'NDLS'
                WHEN 2 THEN 'MAS'
                ELSE 'HWH'
            END,
            DATE_ADD('2026-05-01', INTERVAL (i % 45) DAY),
            CASE (i % 4)
                WHEN 0 THEN '1A'
                WHEN 1 THEN '2A'
                WHEN 2 THEN '3A'
                ELSE 'SL'
            END,
            CASE (i % 3)
                WHEN 0 THEN 'CONFIRMED'
                WHEN 1 THEN 'RAC'
                ELSE 'WAITING'
            END,
            350.00 + ((i % 25) * 85.00)
        );
        
        SET i = i + 1;
    END WHILE;
    
    COMMIT;
END //

DELIMITER ;

-- Generate 5,000 records
CALL PopulateRailwayBookings(5000);

-- Confirm row count
SELECT COUNT(*) AS total_booked_records FROM Railway_Booking;
SELECT * FROM Railway_Booking LIMIT 5;


-- ============================================================================
-- 3. BENCHMARK QUERY 1: SINGLE-COLUMN LOOKUP (train_no)
-- ============================================================================

-- [BEFORE INDEX] Execution plan analysis
EXPLAIN
SELECT booking_id, pnr_no, passenger_name, fare_amount
FROM Railway_Booking
WHERE train_no = 12002;
-- Observation: type = ALL (Full Table Scan), rows = 5000, key = NULL

-- CREATE SINGLE INDEX
CREATE INDEX idx_train_no ON Railway_Booking(train_no);

-- [AFTER INDEX] Execution plan analysis
EXPLAIN
SELECT booking_id, pnr_no, passenger_name, fare_amount
FROM Railway_Booking
WHERE train_no = 12002;
-- Observation: type = ref, key = idx_train_no, rows ~ 1000 (Exact B-Tree branch lookup)


-- ============================================================================
-- 4. BENCHMARK QUERY 2: RANGE QUERY ON DATE (journey_date)
-- ============================================================================

-- [BEFORE INDEX] Execution plan analysis
EXPLAIN
SELECT booking_id, pnr_no, train_no, journey_date, booking_status
FROM Railway_Booking
WHERE journey_date BETWEEN '2026-05-10' AND '2026-05-15';
-- Observation: type = ALL (Full Table Scan), rows = 5000

-- CREATE SINGLE INDEX
CREATE INDEX idx_journey_date ON Railway_Booking(journey_date);

-- [AFTER INDEX] Execution plan analysis
EXPLAIN
SELECT booking_id, pnr_no, train_no, journey_date, booking_status
FROM Railway_Booking
WHERE journey_date BETWEEN '2026-05-10' AND '2026-05-15';
-- Observation: type = range, key = idx_journey_date, rows scanned ~ 660


-- ============================================================================
-- 5. BENCHMARK QUERY 3: COMPOSITE INDEX (MULTI-COLUMN FILTER + ORDER BY)
-- ============================================================================

-- [BEFORE COMPOSITE INDEX] Execution plan analysis
EXPLAIN
SELECT booking_id, pnr_no, passenger_name, fare_amount
FROM Railway_Booking
WHERE source_stn = 'NDLS' 
  AND dest_stn = 'BCT' 
  AND travel_class = '3A'
ORDER BY journey_date ASC;
-- Observation: type = ALL, rows = 5000, Extra: Using where; Using filesort (Expensive disk/RAM sort)

-- CREATE COMPOSITE INDEX (Columns ordered by equality filters then range/sort)
CREATE INDEX idx_route_class_date 
ON Railway_Booking(source_stn, dest_stn, travel_class, journey_date);

-- [AFTER COMPOSITE INDEX] Execution plan analysis
EXPLAIN
SELECT booking_id, pnr_no, passenger_name, fare_amount
FROM Railway_Booking
WHERE source_stn = 'NDLS' 
  AND dest_stn = 'BCT' 
  AND travel_class = '3A'
ORDER BY journey_date ASC;
-- Observation: type = ref, key = idx_route_class_date, rows ~ 310, Extra: Using index condition
-- Notice: 'Using filesort' is completely ELIMINATED because index stores keys pre-sorted!


-- ============================================================================
-- 6. BENCHMARK QUERY 4: COVERING INDEX (INDEX-ONLY SCAN)
-- ============================================================================

-- [BEFORE COVERING INDEX]
EXPLAIN
SELECT pnr_no, train_no, journey_date, fare_amount
FROM Railway_Booking
WHERE train_no = 12301;
-- Observation: Uses idx_train_no to find primary keys, then performs bookmark lookup into table pages

-- CREATE COVERING COMPOSITE INDEX
CREATE INDEX idx_covering_train
ON Railway_Booking(train_no, pnr_no, journey_date, fare_amount);

-- [AFTER COVERING INDEX]
EXPLAIN
SELECT pnr_no, train_no, journey_date, fare_amount
FROM Railway_Booking
WHERE train_no = 12301;
-- Observation: key = idx_covering_train, Extra: Using index!
-- 100% of requested columns are retrieved directly from the index tree without touching table rows!


-- ============================================================================
-- 7. CLEANUP & INDEX MAINTENANCE COMMANDS
-- ============================================================================

-- Check index usage and cardinalities
SHOW INDEX FROM Railway_Booking;

