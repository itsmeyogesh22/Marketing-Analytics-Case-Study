USE dvd_rentals;

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