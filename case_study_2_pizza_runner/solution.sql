/* --------------------
   Case Study Questions #2 Pizza Runner

A. Pizza Metrics 
1. How many pizzas were ordered?
2. How many unique customer orders were made?
3. How many successful orders were delivered by each runner?
4. How many of each type of pizza was delivered?
5. How many Vegetarian and Meatlovers were ordered by each customer?
6. What was the maximum number of pizzas delivered in a single order?
7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
8. How many pizzas were delivered that had both exclusions and extras?
9. What was the total volume of pizzas ordered for each hour of the day?
10. What was the volume of orders for each day of the week?

B. Runner and Customer Experience
1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
4. What was the average distance travelled for each customer?
5. What was the difference between the longest and shortest delivery times for all orders?
6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
7. What is the successful delivery percentage for each runner?

C. Ingredient Optimisation
1. What are the standard ingredients for each pizza?
2. What was the most commonly added extra?
3. What was the most common exclusion?
4. Generate an order item for each record in the customers_orders table in the format of one of the following:
	• Meat Lovers
	• Meat Lovers - Exclude Beef
	• Meat Lovers - Extra Bacon
	• Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
	For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

D. Pricing and Ratings
1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
2. What if there was an additional $1 charge for any pizza extras?
	• Add cheese is $1 extra
3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
	• customer_id
	• order_id
	• runner_id
	• rating
	• order_time
	• pickup_time
	• Time between order and pickup
	• Delivery duration
	• Average speed
	• Total number of pizzas
5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

E. Bonus Questions
If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

-------------------- */

-- Setting search path - run this every time the file is launched
SET search_path = pizza_runner;

-- Tables and columns (for quick reference):
SELECT * FROM pizza_runner.runners;
SELECT * FROM pizza_runner.customer_orders ORDER BY order_id, order_time;
SELECT * FROM pizza_runner.runner_orders;
SELECT * FROM pizza_runner.pizza_names;
SELECT * FROM pizza_runner.pizza_recipes;
SELECT * FROM pizza_runner.pizza_toppings;

--- Cleaning Up Data --- 
-- customer_orders table cleanup
UPDATE customer_orders
SET extras = null
WHERE extras IN ('NaN', 'null', '');

UPDATE customer_orders
SET exclusions = null
WHERE exclusions IN ('null', '');

-- runner_orders table cleanup
UPDATE runner_orders
SET distance = TRIM(replace(distance, 'km', '')); -- remove 'km' and trailing white space

UPDATE runner_orders -- removing excess characters and white space 
SET duration = TRIM(REPLACE(REPLACE(REPLACE(REPLACE(duration, 'minutes',''),'minute', ''), 'mins', ''), 's',''));

UPDATE runner_orders -- changing null strings to null values
SET pickup_time = NULLIF(pickup_time, 'null'),
    distance = NULLIF(distance, 'null'),
    duration = NULLIF(duration, 'null'),
    cancellation = NULLIF(cancellation, 'null');

UPDATE runner_orders
SET cancellation = NULLIF(cancellation, '');

ALTER TABLE runner_orders -- changing column type to numeric
ALTER COLUMN distance TYPE numeric
USING distance::numeric;

ALTER TABLE runner_orders -- changing column type to numeric
ALTER COLUMN duration TYPE numeric
USING duration::numeric;

ALTER TABLE runner_orders -- changing column type to datetime
ALTER COLUMN pickup_time TYPE timestamp
USING pickup_time::timestamp

--- A. Pizza Metrics --- 
-- 1. How many pizzas were ordered?
SELECT COUNT(pizza_id) AS pizzas_ordered
FROM customer_orders;
/*
| pizzas_ordered |
|----------------|
| 14             |
*/

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT(order_id)) AS unique_orders
FROM customer_orders;
/*
| unique_orders |
|---------------|
| 10            |
*/

-- 3. How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(order_id) AS successful_orders
FROM runner_orders
WHERE cancellation is not null
GROUP BY runner_id;
/*
| runner_id | successful_orders |
|-----------|-------------------|
| 3         | 1                 |
| 2         | 1                 |
*/

