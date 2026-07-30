/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Свечникова Дарья Алексеевна
 * Дата: 17.11.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(DISTINCT id) AS total_users, --общее количество игроков, зарегистрированных в игре
	   SUM(payer) AS payer_users,--количество платящих игроков
	   SUM(payer)/COUNT(DISTINCT id)::numeric AS share_users --доля платящих игроков от общего количества пользователей, зарегистрированных в игре
FROM fantasy.users;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT DISTINCT race, -- раса персонажа
  	   SUM(payer) AS payer_race_users, -- количество платящих игроков этой расы
  	   COUNT(id) AS total_race_users, -- общее количество зарегистрированных игроков этой расы
	   SUM(payer)/COUNT(id)::numeric AS share_race -- доля платящих игроков среди всех зарегистрированных игроков этой расы
FROM fantasy.users AS u
LEFT JOIN fantasy.race r ON u.race_id = r.race_id
GROUP BY race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) AS count_transaction, --общее количество покупок
	   SUM(amount) AS sum_amount, --суммарная стоимость всех покупок
	   MIN(amount) AS min_amount, -- минимальная стоимость покупки
	   MAX(amount) AS max_amount, -- максимальная стоимость покупки
	   AVG(amount) AS avg_amount, -- среднее значение стоимости покупки
	   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amoint, --медиана стоимости покупки
	   STDDEV(amount) AS stddev_amount --стандартное отклонение стоимости покупки
FROM fantasy.events; 
-- 2.2: Аномальные нулевые покупки:
SELECT SUM(CASE WHEN amount=0 THEN 1 ELSE 0 END) AS zero_amount, --количество покупок с нулевой стоимостью
	   SUM(CASE WHEN amount=0 THEN 1 ELSE 0 END)/COUNT(transaction_id)::numeric AS share_zero_amount --доля покупок с нулевой стоимостью от общего числа покупок
FROM fantasy.events;
-- 2.3: Популярные эпические предметы:
WITH 
not_null AS (SELECT item_code,
   					id
    		 FROM fantasy.events
       		 WHERE amount > 0), -- фильрация покупок с нулевой стоимостью
transaction AS (SELECT DISTINCT item_code,
            		   COUNT(*)OVER(PARTITION BY item_code) AS absolute_transaction,
            		   COUNT(*)OVER(PARTITION BY item_code)::NUMERIC/COUNT(*)OVER() AS relative_transaction
      			FROM not_null),
users AS (SELECT item_code,
        		 COUNT(DISTINCT id) AS item_users  -- уникальные пользователи, купившие предмет
   		 FROM not_null 
         GROUP BY item_code)
SELECT
    i.game_items,
    t.item_code,
    t.absolute_transaction, --Общее количество внутриигровых продаж в абсолютном значении
    t.relative_transaction, ----Общее количество внутриигровых продаж в относительном значении
    u.item_users::numeric / (SELECT COUNT(DISTINCT id) FROM not_null) AS share_users -- доля уникальных пользователей,которые хотя бы раз покупали этот предмет, от общего числа внутриигровых покупателей
FROM transaction t
LEFT JOIN users u ON t.item_code = u.item_code
LEFT JOIN fantasy.items i  ON u.item_code = i.item_code
ORDER BY t.absolute_transaction DESC;
-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH 
race_total_users AS (SELECT COUNT(DISTINCT id) AS total_users,--общее количество зарегистрированных игроков по расе
      		   				race_id
					 FROM fantasy.users 
      		         GROUP BY race_id),
race_users AS (SELECT u.race_id,
					  COUNT(DISTINCT e.id) AS users_buy,---- количество игроков, совершивших покупки
					  COUNT(DISTINCT CASE WHEN u.payer=1 THEN e.id END)::numeric/COUNT(DISTINCT e.id) AS share_paying,-- доля платящих среди покупавших
					  COUNT(e.transaction_id) AS count_transaction,-- общее количество покупок
					  SUM(e.amount) AS sum_amount,-- общая сумма покупок
					  AVG(e.amount) AS avg_amount_per_purchase-- средняя стоимость одной покупки
			   FROM fantasy.events e 
			   LEFT JOIN fantasy.users u ON e.id = u.id
			   WHERE e.amount<>'0'
			   GROUP BY u.race_id)
SELECT r.race,
	   rtu.race_id,
	   rtu.total_users,
	   ru.users_buy,
	   ru.users_buy::numeric/rtu.total_users AS share_buy, -- доля покупавших от общего числа
	   ru.share_paying,
	   ru.count_transaction::numeric/ru.users_buy AS avg_transaction_per_user, -- среднее кол-во покупок на игрока
	   ru.avg_amount_per_purchase,
	   ru.sum_amount::numeric/ru.users_buy AS avg_sum_amount_per_user -- средняя суммарная стоимость на игрока
FROM race_total_users rtu
LEFT JOIN race_users ru ON rtu.race_id = ru.race_id
LEFT JOIN fantasy.race r ON ru.race_id=r.race_id
ORDER BY rtu.race_id;
