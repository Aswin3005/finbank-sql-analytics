-- ============================================================
--  FINBANK ANALYTICS  |  Portfolio SQL Project
--  Domain  : Finance / Banking
--  Author  : [Your Name]
--  Dialect : MySQL 8.0+
--  Tool    : MySQL Workbench
-- ============================================================
--  HOW TO RUN IN WORKBENCH:
--  1. Open MySQL Workbench
--  2. File > Open SQL Script > select this file
--  3. Click the lightning bolt (Run All) or Ctrl+Shift+Enter
-- ============================================================


-- ─────────────────────────────────────────────
--  DATABASE
-- ─────────────────────────────────────────────

DROP DATABASE IF EXISTS finbank;
CREATE DATABASE finbank
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE finbank;


-- ─────────────────────────────────────────────
--  SCHEMA
-- ─────────────────────────────────────────────

-- Disable FK checks during setup so drop order doesn't matter
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS branches;
SET FOREIGN_KEY_CHECKS = 1;

-- Branches
CREATE TABLE branches (
    branch_id     INT AUTO_INCREMENT PRIMARY KEY,
    branch_name   VARCHAR(60)  NOT NULL,
    city          VARCHAR(40)  NOT NULL,
    region        VARCHAR(30)  NOT NULL,        -- 'North','South','East','West'
    opened_date   DATE         NOT NULL
);

-- Customers
CREATE TABLE customers (
    customer_id    INT AUTO_INCREMENT PRIMARY KEY,
    full_name      VARCHAR(80)  NOT NULL,
    email          VARCHAR(80)  UNIQUE,
    date_of_birth  DATE         NOT NULL,
    gender         CHAR(1)      NOT NULL,
    city           VARCHAR(40),
    joined_date    DATE         NOT NULL,
    credit_score   SMALLINT,
    CONSTRAINT chk_gender       CHECK (gender IN ('M','F','O')),
    CONSTRAINT chk_credit_score CHECK (credit_score BETWEEN 300 AND 850)
);

-- Accounts
CREATE TABLE accounts (
    account_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id   INT          NOT NULL,
    branch_id     INT          NOT NULL,
    account_type  VARCHAR(20)  NOT NULL,
    opened_date   DATE         NOT NULL,
    balance       DECIMAL(14,2) DEFAULT 0.00,
    status        VARCHAR(10)  DEFAULT 'Active',
    CONSTRAINT fk_acc_customer  FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_acc_branch    FOREIGN KEY (branch_id)   REFERENCES branches(branch_id),
    CONSTRAINT chk_acc_type     CHECK (account_type IN ('Savings','Current','Fixed Deposit','Loan')),
    CONSTRAINT chk_acc_status   CHECK (status IN ('Active','Dormant','Closed'))
);

-- Transactions
CREATE TABLE transactions (
    txn_id        INT AUTO_INCREMENT PRIMARY KEY,
    account_id    INT          NOT NULL,
    txn_date      DATE         NOT NULL,
    txn_type      VARCHAR(20)  NOT NULL,
    amount        DECIMAL(12,2) NOT NULL,
    channel       VARCHAR(20)  NOT NULL,
    description   VARCHAR(120),
    CONSTRAINT fk_txn_account   FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    CONSTRAINT chk_txn_type     CHECK (txn_type IN ('Deposit','Withdrawal','Transfer','Fee','Interest')),
    CONSTRAINT chk_channel      CHECK (channel  IN ('Branch','ATM','Online','Mobile'))
);

-- Loans
CREATE TABLE loans (
    loan_id          INT AUTO_INCREMENT PRIMARY KEY,
    customer_id      INT           NOT NULL,
    branch_id        INT           NOT NULL,
    loan_type        VARCHAR(30)   NOT NULL,
    principal        DECIMAL(14,2) NOT NULL,
    interest_rate    DECIMAL(5,2)  NOT NULL,
    tenure_months    SMALLINT      NOT NULL,
    disbursed_date   DATE          NOT NULL,
    status           VARCHAR(15)   DEFAULT 'Active',
    emi_amount       DECIMAL(10,2),
    outstanding_amt  DECIMAL(14,2),
    CONSTRAINT fk_loan_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_loan_branch   FOREIGN KEY (branch_id)   REFERENCES branches(branch_id),
    CONSTRAINT chk_loan_type    CHECK (loan_type IN ('Home','Personal','Auto','Education','Business')),
    CONSTRAINT chk_loan_status  CHECK (status IN ('Active','Closed','Defaulted','NPA'))
);