-- 4. How many of each type of pizza was delivered?
SELECT pizza_id, COUNT(pizza_id) AS pizzas_ordered
FROM customer_orders
GROUP BY pizza_id;
/*
| pizza_id | pizzas_ordered |
|----------|----------------|
| 2        | 4              |
| 1        | 10             |
*/

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT orders.customer_id, pizza_names.pizza_name, COUNT(orders.pizza_id) AS pizzas_ordered
FROM customer_orders AS orders
INNER JOIN pizza_names ON orders.pizza_id = pizza_names.pizza_id
GROUP BY orders.customer_id, pizza_names.pizza_name
ORDER BY orders.customer_id, pizza_names.pizza_name;
/*
| customer_id | pizza_name | pizzas_ordered |
|-------------|------------|----------------|
| 101         | Meatlovers | 2              |
| 101         | Vegetarian | 1              |
| 102         | Meatlovers | 2              |
| 102         | Vegetarian | 1              |
| 103         | Meatlovers | 3              |
| 103         | Vegetarian | 1              |
| 104         | Meatlovers | 3              |
| 105         | Vegetarian | 1              |
*/

-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT order_id, COUNT(pizza_id) AS pizzas_ordered
FROM customer_orders
GROUP BY order_id
ORDER BY pizzas_ordered DESC
LIMIT 1;
/*
| order_id | pizzas_ordered |
|----------|----------------|
| 4        | 3              |
*/

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT customer.customer_id, COUNT(customer.pizza_id) AS delivered_pizzas,
SUM(CASE
	WHEN customer.exclusions is null AND customer.extras is null THEN 1
	ELSE 0
	END) AS orders_no_change,
SUM(CASE
	WHEN customer.exclusions is not null OR customer.extras is not null THEN 1
	ELSE 0
	END) AS orders_changed
FROM customer_orders AS customer
JOIN runner_orders AS runner ON customer.order_id = runner.order_id
WHERE runner.cancellation is null
GROUP BY customer_id
ORDER BY customer_id;
/*
| customer_id | delivered_pizzas | orders_no_change | orders_changed |
|-------------|------------------|------------------|----------------|
| 101         | 2                | 2                | 0              |
| 102         | 3                | 3                | 0              |
| 103         | 3                | 0                | 3              |
| 104         | 3                | 1                | 2              |
| 105         | 1                | 0                | 1              |
*/

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(customer.pizza_id) AS delivered_pizzas
FROM customer_orders AS customer
INNER JOIN runner_orders AS runner ON customer.order_id = runner.order_id
WHERE runner.cancellation is null and (customer.exclusions is not null and customer.extras is not null);
/*
| delivered_pizzas_w_extras_and_exclusions |
|--------------------------------------------|
| 1                                          |
*/

-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT EXTRACT(HOUR FROM order_time) AS hour_of_day, COUNT(pizza_id)
FROM customer_orders
GROUP BY hour_of_day
ORDER BY hour_of_day ASC;
/*
| hour_of_day | count |
|-------------|-------|
| 11          | 1     |
| 13          | 3     |
| 18          | 3     |
| 19          | 1     |
| 21          | 3     |
| 23          | 3     |
*/

-- 10. What was the volume of orders for each day of the week?
SELECT EXTRACT(DOW FROM order_time) AS day_of_week, COUNT(order_id) -- 0 = Sunday; 6 = Saturday
FROM customer_orders
GROUP BY day_of_week
ORDER BY day_of_week ASC;
/*
| day_of_week | count |
|-------------|-------|
| 3           | 5     |
| 4           | 3     |
| 5           | 1     |
| 6           | 5     |
*/

--- B. Runner and Customer Experience --- 
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT FLOOR(((registration_date - DATE '2021-01-01')/7)) + 1 AS week, COUNT(runner_id) AS runners
FROM runners -- calculate number of days between registration and Jan 1st, divide 7 to get week
GROUP BY week
ORDER BY week ASC;
/*
| week | runners |
|------|---------|
| 1    | 2       |
| 2    | 1       |
| 3    | 1       |
*/

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT AVG(EXTRACT(EPOCH FROM (runner.pickup_time::timestamp - customer.order_time::timestamp)) / 60) AS avg_min_difference
FROM runner_orders AS runner
INNER JOIN customer_orders AS customer ON runner.order_id = customer.order_id
WHERE runner.pickup_time is not null;
/*
| avg_min_difference |
|--------------------|
| 18.594             |
*/

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
SELECT
	COUNT(customer.pizza_id) AS num_pizzas,
	SUM(EXTRACT(EPOCH FROM (runner.pickup_time::timestamp - customer.order_time::timestamp)) / 60) AS min_difference
