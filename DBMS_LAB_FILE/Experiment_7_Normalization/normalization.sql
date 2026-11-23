-- ============================================================================
-- Experiment 7: Database Normalization (UNF to 1NF, 2NF, 3NF, and BCNF)
-- Course Outcome: CO4
-- Database System: Standard SQL (MySQL 8.0+ / PostgreSQL Compatible)
-- ============================================================================

-- Drop pre-existing tables if any
DROP TABLE IF EXISTS Invoice_Item_3NF CASCADE;
DROP TABLE IF EXISTS Invoice_3NF CASCADE;
DROP TABLE IF EXISTS Salesperson_3NF CASCADE;
DROP TABLE IF EXISTS Store_3NF CASCADE;
DROP TABLE IF EXISTS Customer_3NF CASCADE;
DROP TABLE IF EXISTS Product_3NF CASCADE;

DROP TABLE IF EXISTS Invoice_Item_2NF CASCADE;
DROP TABLE IF EXISTS Invoice_Header_2NF CASCADE;
DROP TABLE IF EXISTS Product_2NF CASCADE;

DROP TABLE IF EXISTS Sales_1NF CASCADE;
DROP TABLE IF EXISTS Sales_UNF CASCADE;


-- ============================================================================
-- 1. UNNORMALIZED FORM (UNF) - DENORMALIZED SALES TABLE
-- ============================================================================
-- Notice: Contains repeating groups / non-atomic multivalued attributes
-- (e.g., multiple items in one single invoice row).

CREATE TABLE Sales_UNF (
    invoice_no VARCHAR(20),
    invoice_date DATE,
    customer_name VARCHAR(100),
    customer_email VARCHAR(100),
    customer_city VARCHAR(100),
    product_details VARCHAR(500), -- Non-atomic: 'P101:Wireless Mouse:Electronics:25.00:2; P102:USB Keyboard:Electronics:45.00:1'
    salesperson_id VARCHAR(20),
    salesperson_name VARCHAR(100),
    store_name VARCHAR(100),
    store_location VARCHAR(100)
);

-- Insert sample denormalized data
INSERT INTO Sales_UNF VALUES
('INV-2026-001', '2026-03-01', 'Rahul Sharma', 'rahul@example.com', 'Bengaluru', 'P101:Wireless Mouse:Electronics:25.00:2; P102:USB Keyboard:Electronics:45.00:1', 'SP-01', 'Anil Verma', 'Apex Tech Store', 'MG Road'),
('INV-2026-002', '2026-03-02', 'Priya Patel', 'priya@example.com', 'Mumbai', 'P103:Noise-Cancelling Headphones:Audio:120.00:1', 'SP-02', 'Sunita Rao', 'Metro Gadgets', 'Bandra West'),
('INV-2026-003', '2026-03-02', 'Rahul Sharma', 'rahul@example.com', 'Bengaluru', 'P102:USB Keyboard:Electronics:45.00:2; P104:1080p Webcam:Electronics:60.00:1', 'SP-01', 'Anil Verma', 'Apex Tech Store', 'MG Road'),
('INV-2026-004', '2026-03-03', 'Amit Singh', 'amit@example.com', 'Delhi', 'P101:Wireless Mouse:Electronics:25.00:1; P105:Gaming Mousepad:Accessories:15.00:3', 'SP-03', 'Deepak Mehta', 'Capital Electronics', 'Connaught Place');

SELECT * FROM Sales_UNF;


-- ============================================================================
-- 2. FIRST NORMAL FORM (1NF)
-- ============================================================================
-- Rule: Eliminate repeating groups. Every attribute must be atomic (single-valued).
-- Define Candidate Key: Composite Key (invoice_no, product_id)

CREATE TABLE Sales_1NF (
    invoice_no VARCHAR(20) NOT NULL,
    invoice_date DATE NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    quantity INT NOT NULL,
    salesperson_id VARCHAR(20) NOT NULL,
    salesperson_name VARCHAR(100) NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    store_location VARCHAR(100) NOT NULL,
    PRIMARY KEY (invoice_no, product_id)
);

