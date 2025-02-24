-- 1. Retrieve the total number of unique customers in the dataset.
SELECT COUNT(DISTINCT customer_unique_id) AS unique_customers 
FROM customers

-- 2. List the different order statuses along with the count of orders in each status.
SELECT order_status, COUNT(*) AS order_count FROM orders
GROUP BY order_status
ORDER BY order_count DESC

-- 3. Find the top 5 states with the highest number of customers.
SELECT customer_state, COUNT(*) AS customer_count FROM customers
GROUP BY customer_state
ORDER BY customer_count DESC
LIMIT 5

-- 4  Identify the top-selling product categories based on the total number of items sold.
SELECT products.product_category_name, COUNT(*) AS total_orders FROM products
LEFT JOIN order_items
ON products.product_id = order_items.product_id
GROUP BY  products.product_category_name
ORDER BY total_orders DESC
LIMIT 5

-- 5. Calculate the total revenue generated by each seller and rank them in descending order.
SELECT seller_id, SUM(price + freight_value) AS revenue FROM order_items
GROUP BY seller_id
ORDER BY revenue DESC
LIMIT 5

-- 6. Find the most common payment type and its percentage of total transactions.
SELECT payment_type,
COUNT(*) AS total_transaction,
ROUND((COUNT(*) * 1.0 /(SELECT COUNT(*) FROM order_payments)) * 100,2) AS percent_share
FROM order_payments
GROUP BY payment_type
ORDER BY percent_share DESC

-- 7. Determine the average delivery time (in days) per state and rank states based on fastest deliveries.
WITH my_cte AS (
SELECT customer_id, 
DATE(order_delivered_customer_date) - DATE(order_purchase_timestamp) AS delivery_time 
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
)

SELECT customers.customer_state, 
ROUND(AVG(my_cte.delivery_time),2) AS avg_delivery_time 
FROM customers
INNER JOIN my_cte
ON customers.customer_id = my_cte.customer_id
GROUP BY customers.customer_state
ORDER BY avg_delivery_time ASC
LIMIT 5

-- 8. Identify the top 5 customers who spent the most on orders, including product price and freight costs.
SELECT c.customer_unique_id, SUM(oi.price + oi.freight_value) AS total_spend 
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
JOIN order_items oi
ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id
ORDER BY total_spend DESC
LIMIT 5

-- 9. Find the monthly total revenue for each month in 2018, sorted chronologically.
SELECT to_char(o.order_purchase_timestamp,'YYYY-MM') AS month,
SUM(op.payment_value) AS payments_received 
FROM order_payments op
JOIN orders o
ON op.order_id = o.order_id
WHERE to_char(o.order_purchase_timestamp, 'YYYY') = '2018'
GROUP BY to_char(o.order_purchase_timestamp,'YYYY-MM')
ORDER BY month

-- 10. Determine which sellers have an average review score below 3.0, along with their total number of orders.
SELECT oi.seller_id, 
ROUND(AVG(COALESCE(ors.review_score,0)),1) AS avg_score, 
COUNT(DISTINCT oi.order_id) AS order_count 
FROM order_items oi
LEFT JOIN order_reviews AS ors
ON oi.order_id = ors.order_id
GROUP BY oi.seller_id
HAVING AVG(ors.review_score) < 3
ORDER BY order_count DESC

-- 11. Identify repeat customers who have made more than one purchase and count their total orders.
SELECT c.customer_unique_id, 
COUNT(*) AS total_orders 
FROM orders o
LEFT JOIN customers c
ON o.customer_id = c.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(*) > 1
ORDER BY total_orders DESC
LIMIT 10