FROM runner_orders AS runner
INNER JOIN customer_orders AS customer ON runner.order_id = customer.order_id
WHERE runner.pickup_time is not null
GROUP BY customer.order_id
ORDER BY num_pizzas ASC;
/*
| num_pizzas | min_difference |
|------------|----------------|
| 1          | 20.483         |
| 1          | 10.467         |
| 1          | 10.033         |
| 1          | 10.267         |
| 1          | 10.533         |
| 2          | 31.033         |
| 2          | 42.467         |
| 3          | 87.850         |
*/

-- 4. What was the average distance travelled for each customer?
SELECT customer.customer_id, AVG(runner.distance) AS avg_distance
FROM customer_orders AS customer
INNER JOIN runner_orders AS runner ON customer.order_id = runner.order_id
GROUP BY customer.customer_id
ORDER BY avg_distance DESC;
/*
| customer_id | avg_distance |
|-------------|--------------|
| 105         | 25.00        |
| 103         | 23.40        |
| 101         | 20.00        |
| 102         | 16.73        |
| 104         | 10.00        |
*/

-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration) - MIN(duration) AS time_difference
FROM runner_orders;
/*
| time_difference |
|-----------------|
| 30              |
*/

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT 
	order_id, 
	runner_id, 
	pickup_time, 
	distance, 
	duration, 
	(distance/(duration/60)) AS avg_speed,
	EXTRACT(HOUR FROM pickup_time) AS hour_of_day
FROM runner_orders
ORDER BY avg_speed ASC;
/*
| order_id | runner_id | pickup_time    | distance | duration | avg_speed | hour_of_day |
|----------|-----------|----------------|----------|----------|-----------|-------------|
| 4        | 2         | 1/4/2020 13:53 | 23.40    | 40.00    | 35.10     | 13.00       |
| 1        | 1         | 1/1/2020 18:15 | 20.00    | 32.00    | 37.50     | 18.00       |
| 5        | 3         | 1/8/2020 21:10 | 10.00    | 15.00    | 40.00     | 21.00       |
| 3        | 1         | 1/3/2020 0:12  | 13.40    | 20.00    | 40.20     | 0.00        |
| 2        | 1         | 1/1/2020 19:10 | 20.00    | 27.00    | 44.44     | 19.00       |
| 10       | 1         | 1/11/2020 18:50| 10.00    | 10.00    | 60.00     | 18.00       |
| 7        | 2         | 1/8/2020 21:30 | 25.00    | 25.00    | 60.00     | 21.00       |
| 8        | 2         | 1/10/2020 0:15 | 23.40    | 15.00    | 93.60     | 0.00        |
| 9        | 2         | [null]         | [null]   | [null]   | [null]    | [null]      |
| 6        | 3         | [null]         | [null]   | [null]   | [null]    | [null]      |
*/

-- 7. What is the successful delivery percentage for each runner?
SELECT runner_id, 
100 * AVG(
CASE
	WHEN pickup_time is null THEN 0
	ELSE 1
	END) AS successful_percentage
FROM runner_orders
GROUP BY runner_id;
/*
| runner_id | successful_percentage |
|-----------|-----------------------|
| 3         | 50                    |
| 2         | 75                    |
| 1         | 100                   |
*/

--- C. Ingredient Optimisation ---
-- 1. What are the standard ingredients for each pizza?
WITH unnest_recipes AS (
	SELECT pizza_id, unnest(string_to_array(toppings, ','))::int AS topping_id
	FROM pizza_recipes
)
SELECT name.pizza_id, name.pizza_name, 
	string_agg(toppings.topping_name, ', ' ORDER BY toppings.topping_id) AS topping_list
