USE dvd_rentals;

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