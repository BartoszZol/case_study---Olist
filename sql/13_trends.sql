-- Category sales monthly trend and growth

WITH monthly_sales AS (
    SELECT
        product_category_name,
        product_category_name_english,
        DATE(DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01')) AS month_start,
        SUM(price) AS revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        product_category_name,
        product_category_name_english,
        month_start
),
category_baseline AS (
    SELECT
        product_category_name,
        AVG(revenue) AS avg_monthly_revenue
    FROM monthly_sales
    GROUP BY product_category_name
),
sales_comparison AS (
    SELECT
        m.product_category_name,
        m.product_category_name_english,
        m.month_start,
        m.revenue,
        b.avg_monthly_revenue,
        LAG(m.revenue) OVER (
            PARTITION BY m.product_category_name
            ORDER BY m.month_start
        ) AS previous_month_revenue,
        LAG(m.month_start) OVER (
            PARTITION BY m.product_category_name
            ORDER BY m.month_start
        ) AS previous_month_start,
        ROUND(
            AVG(m.revenue) OVER (
                PARTITION BY m.product_category_name
                ORDER BY m.month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ),
            2
        ) AS moving_avg_3_months
    FROM monthly_sales m
    JOIN category_baseline b
        ON m.product_category_name = b.product_category_name
)
SELECT
    product_category_name,
    product_category_name_english,
    month_start,
    revenue,
    previous_month_revenue,
    ROUND(revenue - previous_month_revenue, 2) AS revenue_difference,
    ROUND(
        (revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0) * 100,
        2
    ) AS revenue_growth_percent,
    moving_avg_3_months,
    CASE WHEN previous_month_start < '2017-01-01' THEN TRUE ELSE FALSE END AS is_ramp_up_period,
    CASE
        WHEN previous_month_revenue < 0.2 * avg_monthly_revenue THEN TRUE
        ELSE FALSE
    END AS is_low_volume_baseline -- flags a category-month where the PRIOR month was small relative to THAT CATEGORY's own average
FROM sales_comparison
ORDER BY
    product_category_name,
    month_start;
    
-- Category sales trends by month (normalizes each month against its OWN year's total before - averaging across years. does not pool Jan-2017 + Jan-2018.)
WITH monthly_sales AS (
    SELECT
        product_category_name,
        product_category_name_english,
        YEAR(order_purchase_timestamp) AS sales_year,
        MONTH(order_purchase_timestamp) AS sales_month,
        MONTHNAME(order_purchase_timestamp) AS sales_month_name,
        SUM(price) AS revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        product_category_name, product_category_name_english,
        YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp),
        MONTHNAME(order_purchase_timestamp)
),
yearly_totals AS (
    SELECT product_category_name, sales_year, SUM(revenue) AS year_revenue
    FROM monthly_sales
    GROUP BY product_category_name, sales_year
),
monthly_share AS (
    SELECT
        m.product_category_name,
        m.product_category_name_english,
        m.sales_month,
        m.sales_month_name,
        m.revenue / NULLIF(y.year_revenue, 0) AS revenue_share_of_year
    FROM monthly_sales m
    JOIN yearly_totals y
        ON m.product_category_name = y.product_category_name
        AND m.sales_year = y.sales_year
)
SELECT
    product_category_name,
    product_category_name_english,
    sales_month,
    sales_month_name,
    ROUND(AVG(revenue_share_of_year) / (1.0 / 12), 2) AS seasonality_index
FROM monthly_share
GROUP BY product_category_name, product_category_name_english, sales_month, sales_month_name
ORDER BY product_category_name, sales_month;
    
-- Category sales 3-month trailing moving-average

WITH monthly_sales AS (
    SELECT
        product_category_name,
        product_category_name_english,
        DATE(DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01')) AS month_start,
        SUM(price) AS revenue
    FROM vw_sales_analysis
    WHERE order_status = 'delivered'
    GROUP BY
        product_category_name,
        product_category_name_english,
        month_start
),
moving_average AS (
    SELECT
        product_category_name,
        product_category_name_english,
        month_start,
        revenue,
        AVG(revenue) OVER (
            PARTITION BY product_category_name
            ORDER BY month_start
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3_months
    FROM monthly_sales
),
forecast AS (
    SELECT
        product_category_name,
        product_category_name_english,
        month_start,
        revenue,
        LAG(moving_avg_3_months) OVER (
            PARTITION BY product_category_name
            ORDER BY month_start
        ) AS forecast_revenue
    FROM moving_average
)
SELECT
    product_category_name,
    product_category_name_english,
    month_start,
    ROUND(revenue, 2) AS revenue,
    ROUND(forecast_revenue, 2) AS forecast_revenue,
    ROUND(revenue - forecast_revenue, 2) AS forecast_difference,
    ROUND(
        (revenue - forecast_revenue) / NULLIF(forecast_revenue, 0) * 100,
        2
    ) AS forecast_difference_percent
FROM forecast
ORDER BY
    product_category_name,
    month_start;