-- ─────────────────────────────────────────────
--  SEED DATA
-- ─────────────────────────────────────────────

-- Branches
INSERT INTO branches (branch_name, city, region, opened_date) VALUES
 ('Connaught Place Main',  'New Delhi',  'North', '2005-03-15'),
 ('Bandra West',           'Mumbai',     'West',  '2007-08-01'),
 ('Koramangala',           'Bangalore',  'South', '2009-11-20'),
 ('Salt Lake Sector V',    'Kolkata',    'East',  '2010-04-10'),
 ('Anna Nagar',            'Chennai',    'South', '2011-07-05'),
 ('Jubilee Hills',         'Hyderabad',  'South', '2013-02-14'),
 ('Navrangpura',           'Ahmedabad',  'West',  '2015-09-30'),
 ('Civil Lines',           'Pune',       'West',  '2017-06-22');

-- Customers
INSERT INTO customers (full_name, email, date_of_birth, gender, city, joined_date, credit_score) VALUES
 ('Arjun Sharma',      'arjun.sharma@email.com',    '1985-04-12', 'M', 'New Delhi',  '2015-01-10', 780),
 ('Priya Nair',        'priya.nair@email.com',      '1990-07-23', 'F', 'Mumbai',     '2016-03-22', 720),
 ('Rahul Mehta',       'rahul.mehta@email.com',     '1978-11-05', 'M', 'Bangalore',  '2014-06-15', 650),
 ('Sneha Reddy',       'sneha.reddy@email.com',     '1993-02-18', 'F', 'Hyderabad',  '2017-09-01', 810),
 ('Vikram Singh',      'vikram.singh@email.com',    '1982-08-30', 'M', 'Pune',       '2013-11-20', 700),
 ('Anjali Patel',      'anjali.patel@email.com',    '1995-05-14', 'F', 'Ahmedabad',  '2018-02-14', 760),
 ('Kiran Kumar',       'kiran.kumar@email.com',     '1987-12-03', 'M', 'Chennai',    '2016-07-08', 630),
 ('Meena Iyer',        'meena.iyer@email.com',      '1991-09-27', 'F', 'Kolkata',    '2017-04-19', 790),
 ('Suresh Bansal',     'suresh.bansal@email.com',   '1975-03-08', 'M', 'New Delhi',  '2010-08-25', 850),
 ('Deepa Thomas',      'deepa.thomas@email.com',    '1988-06-16', 'F', 'Mumbai',     '2015-12-03', 670),
 ('Aakash Gupta',      'aakash.gupta@email.com',    '1996-01-22', 'M', 'Bangalore',  '2019-01-15', 710),
 ('Lakshmi Rao',       'lakshmi.rao@email.com',     '1983-10-11', 'F', 'Hyderabad',  '2014-03-07', 730),
 ('Ravi Desai',        'ravi.desai@email.com',      '1979-07-04', 'M', 'Ahmedabad',  '2012-05-18', 580),
 ('Pooja Joshi',       'pooja.joshi@email.com',     '1994-03-29', 'F', 'Pune',       '2018-10-22', 760),
 ('Nitin Chandra',     'nitin.chandra@email.com',   '1986-11-17', 'M', 'Chennai',    '2016-01-09', 690),
 ('Shalini Menon',     'shalini.menon@email.com',   '1992-08-08', 'F', 'Kolkata',    '2017-06-30', 800),
 ('Arun Pillai',       'arun.pillai@email.com',     '1980-05-25', 'M', 'Mumbai',     '2011-09-14', 770),
 ('Nisha Kapoor',      'nisha.kapoor@email.com',    '1997-02-13', 'F', 'New Delhi',  '2020-03-01', 690),
 ('Harish Nambiar',    'harish.nambiar@email.com',  '1984-09-06', 'M', 'Bangalore',  '2015-07-23', 620),
 ('Rekha Agarwal',     'rekha.agarwal@email.com',   '1989-12-20', 'F', 'Hyderabad',  '2016-11-11', 740),
 ('Sandeep Bose',      'sandeep.bose@email.com',    '1977-04-14', 'M', 'Kolkata',    '2009-02-27', 810),
 ('Kavita Sinha',      'kavita.sinha@email.com',    '1993-06-09', 'F', 'Pune',       '2018-08-16', 700),
 ('Mohan Krishnan',    'mohan.krishnan@email.com',  '1981-01-31', 'M', 'Chennai',    '2013-04-05', 660),
 ('Divya Saxena',      'divya.saxena@email.com',    '1998-10-17', 'F', 'Ahmedabad',  '2021-01-20', 730),
 ('Ajay Verma',        'ajay.verma@email.com',      '1976-07-07', 'M', 'New Delhi',  '2008-06-10', 840),
 ('Tara Pillai',       'tara.pillai@email.com',     '1991-03-03', 'F', 'Mumbai',     '2016-09-25', 750),
 ('Rohit Shetty',      'rohit.shetty@email.com',    '1986-08-18', 'M', 'Bangalore',  '2015-02-12', 680),
 ('Sunita Devi',       'sunita.devi@email.com',     '1984-11-24', 'F', 'Hyderabad',  '2014-10-08', 720),
 ('Prasad Kulkarni',   'prasad.kulkarni@email.com', '1978-02-09', 'M', 'Pune',       '2011-12-19', 790),
 ('Anita Ghosh',       'anita.ghosh@email.com',     '1995-09-14', 'F', 'Kolkata',    '2019-05-07', 670),
 ('Vivek Mathur',      'vivek.mathur@email.com',    '1983-04-21', 'M', 'New Delhi',  '2013-08-31', 760),
 ('Geeta Nair',        'geeta.nair@email.com',      '1990-06-28', 'F', 'Mumbai',     '2017-01-14', 810),
 ('Sunil Yadav',       'sunil.yadav@email.com',     '1975-12-15', 'M', 'Chennai',    '2010-11-03', 550),
 ('Bharti Malhotra',   'bharti.malhotra@email.com', '1996-08-05', 'F', 'Ahmedabad',  '2020-07-18', 720),
 ('Dinesh Tiwari',     'dinesh.tiwari@email.com',   '1980-03-11', 'M', 'Bangalore',  '2012-02-22', 640),
 ('Kamala Seshadri',   'kamala.seshadri@email.com', '1988-07-19', 'F', 'Hyderabad',  '2016-04-06', 780),
 ('Naveen Dubey',      'naveen.dubey@email.com',    '1993-11-08', 'M', 'Kolkata',    '2018-12-15', 710),
 ('Preethi Balaji',    'preethi.balaji@email.com',  '1987-05-30', 'F', 'Chennai',    '2015-06-21', 760),
 ('Sameer Khan',       'sameer.khan@email.com',     '1982-01-17', 'M', 'Pune',       '2013-09-09', 680),
 ('Usha Ramachandran', 'usha.ramachandran@email.com','1979-10-26','F', 'New Delhi',  '2011-03-28', 800);

