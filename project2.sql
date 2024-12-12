-- Выведем зоны хранения, где условия хранения не соответствуют нормативам.

CREATE OR REPLACE VIEW view_zone_condition_deviation AS
SELECT
    sz.name AS storage_zone,
    szc.temperature,
    szc.wetness,
    sz.temperature_range AS norm_temperature,
    sz.wetness_range AS norm_wetness,
    CASE
        WHEN szc.temperature < lower(sz.temperature_range) THEN 'Ниже нормы'
        WHEN szc.temperature > upper(sz.temperature_range) THEN 'Выше нормы'
        ELSE 'В норме'
    END AS temperature_status,
    CASE
        WHEN szc.wetness < lower(sz.wetness_range) THEN 'Ниже нормы'
        WHEN szc.wetness > upper(sz.wetness_range) THEN 'Выше нормы'
        ELSE 'В норме'
    END AS wetness_status
FROM
    storage_zone_conditions szc
JOIN
    storage_zone sz ON szc.storage_zone_id = sz.id;

SELECT *
FROM view_zone_condition_deviation
WHERE temperature_status != 'В норме' OR wetness_status != 'В норме'
LIMIT 100;



-- Выведем популярные товары, продаваемые в конкретные даты
WITH popular_products AS (
    SELECT
        cp.product_name,
        SUM(srd.quantity) AS total_sold,
        sr.sale_date::DATE AS sale_day
    FROM
        sale_receipt_details srd
    JOIN
        product_unit pu ON srd.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    JOIN
        sale_receipt sr ON srd.receipt_id = sr.id
    GROUP BY
        cp.product_name, sr.sale_date::DATE
)
SELECT
    sale_day,
    product_name,
    total_sold
FROM
    popular_products
WHERE
    total_sold = (
        SELECT MAX(total_sold)
        FROM popular_products pp
        WHERE pp.sale_day = popular_products.sale_day
    )
ORDER BY
    sale_day
LIMIT 100;
   
-- Запрос на поиск партий с истекающим сроком годности, оптимизированный с использованием индекса

-- Поиск партий с истекающим сроком годности
EXPLAIN ANALYZE
SELECT
    pu.barcode,
    cp.product_name,
    pu.date_production,
    cp.storage_life
FROM
    product_unit pu
JOIN
    catalog_product cp ON pu.catalog_id = cp.id
WHERE
    CURRENT_DATE - pu.date_production > cp.storage_life * 0.9 -- Товары, срок годности которых превышает 90%
ORDER BY
    pu.date_production DESC
LIMIT 100;
 /* 
 Sort  (cost=3.20..3.23 rows=13 width=304) (actual time=0.307..0.308 rows=7 loops=1)
  Sort Key: pu.date_production DESC
  Sort Method: quicksort  Memory: 25kB
  ->  Hash Join  (cost=1.45..2.96 rows=13 width=304) (actual time=0.287..0.301 rows=7 loops=1)
        Hash Cond: (pu.catalog_id = cp.id)
        Join Filter: (((CURRENT_DATE - pu.date_production))::numeric > ((cp.storage_life)::numeric * 0.9))
        Rows Removed by Join Filter: 33
        ->  Seq Scan on product_unit pu  (cost=0.00..1.40 rows=40 width=86) (actual time=0.007..0.009 rows=40 loops=1)
        ->  Hash  (cost=1.20..1.20 rows=20 width=226) (actual time=0.010..0.010 rows=20 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 10kB
              ->  Seq Scan on catalog_product cp  (cost=0.00..1.20 rows=20 width=226) (actual time=0.004..0.006 rows=20 loops=1)
Planning Time: 0.224 ms
Execution Time: 0.324 ms  
 */

-- Создание индекса на поле date_production
CREATE INDEX IF NOT EXISTS idx_product_unit_date_production ON product_unit (date_production);


EXPLAIN ANALYZE
SELECT
    pu.barcode,
    cp.product_name,
    pu.date_production,
    cp.storage_life
FROM
    product_unit pu
JOIN
    catalog_product cp ON pu.catalog_id = cp.id
WHERE
    CURRENT_DATE - pu.date_production > cp.storage_life * 0.9 -- Товары, срок годности которых превышает 90%
ORDER BY
    pu.date_production DESC
