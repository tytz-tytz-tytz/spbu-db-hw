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


SELECT * FROM employees LIMIT 100;

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

SELECT * FROM sales LIMIT 200;


CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

SELECT * FROM products LIMIT 200;

--------------------------------------------------------
-- 1. Создать триггеры со всеми возможными ключевыми словами, а также рассмотреть операционные триггеры
-- 2. Попрактиковаться в созданиях транзакций (привести пример успешной и фейл транзакции, объяснить в комментариях почему она зафейлилась)
-- 3. Использовать RAISE для логирования

-- Cоздадим триггер для таблицы products, который будет проверять, 
-- чтобы цена продукта (price) была положительной при добавлении новой записи или обновлении существующей.

CREATE OR REPLACE FUNCTION check_product_price()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.price <= 0 THEN
        RAISE EXCEPTION 'Цена продукта должна быть больше нуля.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_product_price
BEFORE INSERT OR UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION check_product_price();

-- Проверим:
INSERT INTO products (name, price)
VALUES
    ('Product X', -150.00)

-- Результат: SQL Error [P0001]: ОШИБКА: Цена продукта должна быть больше нуля.


-- Пусть нужно логировать все изменения, происходящие в таблице employees, 
-- включая информацию о том, какой сотрудник был изменён, 
-- кем он управляется и какая у него зарплата до и после изменений. 
-- Для этого создадим таблицу employee_log и напишем соответствующий триггер.
    
