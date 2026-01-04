/* --------------------
   Case Study Questions #3 Foodie-Fi
A. Customer Journey
Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.

Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

B. Data Analysis Questions
1. How many customers has Foodie-Fi ever had?
2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
6. What is the number and percentage of customer plans after their initial free trial?
7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
8. How many customers have upgraded to an annual plan in 2020?
9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?

C. Challenge Payment Question
The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

	• monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
	• upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
	• upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
	• once a customer churns they will no longer make payments

D. Outside The Box Questions
The following are open ended questions which might be asked during a technical interview for this case study - there are no right or wrong answers, but answers that make sense from both a technical and a business perspective make an amazing impression!

1. How would you calculate the rate of growth for Foodie-Fi?
2. What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?
3. What are some key customer journeys or experiences that you would analyse further to improve customer retention?
4. If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?
5. What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?

-------------------- */

-- Setting search path - run this every time the file is launched
SET search_path = foodie_fi;

--- A. Customer Journey --- 
SELECT *
FROM subscriptions AS s
JOIN plans AS p ON s.plan_id = p.plan_id
WHERE customer_id IN (1,2,11,13,15,16,18,19);
-- summaries provided in insights.md

--- B. Data Analysis Questions --- 
-- 1. How many customers has Foodie-Fi ever had?
SELECT COUNT (DISTINCT customer_id) AS total_customers
FROM subscriptions;
/*
| total_customers |
|-----------------|
| 1000            |
*/

-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT
	DATE_TRUNC('MONTH', start_date) AS startdate_month, -- function to return date to start date of month
	COUNT(plan_id) AS num_customers
FROM subscriptions
WHERE plan_id = 0
GROUP BY startdate_month
ORDER BY startdate_month ASC;
/*
| startdate_month        | num_customers |
|------------------------|---------------|
| 2020-01-01 00:00:00-06 | 88            |
| 2020-02-01 00:00:00-06 | 68            |
| 2020-03-01 00:00:00-06 | 94            |
| 2020-04-01 00:00:00-05 | 81            |
| 2020-05-01 00:00:00-05 | 88            |
| 2020-06-01 00:00:00-05 | 79            |
| 2020-07-01 00:00:00-05 | 89            |
| 2020-08-01 00:00:00-05 | 88            |
| 2020-09-01 00:00:00-05 | 87            |
| 2020-10-01 00:00:00-05 | 79            |
| 2020-11-01 00:00:00-05 | 75            |
| 2020-12-01 00:00:00-06 | 84            |
*/

-- Expanded Query for Insights: By Plan
SELECT
	DATE_TRUNC('MONTH', s.start_date) AS startdate_month, -- function to return date to start date of month
	p.plan_name,
	COUNT(s.plan_id) AS num_customers
FROM subscriptions AS s
JOIN plans AS p ON s.plan_id = p.plan_id
WHERE s.plan_id = 0
GROUP BY startdate_month, p.plan_name
ORDER BY startdate_month ASC;

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT s.plan_id, p.plan_name, COUNT(p.plan_name)
FROM plans AS p
JOIN subscriptions AS s ON p.plan_id = s.plan_id
WHERE s.start_date >= '2021-01-01'
GROUP BY s.plan_id, p.plan_name
ORDER BY s.plan_id;
/*
| plan_id | plan_name     | count |
|---------|---------------|-------|
| 1       | basic monthly | 8     |
| 2       | pro monthly   | 60    |
| 3       | pro annual    | 63    |
| 4       | churn         | 71    |
*/

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
-- Sub query Method
SELECT
  COUNT(DISTINCT s.customer_id) AS churned_customers,
  ROUND(100.0 * COUNT(s.customer_id)
    / (SELECT COUNT(DISTINCT customer_id) 
    	FROM subscriptions)
  ,1) AS churn_percentage
FROM subscriptions AS s
WHERE s.plan_id = 4; -- plan_id for churn
/*
| churned_customers | churn_percentage |
|-------------------|------------------|
| 307               | 30.7             |
*/