LIMIT 100;
/*
Sort  (cost=3.20..3.23 rows=13 width=304) (actual time=0.049..0.049 rows=7 loops=1)
  Sort Key: pu.date_production DESC
  Sort Method: quicksort  Memory: 25kB
  ->  Hash Join  (cost=1.45..2.96 rows=13 width=304) (actual time=0.029..0.041 rows=7 loops=1)
        Hash Cond: (pu.catalog_id = cp.id)
        Join Filter: (((CURRENT_DATE - pu.date_production))::numeric > ((cp.storage_life)::numeric * 0.9))
        Rows Removed by Join Filter: 33
        ->  Seq Scan on product_unit pu  (cost=0.00..1.40 rows=40 width=86) (actual time=0.011..0.013 rows=40 loops=1)
        ->  Hash  (cost=1.20..1.20 rows=20 width=226) (actual time=0.009..0.009 rows=20 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 10kB
              ->  Seq Scan on catalog_product cp  (cost=0.00..1.20 rows=20 width=226) (actual time=0.004..0.006 rows=20 loops=1)
Planning Time: 0.147 ms
Execution Time: 0.065 ms
 */
   
-- Индекс не используется либо из-за сложного условия, либо из-за оптимизации PostgreSQL

   
--  Получение данных о частоте и объемах списания по причинам

EXPLAIN ANALYZE
SELECT
    w.write_off_reason,
    COUNT(*) AS total_write_offs,
    SUM(w.quantity) AS total_quantity
FROM
    product_write_off w
GROUP BY
    w.write_off_reason
ORDER BY
    total_quantity DESC
LIMIT 100;
/*
 Sort  (cost=30.14..30.64 rows=200 width=20) (actual time=0.025..0.026 rows=5 loops=1)
  Sort Key: (sum(quantity)) DESC
  Sort Method: quicksort  Memory: 25kB
  ->  HashAggregate  (cost=20.50..22.50 rows=200 width=20) (actual time=0.020..0.021 rows=5 loops=1)
        Group Key: write_off_reason
        Batches: 1  Memory Usage: 40kB
        ->  Seq Scan on product_write_off w  (cost=0.00..16.00 rows=600 width=8) (actual time=0.010..0.011 rows=20 loops=1)
Planning Time: 0.074 ms
Execution Time: 0.049 ms
 */

   
-- Создание временного индекса
CREATE INDEX CONCURRENTLY temp_idx_write_off_date ON product_write_off (write_off_date);

-- Анализ причин списания
EXPLAIN ANALYZE
SELECT
    w.write_off_reason,
    COUNT(*) AS total_write_offs,
    SUM(w.quantity) AS total_quantity
FROM
    product_write_off w
GROUP BY
    w.write_off_reason
ORDER BY
    total_quantity DESC
LIMIT 100;
/*
 Sort  (cost=1.98..2.03 rows=20 width=20) (actual time=0.027..0.028 rows=5 loops=1)
  Sort Key: (sum(quantity)) DESC
  Sort Method: quicksort  Memory: 25kB
  ->  HashAggregate  (cost=1.35..1.55 rows=20 width=20) (actual time=0.021..0.023 rows=5 loops=1)
        Group Key: write_off_reason
        Batches: 1  Memory Usage: 24kB
        ->  Seq Scan on product_write_off w  (cost=0.00..1.20 rows=20 width=8) (actual time=0.009..0.010 rows=20 loops=1)
Planning Time: 0.253 ms
Execution Time: 0.057 ms
 */

-- Индекс не используется из-за оптимизации PostgreSQL

-- Удаление временного индекса
DROP INDEX temp_idx_write_off_date;


-- Анализ товаров с указанным ингредиентом, распределенных по зонам хранения

CREATE INDEX IF NOT EXISTS idx_catalog_product_ingredients ON catalog_product USING GIN (ingredients);

WITH ingredient_products AS (
    SELECT
        cp.id AS catalog_id,
        cp.product_name,
        cp.ingredients,
        c.name AS category_name
    FROM
        catalog_product cp
    JOIN
        category c ON cp.category_id = c.id
    WHERE
        'Мясо' = ANY(cp.ingredients) -- Условие на ингредиент
)
SELECT
    ip.product_name,
    ip.category_name,
    ip.ingredients,
    sz.name AS storage_zone,
    SUM(ps.quantity) AS total_quantity
FROM
    ingredient_products ip
JOIN
    product_unit pu ON ip.catalog_id = pu.catalog_id
JOIN
    product_storage ps ON pu.barcode = ps.product_unit_barcode
JOIN
    storage_sale ss ON ps.storage_sale_id = ss.id
