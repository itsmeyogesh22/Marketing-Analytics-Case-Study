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