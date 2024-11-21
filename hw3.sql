CREATE TABLE IF NOT EXISTS employees (
    employee_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    position VARCHAR(50) NOT NULL,
    department VARCHAR(50) NOT NULL,
    salary NUMERIC(10, 2) NOT NULL,
    manager_id INT REFERENCES employees(employee_id)
);

INSERT INTO employees (name, position, department, salary, manager_id)
VALUES
    ('Alice Johnson', 'Manager', 'Sales', 85000, NULL),
    ('Bob Smith', 'Sales Associate', 'Sales', 50000, 1),
    ('Carol Lee', 'Sales Associate', 'Sales', 48000, 1),
    ('David Brown', 'Sales Intern', 'Sales', 30000, 2),
    ('Eve Davis', 'Developer', 'IT', 75000, NULL),
    ('Frank Miller', 'Intern', 'IT', 35000, 5);
   
SELECT * FROM employees LIMIT 10;

 CREATE TABLE IF NOT EXISTS sales(
    sale_id SERIAL PRIMARY KEY,
    employee_id INT REFERENCES employees(employee_id),
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    sale_date DATE NOT NULL
);

INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES
    (2, 1, 20, '2024-10-15'),
    (2, 2, 15, '2024-10-16'),
    (3, 1, 10, '2024-10-17'),
    (3, 3, 5, '2024-10-20'),
    (4, 2, 8, '2024-10-21'),
    (2, 1, 12, '2024-11-01');
   
INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES
    (2, 1, 20, '2024-11-15'),
    (2, 2, 15, '2024-11-14'),
    (3, 1, 10, '2024-11-15'),
    (3, 3, 5, '2024-11-13'),
    (4, 2, 8, '2024-11-16'),
    (2, 1, 12, '2024-11-15');
   
INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES
    (6, 1, 20, '2024-11-15'),
    (6, 2, 15, '2024-11-14'),
    (5, 1, 10, '2024-11-15'),
    (5, 3, 5, '2024-11-13'),
    (4, 2, 8, '2024-11-16'),
    (3, 1, 12, '2024-11-15');

TRUNCATE TABLE sales;

SELECT * FROM sales LIMIT 30;
   
CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

INSERT INTO products (name, price)
VALUES
    ('Product A', 150.00),
    ('Product B', 200.00),
    ('Product C', 100.00);

SELECT * FROM products LIMIT 10;   

-- 1. Создайте временную таблицу high_sales_products, которая будет содержать продукты, 
-- проданные в количестве более 10 единиц за последние 7 дней. Выведите данные из таблицы high_sales_products 



CREATE TEMPORARY TABLE IF NOT EXISTS high_sales_products AS
SELECT product_id, employee_id, quantity, sale_date
FROM sales
WHERE sale_date >= CURRENT_DATE - 7
GROUP BY product_id, employee_id, quantity, sale_date
HAVING SUM(quantity) > 10;

SELECT * FROM high_sales_products LIMIT 10;

-- 2. Создайте CTE employee_sales_stats, который посчитает общее количество продаж и среднее количество продаж
-- для каждого сотрудника за последние 30 дней. 

WITH employee_sales_stats AS (
    SELECT
        sales.employee_id,
        employees.name,
        SUM(sales.quantity) AS total_sales_sum,
        AVG(sales.quantity) AS average_sales
    FROM
        sales
    JOIN
        employees ON sales.employee_id = employees.employee_id
    WHERE
        sales.sale_date >= CURRENT_DATE - 30
    GROUP BY
        sales.employee_id, employees.name
)
SELECT * FROM employee_sales_stats LIMIT 50;

-- Напишите запрос, который выводит сотрудников с количеством продаж выше среднего по компании 

WITH employee_sales_stats AS (
    SELECT
        sales.employee_id,
        employees.name,
        SUM(sales.quantity) AS total_sales_sum,
        AVG(sales.quantity) AS average_sales
    FROM
        sales
    JOIN
        employees ON sales.employee_id = employees.employee_id
    WHERE
        sales.sale_date >= CURRENT_DATE - 30
    GROUP BY
        sales.employee_id, employees.name
)
SELECT
    employee_sales_stats.name,
    employee_sales_stats.total_sales_sum