-- Flatten UNF repeating groups into atomic rows
INSERT INTO Sales_1NF VALUES
('INV-2026-001', '2026-03-01', 'rahul@example.com', 'Rahul Sharma', 'Bengaluru', 'P101', 'Wireless Mouse', 'Electronics', 25.00, 2, 'SP-01', 'Anil Verma', 'Apex Tech Store', 'MG Road'),
('INV-2026-001', '2026-03-01', 'rahul@example.com', 'Rahul Sharma', 'Bengaluru', 'P102', 'USB Keyboard', 'Electronics', 45.00, 1, 'SP-01', 'Anil Verma', 'Apex Tech Store', 'MG Road'),
('INV-2026-002', '2026-03-02', 'priya@example.com', 'Priya Patel', 'Mumbai', 'P103', 'Noise-Cancelling Headphones', 'Audio', 120.00, 1, 'SP-02', 'Sunita Rao', 'Metro Gadgets', 'Bandra West'),
('INV-2026-003', '2026-03-02', 'rahul@example.com', 'Rahul Sharma', 'Bengaluru', 'P102', 'USB Keyboard', 'Electronics', 45.00, 2, 'SP-01', 'Anil Verma', 'Apex Tech Store', 'MG Road'),
('INV-2026-003', '2026-03-02', 'rahul@example.com', 'Rahul Sharma', 'Bengaluru', 'P104', '1080p Webcam', 'Electronics', 60.00, 1, 'SP-01', 'Anil Verma', 'Apex Tech Store', 'MG Road'),
('INV-2026-004', '2026-03-03', 'amit@example.com', 'Amit Singh', 'Delhi', 'P101', 'Wireless Mouse', 'Electronics', 25.00, 1, 'SP-03', 'Deepak Mehta', 'Capital Electronics', 'Connaught Place'),
('INV-2026-004', '2026-03-03', 'amit@example.com', 'Amit Singh', 'Delhi', 'P105', 'Gaming Mousepad', 'Accessories', 15.00, 3, 'SP-03', 'Deepak Mehta', 'Capital Electronics', 'Connaught Place');

SELECT * FROM Sales_1NF;


-- ============================================================================
-- 3. IDENTIFY FUNCTIONAL DEPENDENCIES (FDs)
-- ============================================================================
/*
Primary Key of Sales_1NF: (invoice_no, product_id)

Functional Dependencies identified:
  FD1: invoice_no -> invoice_date, customer_email, salesperson_id
  FD2: customer_email -> customer_name, customer_city
  FD3: product_id -> product_name, category, unit_price
  FD4: salesperson_id -> salesperson_name, store_name
  FD5: store_name -> store_location
  FD6: (invoice_no, product_id) -> quantity

Analysis of Anomalies in 1NF:
  - Partial Dependency: Non-prime attributes (product_name, category, unit_price)
    depend only on product_id (part of PK), NOT the whole composite PK!
  - Partial Dependency: invoice_date, customer_email, etc. depend only on invoice_no.
  - Insertion Anomaly: Cannot add a new product without an invoice.
  - Deletion Anomaly: Deleting invoice 'INV-2026-002' erases all records of P103!
  - Update Anomaly: If 'Wireless Mouse' price changes, multiple rows must be updated.
*/


-- ============================================================================
-- 4. SECOND NORMAL FORM (2NF)
-- ============================================================================
-- Rule: Must be in 1NF and have NO partial dependencies (all non-key attributes
-- must be fully functionally dependent on the entire primary key).

-- Decompose Sales_1NF into 3 relations:
-- Relation 1: Product_2NF (eliminates FD3 partial dependency)
CREATE TABLE Product_2NF (
    product_id VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL
);

-- Relation 2: Invoice_Header_2NF (eliminates FD1 partial dependency)
CREATE TABLE Invoice_Header_2NF (
    invoice_no VARCHAR(20) PRIMARY KEY,
    invoice_date DATE NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    salesperson_id VARCHAR(20) NOT NULL,
    salesperson_name VARCHAR(100) NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    store_location VARCHAR(100) NOT NULL
);