-- Accounts
INSERT INTO accounts (customer_id, branch_id, account_type, opened_date, balance, status) VALUES
 (1,  1, 'Savings',       '2015-01-10', 125000.00, 'Active'),
 (1,  1, 'Fixed Deposit', '2020-03-15', 500000.00, 'Active'),
 (2,  2, 'Savings',       '2016-03-22',  45000.00, 'Active'),
 (3,  3, 'Current',       '2014-06-15', 230000.00, 'Active'),
 (4,  6, 'Savings',       '2017-09-01',  87500.00, 'Active'),
 (5,  8, 'Savings',       '2013-11-20',  62000.00, 'Dormant'),
 (6,  7, 'Current',       '2018-02-14', 310000.00, 'Active'),
 (7,  5, 'Savings',       '2016-07-08',  19000.00, 'Active'),
 (8,  4, 'Fixed Deposit', '2017-04-19', 750000.00, 'Active'),
 (9,  1, 'Savings',       '2010-08-25', 980000.00, 'Active'),
 (10, 2, 'Current',       '2015-12-03', 155000.00, 'Active'),
 (11, 3, 'Savings',       '2019-01-15',  32000.00, 'Active'),
 (12, 6, 'Current',       '2014-03-07', 420000.00, 'Active'),
 (13, 7, 'Savings',       '2012-05-18',   8500.00, 'Dormant'),
 (14, 8, 'Savings',       '2018-10-22',  93000.00, 'Active'),
 (15, 5, 'Current',       '2016-01-09', 175000.00, 'Active'),
 (16, 4, 'Savings',       '2017-06-30',  54000.00, 'Active'),
 (17, 2, 'Fixed Deposit', '2011-09-14', 300000.00, 'Active'),
 (18, 1, 'Savings',       '2020-03-01',  21000.00, 'Active'),
 (19, 3, 'Savings',       '2015-07-23',  11000.00, 'Dormant'),
 (20, 6, 'Current',       '2016-11-11', 260000.00, 'Active'),
 (21, 4, 'Savings',       '2009-02-27',1250000.00, 'Active'),
 (22, 8, 'Savings',       '2018-08-16',  70000.00, 'Active'),
 (23, 5, 'Current',       '2013-04-05', 195000.00, 'Active'),
 (24, 7, 'Savings',       '2021-01-20',  14000.00, 'Active'),
 (25, 1, 'Fixed Deposit', '2008-06-10',2000000.00, 'Active'),
 (26, 2, 'Savings',       '2016-09-25',  38000.00, 'Active'),
 (27, 3, 'Current',       '2015-02-12', 285000.00, 'Active'),
 (28, 6, 'Savings',       '2014-10-08',  67000.00, 'Active'),
 (29, 8, 'Fixed Deposit', '2011-12-19', 450000.00, 'Active'),
 (30, 4, 'Savings',       '2019-05-07',  28000.00, 'Active'),
 (31, 1, 'Current',       '2013-08-31', 510000.00, 'Active'),
 (32, 2, 'Savings',       '2017-01-14', 143000.00, 'Active'),
 (33, 5, 'Savings',       '2010-11-03',   5000.00, 'Dormant'),
 (34, 7, 'Current',       '2020-07-18',  89000.00, 'Active'),
 (35, 3, 'Savings',       '2012-02-22',  41000.00, 'Active'),
 (36, 6, 'Current',       '2016-04-06', 320000.00, 'Active'),
 (37, 4, 'Savings',       '2018-12-15',  57000.00, 'Active'),
 (38, 5, 'Savings',       '2015-06-21',  82000.00, 'Active'),
 (39, 8, 'Current',       '2013-09-09', 198000.00, 'Active'),
 (40, 1, 'Fixed Deposit', '2011-03-28', 600000.00, 'Active');

