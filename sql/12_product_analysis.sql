-- ABC category analysis

WITH category_revenue AS (
    SELECT
        product_category_name,
        product_category_name_english,
        SUM(price) AS revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        product_category_name,
        product_category_name_english
),
category_pareto AS (
    SELECT
        *,
        SUM(revenue) OVER(
            ORDER BY revenue DESC
        )
        /
        SUM(revenue) OVER()
        AS cumulative_share
    FROM category_revenue
)
SELECT
    *,
    CASE
        WHEN cumulative_share <= 0.80 THEN 'A'
        WHEN cumulative_share <= 0.95 THEN 'B'
        ELSE 'C'
    END AS category_ABC
FROM category_pareto;

-- ABC product analysis

WITH product_revenue AS (
    SELECT
        product_id,
        product_category_name,
        product_category_name_english,
        SUM(price) AS product_revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        product_id,
        product_category_name,
        product_category_name_english
),
product_pareto AS (
    SELECT
        *,
        SUM(product_revenue) OVER(
			PARTITION BY product_category_name
            ORDER BY product_revenue DESC
        )
        /
        SUM(product_revenue) OVER(
			PARTITION BY product_category_name
        )
        AS cumulative_share
    FROM product_revenue
)
SELECT
    *,
    CASE
        WHEN cumulative_share <= 0.80 THEN 'A'
        WHEN cumulative_share <= 0.95 THEN 'B'
        ELSE 'C'
    END AS product_ABC
FROM product_pareto;

-- TOP 5 selling products in each category

WITH product_sales AS (
    SELECT
        product_id,
        product_category_name,
        product_category_name_english,
        SUM(price) AS revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        product_id,
        product_category_name,
        product_category_name_english
),
ranked_products AS (
    SELECT
        *,
        ROW_NUMBER() OVER(
            PARTITION BY product_category_name
            ORDER BY revenue DESC
        ) AS product_rank
    FROM product_sales
)
SELECT
    product_category_name,
    product_category_name_english,
    CASE
        WHEN product_rank <= 5
        THEN product_id
        ELSE 'OTHER'
    END AS product_group,
    CASE
        WHEN product_rank <= 5
        THEN 'TOP 5'
        ELSE 'OTHER'
    END AS product_segment,
    SUM(revenue) AS revenue
FROM ranked_products
GROUP BY
    product_category_name,
    product_category_name_english,
    CASE WHEN product_rank <= 5 THEN product_id ELSE 'OTHER' END,
    CASE WHEN product_rank <= 5 THEN 'TOP 5' ELSE 'OTHER' END
ORDER BY
    product_category_name,
    revenue DESC;