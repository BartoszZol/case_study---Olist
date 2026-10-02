-- sales_analysis complex view
CREATE OR REPLACE VIEW vw_sales_analysis AS
SELECT
	-- Order
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    -- Customer
    c.customer_unique_id,
    c.customer_state,
    c.customer_zip_code_prefix,
    -- Seller
    s.seller_id,
    s.seller_state,
    s.seller_zip_code_prefix,
    -- Product
    oi.product_id,
    p.product_category_name,
    pct.product_category_name_english,
    -- Financials
    -- Two deliberately distinct metrics, used consistently everywhere downstream:
    --   price = merchandise value (what sellers/categories/products earn)
    --   total_price = price + freight_value = what the customer actually paid
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS total_price,
    -- Delivery dates
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    -- Order reviews
    orev.review_score
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
JOIN sellers s
    ON oi.seller_id = s.seller_id
LEFT JOIN (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews
    GROUP BY order_id
) orev
    ON o.order_id = orev.order_id
LEFT JOIN product_category_translation pct
	ON pct.product_category_name = p.product_category_name