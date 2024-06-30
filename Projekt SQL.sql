 CREATE TABLE t_NgocKhanhVy_Tranova_project_SQL_primary_final (
	year INT,
	industry_branch_id CHAR(1),
	industry_branch VARCHAR(255),
	avg_payroll INT,
	food_category VARCHAR(255),
	food_price INT
);
-- Temporary tabulka na mzdy

CREATE TEMPORARY TABLE temp_payroll AS
SELECT 
    cpay.payroll_year AS year,
    cpay.industry_branch_code AS industry_branch_id,
    cpib.name AS industry_branch,
    AVG(cpay.value) AS avg_payroll
FROM czechia_payroll cpay
JOIN czechia_payroll_industry_branch cpib 
    ON cpay.industry_branch_code = cpib.code
JOIN czechia_payroll_value_type cpvt 
    ON cpay.value_type_code = cpvt.code
JOIN czechia_payroll_calculation cpcal 
    ON cpay.calculation_code = cpcal.code
WHERE 
    cpay.value_type_code = 5958 AND cpay.calculation_code = 200
GROUP BY 
    cpay.payroll_year, cpay.industry_branch_code, cpib.name;


-- Temporary tabulka na ceny potravin
   
CREATE TEMPORARY TABLE temp_food AS
SELECT 
    YEAR(cp.date_from) AS year,
    cpc.name AS food_category,
    AVG(cp.value) AS food_price
FROM czechia_price cp 
JOIN czechia_price_category cpc 
    ON cp.category_code = cpc.code
GROUP BY 
    YEAR(cp.date_from), cpc.name;

-- Sjednocení temporary tabulek do hlavních tabulek

INSERT INTO t_NgocKhanhVy_Tranova_project_SQL_primary_final (year, industry_branch_id, industry_branch, avg_payroll, food_category, food_price)
SELECT 
    tp.year,
    tp.industry_branch_id,
    tp.industry_branch,
    tp.avg_payroll,
    tf.food_category,
    tf.food_price
FROM temp_payroll tp
LEFT JOIN temp_food tf 
    ON tp.year = tf.year
UNION 
SELECT 
    tf.year,
    tp.industry_branch_id,
    tp.industry_branch,
    tp.avg_payroll,
    tf.food_category,
    tf.food_price
FROM temp_food tf
LEFT JOIN temp_payroll tp
    ON tf.year = tp.year;


/*
 * SQL dotazy pro odpovědi na výzkumné otázky
 */
 
-- 1. Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
SELECT
	`year` ,
	industry_branch_id,
	industry_branch,
	avg_payroll
FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
-- WHERE industry_branch_id = 'A'
GROUP BY industry_branch_id , `year` 
ORDER BY industry_branch_id , `year`;


-- 2. Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?

SELECT 
	MIN(`year`) AS first_year, -- 2006
	MAX(`year`) AS last_year -- 2018
FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
WHERE avg_payroll IS NOT NULL AND food_price IS NOT NULL;

SELECT 
	(SELECT AVG(avg_payroll)
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	WHERE `year` = 2006)/
	(SELECT AVG(food_price) 
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	WHERE food_category = 'Mléko polotučné pasterované' AND `year` = 2006)
-- Za průměrnou mzdu v roce 2006 je možné koupit 1511.80827068 litrů mléka

SELECT 
	(SELECT AVG(avg_payroll)
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	WHERE `year` = 2018)/
	(SELECT AVG(food_price) 
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	WHERE food_category = 'Mléko polotučné pasterované' AND `year` = 2018)
-- Za průměrnou mzdu v roce 2018 je možné koupit 1654.58157895 litrů mléka

	SELECT 
	(SELECT AVG(avg_payroll)
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t 
	WHERE `year` = 2006)/
	(SELECT AVG(food_price) 
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	WHERE food_category = 'Chléb konzumní kmínový' AND `year` = 2006)

-- Za průměrnou mzdu v roce 2006 je možné koupit 1322.83223684 kg chleba

SELECT 
	(SELECT AVG(avg_payroll)
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	WHERE `year` = 2018)/
	(SELECT AVG(food_price) 
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	WHERE food_category = 'Chléb konzumní kmínový' AND `year` = 2018)
-- Za průměrnou mzdu v roce 2018 je možné koupit 1378.81798246 kg chleba

-- 3. Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
CREATE TEMPORARY TABLE temp_avg_price AS
SELECT
	year,
	food_category,
	AVG(food_price) AS avg_price
FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
WHERE food_category IS NOT NULL
GROUP BY food_category, year;

