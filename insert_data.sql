-- ============================================
-- 2. Sample Data (Oracle)
-- Set SQL Developer encoding: Tools > Preferences > Environment > UTF-8
-- Safe to re-run: deletes existing data first
-- ============================================

DELETE FROM JournalEntry;
DELETE FROM Transaction_;
DELETE FROM Serves;
DELETE FROM Owns;
DELETE FROM Account;
DELETE FROM InterestRate;
DELETE FROM Family;
DELETE FROM Customer;
DELETE FROM Employee;
DELETE FROM Person;

-- Persons
INSERT INTO Person VALUES (1, 'Jógvan', 'Petersen', 'jogvan@email.fo', '+298 123456', '120785-1234', 'FO-100', 'Tórshavn');
INSERT INTO Person VALUES (2, 'Katrin', 'Petersen', 'katrin@email.fo', '+298 234567', '050388-5678', 'FO-100', 'Tórshavn');
INSERT INTO Person VALUES (3, 'Brandur', 'Petersen', 'brandur@email.fo', '+298 345678', '220510-9012', 'FO-100', 'Tórshavn');
INSERT INTO Person VALUES (4, 'Anna', 'Joensen', 'anna@email.fo', '+298 456789', '150692-3456', 'FO-110', 'Tórshavn');
INSERT INTO Person VALUES (5, 'Súni', 'Djurhuus', 'suni@email.fo', '+298 567890', '280175-7890', 'FO-200', 'Hoyvík');
INSERT INTO Person VALUES (6, 'Rógvi', 'Patursson', 'rogvi@email.fo', '+298 678901', '030990-2345', 'FO-400', 'Vágur');
INSERT INTO Person VALUES (7, 'Maria', 'Hansen', 'maria@email.fo', '+298 789012', '110895-6789', 'FO-360', 'Sandavágur');
INSERT INTO Person VALUES (8, 'Hans', 'Blaasvær', 'hans@email.fo', '+298 890123', '250670-1111', 'FO-100', 'Tórshavn');

-- Employees
INSERT INTO Employee VALUES (1, 5, DATE '2010-03-15', NULL, 'Fulltime');
INSERT INTO Employee VALUES (2, 6, DATE '2018-08-01', NULL, 'Fulltime');
INSERT INTO Employee VALUES (3, 7, DATE '2022-01-10', NULL, 'Part-time');

-- Customers
INSERT INTO Customer VALUES (1, 1, 'Private');
INSERT INTO Customer VALUES (2, 2, 'Private');
INSERT INTO Customer VALUES (3, 3, 'Private');
INSERT INTO Customer VALUES (4, 4, 'Private');
INSERT INTO Customer VALUES (5, 8, 'Business');

-- Family (Jógvan + Katrin = hjúnarfelagar, Brandur = barn)
INSERT INTO Family VALUES (1, 1, 3, 'Petersen', DATE '2010-05-22', 'Parent-Child');
INSERT INTO Family VALUES (2, 2, 3, 'Petersen', DATE '2010-05-22', 'Parent-Child');
INSERT INTO Family VALUES (3, 1, 2, 'Petersen', DATE '2008-06-14', 'Spouse');
INSERT INTO Family VALUES (4, 2, 1, 'Petersen', DATE '2008-06-14', 'Spouse');

-- Interest Rates
INSERT INTO InterestRate VALUES (1, 'Monthly', 0.0500, 0.0100, 'Savings');
INSERT INTO InterestRate VALUES (2, 'Monthly', 0.1200, 0.0000, 'Checking');
INSERT INTO InterestRate VALUES (3, 'Monthly', 0.0350, 0.0200, 'Business');

-- Accounts
INSERT INTO Account VALUES (1001, 45000.00, DATE '2015-04-10', 'Active', 'Checking', 2);
INSERT INTO Account VALUES (1002, 120000.00, DATE '2016-01-20', 'Active', 'Savings', 1);
INSERT INTO Account VALUES (1003, 67500.00, DATE '2015-04-10', 'Active', 'Checking', 2);
INSERT INTO Account VALUES (1004, 8500.00, DATE '2020-09-01', 'Active', 'Savings', 1);
INSERT INTO Account VALUES (1005, 32000.00, DATE '2019-11-05', 'Active', 'Checking', 2);
INSERT INTO Account VALUES (1006, 250000.00, DATE '2019-11-05', 'Active', 'Savings', 1);
INSERT INTO Account VALUES (1007, 500000.00, DATE '2012-02-28', 'Active', 'Business', 3);

-- Owns
INSERT INTO Owns VALUES (1, 1001);
INSERT INTO Owns VALUES (1, 1002);
INSERT INTO Owns VALUES (2, 1003);
INSERT INTO Owns VALUES (3, 1004);
INSERT INTO Owns VALUES (4, 1005);
INSERT INTO Owns VALUES (4, 1006);
INSERT INTO Owns VALUES (5, 1007);

-- Serves
INSERT INTO Serves VALUES (1, 1);
INSERT INTO Serves VALUES (1, 2);
INSERT INTO Serves VALUES (1, 3);
INSERT INTO Serves VALUES (2, 4);
INSERT INTO Serves VALUES (2, 5);
INSERT INTO Serves VALUES (3, 1);

-- Transactions (March 1-7, 2026)
INSERT INTO Transaction_ VALUES (1, 1001, NULL, 1001, 'Deposit', 15000.00, TIMESTAMP '2026-03-01 08:15:00', 'Lønargreiðsla', 'Pending');
INSERT INTO Transaction_ VALUES (2, 1003, NULL, 1003, 'Deposit', 14000.00, TIMESTAMP '2026-03-01 08:42:00', 'Lønargreiðsla', 'Pending');
INSERT INTO Transaction_ VALUES (3, 1001, 1001, 1002, 'Transfer', 5000.00, TIMESTAMP '2026-03-02 10:30:00', 'Flutt til sparikonto', 'Pending');
INSERT INTO Transaction_ VALUES (4, 1005, 1005, NULL, 'Withdrawal', 2000.00, TIMESTAMP '2026-03-03 11:15:00', 'Úttøka í bankaautomati', 'Pending');
INSERT INTO Transaction_ VALUES (5, 1004, NULL, 1004, 'Deposit', 500.00, TIMESTAMP '2026-03-04 09:00:00', 'Tøkupengar', 'Pending');
INSERT INTO Transaction_ VALUES (6, 1005, 1005, 1001, 'Transfer', 3500.00, TIMESTAMP '2026-03-05 14:20:00', 'Rúmleiga', 'Pending');
INSERT INTO Transaction_ VALUES (7, 1007, NULL, 1007, 'Deposit', 75000.00, TIMESTAMP '2026-03-06 08:00:00', 'Faktura #2026-041', 'Pending');
INSERT INTO Transaction_ VALUES (8, 1001, 1001, 1004, 'Transfer', 1000.00, TIMESTAMP '2026-03-07 12:30:00', 'Mánaðarpengar til Brandur', 'Pending');

COMMIT;
