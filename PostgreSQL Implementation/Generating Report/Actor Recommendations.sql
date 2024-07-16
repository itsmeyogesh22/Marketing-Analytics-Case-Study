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
    DENSE_RANK() OVER (
      PARTITION BY
        top_actor_counts.customer_id
      ORDER BY
        actor_film_counts.rental_count DESC,
        actor_film_counts.title
    ) AS reco_rank
  FROM top_actor_counts
  INNER JOIN actor_film_counts
    ON top_actor_counts.actor_id = actor_film_counts.actor_id
  WHERE NOT EXISTS (
    SELECT 1
    FROM actor_film_exclusions
    WHERE
      actor_film_exclusions.customer_id = top_actor_counts.customer_id AND
      actor_film_exclusions.film_id = actor_film_counts.film_id
  )
)
SELECT * FROM ranked_actor_films_cte
WHERE reco_rank <= 3;