CREATE TEMPORARY TABLE temp_yearly_changes AS
SELECT
    cur.year,
    cur.food_category,
    cur.avg_price,
    prev.avg_price AS prev_avg_price,
    ((cur.avg_price - prev.avg_price) / prev.avg_price) * 100 AS yearly_change
FROM temp_avg_price cur
JOIN temp_avg_price prev
    ON cur.food_category = prev.food_category AND cur.year = prev.year + 1;
	
SELECT
 	food_category,
 	AVG(yearly_change) AS avg_yearly_increase
FROM temp_yearly_changes 
GROUP BY food_category
ORDER BY avg_yearly_increase ASC
LIMIT 1; -- Cukr krystalový

-- 4. Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

CREATE TEMPORARY TABLE temp_payroll_changes AS
SELECT
	cur.year,
	((cur.avg_payroll - prev.avg_payroll)/prev.avg_payroll) * 100 AS payroll_change
FROM (
	SELECT 
		year,
		AVG(avg_payroll) AS avg_payroll
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	GROUP BY year) cur
JOIN (
	SELECT 
		year,
		AVG(avg_payroll) AS avg_payroll
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	GROUP BY year) prev
	ON cur.year = prev.year + 1

CREATE TEMPORARY TABLE temp_price_changes AS
SELECT
	cur.year,
	((cur.avg_price - prev.avg_price)/prev.avg_price) * 100 AS price_change
FROM (
	SELECT 
		year,
		AVG(food_price) AS avg_price
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	GROUP BY year) cur
JOIN (
	SELECT 
		year,
		AVG(food_price) AS avg_price
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	GROUP BY year) prev
	ON cur.year = prev.year + 1

SELECT 
	pr.year,
	pr.price_change,
	pay.payroll_change
FROM temp_price_changes pr
JOIN temp_payroll_changes pay
	ON pr.year = pay.year
WHERE pr.price_change - pay.payroll_change > 10 -- NE


-- 5. Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?

SELECT *
FROM economies e 
WHERE country = 'Czech republic';

ALTER TABLE t_NgocKhanhVy_Tranova_project_SQL_primary_final  
ADD COLUMN gdp DOUBLE;

-- ALTER TABLE t_NgocKhanhVy_Tranova_project_SQL_primary_final DROP COLUMN gdp; 

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2000 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2001 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2002 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP  
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2003;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2004 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2005;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2006 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2007 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2008 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2009;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2010;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2011 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2012 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2013 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2014 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2015 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2016 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2017 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2018;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2019 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2020 ;

UPDATE t_NgocKhanhVy_Tranova_project_SQL_primary_final t
JOIN economies e	
	ON t.`year` = e.`year` 
SET t.gdp = e.GDP 
WHERE e.country = 'Czech republic' AND e.GDP IS NOT NULL AND t.`year` = 2021 ;

CREATE TEMPORARY TABLE temp_gdp_changes AS
SELECT 
	cur.year,
	((cur.gdp - prev.gdp) / prev.gdp) * 100 AS gdp_change
FROM (
	SELECT
		year,
		AVG(gdp) AS gdp
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	GROUP BY year) cur 
JOIN (
	SELECT
		year,
		AVG(gdp) AS gdp
	FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final t
	GROUP BY year) prev
	ON cur.year = prev.year + 1;

SELECT 
	gdp.year,
	gdp.gdp_change,
	pay.payroll_change,
	pr.price_change
FROM temp_gdp_changes gdp
JOIN temp_payroll_changes pay 
	ON gdp.year = pay.year
JOIN temp_price_changes pr
	ON gdp.year = pr.year
ORDER BY gdp.year;


-- Jako dodatečný materiál připravte i tabulku s HDP, GINI koeficientem a populací dalších evropských států ve stejném období, jako primární přehled pro ČR.

CREATE TABLE t_NgocKhanhVy_Tranova_project_SQL_secondary_final (
	country VARCHAR(255),
	year INT,
	gdp DOUBLE,
	gini DOUBLE,
	population DOUBLE
)

CREATE TEMPORARY TABLE temp_eu_countries AS
SELECT
	country
FROM countries c 
WHERE c.region_in_world LIKE '%Europe%'

INSERT INTO t_NgocKhanhVy_Tranova_project_SQL_secondary_final (country, year, gdp, gini, population)
SELECT
	e.country,
	e.`year` ,
	e.GDP ,
	e.gini ,
	e.population 
FROM economies e
JOIN temp_eu_countries eu
	ON e.country = eu.country
WHERE e.`year` BETWEEN (SELECT MIN(year) FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final) AND (SELECT MAX(year) FROM t_NgocKhanhVy_Tranova_project_SQL_primary_final); ;
	