-- CTE Method
WITH churned_customers AS (
	SELECT 
		DISTINCT customer_id, -- assuming a customer can churn multiple times 
		plan_id,
	FROM subscriptions
	WHERE plan_id = 4 -- plan_id for churn
	GROUP BY customer_id, plan_id
)
SELECT 
	COUNT (DISTINCT s.customer_id) AS total_customers,
    ROUND(COUNT(c.customer_id)*100.0/COUNT(DISTINCT s.customer_id), 1) AS churn_percentage
FROM subscriptions AS s
LEFT JOIN churned_customers AS c ON s.customer_id = c.customer_id AND s.plan_id = c.plan_id; 

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
/* Documentation: This query was built based on the assumptions below:
	• Each customer can only enroll in the free trial once
	• A customer can skip the trial plan entirely and go straight into a premium plan. The real dataset makes it look like everyone starts with a trial, thus my solution might be more complicated than what this scenario technically requires.
*/
WITH num_rows AS (
	SELECT customer_id, plan_id, 
		ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date ASC
		) AS row_num
	FROM subscriptions
),
first_plans AS (
	SELECT
		customer_id,
        MAX(CASE WHEN row_num = 1 THEN plan_id END) AS first_plan,
        MAX(CASE WHEN row_num = 2 THEN plan_id END) AS second_plan -- MAX() only returns non-null values
    FROM num_rows
    GROUP BY customer_id
)
SELECT COUNT(customer_id) AS num_customers,
	ROUND(COUNT(customer_id)*100/ (SELECT COUNT(DISTINCT customer_id) 
    	FROM subscriptions),0) AS pct_churn
FROM first_plans
WHERE first_plan = 0 AND second_plan = 4;
/*
| num_customers | pct_churn |
|---------------|-----------|
| 92            | 9         |
*/

-- 6. What is the number and percentage of customer plans after their initial free trial?
-- Assumption: Percentage denominator includes customer who churned
WITH num_rows AS (
	SELECT s.customer_id, s.plan_id,
		ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.start_date ASC
		) AS row_num
	FROM subscriptions AS s
	JOIN plans AS p ON s.plan_id = p.plan_id
),
second_plan AS (
	SELECT
		customer_id,
        MAX(CASE WHEN row_num = 2 THEN plan_id END) AS second_plan -- MAX() only returns non-null values
    FROM num_rows
    GROUP BY customer_id
)
SELECT 
	COUNT(s2.customer_id) AS num_customers,
	ROUND(COUNT(s2.customer_id)*100.0 / (SELECT COUNT(DISTINCT customer_id)
		FROM subscriptions),1) AS pct_customers,
	p.plan_name
FROM second_plan AS s2
JOIN plans AS p ON s2.second_plan = p.plan_id
GROUP BY plan_name, p.plan_id
ORDER BY p.plan_id;
/*
| num_customers | pct_customers | plan_name     |
|---------------|---------------|---------------|
| 546           | 54.6          | basic monthly |
| 325           | 32.5          | pro monthly   |
| 37            | 3.7           | pro annual    |
| 92            | 9.2           | churn         |
*/

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH latest_plan AS (
	SELECT
		customer_id,
		MAX(start_date) AS latest_start_date -- get the most recent plan's start date
	FROM subscriptions
	WHERE start_date <= '2020-12-31'
	GROUP BY customer_id
	ORDER BY customer_id 
)
SELECT 
	p.plan_name, 
	COUNT(l.customer_id) AS num_customers,
	ROUND(COUNT(l.customer_id)*100.0 / (SELECT 
		COUNT(DISTINCT customer_id) FROM subscriptions WHERE start_date <= '2020-12-31'),1)
		AS pct_customers 
FROM latest_plan AS l
JOIN subscriptions AS s ON l.customer_id = s.customer_id AND l.latest_start_date = s.start_date
JOIN plans AS p ON s.plan_id = p.plan_id
GROUP BY p.plan_name, p.plan_id
ORDER BY p.plan_id
/*
| plan_name     | num_customers | pct_customers |
|---------------|---------------|---------------|
| trial         | 19            | 1.9           |
| basic monthly | 224           | 22.4          |
| pro monthly   | 326           | 32.6          |
| pro annual    | 195           | 19.5          |
| churn         | 236           | 23.6          |
*/

