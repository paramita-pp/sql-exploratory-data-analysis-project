/*
===============================================================================
Product Report
===============================================================================
Purpose:
	- This report consolidates key product metrics and behaviours

Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
	3. Aggregate customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue

===============================================================================

*/

CREATE VIEW gold.report_products AS
WITH base_query AS (
/*-----------------------------------------------------------------------------
1) Base Query: Retrieves core columns from tables
------------------------------------------------------------------------------*/
	SELECT
	f.order_number,
	f.product_key,
	f.order_date,
	f.sales_amount,
	f.quantity,
	f.customer_key,
	p.product_number,
	p.product_name,
	p.category,
	p.sub_category,
	p.cost
	FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c
	ON f.customer_key = c.customer_key
	LEFT JOIN gold.dim_products p
	ON f.product_key = p.product_key
	WHERE order_date IS NOT NULL
),
product_aggregration AS (
/*-----------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
------------------------------------------------------------------------------*/
	SELECT
	product_key,
	product_number,
	product_name,
	category,
	sub_category,
	cost,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers,
	MAX(order_date) AS last_sale_date,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
	ROUND(AVG(CAST(sales_amount AS FLOAT)/ NULLIF(quantity, 0)), 1) AS avg_selling_price
	FROM base_query
	GROUP BY
	product_key,
	product_number,
	product_name,
	category,
	sub_category,
	cost
)
/*-----------------------------------------------------------------------------
3) Final Report
------------------------------------------------------------------------------*/
SELECT
product_key,
product_name,
category,
sub_category,
cost,
last_sale_date,
DATEDIFF(month, last_sale_date, GETDATE()) AS recency_in_months,
CASE
	WHEN total_sales > 5000	THEN 'High-Performer'
	WHEN total_sales >= 1000	THEN 'Mid-Range'
	ELSE 'Low-Performer'
END AS product_segment,
total_orders,
total_sales,
total_quantity,
total_customers,
lifespan,
avg_selling_price,
-- Compute average order revenue (AOR)
CASE WHEN total_orders = 0 THEN 0
	ELSE total_sales / total_orders
END AS avg_order_value,
-- Compute average monthly spend
CASE WHEN lifespan = 0 THEN total_sales
	ELSE total_sales / lifespan
END AS avg_monthly_spend
FROM product_aggregration
