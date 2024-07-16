SELECT * FROM CURRENT_CATALOG;

DROP TABLE IF EXISTS inventory;
CREATE TABLE inventory
	(
	inventory_id INT,
	film_id INT,
	store_id INT,
	last_update TIMESTAMP
	);

DROP TABLE IF EXISTS rental;
CREATE TABLE rental 
	(
	rental_id INT,
	rental_date TIMESTAMP,
	inventory_id INT,
	customer_id INT,
	return_date TIMESTAMP,
	staff_id INT,
	last_update TIMESTAMP
	);

DROP TABLE IF EXISTS film;
CREATE TABLE film 
	(
	film_id INT NOT NULL,
	title CHARACTER VARYING(255) NOT NULL,
	description TEXT,
	release_year TEXT,
	language_id SMALLINT NOT NULL,
	original_language_id SMALLINT,
	rental_duration SMALLINT NOT NULL,
	rental_rate NUMERIC(4, 2) NOT NULL,
	length SMALLINT,
	replacement_cost NUMERIC(5, 2),
	rating CHARACTER VARYING(5),
	last_update TIMESTAMP NOT NULL,
	special_feature TEXT,
	fulltext TSVECTOR NOT NULL
	);

DROP TABLE IF EXISTS film_category;
CREATE TABLE film_category 
	(
	film_id INT NOT NULL,
	category_id INT NOT NULL,
	last_update TIMESTAMP NOT NULL
	);

DROP TABLE IF EXISTS category;
CREATE TABLE category 
	(
	category_id INT NOT NULL,
	name CHARACTER VARYING(25) NOT NULL,
	last_update TIMESTAMP NOT NULL
	);

DROP TABLE IF EXISTS film_actor;
CREATE TABLE film_actor 
	(
	actor_id INT NOT NULL,
	film_id INT NOT NULL,
	last_update TIMESTAMP NOT NULL
	);

DROP TABLE IF EXISTS actor;
CREATE TABLE actor 
	(
	actor_id INT NOT NULL,
	first_name VARCHAR(45) NOT NULL,
	last_name VARCHAR(45) NOT NULL,
	last_update TIMESTAMP NOT NULL
	);