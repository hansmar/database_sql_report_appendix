-- Create Tables

CREATE TABLE Person (
    person_id       NUMBER PRIMARY KEY,
    first_name      VARCHAR2(100) NOT NULL,
    last_name       VARCHAR2(100) NOT NULL,
    email           VARCHAR2(255),
    phone           VARCHAR2(50),
    national_id     VARCHAR2(50) UNIQUE,
    zip_code        VARCHAR2(20),
    town_name       VARCHAR2(100)
);

CREATE TABLE Employee (
    employee_id     NUMBER PRIMARY KEY,
    person_id       NUMBER NOT NULL UNIQUE,
    start_date      DATE NOT NULL,
    end_date        DATE,
    contract        VARCHAR2(100),
    FOREIGN KEY (person_id) REFERENCES Person(person_id)
);

CREATE TABLE Customer (
    customer_id     NUMBER PRIMARY KEY,
    person_id       NUMBER NOT NULL UNIQUE,
    customer_type   VARCHAR2(50),
    FOREIGN KEY (person_id) REFERENCES Person(person_id)
);

CREATE TABLE Family (
    family_id           NUMBER PRIMARY KEY,
    guardian_person_id  NUMBER NOT NULL,
    child_person_id     NUMBER NOT NULL,
    family_name         VARCHAR2(100),
    valid_from          DATE,
    relationship_type   VARCHAR2(50),
    FOREIGN KEY (guardian_person_id) REFERENCES Person(person_id),
    FOREIGN KEY (child_person_id)    REFERENCES Person(person_id)
);

CREATE TABLE InterestRate (
    rate_id             NUMBER PRIMARY KEY,
    calculated_method   VARCHAR2(100),
    debit_rate          NUMBER(10, 4),
    credit_rate         NUMBER(10, 4),
    account_type        VARCHAR2(50)
);

CREATE TABLE Account (
    account_id      NUMBER PRIMARY KEY,
    balance         NUMBER(15, 2),
    opened_date     DATE NOT NULL,
    status          VARCHAR2(50),
    account_type    VARCHAR2(50),
    rate_id         NUMBER,
    FOREIGN KEY (rate_id) REFERENCES InterestRate(rate_id)
);

CREATE TABLE Serves (
    employee_id     NUMBER NOT NULL,
    customer_id     NUMBER NOT NULL,
    PRIMARY KEY (employee_id, customer_id),
    FOREIGN KEY (employee_id) REFERENCES Employee(employee_id),
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id)
);

CREATE TABLE Owns (
    customer_id     NUMBER NOT NULL,
    account_id      NUMBER NOT NULL,
    PRIMARY KEY (customer_id, account_id),
    FOREIGN KEY (customer_id) REFERENCES Customer(customer_id),
    FOREIGN KEY (account_id)  REFERENCES Account(account_id)
);

CREATE TABLE Transaction_ (
    transaction_id      NUMBER PRIMARY KEY,
    account_id          NUMBER NOT NULL,
    from_account_id     NUMBER,
    to_account_id       NUMBER,
    transaction_type    VARCHAR2(50),
    amount              NUMBER(15, 2) NOT NULL CHECK (amount > 0),
    date_time           TIMESTAMP NOT NULL,
    description         VARCHAR2(255),
    status              VARCHAR2(20) DEFAULT 'Pending',
    FOREIGN KEY (account_id)      REFERENCES Account(account_id),
    FOREIGN KEY (from_account_id) REFERENCES Account(account_id),
    FOREIGN KEY (to_account_id)   REFERENCES Account(account_id)
);

CREATE TABLE JournalEntry (
    journal_entry_id    NUMBER PRIMARY KEY,
    transaction_id      NUMBER NOT NULL,
    posted_id           NUMBER,
    description         VARCHAR2(255),
    reference           VARCHAR2(100),
    entry_date          DATE NOT NULL,
    status              VARCHAR2(50),
    FOREIGN KEY (transaction_id) REFERENCES Transaction_(transaction_id)
);
