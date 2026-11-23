# Experiment 8: Banking Transactions, Savepoints & Concurrency Anomalies

## 📌 Aim & Objective
To implement **banking-style database transactions** using `BEGIN / START TRANSACTION`, `COMMIT`, `ROLLBACK`, and `SAVEPOINT`. To simulate **partial failures** and demonstrate **Transaction Isolation Levels** and **Concurrency Anomalies** (Dirty Read, Non-Repeatable Read, Phantom Read, Lost Update) across concurrent database sessions.

- **Course Outcome:** `CO4`
- **Database System:** Standard SQL / MySQL (InnoDB Engine) / PostgreSQL

---

## 🏛️ 1. ACID Properties in Banking

1. **Atomicity (All or Nothing):** Either all operations in a money transfer occur (debit sender, credit receiver, record audit), or none occur.
2. **Consistency (Integrity Maintained):** The sum of balances across accounts remains invariant; constraints (e.g. `balance >= 0`) are never violated.
3. **Isolation (Concurrent Independence):** Concurrent transactions operate without interfering with uncommitted modifications of one another.
4. **Durability (Persistence):** Once `COMMIT` completes, changes persist across power cuts or server crashes.

---

## 🗄️ 2. Database Schema

- **`Bank_Account`** (`account_no` [PK], `customer_name`, `balance` [CHECK >= 0], `account_type`, `status`)
- **`Transaction_Audit`** (`txn_id` [PK], `from_acc` [FK], `to_acc` [FK], `amount`, `txn_type`, `remarks`, `txn_time`)

---

## 💻 3. Transaction Control Scenarios

### Scenario A: Atomic Transfer with `COMMIT`
Transfer ₹1,000 from Account 101 to Account 102:

```sql
START TRANSACTION;

UPDATE Bank_Account SET balance = balance - 1000.00 WHERE account_no = 101;
UPDATE Bank_Account SET balance = balance + 1000.00 WHERE account_no = 102;

INSERT INTO Transaction_Audit (from_acc, to_acc, amount, txn_type, remarks)
VALUES (101, 102, 1000.00, 'TRANSFER', 'Intra-bank transfer');

COMMIT;
```

---

### Scenario B: Full Transaction Rollback on Failure
Attempting to withdraw ₹8,000 from Account 103 (balance = ₹1,500):

```sql
START TRANSACTION;

-- Business validation fails due to insufficient balance
ROLLBACK;
```
> Both balance and audit records revert completely to their prior state.

---

### Scenario C: Partial Failure Recovery with `SAVEPOINT`
Apply a ₹250 bonus, attempt an invalid debit on Account 999, roll back only the failed step, and commit:

```sql
START TRANSACTION;

-- Step 1: Valid Bonus
UPDATE Bank_Account SET balance = balance + 250.00 WHERE account_no = 101;
SAVEPOINT after_bonus;

-- Step 2: Faulty operation
UPDATE Bank_Account SET balance = balance - 50.00 WHERE account_no = 999;

-- Revert ONLY the faulty operation
ROLLBACK TO SAVEPOINT after_bonus;

-- Step 3: Log successful portion and finalize
INSERT INTO Transaction_Audit (from_acc, to_acc, amount, txn_type, remarks)
VALUES (NULL, 101, 250.00, 'BONUS', 'Annual loyalty bonus');

COMMIT;
```

---

## ⚡ 4. Concurrency Anomalies & Isolation Levels (Two-Session Simulation)

| Isolation Level | Dirty Read | Non-Repeatable Read | Phantom Read |
| :--- | :---: | :---: | :---: |
| **READ UNCOMMITTED** | ❌ Allowed | ❌ Allowed | ❌ Allowed |
| **READ COMMITTED** |  Prevented | ❌ Allowed | ❌ Allowed |
| **REPEATABLE READ** (Default) |  Prevented |  Prevented | ❌ Allowed (InnoDB MVCC mitigates) |
| **SERIALIZABLE** |  Prevented |  Prevented |  Prevented |

---

### Anomaly 1: Dirty Read
- **Session 1:** Updates Account 102 balance by +5,000 without committing.
- **Session 2:** Reads Account 102 (`READ UNCOMMITTED`) and observes the inflated 9,000 balance.
- **Session 1:** Executes `ROLLBACK`.
- **Result:** Session 2 acted upon non-existent data ("dirty read").
- **Fix:** `SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;`

---

### Anomaly 2: Non-Repeatable Read
- **Session 1:** Reads Account 101 balance = ₹4,250.
- **Session 2:** Debits ₹1,000 from Account 101 and executes `COMMIT`.
- **Session 1:** Re-reads Account 101 within the same active transaction and observes ₹3,250.
- **Result:** Same row returned two different values within one transaction.
- **Fix:** `SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;`

---

### Anomaly 3: Phantom Read
- **Session 1:** Queries `WHERE balance >= 4000` (receives 2 rows).
- **Session 2:** Inserts new Account 104 with balance ₹6,000 and commits.
- **Session 1:** Executes an update or re-evaluates predicate and observes a new "phantom" row.
- **Fix:** `SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;`

---

### Anomaly 4: Lost Update & Pessimistic Locking
Prevent two concurrent withdraw transactions from overwriting each other using `FOR UPDATE`:

```sql
START TRANSACTION;

-- Exclusive lock acquired on target row
SELECT balance FROM Bank_Account WHERE account_no = 101 FOR UPDATE;

UPDATE Bank_Account SET balance = balance - 200.00 WHERE account_no = 101;

COMMIT; -- Lock released
```

---

- **Executable SQL Script:** [`transactions_concurrency.sql`](./transactions_concurrency.sql)

