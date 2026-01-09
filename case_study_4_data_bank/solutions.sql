/* --------------------
	Case Study Questions #4 Data Bank
The following case study questions include some general data exploration analysis for the nodes and transactions before diving right into the core business questions and finishes with a challenging final request!

A. Customer Nodes Exploration
1. How many unique nodes are there on the Data Bank system?
2. What is the number of nodes per region?
3. How many customers are allocated to each region?
4. How many days on average are customers reallocated to a different node?
5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?\

B. Customer Transactions
1. What is the unique count and total amount for each transaction type?
2. What is the average total historical deposit counts and amounts for all customers?
3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
4. What is the closing balance for each customer at the end of the month?
5. What is the percentage of customers who increase their closing balance by more than 5%?

C. Data Allocation Challenge
To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

Option 1: data is allocated based off the amount of money at the end of the previous month
Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
Option 3: data is updated real-time
For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:

running customer balance column that includes the impact each transaction
customer balance at the end of each month
minimum, average and maximum values of the running balance for each customer
Using all of the data available - how much data would have been required for each option on a monthly basis?

D. Extra Challenge
Data Bank wants to try another option which is a bit more difficult to implement - they want to calculate data growth using an interest calculation, just like in a traditional savings account you might have with a bank.

If the annual interest rate is set at 6% and the Data Bank team wants to reward its customers by increasing their data allocation based off the interest calculated on a daily basis at the end of each day, how much data would be required for this option on a monthly basis?

Special notes:

Data Bank wants an initial calculation which does not allow for compounding interest, however they may also be interested in a daily compounding interest calculation so you can try to perform this calculation if you have the stamina!

-------------------- */

-- Setting search path - run this every time the file is launched
SET search_path = data_bank;

--- A. Customer Node Exploration ---
-- 1. How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) AS unique_nodes
FROM customer_nodes;

-- 2. What is the number of nodes per region?
SELECT re.region_name, COUNT(DISTINCT cu.node_id) AS num_nodes
FROM customer_nodes AS cu
JOIN regions AS re ON cu.region_id = re.region_id
GROUP BY re.region_name;

-- 3. How many customers are allocated to each region?
SELECT re.region_name, COUNT(cu.customer_id) as num_customers
FROM customer_nodes AS cu
JOIN regions AS re ON re.region_id = cu.region_id
GROUP BY re.region_name;

-- 4. How many days on average are customers reallocated to a different node?
WITH node_change AS (
	SELECT *,
	LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date ASC) AS next_start_date,
	LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date ASC) - start_date AS day_diff
	FROM customer_nodes
	) 
SELECT AVG(day_diff) AS avg_day
FROM node_change
WHERE day_diff IS NOT NULL

-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
WITH node_change AS (
	SELECT *,
	LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date ASC) AS next_start_date,
	LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date ASC) - start_date AS day_diff
	FROM customer_nodes
	)
SELECT
	re.region_name,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY nc.day_diff) AS median,
	PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY nc.day_diff) AS percentile_80,
	PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY nc.day_diff) AS percentile_95
FROM node_change AS nc
JOIN regions AS re ON nc.region_id = re.region_id
WHERE day_diff IS NOT NULL
GROUP BY re.region_name;

--- B. Customer Transactions --- 
-- 1. What is the unique count and total amount for each transaction type?
SELECT txn_type, COUNT(*) AS num_transaction, SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type;

-- 2. What is the average total historical deposit counts and amounts for all customers?
SELECT 
    AVG(deposit_count) AS avg_deposit_count,
    AVG(deposit_amount) AS avg_deposit_amount
FROM (
    SELECT 
        customer_id,
        COUNT(*) AS deposit_count,
        SUM(txn_amount) AS deposit_amount
    FROM customer_transactions
    WHERE txn_type = 'deposit'
    GROUP BY customer_id
) AS a;

-- 3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH txn_type_count AS (
	SELECT 
	customer_id, 
	DATE_TRUNC('month', txn_date)::date AS year_month,
	COUNT(CASE WHEN txn_type = 'deposit' THEN 1 END) AS deposit_count,
	COUNT(CASE WHEN txn_type = 'purchase' THEN 1 END) AS purchase_count,
	COUNT(CASE WHEN txn_type = 'withdrawal' THEN 1 END) AS withdrawal_count
	FROM customer_transactions
	GROUP BY customer_id, year_month
)
SELECT 
	year_month,
	COUNT(customer_id) num_customers
FROM txn_type_count
WHERE deposit_count > 1 AND (purchase_count >=1 OR withdrawal_count >= 1)
GROUP BY year_month
ORDER BY year_month

-- 4. What is the closing balance for each customer at the end of the month?
WITH customer_net AS (
	SELECT 
	customer_id,
	txn_date,
	DATE_TRUNC('month', txn_date)::date AS year_month,
	CASE
		WHEN txn_type = 'deposit' THEN txn_amount
		WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
	END AS net_amount
	FROM customer_transactions
)
SELECT customer_id, year_month, running_balance 
FROM (
		SELECT
			*,
			SUM(net_amount) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_balance,
			ROW_NUMBER() OVER (PARTITION BY customer_id, year_month ORDER BY txn_date DESC) AS row_num
		FROM customer_net) AS running_balance
