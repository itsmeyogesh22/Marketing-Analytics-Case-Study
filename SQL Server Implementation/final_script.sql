
/*
	!!-- Set Compatibility level to use STR_AGG() and STR_SPLIT() Function --!!
*/

USE master;
ALTER DATABASE dvd_rentals
SET COMPATIBILITY_LEVEL = 150;
USE dvd_rentals;

--Part-A: Category Insights
/*
	1) Create a base dataset and join all relevant tables.
*/
DROP TABLE IF EXISTS #complete_joint_dataset;
CREATE TABLE #complete_joint_dataset 
									(
									 customer_id INT,
									 film_id INT,
									 title VARCHAR(50),
									 rental_date DATETIME2,
									 category_name VARCHAR(50)
									);
INSERT INTO #complete_joint_dataset 
									(
									 customer_id,
									 film_id,
									 title,
									 rental_date,
									 category_name
									)
SELECT 
	T1.customer_id,
	T2.film_id,
	T3.title, 
	T1.rental_date,
	T5.[name] AS category_name
FROM rental AS T1
INNER JOIN inventory AS T2
	ON T1.inventory_id = T2.inventory_id
INNER JOIN film AS T3
	ON T3.film_id = T2.film_id
INNER JOIN film_category AS T4
	ON T4.film_id = T3.film_id
INNER JOIN category AS T5
	ON T5.category_id = T4.category_id;


/*
	2) Calculate customer rental counts for each category. 
	* `category_counts`
*/
DROP TABLE IF EXISTS #category_counts;
CREATE TABLE #category_counts 
							 (
							  customer_id INT,
							  category_name VARCHAR(50),
							  rental_count INT,
							  recent_renatal_date DATETIME2
							 );
INSERT INTO #category_counts 
							(
							 customer_id,
							 category_name,
							 rental_count,
							 recent_renatal_date
							)
SELECT 
	customer_id,
	category_name,
	COUNT(*) AS rental_count,
	MAX(rental_date) AS recent_renatal_date
FROM #complete_joint_dataset
GROUP BY 
	customer_id,
	category_name;


/*
	3) Aggregate all customer total films watched.
	* `total_counts`
*/
DROP TABLE IF EXISTS #total_counts;
CREATE TABLE #total_counts 
						  (
						   customer_id INT,
						   total_rental_count INT
						  );
INSERT INTO #total_counts 
						 (
						 customer_id,
						 total_rental_count
						 )
SELECT 
	customer_id,
	SUM(rental_count) AS total_rental_count
FROM #category_counts
GROUP BY 
	customer_id;



/*
	4) Identify the top 2 categories for each customer 
	* `top_categories`
*/
DROP TABLE IF EXISTS #top_categories;
CREATE TABLE #top_categories 
							(
							 customer_id INT,
							 category_name VARCHAR(50),
							 rental_count INT,
							 category_rank INT
							);
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
FROM #category_counts
) 
INSERT INTO #top_categories 
						   (
						    customer_id,
							category_name,
							rental_count,
							category_rank
						   )
SELECT *
FROM ranked_cte
WHERE category_rank <= 2;



/*
	5) Calculate each category's aggregated average rental count
	* `average_category_count`
*/
DROP TABLE IF EXISTS #average_category_count;
CREATE TABLE #average_category_count 
									(
									 category_name VARCHAR(50),
									 category_average INT
									);
INSERT INTO #average_category_count 
								   (
								    category_name,
									category_average
								   )
SELECT 
	category_name,
	FLOOR(AVG(rental_count)) AS category_average
FROM #category_counts
GROUP BY 
	category_name;