FROM pizza_names AS name 
JOIN unnest_recipes AS recipe ON name.pizza_id = recipe.pizza_id
JOIN pizza_toppings AS toppings ON recipe.topping_id = toppings.topping_id
GROUP BY name.pizza_id, name.pizza_name
ORDER BY name.pizza_id;
/*
| pizza_id | pizza_name | topping_list |
|----------|------------|--------------|
| 1        | Meatlovers | Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami |
| 2        | Vegetarian | Cheese, Mushrooms, Onions, Peppers, Tomatoes, Tomato Sauce |
*/

-- 2. What was the most commonly added extra?
WITH unnest_extras AS (
	SELECT pizza_id, unnest(string_to_array(extras, ','))::int AS extras_id
	FROM customer_orders
)
SELECT extras.extras_id, toppings.topping_name, COUNT(extras.extras_id) AS extra_freq
FROM unnest_extras AS extras
JOIN pizza_toppings AS toppings ON extras.extras_id = toppings.topping_id
GROUP BY extras.extras_id, toppings.topping_name
ORDER BY extra_freq DESC;
/*
| extras_id | topping_name | extra_freq |
|-----------|--------------|------------|
| 1         | Bacon        | 4          |
| 4         | Cheese       | 1          |
| 5         | Chicken      | 1          |
*/

-- 3. What was the most common exclusion?
WITH unnest_exclusions AS (
	SELECT pizza_id, unnest(string_to_array(exclusions, ','))::int AS exclusion_id
	FROM customer_orders
)
SELECT exclusions.exclusion_id, toppings.topping_name, COUNT(exclusions.exclusion_id) AS exclusion_freq
FROM unnest_exclusions AS exclusions
JOIN pizza_toppings AS toppings ON exclusions.exclusion_id= toppings.topping_id
GROUP BY exclusions.exclusion_id, toppings.topping_name
ORDER BY exclusion_freq DESC;
/*
| exclusion_id | topping_name | exclusion_freq |
|--------------|--------------|----------------|
| 4            | Cheese       | 4              |
| 6            | Mushrooms    | 1              |
| 2            | BBQ Sauce    | 1              |
*/

/* 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
	• Meat Lovers
	• Meat Lovers - Exclude Beef
	• Meat Lovers - Extra Bacon
	• Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers */

/* Documentation -- this question was picking my brain a lot:
I added the num_row and built the distinct_pizzas CTE to give each row a unique identifier. 
This prevents different pizzas in the same order from collapsing together when exclusions or extras overlap. 
By numbering rows consistently, I can join back to the correct toppings without duplicates sneaking in. 
It also makes the final output easier to read and ensures every item is mapped cleanly to its own set of exclusions and extras. 
Although this level of complexity wasn’t strictly necessary given the simplicity of the provided data, 
I wanted to think through the scenario where orders might contain multiple pizzas with overlapping or differing toppings. 
Exploring that possibility helped me uncover potential pitfalls in grouping and aggregation, 
and finding the answers gave me confidence that the query would hold up even if the dataset were more complicated. */

WITH distinct_pizzas AS (
	SELECT *, ROW_NUMBER() OVER (ORDER BY order_id, pizza_id, exclusions, extras, order_time) AS num_row
	FROM customer_orders
	),
exclusions AS (
	SELECT d.num_row, d.order_id, string_agg(toppings.topping_name, ', ') AS exclusions
	FROM distinct_pizzas AS d
	JOIN pizza_toppings AS toppings
		ON toppings.topping_id = ANY(string_to_array(d.exclusions, ', ')::int[])
	GROUP BY d.num_row, d.order_id
	),
extras AS (
	SELECT d.num_row, d.order_id, string_agg(toppings.topping_name, ', ') AS extras
	FROM distinct_pizzas AS d
	JOIN pizza_toppings AS toppings
		ON toppings.topping_id = ANY(string_to_array(d.extras, ', ')::int[])
	GROUP BY d.num_row, d.order_id
	)

SELECT d.order_id, d.customer_id, d.pizza_id,
CASE
	WHEN d.exclusions is null and d.extras is null THEN name.pizza_name
	WHEN d.exclusions is not null and d.extras is null THEN name.pizza_name || ' - Exclude ' || e1.exclusions
	WHEN d.exclusions is null and d.extras is not null THEN name.pizza_name || ' - Extra ' || e2.extras
	WHEN d.exclusions is not null and d.extras is not null THEN name.pizza_name || ' - Exclude ' || e1.exclusions || ' - Extra ' || e2.extras
	END AS full_order