WHERE row_num = 1 -- last transaction for each customer and month
ORDER BY customer_id,year_month

-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
/* Documentation: The question here could have used a little bit more clarity. Below are my assumptions.
	• The percentage increase is calculated month-to-month. Because the dataset does not provide customer balances prior to the first transaction month, it is not possible to calculate growth using the absolute start and end points of the sample.
	• Each customer’s percentage increase is calculated using their most recent month of activity. Specifically, I take the customer’s closing balance from their latest month (based on MAX(txn_date)) and compare it to the closing balance from the immediately preceding month in which they had transactions.
	• Time frames with vary between customers, meaning the “latest month” and its corresponding “previous month” vary by customer. As a result, each customer has exactly one percentage‑increase value, based on their own final two months of available data. 
*/
WITH customer_net AS (
	SELECT 
	customer_id,
	txn_date,
	DATE_TRUNC('month', txn_date)::date AS year_month,
	CASE
		WHEN txn_type = 'deposit' THEN txn_amount
		WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
	END AS net_amount
	FROM customer_transactions
),
closing_balance AS (
SELECT 
	customer_id, 
	year_month, 
	running_balance,
	ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY year_month DESC) AS latest_month
FROM (
		SELECT
			*,
			SUM(net_amount) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_balance,
			ROW_NUMBER() OVER (PARTITION BY customer_id, year_month ORDER BY txn_date DESC) AS row_num
		FROM customer_net) AS running_balance
WHERE row_num = 1 -- last transaction for each customer and month
ORDER BY customer_id,year_month
),
pct_change AS (
    SELECT
        cb.customer_id,
        ROUND(
            100.0* (cb.running_balance - prev.running_balance)
            / prev.running_balance,
            2
        ) AS pct_increase
    FROM closing_balance cb
    LEFT JOIN closing_balance prev
        ON cb.customer_id = prev.customer_id
        AND cb.latest_month = 1
        AND prev.latest_month = 2
	WHERE prev.running_balance <> 0 -- avoid division by zero error
)
SELECT 
    ROUND(
        100.0 * SUM(CASE WHEN pct_increase > 5 THEN 1 ELSE 0 END) -- count the number of accounts had 5% increase
        / COUNT(*),
        2
    ) AS pct_customers_increased_over_5
FROM pct_change;

--- C. Data Allocation Challenge ---
-- Option 1: Monthly data requirement based on end-of-month closing balance
WITH customer_net AS (
    SELECT 
        customer_id,
        txn_date,
        DATE_TRUNC('month', txn_date)::date AS year_month,
        CASE
            WHEN txn_type = 'deposit' THEN txn_amount
            WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
        END AS net_amount
    FROM customer_transactions
),
closing_balance AS (
    SELECT 
        customer_id,
        year_month,
        running_balance,
        ROW_NUMBER() OVER (PARTITION BY customer_id, year_month ORDER BY txn_date DESC) AS row_num
    FROM (
        SELECT
            *,
            SUM(net_amount) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_balance
        FROM customer_net
    ) AS a
)
SELECT 
    year_month,
    SUM(running_balance) AS total_data_required_option_1
FROM closing_balance
WHERE row_num = 1 -- get the most latest balance by month for each customer
GROUP BY year_month
ORDER BY year_month;

-- Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
WITH customer_net AS (
    SELECT 
        customer_id,
        txn_date,
        CASE
            WHEN txn_type = 'deposit' THEN txn_amount
            WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
        END AS net_amount
    FROM customer_transactions
),
running_balance AS (
    SELECT
        customer_id,
        txn_date,
        SUM(net_amount) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_balance
    FROM customer_net
),
avg_balance AS (
    SELECT
        customer_id,
        AVG(running_balance) AS avg_running_balance
    FROM running_balance
    GROUP BY customer_id
)
SELECT
    DATE_TRUNC('month', txn_date)::date AS year_month,
    SUM(avg_running_balance) AS total_data_required_option_2
FROM running_balance AS rb
JOIN avg_balance AS ab
    ON rb.customer_id = ab.customer_id
GROUP BY year_month
ORDER BY year_month;

-- Option 3: data is updated real-time
WITH customer_net AS (
    SELECT 
        customer_id,
        txn_date,
        CASE
            WHEN txn_type = 'deposit' THEN txn_amount
            WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
        END AS net_amount
    FROM customer_transactions
),
running_balance AS (
    SELECT
        customer_id,
        txn_date,
        SUM(net_amount) OVER (PARTITION BY customer_id ORDER BY txn_date) AS running_balance
    FROM customer_net
)
SELECT
    DATE_TRUNC('month', txn_date)::date AS year_month,
    SUM(running_balance) AS total_data_required_option_3
FROM running_balance
GROUP BY year_month
ORDER BY year_month;

--- D. Extra Challenge ---
-- Non-Compounding Daily Interest
/* Assumptions:
	• APR: 6%
	• Daily Interest = Daily Balance * (0.06/365)
	• Interest is sum on a monthly basis.
*/

