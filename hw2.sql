-- 1. Создать промежуточные таблицы:
-- student_courses — связывает студентов с курсами. Поля: id, student_id, course_id.
-- group_courses — связывает группы с курсами. Поля: id, group_id, course_id.
-- Заполнить эти таблицы данными, чтобы облегчить работу с отношениями «многие ко многим».
-- Должно гарантироваться уникальное отношение соответствующих полей (ключевое слово UNIQUE).
   
 
-- Таблица для связи студентов с курсами
CREATE TABLE student_courses (
    id SERIAL PRIMARY KEY,
    student_id INT REFERENCES students(id),
    course_id INT REFERENCES courses(id),
    UNIQUE(student_id, course_id)
);

-- Таблица для связи групп с курсами
CREATE TABLE group_courses (
    id SERIAL PRIMARY KEY,
    group_id INT REFERENCES groups(id),
    course_id INT REFERENCES courses(id),
    UNIQUE(group_id, course_id)
);

-- Заполнение данными
INSERT INTO student_courses (student_id, course_id)
VALUES
    (1, 1), (1, 2),
    (2, 3), (2, 4),
    (3, 5), (3, 6),
    (4, 7), (4, 8),
    (5, 1), (5, 3),
    (6, 2), (6, 4),
    (7, 5), (7, 6),
    (8, 7), (8, 8),
    (9, 1), (9, 2),
    (10, 3), (10, 4),
    (11, 5), (11, 6),
    (12, 7), (12, 8),
    (13, 1), (13, 2),
    (14, 3), (14, 4),
    (15, 5), (15, 6),
    (16, 7), (16, 8),
    (17, 1), (17, 2),
    (18, 3), (18, 4),
    (19, 5), (19, 6),
    (20, 7), (20, 8);
   
SELECT * FROM student_courses LIMIT 50;

INSERT INTO group_courses (group_id, course_id)
VALUES
    (1, 1), (1, 2), (1, 3),
    (2, 2), (2, 4), (2, 6),
    (3, 3), (3, 7), (3, 8),
    (4, 1), (4, 5);

SELECT * FROM group_courses LIMIT 20;

-- Удаление лишних полей:

-- Соответствие студент-группа будем брать из таблицы students
ALTER TABLE groups DROP COLUMN students_ids;
SELECT * FROM groups LIMIT 5;

-- Соответствие студент-курс будем брать из таблицы student_courses
ALTER TABLE students DROP COLUMN courses_ids;
SELECT * FROM students LIMIT 5;

-- 2. Добавить в таблицу courses уникальное ограничение на поле name, чтобы не допустить дублирующих названий курсов.
-- Создать индекс на поле group_id в таблице students и объяснить, как индексирование влияет на производительность запросов
-- (Комментариями в коде).

-- Добавим ограничение на поле name:
ALTER TABLE courses ADD CONSTRAINT unique_course_name UNIQUE (name);

-- Проверим, что оно работает верно:
INSERT INTO courses (name, is_exam, min_grade, max_grade)
values ('Математика', TRUE, 60, 100);

-- Получаем ошибку. Значит, все верно.

-- Создадим индекс:
CREATE INDEX idx_students_group_id ON students (group_id);

-- Когда выполняется запрос поиска по полю group_id индекс позволяет БД найти строки без полного сканирования всей таблицы.
-- Т.е. индекс работает как оглавление книги, позволяя найти нужную страницу, не листая всю книгу.
-- Т.к. индексы обычно хранятся в упорядоченном виде, при сортировке результатов по проиндексированному полю, процесс проходит быстрее.
-- При операциях соединения таблиц индекс ускоряет процесс сопоставления таблиц, т.к. нет необходимости сканировать обе таблицы полностью.
-- Но индекссы занимают дополнительное пространство на дисков, а операции вставки, удаления и обновления данных замедляются, т.к. необходимо 
-- помимо изменения данных обновлять индексы.

-- 3. Написать запрос, который покажет список всех студентов с их курсами.
-- Найти студентов, у которых средняя оценка по курсам выше, чем у любого другого студента в их группе.
-- (Ключевые слова JOIN, GROUP BY, HAVING)


