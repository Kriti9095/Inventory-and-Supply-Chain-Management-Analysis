CREATE DATABASE inventory_db;
USE inventory_db;
CREATE TABLE fact_inventory (
    inv_id INT AUTO_INCREMENT PRIMARY KEY,
    date_id DATE,
    region VARCHAR(50),
    category VARCHAR(50),
    supplier VARCHAR(50),
    warehouse VARCHAR(50),
    order_status VARCHAR(50),
    units_sold INT,
    inventory_level INT,
    transportation_cost FLOAT,
    order_accuracy BOOLEAN,
    lead_time INT,
    backorder BOOLEAN,
    cost_of_goods FLOAT,
    average_inventory FLOAT,
    warehouse_capacity INT
);

SET GLOBAL local_infile = 1;

SHOW GLOBAL VARIABLES LIKE 'local_infile';
SELECT COUNT(*) FROM fact_inventory;
SELECT date_id FROM fact_inventory LIMIT 10;

USE inventory_db;

-- KPI

SELECT
    ROUND(SUM(inventory_level) * 100.0 / SUM(warehouse_capacity), 2) AS warehouse_utilization_pct,
    ROUND(SUM(cost_of_goods) / SUM(average_inventory), 2) AS inventory_turnover_ratio,
    ROUND(365*SUM(average_inventory) / SUM(cost_of_goods), 2) AS days_sales_of_inventory,
    ROUND(AVG(lead_time), 2) AS avg_lead_time_days
FROM fact_inventory;


-- Order status 

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM fact_inventory
GROUP BY order_status
ORDER BY orders DESC;


-- Costliest region + category for transportation

SELECT
    region,
    category,
    ROUND(SUM(transportation_cost), 0) AS total_transport_cost
FROM fact_inventory
GROUP BY region, category
ORDER BY total_transport_cost DESC
LIMIT 5;


-- Warehouse utilization by warehouse

SELECT
    warehouse,
    ROUND(SUM(inventory_level) * 100.0 / SUM(warehouse_capacity), 2) AS utilization_pct,
    ROUND(100 - SUM(inventory_level) * 100.0 / SUM(warehouse_capacity), 2) AS idle_capacity_pct
FROM fact_inventory
GROUP BY warehouse
ORDER BY utilization_pct;


-- best-selling category in each region

WITH category_sales AS (
    SELECT
        region,
        category,
        SUM(units_sold) AS units,
        RANK() OVER (PARTITION BY region ORDER BY SUM(units_sold) DESC) AS rnk
    FROM fact_inventory
    GROUP BY region, category
)
SELECT region, category, units
FROM category_sales
WHERE rnk = 1
ORDER BY region;


-- Which region and category are slower than their own region's average?

WITH region_category AS (
    SELECT region, category, ROUND(AVG(lead_time), 2) AS avg_lead_time
    FROM fact_inventory
    GROUP BY region, category
),
region_avg AS (
    SELECT region, ROUND(AVG(lead_time), 2) AS region_avg_lead_time
    FROM fact_inventory
    GROUP BY region
)
SELECT
    rc.region,
    rc.category,
    rc.avg_lead_time,
    ra.region_avg_lead_time,
    ROUND(rc.avg_lead_time - ra.region_avg_lead_time, 2) AS days_slower
FROM region_category rc
JOIN region_avg ra ON rc.region = ra.region
ORDER BY days_slower DESC
LIMIT 5;


-- Where are pending and canceled orders concentrated?

SELECT
    region,
    COUNT(*) AS orders,
    SUM(CASE WHEN order_status = 'Pending' THEN 1 ELSE 0 END) AS pending_orders,
    SUM(CASE WHEN order_status = 'Canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND(SUM(CASE WHEN order_status = 'Canceled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS cancel_pct
FROM fact_inventory
GROUP BY region
ORDER BY cancel_pct DESC;



