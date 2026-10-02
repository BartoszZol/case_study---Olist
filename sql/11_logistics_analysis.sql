-- Seller order processing time

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
/*
Order status is not filtered, assuming freight costs are incurred regardless of final order status.
In a real-world scenario, cancellation and refund policies should be considered when calculating actual logistics costs.
*/

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