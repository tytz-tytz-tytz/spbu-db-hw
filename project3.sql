-- Триггер должен запрещать добавление товаров с истекшим сроком годности в таблицу sale_receipt_details

-- Функция для проверки срока годности
CREATE OR REPLACE FUNCTION check_expired_products()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверяем, если срок годности истек, запрещаем продажу
    IF EXISTS (
        SELECT 1
        FROM product_unit pu
        JOIN catalog_product cp ON pu.catalog_id = cp.id
        WHERE pu.barcode = NEW.product_unit_barcode
          AND pu.date_production + cp.storage_life * INTERVAL '1 day' < NOW()
    ) THEN
        RAISE EXCEPTION 'Нельзя продать товар с истекшим сроком годности: %', NEW.product_unit_barcode;
    END IF;
    RETURN NEW;
END;
$$;

-- Создаем триггер для проверки срока годности перед добавлением записи в чек
CREATE TRIGGER check_expired_products_trigger
BEFORE INSERT ON sale_receipt_details
FOR EACH ROW
EXECUTE FUNCTION check_expired_products();

-- Пример записи с истекшим сроком годности
INSERT INTO product_unit (barcode, catalog_id, date_production, provider_id, lot_count)
VALUES ('9999999999999', 1, CURRENT_DATE - INTERVAL '2 years', 1, 10);

INSERT INTO sale_receipt_details (receipt_id, product_unit_barcode, quantity)
VALUES (1, '9999999999999', 1);

-- Результат:
-- Нельзя продать товар с истекшим сроком годности: 9999999999999


-- Триггер должен логировать любые изменения (вставка, обновление, удаление) в таблице product_storage в отдельную таблицу product_storage_log.
-- Функция для логирования изменений
CREATE OR REPLACE FUNCTION log_product_storage_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO product_storage_log (action, product_unit_barcode, storage_sale_id, quantity, changed_at)
        VALUES ('INSERT', NEW.product_unit_barcode, NEW.storage_sale_id, NEW.quantity, NOW());
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO product_storage_log (action, product_unit_barcode, storage_sale_id, quantity, changed_at)
        VALUES ('UPDATE', OLD.product_unit_barcode, OLD.storage_sale_id, OLD.quantity, NOW());
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO product_storage_log (action, product_unit_barcode, storage_sale_id, quantity, changed_at)
        VALUES ('DELETE', OLD.product_unit_barcode, OLD.storage_sale_id, OLD.quantity, NOW());
    END IF;
    RETURN NEW;
END;
$$;

-- Создаем триггер для логирования изменений в таблице product_storage
CREATE TRIGGER log_product_storage_trigger
AFTER INSERT OR UPDATE OR DELETE ON product_storage
FOR EACH ROW
EXECUTE FUNCTION log_product_storage_changes();

CREATE TABLE product_storage_log (
    id SERIAL PRIMARY KEY, -- Уникальный идентификатор записи
    action VARCHAR(10) NOT NULL, -- Тип действия (INSERT, UPDATE, DELETE)
    product_unit_barcode VARCHAR(30), -- Штрих-код товара
    storage_sale_id INT, -- Идентификатор ячейки хранения
    quantity INT, -- Количество товара
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Время изменения
);

-- Вставка в таблицу product_storage
INSERT INTO product_storage (product_unit_barcode, storage_sale_id, quantity)
VALUES ('1234567890051', 10, 10);

-- Обновление в таблице product_storage
UPDATE product_storage
SET quantity = 20
WHERE product_unit_barcode = '1234567890051';

-- Удаление из таблицы product_storage
DELETE FROM product_storage
WHERE product_unit_barcode = '1234567890051';

-- Проверка таблицы логов
SELECT * FROM product_storage_log LIMIT 100;

-- Изменения логируются

-- Триггер должен запрещать размещение товара в ячейку хранения, если её условия (температура и влажность) не соответствуют требованиям категории товара.
-- Функция для проверки условий хранения
CREATE OR REPLACE FUNCTION check_storage_conditions()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM product_unit pu
        JOIN catalog_product cp ON pu.catalog_id = cp.id
        JOIN category c ON cp.category_id = c.id
        JOIN storage_sale ss ON ss.id = NEW.storage_sale_id
        JOIN storage_zone sz ON ss.storage_zone_id = sz.id
        WHERE pu.barcode = NEW.product_unit_barcode
          AND c.temper @> sz.temperature_range
          AND c.wetness @> sz.wetness_range
    ) THEN
        RAISE EXCEPTION 'Условия хранения не соответствуют требованиям для товара: %', NEW.product_unit_barcode;
    END IF;
    RETURN NEW;
END;
$$;

-- Создаем триггер для проверки условий хранения
CREATE TRIGGER check_storage_conditions_trigger
BEFORE INSERT OR UPDATE ON product_storage
FOR EACH ROW
EXECUTE FUNCTION check_storage_conditions();