FROM distinct_pizzas AS d
LEFT JOIN pizza_names AS name ON d.pizza_id = name.pizza_id
LEFT JOIN exclusions AS e1 ON d.num_row = e1.num_row
LEFT JOIN extras AS e2 ON d.num_row = e2.num_row
ORDER BY d.num_row
/*
| order_id | customer_id | pizza_id | full_order                                                      |
|----------|-------------|----------|-----------------------------------------------------------------|
| 1        | 101         | 1        | Meatlovers                                                      |
| 2        | 101         | 1        | Meatlovers                                                      |
| 3        | 102         | 1        | Meatlovers                                                      |
| 3        | 102         | 2        | Vegetarian                                                      |
| 4        | 103         | 1        | Meatlovers - Exclude Cheese                                     |
| 4        | 103         | 1        | Meatlovers - Exclude Cheese                                     |
| 4        | 103         | 2        | Vegetarian - Exclude Cheese                                     |
| 5        | 104         | 1        | Meatlovers - Extra Bacon                                        |
| 6        | 101         | 2        | Vegetarian                                                      |
| 7        | 105         | 2        | Vegetarian - Extra Bacon                                        |
| 8        | 102         | 1        | Meatlovers                                                      |
| 9        | 103         | 1        | Meatlovers - Exclude Cheese - Extra Bacon, Chicken              |
| 10       | 104         | 1        | Meatlovers - Exclude BBQ Sauce, Mushrooms - Extra Bacon, Cheese |
| 10       | 104         | 1        | Meatlovers                                                      |
*/

/* 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
	For example: "Meat Lovers: 2xBacon, Beef, ... , Salami" */
/* Documentation:
I built the ingredients CTE to unify both the base recipe toppings and any extras into a single stream of ingredient names.
The exclusions CTE then maps out any toppings the customer requested to remove, so they can be filtered cleanly.
Next, the ingredient_counts CTE groups toppings by pizza row and calculates how many times each appears, while excluding any unwanted items.
The final_cte assembles these results into an alphabetically ordered, comma‑separated list, prefixing counts like 2x when needed.
Finally, the main query joins back to pizza names and order details, producing the ingredient list for each pizza order. */

WITH distinct_pizzas AS (
	SELECT *, ROW_NUMBER() OVER (ORDER BY order_id, pizza_id, exclusions, extras, order_time) AS num_row
	FROM customer_orders
	),
	
ingredients AS (
	-- Getting the base recipe by pizza type
	SELECT d.num_row, toppings.topping_name
	FROM distinct_pizzas AS d
	JOIN pizza_recipes AS recipe ON d.pizza_id = recipe.pizza_id
	JOIN pizza_toppings AS toppings ON toppings.topping_id = ANY(string_to_array(recipe.toppings, ', ')::int[])
	GROUP BY d.num_row, d.order_id, toppings.topping_name
	
	UNION ALL

	-- Adding extra toppings from customers' orders
	SELECT d.num_row, toppings.topping_name
	FROM distinct_pizzas AS d
	JOIN pizza_toppings AS toppings ON toppings.topping_id = ANY(string_to_array(d.extras, ', ')::int[])
	),

	-- Mapping exclusions to be filtered out of full ingredients list
exclusions AS (
	SELECT d.num_row, toppings.topping_name
	FROM distinct_pizzas AS d
	JOIN pizza_toppings AS toppings ON toppings.topping_id = ANY (string_to_array(d.exclusions, ', ')::int[])
	),

ingredient_counts AS (
	SELECT i.num_row, i.topping_name, COUNT(*) AS topping_count
	FROM ingredients AS i
	LEFT JOIN exclusions AS e ON i.num_row = e.num_row AND i.topping_name = e.topping_name
	WHERE e.topping_name is NULL -- filtering out excluded toppings
	GROUP BY i.num_row, i.topping_name
	),

final_cte AS (
    SELECT num_row,
           string_agg(
             CASE WHEN topping_count > 1
                  THEN topping_count || 'x' || topping_name
                  ELSE topping_name END,
             ', ' ORDER BY topping_name
           ) AS ingredient_list
    FROM ingredient_counts
    GROUP BY num_row
	)