-- Добавим данных:
INSERT INTO course_grades (course_id, student_id, grade, grade_str)
VALUES
(2, 1, 50, 'F'),
(2, 2, 60, 'F'),
(2, 3, 70, 'C'),
(2, 4, 80, 'B'),
(2, 5, 90, 'A'),
(2, 6, 100, 'A'),
(2, 7, 60, 'F'),
(2, 8, 70, 'C'),
(2, 9, 80, 'B'),
(2, 10, 90, 'A'),
(2, 11, 100, 'A'),
(2, 12, 60, 'F'),
(2, 13, 70, 'C'),
(2, 14, 80, 'B'),
(2, 15, 90, 'A'),
(2, 16, 100, 'A'),
(2, 17, 60, 'F'),
(2, 18, 70, 'C'),
(2, 19, 80, 'B'),
(2, 20, 90, 'A'),
(3, 1, 70, 'C'),
(3, 2, 80, 'B'),
(3, 3, 90, 'A'),
(3, 4, 100, 'A'),
(3, 5, 70, 'C'),
(3, 6, 80, 'B'),
(3, 7, 90, 'A'),
(3, 8, 100, 'A'),
(3, 9, 70, 'C'),
(3, 10, 80, 'B'),
(3, 11, 90, 'A'),
(3, 12, 100, 'A'),
(3, 13, 70, 'C'),
(3, 14, 80, 'B'),
(3, 15, 90, 'A'),
(3, 16, 100, 'A'),
(3, 17, 70, 'C'),
(3, 18, 80, 'B'),
(3, 19, 90, 'A'),
(3, 20, 100, 'A'),
(4, 1, 40, 'F'),
(4, 2, 50, 'F'),
(4, 3, 60, 'F'),
(4, 4, 70, 'C'),
(4, 5, 80, 'B'),
(4, 6, 90, 'A'),
(4, 7, 40, 'F'),
(4, 8, 50, 'F'),
(4, 9, 60, 'F'),
(4, 10, 70, 'C'),
(4, 11, 80, 'B'),
(4, 12, 90, 'A'),
(4, 13, 40, 'F'),
(4, 14, 50, 'F'),
(4, 15, 60, 'F'),
(4, 16, 70, 'C'),
(4, 17, 80, 'B'),
(4, 18, 90, 'A'),
(4, 19, 40, 'F'),
(4, 20, 50, 'F');


TRUNCATE TABLE student_courses;

INSERT INTO student_courses (student_id, course_id)
VALUES
    (1, 1), (1, 2), (1, 3), (1, 4),
    (2, 1), (2, 2), (2, 3), (2, 4),
    (3, 1), (3, 2), (3, 3), (3, 4),
    (4, 1), (4, 2), (4, 3), (4, 4),
    (5, 1), (5, 2), (5, 3), (5, 4),
    (6, 1), (6, 2), (6, 3), (6, 4),
    (7, 1), (7, 2), (7, 3), (7, 4),
    (8, 1), (8, 2), (8, 3), (8, 4),
    (9, 1), (9, 2), (9, 3), (9, 4),
    (10, 1), (10, 2), (10, 3), (10, 4),
    (11, 1), (11, 2), (11, 3), (11, 4),
    (12, 1), (12, 2), (12, 3), (12, 4),
    (13, 1), (13, 2), (13, 3), (13, 4),
    (14, 1), (14, 2), (14, 3), (14, 4),
    (15, 1), (15, 2), (15, 3), (15, 4),
    (16, 1), (16, 2), (16, 3), (16, 4),
    (17, 1), (17, 2), (17, 3), (17, 4),
    (18, 1), (18, 2), (18, 3), (18, 4),
    (19, 1), (19, 2), (19, 3), (19, 4),
    (20, 1), (20, 2), (20, 3), (20, 4);

-- Список студентов с их курсами:
SELECT
    students.id AS student_id,
    students.first_name || ' ' || students.last_name AS full_name,
    courses.name AS course_name
FROM
    students
JOIN
    student_courses ON students.id = student_courses.student_id
JOIN
    courses ON student_courses.course_id = courses.id
ORDER BY
    students.id, courses.name
LIMIT 200;
    
-- Студенты, у которых средняя оценка по курсам выше, чем у любого другого студента в их группе:
SELECT
    students.id AS student_id,
    students.first_name,
    students.last_name,
    students.group_id,
    AVG(course_grades.grade) AS average_grade
FROM
    students
JOIN
    student_courses ON students.id = student_courses.student_id
JOIN
    course_grades ON student_courses.course_id = course_grades.course_id
                  AND student_courses.student_id = course_grades.student_id
GROUP BY
    students.id, students.first_name, students.last_name, students.group_id
HAVING
    AVG(course_grades.grade) > ALL (
        SELECT
            AVG(course_grades_2.grade)
        FROM
            students students_2
        JOIN
            student_courses student_courses_2 ON students_2.id = student_courses_2.student_id
        JOIN
            course_grades course_grades_2 ON student_courses_2.course_id = course_grades_2.course_id
                                          AND student_courses_2.student_id = course_grades_2.student_id
        WHERE
            students_2.group_id = students.group_id
            AND students_2.id <> students.id
        GROUP BY
            students_2.id
    )
ORDER BY
    students.group_id, students.id
LIMIT 100;
    
-- 4. Подсчитать количество студентов на каждом курсе.
-- Найти среднюю оценку на каждом курсе.
   
-- Количество студентов на каждом курсе:
SELECT course_id, COUNT(*) AS count_of_students
FROM student_courses
GROUP BY course_id
ORDER BY course_id
LIMIT 30;

-- Найдем среднюю оценку на каждом курсе.
SELECT course_id, courses.name, AVG(grade) AS average_grade
FROM course_grades
JOIN courses ON course_grades.course_id = courses.id
GROUP BY course_id, courses.name
ORDER BY course_id
LIMIT 10;