-- Пример записи, нарушающей условия хранения
INSERT INTO product_storage (product_unit_barcode, storage_sale_id, quantity)
VALUES ('1234567890001', 6, 10);

-- Результат: 
-- ОШИБКА: Условия хранения не соответствуют требованиям для товара: 1234567890001

-- Триггер должен автоматически увеличивать количество товара в таблице product_storage, если соответствующая запись удаляется из таблицы sale_receipt_details
-- Функция для обновления количества товара при удалении из чека
CREATE OR REPLACE FUNCTION restore_product_quantity_on_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE product_storage
    SET quantity = quantity + OLD.quantity
    WHERE product_unit_barcode = OLD.product_unit_barcode;

    RETURN OLD;
END;
$$;

-- Создаем триггер для обновления количества товара при удалении из чека
CREATE TRIGGER restore_product_quantity_trigger
AFTER DELETE ON sale_receipt_details
FOR EACH ROW
EXECUTE FUNCTION restore_product_quantity_on_delete();

-- Удаление товара из чека
DELETE FROM sale_receipt_details
WHERE id = 1;

-- Проверка количества товара в таблице product_storage
SELECT * FROM product_storage WHERE product_unit_barcode = '1234567890001' LIMIT 100;

-- Триггер должен логировать любые изменения статуса в таблице purchase_order
-- Функция для логирования изменений статуса заказа
CREATE OR REPLACE FUNCTION log_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Логируем изменение статуса
    INSERT INTO order_status_log (purchase_order_id, old_status, new_status, changed_at)
    VALUES (OLD.id, OLD.status, NEW.status, NOW());

    RETURN NEW;
END;
$$;

-- Создаем триггер для логирования изменения статуса заказа
CREATE TRIGGER log_status_change_trigger
AFTER UPDATE OF status ON purchase_order
FOR EACH ROW
EXECUTE FUNCTION log_status_change();

-- Изменяем статус заказа
UPDATE purchase_order
SET status = 'В пути'
WHERE id = 1;

-- Проверяем таблицу логов
SELECT * FROM order_status_log WHERE purchase_order_id = 1 LIMIT 100;

-- Запретить добавление новых партий товаров, если дата производства товара в этой партии указывает на просрочку уже на момент поставки.

-- Функция для контроля поставки просроченного товара
CREATE OR REPLACE FUNCTION prevent_expired_product_supply()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверяем, истек ли срок годности
    IF EXISTS (
        SELECT 1
        FROM catalog_product cp
        WHERE cp.id = NEW.catalog_id
          AND NEW.date_production + cp.storage_life * INTERVAL '1 day' < NOW()
    ) THEN
        RAISE EXCEPTION 'Поставка товара с истекшим сроком годности запрещена: %', NEW.barcode;
    END IF;

    RETURN NEW;
END;
$$;

-- Создаем триггер для проверки срока годности партии
CREATE TRIGGER prevent_expired_product_supply_trigger
BEFORE INSERT ON product_unit
FOR EACH ROW
EXECUTE FUNCTION prevent_expired_product_supply();

-- Попытка добавления партии товара с истекшим сроком годности
INSERT INTO product_unit (barcode, catalog_id, date_production, provider_id, lot_count)
VALUES ('1234567899999', 1, '2020-01-01', 1, 100);

-- Результат:
-- ОШИБКА: Поставка товара с истекшим сроком годности запрещена: 1234567899999

-- Автоматически списывать партию товара, если истекает её срок годности.

-- Функция для автоматического списания истекших партий
CREATE OR REPLACE FUNCTION auto_write_off_expired()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.date_production + INTERVAL '1 day' * (SELECT storage_life FROM catalog_product WHERE id = NEW.catalog_id) < NOW() THEN
        INSERT INTO product_write_off (product_unit_barcode, quantity, write_off_reason, write_off_date, recorded_by, storage_sale_id)
        SELECT NEW.barcode, NEW.lot_count, 'Просрочка', NOW(), 1, ps.storage_sale_id
        FROM product_storage ps
        WHERE ps.product_unit_barcode = NEW.barcode;

        -- Удаляем товар из доступного запаса
        DELETE FROM product_storage WHERE product_unit_barcode = NEW.barcode;
    END IF;

    RETURN NEW;
END;
$$;

-- Создаем триггер для автоматического списания товара
CREATE TRIGGER auto_write_off_expired_trigger
AFTER UPDATE ON product_unit
FOR EACH ROW
EXECUTE FUNCTION auto_write_off_expired();

-- Устанавливаем дату производства так, чтобы срок годности истёк
UPDATE product_unit
SET date_production = '2020-01-01'
WHERE barcode = '1234567890001';

-- Проверяем таблицу списаний
SELECT * FROM product_write_off WHERE product_unit_barcode = '1234567890001' LIMIT 100;

-- Триггер должен запретить уменьшение цены товара более чем на 20% от текущей.