-- 8. How many customers have upgraded to an annual plan in 2020?
SELECT COUNT(DISTINCT customer_id) AS num_customers
FROM subscriptions
WHERE plan_id = 3 AND start_date <= '2020-12-31'
/*
| num_customers |
|---------------|
| 195           |
*/

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
-- Assumptions: every customers opts into a trial plan when they join Foodie-Fi
WITH trial_plan AS (
	SELECT *
	FROM subscriptions
	WHERE plan_id = 0 -- trial plan ID
),
annual_plan AS (
	SELECT *
	FROM subscriptions
	WHERE plan_id = 3 -- annual plan ID
)

SELECT ROUND(AVG(a.start_date - t.start_date),1) AS avg_days
FROM annual_plan AS a
JOIN trial_plan AS t ON a.customer_id = t.customer_id
/*
| avg_days |
|----------|
| 104.6    |
*/

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
-- Learnt about WIDTH_BUCKET here
WITH trial_plan AS (
	SELECT *
	FROM subscriptions
	WHERE plan_id = 0 -- trial plan ID
),
annual_plan AS (
	SELECT *
	FROM subscriptions
	WHERE plan_id = 3 -- annual plan ID
),
day_periods AS (
	SELECT t.customer_id, 
	-- (a.start_date - t.start_date) AS day_diff, -- used to validate WIDTH_BUCKET
	WIDTH_BUCKET(a.start_date - t.start_date, 0, 540, 18) AS day_period -- using a high max_value to capture all values
	FROM trial_plan AS t
	JOIN annual_plan AS a ON t.customer_id = a.customer_id
)

SELECT
    day_period,
    CASE 
    	WHEN day_period = 1 THEN '0–30 days' -- to include '0'
    	ELSE CONCAT( --used to create the proper label for readability
        	((day_period - 1) * 30) + 1,  -- lower bound
        	'–',
        	(day_period * 30),            -- upper bound
        	' days'
    	)
	END AS day_period_label,
	COUNT(*) AS num_customers
FROM day_periods
GROUP BY day_period
ORDER BY day_period;
/*
| day_period | day_period_label | num_customers |
|------------|------------------|---------------|
| 1          | 0–30 days        | 48            |
| 2          | 31–60 days       | 25            |
| 3          | 61–90 days       | 33            |
| 4          | 91–120 days      | 35            |
| 5          | 121–150 days     | 43            |
| 6          | 151–180 days     | 35            |
| 7          | 181–210 days     | 27            |
| 8          | 211–240 days     | 4             |
| 9          | 241–270 days     | 5             |
| 10         | 271–300 days     | 1             |
| 11         | 301–330 days     | 1             |
| 12         | 331–360 days     | 1             |
*/ 

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
/* Documentation: I have written two solutions for this question, each operating under different assumptions.

For the first query, it does not check whether the downgrade to Basic Monthly IMMEDIATELY AFTER Pro Monthly; it just checks whether the switch to Basic Monthly happened any time (before 2021) after Pro Monthly - meaning a customer could have had another plan in between time of having Pro Monthly and Basic Monthly.

The refined query, however, strictly checks whether the downgrade to Basic Monthly DOES HAPPENED IMMEDIATELY AFTER Pro Monthly. It only counts customers whose next plan after Pro Monthly is Basic Monthly, with no other plans in between.

For this particular dataset, both solutions produced the same output due to the simplicity of the provided scenario. 
*/

-- 1st and Initial solution:
WITH basic_monthly AS (
	SELECT customer_id, MIN(start_date) AS start_date -- get the first start date for basic monthly of each customer
	FROM subscriptions
	WHERE plan_id = 1 -- basic monthly plan ID
		AND start_date <= '2020-12-31'
	GROUP BY customer_id
),
pro_monthly AS (
	SELECT customer_id, MAX(start_date) AS start_date -- get the latest start date for pro monthly of each customer
	FROM subscriptions
	WHERE plan_id = 2 -- pro monthly plan ID
		AND start_date <= '2020-12-31'
	GROUP BY customer_id
)
SELECT COUNT(*)
FROM pro_monthly AS p
JOIN basic_monthly AS b ON p.customer_id = b.customer_id
WHERE b.start_date > p.start_date