-- Relation 3: Invoice_Item_2NF (holds full functional dependency FD6)
CREATE TABLE Invoice_Item_2NF (
    invoice_no VARCHAR(20) NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    quantity INT NOT NULL,
    PRIMARY KEY (invoice_no, product_id),
    FOREIGN KEY (invoice_no) REFERENCES Invoice_Header_2NF(invoice_no) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Product_2NF(product_id) ON DELETE CASCADE
);

-- Populate 2NF Tables
INSERT INTO Product_2NF
SELECT DISTINCT product_id, product_name, category, unit_price FROM Sales_1NF;

INSERT INTO Invoice_Header_2NF
SELECT DISTINCT invoice_no, invoice_date, customer_email, customer_name, customer_city,
                salesperson_id, salesperson_name, store_name, store_location
FROM Sales_1NF;

INSERT INTO Invoice_Item_2NF
SELECT invoice_no, product_id, quantity FROM Sales_1NF;

SELECT * FROM Product_2NF;
SELECT * FROM Invoice_Header_2NF;
SELECT * FROM Invoice_Item_2NF;


-- ============================================================================
-- 5. THIRD NORMAL FORM (3NF)
-- ============================================================================
-- Rule: Must be in 2NF and have NO transitive dependencies (non-key attribute
-- must not determine another non-key attribute: X -> Y and Y -> Z).

/*
In Invoice_Header_2NF:
  - PK is invoice_no.
  - Transitive Dependency 1: invoice_no -> customer_email, and customer_email -> customer_name, customer_city
  - Transitive Dependency 2: invoice_no -> salesperson_id, and salesperson_id -> salesperson_name, store_name
  - Transitive Dependency 3: salesperson_id -> store_name, and store_name -> store_location
*/

-- Decompose into clean 3NF entities:

-- 1. Customer Entity
CREATE TABLE Customer_3NF (
    customer_email VARCHAR(100) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_city VARCHAR(100) NOT NULL
);

-- 2. Store Entity
CREATE TABLE Store_3NF (
    store_name VARCHAR(100) PRIMARY KEY,
    store_location VARCHAR(100) NOT NULL
);

-- 3. Salesperson Entity
CREATE TABLE Salesperson_3NF (
    salesperson_id VARCHAR(20) PRIMARY KEY,
    salesperson_name VARCHAR(100) NOT NULL,
    store_name VARCHAR(100) NOT NULL,
    FOREIGN KEY (store_name) REFERENCES Store_3NF(store_name) ON DELETE RESTRICT
);

-- 4. Product Entity
CREATE TABLE Product_3NF (
    product_id VARCHAR(20) PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL
);

-- 5. Invoice Transaction Header
CREATE TABLE Invoice_3NF (
    invoice_no VARCHAR(20) PRIMARY KEY,
    invoice_date DATE NOT NULL,
    customer_email VARCHAR(100) NOT NULL,
    salesperson_id VARCHAR(20) NOT NULL,
    FOREIGN KEY (customer_email) REFERENCES Customer_3NF(customer_email) ON DELETE RESTRICT,
    FOREIGN KEY (salesperson_id) REFERENCES Salesperson_3NF(salesperson_id) ON DELETE RESTRICT
);

-- 6. Invoice Item Association
CREATE TABLE Invoice_Item_3NF (
    invoice_no VARCHAR(20) NOT NULL,
    product_id VARCHAR(20) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (invoice_no, product_id),
    FOREIGN KEY (invoice_no) REFERENCES Invoice_3NF(invoice_no) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Product_3NF(product_id) ON DELETE RESTRICT
);

-- Populate 3NF Tables
INSERT INTO Customer_3NF
SELECT DISTINCT customer_email, customer_name, customer_city FROM Sales_1NF;

INSERT INTO Store_3NF
SELECT DISTINCT store_name, store_location FROM Sales_1NF;

INSERT INTO Salesperson_3NF
SELECT DISTINCT salesperson_id, salesperson_name, store_name FROM Sales_1NF;

INSERT INTO Product_3NF
SELECT * FROM Product_2NF;

INSERT INTO Invoice_3NF
SELECT DISTINCT invoice_no, invoice_date, customer_email, salesperson_id FROM Sales_1NF;

