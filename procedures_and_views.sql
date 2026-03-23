-- Stored Procedures, Trigger, and Views

CREATE OR REPLACE PROCEDURE book_transaction (
    p_transaction_id IN NUMBER,
    p_auto_commit    IN BOOLEAN DEFAULT TRUE
) AS
    v_rec        Transaction_%ROWTYPE;
    v_journal_id NUMBER;
    v_balance    NUMBER(15,2);
    e_insufficient_funds EXCEPTION;
BEGIN
    -- Get the transaction
    SELECT * INTO v_rec FROM Transaction_
    WHERE transaction_id = p_transaction_id;

    -- Only book if pending
    IF v_rec.status != 'Pending' THEN
        RETURN;
    END IF;

    -- Check sufficient balance for withdrawals and transfers
    IF v_rec.transaction_type IN ('Withdrawal', 'Transfer') THEN
        SELECT balance INTO v_balance FROM Account
        WHERE account_id = v_rec.from_account_id;

        IF v_balance < v_rec.amount THEN
            RAISE e_insufficient_funds;
        END IF;
    END IF;

    -- Create debit journal entry (using sequence)
    INSERT INTO JournalEntry (journal_entry_id, transaction_id, posted_id,
        description, reference, entry_date, status)
    VALUES (seq_journal.NEXTVAL, p_transaction_id, p_transaction_id,
        'Debit: ' || v_rec.description,
        'TXN-' || p_transaction_id || '-D', SYSDATE, 'Posted');

    -- Create credit journal entry (using sequence)
    INSERT INTO JournalEntry (journal_entry_id, transaction_id, posted_id,
        description, reference, entry_date, status)
    VALUES (seq_journal.NEXTVAL, p_transaction_id, p_transaction_id,
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

    -- Only commit if called directly (not from book_all_pending)
    IF p_auto_commit THEN
        COMMIT;
    END IF;

EXCEPTION
    WHEN e_insufficient_funds THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001,
            'Ikki nóg innistand á konti ' || v_rec.from_account_id ||
            '. Saldo: ' || v_balance || ', Upphædd: ' || v_rec.amount);
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002,
            'Transaktión ' || p_transaction_id || ' finnst ikki.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- Procedure: Book all pending transactions

CREATE OR REPLACE PROCEDURE book_all_pending
AS
BEGIN
    FOR rec IN (
        SELECT transaction_id FROM Transaction_
        WHERE status = 'Pending'
        ORDER BY date_time
    ) LOOP
        -- Pass FALSE so book_transaction does not commit individually
        book_transaction(rec.transaction_id, p_auto_commit => FALSE);
    END LOOP;

    -- Single commit after all transactions are booked
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- Procedure: Monthly interest calculation

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

        -- Get next transaction ID from sequence
        v_txn_id := seq_transaction.NEXTVAL;

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

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/


-- Trigger: Log when a transaction is booked

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
        seq_log.NEXTVAL,
        :OLD.transaction_id,
        :OLD.status,
        :NEW.status
    );
END;
/


-- View: Account statement (kontoavrit)

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
LEFT JOIN Transaction_ t ON (
    (t.transaction_type IN ('Deposit', 'Withdrawal', 'Interest')
        AND t.account_id = a.account_id)
    OR
    (t.transaction_type = 'Transfer'
        AND (t.from_account_id = a.account_id
             OR t.to_account_id = a.account_id))
)
ORDER BY a.account_id, t.date_time;


-- View: Customer overview with total balance

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