-- Refined solution
WITH plan_order AS ( -- builds sequence of plans for each customer
    SELECT customer_id, plan_id, start_date,
        LEAD(plan_id) OVER ( -- returns the next plan in the customer's sequence
            PARTITION BY customer_id ORDER BY start_date
        ) AS next_plan_id,
        LEAD(start_date) OVER ( -- returns the start_date of the next plan
            PARTITION BY customer_id ORDER BY start_date
        ) AS next_start_date
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
)
SELECT COUNT(*)
FROM plan_order
WHERE plan_id = 2 -- Pro Monthly plan ID
  AND next_plan_id = 1 -- immediately followed by Basic Monthly
  AND next_start_date <= '2020-12-31';
-- Both solutions returned no results.

--- Part C: Creating Payments Table ---
/* The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:
	• monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
	• upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
	• upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
	• once a customer churns they will no longer make payments 
*/

-- subscription_timeline: layout each customer's plan progression, along with their next plan and next start date
WITH subscription_timeline AS (
    SELECT
        customer_id,
        plan_id,
        start_date,
        LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_plan,
        LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date) AS next_start
    FROM subscriptions
),

-- Monthly Billing + All Upgrades: union payments for all plans, each with different rules with prorated fees
payments AS (
    /* Monthly billing */
    SELECT
        st.customer_id,
        st.plan_id,
        (st.start_date + (n || ' month')::interval)::date AS payment_date,
        p.price AS amount
    FROM subscription_timeline AS st
    JOIN plans AS p ON st.plan_id = p.plan_id
    JOIN generate_series(0, 12) AS n 
		ON st.plan_id IN (1,2) -- only monthly cycles for basic/pro monthly plans
	-- convert each n value into a billing date by adding n months to the plan's start_date, if next_start does not exist, then compare against the end of 2020.
    WHERE (st.start_date + (n || ' month')::interval)::date <= COALESCE(st.next_start, DATE '2020-12-31')
	
    UNION ALL

-- Upgrades from Basic to Pro monthly/annual (with prorated fees)
    SELECT
        st.customer_id,
        st.next_plan AS plan_id,
        st.next_start AS payment_date,
        p2.price - p1.price AS amount -- upgrades to pro plans are deducted by the amount already paid for basic
    FROM subscription_timeline AS st
    JOIN plans AS p1 ON st.plan_id = p1.plan_id -- join by previous plan (basic)
    JOIN plans AS p2 ON st.next_plan = p2.plan_id -- join by new plan (pro monthly/annual upgrades)
    WHERE st.plan_id = 1 AND st.next_plan IN (2,3) -- find customrs upgrading from basic to pro monthly/annual

    UNION ALL

-- Upgrades from Pro monthly to Pro annual (end of cycle) */
    SELECT
        st.customer_id,
        st.next_plan AS plan_id,
        st.next_start AS payment_date,
        p2.price AS amount
    FROM subscription_timeline AS st
    JOIN plans AS p2 ON st.next_plan = p2.plan_id
    WHERE st.plan_id = 2 AND st.next_plan = 3 -- pro monthly and pro annual plan id

    UNION ALL

-- Direct annual signups from free trial (example: customer_id = 2)
    SELECT
        s.customer_id,
        s.plan_id,
        s.start_date AS payment_date,
        p.price AS amount
    FROM subscriptions AS s
    JOIN plans AS p ON s.plan_id = p.plan_id
    WHERE s.plan_id = 3 -- pro annual plan ID
),
final AS (
    SELECT
        pay.customer_id,
        pay.plan_id,
        p.plan_name,
        pay.payment_date,
        pay.amount,
        ROW_NUMBER() OVER (PARTITION BY pay.customer_id ORDER BY pay.payment_date) AS payment_order
    FROM payments AS pay
    JOIN plans AS p ON pay.plan_id = p.plan_id
)

SELECT *
FROM final
ORDER BY customer_id, payment_date;
