-- ============================================================
--  FINBANK ANALYTICS  |  Analysis Queries
--  Domain  : Finance / Banking
--  Dialect : MySQL 8.0+
--  Tool    : MySQL Workbench
-- ============================================================
--  HOW TO RUN:
--  Run each query individually — select the query text,
--  then press Ctrl+Shift+Enter (or click the lightning bolt)
--  TIP: Run 01_dataset_setup_mysql.sql FIRST before this file
-- ============================================================

USE finbank;


-- ─────────────────────────────────────────────
--  SECTION 1 : CUSTOMER SEGMENTATION
-- ─────────────────────────────────────────────

-- Q1. Segment customers by total balance using NTILE
--     Business use: target high-value clients for wealth management
--     MySQL change: identical to PostgreSQL — NTILE is supported in MySQL 8+

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
    COUNT(*)                        AS customer_count,
    ROUND(AVG(total_balance), 2)    AS avg_balance,
    ROUND(AVG(credit_score), 1)     AS avg_credit_score,
    SUM(total_balance)              AS total_aum
FROM segmented
GROUP BY segment
ORDER BY total_aum DESC;


-- Q2. Dormant customers — no transaction in last 180 days
--     Business use: re-engagement campaign targeting
--     MySQL change: INTERVAL '180 days' → INTERVAL 180 DAY
--                   CURRENT_DATE stays the same in MySQL

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


-- ─────────────────────────────────────────────
--  SECTION 2 : TRANSACTION TREND ANALYSIS
-- ─────────────────────────────────────────────

-- Q3. Monthly transaction volume with Month-over-Month % change
--     Business use: track growth trends and seasonal patterns
--     MySQL change: DATE_TRUNC → DATE_FORMAT
--                   LAG() is supported in MySQL 8+

WITH monthly AS (
    SELECT
        DATE_FORMAT(txn_date, '%Y-%m-01') AS txn_month,
        COUNT(*)                           AS txn_count,
        SUM(amount)                        AS total_amount
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
    ROUND(total_amount, 2)                                          AS total_amount,
    ROUND(
        100.0 * (total_amount - prev_month_amount)
        / NULLIF(prev_month_amount, 0),
    2)                                                              AS mom_pct_change
FROM with_lag
ORDER BY txn_month;


-- Q4. Running balance per account (cumulative sum)
--     Business use: reconstruct account statement, detect overdrafts
--     MySQL change: none — window frame syntax is identical

SELECT
    t.txn_id,
    t.account_id,
    c.full_name,
    t.txn_date,
    t.txn_type,
    t.amount,
    SUM(
        CASE
            WHEN t.txn_type IN ('Deposit', 'Interest')             THEN  t.amount
            WHEN t.txn_type IN ('Withdrawal', 'Fee', 'Transfer')   THEN -t.amount
            ELSE 0
        END
    ) OVER (
        PARTITION BY t.account_id
        ORDER BY t.txn_date, t.txn_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM transactions t
JOIN accounts   a  USING (account_id)
JOIN customers  c  ON c.customer_id = a.customer_id
ORDER BY t.account_id, t.txn_date;


-- Q5. Channel mix — share of transactions by channel per year
--     Business use: digital adoption KPI tracking
--     MySQL change: EXTRACT(YEAR FROM ...) → YEAR(...)

SELECT
    YEAR(txn_date)   AS txn_year,
    channel,
    COUNT(*)         AS txn_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY YEAR(txn_date)),
    2)               AS channel_share_pct
FROM transactions
GROUP BY YEAR(txn_date), channel
ORDER BY txn_year, txn_count DESC;


-- ─────────────────────────────────────────────
--  SECTION 3 : LOAN PORTFOLIO RISK ANALYSIS
-- ─────────────────────────────────────────────

-- Q6. Loan portfolio breakdown by type and status
--     Business use: credit risk dashboard
--     MySQL change: none needed

SELECT
    loan_type,
    status,
    COUNT(*)                                AS loan_count,
    SUM(principal)                          AS total_principal,
    SUM(outstanding_amt)                    AS total_outstanding,
    ROUND(AVG(interest_rate), 2)            AS avg_rate,
    ROUND(
        100.0 * SUM(outstanding_amt)
        / SUM(SUM(outstanding_amt)) OVER (),
    2)                                      AS portfolio_share_pct
