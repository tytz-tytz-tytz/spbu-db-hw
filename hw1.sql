CREATE TABLE courses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    is_exam BOOLEAN DEFAULT FALSE,
    min_grade SMALLINT,
    max_grade SMALLINT
);

CREATE TABLE groups (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    short_name VARCHAR(100) NOT NULL,
    students_ids INTEGER[] -- мне не очень понятно, зачем тут массив. как будто обычно создается доп таблица для подобных структур.
);

CREATE TABLE students (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    group_id INT REFERENCES groups(id), -- связь с таблицей groups
    courses_ids INTEGER[] -- аналогично - зачем тут массив?
);

CREATE TABLE course_grades (
    course_id INT NOT NULL REFERENCES courses(id), -- связь с таблицей courses
    student_id INT NOT NULL REFERENCES students(id), -- связь с таблицей students
    grade SMALLINT,
    grade_str VARCHAR(20) CHECK (grade_str IN ('A', 'B', 'C', 'D', 'E', 'F')), -- буквенная оценка в шестибалльной системе
    PRIMARY KEY (course_id, student_id)
);


-- Пропишем функцию, которая будет проверять, что оценка находится в пределах минимальной и максимальной возможной.
CREATE OR REPLACE FUNCTION validate_grade_range() RETURNS TRIGGER AS $$
DECLARE
    min_grade_val SMALLINT;
    max_grade_val SMALLINT;
BEGIN
    -- Получаем минимальную и максимальную оценку для текущего курса
    SELECT min_grade, max_grade INTO min_grade_val, max_grade_val
    FROM courses
    WHERE id = NEW.course_id;

    IF NEW.grade < min_grade_val OR NEW.grade > max_grade_val THEN
        RAISE EXCEPTION 'Оценка выходит за допустимые пределы.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Зададим триггер, который будет будет запускать функцию для проверки правильности заполнения данных
CREATE TRIGGER before_insert_or_update_course_grades
BEFORE INSERT OR UPDATE ON course_grades
FOR EACH ROW EXECUTE FUNCTION validate_grade_range();

INSERT INTO courses (name, is_exam, min_grade, max_grade)
VALUES
('Математика', TRUE, 60, 100),
('Физика', TRUE, 50, 100),
('История', FALSE, 70, 100),
('Литература', FALSE, 40, 100),
('Русский язык', TRUE, 60, 100),
('Английский язык', FALSE, 60, 100),
('Информатика', FALSE, 70, 100),
('ОБЖ', FALSE, 40, 100);

SELECT * FROM courses LIMIT 10;


INSERT INTO groups (full_name, short_name, students_ids)
VALUES
('Группа А', 'A', '{1, 2}'),
('Группа Б', 'Б', '{3, 4}'),
('Группа В', 'B', '{}'),
('Группа Г', 'Г', '{5, 6, 7}');

SELECT * FROM groups LIMIT 5;

INSERT INTO students (first_name, last_name, group_id, courses_ids)
VALUES
('Иван', 'Иванов', 1, '{1}'),
('Петр', 'Петров', 2, '{1, 2}'),
('Сергей', 'Сергеев', 3, '{1, 3, 6}'),
('Анна', 'Кузнецова', 4, '{1, 7}'),
('Елена', 'Васильева', 1, '{1, 4, 8}'),
('Ольга', 'Орлова', 2, '{1, 5}'),
('Виктория', 'Сидорова', 3, '{1, 2, 3}'),
('Алексей', 'Федоров', 4, '{1, 6, 7}'),
('Марина', 'Павлова', 1, '{1, 8}'),
('Дмитрий', 'Захаров', 2, '{1, 2, 4}'),
('Татьяна', 'Комарова', 3, '{1, 5, 7}'),
('Андрей', 'Николаев', 4, '{1, 3, 8}'),
('Наталья', 'Романова', 1, '{1, 6}'),
('Михаил', 'Миронов', 2, '{1, 7, 8}'),
('Юлия', 'Волкова', 3, '{1, 2, 5}'),
('Евгений', 'Смирнов', 4, '{1, 3, 6}'),
('Валентина', 'Белова', 1, '{1, 4, 7}'),
('Кирилл', 'Дмитриев', 2, '{1, 5, 8}'),
('Светлана', 'Горбунова', 3, '{1, 2, 6}'),
('Максим', 'Королев', 4, '{1, 3, 7}');

SELECT * FROM students LIMIT 20;