-- Transactions
INSERT INTO transactions (account_id, txn_date, txn_type, amount, channel, description) VALUES
 (1,  '2024-01-05', 'Deposit',    50000.00, 'Online',  'Salary credit'),
 (1,  '2024-01-18', 'Withdrawal', 12000.00, 'ATM',     'ATM cash withdrawal'),
 (1,  '2024-02-03', 'Fee',          250.00, 'Branch',  'Account maintenance fee'),
 (1,  '2024-02-20', 'Deposit',    50000.00, 'Online',  'Salary credit'),
 (1,  '2024-03-07', 'Transfer',   20000.00, 'Mobile',  'NEFT to account 4'),
 (2,  '2023-06-15', 'Interest',   18750.00, 'Branch',  'FD interest payout Q2'),
 (2,  '2023-12-15', 'Interest',   18750.00, 'Branch',  'FD interest payout Q4'),
 (3,  '2024-01-10', 'Deposit',   200000.00, 'Online',  'Business receipt'),
 (3,  '2024-01-25', 'Withdrawal',150000.00, 'Branch',  'Vendor payment'),
 (3,  '2024-02-12', 'Fee',          500.00, 'Online',  'Wire transfer fee'),
 (4,  '2024-01-03', 'Deposit',    30000.00, 'Mobile',  'Salary credit'),
 (4,  '2024-01-22', 'Withdrawal',  8000.00, 'ATM',     'Cash withdrawal'),
 (4,  '2024-03-01', 'Deposit',    30000.00, 'Mobile',  'Salary credit'),
 (5,  '2023-11-10', 'Deposit',    25000.00, 'Branch',  'Cash deposit'),
 (5,  '2024-01-08', 'Transfer',   15000.00, 'Online',  'IMPS to account 10'),
 (6,  '2024-01-14', 'Deposit',    80000.00, 'Online',  'Business receipt'),
 (6,  '2024-02-18', 'Withdrawal', 50000.00, 'Branch',  'Cheque payment'),
 (6,  '2024-03-05', 'Fee',          800.00, 'Online',  'International wire fee'),
 (7,  '2024-01-20', 'Deposit',    18000.00, 'ATM',     'Cash deposit'),
 (7,  '2024-02-10', 'Withdrawal',  5000.00, 'Mobile',  'Bill payment'),
 (8,  '2023-04-15', 'Interest',   26250.00, 'Branch',  'FD interest payout'),
 (8,  '2023-10-15', 'Interest',   26250.00, 'Branch',  'FD interest payout'),
 (9,  '2024-01-01', 'Deposit',   200000.00, 'Online',  'Business revenue'),
 (9,  '2024-02-01', 'Deposit',   200000.00, 'Online',  'Business revenue'),
 (9,  '2024-03-01', 'Deposit',   200000.00, 'Online',  'Business revenue'),
 (9,  '2024-01-15', 'Withdrawal',100000.00, 'Branch',  'Investment transfer'),
 (10, '2024-01-09', 'Deposit',    60000.00, 'Online',  'Salary credit'),
 (10, '2024-01-28', 'Withdrawal', 20000.00, 'ATM',     'Cash withdrawal'),
 (10, '2024-02-09', 'Deposit',    60000.00, 'Online',  'Salary credit'),
 (11, '2024-02-01', 'Deposit',    15000.00, 'Mobile',  'Part-time income'),
 (12, '2024-01-06', 'Deposit',   100000.00, 'Online',  'Business receipt'),
 (12, '2024-02-20', 'Withdrawal', 70000.00, 'Branch',  'Supplier payment'),
 (13, '2023-08-15', 'Deposit',     5000.00, 'Branch',  'Cash deposit'),
 (14, '2024-01-12', 'Deposit',    35000.00, 'Mobile',  'Salary credit'),
 (14, '2024-03-12', 'Deposit',    35000.00, 'Mobile',  'Salary credit'),
 (15, '2024-01-07', 'Deposit',    70000.00, 'Online',  'Business receipt'),
 (15, '2024-02-14', 'Withdrawal', 40000.00, 'Branch',  'Rent payment'),
 (16, '2024-01-17', 'Deposit',    22000.00, 'ATM',     'Cash deposit'),
 (17, '2023-09-14', 'Interest',   10500.00, 'Branch',  'FD interest payout'),
 (17, '2024-03-14', 'Interest',   10500.00, 'Branch',  'FD interest payout'),
 (18, '2024-01-25', 'Deposit',    10000.00, 'Mobile',  'Freelance payment'),
 (19, '2023-05-20', 'Deposit',     8000.00, 'Branch',  'Cash deposit'),
 (20, '2024-01-04', 'Deposit',   120000.00, 'Online',  'Business receipt'),
 (20, '2024-02-04', 'Withdrawal', 80000.00, 'Branch',  'Vendor payment'),
 (21, '2024-01-02', 'Deposit',   500000.00, 'Online',  'Investment proceeds'),
 (21, '2024-02-02', 'Deposit',   500000.00, 'Online',  'Investment proceeds'),
 (21, '2024-01-20', 'Transfer',  200000.00, 'Online',  'Portfolio rebalance'),
 (22, '2024-01-23', 'Deposit',    28000.00, 'Mobile',  'Salary credit'),
 (23, '2024-01-11', 'Deposit',    90000.00, 'Online',  'Business receipt'),
 (23, '2024-02-25', 'Withdrawal', 60000.00, 'Branch',  'Equipment purchase'),
 (24, '2024-02-05', 'Deposit',     7000.00, 'ATM',     'Cash deposit'),
 (25, '2023-06-10', 'Interest',   70000.00, 'Branch',  'FD interest payout H1'),
 (25, '2023-12-10', 'Interest',   70000.00, 'Branch',  'FD interest payout H2'),
 (26, '2024-01-16', 'Deposit',    18000.00, 'Mobile',  'Salary credit'),
 (27, '2024-01-08', 'Deposit',   110000.00, 'Online',  'Business receipt'),
 (27, '2024-03-08', 'Withdrawal', 70000.00, 'Branch',  'Operational expenses'),
 (28, '2024-01-21', 'Deposit',    27000.00, 'Mobile',  'Salary credit'),
 (29, '2023-12-19', 'Interest',   15750.00, 'Branch',  'FD interest payout'),
 (30, '2024-02-08', 'Deposit',    12000.00, 'ATM',     'Cash deposit'),
 (31, '2024-01-03', 'Deposit',   250000.00, 'Online',  'Business revenue'),
 (31, '2024-02-03', 'Deposit',   250000.00, 'Online',  'Business revenue'),
 (31, '2024-01-18', 'Withdrawal',150000.00, 'Branch',  'Investment transfer'),
 (32, '2024-01-13', 'Deposit',    55000.00, 'Online',  'Salary credit'),
 (32, '2024-02-13', 'Deposit',    55000.00, 'Online',  'Salary credit'),
 (33, '2023-07-25', 'Deposit',     2000.00, 'Branch',  'Cash deposit'),
 (34, '2024-01-19', 'Deposit',    40000.00, 'Mobile',  'Salary credit'),
 (35, '2024-01-24', 'Deposit',    17000.00, 'ATM',     'Cash deposit'),
 (36, '2024-01-06', 'Deposit',   150000.00, 'Online',  'Business receipt'),
 (36, '2024-02-22', 'Withdrawal', 90000.00, 'Branch',  'Inventory purchase'),
 (37, '2024-01-26', 'Deposit',    24000.00, 'Mobile',  'Salary credit'),
 (38, '2024-01-15', 'Deposit',    33000.00, 'Online',  'Salary credit'),
 (38, '2024-03-15', 'Deposit',    33000.00, 'Online',  'Salary credit'),
 (39, '2024-01-09', 'Deposit',    85000.00, 'Online',  'Business receipt'),
 (39, '2024-02-28', 'Withdrawal', 55000.00, 'Branch',  'Rent and utilities'),
 (40, '2023-03-28', 'Interest',   21000.00, 'Branch',  'FD interest payout'),
 (40, '2023-09-28', 'Interest',   21000.00, 'Branch',  'FD interest payout'),
 (1,  '2023-07-10', 'Deposit',    50000.00, 'Online',  'Salary credit'),
 (1,  '2023-08-10', 'Deposit',    50000.00, 'Online',  'Salary credit'),
 (9,  '2023-10-01', 'Deposit',   200000.00, 'Online',  'Business revenue'),
 (21, '2023-09-15', 'Deposit',   400000.00, 'Online',  'Investment proceeds'),
 (3,  '2023-11-20', 'Fee',          500.00, 'Online',  'Wire transfer fee');