-- Функция для ограничения изменения цены
CREATE OR REPLACE FUNCTION restrict_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.price < OLD.price * 0.8 THEN
        RAISE EXCEPTION 'Снижение цены товара более чем на 20%% запрещено: %', OLD.product_name;
    END IF;

    RETURN NEW;
END;
$$;

-- Создаем триггер для ограничения изменения цены
CREATE TRIGGER restrict_price_change_trigger
BEFORE UPDATE OF price ON catalog_product
FOR EACH ROW
EXECUTE FUNCTION restrict_price_change();

-- Попытка изменить цену на недопустимую
UPDATE catalog_product
SET price = 100
WHERE id = 1;

-- Результат:
-- ОШИБКА: Снижение цены товара более чем на 20% запрещено: Собачий обед Папа-Говядина

-- Транзакции:

-- Возвращенный товар добавляется обратно на склад. Если товар возвращен по частям (разные партии), то он равномерно распределяется по доступным ячейкам.

BEGIN;

DO $$
DECLARE
    return_quantity INT := 120;
    product_barcode VARCHAR := '1234567890001';
    remaining_quantity INT := return_quantity;
    storage_id INT;
BEGIN
    FOR storage_id IN
        SELECT id
        FROM storage_sale
        WHERE storage_zone_id = 1
    LOOP
        IF remaining_quantity > 0 THEN
            UPDATE product_storage
            SET quantity = quantity + LEAST(remaining_quantity, 50)
            WHERE product_unit_barcode = product_barcode AND storage_sale_id = storage_id;

            remaining_quantity := remaining_quantity - 50;
        END IF;
    END LOOP;

    IF remaining_quantity > 0 THEN
        RAISE EXCEPTION 'Не удалось распределить весь возврат: осталось % единиц', remaining_quantity;
    END IF;
END $$;

COMMIT;


-- Обновляются цены всех товаров в указанной категории, но не более чем на 10% за раз

BEGIN;

UPDATE catalog_product
SET price = LEAST(price * 1.1, 1000) -- Цена не может превышать 1000
WHERE category_id = (
    SELECT id FROM category WHERE name = 'Корм для собак'
);

COMMIT;

-- Транзакция одновременно изменяет цены на товары и записывает изменения в таблицу price_change_log

CREATE TABLE price_change_log (
    id SERIAL PRIMARY KEY, -- Уникальный идентификатор записи
    product_id INT NOT NULL, -- ID товара из catalog_product
    old_price NUMERIC NOT NULL, -- Старая цена товара
    new_price NUMERIC NOT NULL, -- Новая цена товара
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP -- Время изменения цены
);


BEGIN;

DO $$
DECLARE
    product RECORD;
BEGIN
    FOR product IN 
        SELECT id, price FROM catalog_product WHERE category_id = 1
    LOOP
        INSERT INTO price_change_log (product_id, old_price, new_price, changed_at)
        VALUES (product.id, product.price, product.price * 1.05, NOW());

        UPDATE catalog_product
        SET price = price * 1.05
        WHERE id = product.id;
    END LOOP;
END $$;

COMMIT;


-- Одновременно списываются партии товара с истекшим сроком годности, а информация о списании записывается в таблицу product_write_off

BEGIN;
DO $$
DECLARE
    expired_product RECORD;
BEGIN
    FOR expired_product IN 
        SELECT pu.barcode, ps.storage_sale_id, ps.quantity
        FROM product_unit pu
        JOIN product_storage ps ON ps.product_unit_barcode = pu.barcode
        JOIN catalog_product cp ON pu.catalog_id = cp.id
        WHERE cp.category_id = 1 -- Только категория "Корм для собак"
          AND pu.date_production + INTERVAL '1 day' * cp.storage_life < NOW()
    LOOP
        INSERT INTO product_write_off (product_unit_barcode, quantity, write_off_reason, write_off_date, recorded_by, storage_sale_id)
        VALUES (expired_product.barcode, expired_product.quantity, 'Просрочка', NOW(), 1, expired_product.storage_sale_id);
        DELETE FROM product_storage WHERE product_unit_barcode = expired_product.barcode;
    END LOOP;
END $$;

COMMIT;

-- Если удаляется категория товаров, все товары из этой категории автоматически перемещаются в категорию «Прочее».

BEGIN;

-- Создаем категорию "Прочее", если её не существует
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM category WHERE name = 'Прочее') THEN
        INSERT INTO category (name, temper, wetness)
        VALUES ('Прочее', '[0, 30]', '[40, 70]');
    END IF;
END $$;

DO $$
DECLARE
    misc_category_id INT;
BEGIN
    SELECT id INTO misc_category_id FROM category WHERE name = 'Прочее';

    UPDATE catalog_product
    SET category_id = misc_category_id
    WHERE category_id = (SELECT id FROM category WHERE name = 'Удаляемая категория');

    DELETE FROM category WHERE name = 'Удаляемая категория';
END $$;

COMMIT;