# 🏦 FinBank Analytics — SQL Portfolio Project

**Domain:** Finance / Banking  
**Tool:** MySQL Workbench (MySQL 8.0+)  
**Skills:** CTEs, Window Functions, JOINs, Subqueries, Aggregations, Date Functions  

---

## 📌 Project Overview

This project simulates a real-world banking analytics database for a fictional bank — **FinBank**.  
It covers customer segmentation, transaction trend analysis, loan risk assessment, branch performance, and executive reporting.

The goal is to answer **15 business questions** that a Data Analyst would be expected to solve in a banking or fintech environment.

---

## 🗂️ Database Schema

The database contains **5 related tables:**

```
branches      → 8 rows   — Bank branches across India (city, region)
customers     → 40 rows  — Customer profiles with credit scores
accounts      → 41 rows  — Savings, Current, and Fixed Deposit accounts
transactions  → 81 rows  — Deposits, withdrawals, transfers, fees, interest
loans         → 30 rows  — Home, auto, personal, education, business loans
```

**Entity Relationship:**
```
branches ──< accounts >── customers
branches ──< loans    >── customers
accounts ──< transactions
```

---

## 📁 Files

| File | Description |
|------|-------------|
| `01_dataset_setup_mysql.sql` | Creates the database, tables, and inserts all seed data |
| `02_analysis_queries_mysql.sql` | 15 business analysis queries across 6 sections |

---

## 📊 Business Questions & Queries

---

### Section 1 — Customer Segmentation

---

#### Q1. Which customers are our highest-value clients?
**Business use:** Target Platinum and Gold customers for wealth management and premium offers.  

```sql
WITH customer_balances AS (
    SELECT
        c.customer_id,
        c.full_name,
        c.city,
        c.credit_score,
        SUM(a.balance) AS total_balance
    FROM customers c
    JOIN accounts a USING (customer_id)
    WHERE a.status = 'Active'
    GROUP BY c.customer_id, c.full_name, c.city, c.credit_score
),
segmented AS (
    SELECT *,
        NTILE(4) OVER (ORDER BY total_balance DESC) AS quartile,
        CASE NTILE(4) OVER (ORDER BY total_balance DESC)
            WHEN 1 THEN 'Platinum'
            WHEN 2 THEN 'Gold'
            WHEN 3 THEN 'Silver'
            ELSE        'Standard'
        END AS segment
    FROM customer_balances
)
SELECT
    segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_balance), 2) AS avg_balance,
    ROUND(AVG(credit_score), 1) AS avg_credit_score,
    SUM(total_balance) AS total_aum
FROM segmented
GROUP BY segment
ORDER BY total_aum DESC;
```
<img width="582" height="187" alt="Image" src="https://github.com/user-attachments/assets/2accfdb9-2caf-4d27-b83e-525720a317d0" />

---

#### Q2. Which customers have been inactive for over 180 days?
**Business use:** Build a re-engagement campaign list for dormant account holders.  

```sql
WITH last_txn AS (
    SELECT
        a.customer_id,
        MAX(t.txn_date) AS last_txn_date
    FROM transactions t
    JOIN accounts a USING (account_id)
    GROUP BY a.customer_id
)
SELECT
    c.customer_id,
    c.full_name,
    c.email,
    lt.last_txn_date,
    DATEDIFF(CURDATE(), lt.last_txn_date) AS days_since_last_txn
FROM customers c
LEFT JOIN last_txn lt USING (customer_id)
WHERE lt.last_txn_date IS NULL
   OR lt.last_txn_date < CURDATE() - INTERVAL 180 DAY
ORDER BY days_since_last_txn DESC;
```
<img width="687" height="248" alt="Image" src="https://github.com/user-attachments/assets/b041e7cd-0546-4a1b-9292-6e0588640746" />

---

### Section 2 — Transaction Trend Analysis

---

#### Q3. How has monthly transaction volume changed month over month?
**Business use:** Track business growth and identify seasonal patterns in deposits and withdrawals.  

```sql
WITH monthly AS (
    SELECT
        DATE_FORMAT(txn_date, '%Y-%m-01') AS txn_month,
        COUNT(*) AS txn_count,
        SUM(amount) AS total_amount
    FROM transactions
    WHERE txn_type IN ('Deposit', 'Withdrawal')
    GROUP BY DATE_FORMAT(txn_date, '%Y-%m-01')
),
with_lag AS (
    SELECT *,
        LAG(total_amount) OVER (ORDER BY txn_month) AS prev_month_amount
    FROM monthly
)
SELECT
    txn_month,
    txn_count,
    ROUND(total_amount, 2) AS total_amount,
    ROUND(
        100.0 * (total_amount - prev_month_amount)
        / NULLIF(prev_month_amount, 0),2) AS mom_pct_change
FROM with_lag
ORDER BY txn_month;
```

