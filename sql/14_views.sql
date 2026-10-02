-- TOP customers per state - value
CREATE OR REPLACE VIEW vw_ca_top_customers_state_value AS
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
CREATE OR REPLACE VIEW vw_ca_top_customers_state_orders AS
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
CREATE OR REPLACE VIEW vw_ca_top_category_customer_state AS
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

-- Monthly revenue by seller state
CREATE OR REPLACE VIEW vw_s_monthly_revenue_by_state AS
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

CREATE OR REPLACE VIEW vw_s_top_sellers_by_state AS
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

-- ABC seller analysis

CREATE OR REPLACE VIEW vw_s_seller_abc_analysis AS
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

-- Seller order processing time
CREATE OR REPLACE VIEW vw_l_delivery_timeliness AS
WITH seller_orders AS (
    SELECT DISTINCT
        seller_id,
        seller_state,
        order_id,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date
    FROM vw_sales_analysis
)
SELECT
    seller_state,
    seller_id,
    AVG(DATEDIFF(order_approved_at, order_purchase_timestamp)) AS avg_accepting_order_time,
    AVG(DATEDIFF(order_delivered_carrier_date, order_approved_at)) AS avg_preparing_order_time
FROM seller_orders
GROUP BY
    seller_state,
    seller_id;
    
-- avg delivery time for each state relation
CREATE OR REPLACE VIEW vw_l_avg_delivery_time_state AS
WITH route_orders AS (
    SELECT DISTINCT
        seller_state,
        customer_state,
        order_id,
        order_delivered_customer_date,
        order_delivered_carrier_date,
        order_estimated_delivery_date
    FROM vw_sales_analysis
)
SELECT
    seller_state,
    customer_state,
    AVG(DATEDIFF(order_delivered_customer_date, order_delivered_carrier_date)) AS avg_delivery_time_days,
    AVG(DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date)) AS avg_delivery_delay_days,
    COUNT(order_id) AS number_of_orders
FROM route_orders
GROUP BY
    seller_state,
    customer_state;
   
-- Freight cost, distance and cost per km analysis by seller-customer route
CREATE OR REPLACE VIEW vw_l_freight_costs AS
WITH seller_geo AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS seller_lat,
        AVG(geolocation_lng) AS seller_lng
    FROM 
		geolocation
    GROUP BY 
		geolocation_zip_code_prefix
),
customer_geo AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS customer_lat,
        AVG(geolocation_lng) AS customer_lng
    FROM 
		geolocation
    GROUP BY 
		geolocation_zip_code_prefix
)
SELECT
    v.seller_state,
    v.customer_state,
    ROUND(AVG(v.freight_value),2) AS avg_freight_cost,
    ROUND(AVG(
        6371 * 2 * ASIN(
            SQRT(
                POWER(SIN(RADIANS(cg.customer_lat - sg.seller_lat) / 2), 2)
                +
                COS(RADIANS(sg.seller_lat))
                *
                COS(RADIANS(cg.customer_lat))
                *
                POWER(SIN(RADIANS(cg.customer_lng - sg.seller_lng) / 2), 2)
            )
        )
    ),2) AS avg_distance_km,
    ROUND(AVG(v.freight_value) /
    AVG(
        6371 * 2 * ASIN(
            SQRT(
                POWER(SIN(RADIANS(cg.customer_lat - sg.seller_lat) / 2), 2)
                +
                COS(RADIANS(sg.seller_lat))
                *
                COS(RADIANS(cg.customer_lat))
                *
                POWER(SIN(RADIANS(cg.customer_lng - sg.seller_lng) / 2), 2)
            )
        )
    ),2) AS freight_cost_per_km,
	COUNT(DISTINCT v.order_id) AS number_of_orders
FROM 
	vw_sales_analysis v
JOIN 
	seller_geo sg
    ON 
		sg.geolocation_zip_code_prefix = v.seller_zip_code_prefix
JOIN 
	customer_geo cg
    ON 
		cg.geolocation_zip_code_prefix = v.customer_zip_code_prefix
GROUP BY
    v.seller_state,
    v.customer_state;

-- ABC category analysis
CREATE OR REPLACE VIEW vw_p_abc_category_analysis AS
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
    END AS category_abc
FROM category_pareto;

-- ABC product analysis
CREATE OR REPLACE VIEW vw_p_abc_product_analysis AS
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
    END AS product_abc
FROM product_pareto;

-- TOP 5 selling products in each category
CREATE OR REPLACE VIEW vw_p_top5_selling_products AS
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
    
-- Category sales monthly trend and growth
CREATE OR REPLACE VIEW vw_t_category_sales_monthly AS
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
    END AS is_low_volume_baseline
FROM sales_comparison
ORDER BY
    product_category_name,
    month_start;
    
-- Category sales trends by month
CREATE OR REPLACE VIEW vw_t_category_seasonality_index AS
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
    
-- Category sales forecast
CREATE OR REPLACE VIEW vw_t_category_sales_forecast AS
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
    
-- Route flow points for map visualization (Path/Detail encoding).
-- WARNING: every metric is duplicated across the two rows per route —
-- do NOT SUM/COUNT anything from this view directly. Use vw_l_freight_costs
-- for any actual numeric analysis; this view exists only to feed the map.
CREATE OR REPLACE VIEW vw_l_freight_routes_map AS
SELECT
    CONCAT(seller_state, '-', customer_state) AS route_id,
    1 AS point_order,
    seller_state AS state,
    seller_state AS route_seller_state,
    customer_state AS route_customer_state,
    CASE WHEN seller_state = customer_state THEN 'Intra-state' ELSE 'Inter-state' END AS route_type,
    avg_freight_cost,
    avg_distance_km,
    freight_cost_per_km,
    number_of_orders,
    CASE WHEN seller_state <> customer_state THEN freight_cost_per_km END AS inter_freight_cost_per_km,
    CASE WHEN seller_state =  customer_state THEN freight_cost_per_km END AS intra_freight_cost_per_km,
    CASE WHEN seller_state <> customer_state THEN number_of_orders END AS inter_number_of_orders,
    CASE WHEN seller_state =  customer_state THEN number_of_orders END AS intra_number_of_orders
FROM vw_l_freight_costs

UNION ALL

SELECT
    CONCAT(seller_state, '-', customer_state) AS route_id,
    2 AS point_order,
    customer_state AS state,
    seller_state AS route_seller_state,
    customer_state AS route_customer_state,
    CASE WHEN seller_state = customer_state THEN 'Intra-state' ELSE 'Inter-state' END AS route_type,
    avg_freight_cost,
    avg_distance_km,
    freight_cost_per_km,
    number_of_orders,
    CASE WHEN seller_state <> customer_state THEN freight_cost_per_km END AS inter_freight_cost_per_km,
    CASE WHEN seller_state =  customer_state THEN freight_cost_per_km END AS intra_freight_cost_per_km,
    CASE WHEN seller_state <> customer_state THEN number_of_orders END AS inter_number_of_orders,
    CASE WHEN seller_state =  customer_state THEN number_of_orders END AS intra_number_of_orders
FROM vw_l_freight_costs
ORDER BY route_id, point_order;