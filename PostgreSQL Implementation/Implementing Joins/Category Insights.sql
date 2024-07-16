--1) Create a base dataset and join all relevant tables.
DROP TABLE IF EXISTS complete_joint_dataset;
CREATE TEMP TABLE complete_joint_dataset AS
SELECT 
	T1.customer_id,
	T2.film_id,
	T3.title, 
	T1.rental_date,
	T5."name" AS category_name
FROM rental AS T1
INNER JOIN inventory AS T2
	ON T1.inventory_id = T2.inventory_id
INNER JOIN film AS T3
	ON T3.film_id = T2.film_id
INNER JOIN film_category AS T4
	ON T4.film_id = T3.film_id
INNER JOIN category AS T5
	ON T5.category_id = T4.category_id;


--2) Calculate customer rental counts for each category.
--  * `category_counts`
DROP TABLE IF EXISTS category_counts;
CREATE TEMP TABLE category_counts AS
SELECT 
	customer_id,
	category_name,
	COUNT(*) AS rental_count,
	MAX(rental_date) AS recent_renatal_date
FROM complete_joint_dataset
GROUP BY 
	customer_id,
	category_name;


--3) Aggregate all customer total films watched.
-- * `total_counts`
DROP TABLE IF EXISTS total_counts;
CREATE TEMP TABLE total_counts AS 
SELECT 
	customer_id,
	SUM(rental_count) AS total_rental_count
FROM category_counts
GROUP BY 
	customer_id;


--4. Identify the top 2 categories for each customer 
--	 * `top_categories`
DROP TABLE IF EXISTS top_categories;
CREATE TEMP TABLE top_categories AS
WITH ranked_cte AS (
SELECT 
	customer_id,
	category_name,
	rental_count,
	DENSE_RANK()
		OVER (
			PARTITION BY customer_id
			ORDER BY rental_count DESC, recent_renatal_date DESC
		) AS category_rank
FROM category_counts
) 
SELECT *
FROM ranked_cte
WHERE category_rank <= 2;


--5. Calculate each category's aggregated average rental count
--	* `average_category_count`
DROP TABLE IF EXISTS average_category_count;
CREATE TEMP TABLE average_category_count AS 
SELECT 
	category_name,
	FLOOR(AVG(rental_count)) AS category_average
FROM category_counts
GROUP BY 
	category_name;


--6. Calculate the percentile metric for each customer's top category film count
--	* `top_category_percentile`
DROP TABLE IF EXISTS top_category_percentile;
CREATE TEMP TABLE top_category_percentile AS
WITH calculated_cte AS (
SELECT 
	T2.customer_id,
	T2.category_name AS top_category_name,
	T1.rental_count,
	T1.category_name,
	T2.category_rank,
	PERCENT_RANK()
	OVER (
		PARTITION BY T1.category_name
		ORDER BY T1.rental_count DESC
	) AS raw_percentile
FROM category_counts AS T1
LEFT JOIN top_categories AS T2
	ON T1.customer_id = T2.customer_id
)
SELECT 
	customer_id,
	category_name,
	rental_count,
	category_rank,
	CASE 
		WHEN ROUND(100 * raw_percentile) = 0 THEN 1 
		ELSE ROUND(100 * raw_percentile)
	END AS percentile
FROM calculated_cte
WHERE
	category_rank = 1
	AND category_name = top_category_name;


--7. Generate our first top category insights table using all previously generated tables
--  * `top_category_insights`
DROP TABLE IF EXISTS first_category_insights;
CREATE TEMP TABLE first_category_insights AS 
SELECT 
	T1.customer_id,
	T1.category_name,
	T1.rental_count,
	(T1.rental_count - T2.category_average) AS average_comparison,
	T1.percentile
FROM top_category_percentile AS T1
LEFT JOIN average_category_count AS T2
	ON T1.category_name = T2.category_name;


--8. Generate the 2nd category insights
--  * `second_category_insights`
DROP TABLE IF EXISTS second_category_insights;
CREATE TEMP TABLE second_category_insights AS 
SELECT 
	T1.customer_id,
	T1.category_name,
	T1.rental_count,
	ROUND(
		100 * T1.rental_count::NUMERIC/T2.total_rental_count
	) AS total_percentage
FROM top_categories AS T1
LEFT JOIN total_counts AS T2
	ON T1.customer_id = T2.customer_id
WHERE T1.category_rank = 2;