<img width="442" height="265" alt="Image" src="https://github.com/user-attachments/assets/5200ca63-8253-41d0-a9bc-f3dc1eb0ecf7" />

---

#### Q4. What is the running balance for each account over time?
**Business use:** Reconstruct account statements and detect potential overdrafts.  

```sql
SELECT
    t.txn_id,
    t.account_id,
    c.full_name,
    t.txn_date,
    t.txn_type,
    t.amount,
    SUM(
        CASE
            WHEN t.txn_type IN ('Deposit', 'Interest') THEN  t.amount
            WHEN t.txn_type IN ('Withdrawal', 'Fee', 'Transfer') THEN -t.amount
            ELSE 0
        END
    ) OVER (
        PARTITION BY t.account_id
        ORDER BY t.txn_date, t.txn_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM transactions t
JOIN accounts  a USING (account_id)
JOIN customers c ON c.customer_id = a.customer_id
ORDER BY t.account_id, t.txn_date;
```

<img width="692" height="232" alt="Image" src="https://github.com/user-attachments/assets/fcb08875-aafa-4b67-92d4-565c96d32470" />

---

#### Q5. What percentage of transactions happen through each channel per year?
**Business use:** Track digital adoption — how fast are customers moving from Branch/ATM to Online/Mobile?  

```sql
SELECT
    YEAR(txn_date) AS txn_year,
    channel,
    COUNT(*) AS txn_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY YEAR(txn_date)),2) AS channel_share_pct
FROM transactions
GROUP BY YEAR(txn_date), channel
ORDER BY txn_year, txn_count DESC;
```
<img width="415" height="177" alt="Image" src="https://github.com/user-attachments/assets/44d1f2ee-755d-4a45-8fb7-9d11076300f1" />

---

### Section 3 — Loan Portfolio Risk Analysis

---

#### Q6. What does the loan portfolio look like by type and status?
**Business use:** Credit risk dashboard — see where the bank's loan exposure is concentrated.  

```sql
SELECT
    loan_type,
    status,
    COUNT(*) AS loan_count,
    SUM(principal) AS total_principal,
    SUM(outstanding_amt) AS total_outstanding,
    ROUND(AVG(interest_rate), 2) AS avg_rate,
    ROUND(
        100.0 * SUM(outstanding_amt)
        / SUM(SUM(outstanding_amt)) OVER (),
    2)                                   AS portfolio_share_pct
FROM loans
GROUP BY loan_type, status
ORDER BY total_outstanding DESC;
```
<img width="752" height="225" alt="Image" src="https://github.com/user-attachments/assets/adf1becb-009c-4bfd-ac75-445cbf0c680d" />

---

#### Q7. Which NPA and defaulted loan customers had low credit scores?
**Business use:** Validate whether the credit scoring model correctly predicted risk at the time of disbursement.  

```sql
SELECT
    c.customer_id,
    c.full_name,
    c.credit_score,
    l.loan_type,
    l.principal,
    l.outstanding_amt,
    l.status AS loan_status,
    l.disbursed_date,
    c.credit_score - (SELECT ROUND(AVG(credit_score), 1)
                      FROM customers) AS score_vs_avg
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
WHERE l.status IN ('NPA', 'Defaulted')
ORDER BY l.outstanding_amt DESC;
```

<img width="952" height="105" alt="Image" src="https://github.com/user-attachments/assets/b30b209c-3a99-439d-bab1-c13edeb8092f" />

---

#### Q8. Which customers are over-leveraged relative to their deposits?
**Business use:** Flag customers for credit limit review before approving new loans.  

```sql
WITH deposits AS (
    SELECT
        customer_id,
        SUM(balance) AS total_deposits
    FROM accounts
    WHERE account_type IN ('Savings', 'Current')
    GROUP BY customer_id
),
loan_exposure AS (
    SELECT
        customer_id,
        SUM(outstanding_amt) AS total_outstanding
    FROM loans
    WHERE status = 'Active'
    GROUP BY customer_id
)
SELECT
    c.customer_id,
    c.full_name,
    c.credit_score,
    COALESCE(d.total_deposits, 0)     AS total_deposits,
    COALESCE(le.total_outstanding, 0) AS total_outstanding,
    ROUND(
        COALESCE(le.total_outstanding, 0)
        / NULLIF(COALESCE(d.total_deposits, 0), 0), 2) AS debt_to_deposit_ratio,
    CASE
        WHEN COALESCE(le.total_outstanding, 0) = 0 THEN 'No Debt'
        WHEN COALESCE(le.total_outstanding, 0)
             / NULLIF(COALESCE(d.total_deposits, 0), 0) > 5 THEN 'High Risk'
        WHEN COALESCE(le.total_outstanding, 0)
             / NULLIF(COALESCE(d.total_deposits, 0), 0) > 2 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_flag
FROM customers c
LEFT JOIN deposits d USING (customer_id)
LEFT JOIN loan_exposure le USING (customer_id)
ORDER BY debt_to_deposit_ratio DESC;
```

