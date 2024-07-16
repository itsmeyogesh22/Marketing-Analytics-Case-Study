USE dvd_rentals;


--Part-A: Inspecting Foreign Keys 
/*
	Hypothesis-1: The number of unique inventory_id records will be equal in both 
	dvd_rentals.rental and dvd_rentals.inventory tables.
*/
SELECT 
	('rental') AS table_name,
	COUNT (DISTINCT inventory_id) AS inventory_count
FROM rental
UNION
SELECT 
	('inventory') AS table_name,
	COUNT (DISTINCT inventory_id) AS inventory_count
FROM inventory;

--Conclusion: No, as there is one extra inventory_id in Table- dvd_rentals.inventory


/*
	Hypothesis-2: There will be a multiple records per unique inventory_id in the 
	dvd_rentals.rental table.
*/
WITH count_base AS (
SELECT 
	inventory_id AS target_value_column,
	COUNT(*) AS record_count
FROM rental
GROUP BY inventory_id
)
SELECT 
	record_count,
	COUNT(target_value_column) AS count_of_target_value
FROM count_base
GROUP BY 
	record_count
ORDER BY 
	record_count ASC;

--Conclusion: Yes, there are multiple records per unique inventory_id in dvd_rentals.rental table.


/*
	Hypothesis-3: There will be multiple inventory_id records per unique film_id value in the 
	dvd_rentals.inventory table.
*/
WITH base_count AS (
SELECT 
	film_id AS target_value_column,
	COUNT(DISTINCT inventory_id) AS record_count
FROM inventory
GROUP BY 
	film_id
)
SELECT 
	record_count,
	COUNT(target_value_column) AS count_of_target_value
FROM base_count
GROUP BY 
	record_count
ORDER BY 
	record_count;

--Conclusion: Yes, there are indeed multiple unique inventory_id per film_id value in the dvd_rentals.inventory table.


--Part-B: Joining TABLE
--Part-B-1
--Table Joining Checklist:
/*
	1. What is the purpose of joining these two tables?
	   Purpose: We want to match the films on film_id to obtain the title of each film.

	   a. What contextual hypotheses do we have about the data?
		  Part-1: There might be 1-to-many relationship for film_id and the rows of the 
		  dvd_rentals.inventory table as one specific film might have multiple copies to be purchased 
		  at the rental store.
		  Part-2: There should be 1-to-1 relationship for film_id and the rows of the dvd_rentals.
		  film table as it doesn’t make sense for there to be duplicates in this dvd_rentals.film.

		b. How can we validate these assumptions?
		Generate the row counts for film_id for both the dvd_rentals.inventory and dvd_rentals.film tables.
*/

--Table- dvd_rentals.inventory 
WITH base_count AS (
SELECT 
	film_id AS target_value_column,
	COUNT(DISTINCT inventory_id) AS record_count
FROM inventory
GROUP BY film_id
)
SELECT record_count, 
COUNT(DISTINCT target_value_column) AS unique_film_id_values
FROM base_count
GROUP BY 
	record_count
ORDER BY 
	record_count ASC;

--Table- dvd_rentals.film
WITH base_count AS (
SELECT 
	film_id AS target_value_columns,
	COUNT(*) AS record_count
FROM film
GROUP BY film_id
)
SELECT 
	record_count,
	COUNT(target_value_columns) AS unique_film_id_values
FROM base_count
GROUP BY 
	record_count
ORDER BY 
	record_count ASC;

--2. What is the distribution of foreign keys within each table?
WITH base_count2 AS (
SELECT 
	film_id AS target_value_column,
	COUNT(inventory_id) AS record_count
FROM inventory
GROUP BY film_id
)
SELECT 
	record_count,
	COUNT(DISTINCT target_value_column) AS count_of_foreign_key
FROM base_count2
GROUP BY 
	record_count
ORDER BY 
	record_count ASC; 

--Conclusion: There are no foreign keys within dvd_rentals.film table.


--3. How many unique foreign key values exist in each table?
SELECT 
	COUNT(DISTINCT T1.film_id) AS unique_keys
FROM inventory AS T1
WHERE NOT EXISTS
	(
	SELECT 
		T2.film_id
	FROM film AS T2
	WHERE T1.film_id = T2.film_id
	);

SELECT 
	COUNT(DISTINCT T1.film_id) AS unique_keys
FROM film AS T1
WHERE NOT EXISTS
	(
	SELECT 
		T2.film_id
	FROM inventory AS T2
	WHERE T1.film_id = T2.film_id
	);

--4. How many overlapping and missing unique foreign key values are there between the two tables?
SELECT 
	COUNT(DISTINCT T1.film_id) AS unique_keys
FROM inventory AS T1
WHERE EXISTS
	(
	SELECT 
		T2.film_id
	FROM film AS T2
	WHERE T1.film_id = T2.film_id
	);
--Conclusion: 958 total intersecting values.



--Part-B-2
--Table Joining Checklist:
/*
	1. What is the purpose of joining these two tables?
	   Purpose: We want to match film_category on film_id to obtain category of each title.

	   a. What contextual hypotheses do we have about the data?
		  Part-1: There might be 1-to-many relationship for category_id and the rows of the 
		  dvd_rentals.film_category table as there might be multiple films that belong to the
		  same film category or genre.
		  Part-2: There should be 1-to-1 relationship for category_id and the rows of the 
		  dvd_rentals.category, i.e a single category_id mapped to single category name.

		b. How can we validate these assumptions?
		Generate the row counts for film_id for both the dvd_rentals.film_category and dvd_rentals.category tables
*/
--Table- dvd_rentals.film_category 
WITH base_count AS (
SELECT 
	category_id AS target_value_column,
	COUNT(*) AS record_count
FROM film_category
GROUP BY 
	category_id
)
SELECT 
	record_count,
	COUNT(DISTINCT target_value_column) AS count_of_target_value
FROM base_count
GROUP BY record_count;

--Table- dvd_rentals.category 
WITH base_count AS (
SELECT 
	category_id AS target_value_column,
	COUNT(*) AS record_count
FROM category
GROUP BY 
	category_id
)
SELECT 
	record_count,
	COUNT(DISTINCT target_value_column) AS count_of_target_value
FROM base_count
GROUP BY 
	record_count;


--2. What is the distribution of foreign keys within each table?
WITH base_count AS (
SELECT 
	category_id AS target_value_column,
	COUNT(DISTINCT film_id) AS record_count
FROM film_category
GROUP BY 
	category_id
)
SELECT 
	record_count,
	COUNT(DISTINCT target_value_column) AS count_of_foreign_key
FROM base_count
GROUP BY record_count;

--Conclusion: There are no foreign keys in dvd_rentals.category table.


--3. How many unique foreign key values exist in each table?
SELECT 
	COUNT(DISTINCT category_id) AS unique_keys
FROM film_category AS T1
WHERE NOT EXISTS 
	(
	SELECT T2.category_id
	FROM category AS T2
	WHERE T1.category_id = T2.category_id
	);

SELECT 
	COUNT(DISTINCT category_id) AS unique_keys
FROM category AS T1
WHERE NOT EXISTS 
	(
	SELECT T2.category_id
	FROM film_category AS T2
	WHERE T1.category_id = T2.category_id
	);


--4. How many overlapping and missing unique foreign key values are there between the two tables?
SELECT 
	COUNT(DISTINCT category_id) AS unique_keys
FROM film_category AS T1
WHERE EXISTS 
	(
	SELECT T2.category_id
	FROM category AS T2
	WHERE T1.category_id = T2.category_id
	);

--Conclusion: 16 total intersecting values.


