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
-- Limit  (cost=1.27..1.45 rows=18 width=12) (actual time=0.039..0.044 rows=3 loops=1)
--  ->  HashAggregate  (cost=1.27..1.45 rows=18 width=12) (actual time=0.038..0.042 rows=3 loops=1)
--        Group Key: product_id
--        Batches: 1  Memory Usage: 24kB
--        ->  Seq Scan on sales  (cost=0.00..1.18 rows=18 width=8) (actual time=0.016..0.018 rows=18 loops=1)
-- Planning Time: 0.607 ms
-- Execution Time: 0.124 ms

-- Возьмем запрос, который находит общее количество проданных единиц каждого продукта за текущий месяц:
EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
WHERE sale_date >= DATE_TRUNC('month', CURRENT_DATE) AND sale_date < DATE_TRUNC('month', CURRENT_DATE + INTERVAL '1 month')
GROUP BY product_id
LIMIT 100;

-- Результаты:
-- Limit  (cost=1.55..1.57 rows=1 width=12) (actual time=0.039..0.042 rows=3 loops=1)
--  ->  GroupAggregate  (cost=1.55..1.57 rows=1 width=12) (actual time=0.039..0.041 rows=3 loops=1)
--        Group Key: product_id
--        ->  Sort  (cost=1.55..1.55 rows=1 width=8) (actual time=0.034..0.035 rows=13 loops=1)
--              Sort Key: product_id
--              Sort Method: quicksort  Memory: 25kB
--              ->  Seq Scan on sales  (cost=0.00..1.54 rows=1 width=8) (actual time=0.010..0.016 rows=13 loops=1)
--                    Filter: ((sale_date >= date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (sale_date < date_trunc('month'::text, (CURRENT_DATE + '1 mon'::interval))))
--                    Rows Removed by Filter: 5
-- Planning Time: 0.120 ms
-- Execution Time: 0.061 ms



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
-- Limit  (cost=1.27..1.45 rows=18 width=12) (actual time=0.027..0.030 rows=3 loops=1)
--  ->  HashAggregate  (cost=1.27..1.45 rows=18 width=12) (actual time=0.026..0.028 rows=3 loops=1)
--        Group Key: product_id
--        Batches: 1  Memory Usage: 24kB
--        ->  Seq Scan on sales  (cost=0.00..1.18 rows=18 width=8) (actual time=0.011..0.013 rows=18 loops=1)
-- Planning Time: 0.414 ms
-- Execution Time: 0.062 ms

EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
WHERE sale_date >= DATE_TRUNC('month', CURRENT_DATE) AND sale_date < DATE_TRUNC('month', CURRENT_DATE + INTERVAL '1 month')
GROUP BY product_id
LIMIT 100;

-- Результаты:
-- Limit  (cost=1.55..1.57 rows=1 width=12) (actual time=0.026..0.028 rows=3 loops=1)
-- ->  GroupAggregate  (cost=1.55..1.57 rows=1 width=12) (actual time=0.025..0.026 rows=3 loops=1)
--        Group Key: product_id
--        ->  Sort  (cost=1.55..1.55 rows=1 width=8) (actual time=0.021..0.022 rows=13 loops=1)
--              Sort Key: product_id
--              Sort Method: quicksort  Memory: 25kB
--              ->  Seq Scan on sales  (cost=0.00..1.54 rows=1 width=8) (actual time=0.011..0.015 rows=13 loops=1)
--                    Filter: ((sale_date >= date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (sale_date < date_trunc('month'::text, (CURRENT_DATE + '1 mon'::interval))))
--                    Rows Removed by Filter: 5
-- Planning Time: 0.095 ms
-- Execution Time: 0.042 ms

-- Т.к. в таблице мало строк, индекс не применяется. Удалим индекс:
DROP INDEX IF EXISTS idx_employee_id_sale_date;

-- Добавим больше строк в таблицу sales: \прогнала этот запрос несколько раз, получила 1047 строк в таблице\
INSERT INTO sales (employee_id, product_id, quantity, sale_date)
SELECT floor(random() * 6 + 1)::int AS employee_id,
       floor(random() * 3 + 1)::int AS product_id,
       floor(random() * 10 + 1)::int AS quantity,
       '2024-11-01'::date + (random() * 16)::int AS sale_date
FROM generate_series(1, 1000000);

SELECT COUNT(*)
FROM sales;

-- 1001047 строк

-- Повторим те же запросы:

-- Без индекса

EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
GROUP BY product_id
LIMIT 100;

-- Результаты:
-- Limit  (cost=47160.61..47161.37 rows=3 width=12) (actual time=155.924..160.063 rows=3 loops=1)
--  ->  Finalize GroupAggregate  (cost=47160.61..47161.37 rows=3 width=12) (actual time=155.923..160.061 rows=3 loops=1)
--        Group Key: product_id
--        ->  Gather Merge  (cost=47160.61..47161.31 rows=6 width=12) (actual time=155.918..160.055 rows=9 loops=1)
--              Workers Planned: 2
--              Workers Launched: 2
--              ->  Sort  (cost=46160.59..46160.60 rows=3 width=12) (actual time=126.918..126.919 rows=3 loops=3)
--                    Sort Key: product_id
--                    Sort Method: quicksort  Memory: 25kB
--                    Worker 0:  Sort Method: quicksort  Memory: 25kB
--                    Worker 1:  Sort Method: quicksort  Memory: 25kB
--                    ->  Partial HashAggregate  (cost=46160.53..46160.56 rows=3 width=12) (actual time=126.904..126.905 rows=3 loops=3)
--                          Group Key: product_id
--                          Batches: 1  Memory Usage: 24kB
--                          Worker 0:  Batches: 1  Memory Usage: 24kB
--                          Worker 1:  Batches: 1  Memory Usage: 24kB
--                          ->  Parallel Seq Scan on sales  (cost=0.00..44092.03 rows=413702 width=8) (actual time=38.626..90.367 rows=333682 loops=3)
-- Planning Time: 0.230 ms
-- Execution Time: 160.095 ms

-- Возьмем запрос, который находит общее количество проданных единиц каждого продукта за текущий месяц:
EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
WHERE DATE_TRUNC('month', sale_date) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY product_id
LIMIT 100;

-- Результаты:
-- Limit  (cost=55434.66..55435.42 rows=3 width=12) (actual time=260.715..265.321 rows=3 loops=1)
--  ->  Finalize GroupAggregate  (cost=55434.66..55435.42 rows=3 width=12) (actual time=260.713..265.319 rows=3 loops=1)
--        Group Key: product_id
--        ->  Gather Merge  (cost=55434.66..55435.36 rows=6 width=12) (actual time=260.707..265.310 rows=9 loops=1)
--              Workers Planned: 2
--              Workers Launched: 2
--              ->  Sort  (cost=54434.64..54434.65 rows=3 width=12) (actual time=223.003..223.004 rows=3 loops=3)
--                    Sort Key: product_id
--                    Sort Method: quicksort  Memory: 25kB
--                    Worker 0:  Sort Method: quicksort  Memory: 25kB
--                    Worker 1:  Sort Method: quicksort  Memory: 25kB
--                   ->  Partial HashAggregate  (cost=54434.58..54434.61 rows=3 width=12) (actual time=222.989..222.990 rows=3 loops=3)
--                          Group Key: product_id
--                          Batches: 1  Memory Usage: 24kB
--                          Worker 0:  Batches: 1  Memory Usage: 24kB
--                          Worker 1:  Batches: 1  Memory Usage: 24kB
--                          ->  Parallel Seq Scan on sales  (cost=0.00..52366.07 rows=413702 width=8) (actual time=34.247..189.843 rows=333681 loops=3)
--                                Filter: ((sale_date >= date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (sale_date < date_trunc('month'::text, (CURRENT_DATE + '1 mon'::interval))))
--                                Rows Removed by Filter: 2
-- Planning Time: 0.191 ms
-- Execution Time: 265.372 ms



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
-- Limit  (cost=47211.62..47212.38 rows=3 width=12) (actual time=142.235..146.647 rows=3 loops=1)
--  ->  Finalize GroupAggregate  (cost=47211.62..47212.38 rows=3 width=12) (actual time=142.234..146.644 rows=3 loops=1)
--        Group Key: product_id
--        ->  Gather Merge  (cost=47211.62..47212.32 rows=6 width=12) (actual time=142.227..146.635 rows=9 loops=1)
--              Workers Planned: 2
--              Workers Launched: 2
--              ->  Sort  (cost=46211.60..46211.61 rows=3 width=12) (actual time=109.462..109.463 rows=3 loops=3)
--                    Sort Key: product_id
--                    Sort Method: quicksort  Memory: 25kB
--                    Worker 0:  Sort Method: quicksort  Memory: 25kB
--                    Worker 1:  Sort Method: quicksort  Memory: 25kB
--                    ->  Partial HashAggregate  (cost=46211.54..46211.57 rows=3 width=12) (actual time=109.447..109.448 rows=3 loops=3)
--                          Group Key: product_id
--                          Batches: 1  Memory Usage: 24kB
--                          Worker 0:  Batches: 1  Memory Usage: 24kB
--                          Worker 1:  Batches: 1  Memory Usage: 24kB
--                          ->  Parallel Seq Scan on sales  (cost=0.00..44126.03 rows=417103 width=8) (actual time=26.101..72.634 rows=333682 loops=3)
-- Planning Time: 0.078 ms
-- Execution Time: 146.682 ms

EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
WHERE DATE_TRUNC('month', sale_date) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY product_id
LIMIT 100;

-- Результаты:
-- Limit  (cost=55553.68..55554.44 rows=3 width=12) (actual time=240.522..245.001 rows=3 loops=1)
--  ->  Finalize GroupAggregate  (cost=55553.68..55554.44 rows=3 width=12) (actual time=240.520..244.998 rows=3 loops=1)
--        Group Key: product_id
--        ->  Gather Merge  (cost=55553.68..55554.38 rows=6 width=12) (actual time=240.501..244.989 rows=9 loops=1)
--              Workers Planned: 2
--              Workers Launched: 2
--              ->  Sort  (cost=54553.66..54553.66 rows=3 width=12) (actual time=211.834..211.835 rows=3 loops=3)
--                    Sort Key: product_id
--                    Sort Method: quicksort  Memory: 25kB
--                    Worker 0:  Sort Method: quicksort  Memory: 25kB
--                    Worker 1:  Sort Method: quicksort  Memory: 25kB
--                    ->  Partial HashAggregate  (cost=54553.60..54553.63 rows=3 width=12) (actual time=211.818..211.819 rows=3 loops=3)
--                          Group Key: product_id
--                          Batches: 1  Memory Usage: 24kB
--                          Worker 0:  Batches: 1  Memory Usage: 24kB
--                          Worker 1:  Batches: 1  Memory Usage: 24kB
--                          ->  Parallel Seq Scan on sales  (cost=0.00..52468.09 rows=417103 width=8) (actual time=28.838..177.280 rows=333681 loops=3)
--                                Filter: ((sale_date >= date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone)) AND (sale_date < date_trunc('month'::text, (CURRENT_DATE + '1 mon'::interval))))
--                               Rows Removed by Filter: 2
-- Planning Time: 0.171 ms
-- Execution Time: 245.050 ms

-- Индекс почему-то не применяяется даже на таком количестве строк...