<img width="842" height="223" alt="Image" src="https://github.com/user-attachments/assets/8144d0e4-155e-4d0a-a592-73ae50a4afb6" />

---

### Section 4 — Branch Performance

---

#### Q9. How do branches rank against each other within their region?
**Business use:** Regional performance review — identify top and underperforming branches.  

```sql
SELECT
    b.branch_id,
    b.branch_name,
    b.region,
    COUNT(DISTINCT a.account_id) AS total_accounts,
    COUNT(DISTINCT a.customer_id) AS total_customers,
    SUM(a.balance) AS total_deposits,
    COUNT(DISTINCT l.loan_id) AS total_loans,
    SUM(l.principal) AS total_loan_book,
    ROUND(AVG(c.credit_score), 1)    AS avg_credit_score,
    RANK() OVER (
        PARTITION BY b.region
        ORDER BY SUM(a.balance) + COALESCE(SUM(l.principal), 0) DESC
    ) AS rank_in_region
FROM branches b
LEFT JOIN accounts  a ON a.branch_id   = b.branch_id AND a.status = 'Active'
LEFT JOIN loans     l ON l.branch_id   = b.branch_id AND l.status = 'Active'
LEFT JOIN customers c ON c.customer_id = a.customer_id
GROUP BY b.branch_id, b.branch_name, b.region
ORDER BY b.region, rank_in_region;
```

<img width="1110" height="205" alt="Image" src="https://github.com/user-attachments/assets/e7d12036-6f44-429b-a47d-f5359be1a99c" />

---

#### Q10. Who are the top 3 depositors at each branch?
**Business use:** Identify VIP customers per branch for relationship manager assignment.  

```sql
WITH ranked AS (
    SELECT
        b.branch_name,
        c.full_name,
        SUM(a.balance) AS total_balance,
        DENSE_RANK() OVER (
            PARTITION BY b.branch_id
            ORDER BY SUM(a.balance) DESC
        ) AS rnk
    FROM accounts a
    JOIN branches  b ON b.branch_id   = a.branch_id
    JOIN customers c ON c.customer_id = a.customer_id
    WHERE a.status = 'Active'
    GROUP BY b.branch_id, b.branch_name, c.customer_id, c.full_name
)
SELECT branch_name, rnk, full_name, total_balance
FROM ranked
WHERE rnk <= 3
ORDER BY branch_name, rnk;
```
<img width="452" height="226" alt="Image" src="https://github.com/user-attachments/assets/c69f5d5d-1b4c-4ad7-a12a-5573549636ee" />

---

### Section 5 — Customer & Product Analysis

---

#### Q11. How many new customers joined each year and what is their average credit score?
**Business use:** Track customer acquisition trends and the quality of new customers over time.  

```sql
SELECT
    YEAR(joined_date) AS join_year,
    COUNT(*) AS new_customers,
    ROUND(AVG(credit_score), 1) AS avg_credit_score,
    MIN(credit_score) AS lowest_score,
    MAX(credit_score) AS highest_score
FROM customers
GROUP BY YEAR(joined_date)
ORDER BY join_year;
```
<img width="567" height="342" alt="Image" src="https://github.com/user-attachments/assets/26236b34-dcec-4052-8530-078bd783b70c" />

---

#### Q12. Which loan types have the most outstanding debt and bad loans?
**Business use:** Product team uses this to adjust lending strategy — reduce exposure in high-risk categories.  

```sql
SELECT
    loan_type,
    COUNT(*) AS total_loans,
    ROUND(SUM(principal), 0) AS total_disbursed,
    ROUND(SUM(outstanding_amt), 0) AS total_outstanding,
    ROUND(SUM(principal) - SUM(outstanding_amt), 0) AS total_repaid,
    ROUND(AVG(interest_rate), 2) AS avg_interest_rate,
    COUNT(CASE WHEN status = 'Active' THEN 1 END) AS active_loans,
    COUNT(CASE WHEN status IN ('Defaulted','NPA') THEN 1 END) AS bad_loans
FROM loans
GROUP BY loan_type
ORDER BY total_disbursed DESC;
```
<img width="862" height="162" alt="Image" src="https://github.com/user-attachments/assets/ab0abe9c-0a0f-41b2-88c1-e75deb4be9d9" />

---

#### Q13. Which large deposits might need a closer look?
**Business use:** Compliance team flags high-value deposits for review based on amount thresholds.  