SELECT d.order_id, d.pizza_id,
       name.pizza_name || ': ' || f.ingredient_list AS full_order
FROM distinct_pizzas AS d
JOIN final_cte AS f 
  ON d.num_row = f.num_row
JOIN pizza_names AS name
  ON d.pizza_id = name.pizza_id
ORDER BY d.num_row;
/*
| order_id | pizza_id | full_order                                                                          |
|----------|----------|-------------------------------------------------------------------------------------|
| 1        | 1        | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 2        | 1        | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 3        | 1        | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 3        | 2        | Vegetarian: Cheese, Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes              |
| 4        | 1        | Meatlovers: Bacon, BBQ Sauce, Beef, Chicken, Mushrooms, Pepperoni, Salami           |
| 4        | 1        | Meatlovers: Bacon, BBQ Sauce, Beef, Chicken, Mushrooms, Pepperoni, Salami           |
| 4        | 2        | Vegetarian: Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes                      |
| 5        | 1        | Meatlovers: 2xBacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami |
| 6        | 2        | Vegetarian: Cheese, Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes              |
| 7        | 2        | Vegetarian: Bacon, Cheese, Mushrooms, Onions, Peppers, Tomato Sauce, Tomatoes       |
| 8        | 1        | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
| 9        | 1        | Meatlovers: 2xBacon, BBQ Sauce, Beef, 2xChicken, Mushrooms, Pepperoni, Salami       |
| 10       | 1        | Meatlovers: 2xBacon, Beef, 2xCheese, Chicken, Pepperoni, Salami                     |
| 10       | 1        | Meatlovers: Bacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami   |
*/

-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH all_ingredients AS (
    -- Selecting base recipe toppings
    SELECT customer.order_id,
           unnest(string_to_array(recipe.toppings, ','))::int AS topping_id
    FROM customer_orders AS customer
    JOIN pizza_recipes AS recipe ON customer.pizza_id = recipe.pizza_id

    UNION ALL

    -- Selecting extras toppings
    SELECT customer.order_id,
           unnest(string_to_array(customer.extras, ','))::int AS topping_id
    FROM customer_orders AS customer

    UNION ALL

    -- Selecting exclusions toppings
    SELECT customer.order_id,
           unnest(string_to_array(customer.exclusions, ','))::int AS topping_id
    FROM customer_orders AS customer
	)

SELECT toppings.topping_name, COUNT(*) AS total_quantity
FROM all_ingredients AS a
JOIN pizza_toppings AS toppings ON toppings.topping_id = a.topping_id
JOIN runner_orders AS runner ON a.order_id = runner.order_id
WHERE runner.pickup_time is not null
GROUP BY toppings.topping_name
ORDER BY total_quantity DESC;
/*
| topping_name | total_quantity |
|--------------|----------------|
| Cheese       | 16             |
| Mushrooms    | 13             |
| Bacon        | 12             |
| BBQ Sauce    | 10             |
| Pepperoni    | 9              |
| Salami       | 9              |
| Chicken      | 9              |
| Beef         | 9              |
| Tomatoes     | 3              |
| Onions       | 3              |
| Peppers      | 3              |
| Tomato Sauce | 3              |
*/

--- D. Pricing and Ratings --- 
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
WITH revenue AS (
	SELECT *, 
	CASE 
		WHEN pizza_id = 1 THEN 12 -- Meat Lovers
		WHEN pizza_id = 2 THEN 10 -- Veggie
		END AS price
	FROM customer_orders
)
SELECT SUM(r.price)
FROM revenue AS r
JOIN runner_orders AS runner ON r.order_id = runner.order_id
WHERE runner.pickup_time is not null;
/*
| sum |
|-----|
| 138 |
*/

-- 2. What if there was an additional $1 charge for any pizza extras?
	-- • Add cheese is $1 extra
WITH unnest_extras AS (
	SELECT order_id, pizza_id,
	ROW_NUMBER() OVER (ORDER BY order_id, pizza_id, exclusions, extras, order_time) AS num_row,
	unnest(string_to_array(extras, ','))::int AS extras_id
	FROM customer_orders
	),
