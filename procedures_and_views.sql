-- ============================================
-- 3. Stored Procedures, Trigger, and Views
-- ============================================

-- ==================
-- Procedure: Book a single pending transaction
-- Creates journal entries and updates balances
-- ==================
CREATE OR REPLACE PROCEDURE book_transaction (
    p_transaction_id IN NUMBER
) AS
    v_rec Transaction_%ROWTYPE;
    v_journal_id NUMBER;
BEGIN
    -- Get the transaction
    SELECT * INTO v_rec FROM Transaction_
    WHERE transaction_id = p_transaction_id;

    -- Only book if pending
    IF v_rec.status != 'Pending' THEN
        RETURN;
    END IF;

    -- Get next journal ID
    SELECT NVL(MAX(journal_entry_id), 0) + 1 INTO v_journal_id FROM JournalEntry;

    -- Create debit journal entry
    INSERT INTO JournalEntry (journal_entry_id, transaction_id, posted_id,
        description, reference, entry_date, status)
    VALUES (v_journal_id, p_transaction_id, p_transaction_id,
        'Debit: ' || v_rec.description,
        'TXN-' || p_transaction_id || '-D', SYSDATE, 'Posted');

    -- Create credit journal entry
    INSERT INTO JournalEntry (journal_entry_id, transaction_id, posted_id,
        description, reference, entry_date, status)
    VALUES (v_journal_id + 1, p_transaction_id, p_transaction_id,
        'Credit: ' || v_rec.description,
        'TXN-' || p_transaction_id || '-C', SYSDATE, 'Posted');

    -- Update balances based on transaction type
    IF v_rec.transaction_type = 'Deposit' THEN
        UPDATE Account SET balance = balance + v_rec.amount
        WHERE account_id = v_rec.to_account_id;

    ELSIF v_rec.transaction_type = 'Withdrawal' THEN
        UPDATE Account SET balance = balance - v_rec.amount
        WHERE account_id = v_rec.from_account_id;

    ELSIF v_rec.transaction_type = 'Transfer' THEN
        UPDATE Account SET balance = balance - v_rec.amount
        WHERE account_id = v_rec.from_account_id;
        UPDATE Account SET balance = balance + v_rec.amount
        WHERE account_id = v_rec.to_account_id;
    END IF;

    -- Mark as posted
    UPDATE Transaction_ SET status = 'Posted'
    WHERE transaction_id = p_transaction_id;

    COMMIT;
END;
/

-- ==================
-- Procedure: Book all pending transactions
-- ==================
CREATE OR REPLACE PROCEDURE book_all_pending
AS
BEGIN
    FOR rec IN (
        SELECT transaction_id FROM Transaction_
        WHERE status = 'Pending'
        ORDER BY date_time
    ) LOOP
        book_transaction(rec.transaction_id);
    END LOOP;
END;
/

-- ==================
-- Procedure: Monthly interest calculation
-- Loops through active accounts and adds interest
-- ==================
CREATE OR REPLACE PROCEDURE calculate_interest (
    p_calc_date IN DATE
) AS
    v_interest  NUMBER(15,2);
    v_txn_id    NUMBER;
BEGIN
    FOR rec IN (
        SELECT a.account_id, a.balance, ir.credit_rate
        FROM Account a
        JOIN InterestRate ir ON a.rate_id = ir.rate_id
        WHERE a.status = 'Active' AND a.balance > 0
    ) LOOP
        -- Monthly interest = balance * (annual rate / 12)
        v_interest := ROUND(rec.balance * (rec.credit_rate / 12), 2);

        -- Skip if no interest
        IF v_interest = 0 THEN
            CONTINUE;
        END IF;

        -- Get next transaction ID
        SELECT NVL(MAX(transaction_id), 0) + 1 INTO v_txn_id FROM Transaction_;

        -- Create interest transaction
        INSERT INTO Transaction_ (transaction_id, account_id, from_account_id,
            to_account_id, transaction_type, amount, date_time, description, status)
        VALUES (v_txn_id, rec.account_id, NULL, rec.account_id,
            'Interest', v_interest, p_calc_date,
            'Renturokning fyri ' || TO_CHAR(p_calc_date, 'MM/YYYY'), 'Posted');

        -- Update balance
        UPDATE Account SET balance = balance + v_interest
        WHERE account_id = rec.account_id;
    END LOOP;

    COMMIT;
END;
/

-- ==================
-- Trigger: Log when a transaction is booked
-- Fires when status changes from Pending to Posted
-- ==================
CREATE TABLE TransactionLog (
    log_id          NUMBER PRIMARY KEY,
    transaction_id  NUMBER NOT NULL,
    old_status      VARCHAR2(20),
    new_status      VARCHAR2(20),
    changed_at      TIMESTAMP DEFAULT SYSTIMESTAMP
);

CREATE OR REPLACE TRIGGER trg_transaction_status
AFTER UPDATE OF status ON Transaction_
FOR EACH ROW
BEGIN
    INSERT INTO TransactionLog (log_id, transaction_id, old_status, new_status)
    VALUES (
        (SELECT NVL(MAX(log_id), 0) + 1 FROM TransactionLog),
        :OLD.transaction_id,
        :OLD.status,
        :NEW.status
    );
END;
/

-- ==================
-- View: Account statement (kontoavrit)
-- ==================
CREATE OR REPLACE VIEW v_account_statement AS
SELECT
    a.account_id,
    p.first_name || ' ' || p.last_name AS eigari,
    a.account_type,
    t.date_time,
    t.transaction_type,
    t.description,
    t.amount,
    t.status,
    a.balance AS current_balance
FROM Account a
JOIN Owns o ON a.account_id = o.account_id
JOIN Customer c ON o.customer_id = c.customer_id
JOIN Person p ON c.person_id = p.person_id
LEFT JOIN Transaction_ t ON a.account_id = t.account_id
ORDER BY a.account_id, t.date_time;

-- ==================
-- View: Customer overview with total balance
-- ==================
CREATE OR REPLACE VIEW v_customer_overview AS
SELECT
    c.customer_id,
    p.first_name || ' ' || p.last_name AS kundinavn,
    c.customer_type,
    COUNT(a.account_id) AS antal_konti,
    SUM(a.balance) AS total_saldo
FROM Customer c
JOIN Person p ON c.person_id = p.person_id
JOIN Owns o ON c.customer_id = o.customer_id
JOIN Account a ON o.account_id = a.account_id
GROUP BY c.customer_id, p.first_name, p.last_name, c.customer_type
ORDER BY c.customer_id;

-- ============================================
-- HOW TO USE:
-- ============================================
-- Book all pending transactions:
--   EXEC book_all_pending;
--
-- Book a single transaction:
--   EXEC book_transaction(1);
--
-- Run interest calculation for March:
--   EXEC calculate_interest(DATE '2026-03-31');
--
-- View results:
--   SELECT * FROM v_account_statement WHERE account_id = 1001;
--   SELECT * FROM v_customer_overview;
--   SELECT * FROM TransactionLog;
-- ============================================