INSERT INTO Invoice_Item_3NF
SELECT * FROM Invoice_Item_2NF;


-- ============================================================================
-- 6. BOYCE-CODD NORMAL FORM (BCNF) EVALUATION
-- ============================================================================
-- Rule: For EVERY functional dependency X -> Y, X must be a SUPER KEY.
-- Evaluating our 3NF schema:
-- Customer_3NF: customer_email is Super Key. (Satisfies BCNF)
-- Store_3NF: store_name is Super Key. (Satisfies BCNF)
-- Salesperson_3NF: salesperson_id is Super Key. (Satisfies BCNF)
-- Product_3NF: product_id is Super Key. (Satisfies BCNF)
-- Invoice_3NF: invoice_no is Super Key. (Satisfies BCNF)
-- Invoice_Item_3NF: (invoice_no, product_id) is Super Key. (Satisfies BCNF)
-- Result: The decomposed 3NF relations are strictly in BCNF!


-- ============================================================================
-- 7. VERIFICATION 1: LOSSLESS JOIN DECOMPOSITION VERIFICATION
-- ============================================================================
-- Lossless Join Property: A decomposition D = {R1, R2, ... Rn} of R is lossless
-- if joining R1, R2, ... Rn produces EXACTLY the original relation R with NO
-- spurious tuples and NO missing rows.

-- Query: Reconstruct the original 1NF dataset from 3NF relations via INNER JOIN
SELECT 
    I.invoice_no,
    I.invoice_date,
    C.customer_email,
    C.customer_name,
    C.customer_city,
    P.product_id,
    P.product_name,
    P.category,
    P.unit_price,
    II.quantity,
    S.salesperson_id,
    S.salesperson_name,
    ST.store_name,
    ST.store_location
FROM Invoice_3NF I
INNER JOIN Customer_3NF C ON I.customer_email = C.customer_email
INNER JOIN Salesperson_3NF S ON I.salesperson_id = S.salesperson_id
INNER JOIN Store_3NF ST ON S.store_name = ST.store_name
INNER JOIN Invoice_Item_3NF II ON I.invoice_no = II.invoice_no
INNER JOIN Product_3NF P ON II.product_id = P.product_id
ORDER BY I.invoice_no, P.product_id;

-- Verification Check using EXCEPT / Count Match:
-- Compare row count between Sales_1NF and Reconstructed Join View
SELECT 
    (SELECT COUNT(*) FROM Sales_1NF) AS original_1nf_row_count,
    (
        SELECT COUNT(*)
        FROM Invoice_3NF I
        JOIN Customer_3NF C ON I.customer_email = C.customer_email
        JOIN Salesperson_3NF S ON I.salesperson_id = S.salesperson_id
        JOIN Store_3NF ST ON S.store_name = ST.store_name
        JOIN Invoice_Item_3NF II ON I.invoice_no = II.invoice_no
        JOIN Product_3NF P ON II.product_id = P.product_id
    ) AS reconstructed_row_count;


-- ============================================================================
-- 8. VERIFICATION 2: DEPENDENCY PRESERVATION
-- ============================================================================
-- Dependency Preservation Property: All functional dependencies F of R are
-- preserved if every FD in F can be enforced within individual decomposed
-- relations using PRIMARY KEY and FOREIGN KEY constraints without requiring cross-table joins.

-- FD1: invoice_no -> invoice_date, customer_email, salesperson_id (Enforced by PK on Invoice_3NF)
-- FD2: customer_email -> customer_name, customer_city (Enforced by PK on Customer_3NF)
-- FD3: product_id -> product_name, category, unit_price (Enforced by PK on Product_3NF)
-- FD4: salesperson_id -> salesperson_name, store_name (Enforced by PK on Salesperson_3NF)
-- FD5: store_name -> store_location (Enforced by PK on Store_3NF)
-- FD6: (invoice_no, product_id) -> quantity (Enforced by Composite PK on Invoice_Item_3NF)

SELECT 'Dependency Preservation: 100% of Functional Dependencies preserved via relational keys.' AS Verification_Status;

