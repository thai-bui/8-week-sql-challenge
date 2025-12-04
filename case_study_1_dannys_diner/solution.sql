/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SET search_path = dannys_diner, public;

-- Question 1: What is the total amount each customer spent at the restaurant?
SELECT sales.customer_id, SUM(menu.price) AS total_spent
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu
	ON sales.product_id = menu.product_id
GROUP BY sales.customer_id
/*
| customer_id | total_spent |
|-------------|-------------|
| A           | 76          |
| B           | 74          |
| C           | 36          |
*/

--Question 2: How many days has each customer visited the restaurant?
SELECT sales.customer_id, COUNT(DISTINCT sales.order_date) as days_visited
FROM sales
GROUP BY customer_id
/*
| customer_id | days_visited |
|-------------|--------------|
| A           | 4            |
| B           | 6            |
| C           | 2            |
*/

--Question 3: What was the first item from the menu purchased by each customer?
WITH first_purchase AS (
	SELECT *, 
		ROW_NUMBER() OVER (
		PARTITION BY sales.customer_id
		ORDER BY sales.order_date ASC
		) AS rnk
	FROM sales
)
SELECT customer_id, product_name
FROM first_purchase as f
INNER JOIN menu
	ON f.product_id = menu.product_id
WHERE rnk = 1
/*
| customer_id | product_name |
|-------------|--------------|
| A           | sushi        |
| B           | curry        |
| C           | ramen        |
*/

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT menu.product_name, COUNT(sales.product_id) as purchase_freq
FROM sales
INNER JOIN menu
	ON sales.product_id = menu.product_id
GROUP BY menu.product_name
ORDER BY purchase_freq DESC
/*
| product_name | purchase_freq |
|--------------|---------------|
| ramen        | 8             |
| curry        | 4             |
| sushi        | 3             |
*/

-- Question 5: Which item was the most popular for each customer?
WITH favorite_product AS (
	SELECT sales.customer_id, sales.product_id, COUNT(sales.product_id) as purchase_freq, 
		RANK() OVER (
		PARTITION BY sales.customer_id
		ORDER BY COUNT(sales.product_id) DESC
		) AS rnk
	FROM sales
	GROUP BY customer_id, product_id
)
SELECT f.customer_id, f.purchase_freq, menu.product_name
FROM favorite_product as f
INNER JOIN menu
	ON f.product_id = menu.product_id
WHERE rnk = 1
ORDER BY customer_id;
/*
| customer_id | purchase_freq | product_name |
|-------------|---------------|--------------|
| A           | 3             | ramen        |
| B           | 2             | sushi        |
| B           | 2             | curry        |
| B           | 2             | ramen        |
| C           | 3             | ramen        |
*/

-- Question 6: Which item was purchased first by the customer after they became a member?
WITH after_joining AS (
	SELECT sales.customer_id, sales.order_date, sales.product_id,
	ROW_NUMBER() OVER (
	PARTITION BY sales.customer_id
	ORDER BY sales.order_date ASC
	) AS rnk
	FROM sales
	INNER JOIN members
		ON sales.customer_id = members.customer_id
	WHERE sales.order_date > members.join_date
)
SELECT a.customer_id, a.order_date, menu.product_name
FROM after_joining AS a
INNER JOIN menu
	ON a.product_id = menu.product_id
WHERE a.rnk = 1
/*
| customer_id | order_date | product_name |
|-------------|------------|--------------|
| A           | 2021-01-10 | ramen        |
| B           | 2021-01-11 | sushi        |
*/

-- Question 7: Which item was purchased just before the customer became a member?
WITH before_joining AS (
	SELECT sales.customer_id, sales.order_date, sales.product_id,
	ROW_NUMBER() OVER (
	PARTITION BY sales.customer_id
	ORDER BY sales.order_date DESC
	) AS rnk
	FROM sales
	INNER JOIN members
		ON sales.customer_id = members.customer_id
	WHERE sales.order_date < members.join_date
)
SELECT b.customer_id, b.order_date, menu.product_name
FROM before_joining AS b
INNER JOIN menu
	ON b.product_id = menu.product_id
WHERE b.rnk = 1
/*
| customer_id | order_date | product_name |
|-------------|------------|--------------|
| A           | 2021-01-01 | sushi        |
| B           | 2021-01-04 | sushi        |
*/

-- Question 8: What is the total items and amount spent for each member before they became a member?
SELECT sales.customer_id, COUNT(sales.product_id) as total_items, SUM(menu.price) as total_spent
FROM sales
INNER JOIN menu ON sales.product_id = menu.product_id
INNER JOIN members ON sales.customer_id = members.customer_id
WHERE sales.order_date < members.join_date
GROUP BY sales.customer_id
/*
| customer_id | total_items | total_spent |
|-------------|-------------|-------------|
| A           | 2           | 26          |
| B           | 3           | 40          |
*/

-- Question 9: If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH rewards AS (
	SELECT sales.customer_id, 
	   menu.price,
	   CASE WHEN product_name = 'curry' THEN 10
	   WHEN product_name = 'ramen' THEN 10
	   WHEN product_name = 'sushi' THEN 20
	   ELSE NULL END AS points
	   FROM sales
	   INNER JOIN menu 
	   		ON sales.product_id = menu.product_id
)
SELECT customer_id,
	   sum(price * points) AS total_points
FROM rewards
GROUP BY customer_id
/*
| customer_id | total_points |
|-------------|--------------|
| A           | 860          |
| B           | 940          |
| C           | 360          |
*/

-- Question 10: In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH rewards AS (
	SELECT sales.customer_id,
	   sales.order_date,
	   menu.price,
	   CASE
	   WHEN sales.order_date BETWEEN members.join_date AND (members.join_date + 6) THEN 20
	   WHEN product_name = 'sushi' THEN 20
	   ELSE 10 END AS points
	   FROM sales
	   INNER JOIN menu ON sales.product_id = menu.product_id
	   INNER JOIN members ON sales.customer_id = members.customer_id
)
SELECT customer_id,
	   sum(price * points) AS total_points
FROM rewards 
WHERE order_date <= '2021-01-31'
GROUP BY customer_id
/*
| customer_id | total_points |
|-------------|--------------|
| A           | 1370         |
| B           | 820          |
*/

-- Bonus Question #1: Join All The Things
SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
CASE 
WHEN members.join_date <= sales.order_date then 'Y'
WHEN members.join_date > sales.order_date then'N'
ELSE 'N' END AS member
FROM sales
JOIN menu on sales.product_id = menu.product_id
LEFT JOIN members on sales.customer_id = members.customer_id
ORDER BY customer_id, order_date, product_name ASC;

-- Bonus Question #2: Rank All The Things
SELECT sales.customer_id, sales.order_date, menu.product_name, menu.price,
CASE 
	WHEN members.join_date <= sales.order_date then 'Y'
	WHEN members.join_date > sales.order_date then'N'
	ELSE 'N' END AS member,
CASE
	WHEN members.join_date <= sales.order_date and members.join_date IS NOT NULL
	THEN RANK() OVER (PARTITION BY sales.customer_id ORDER BY sales.order_date)
	ELSE NULL
END AS ranking
FROM sales
JOIN menu on sales.product_id = menu.product_id
LEFT JOIN members on sales.customer_id = members.customer_id
ORDER BY customer_id, order_date, product_name ASC;