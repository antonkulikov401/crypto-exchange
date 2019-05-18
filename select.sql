SET SEARCH_PATH = crypto_exchange;


/* ЗАПРОС 1. ПОДСЧИТАТЬ ПРИБЫЛЬ БИРЖИ СО СПРЕДОВ И КОММИССИИ ЗА 01-07-2019 С 12:30 ДО 13:00 */

WITH profit_info AS (
  SELECT c.currency_nm as coin, cast(sum(abs(o1.price_rate - o2.price_rate)) AS DECIMAL(15, 12)) as spread,
         cast(sum(o1.order_amt * fr1.fee_rate / 100 + o2.order_amt * fr2.fee_rate / 100) AS DECIMAL(15, 12)) as fee
  FROM transaction t
  INNER JOIN "order" o1
    ON t.order_a_id = o1.order_id
  INNER JOIN "order" o2
    ON t.order_b_id = o2.order_id
  INNER JOIN account a1
    ON o1.account_id = a1.account_id
  INNER JOIN account a2
    ON o2.account_id = a2.account_id
  INNER JOIN client c1
    ON a1.client_id = c1.client_id
  INNER JOIN client c2
    ON a2.client_id = c2.client_id
  INNER JOIN client_status cs1
    ON c1.client_id = cs1.client_id
  INNER JOIN client_status cs2
    ON c2.client_id = cs2.client_id
  INNER JOIN fee_rate fr1
    ON cs1.status_code = fr1.status_code
  INNER JOIN fee_rate fr2
    ON cs2.status_code = fr2.status_code
  INNER JOIN currency c
    ON o1.order_currency_id = c.currency_id
  WHERE t.transaction_dttm BETWEEN '01-07-2019 12:30:00' AND '01-07-2019 13:00:00'
  GROUP BY c.currency_nm)
SELECT coin, spread, fee, spread + fee AS total
FROM profit_info;


/* ЗАПРОС 2. НАЙТИ ОБЪЕМ ТОРГОВ, НАИБОЛЬШУЮ И НАИМЕНЬШУЮ ЦЕНЫ ETH/BTC за 01-07-2019 */

SELECT sum(o1.order_amt) AS volume, max(o1.price_rate) AS high, min(o1.price_rate) AS low
FROM transaction t
  INNER JOIN "order" o1
    ON t.order_a_id = o1.order_id
  INNER JOIN "order" o2
    ON t.order_b_id = o2.order_id
  INNER JOIN currency c1
    ON o1.order_currency_id = c1.currency_id
  INNER JOIN currency c2
    ON o2.order_currency_id = c2.currency_id
WHERE c1.currency_cd = 'eth' AND c2.currency_cd = 'btc' AND
      date(t.transaction_dttm) = '01-07-2019';


/* ЗАПРОС 3. ОПРЕДЕЛИТЬ ПРИБЫЛЬ КАЖДОГО АКТИВНОГО (ВЕРИФИЦИРОВАННОГО И НЕЗАМОРОЖЕННОГО) ТРЕЙДЕРА НА ТЕКУЩИЙ МОМЕНТ */

CREATE EXTENSION tablefunc; /* для использования функции crosstab */

SELECT first_nm || ' ' || second_nm AS name, btc, bch, eth, ltc
FROM crosstab('
SELECT a.client_id, cur.currency_cd, a.balance_amt - income AS income
FROM client c
  INNER JOIN client_status cs
    ON c.client_id = cs.client_id
  INNER JOIN account a
    ON c.client_id = a.client_id
  INNER JOIN currency cur
    ON a.currency_id = cur.currency_id
  INNER JOIN (
    SELECT account_id, sum(CASE WHEN operation_code = ''WITHDRAWAL''
                                THEN -operation_amt ELSE operation_amt END) AS income
    FROM transfer_operation
    GROUP BY account_id) emerged
    ON a.account_id = emerged.account_id
WHERE cs.valid_to = ''01-01-9999''
    AND cs.verified_flg = TRUE
    AND cs.frozen_flg = FALSE
ORDER BY a.client_id, cur.currency_cd') AS data(client_id INTEGER, bch DECIMAL(18, 12), btc DECIMAL(18, 12),
                                                eth DECIMAL(18, 12), ltc DECIMAL(18, 12))
  INNER JOIN client
    ON data.client_id = client.client_id;


/* ЗАПРОС 4. ВЫВЕСТИ ORDER-BOOK ТОРГОВОЙ ПАРЫ BCH/BTC */

SELECT order_type_code, order_amt, order_dttm
FROM "order" o
  INNER JOIN order_status os
    ON o.order_id = os.order_id AND os.valid_to = '01-01-9999'
  INNER JOIN account a
    ON o.account_id = a.account_id
WHERE CASE WHEN order_type_code = 'BUY'
  THEN order_currency_id = 4 AND a.currency_id = 1
  ELSE order_currency_id = 1 AND a.currency_id = 4
  END AND os.order_status_code = 'ACTIVE'
ORDER BY order_dttm DESC
LIMIT 10;


/* ЗАПРОС 5. ОПРЕДЕЛИТЬ КОРРЕЛЯЦИЮ ЦЕН LTC И ETH (В BTC) ЗА 01-07-2019 С 12:00 ДО 13:00,
   ИСПОЛЬЗУЯ СРЕДНЕЕ ЗА 2 ПОСЛЕДНИЕ ТРАНЗАКЦИИ */

SELECT cast((sum(avg1 * avg2) - sum(avg1) * sum(avg2) / count(*)) /
       sqrt((sum(avg1 * avg1) - sum(avg1) * sum(avg1) / count(*)) *
            (sum(avg2 * avg2) - sum(avg2) * sum(avg2) / count(*))) AS DECIMAL(5, 3)) AS pearson_corr
FROM (
  SELECT row_number() OVER () AS rn, avg(o.price_rate)
    OVER (ORDER BY o.order_dttm ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS avg1
  FROM "order" o
    INNER JOIN account a
      ON o.account_id = a.account_id
  WHERE o.order_currency_id = 1 AND a.currency_id = 2 AND o.order_type_code = 'BUY' AND
        o.order_dttm BETWEEN '01-07-2019 12:00:00' AND '01-07-2019 13:00:00') t1
INNER JOIN (
  SELECT row_number() OVER () AS rn, avg(o.price_rate)
    OVER (ORDER BY o.order_dttm ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS avg2
  FROM "order" o
    INNER JOIN account a
      ON o.account_id = a.account_id
  WHERE o.order_currency_id = 1 AND a.currency_id = 3 AND o.order_type_code = 'BUY' AND
        o.order_dttm BETWEEN '01-07-2019 12:00:00' AND '01-07-2019 13:00:00') t2
    ON t1.rn = t2.rn;