FROM loans
GROUP BY loan_type, status
ORDER BY total_outstanding DESC;


-- Q7. NPA & Defaulted loans — cross-referenced with credit scores
--     Business use: validate the credit scoring model
--     MySQL change: subquery replaces CROSS JOIN for avg score

SELECT
    c.customer_id,
    c.full_name,
    c.credit_score,
    l.loan_type,
    l.principal,
    l.outstanding_amt,
    l.status                                                  AS loan_status,
    l.disbursed_date,
    c.credit_score - (SELECT ROUND(AVG(credit_score), 1)
                      FROM customers)                         AS score_vs_avg
FROM loans l
JOIN customers c ON c.customer_id = l.customer_id
WHERE l.status IN ('NPA', 'Defaulted')
ORDER BY l.outstanding_amt DESC;


-- Q8. Debt-to-deposit ratio per customer
--     Business use: identify over-leveraged customers
--     MySQL change: none needed — COALESCE and NULLIF work the same

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
    COALESCE(d.total_deposits, 0)      AS total_deposits,
    COALESCE(le.total_outstanding, 0)  AS total_outstanding,
    ROUND(
        COALESCE(le.total_outstanding, 0)
        / NULLIF(COALESCE(d.total_deposits, 0), 0),
    2)                                 AS debt_to_deposit_ratio,
    CASE
        WHEN COALESCE(le.total_outstanding, 0) = 0 THEN 'No Debt'
        WHEN COALESCE(le.total_outstanding, 0)
             / NULLIF(COALESCE(d.total_deposits, 0), 0) > 5 THEN 'High Risk'
        WHEN COALESCE(le.total_outstanding, 0)
             / NULLIF(COALESCE(d.total_deposits, 0), 0) > 2 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END                                AS risk_flag
FROM customers c
LEFT JOIN deposits d       USING (customer_id)
LEFT JOIN loan_exposure le USING (customer_id)
ORDER BY debt_to_deposit_ratio DESC;


-- ─────────────────────────────────────────────
--  SECTION 4 : BRANCH PERFORMANCE
-- ─────────────────────────────────────────────

-- Q9. Branch KPI scorecard with regional ranking
--     Business use: regional performance review
--     MySQL change: none needed

SELECT
    b.branch_id,
    b.branch_name,
    b.region,
    COUNT(DISTINCT a.account_id)          AS total_accounts,
    COUNT(DISTINCT a.customer_id)         AS total_customers,
    SUM(a.balance)                        AS total_deposits,
    COUNT(DISTINCT l.loan_id)             AS total_loans,
    SUM(l.principal)                      AS total_loan_book,
    ROUND(AVG(c.credit_score), 1)         AS avg_credit_score,
    RANK() OVER (
        PARTITION BY b.region
        ORDER BY SUM(a.balance) + COALESCE(SUM(l.principal), 0) DESC
    )                                     AS rank_in_region
FROM branches b
LEFT JOIN accounts  a ON a.branch_id   = b.branch_id AND a.status = 'Active'
LEFT JOIN loans     l ON l.branch_id   = b.branch_id AND l.status = 'Active'
LEFT JOIN customers c ON c.customer_id = a.customer_id
GROUP BY b.branch_id, b.branch_name, b.region
ORDER BY b.region, rank_in_region;


-- Q10. Top 3 customers by deposit balance per branch
--      Business use: identify branch-level VIP customers
--      MySQL change: none needed — DENSE_RANK works in MySQL 8+

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


-- ─────────────────────────────────────────────
--  SECTION 5 : ADVANCED / SHOWCASE QUERIES
-- ─────────────────────────────────────────────

-- Q11. New customers joined each year with their average credit score
--      Business use: track customer acquisition trends over time
--      Concepts: GROUP BY, YEAR(), COUNT(), AVG(), ORDER BY

SELECT
    YEAR(joined_date)               AS join_year,
    COUNT(*)                        AS new_customers,
    ROUND(AVG(credit_score), 1)     AS avg_credit_score,
    MIN(credit_score)               AS lowest_score,
    MAX(credit_score)               AS highest_score
FROM customers
GROUP BY YEAR(joined_date)
ORDER BY join_year;


-- Q12. Loan summary by type — total lent, outstanding, and repaid
--      Business use: understand which loan products drive the most exposure
--      Concepts: GROUP BY, SUM(), ROUND(), calculated columns, ORDER BY