/*
	6) Calculate the percentile metric for each customer's top category film count
	* `top_category_percentile`
*/
DROP TABLE IF EXISTS #top_category_percentile;
CREATE TABLE #top_category_percentile 
									 (
									  customer_id INT,
									  category_name VARCHAR(50),
									  rental_count INT,
									  category_rank INT,
									  percentile INT
									 );
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
FROM #category_counts AS T1
LEFT JOIN #top_categories AS T2
	ON T1.customer_id = T2.customer_id
)
INSERT INTO #top_category_percentile 
									(
									 customer_id,
									 category_name,
									 rental_count,
									 category_rank,
									 percentile
									)
SELECT 
	customer_id,
	category_name,
	rental_count,
	category_rank,
	CASE 
		WHEN CAST(100 * raw_percentile AS numeric) = 0 THEN 1 
		ELSE CAST(100 * raw_percentile AS numeric)
	END AS percentile
FROM calculated_cte
WHERE
	category_rank = 1
	AND category_name = top_category_name;



/*
	7) Generate our first top category insights table using all previously generated tables
	* `top_category_insights`
*/
DROP TABLE IF EXISTS #top_category_insights;
CREATE TABLE #top_category_insights 
								   (
								    customer_id INT,
									category_name VARCHAR(50),
									rental_count INT,
									average_comparison INT,
									percentile INT
								   );
INSERT INTO #top_category_insights 
								  (
								   customer_id,
								   category_name,
								   rental_count,
								   average_comparison,
								   percentile
								  )
SELECT 
	T1.customer_id,
	T1.category_name,
	T1.rental_count,
	(T1.rental_count - T2.category_average) AS average_comparison,
	T1.percentile
FROM #top_category_percentile AS T1
LEFT JOIN #average_category_count AS T2
	ON T1.category_name = T2.category_name;



/*
	8) Generate the 2nd category insights
	* `second_category_insights`
*/
DROP TABLE IF EXISTS #second_category_insights;
CREATE TABLE #second_category_insights 
									  (
									   customer_id INT,
									   category_name VARCHAR(50),
									   rental_count INT,
									   total_percentage INT
									  );
INSERT INTO #second_category_insights 
									 (
									  customer_id,
									  category_name,
									  rental_count,
									  total_percentage
									 )
SELECT 
	T1.customer_id,
	T1.category_name,
	T1.rental_count,
	CAST((T1.rental_count*100/CAST(T2.total_rental_count AS NUMERIC)) AS NUMERIC) AS total_percentage
FROM #top_categories AS T1
LEFT JOIN #total_counts AS T2
	ON T1.customer_id = T2.customer_id
WHERE T1.category_rank = 2;


--Part-B: Category Recommendations
/* --------------------------------------------------------------
	1) Generate a summarised film count table with the category
	included, we will use this table to rank the films by popularity
	* `film_counts`
---------------------------------------------------------------- */
DROP TABLE IF EXISTS #film_counts;
CREATE TABLE #film_counts 
						 (
						  film_id INT,
						  title VARCHAR(50),
						  category_name VARCHAR(50),
						  rental_count INT
						 );
INSERT INTO #film_counts
						(
						 film_id,
						 title,
						 category_name,
						 rental_count
						)
SELECT DISTINCT 
	film_id,
	title,
	category_name,
	COUNT(*)
		OVER (
		PARTITION BY film_id
		) AS rental_count
FROM #complete_joint_dataset;



/* ---------------------------------------------------
	2) Create a previously watched films for the top 2
	categories to exclude for each customer
	* `category_film_exclusions`
---------------------------------------------------- */
DROP TABLE IF EXISTS #category_film_exclusions;
CREATE TABLE #category_film_exclusions (customer_id INT, film_id INT);
INSERT INTO #category_film_exclusions (customer_id, film_id)
SELECT DISTINCT
	customer_id,
	film_id
FROM #complete_joint_dataset;