INSERT INTO course_grades (course_id, student_id, grade, grade_str)
VALUES
(1, 1, 95, 'A'),
(1, 2, 85, 'B'),
(1, 3, 75, 'C'),
(1, 4, 68, 'D'),
(1, 5, 60, 'F'),
(1, 6, 91, 'A'),
(1, 7, 82, 'B'),
(1, 8, 73, 'C'),
(1, 9, 66, 'D'),
(1, 10, 60, 'F'),
(1, 11, 94, 'A'),
(1, 12, 86, 'B'),
(1, 13, 77, 'C'),
(1, 14, 69, 'D'),
(1, 15, 60, 'F'),
(1, 16, 92, 'A'),
(1, 17, 83, 'B'),
(1, 18, 74, 'C'),
(1, 19, 67, 'D'),
(1, 20, 60, 'F');

SELECT * FROM course_grades LIMIT 20;

-- Проверим, что триггер срабатывает, и мы не можем в таблицу course_grades ввести значение оценки,
-- не попадающей в диапазон [min_grade,max_grade]
INSERT INTO course_grades (course_id, student_id, grade, grade_str)
VALUES
(2, 1, 30, 'F');

-- Получаем сообщение "ОШИБКА: Оценка выходит за допустимые пределы."
-- Проверим сверху
INSERT INTO course_grades (course_id, student_id, grade, grade_str)
VALUES
(2, 1, 101, 'A');
-- Аналогичное сообщение

-- Данные не внеслись в таблицу:
SELECT * FROM course_grades;

--Выведем список студентов, где перечислено название предмета, имя студента, оценка и буквенная оценка, 
--отсортируем от большого балла к меньшему:
SELECT
    courses.name AS course_name,
    students.first_name || ' ' || students.last_name AS stunt_full_name,
    course_grades.grade,
    course_grades.grade_str
FROM
    course_grades course_grades
JOIN
    students ON course_grades.student_id = students.id
JOIN
    courses ON course_grades.course_id = courses.id
WHERE
    course_grades.course_id = 1
ORDER BY
    course_grades.grade DESC
LIMIT 20;
   
-- Посчитаем количество студентов в каждой группе и отсортируем по возрастанию номера группы:
SELECT
    group_id,
    groups.full_name AS group_name,
    COUNT(*) AS number_of_students
FROM
    students
JOIN
	groups ON students.group_id = groups.id
GROUP BY
    group_id, group_name
ORDER BY
    group_id ASC
LIMIT 10;

-- Посчитаем другим способом:
SELECT
    full_name,
    array_length(students_ids, 1) AS student_count
FROM
    groups;
-- Видим, что данные не согласовываны. На таком уровне надо либо прописывать триггер, для проверки, что в students_ids
-- действительно студенты, у которых в таблице students задана группа. Либо сразу задавать номальную архитектуру.
-- ИМХО можно вообще не использовать поле students_ids и выводить нужные данные по количеству и соответствию студенту группе по таблице students.
    
   
 -- Выведем студентов из первой группы и отсортируем от большего числа предметов к меньшему:
 SELECT
    first_name,
    last_name,
    courses_ids
FROM
    students
WHERE
    group_id = 1
ORDER BY
    array_length(courses_ids, 1) DESC
LIMIT 20;


--Выберем студентов с оценкой A по математике и отсортируем от большего балла к меньшему:
SELECT
    courses.name AS subject,
    students.first_name || ' ' || students.last_name AS stunt_full_name,
    course_grades.grade,
    course_grades.grade_str
FROM
    course_grades course_grades
JOIN
    students ON course_grades.student_id = students.id
JOIN
    courses ON course_grades.course_id = courses.id
WHERE
    course_grades.course_id = 1 AND course_grades.grade_str = 'A'
ORDER BY
    course_grades.grade DESC
LIMIT 20;

-- Выведем название предмета, номер группы, имя, фамилию студента, который его посещает. Отсортируем сначала по названию предмета,
-- затем по группе, затем по фамилии и по имени студента.
WITH expanded_courses AS (
    SELECT
        first_name,
        last_name,
        group_id,
        unnest(courses_ids::integer[]) AS course_id
    FROM
        students
)
SELECT
    courses.name AS course_name,
    expanded_courses.group_id,
    expanded_courses.first_name,
    expanded_courses.last_name
FROM
    expanded_courses
JOIN
    courses ON expanded_courses.course_id = courses.id
ORDER BY
    courses.name,
    expanded_courses.group_id,
    expanded_courses.last_name,
    expanded_courses.first_name
LIMIT 100;