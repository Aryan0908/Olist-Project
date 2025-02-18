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
SELECT c.customer_unique_id, SUM(oi.price + oi.freight_value) AS total_spend FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
JOIN order_items oi
ON o.order_id = oi.order_id
GROUP BY c.customer_unique_id
ORDER BY total_spend DESC
LIMIT 5

-- 9. Find the monthly total revenue for each month in 2018, sorted chronologically.
SELECT to_char(o.order_purchase_timestamp,'YYYY-MM') AS month,
SUM(op.payment_value) AS payments_received FROM order_payments op
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