/* -------------------------------------------------------------------------
	3) Finally perform an anti join from the relevant category films on the
	exclusions and use window functions to keep the top 3 from each category
	by popularity, split out the recommendations by category ranking
	* `category_recommendations`
---------------------------------------------------------------------------- */
DROP TABLE IF EXISTS #category_recommendations;
CREATE TABLE #category_recommendations 
									  (
									   customer_id INT,
									   category_name VARCHAR(50),
									   category_rank INT, 
									   film_id INT,
									   title VARCHAR(50),
									   rental_count INT,
									   reco_rank INT
									  );
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
FROM #top_categories AS T1
INNER JOIN #film_counts AS T2
	ON T1.category_name = T2.category_name
WHERE NOT EXISTS
	(
	SELECT 1
	FROM #category_film_exclusions AS T3
	WHERE T1.customer_id = T3. customer_id
	AND T2.film_id = T3.film_id
	)
)
INSERT INTO #category_recommendations 
									 (
									  customer_id,
									  category_name,
									  category_rank,
									  film_id,
									  title,
									  rental_count,
									  reco_rank
									 )
SELECT *
FROM ranked_films_cte
WHERE reco_rank <= 3;


--Part-C: Actor Insights
/* ---------------------------------------------------
	1. Create a new base dataset which has a focus on the actor instead of category
	* `actor_joint_table`
---------------------------------------------------- */
DROP TABLE IF EXISTS #actor_joint_dataset;
CREATE TABLE #actor_joint_dataset 
								 (
								  customer_id INT,
								  rental_id INT,
								  rental_date DATETIME2,
								  film_id INT,
								  title VARCHAR(50),
								  actor_id INT,
								  first_name VARCHAR(50),
								  last_name VARCHAR(50)
								 );
INSERT INTO #actor_joint_dataset 
								(
								 customer_id,
								 rental_id,
								 rental_date,
								 film_id,
								 title,
								 actor_id,
								 first_name,
								 last_name
								)
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
DROP TABLE IF EXISTS #top_actor_counts;
CREATE TABLE #top_actor_counts 
							  (
							   customer_id INT,
							   actor_id INT,
							   first_name VARCHAR(50),
							   last_name VARCHAR(50),
							   rental_count INT
							  );
