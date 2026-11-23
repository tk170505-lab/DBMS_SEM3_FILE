-- ============================================================================
-- Experiment 8: Banking-Style Transactions, Savepoints & Concurrency Anomalies
-- Course Outcome: CO4
-- Database System: Standard SQL (MySQL 8.0+ / InnoDB Engine)
-- ============================================================================

-- Drop existing tables if present
DROP TABLE IF EXISTS Transaction_Audit CASCADE;
DROP TABLE IF EXISTS Bank_Account CASCADE;

-- ============================================================================
-- 1. SCHEMA SETUP: BANK ACCOUNT & TRANSACTION AUDIT LOG
-- ============================================================================

CREATE TABLE Bank_Account (
    account_no INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    balance DECIMAL(12, 2) NOT NULL CHECK (balance >= 0.00),
    account_type VARCHAR(20) DEFAULT 'SAVINGS',
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

CREATE TABLE Transaction_Audit (
    txn_id INT AUTO_INCREMENT PRIMARY KEY,
    from_acc INT,
    to_acc INT,
    amount DECIMAL(12, 2) NOT NULL,
    txn_type VARCHAR(50) NOT NULL,
    remarks VARCHAR(255),
    txn_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (from_acc) REFERENCES Bank_Account(account_no) ON DELETE SET NULL,
    FOREIGN KEY (to_acc) REFERENCES Bank_Account(account_no) ON DELETE SET NULL
);

-- Seed initial accounts
INSERT INTO Bank_Account (account_no, customer_name, balance, account_type, status) VALUES
(101, 'Aarav Sharma', 5000.00, 'SAVINGS', 'ACTIVE'),
(102, 'Bhavna Verma', 3000.00, 'SAVINGS', 'ACTIVE'),
(103, 'Chetan Patel', 1500.00, 'CURRENT', 'ACTIVE');

SELECT * FROM Bank_Account;


-- ============================================================================
-- 2. SCENARIO A: SUCCESSFUL ATOMIC FUNDS TRANSFER (COMMIT)
-- ============================================================================
-- Transfer 1,000.00 from Account 101 to Account 102.
-- Both debit and credit must happen atomically.

START TRANSACTION;

-- Step 1: Debit from Account 101
UPDATE Bank_Account
SET balance = balance - 1000.00
WHERE account_no = 101;

-- Step 2: Credit to Account 102
UPDATE Bank_Account
SET balance = balance + 1000.00
WHERE account_no = 102;

-- Step 3: Record Audit Entry
INSERT INTO Transaction_Audit (from_acc, to_acc, amount, txn_type, remarks)
VALUES (101, 102, 1000.00, 'TRANSFER', 'Successful intra-bank transfer');

-- Commit permanent changes
COMMIT;

-- Verify updated balances (101: 4000.00, 102: 4000.00)
SELECT * FROM Bank_Account;
SELECT * FROM Transaction_Audit;


-- ============================================================================
-- 3. SCENARIO B: TRANSACTION ABORT & TOTAL ROLLBACK (SIMULATING FAILURE)
-- ============================================================================
-- Attempt to transfer 8,000.00 from Account 103 (current balance: 1,500.00).
-- The transfer violates the balance >= 0 check constraint or business rule.

START TRANSACTION;

-- Step 1: Attempt deduction (Simulate overdraft failure)
-- If application checks balance < transfer amount, it triggers ROLLBACK.
SET @sender_acc = 103;
SET @transfer_amt = 8000.00;

SELECT balance INTO @current_bal FROM Bank_Account WHERE account_no = @sender_acc;

-- Simulated condition: Insufficient funds check
-- In SQL script, we execute ROLLBACK to restore state.
ROLLBACK;

-- Verify: Account 103 balance remains unchanged at 1500.00
SELECT * FROM Bank_Account WHERE account_no = 103;


-- ============================================================================
-- 4. SCENARIO C: PARTIAL FAILURE RECOVERY USING SAVEPOINT & ROLLBACK TO SAVEPOINT
-- ============================================================================
-- Scenario:
--   Step 1: Deposit a loyalty bonus of 250.00 to Account 101.
--   Create SAVEPOINT 'after_bonus'.
--   Step 2: Attempt to charge a processing fee on non-existent Account 999.
--   Error detected -> ROLLBACK TO SAVEPOINT 'after_bonus'.
--   Step 3: Proceed with remaining valid steps and COMMIT.

START TRANSACTION;

-- Step 1: Valid Bonus Credit to 101
UPDATE Bank_Account
SET balance = balance + 250.00
WHERE account_no = 101;

-- Set Savepoint
SAVEPOINT after_bonus;

-- Step 2: Simulating sub-operation failure
-- Attempting deduction on an invalid account (acc 999 does not exist)
UPDATE Bank_Account
SET balance = balance - 50.00
WHERE account_no = 999;

-- Check affected rows: 0 rows affected -> operation failed!
-- Rollback only the sub-operation to the savepoint
ROLLBACK TO SAVEPOINT after_bonus;

-- Step 3: Log successful bonus in audit table
INSERT INTO Transaction_Audit (from_acc, to_acc, amount, txn_type, remarks)
VALUES (NULL, 101, 250.00, 'BONUS', 'Annual loyalty cash bonus deposited');

-- Commit the valid portion
COMMIT;

-- Verification:
-- Account 101 balance is now 4250.00 (4000 + 250 bonus, without any deduction)
SELECT * FROM Bank_Account WHERE account_no = 101;
SELECT * FROM Transaction_Audit ORDER BY txn_id DESC;


-- ============================================================================
-- 5. CONCURRENCY ANOMALIES & ISOLATION LEVELS (TWO-SESSION DEMONSTRATION)
-- ============================================================================

/*
-------------------------------------------------------------------------------
EXPERIMENT 8.1: DIRTY READ ANOMALY (READ UNCOMMITTED)
-------------------------------------------------------------------------------
Session 1 (Terminal 1):
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
  START TRANSACTION;
  UPDATE Bank_Account SET balance = balance + 5000.00 WHERE account_no = 102;
  -- DO NOT COMMIT YET!

Session 2 (Terminal 2):
  SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
  START TRANSACTION;
  -- Reads uncommitted dirty balance of Account 102 (reads 9000.00 instead of 4000.00)
  SELECT balance FROM Bank_Account WHERE account_no = 102;
  COMMIT;

Session 1 (Terminal 1):
  -- Transaction fails and aborts!
  ROLLBACK;
  -- Session 2 made business decisions on fictitious, rolled-back money!

Resolution:
  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
*/

/*
-------------------------------------------------------------------------------
EXPERIMENT 8.2: NON-REPEATABLE READ ANOMALY (READ COMMITTED)
-------------------------------------------------------------------------------
Session 1 (Terminal 1):
  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;
  -- Query 1: Reads balance = 4250.00
  SELECT balance FROM Bank_Account WHERE account_no = 101;

Session 2 (Terminal 2):
  SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;
  UPDATE Bank_Account SET balance = balance - 1000.00 WHERE account_no = 101;
  COMMIT;

Session 1 (Terminal 1):
  -- Query 2: Re-reading the EXACT SAME ROW inside the same active transaction!
  -- Returns 3250.00 (Value changed under the feet of Session 1!)
  SELECT balance FROM Bank_Account WHERE account_no = 101;
  COMMIT;

Resolution:
  SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
*/

/*
-------------------------------------------------------------------------------
EXPERIMENT 8.3: PHANTOM READ ANOMALY (REPEATABLE READ vs SERIALIZABLE)
-------------------------------------------------------------------------------
Session 1 (Terminal 1):
  SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
  START TRANSACTION;
  -- Range query: returns accounts with balance >= 4000.00
  SELECT * FROM Bank_Account WHERE balance >= 4000.00;

Session 2 (Terminal 2):
  START TRANSACTION;
  -- Insert a new account matching Session 1's predicate
  INSERT INTO Bank_Account VALUES (104, 'Divya Nair', 6000.00, 'SAVINGS', 'ACTIVE');
  COMMIT;

Session 1 (Terminal 1):
  -- Session 1 updates all high-balance accounts
  UPDATE Bank_Account SET status = 'PREMIUM' WHERE balance >= 4000.00;
  -- Session 1 now discovers Account 104 was modified even though it wasn't visible earlier!
  SELECT * FROM Bank_Account WHERE balance >= 4000.00;
  COMMIT;

Resolution:
  SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
*/

-- ============================================================================
-- 6. PESSIMISTIC CONCURRENCY CONTROL: SELECT ... FOR UPDATE
-- ============================================================================
-- Demonstrates row-level exclusive locking to prevent the classic Lost Update problem.

START TRANSACTION;

-- Locks row for Account 101 exclusively; concurrent transactions must wait
SELECT balance 
FROM Bank_Account 
WHERE account_no = 101 
FOR UPDATE;

-- Safe update while holding lock
UPDATE Bank_Account
SET balance = balance - 200.00
WHERE account_no = 101;

COMMIT; -- Lock released immediately upon commit

-- Final Verification of Database State
SELECT * FROM Bank_Account;
SELECT * FROM Transaction_Audit;