revenue AS (
	SELECT *, 
	ROW_NUMBER() OVER (ORDER BY order_id, pizza_id, exclusions, extras, order_time) AS num_row,
	CASE 
		WHEN pizza_id = 1 THEN 12 -- Meat Lovers
		WHEN pizza_id = 2 THEN 10 -- Veggie
	END AS base_price
	FROM customer_orders
	),
total_revenue AS (
	SELECT r.num_row, r.order_id, r.base_price, e.extras_id,
		CASE
			WHEN extras_id is not null THEN 1
			ELSE 0
		END AS topping_charge
	FROM revenue AS r
	LEFT JOIN unnest_extras AS e ON r.num_row = e.num_row
	),
orders_total AS(
	SELECT 
		total.order_id, 
		SUM(total.base_price) AS base_price, 
		SUM(total.topping_charge) AS topping_charge,
		MAX(total.base_price) + SUM(total.topping_charge) AS total_revenue
	FROM total_revenue AS total
	JOIN runner_orders AS runner ON total.order_id = runner.order_id
	WHERE runner.pickup_time is not null
	GROUP BY total.order_id
	ORDER BY order_id ASC
	)
SELECT SUM(total_revenue) AS total_revenue
FROM orders_total;
/*
| total_revenue |
|---------------|
| 98            |
*/

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

CREATE SCHEMA IF NOT EXISTS pizza_runner_reviews;

CREATE TABLE pizza_runner_reviews.customer_reviews (
    "order_id" INTEGER 
    "customer_id" INTEGER 
    "runner_id" INTEGER 
    "rating" INTEGER
);
INSERT INTO pizza_runner_reviews.customer_reviews
    (order_id, customer_id, runner_id, rating)
VALUES
    (1, 101, 1, 5),
    (2, 101, 1, 4),
    (3, 102, 1, 3),
    (4, 103, 2, 5),
    (5, 104, 3, 2),
    (7, 105, 2, 4),
    (8, 102, 2, 5),
    (10, 104, 1, 3);

/* 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
	• customer_id
	• order_id
	• runner_id
	• rating
	• order_time
	• pickup_time
	• Time between order and pickup
	• Delivery duration
	• Average speed
	• Total number of pizzas 
*/

SELECT 
	review.*, -- includes customer_id, order_id, runner_id and rating
	customer.order_time,
	runner.pickup_time,
	(runner.pickup_time - customer.order_time) AS time_between,
	runner.duration,
	(runner.distance/(runner.duration/60)) AS speed_mph,
	COUNT(pizza_id) as num_pizza
FROM pizza_runner_reviews.customer_reviews AS review
JOIN pizza_runner.customer_orders AS customer ON review.order_id = customer.order_id
JOIN pizza_runner.runner_orders AS runner ON review.order_id = runner.order_id
WHERE runner.pickup_time is not null
GROUP BY 
    review.order_id, 
    review.customer_id, 
    review.runner_id, 
    review.rating, 
    customer.order_time, 
    runner.pickup_time, 
    runner.duration, 
    runner.distance
ORDER BY review.order_id;

-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
WITH profit AS (
	SELECT customer.*, 
	ROW_NUMBER() OVER (ORDER BY customer.order_id, customer.pizza_id, customer.exclusions, customer.extras, customer.order_time) AS num_row,
	CASE 
		WHEN pizza_id = 1 THEN 12 -- Meat Lovers
		WHEN pizza_id = 2 THEN 10 -- Veggie
	END AS base_price,
	(runner.distance*0.3) AS delivery_cost,
	runner.pickup_time
	FROM customer_orders AS customer
	JOIN runner_orders AS runner ON customer.order_id = runner.order_id
	)

SELECT SUM(base_price - delivery_cost)
FROM profit
WHERE pickup_time is not null
/*
| sum   |
|-------|
| 73.38 |
*/

--- E. Bonus Questions ---
-- If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

INSERT INTO pizza_names (pizza_id, pizza_name)
VALUES (3, 'Supreme');

INSERT INTO pizza_recipes (pizza_id, toppings)
VALUES (3, '1,2,3,4,5,6,7,8,9,10,11,12');