-- 12.Rank sellers by their total revenue within each state using window functions.
WITH customer_orders AS (
    SELECT o.order_id, c.customer_state 
    FROM olist_customers_dataset c
    JOIN olist_orders_dataset o 
    ON o.customer_id = c.customer_id
),
order_info AS (
    SELECT 
        oi.seller_id, 
        co.customer_state, 
        SUM(oi.price + oi.freight_value) AS revenue 
    FROM olist_order_items_dataset oi
    JOIN customer_orders co 
    ON oi.order_id = co.order_id
    GROUP BY co.customer_state, oi.seller_id
)
SELECT 
    seller_id, 
    customer_state, 
    revenue, 
    RANK() OVER(PARTITION BY customer_state ORDER BY revenue DESC) AS state_rank 
FROM order_info;


-- 13. Calculate the percentage of late deliveries by comparing the estimated and actual delivery times.
SELECT 
    ROUND(
        (COUNT(order_id) * 100.0) / (SELECT COUNT(*) FROM orders WHERE order_estimated_delivery_date IS NOT NULL), 
        2
    ) AS late_delivery_percentage
FROM orders
WHERE order_delivered_customer_date > order_estimated_delivery_date;

-- 14.  Identify the most frequently used number of payment installments and its percentage of total payments.
With my_cte AS (
SELECT payment_installments, 
(COUNT(*)/SUM(COUNT(*) ) OVER())*100 AS percent_share 
FROM order_payments op
WHERE payment_installments != 1
GROUP BY payment_installments
)

SELECT payment_installments, ROUND(percent_share,2) AS percent_share FROM my_cte
ORDER BY percent_share DESC
LIMIT 1


-- 15. Find the percentage of orders that received a 5-star review and compare it to other review scores.
WITH my_cte AS (
SELECT review_score, 
COUNT(order_id) AS total_orders, 
COUNT(order_id) *100.0 / SUM(COUNT(order_id)) OVER() AS order_percent
FROM order_reviews
GROUP BY review_score
)

SELECT review_score, total_orders, ROUND(order_percent,2) FROM my_cte
ORDER BY review_score DESC

-- YOY
-- year on year analysics

WITH yoy_revenue AS (
SELECT Extract(year from order_purchase_timestamp) AS year, 
SUM(payment_value) AS total_revenue
FROM order_payments op
LEFT JOIN orders o
ON op.order_id = o.order_id
GROUP BY Extract(year from order_purchase_timestamp)
),
yoy_revenue_growth AS (
SELECT year, 
total_revenue, 
ROUND(revenue_growth / COALESCE(LAG(total_revenue) OVER(), total_revenue),2) AS percent_revenue_growth
FROM (SELECT year, 
total_revenue, 
total_revenue - COALESCE(LAG(total_revenue) OVER(),total_revenue) AS revenue_growth
FROM yoy_revenue)
),
yoy_orders AS (
SELECT Extract(year from order_purchase_timestamp) AS year,
COUNT(order_id) AS total_orders,
COUNT(order_id) - COALESCE(LAG(COUNT(order_id)) OVER(), COUNT(order_id)) AS orders_growth
FROM orders
GROUP BY Extract(year from order_purchase_timestamp)
),
yoy_orders_growth AS (
SELECT year, total_orders, 
ROUND(orders_growth * 1.1 / COALESCE(LAG(total_orders) OVER(), total_orders),2) AS percent_order_growth
FROM yoy_orders
)

SELECT yoy_rg.year, 
yoy_rg.total_revenue, 
CASE 
	WHEN yoy_rg.percent_revenue_growth > 1 
	THEN  yoy_rg.percent_revenue_growth 
	ELSE yoy_rg.percent_revenue_growth *100
END AS percent_revenue_growth,
yoy_og.total_orders,
CASE 
	WHEN yoy_og.percent_order_growth > 1 
	THEN  yoy_og.percent_order_growth 
	ELSE yoy_og.percent_order_growth *100
END AS percent_order_growth
FROM yoy_revenue_growth AS yoy_rg
INNER JOIN yoy_orders_growth AS yoy_og
ON yoy_og.year = yoy_rg.year
