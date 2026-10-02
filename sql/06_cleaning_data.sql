-- replacing empty strings with null

UPDATE order_reviews
SET review_comment_title = NULL
WHERE review_comment_title = '';

UPDATE order_reviews
SET review_comment_message = NULL
WHERE review_comment_message = '';

UPDATE products
SET product_category_name = NULL
WHERE product_category_name = '';

DELETE FROM product_category_translation
WHERE product_category_name = '';

UPDATE product_category_translation
SET product_category_name_english = NULL
WHERE product_category_name_english = '';


-- fixing invalid product measurements

UPDATE products
SET
    product_weight_g = NULLIF(product_weight_g, 0),
    product_length_cm = NULLIF(product_length_cm, 0),
    product_height_cm = NULLIF(product_height_cm, 0),
    product_width_cm = NULLIF(product_width_cm, 0);

-- Adding missing categories, filling null categories with 'uncategorized' synthetic value

INSERT INTO product_category_translation
(
    product_category_name,
    product_category_name_english
)
SELECT DISTINCT
    product_category_name,
    NULL
FROM products p
WHERE product_category_name IS NOT NULL
AND NOT EXISTS (
    SELECT 1
    FROM product_category_translation t
    WHERE p.product_category_name = t.product_category_name
);
UPDATE product_category_translation
SET product_category_name_english = CASE product_category_name
    WHEN 'pc_gamer' THEN 'gaming_pc'
    WHEN 'portateis_cozinha_e_preparadores_de_alimentos' THEN 'portable_kitchen_appliances'
END
WHERE product_category_name IN (
    'pc_gamer',
    'portateis_cozinha_e_preparadores_de_alimentos'
);

UPDATE product_category_translation
SET product_category_name_english = 'uncategorized'
WHERE product_category_name_english IS NULL;

INSERT INTO product_category_translation (product_category_name, product_category_name_english)
VALUES ('uncategorized', 'uncategorized');

UPDATE products
SET product_category_name = 'uncategorized'
WHERE product_category_name IS NULL;

-- adding missing fk (fk was not valid before due to missing categories)

ALTER TABLE products
ADD CONSTRAINT fk_products_translation
FOREIGN KEY (product_category_name)
REFERENCES product_category_translation(product_category_name);

-- Replace logically invalid delivery dates with NULL
  
UPDATE orders
SET 
	order_delivered_customer_date =
		CASE
			WHEN order_delivered_customer_date < order_delivered_carrier_date
			THEN NULL
			ELSE order_delivered_customer_date
		END,
        
    order_delivered_carrier_date =
		CASE 
			WHEN order_delivered_carrier_date < order_purchase_timestamp
			THEN NULL
			ELSE order_delivered_carrier_date
		END,
	
    order_delivered_carrier_date =
		CASE 
			WHEN order_delivered_carrier_date IS NULL OR order_approved_at IS NULL THEN NULL
			WHEN order_delivered_carrier_date < order_approved_at
			THEN NULL
			ELSE order_delivered_carrier_date
		END,
        
	order_estimated_delivery_date =
            
		CASE 
			WHEN order_estimated_delivery_date < order_purchase_timestamp
			THEN NULL
			ELSE order_estimated_delivery_date
		END;