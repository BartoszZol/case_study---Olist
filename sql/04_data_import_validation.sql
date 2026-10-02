USE olist_brazilian_ecommerce;

-- IMPORT CHECK
-- 1. number of rows validation
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;

-- 2. Check for NULL values in PRIMARY KEY columns

SELECT 'customers' AS table_name, COUNT(*) AS null_pk
FROM customers
WHERE customer_id IS NULL

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders
WHERE order_id IS NULL

UNION ALL
 
SELECT 'order_items', COUNT(*)
FROM order_items
WHERE order_id IS NULL
OR order_item_id IS NULL

UNION ALL

SELECT 'order_payments', COUNT(*)
FROM order_payments
WHERE order_id IS NULL
OR payment_sequential IS NULL

UNION ALL

SELECT 'order_reviews', COUNT(*)
FROM order_reviews
WHERE review_id IS NULL
OR order_id IS NULL

UNION ALL

SELECT 'products', COUNT(*)
FROM products
WHERE product_id IS NULL

UNION ALL

SELECT 'sellers', COUNT(*)
FROM sellers
WHERE seller_id IS NULL

UNION ALL

SELECT 'geolocation', COUNT(*)
FROM geolocation
WHERE geolocation_zip_code_prefix IS NULL

UNION ALL

SELECT 'product_category_translation', COUNT(*)
FROM product_category_translation
WHERE product_category_name IS NULL;

-- 3. Check for PK duplicates

-- customers
SELECT
    'customers' AS table_name,
    COUNT(*) AS duplicate_pk_groups
FROM (
    SELECT customer_id
    FROM customers
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) t

UNION ALL

-- orders
SELECT
    'orders',
    COUNT(*)
FROM (
    SELECT order_id
    FROM orders
    GROUP BY order_id
    HAVING COUNT(*) > 1
) t

UNION ALL

-- order_items (Composite PK)
SELECT
    'order_items',
    COUNT(*)
FROM (
    SELECT order_id, order_item_id
    FROM order_items
    GROUP BY order_id, order_item_id
    HAVING COUNT(*) > 1
) t

UNION ALL

-- order_payments (Composite PK)
SELECT
    'order_payments',
    COUNT(*)
FROM (
    SELECT order_id, payment_sequential
    FROM order_payments
    GROUP BY order_id, payment_sequential
    HAVING COUNT(*) > 1
) t

UNION ALL

-- order_reviews
SELECT
    'order_reviews',
    COUNT(*)
FROM (
    SELECT 
		review_id, 
        order_id
    FROM order_reviews
    GROUP BY 
		review_id,
        order_id
    HAVING COUNT(*) > 1
) t

UNION ALL

-- products
SELECT
    'products',
    COUNT(*)
FROM (
    SELECT product_id
    FROM products
    GROUP BY product_id
    HAVING COUNT(*) > 1
) t

UNION ALL

-- sellers
SELECT
    'sellers',
    COUNT(*)
FROM (
    SELECT seller_id
    FROM sellers
    GROUP BY seller_id
    HAVING COUNT(*) > 1
) t

UNION ALL

-- geolocation - dupliacte check fail expected, pk not defined in this group
SELECT
    'geolocation',
    COUNT(*)
FROM (
    SELECT geolocation_zip_code_prefix
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
    HAVING COUNT(*) > 1
) t

UNION ALL

-- product_category_translation
SELECT
    'product_category_translation',
    COUNT(*)
FROM (
    SELECT product_category_name
    FROM product_category_translation
    GROUP BY product_category_name
    HAVING COUNT(*) > 1
) t;

