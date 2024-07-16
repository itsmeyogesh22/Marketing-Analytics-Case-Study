--Part-A: Category Insights
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


--Part-B: Category Recommendations
/* --------------------------------------------------------------
1. Generate a summarised film count table with the category
included, we will use this table to rank the films by popularity
  * `film_counts`
---------------------------------------------------------------- */
DROP TABLE IF EXISTS film_counts;
CREATE TEMP TABLE film_counts AS
SELECT DISTINCT 
	film_id,
	title,
	category_name,
	COUNT(*)
		OVER (
		PARTITION BY film_id
		) AS rental_count
FROM complete_joint_dataset;


/* ---------------------------------------------------
2. Create a previously watched films for the top 2
categories to exclude for each customer
  * `category_film_exclusions`
---------------------------------------------------- */
DROP TABLE IF EXISTS category_film_exclusions;
CREATE TEMP TABLE category_film_exclusions AS 
SELECT DISTINCT
	customer_id,
	film_id
FROM complete_joint_dataset;


/* -------------------------------------------------------------------------
3. Finally perform an anti join from the relevant category films on the
exclusions and use window functions to keep the top 3 from each category
by popularity, split out the recommendations by category ranking
  * `category_recommendations`
---------------------------------------------------------------------------- */
DROP TABLE IF EXISTS category_recommendations;
CREATE TEMP TABLE category_recommendations AS 
WITH ranked_films_cte AS (
SELECT 
	T1.customer_id,
	T1.category_name,
	T1.category_rank,
	T2.film_id,
	T2.title,
	T2.rental_count,
	DENSE_RANK()
		OVER (
		PARTITION BY T1.customer_id, T1.category_rank
		ORDER BY T2.rental_count DESC, T2.title ASC
		) AS reco_rank
FROM top_categories AS T1
INNER JOIN film_counts AS T2
	ON T1.category_name = T2.category_name
WHERE NOT EXISTS
	(
	SELECT 1
	FROM category_film_exclusions AS T3
	WHERE T1.customer_id = T3. customer_id
	AND T2.film_id = T3.film_id
	)
)
SELECT *
FROM ranked_films_cte
WHERE reco_rank <= 3;




--Part-C: Actor Insights
/* ---------------------------------------------------
1. Create a new base dataset which has a focus on the actor instead of category
  * `actor_joint_table`
---------------------------------------------------- */
DROP TABLE IF EXISTS actor_joint_dataset;
CREATE TEMP TABLE actor_joint_dataset AS
SELECT 
	T1.customer_id, 
	T1.rental_id,
	T1.rental_date,
	T3.film_id,
	T3.title,
	T5.actor_id,
	T5.first_name,
	T5.last_name
FROM rental AS T1
INNER JOIN inventory AS T2
	ON T1.inventory_id = T2.inventory_id
INNER JOIN film AS T3
	ON T3.film_id = T2.film_id
INNER JOIN film_actor AS T4
	ON T4.film_id = T3.film_id
INNER JOIN actor AS T5
	ON T5.actor_id = T4.actor_id;


/* ---------------------------------------------------
2. Identify the top actor and their respective rental
count for each customer based off the ranked rental counts
  * `top_actor_counts`
---------------------------------------------------- */
DROP TABLE IF EXISTS top_actor_counts;
CREATE TEMP TABLE top_actor_counts AS
WITH actor_counts AS (
SELECT 
	customer_id,
	actor_id,
	first_name,
	last_name,
	COUNT(*) AS rental_count,
	MAX(rental_date) AS recent_rental_date
FROM actor_joint_dataset
GROUP BY 	
	customer_id,
	actor_id,
	first_name,
	last_name
),
ranked_actor AS (
SELECT 
	actor_counts.*,
	DENSE_RANK()
		OVER (
		PARTITION BY customer_id
		ORDER BY 
				rental_count DESC, 
				recent_rental_date DESC,
				first_name ASC,
				last_name ASC 
		) AS actor_rank
FROM actor_counts
) 
SELECT 
	customer_id,
	actor_id,
	first_name,
	last_name,
	rental_count
FROM ranked_actor
WHERE actor_rank = 1;


--Part-D: Actor Recommendations
/* ---------------------------------------------------
1. Generate total actor rental counts to use for film
popularity ranking in later steps
  * `actor_film_counts`
---------------------------------------------------- */

DROP TABLE IF EXISTS actor_film_counts;
CREATE TEMP TABLE actor_film_counts AS
WITH film_counts AS (
  SELECT
    film_id,
    COUNT(DISTINCT rental_id) AS rental_count
  FROM actor_joint_dataset
  GROUP BY film_id
)
SELECT DISTINCT
  actor_joint_dataset.film_id,
  actor_joint_dataset.actor_id,
  actor_joint_dataset.title,
  film_counts.rental_count
FROM actor_joint_dataset
LEFT JOIN film_counts
  ON actor_joint_dataset.film_id = film_counts.film_id;


/* -------------------------------------------------
2. Create an updated film exclusions table which
includes the previously watched films like we had
for the category recommendations - but this time we
need to also add in the films which were previously
recommended
  * `actor_film_exclusions`
---------------------------------------------------- */

DROP TABLE IF EXISTS actor_film_exclusions;
CREATE TEMP TABLE actor_film_exclusions AS
(
  SELECT DISTINCT
    customer_id,
    film_id
  FROM complete_joint_dataset
)
UNION
(
  SELECT DISTINCT
    customer_id,
    film_id
  FROM category_recommendations
);