```sql
SELECT
    t.txn_id,
    c.full_name,
    c.city,
    a.account_type,
    t.txn_date,
    t.amount,
    t.channel,
    CASE
        WHEN t.amount >= 500000 THEN 'Very Large'
        WHEN t.amount >= 200000 THEN 'Large'
        ELSE 'Moderate'
    END AS deposit_category
FROM transactions t
JOIN accounts  a ON a.account_id  = t.account_id
JOIN customers c ON c.customer_id = a.customer_id
WHERE t.txn_type = 'Deposit'
  AND t.amount  >= 100000
ORDER BY t.amount DESC;
```

<img width="787" height="337" alt="Image" src="https://github.com/user-attachments/assets/7c3941fe-e1aa-4cea-959b-e499d9511c7f" />

---

#### Q14. When do Fixed Deposits mature and how much interest will be paid?
**Business use:** Treasury team plans cash outflows by knowing when FDs mature and how much interest is owed.  

```sql
SELECT
    c.full_name,
    c.city,
    a.balance AS fd_amount,
    a.opened_date,
    ROUND(a.balance * 0.07, 2) AS annual_interest,
    ROUND(a.balance * 0.07 / 12, 2) AS monthly_interest,
    DATE_ADD(a.opened_date, INTERVAL 1 YEAR)  AS first_maturity_date,
    DATEDIFF(
        DATE_ADD(a.opened_date, INTERVAL 1 YEAR),
        CURDATE()
    ) AS days_to_maturity
FROM accounts a
JOIN customers c USING (customer_id)
WHERE a.account_type = 'Fixed Deposit'
  AND a.status = 'Active'
ORDER BY annual_interest DESC;
```

<img width="972" height="168" alt="Image" src="https://github.com/user-attachments/assets/209d2afc-1642-4a62-a647-2766f6ad0d1a" />

---

### Section 6 — Executive Summary Dashboard

---

#### Q15. What is the overall health of the bank in one report?
**Business use:** Management dashboard — a single query that gives the C-suite a snapshot of all key metrics.  
**Concepts:** `UNION ALL`, `COUNT()`, `SUM()`, `AVG()`, `ROUND()`, `WHERE` filters per metric

```sql
SELECT 'Total customers'          AS metric, COUNT(*)               AS value FROM customers
UNION ALL
SELECT 'Active accounts',           COUNT(*)                         FROM accounts    WHERE status = 'Active'
UNION ALL
SELECT 'Dormant accounts',          COUNT(*)                         FROM accounts    WHERE status = 'Dormant'
UNION ALL
SELECT 'Total deposits (AUM)',       ROUND(SUM(balance), 0)          FROM accounts    WHERE status = 'Active'
UNION ALL
SELECT 'Active loans',              COUNT(*)                         FROM loans       WHERE status = 'Active'
UNION ALL
SELECT 'Total loan book',           ROUND(SUM(outstanding_amt), 0)   FROM loans       WHERE status = 'Active'
UNION ALL
SELECT 'NPA + Defaulted loans',     COUNT(*)                         FROM loans       WHERE status IN ('NPA','Defaulted')
UNION ALL
SELECT 'NPA exposure (amount)',     ROUND(SUM(outstanding_amt), 0)   FROM loans       WHERE status IN ('NPA','Defaulted')
UNION ALL
SELECT 'Avg customer credit score', ROUND(AVG(credit_score), 1)      FROM customers
UNION ALL
SELECT 'Total transactions',        COUNT(*)                         FROM transactions
UNION ALL
SELECT 'Total deposit amount',      ROUND(SUM(amount), 0)            FROM transactions WHERE txn_type = 'Deposit'
UNION ALL
SELECT 'Total withdrawal amount',   ROUND(SUM(amount), 0)            FROM transactions WHERE txn_type = 'Withdrawal';
```

<img width="317" height="306" alt="Image" src="https://github.com/user-attachments/assets/1b76a57e-6b0c-4525-b3b3-6d45ed7e0308" />

---

## 🧠 SQL Concepts Covered

| Concept | Used In |
|--------|---------|
| Common Table Expressions (CTEs) | Q1, Q2, Q3, Q8, Q10 |
| Window Functions (`RANK`, `DENSE_RANK`, `NTILE`, `LAG`) | Q1, Q3, Q5, Q9, Q10 |
| Running Totals (`SUM OVER` with frame) | Q4 |
| Multi-table JOINs | Q4, Q9, Q10, Q13 |
| LEFT JOIN for missing data | Q2, Q8, Q9 |
| Subqueries | Q7 |
| CASE WHEN | Q1, Q4, Q8, Q12, Q13 |
| COALESCE / NULLIF | Q3, Q8 |
| Date Functions (`YEAR`, `DATEDIFF`, `DATE_ADD`, `CURDATE`) | Q2, Q3, Q11, Q14 |
| UNION ALL | Q15 |
| Aggregations (`SUM`, `COUNT`, `AVG`, `MIN`, `MAX`) | All sections |
