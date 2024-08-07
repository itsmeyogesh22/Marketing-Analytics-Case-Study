USE dvd_rentals;

--1) Which film title was the most recommended for all customers?
SELECT TOP 1
	title,
	COUNT(*) AS [total_users]
FROM
(
SELECT 
	title
FROM category_recommendations
UNION ALL
SELECT 
	title
FROM actor_recommendations
) AS C1
GROUP BY title
ORDER BY 2 DESC;


--2) How many customers were included in the email campaign?
SELECT 
	COUNT(DISTINCT customer_id) AS user_count
FROM #final_data_asset;


--3) Out of all the possible films - what percentage coverage do we have in our recommendations?
SELECT 
	CAST((COUNT(*)*100/CAST((SELECT COUNT(film_id) FROM film) AS NUMERIC)) AS NUMERIC) AS total_films
FROM
(
SELECT 
	title
FROM #category_recommendations
UNION 
SELECT 
	title
FROM #actor_recommendations
) AS C1;


--4) What is the most popular top category?
SELECT TOP 1
	category_name,
	COUNT(DISTINCT customer_id) AS [total_users]
FROM first_category_insights
GROUP BY category_name
ORDER BY 2 DESC;



--5) What is the 4th most popular top category?
WITH category_rnk AS (
SELECT 
	category_name,
	COUNT(DISTINCT customer_id) AS total_users,
	RANK() 
		OVER (
			ORDER BY COUNT(DISTINCT customer_id) DESC
		) AS category_rank
FROM #top_category_insights
GROUP BY category_name
)
SELECT category_name
FROM category_rnk
WHERE category_rank = 4;


--6) What is the average percentile ranking for each customer in their top category rounded to the nearest 2 decimal places?
SELECT 
	CAST(AVG(CAST(percentile AS NUMERIC)) AS DECIMAL(5, 2)) AS average_percentile
FROM #top_category_insights;


--7) What is the cumulative distribution of the top 5 percentile values for the top category from the first_category_insights table 
--rounded to the nearest round percentage?
SELECT TOP 5
	percentile,
	COUNT(*) AS [count],
	CAST(100 * CUME_DIST() 
					OVER (
						   ORDER BY CAST(percentile AS NUMERIC)) 
					AS NUMERIC) AS cumulative_distribution 
FROM #top_category_insights
GROUP BY percentile
ORDER BY 1;


--8) What is the median of the second category percentage of entire viewing history?
SELECT DISTINCT
	PERCENTILE_CONT(0.5)
		WITHIN GROUP (
			ORDER BY total_percentage ASC
		) OVER () AS median_value
FROM #second_category_insights;


--9) What is the 80th percentile of films watched featuring each customer's favourite actor?
SELECT DISTINCT 
	PERCENTILE_CONT(0.8)
		WITHIN GROUP (
			ORDER BY rental_count ASC
		) OVER () AS [80th_percentile]
FROM #top_actor_counts;


--10) What was the average number of films watched by each customer rounded to the nearest whole number?
SELECT 
	CAST(AVG(CAST(total_rental_count AS NUMERIC)) AS NUMERIC) AS average_count_films_watched
FROM #total_counts;


--11) What is the top combination of top 2 categories and how many customers if the order is relevant 
--(e.g. Horror and Drama is a different combination to Drama and Horror)
SELECT TOP 1
	cat_combo,
	COUNT(*) AS user_count
FROM
(
SELECT 
	CONCAT(cat_1, ' and ', cat_2) AS cat_combo,
	customer_id
FROM #final_data_asset
) AS cat_order
GROUP BY cat_combo
ORDER BY 2 DESC;


--12) Which actor was the most popular for all customers?
SELECT TOP 1
	actor_name,
	SUM(rental_count) AS [total_rental_count]
FROM
(
SELECT 
	CONCAT(
			UPPER(LEFT(first_name, 1)), 
			LOWER(RIGHT(first_name, LEN(first_name)-1)), 
			' ', 
			UPPER(LEFT(last_name, 1)), 
			LOWER(RIGHT(last_name, LEN(last_name)-1))) AS [actor_name],
	rental_count
FROM #top_actor_counts
) AS [popular_actor]
GROUP BY actor_name
ORDER BY 2 DESC;


--13) How many films on average had customers already seen that feature their favourite actor rounded to closest integer?
SELECT 
	CAST(AVG(CAST(rental_count AS NUMERIC)) AS NUMERIC) AS average_rental_count
FROM #top_actor_counts;


/*
14) CHALLENGE: What is the most common top categories combination if order was irrelevant and how many customers have this combination? 
(e.g. Horror and Drama is a the same as Drama and Horror)
*/
WITH cat_combo_1 AS (
SELECT 
	cat_1,
	cat_2,
	COUNT(*) AS total_viewer_count
FROM #final_data_asset
GROUP BY cat_1, cat_2
)
SELECT TOP 1
	CONCAT(T1.cat_1, ' and ', T1.cat_2, ' | ', T2.cat_1, ' and ', T2.cat_2) AS joint_combo, 
	T1.total_viewer_count + T2.total_viewer_count AS final_count
FROM cat_combo_1 AS T1
INNER JOIN cat_combo_1 AS T2
	ON T1.cat_1 = T2.cat_2
	AND T1.cat_2 = T2.cat_1
ORDER BY final_count DESC;