/* -------------------------------------------------
3. Apply the same `ANTI JOIN` technique and use a
window function to identify the 3 valid film
recommendations for our customers
  * `actor_recommendations`
---------------------------------------------------- */

DROP TABLE IF EXISTS actor_recommendations;
CREATE TEMP TABLE actor_recommendations AS
WITH ranked_actor_films_cte AS (
SELECT
	top_actor_counts.customer_id,
	top_actor_counts.first_name,
    top_actor_counts.last_name,
    top_actor_counts.rental_count,
    actor_film_counts.title,
    actor_film_counts.film_id,
    actor_film_counts.actor_id,
    DENSE_RANK() 
		OVER (
		PARTITION BY top_actor_counts.customer_id
		ORDER BY 
			actor_film_counts.rental_count DESC, 
			actor_film_counts.title
    ) AS reco_rank
FROM top_actor_counts
INNER JOIN actor_film_counts
	ON top_actor_counts.actor_id = actor_film_counts.actor_id
WHERE NOT EXISTS 
	(
    SELECT 1
    FROM actor_film_exclusions
    WHERE
      actor_film_exclusions.customer_id = top_actor_counts.customer_id AND
      actor_film_exclusions.film_id = actor_film_counts.film_id
  	)
)
SELECT * FROM ranked_actor_films_cte
WHERE reco_rank <= 3;


DROP TABLE IF EXISTS final_data_asset;
CREATE TEMP TABLE final_data_asset AS 
WITH first_category AS (
SELECT 
	customer_id,
	category_name,
	CONCAT(
		'You''ve watched ', rental_count, ' ', category_name,
		' films, that''s ', average_comparison,
		' more than the DVD Rental Co average and puts you in the top ',
		percentile, '% of ', category_name, ' gurus!'
    ) AS insight
FROM first_category_insights
),
second_category AS (
SELECT 
	customer_id,
	category_name,
	CONCAT(
      'You''ve watched ', rental_count, ' ', category_name,
      ' films making up ', total_percentage,
      '% of your entire viewing history!'
    ) AS insight
FROM second_category_insights
),
top_actor AS (
SELECT 
	customer_id,
	CONCAT(INITCAP(first_name), ' ', INITCAP(last_name)) AS actor_name,
	CONCAT(
      'You''ve watched ', rental_count, ' films featuring ',
      INITCAP(first_name), ' ', INITCAP(last_name),
      '! Here are some other films ', INITCAP(first_name),
      ' stars in that might interest you!'
    ) AS insight
FROM top_actor_counts
),
adjusted_title_case_category_recommendations AS (
SELECT 
	customer_id,
	INITCAP(title) AS title,
	category_rank,
	reco_rank
FROM category_recommendations
),
wide_category_recommendations AS (
SELECT 
	customer_id,
	MAX(CASE WHEN category_rank = 1 AND reco_rank = 1 
	THEN title END) AS cat_1_reco_1,
	MAX(CASE WHEN category_rank = 1 AND reco_rank = 2 
	THEN title END) AS cat_1_reco_2,
	MAX(CASE WHEN category_rank = 1 AND reco_rank = 3
	THEN title END) AS cat_1_reco_3,
	MAX(CASE WHEN category_rank = 2 AND reco_rank = 1 
	THEN title END) AS cat_2_reco_1,
	MAX(CASE WHEN category_rank = 2 AND reco_rank = 2
	THEN title END) AS cat_2_reco_2,
	MAX(CASE WHEN category_rank = 2 AND reco_rank = 3
	THEN title END) AS cat_2_reco_3
FROM adjusted_title_case_category_recommendations
GROUP BY customer_id
),
adjusted_title_case_actor_recommendations AS (
SELECT 
	customer_id,
	INITCAP(title) AS title,
	reco_rank
FROM actor_recommendations
),
wide_actor_recommendations AS (
SELECT 
	customer_id,
	MAX(CASE WHEN reco_rank = 1 THEN title END) AS actor_reco_1,
	MAX(CASE WHEN reco_rank = 2 THEN title END) AS actor_reco_2,
	MAX(CASE WHEN reco_rank = 3 THEN title END) AS actor_reco_3
FROM adjusted_title_case_actor_recommendations
GROUP BY customer_id
),
final_output AS (
SELECT DISTINCT
	T1.customer_id,
	T1.category_name AS cat_1,
	T4.cat_1_reco_1,
	T4.cat_1_reco_2,
	T4.cat_1_reco_3,
	T2.category_name AS cat_2,
	T4.cat_2_reco_1,
	T4.cat_2_reco_2,
	T4.cat_2_reco_3,
	T3.actor_name AS actor,
	T5.actor_reco_1,
	T5.actor_reco_2,
	T5.actor_reco_3,
	T1.insight AS insights_cat_1,
	T2.insight AS insights_cat_2,
	T3.insight AS insights_actor
FROM first_category AS T1
INNER JOIN second_category AS T2
	ON T1.customer_id = T2.customer_id
INNER JOIN top_actor AS T3
	ON T1.customer_id = T3.customer_id
INNER JOIN wide_category_recommendations AS T4
	ON T1.customer_id = T4.customer_id
INNER JOIN wide_actor_recommendations AS T5
	ON T1.customer_id = T5.customer_id
)
SELECT *
FROM final_output;