-- Monthly revenue by seller state

SELECT
    DATE(DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01')) AS month_start,
    seller_state,
    SUM(price) AS revenue
FROM vw_sales_analysis
WHERE order_status = 'delivered'
GROUP BY
    month_start,
    seller_state
ORDER BY
    month_start,
    seller_state;
    
-- Top 5 sellers by state (based on revenue)

WITH seller_sales AS (
    SELECT
        seller_id,
        seller_state,
        SUM(price) AS revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        seller_id,
        seller_state
),
ranked_sellers AS (
    SELECT
        seller_id,
        seller_state,
        revenue,
        ROW_NUMBER() OVER (
            PARTITION BY seller_state
            ORDER BY revenue DESC
        ) AS seller_rank
    FROM seller_sales
)
SELECT
    seller_id,
    seller_state,
    revenue,
    seller_rank
FROM ranked_sellers
WHERE seller_rank <= 5
ORDER BY
    seller_state,
    seller_rank;

-- Global Seller Pareto / ABC

WITH seller_sales AS (
    SELECT
        seller_id,
        seller_state,
        SUM(price) AS revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY seller_id, seller_state
),
ranked_sellers AS (
    SELECT
        seller_id,
        seller_state,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC) AS seller_rank,
        SUM(revenue) OVER () AS total_marketplace_revenue,
        SUM(revenue) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_revenue
    FROM seller_sales
)
SELECT
    seller_id,
    seller_state,
    revenue,
    seller_rank,
    ROUND(running_revenue / total_marketplace_revenue * 100, 2) AS cumulative_share_percent,
    CASE
        WHEN running_revenue / total_marketplace_revenue <= 0.80 THEN 'A'
        WHEN running_revenue / total_marketplace_revenue <= 0.95 THEN 'B'
        ELSE 'C'
    END AS seller_abc_segment
FROM ranked_sellers
ORDER BY seller_rank;