SELECT
    loan_type,
    COUNT(*)                                        AS total_loans,
    ROUND(SUM(principal), 0)                        AS total_disbursed,
    ROUND(SUM(outstanding_amt), 0)                  AS total_outstanding,
    ROUND(SUM(principal) - SUM(outstanding_amt), 0) AS total_repaid,
    ROUND(AVG(interest_rate), 2)                    AS avg_interest_rate,
    COUNT(CASE WHEN status = 'Active'    THEN 1 END) AS active_loans,
    COUNT(CASE WHEN status = 'Defaulted'
                 OR status = 'NPA'       THEN 1 END) AS bad_loans
FROM loans
GROUP BY loan_type
ORDER BY total_disbursed DESC;


-- Q13. Large deposits — flag transactions above 100,000
--      Business use: identify high-value deposits for review
--      Concepts: JOIN, WHERE with AND, ORDER BY, ROUND()
--      (simpler version of the AML flag — no window functions needed)

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
        ELSE                         'Moderate'
    END                             AS deposit_category
FROM transactions t
JOIN accounts  a ON a.account_id   = t.account_id
JOIN customers c ON c.customer_id  = a.customer_id
WHERE t.txn_type = 'Deposit'
  AND t.amount  >= 100000
ORDER BY t.amount DESC;


-- Q14. Fixed deposit holders — interest income and maturity overview
--      Business use: treasury team tracks FD payouts due
--      Concepts: JOIN, WHERE, calculated columns, DATE_ADD(), ORDER BY

SELECT
    c.full_name,
    c.city,
    a.balance                               AS fd_amount,
    a.opened_date,
    ROUND(a.balance * 0.07, 2)             AS annual_interest,
    ROUND(a.balance * 0.07 / 12, 2)        AS monthly_interest,
    DATE_ADD(a.opened_date, INTERVAL 1 YEAR) AS first_maturity_date,
    DATEDIFF(
        DATE_ADD(a.opened_date, INTERVAL 1 YEAR),
        CURDATE()
    )                                       AS days_to_maturity
FROM accounts a
JOIN customers c USING (customer_id)
WHERE a.account_type = 'Fixed Deposit'
  AND a.status = 'Active'
ORDER BY annual_interest DESC;


-- ─────────────────────────────────────────────
--  SECTION 6 : EXECUTIVE SUMMARY DASHBOARD
-- ─────────────────────────────────────────────

-- Q15. Bank health summary — one clean report using GROUP BY and UNION ALL
--      Business use: quick snapshot for management reporting
--      Concepts: UNION ALL, COUNT(), SUM(), AVG(), CASE WHEN, subquery
--      (easier alternative to the scalar-subquery dashboard)

SELECT 'Total customers'        AS metric, COUNT(*)                     AS value FROM customers
UNION ALL
SELECT 'Active accounts',         COUNT(*)                               FROM accounts    WHERE status = 'Active'
UNION ALL
SELECT 'Dormant accounts',        COUNT(*)                               FROM accounts    WHERE status = 'Dormant'
UNION ALL
SELECT 'Total deposits (AUM)',     ROUND(SUM(balance), 0)                FROM accounts    WHERE status = 'Active'
UNION ALL
SELECT 'Active loans',            COUNT(*)                               FROM loans       WHERE status = 'Active'
UNION ALL
SELECT 'Total loan book',         ROUND(SUM(outstanding_amt), 0)         FROM loans       WHERE status = 'Active'
UNION ALL
SELECT 'NPA + Defaulted loans',   COUNT(*)                               FROM loans       WHERE status IN ('NPA','Defaulted')
UNION ALL
SELECT 'NPA exposure (amount)',   ROUND(SUM(outstanding_amt), 0)         FROM loans       WHERE status IN ('NPA','Defaulted')
UNION ALL
SELECT 'Avg customer credit score', ROUND(AVG(credit_score), 1)          FROM customers
UNION ALL
SELECT 'Total transactions',      COUNT(*)                               FROM transactions
UNION ALL
SELECT 'Total deposit amount',    ROUND(SUM(amount), 0)                  FROM transactions WHERE txn_type = 'Deposit'
UNION ALL
SELECT 'Total withdrawal amount', ROUND(SUM(amount), 0)                  FROM transactions WHERE txn_type = 'Withdrawal';