-- Loans
INSERT INTO loans (customer_id, branch_id, loan_type, principal, interest_rate, tenure_months, disbursed_date, status, emi_amount, outstanding_amt) VALUES
 (1,  1, 'Home',      5000000.00, 8.50,  240, '2018-06-01', 'Active',    43391.00, 3200000.00),
 (2,  2, 'Personal',   300000.00, 13.00,  36, '2022-01-15', 'Active',    10108.00,   85000.00),
 (3,  3, 'Business',  2000000.00, 11.50,  60, '2020-04-10', 'Active',    43976.00,  950000.00),
 (4,  6, 'Auto',       600000.00,  9.75,  48, '2021-08-20', 'Active',    15137.00,  280000.00),
 (5,  8, 'Education',  400000.00, 10.50,  84, '2019-07-01', 'Closed',     6745.00,       0.00),
 (6,  7, 'Home',      3500000.00,  8.75, 180, '2019-03-01', 'Active',    34906.00, 2200000.00),
 (7,  5, 'Personal',   150000.00, 14.50,  24, '2023-02-10', 'Active',     7205.00,   80000.00),
 (8,  4, 'Auto',       800000.00,  9.50,  60, '2020-11-15', 'Active',    16744.00,  350000.00),
 (9,  1, 'Business',  8000000.00,  9.75, 120, '2017-01-20', 'Active',   104854.00, 3500000.00),
 (10, 2, 'Home',      4200000.00,  8.25, 240, '2019-09-05', 'Active',    35734.00, 3100000.00),
 (11, 3, 'Personal',   200000.00, 15.00,  24, '2022-10-01', 'Active',     9697.00,  100000.00),
 (12, 6, 'Business',  1500000.00, 12.00,  48, '2021-05-18', 'Active',    39457.00,  650000.00),
 (13, 7, 'Personal',   100000.00, 16.00,  18, '2021-06-01', 'Defaulted',  6301.00,  100000.00),
 (14, 8, 'Auto',       450000.00, 10.25,  36, '2022-04-15', 'Active',    14565.00,  200000.00),
 (15, 5, 'Home',      6000000.00,  8.50, 300, '2018-02-01', 'Active',    48262.00, 4500000.00),
 (16, 4, 'Personal',   250000.00, 13.50,  30, '2022-07-12', 'Active',     9488.00,  110000.00),
 (17, 2, 'Education',  500000.00, 10.00,  96, '2018-08-01', 'Active',     7059.00,  220000.00),
 (18, 1, 'Personal',    80000.00, 18.00,  12, '2023-04-01', 'Active',     7351.00,   40000.00),
 (19, 3, 'Auto',       350000.00, 11.00,  36, '2022-09-20', 'NPA',       11449.00,  350000.00),
 (20, 6, 'Business',   900000.00, 13.00,  36, '2022-11-01', 'Active',    30325.00,  450000.00),
 (21, 4, 'Home',      8000000.00,  7.75, 240, '2015-05-15', 'Active',    65765.00, 4000000.00),
 (22, 8, 'Personal',   120000.00, 14.00,  18, '2023-08-01', 'Active',     7441.00,   80000.00),
 (23, 5, 'Business',  3000000.00, 10.50,  84, '2019-01-10', 'Active',    50628.00, 1500000.00),
 (24, 7, 'Education',  350000.00, 10.50,  60, '2021-03-01', 'Active',     7540.00,  240000.00),
 (25, 1, 'Home',      7500000.00,  7.50, 300, '2012-09-01', 'Active',    52959.00, 3000000.00),
 (26, 2, 'Personal',   180000.00, 13.00,  24, '2022-12-01', 'Active',     8574.00,  100000.00),
 (27, 3, 'Auto',       700000.00,  9.75,  48, '2021-11-10', 'Active',    17659.00,  300000.00),
 (28, 6, 'Home',      2800000.00,  9.00, 180, '2020-07-15', 'Active',    28368.00, 2000000.00),
 (33, 5, 'Personal',   200000.00, 17.00,  24, '2021-01-15', 'NPA',        9867.00,  200000.00),
 (35, 3, 'Education',  600000.00, 10.00, 120, '2018-06-01', 'Active',     7928.00,  350000.00);

-- Verify row counts
SELECT 'branches'    AS tbl, COUNT(*) AS rows FROM branches    UNION ALL
SELECT 'customers',          COUNT(*)          FROM customers   UNION ALL
SELECT 'accounts',           COUNT(*)          FROM accounts    UNION ALL
SELECT 'transactions',       COUNT(*)          FROM transactions UNION ALL
SELECT 'loans',              COUNT(*)          FROM loans;