CREATE TABLE IF NOT EXISTS employee_log (
    log_id SERIAL PRIMARY KEY,
    employee_id INT NOT NULL,
    old_manager_id INT,
    new_manager_id INT,
    old_salary NUMERIC(10, 2),
    new_salary NUMERIC(10, 2),
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION log_employee_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.manager_id IS DISTINCT FROM NEW.manager_id THEN
        INSERT INTO employee_log (employee_id, old_manager_id, new_manager_id)
        VALUES (NEW.employee_id, OLD.manager_id, NEW.manager_id);
    END IF;

    IF OLD.salary IS DISTINCT FROM NEW.salary THEN
        INSERT INTO employee_log (employee_id, old_salary, new_salary)
        VALUES (NEW.employee_id, OLD.salary, NEW.salary);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_employees_after_update
AFTER UPDATE ON employees
FOR EACH ROW EXECUTE FUNCTION log_employee_changes();

-- Проверим:
UPDATE employees
SET salary = 45000
WHERE employee_id = 2;

UPDATE employees
SET manager_id = 2
WHERE employee_id = 3

SELECT * FROM employee_log LIMIT 5;

-- Результат: в таблицу employee_log добавлены две записи


-- Создадим представление, которое будет показывать информацию о продажах сотрудников вместе с их именами и должностями.

CREATE VIEW v_employee_sales AS
SELECT e.name, e.position, s.sale_id, p.name as product_name, s.quantity, s.sale_date
FROM employees e
JOIN sales s ON e.employee_id = s.employee_id
JOIN products p ON s.product_id = p.product_id;

-- Создадим триггер, который будет обрабатывать вставку новых строк в представление v_employee_sales.

CREATE OR REPLACE FUNCTION trigger_function_v_employee_sales()
RETURNS TRIGGER AS $$
DECLARE
    emp_id INTEGER;
    prod_id INTEGER;
BEGIN
    SELECT employee_id INTO emp_id
    FROM employees
    WHERE name = NEW.name AND position = NEW.position;

    SELECT product_id INTO prod_id
    FROM products
    WHERE name = NEW.product_name;

    INSERT INTO sales (employee_id, product_id, quantity, sale_date)
    VALUES (emp_id, prod_id, NEW.quantity, NEW.sale_date);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER instead_of_insert_v_employee_sales
INSTEAD OF INSERT ON v_employee_sales
FOR EACH ROW EXECUTE FUNCTION trigger_function_v_employee_sales();

-- Проверим:
INSERT INTO employees (name, position, department, salary, manager_id)
VALUES
('Иван Иванов', 'Менеджер', 'Отдел продаж', 50000, null),
('Петр Петров', 'Консультант', 'Отдел продаж', 40000, 1);

INSERT INTO products (name, price)
VALUES
('Продукт X', 1000),
('Продукт Y', 2000);

-- Пробуем вставить продажу
INSERT INTO v_employee_sales (name, position, product_name, quantity, sale_date)
VALUES ('Иван Иванов', 'Менеджер', 'Продукт X', 10, CURRENT_DATE);

SELECT *
FROM sales
ORDER BY sale_id DESC
LIMIT 5;

-- Строка добавилась

-- Добавим еще одного сотрудника с таким же именем и другой позицией
INSERT INTO employees (name, position, department, salary, manager_id)
VALUES
('Иван Иванов', 'Старший менеджер', 'Отдел маркетинга', 60000, null);

-- Попробуем снова вставить данные в представление
INSERT INTO v_employee_sales (name, position, product_name, quantity, sale_date)
VALUES ('Иван Иванов', 'Менеджер', 'Продукт Y', 20, CURRENT_DATE + INTERVAL '1 day');

-- Еще раз смотрим содержимое таблицы sales
SELECT *
FROM sales
ORDER BY sale_id DESC
LIMIT 5;

-- Строка добавилась корректно

-- Создадим триггер, который будет проверять, чтобы сумма всех продаж за день не превышала определенный лимит.

CREATE OR REPLACE FUNCTION check_daily_sales_limit()
RETURNS TRIGGER AS $$
DECLARE
    daily_sales_sum NUMERIC;
BEGIN
    SELECT SUM(s.quantity * p.price)
    INTO daily_sales_sum
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    WHERE s.sale_date = NEW.sale_date;

    IF daily_sales_sum > 10000000 THEN
        RAISE EXCEPTION 'Превышен дневной лимит продаж';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_daily_sales_trigger
BEFORE INSERT OR UPDATE ON sales
FOR EACH ROW EXECUTE FUNCTION check_daily_sales_limit();

-- Попытка добавить продажу, превышающую лимит
INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES (1, 1, 100000000, CURRENT_DATE);

-- Результат: SQL Error [P0001]: ОШИБКА: Превышен дневной лимит продаж

-- Попытка добавить несколько продаж, превышающих в сумме лимит
INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES 
	(1, 1, 10000000, CURRENT_DATE),
	(1, 2, 10000000, CURRENT_DATE),
	(1, 3, 10000000, CURRENT_DATE);

-- Результат: SQL Error [P0001]: ОШИБКА: Превышен дневной лимит продаж


WITH last_10_sales AS (
    SELECT sale_id
    FROM sales
    ORDER BY sale_id DESC
    LIMIT 10
)
DELETE FROM sales
WHERE sale_id IN (SELECT sale_id FROM last_10_sales);

-- Пусть необходимо получать уведомление, когда цена товара выросла

CREATE OR REPLACE FUNCTION notify_price_increase()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.price > OLD.price THEN
        RAISE NOTICE 'Цена товара "%" была увеличена с % до %', 
                     OLD.name, OLD.price, NEW.price;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER price_increase_trigger
AFTER UPDATE OF price ON products
FOR EACH ROW
WHEN (NEW.price > OLD.price)
EXECUTE FUNCTION notify_price_increase();

-- Проверим:
-- Добавим новый товар:
INSERT INTO products (name, price)
VALUES ('Продукт Q', 1500);
-- Обновим цену:
UPDATE products
SET price = 1800
WHERE name = 'Продукт Q';

-- Результат: уведомление - Цена товара "Продукт Q" была увеличена с 1500.00 до 1800.00

-- Пусть при удалении товара мы хотим архивировать информацию о нем в другую таблицу.

CREATE TABLE archived_products (
    product_id INT,
    name VARCHAR(50),
    price NUMERIC(10, 2),
    deletion_date TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION archive_product_on_delete()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO archived_products (product_id, name, price)
    VALUES (OLD.product_id, OLD.name, OLD.price);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER archive_product_on_delete_trigger
AFTER DELETE ON products
FOR EACH ROW
EXECUTE FUNCTION archive_product_on_delete();

-- Проверим:
-- Добавим товар
INSERT INTO products (name, price)
VALUES ('Тестовый товар', 999.99);

-- Удалим товар
DELETE FROM products
WHERE name = 'Тестовый товар';

-- Проверим, заархивировался ли товар
SELECT * FROM archived_products LIMIT 5;

-- Запись добавилась

-------------------------------------------------------------------------
-- Транзакции:

-- Транзакция, которая пройдет успешно:
BEGIN TRANSACTION;

INSERT INTO employees (name, position, department, salary, manager_id)
VALUES ('Игорь Смирнов', 'Менеджер', 'Отдел продаж', 55000, 1);

INSERT INTO products (name, price)
VALUES ('Новый Продукт', 2500);

INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES ((SELECT employee_id FROM employees WHERE name = 'Игорь Смирнов'),
        (SELECT product_id FROM products WHERE name = 'Новый Продукт'),
        15,
        CURRENT_DATE);
       
COMMIT;


-- Транзакция, которая не пройдет:
BEGIN TRANSACTION;


UPDATE products
SET price = -100  
WHERE product_id = 1;
а
UPDATE sales
SET quantity = quantity + 10
WHERE employee_id = 1 AND product_id = 1;

COMMIT;

-- Результат: SQL Error [P0001]: ОШИБКА: Цена продукта должна быть больше нуля. - сработал триггер

ROLLBACK;