WITH RECURSIVE interest_rate AS (
	SELECT 0.06/365 AS daily_rate
),

-- convert transactions into net amount, depending on transaction type
customer_net AS (
    SELECT 
        customer_id,
        txn_date,
        CASE
            WHEN txn_type = 'deposit' THEN txn_amount
            WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
        END AS net_amount
    FROM customer_transactions
),

-- get start and end dates for each customers
date_range AS (
	SELECT
		customer_id,
		MIN(txn_date) AS start_date,
		MAX(txn_date) AS end_date
	FROM customer_net
	GROUP BY customer_id
),

-- generate daily dates for each customers within their own date range
recursive_dates AS (
	SELECT
		customer_id,
		start_date AS date
	FROM date_range

	UNION ALL

	SELECT
		r.customer_id,
		(r.date + INTERVAL '1 day')::date
	FROM recursive_dates AS r
	JOIN date_range AS d
		ON r.customer_id = d.customer_id
		AND r.date + INTERVAL '1 day' <= d.end_date
),

-- calculate running balance per day by customers
daily_balance AS (
    SELECT
        d.customer_id,
        d.date,
        SUM(n.net_amount) OVER (
            PARTITION BY d.customer_id
            ORDER BY d.date
            ROWS UNBOUNDED PRECEDING
        ) AS balance
    FROM recursive_dates AS d
    LEFT JOIN customer_net AS n
        ON d.customer_id = n.customer_id
       AND d.date = n.txn_date
),

-- calculate non-compounding daily interest by customer by date
daily_interest AS (
    SELECT
        b.customer_id,
        b.date,
        b.balance,
        b.balance * i.daily_rate AS interest
    FROM daily_balance AS b
    CROSS JOIN interest_rate AS i -- use CROSS JOIN to apply same interest rate to every daily balance
),

-- final select
SELECT
    DATE_TRUNC('month', date)::date AS year_month,
    SUM(interest) AS total_data_required_option_4_non_compounding
FROM daily_interest
GROUP BY year_month
ORDER BY year_month;

-- Daily Compouding Interest
/* Assumptions:
	• APR: 6%
	• Balance(t+1) = Balance(t) * (1 + (0.06/365))
	• Interest is sum on a monthly basis.
*/

WITH RECURSIVE interest_rate AS (
    SELECT 0.06/365 AS daily_rate
),

-- convert transactions into net amount
customer_net AS (
    SELECT 
        customer_id,
        txn_date,
        CASE
            WHEN txn_type = 'deposit' THEN txn_amount
            WHEN txn_type IN ('purchase', 'withdrawal') THEN -txn_amount
        END AS net_amount
    FROM customer_transactions
),

-- get start and end dates for each customer
date_range AS (
    SELECT
        customer_id,
        MIN(txn_date) AS start_date,
        MAX(txn_date) AS end_date
    FROM customer_net
    GROUP BY customer_id
),

-- generate daily dates for each customer
recursive_dates AS (
    SELECT
        customer_id,
        start_date AS date
    FROM date_range

    UNION ALL

    SELECT
        r.customer_id,
        (r.date + INTERVAL '1 day')::date
    FROM recursive_dates AS r
    JOIN date_range AS d
        ON r.customer_id = d.customer_id
       AND r.date + INTERVAL '1 day' <= d.end_date
),

-- calculate running balance per day
daily_balance AS (
    SELECT
        d.customer_id,
        d.date,
        SUM(n.net_amount) OVER (
            PARTITION BY d.customer_id
            ORDER BY d.date
            ROWS UNBOUNDED PRECEDING
        ) AS balance
    FROM recursive_dates AS d
    LEFT JOIN customer_net AS n
        ON d.customer_id = n.customer_id
       AND d.date = n.txn_date
),

-- apply daily compounding interest
compounded AS (
    -- first day uses base balance
    SELECT
        b.customer_id,
        b.date,
        b.balance::numeric AS compounded_balance -- int is a non-recursive term, workaround to avoid error
    FROM daily_balance AS b
    JOIN (
        SELECT customer_id, MIN(date) AS first_date
        FROM daily_balance
        GROUP BY customer_id
    ) AS f
        ON b.customer_id = f.customer_id
       AND b.date = f.first_date

    UNION ALL

    -- next day = previous day's compounded balance * (1 + daily_rate)
    SELECT
        b.customer_id,
        b.date,
        c.compounded_balance * (1 + i.daily_rate) AS compounded_balance
    FROM compounded AS c
    JOIN daily_balance AS b
        ON c.customer_id = b.customer_id
       AND b.date = c.date + INTERVAL '1 day'
    CROSS JOIN interest_rate AS i -- use CROSS JOIN to apply same interest rate to every daily balance
),

-- calculate daily interest using compounded balance
daily_interest AS (
    SELECT
        customer_id,
        date,
        compounded_balance * (SELECT daily_rate FROM interest_rate) AS interest
    FROM compounded
)

-- final select
SELECT
    DATE_TRUNC('month', date)::date AS year_month,
    ROUND(SUM(interest),1) AS total_data_required_option_5_compounding
FROM daily_interest
GROUP BY year_month
ORDER BY year_month;