JOIN
    storage_zone sz ON ss.storage_zone_id = sz.id
GROUP BY
    ip.product_name, ip.category_name, ip.ingredients, sz.name
ORDER BY
    ip.category_name, ip.product_name, sz.name
LIMIT 100;

-- Товары, которые распределены по складу неравномерно (например, большая часть находится в одной ячейке).
-- Создание временной таблицы для расчета
WITH product_distribution AS (
    SELECT
        ps.product_unit_barcode,
        cp.product_name,
        COUNT(DISTINCT ps.storage_sale_id) AS total_storage_slots,
        MAX(ps.quantity) AS max_quantity_in_one_slot,
        SUM(ps.quantity) AS total_quantity
    FROM
        product_storage ps
    JOIN
        product_unit pu ON ps.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    GROUP BY
        ps.product_unit_barcode, cp.product_name
)
SELECT
    product_name,
    total_quantity,
    total_storage_slots,
    max_quantity_in_one_slot,
    (max_quantity_in_one_slot::FLOAT / total_quantity) * 100 AS max_slot_percentage
FROM
    product_distribution
WHERE
    total_storage_slots > 1
ORDER BY
    max_slot_percentage DESC, total_quantity desc
LIMIT 100;

-- Как быстро товары продаются - среднее количество дней, прошедших с момента появления партии на складе до продажи
WITH sales_analysis AS (
    SELECT
        pu.barcode,
        cp.product_name,
        pu.date_production,
        MIN(sr.sale_date) AS first_sale_date,
        AVG(EXTRACT(DAY FROM sr.sale_date - pu.date_production)) AS avg_days_to_sell
    FROM
        sale_receipt_details srd
    JOIN
        sale_receipt sr ON srd.receipt_id = sr.id
    JOIN
        product_unit pu ON srd.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    GROUP BY
        pu.barcode, cp.product_name, pu.date_production
)
SELECT
    product_name,
    AVG(avg_days_to_sell) AS avg_days_to_sell
FROM
    sales_analysis
GROUP BY
    product_name
ORDER BY
    avg_days_to_sell asc
LIMIT 100;

-- Выявление топ-5 самых популярных поставщиков
WITH supplier_analysis AS (
    SELECT
        p.provider_name,
        SUM(pu.lot_count) AS total_quantity_supplied
    FROM
        product_unit pu
    JOIN
        provider p ON pu.provider_id = p.id
    GROUP BY
        p.provider_name
)
SELECT
    provider_name,
    total_quantity_supplied
FROM
    supplier_analysis
ORDER BY
    total_quantity_supplied DESC
LIMIT 5;

-- Анализ распределения товаров по категориям, с учетом условий хранения и исторического распределения
-- Создание временной структуры для анализа текущего распределения
WITH current_distribution AS (
    SELECT
        c.name AS category_name,
        sz.name AS storage_zone,
        COUNT(ps.id) AS total_items,
        SUM(CASE
            WHEN NOT (c.temper && sz.temperature_range) OR NOT (c.wetness && sz.wetness_range)
            THEN 1 ELSE 0
        END) AS items_in_mismatch_conditions
    FROM
        product_storage ps
    JOIN
        product_unit pu ON ps.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    JOIN
        category c ON cp.category_id = c.id
    JOIN
        storage_sale ss ON ps.storage_sale_id = ss.id
    JOIN
        storage_zone sz ON ss.storage_zone_id = sz.id
    GROUP BY
        c.name, sz.name
),
historical_distribution AS (
    SELECT
        DATE(sr.sale_date) AS sale_date,
        cp.category_id,
        c.name AS category_name,
        COUNT(srd.id) AS items_sold
    FROM
        sale_receipt_details srd
    JOIN
        sale_receipt sr ON srd.receipt_id = sr.id
    JOIN
        product_unit pu ON srd.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    JOIN
        category c ON cp.category_id = c.id
    WHERE
        sr.sale_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY
        DATE(sr.sale_date), cp.category_id, c.name
)
SELECT
    cd.category_name,
    cd.storage_zone,
    cd.total_items,
    cd.items_in_mismatch_conditions,
    SUM(hd.items_sold) AS total_items_sold_last_30_days
FROM
    current_distribution cd
LEFT JOIN
    historical_distribution hd ON cd.category_name = hd.category_name
GROUP BY
    cd.category_name, cd.storage_zone, cd.total_items, cd.items_in_mismatch_conditions
