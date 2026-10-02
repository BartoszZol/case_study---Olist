-- TOP customers per state - value

WITH customer_value AS (
    SELECT
        customer_unique_id,
        customer_state,
        SUM(price) AS product_price,
        SUM(freight_value) AS freight_price,
        SUM(total_price) AS total_price
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        customer_unique_id,
        customer_state
),
ranked_customers_values AS (
    SELECT
        *,
        RANK() OVER (
            PARTITION BY customer_state
            ORDER BY total_price DESC
        ) AS customer_value_rank
    FROM customer_value
)
SELECT *
FROM ranked_customers_values
WHERE customer_value_rank <= 10;

-- Customers with most orders per state

WITH customer_orders AS (
    SELECT
        customer_unique_id,
        customer_state,
        COUNT(DISTINCT order_id) AS amount_of_orders,
        COUNT(product_id) AS amount_of_products
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        customer_unique_id,
        customer_state
),
ranked_customers_orders AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY customer_state
            ORDER BY amount_of_orders DESC
        ) AS customer_orders_rank
    FROM customer_orders
)
SELECT *
FROM ranked_customers_orders
WHERE customer_orders_rank <= 10;

-- Most popular product category per customer state

WITH category_sales AS(
	SELECT
		customer_state,
        product_category_name_english,
		COUNT(product_id) AS products_sold
	FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        customer_state,
        product_category_name_english
),
ranked_categories AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY customer_state
            ORDER BY products_sold DESC
        ) AS category_rank
    FROM category_sales
)
SELECT *
FROM ranked_categories
WHERE category_rank = 1;