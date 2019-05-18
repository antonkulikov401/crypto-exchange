SET SEARCH_PATH = crypto_exchange;



/* ФУНКЦИИ, МАСКИРУЮЩИЕ ДАННЫЕ */

CREATE OR REPLACE FUNCTION mask(data text)
RETURNS text AS $$
  DECLARE
    len INTEGER := length(data);
  BEGIN
    IF len <= 4 THEN
      RETURN repeat('*', len);
    ELSE
      RETURN substr(data, 1, 2) || repeat('*', len - 4) || substr(data, len - 1, 2);
    END IF;
  END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION mask_email(email text)
RETURNS text AS $$
  BEGIN
    RETURN crypto_exchange.mask(substr(email, 1, position('@' in email) - 1)) || substring(email from position('@' in email));
  END;
$$ LANGUAGE plpgsql
RETURNS NULL ON NULL INPUT;



/* ПРЕДСТАВЛЕНИЯ, СКРЫВАЮЩИЕ СЕКРЕТНУЮ ИНФОРМАЦИЮ */

CREATE OR REPLACE VIEW account_view AS
  SELECT (first_nm || ' ' || second_nm) AS trader, currency_nm, mask(wallet_no) AS wallet_no, balance_amt
  FROM account
    INNER JOIN client
      ON account.client_id = client.client_id
    INNER JOIN currency
      ON account.currency_id = currency.currency_id;


CREATE OR REPLACE VIEW client_view AS
  SELECT (first_nm || ' ' || second_nm) AS name, mask(phone_no), country_cd, mask_email(email),
         mask(passport_series) || ' ' || mask(passport_no) AS passport
  FROM client;


CREATE OR REPLACE VIEW client_status_view AS
  SELECT (first_nm || ' ' || second_nm) AS trader, verified_flg, frozen_flg, status_code
  FROM client_status
    INNER JOIN client
      ON client_status.client_id = client.client_id
  WHERE valid_to = '01-01-9999';


CREATE OR REPLACE VIEW currency_view AS
  SELECT currency_cd AS code, currency_nm AS name
  FROM currency;


CREATE OR REPLACE VIEW fee_rate_view AS
  SELECT status_nm AS name, cast(cast(fee_rate AS DECIMAL(3, 2)) AS text) || '%' AS fee
  FROM fee_rate;


CREATE OR REPLACE VIEW order_view AS
  SELECT order_id, order_type_code, c1.currency_cd || '/' || c2.currency_cd AS trading_pair,
         price_rate, order_dttm, expiration_dttm
  FROM "order"
    INNER JOIN account a
      ON "order".account_id = a.account_id
    INNER JOIN currency c2
      ON "order".order_currency_id = c2.currency_id
    INNER JOIN currency c1
      ON a.currency_id = c1.currency_id;


CREATE OR REPLACE VIEW order_status_view AS
  SELECT order_id, order_status_code
  FROM order_status
  WHERE valid_to = '01-01-9999';


CREATE OR REPLACE VIEW transaciton_view AS
  SELECT order_a_id AS buy_order, order_b_id AS sell_order, transaction_dttm
  FROM transaction;


CREATE OR REPLACE VIEW transfer_operation_view AS
  SELECT (first_nm || ' ' || second_nm) AS trader, currency_cd, operation_code, operation_amt,
         mask(wallet_no) AS wallet_no, mask(external_wallet_no) AS external_wallet_no, operation_dttm
  FROM transfer_operation
    INNER JOIN account
      ON transfer_operation.account_id = account.account_id
    INNER JOIN client
      ON account.client_id = client.client_id
    INNER JOIN currency
      ON account.currency_id = currency.currency_id;



/* СЛОЖНОЕ ПРЕДСТАВЛЕНИЕ 1. ДЛЯ КАЖДОЙ ТОРГОВОЙ ПАРЫ ОПРЕДЕЛИТЬ НИЖНИЙ, ВЕРХНИЙ КВАРТИЛИ И МЕДИАНУ ЦЕНЫ */

CREATE OR REPLACE VIEW percentiles_view AS
  SELECT c1.currency_nm || '/' || c2.currency_nm AS trading_pair,
         percentile_cont(0.25) WITHIN GROUP (ORDER BY price_rate) AS percentile25,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY price_rate) AS percentile50,
         percentile_cont(0.75) WITHIN GROUP (ORDER BY price_rate) AS percentile75
  FROM "order" o
    INNER JOIN account a
      ON o.account_id = a.account_id
    INNER JOIN currency c1
      ON a.currency_id = c1.currency_id
    INNER JOIN currency c2
      ON o.order_currency_id = c2.currency_id
    INNER JOIN order_status os
      ON o.order_id = os.order_id AND os.valid_to = '01-01-9999'
  WHERE o.order_type_code = 'BUY' AND os.order_status_code <> 'DENIED'
  GROUP BY c1.currency_nm, c2.currency_nm;



/* СЛОЖНОЕ ПРЕДСТАВЛЕНИЕ 2. ПОДСЧИТАТЬ ЦЕНУ ПОРТФЕЛЯ КАЖДОГО КЛИЕНТА В BTC НА ТЕКУЩИЙ МОМЕНТ */

CREATE OR REPLACE VIEW client_portfolio_view AS
  SELECT (first_nm || ' ' || second_nm) AS trader,
         sum(CASE
              WHEN a.currency_id = 1
              THEN a.balance_amt
              ELSE a.balance_amt * price.price_rate END) AS portfolio
  FROM client c
    INNER JOIN account a
      ON c.client_id = a.client_id
    LEFT JOIN (
      SELECT a1.currency_id, o.price_rate
      FROM "order" o
        INNER JOIN account a1
          ON o.account_id = a1.account_id
        INNER JOIN order_status os
          ON o.order_id = os.order_id AND os.valid_to = '01-01-9999'
      WHERE o.order_type_code = 'BUY' AND os.order_status_code <> 'DENIED' AND
            o.order_currency_id = 1 AND
            o.order_dttm = (SELECT max(o2.order_dttm)
                            FROM "order" o2
                            INNER JOIN account a2
                              ON o2.account_id = a2.account_id
                            INNER JOIN order_status os2
                              ON o2.order_id = os2.order_id AND os2.valid_to = '01-01-9999'
                            WHERE o2.order_type_code = 'BUY' AND os2.order_status_code <> 'DENIED'
                                  AND o2.order_currency_id = 1 AND a2.currency_id = a1.currency_id)
    ) price ON a.currency_id = price.currency_id
  GROUP BY a.client_id, c.first_nm, c.second_nm;