ORDER BY
    cd.category_name, total_items_sold_last_30_days DESC
LIMIT 100;


-- Оптимизация заказов с учетом текущего состояния склада и потребностей в зонах
-- Этот запрос оценивает запасы товаров и выявляет, какие категории товаров необходимо срочно заказать, чтобы избежать дефицита, основываясь на среднем времени продажи и текущих запасах.

WITH stock_analysis AS (
    SELECT
        c.name AS category_name,
        cp.product_name,
        SUM(ps.quantity) AS total_stock,
        AVG(EXTRACT(DAY FROM CURRENT_DATE - pu.date_production)) AS avg_days_in_stock,
        COUNT(DISTINCT sr.id) AS sales_frequency,
        SUM(srd.quantity) AS total_sold_last_30_days
    FROM
        product_storage ps
    JOIN
        product_unit pu ON ps.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    JOIN
        category c ON cp.category_id = c.id
    LEFT JOIN
        sale_receipt_details srd ON pu.barcode = srd.product_unit_barcode
    LEFT JOIN
        sale_receipt sr ON srd.receipt_id = sr.id AND sr.sale_date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY
        c.name, cp.product_name
),
sales_rate AS (
    SELECT
        category_name,
        product_name,
        CASE
            WHEN total_sold_last_30_days > 0 THEN total_sold_last_30_days / 30.0
            ELSE 0
        END AS daily_sales_rate
    FROM
        stock_analysis
)
SELECT
    sa.category_name,
    sa.product_name,
    sa.total_stock,
    sr.daily_sales_rate,
    CASE
        WHEN sr.daily_sales_rate > 0 THEN sa.total_stock / sr.daily_sales_rate
        ELSE NULL
    END AS days_until_stockout
FROM
    stock_analysis sa
JOIN
    sales_rate sr ON sa.product_name = sr.product_name
WHERE
    sa.total_stock < 50 OR (sa.total_stock / sr.daily_sales_rate) < 10
ORDER BY
    days_until_stockout ASC NULLS LAST, sa.total_stock ASC
LIMIT 100;


-- Прогнозирование уровня списаний с учетом истории и текущих условий хранения

WITH write_off_history AS (
    SELECT
        pu.catalog_id,
        cp.product_name,
        COUNT(pwo.id) AS total_write_offs,
        SUM(pwo.quantity) AS total_quantity_written_off,
        AVG(EXTRACT(DAY FROM pwo.write_off_date - pu.date_production)) AS avg_days_to_write_off
    FROM
        product_write_off pwo
    JOIN
        product_unit pu ON pwo.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    GROUP BY
        pu.catalog_id, cp.product_name
),
current_conditions AS (
    SELECT
        ps.product_unit_barcode,
        cp.product_name,
        sz.name AS storage_zone,
        c.temper AS required_temperature_range,
        sz.temperature_range AS actual_temperature_range,
        c.wetness AS required_wetness_range,
        sz.wetness_range AS actual_wetness_range,
        CASE
            WHEN NOT (c.temper && sz.temperature_range) THEN 1 ELSE 0
        END AS temperature_violation,
        CASE
            WHEN NOT (c.wetness && sz.wetness_range) THEN 1 ELSE 0
        END AS wetness_violation
    FROM
        product_storage ps
    JOIN
        product_unit pu ON ps.product_unit_barcode = pu.barcode
    JOIN
        catalog_product cp ON pu.catalog_id = cp.id
    JOIN
        category c ON cp.category_id = c.id
    JOIN
        storage_sale ss ON ps.storage_sale_id = ss.id
    JOIN
        storage_zone sz ON ss.storage_zone_id = sz.id
)
SELECT
    cc.product_name,
    cc.storage_zone,
    wh.total_write_offs,
    wh.avg_days_to_write_off,
    COUNT(cc.temperature_violation + cc.wetness_violation) AS current_violations,
    CASE
        WHEN COUNT(cc.temperature_violation + cc.wetness_violation) > 0 THEN 'Высокий риск'
        WHEN wh.avg_days_to_write_off < 30 THEN 'Средний риск'
        ELSE 'Низкий риск'
    END AS write_off_risk_level
FROM
    current_conditions cc
LEFT JOIN
    write_off_history wh ON cc.product_name = wh.product_name
GROUP BY
    cc.product_name, cc.storage_zone, wh.total_write_offs, wh.avg_days_to_write_off
ORDER BY
    write_off_risk_level DESC, current_violations desc
LIMIT 100;