# spbu-db-hw

# Описание финального проекта:
Магазин зоотоваров специализируется на продаже кормов, игрушек, аксессуаров, лекарств и других товаров для животных. Предприятие работает с разнообразным ассортиментом продукции, которым необходимо эффективно управлять на всех этапах: от заказа у поставщиков и хранения на складе до продажи конечным клиентам.

Для успешного функционирования требуется система управления складом, которая учитывает специфику хранения зоотоваров (например, требования к температуре и влажности), а также поддерживает процесс продаж, мониторинг остатков, учет списаний и управление заявками на закупку.

# Основные сущности

## Каталог товаров:
Содержит полную информацию о товарах, включая состав, срок годности, бренд, цену и категорию.
Товары классифицируются по категориям, таким как, например, корма, игрушки и лекарства, каждая из которых имеет свои условия хранения.

## Складская система:
Разделена на зоны хранения, каждая из которых предназначена для определенного типа продукции и имеет свои требования по температуре и влажности.
Зоны хранения делятся на ячейки, что позволяет точно отслеживать местоположение каждой партии товара.

## Учет партий товаров:

На каждом товаре есть штрих-код. Штрих-код содержит в себе информацию о партии. Штрих-код описывает партию товара, два товара с одинаковым штрихкодом считаются идентичными, т.к. являются одними и теми же товарами из одной партии. Если товары имеют разные штрихкоды, но одинаковый номер в каталоге товаров, то это одинаковые товары, но из разных партий, соответственно, могут иметь разные даты производства.

## Продажи:

Отслеживаются через систему чеков, в которых также указан продавец, проводивший операцию. В чеке указывается дата, время и детали проданных товаров.

## Заказы поставщикам:

Управление заявками на закупку товаров. Каждая заявка включает дату подачи, предполагаемую дату доставки, составителя заявки и список заказанных товаров.
Статусы заявок позволяют отслеживать их выполнение (например, "Новый", "В пути", "Доставлен").

## Списание товаров:

Включает учет поврежденных, просроченных или ненужных товаров с указанием причины списания, ответственного сотрудника, даты и времени.

## Мониторинг температуры и влажности:

Отслеживание условий хранения в каждой зоне склада. Отклонения от установленных норм фиксируются и подлежат анализу.

# Основные бизнес-процессы

## Управление складом:

Приемка товаров от поставщиков и распределение их по ячейкам хранения.
Контроль соответствия условий хранения установленным нормам (температура, влажность).
Регулярный учет остатков товаров и их перемещение между ячейками при необходимости.

## Продажа товаров:

Продавцы формируют чеки на основании запросов клиентов. Все данные о продажах фиксируются, что позволяет анализировать прибыль, популярность товаров и эффективность продавцов.

## Закупки у поставщиков:

Создание заявок на закупку товаров на основе данных о текущих остатках, ожидаемом спросе и запланированных акциях.
Контроль за выполнением заявок, включая сроки поставок и их соответствие заказанным объемам.

## Списание товаров:

Учет товаров, подлежащих списанию, с указанием причин. Анализ данных о списании позволяет выявить проблемы в логистике, хранении или спросе на товар.

## Анализ данных:

Анализ продаж, остатков на складе, списаний и заказов для оптимизации ассортимента и повышения прибыли.
Выявление проблемных зон хранения, где условия часто не соответствуют требованиям.

# Пользователи системы

## Менеджеры:
Отслеживают продажи, остатки, показатели работы склада и магазинов.
Создают заявки на заказ товаров, контролируют их выполнение и анализируют эффективность работы поставщиков.

## Продавцы:
Отвечают за приемку, размещение и учет товаров на складе, а также за списание поврежденных или просроченных партий.
Работают с клиентами, формируют чеки и обрабатывают возвраты.
Создают заявки на заказ товаров.

## Руководство:

Использует данные для принятия стратегических решений, таких как планирование ассортимента, ценообразование и оптимизация логистики.

# Задачи, которые решаит система
Учет товаров на всех этапах их жизненного цикла: от поставки до продажи или списания.
Поддержание оптимального запаса товаров на складе.
Обеспечение соответствия условий хранения установленным стандартам.
Ускорение и автоматизация процессов учета, продаж и аналитики.
Минимизация потерь из-за порчи или просрочки товаров.
Улучшение обслуживания клиентов за счет оптимального управления запасами и анализа продаж.

Cистема поможет магазину зоотоваров эффективно управлять своими ресурсами, оптимизировать операции и принимать решения на основе данных.