FROM
    employee_sales_stats
WHERE
    employee_sales_stats.total_sales_sum > (
        SELECT
            AVG(employee_sales_stats.total_sales_sum)
        FROM
            employee_sales_stats
    )
LIMIT 10;


-- 3. Используя CTE, создайте иерархическую структуру, показывающую всех сотрудников, которые подчиняются конкретному менеджеру

-- Выведем общую иерархию сотрудников
WITH employee_hierarchy AS (
    SELECT e1.name AS manager, e2.name AS employee
    FROM employees e1
    JOIN employees e2 ON e1.employee_id = e2.manager_id
)
SELECT * FROM employee_hierarchy
LIMIT 10;

-- Выведем, какие сотрудники подчиняются Alice Johnson
WITH employee_hierarchy AS (
    SELECT e1.name AS manager, e2.name AS employee
    FROM employees e1
    JOIN employees e2 ON e1.employee_id = e2.manager_id
)
SELECT employee 
FROM employee_hierarchy
WHERE manager = 'Alice Johnson'
LIMIT 10;

-- 4. Напишите запрос с CTE, который выведет топ-3 продукта по количеству продаж за текущий месяц и за прошлый месяц. 
-- В результатах должно быть указано, к какому месяцу относится каждая запись
   
WITH current_month_sales AS (
    SELECT
        product_id,
        SUM(quantity) AS total_quantity
    FROM
        sales
    WHERE
        date_trunc('month', sale_date) = date_trunc('month', CURRENT_DATE)
    GROUP BY
        product_id
    ORDER BY
        total_quantity DESC
    LIMIT 3
),
past_month_sales AS (
    SELECT
        product_id,
        SUM(quantity) AS total_quantity
    FROM
        sales
    WHERE
        date_trunc('month', sale_date) = date_trunc('month', CURRENT_DATE - INTERVAL '1 month')
    GROUP BY
        product_id
    ORDER BY
        total_quantity DESC
    LIMIT 3
)
SELECT
    to_char(CURRENT_DATE, 'Month') AS month_label,
    product_id,
    total_quantity
FROM
    current_month_sales
UNION ALL
SELECT
    to_char(CURRENT_DATE - INTERVAL '1 month', 'Month'),
    product_id,
    total_quantity
FROM
    past_month_sales;
   

-- 5. Создайте индекс для таблицы sales по полю employee_id и sale_date. 
-- Проверьте, как наличие индекса влияет на производительность следующего запроса, используя трассировку (EXPLAIN ANALYZE)
-- 6. Используя трассировку, проанализируйте запрос, который находит общее количество проданных единиц каждого продукта.
   
-- Без индекса

EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
GROUP BY product_id
LIMIT 100;

-- Результаты:
-- Limit  (cost=35.50..35.53 rows=3 width=12) (actual time=0.032..0.037 rows=3 loops=1)
--  ->  HashAggregate  (cost=35.50..35.53 rows=3 width=12) (actual time=0.031..0.035 rows=3 loops=1)
--        Group Key: product_id
--        Batches: 1  Memory Usage: 24kB
--        ->  Seq Scan on sales  (cost=0.00..27.00 rows=1700 width=8) (actual time=0.014..0.016 rows=18 loops=1)
-- Planning Time: 0.101 ms
-- Execution Time: 0.067 ms

-- Создадим индекс:
CREATE INDEX idx_employee_id_sale_date
ON sales (employee_id, sale_date); 

-- Посмотрим с индексом:
EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
GROUP BY product_id
LIMIT 100;

-- Результаты:
-- Limit  (cost=1.27..1.30 rows=3 width=12) (actual time=0.028..0.030 rows=3 loops=1)
--  ->  HashAggregate  (cost=1.27..1.30 rows=3 width=12) (actual time=0.026..0.028 rows=3 loops=1)
--        Group Key: product_id
--        Batches: 1  Memory Usage: 24kB
--        ->  Seq Scan on sales  (cost=0.00..1.18 rows=18 width=8) (actual time=0.011..0.013 rows=18 loops=1)
-- Planning Time: 0.731 ms
-- Execution Time: 0.063 ms

-- Индекс не должен применяться и не применяется, т.к. в запросе нет поля employee_id