-- 1. Orphan records check

SELECT 'missing_customers', COUNT(*)
FROM orders o
LEFT JOIN customers c
ON o.customer_id = c.customer_id
WHERE o.customer_id IS NOT NULL
AND c.customer_id IS NULL

UNION ALL

SELECT 'missing_products', COUNT(*)
FROM order_items oi
LEFT JOIN products p
ON oi.product_id = p.product_id
WHERE oi.product_id IS NOT NULL
AND p.product_id IS NULL

UNION ALL

SELECT 'missing_sellers', COUNT(*)
FROM order_items oi
LEFT JOIN sellers s
ON oi.seller_id = s.seller_id
WHERE oi.seller_id IS NOT NULL
AND s.seller_id IS NULL

UNION ALL

SELECT 'missing_payment_orders', COUNT(*)
FROM order_payments op
LEFT JOIN orders o
ON op.order_id = o.order_id
WHERE op.order_id IS NOT NULL
AND o.order_id IS NULL

UNION ALL

SELECT 'missing_review_orders', COUNT(*)
FROM order_reviews r
LEFT JOIN orders o
ON r.order_id = o.order_id
WHERE r.order_id IS NOT NULL
AND o.order_id IS NULL

UNION ALL

SELECT 'missing_category_translation', COUNT(*) 
FROM products p
LEFT JOIN product_category_translation t
ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
AND t.product_category_name IS NULL;

-- 2. Invalid dates check

-- zero dates
SELECT *
FROM order_reviews
WHERE CAST(review_creation_date AS CHAR) = '0000-00-00 00:00:00';

-- delivery before purchase
SELECT 'invalid_delivery_dates', COUNT(*)
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp

UNION ALL

-- delivery before order
SELECT 'invalid_shipping_dates', COUNT(*)
FROM orders
WHERE order_delivered_carrier_date < order_purchase_timestamp

UNION ALL

-- delivery before order
SELECT 'invalid_carrier_dates', COUNT(*)
FROM orders
WHERE order_delivered_customer_date < order_delivered_carrier_date

UNION ALL

-- estimated delivery before order
SELECT 'invalid_estimated_dates', COUNT(*)
FROM orders
WHERE order_estimated_delivery_date < order_purchase_timestamp;

-- 3. Invalid values check

-- reviews score (1-5)
SELECT review_score
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5
ORDER BY review_score;

-- unified order statues
SELECT DISTINCT order_status
FROM orders;

-- unified payment statuses
SELECT DISTINCT payment_type
FROM order_payments;

-- negative order prices
SELECT COUNT(*) AS negative_prices
FROM order_items
WHERE price < 0;

-- negative freight prices 
SELECT COUNT(*) AS negative_freight
FROM order_items
WHERE freight_value < 0;

-- payment validation check
SELECT 
	c.customer_id,
    op.order_id,
	op.total_payment,
	oi.total_items,
    CASE
        WHEN op.total_payment > oi.total_items THEN 'overpayment'
        ELSE 'underpayment'
    END AS payment_status,
    ABS(op.total_payment - oi.total_items) AS difference
FROM (
	SELECT
		order_id,
        SUM(payment_value) AS total_payment
	FROM order_payments
    GROUP BY order_id
) op
JOIN (
	SELECT
		order_id,
        SUM(price + freight_value) AS total_items
	FROM order_items
    GROUP BY order_id
) oi
ON 
	op.order_id = oi.order_id
LEFT JOIN 
	orders o
ON
	o.order_id = oi.order_id
LEFT JOIN
	customers c
ON
	c.customer_id = o.customer_id
WHERE 
	op.total_payment != oi.total_items
;
-- Check for zero values in product measurements

SELECT 
	'product_weight_g' AS column_name, 
    COUNT(*) AS zero_values
FROM products
WHERE product_weight_g = 0

UNION ALL

SELECT 'product_length_cm', COUNT(*)
FROM products
WHERE product_length_cm = 0

UNION ALL

SELECT 'product_height_cm', COUNT(*)
FROM products
WHERE product_height_cm = 0

UNION ALL

SELECT 'product_width_cm', COUNT(*)
FROM products
WHERE product_width_cm = 0;

-- customer_id check ##SELF-NOTE for customer related calculations use customer_unique_id, customer_id is not customer but order related
SELECT 
COUNT(DISTINCT customer_id), 
COUNT(DISTINCT customer_unique_id) 
FROM customers;