WITH actor_counts AS (
SELECT 
	customer_id,
	actor_id,
	first_name,
	last_name,
	COUNT(*) AS rental_count,
	MAX(rental_date) AS recent_rental_date
FROM #actor_joint_dataset
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
INSERT INTO #top_actor_counts 
							 (
							  customer_id,
							  actor_id,
							  first_name,
							  last_name,
							  rental_count
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
	1) Generate total actor rental counts to use for film
	popularity ranking in later steps
	* `actor_film_counts`
---------------------------------------------------- */
DROP TABLE IF EXISTS #actor_film_counts;
CREATE TABLE #actor_film_counts 
							   (
							    film_id INT,
								actor_id INT,
								title VARCHAR(50),
								rental_count INT
							   );
WITH film_counts AS (
  SELECT
    film_id,
    COUNT(DISTINCT rental_id) AS rental_count
  FROM #actor_joint_dataset
  GROUP BY film_id
)
INSERT INTO #actor_film_counts 
							  (
							   film_id,
							   actor_id,
							   title,
							   rental_count
							  )
SELECT DISTINCT
  T1.film_id,
  T1.actor_id,
  T1.title,
  T2.rental_count
FROM #actor_joint_dataset [T1] 
LEFT JOIN film_counts [T2]
  ON T1.film_id = T2.film_id;




/* -------------------------------------------------
	2) Create an updated film exclusions table which
	includes the previously watched films like we had
	for the category recommendations - but this time we
	need to also add in the films which were previously
	recommended
	* `actor_film_exclusions`
---------------------------------------------------- */
DROP TABLE IF EXISTS #actor_film_exclusions;
CREATE TABLE #actor_film_exclusions (customer_id INT, film_id INT);
INSERT INTO #actor_film_exclusions (customer_id, film_id)
(
  SELECT DISTINCT
    customer_id,
    film_id
  FROM #complete_joint_dataset
)
UNION
(
  SELECT DISTINCT
    customer_id,
    film_id
  FROM #category_recommendations
);



/* -------------------------------------------------
	3) Apply the same `ANTI JOIN` technique and use a
	window function to identify the 3 valid film
	recommendations for our customers
	* `actor_recommendations`
---------------------------------------------------- */
DROP TABLE IF EXISTS #actor_recommendations;
CREATE TABLE #actor_recommendations 
								   (
								    customer_id INT,
									first_name VARCHAR(50),
									last_name VARCHAR(50),
									rental_count INT,
									title VARCHAR(50),
									film_id INT,
									actor_id INT,
									reco_rank INT
								   );
WITH ranked_actor_films_cte AS (
  SELECT
    T1.customer_id,
    T1.first_name,
    T1.last_name,
    T1.rental_count,
    T2.title,
    T2.film_id,
    T2.actor_id,
    DENSE_RANK() OVER (
      PARTITION BY
        T1.customer_id
      ORDER BY
        T2.rental_count DESC,
        T2.title
    ) AS reco_rank
  FROM #top_actor_counts [T1]
  INNER JOIN #actor_film_counts [T2]
    ON T1.actor_id = T2.actor_id
  WHERE NOT EXISTS (
    SELECT 1
    FROM #actor_film_exclusions [T3]
    WHERE
      T3.customer_id = T1.customer_id AND
      T3.film_id = T2.film_id
  )
)
INSERT INTO #actor_recommendations 
								  (
								   customer_id,
								   first_name,
								   last_name,
								   rental_count,
								   title,
								   film_id,
								   actor_id,
								   reco_rank
								  )
SELECT * FROM ranked_actor_films_cte
WHERE reco_rank <= 3;



--Final Transformation
DROP TABLE IF EXISTS #final_data_asset;
CREATE TABLE #final_data_asset 
							 (
							  customer_id INT,
							  cat_1 VARCHAR(50),
							  cat_1_reco_1 VARCHAR(50),
							  cat_1_reco_2 VARCHAR(50),
							  cat_1_reco_3 VARCHAR(50),
							  cat_2 VARCHAR(50),
							  cat_2_reco_1 VARCHAR(50),
							  cat_2_reco_2 VARCHAR(50),
							  cat_2_reco_3 VARCHAR(50),
							  actor VARCHAR(50),
							  actor_reco_1 VARCHAR(50),
							  actor_reco_2 VARCHAR(50),
							  actor_reco_3 VARCHAR(50),
							  insights_cat_1 VARCHAR(MAX),
							  insights_cat_2 VARCHAR(MAX),
							  insights_actor VARCHAR(MAX)
							 );
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
FROM #top_category_insights
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
FROM #second_category_insights
),
top_actor AS (
SELECT 
	customer_id,
	actor_name,
	CONCAT(
		'You''ve watched ', rental_count, ' films featuring ',
		actor_name,
		'! Here are some other films ', 
		LEFT(actor_name, CHARINDEX(' ', actor_name, 0)),
		' stars in that might interest you!'
	) AS [insight]
FROM
(
SELECT 
	customer_id,
	rental_count,
	CONCAT(
		UPPER(LEFT(first_name, 1)), LOWER(RIGHT(first_name, LEN(first_name)-1)),
		' ',
		UPPER(LEFT(last_name, 1)), LOWER(RIGHT(last_name, LEN(last_name)-1))
		) AS [actor_name]
FROM top_actor_counts
) AS V0
),
adjusted_title_case_category_recommendations AS (
SELECT 
	customer_id,
	STRING_AGG(
		CONCAT(
			UPPER(LEFT(word, 1)), 
			'', 
			LOWER(RIGHT(word, LEN(word)-1))), 
			' ') AS [title],
	category_rank,
	reco_rank
FROM
(
SELECT 
	customer_id,
	title,
	value AS [word],
	category_rank,
	reco_rank
FROM category_recommendations AS T1
CROSS APPLY string_split(title, ' ') AS [split_test]
) AS V1
GROUP BY 
	customer_id,
	category_rank,
	reco_rank
),
wide_category_recommendations AS (
SELECT 
	customer_id,
	MAX(
		CASE WHEN category_rank = 1 AND reco_rank = 1
		THEN title 
		END
	) AS cat_1_reco_1,
	MAX(
		CASE WHEN category_rank = 1 AND reco_rank = 2
		THEN title 
		END
	) AS cat_1_reco_2,
	MAX(
		CASE WHEN category_rank = 1 AND reco_rank = 3
		THEN title 
		END
	) AS cat_1_reco_3,
	MAX(
		CASE WHEN category_rank = 2 AND reco_rank = 1
		THEN title 
		END
	) AS cat_2_reco_1,
	MAX(
		CASE WHEN category_rank = 2 AND reco_rank = 2
		THEN title 
		END
	) AS cat_2_reco_2,
	MAX(
		CASE WHEN category_rank = 2 AND reco_rank = 3
		THEN title 
		END
	) AS cat_2_reco_3
FROM adjusted_title_case_category_recommendations
GROUP BY 
	customer_id
),
adjusted_title_case_actor_recommendations AS (
SELECT 
	customer_id,
	STRING_AGG(
	CONCAT(
		UPPER(LEFT(word, 1)), 
		'', 
		LOWER(RIGHT(word, LEN(word)-1))), 
		' ') AS [title],
	reco_rank
FROM
(
SELECT 
	customer_id,
	title,
	value AS [word],
	reco_rank
FROM actor_recommendations
CROSS APPLY STRING_SPLIT(title, ' ')
) AS V2
GROUP BY 
	customer_id,
	reco_rank
),
wide_actor_recommendations AS (
SELECT 
	customer_id,
	MAX(CASE WHEN reco_rank = 1 THEN title END) AS [actor_reco_1],
	MAX(CASE WHEN reco_rank = 2 THEN title END) AS [actor_reco_2],
	MAX(CASE WHEN reco_rank = 3 THEN title END) AS [actor_reco_3]
FROM adjusted_title_case_actor_recommendations
GROUP BY 
	customer_id
),
final_output AS (
SELECT 
	T1.customer_id,
	T1.category_name AS [cat_1],
	T4.cat_1_reco_1,
	T4.cat_1_reco_2,
	T4.cat_1_reco_3,
	T2.category_name AS [cat_2],
	T4.cat_2_reco_1,
	T4.cat_2_reco_2,
	T4.cat_2_reco_3,
	T3.actor_name AS [Actor],
	T5.actor_reco_1,
	T5.actor_reco_2,
	T5.actor_reco_3,
	T1.insight AS [insight_cat_1],
	T2.insight AS [insight_cat_2],
	T3.insight AS [insight_actor]
FROM first_category [T1]
INNER JOIN second_category [T2]
	ON T1.customer_id = T2.customer_id
INNER JOIN top_actor [T3]
	ON T1.customer_id = T3.customer_id
INNER JOIN wide_category_recommendations [T4]
	ON T1.customer_id = T4.customer_id
INNER JOIN wide_actor_recommendations [T5]
	ON T1.customer_id = T5.customer_id
)
INSERT INTO #final_data_asset
							 (
							  customer_id,
							  cat_1,
							  cat_1_reco_1,
							  cat_1_reco_2,
							  cat_1_reco_3,
							  cat_2,
							  cat_2_reco_1,
							  cat_2_reco_2,
							  cat_2_reco_3,
							  actor,
							  actor_reco_1,
							  actor_reco_2,
							  actor_reco_3,
							  insights_cat_1,
							  insights_cat_2,
							  insights_actor
							)
SELECT *
FROM final_output;


SELECT TOP 5 
	customer_id,
	insights_actor
FROM #final_data_asset
ORDER BY customer_id ASC;