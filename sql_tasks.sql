-- Output the number of movies in each category,
-- sorted descending.

SELECT c.name, 
	COUNT(fc.film_id) as movies_number
FROM category c
	JOIN film_category fc
	ON c.category_id = fc.category_id
GROUP BY c.name
ORDER BY COUNT(fc.film_id) DESC;

-- Output the 10 actors whose movies rented the most, 
-- sorted in descending order.

SELECT
	a.first_name, 
	a.last_name,
	COUNT(r.rental_id) AS rental_count
FROM actor a
	JOIN film_actor fa ON a.actor_id = fa.actor_id
	JOIN inventory i ON i.film_id = fa.film_id
	JOIN rental r ON i.inventory_id = r.inventory_id
GROUP BY
	a.actor_id, a.first_name, a.last_name
ORDER BY
	COUNT(r.rental_id) DESC
LIMIT 10;
	
-- Output the category of movies on which the most money was spent.
WITH total_amount_category AS (
SELECT 
	DISTINCT c.name, 
	SUM(p.amount) as total_amount,
	DENSE_RANK() OVER(ORDER BY SUM(p.amount) DESC) as rank_amount
FROM public.payment p
	JOIN public.rental r ON r.rental_id = p.rental_id
	JOIN public.inventory i ON i.inventory_id = r.inventory_id
	JOIN public.film_category fc ON fc.film_id = i.film_id
	JOIN public.category c ON c.category_id = fc.category_id
GROUP BY c.name
)
SELECT name, total_amount
FROM total_amount_category
WHERE rank_amount = 1;

-- Print the names of movies that are not in the inventory. 
-- Write a query without using the IN operator.

SELECT f.title
FROM public.film f
	LEFT JOIN public.inventory i ON f.film_id = i.film_id
WHERE i.inventory_id IS NULL;

-- Output the top 3 actors who have appeared the most in movies 
-- in the “Children” category. 
-- If several actors have the same number of movies, output all of them.

WITH actor_category AS (
SELECT
	a.actor_id,
	a.first_name,
	a.last_name,
	COUNT(fa.film_id) as film_count,
	DENSE_RANK() OVER(ORDER BY COUNT(fa.film_id) DESC) as count_rank
FROM public.actor a
	JOIN public.film_actor fa ON fa.actor_id = a.actor_id
	JOIN public.film_category fc ON fa.film_id = fc.film_id
	JOIN public.category c ON c.category_id = fc.category_id
WHERE c.name = 'Children'
GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT first_name,
	last_name,
	film_count
FROM actor_category
WHERE count_rank < 4
ORDER BY film_count DESC;

-- Output cities with the number of active and inactive customers 
-- (active - customer.active = 1). 
-- Sort by the number of inactive customers in descending order.

SELECT
	c.city,
	SUM(CASE WHEN cst.active = 1 THEN 1 ELSE 0 END) as count_active,
	SUM(CASE WHEN cst.active = 0 THEN 1 ELSE 0 END) as count_inactive
FROM public.city c
	JOIN public.address a ON c.city_id = a.city_id
	JOIN public.customer cst ON cst.address_id = a.address_id
GROUP BY c.city
ORDER BY SUM(CASE WHEN cst.active = 0 THEN 1 ELSE 0 END) DESC;

-- Output the category of movies that have the highest number 
-- of total rental hours in the city (customer.address_id in this city) 
-- and that start with the letter “a”. Do the same for cities that 
-- have a “-” in them. Write everything in one query.

WITH base_data AS (
    SELECT 
        ctg.name AS category_name,
        c.city,
        SUM(EXTRACT(EPOCH FROM (r.return_date - r.rental_date)) / 3600) AS rental_time_hours
    FROM public.category AS ctg
    JOIN public.film_category AS fc ON fc.category_id = ctg.category_id
    JOIN public.inventory AS i ON i.film_id = fc.film_id
    JOIN public.rental AS r ON r.inventory_id = i.inventory_id
    JOIN public.customer AS cst ON cst.customer_id = r.customer_id
    JOIN public.address AS a ON a.address_id = cst.address_id
    JOIN public.city AS c ON c.city_id = a.city_id
    WHERE LOWER(c.city) LIKE 'a%' 
		AND c.city LIKE '%-%'
		AND r.return_date IS NOT NULL
      	AND r.rental_date IS NOT NULL
    GROUP BY ctg.name, c.city
),
case1 AS (
    SELECT 
        category_name,
        city,
        'case1' AS city_group,
        rental_time_hours,
        DENSE_RANK() OVER (PARTITION BY city ORDER BY rental_time_hours DESC) AS rk
    FROM base_data
    WHERE LOWER(city) LIKE 'a%'
),
case2 AS (
    SELECT 
        category_name,
        city,
        'case2' AS city_group,
        rental_time_hours,
        DENSE_RANK() OVER (PARTITION BY city ORDER BY rental_time_hours DESC) AS rk
    FROM base_data
    WHERE city LIKE '%-%'
)
SELECT 
    city,
    category_name,
    city_group
FROM (
    SELECT * FROM case1 WHERE rk = 1
    UNION ALL
    SELECT * FROM case2 WHERE rk = 1
) AS final
ORDER BY city_group;
