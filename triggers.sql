SET SEARCH_PATH = crypto_exchange;


/* Обновляет баланс аккаунта при переводе средств с внешнего кошелька */


CREATE OR REPLACE FUNCTION transfer() RETURNS TRIGGER AS $$
  BEGIN
    UPDATE account
    SET balance_amt = balance_amt + (CASE
          WHEN new.operation_code = 'REPLENISHMENT'
          THEN new.operation_amt
          ELSE -new.operation_amt
        END)
    WHERE account_id = new.account_id;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER transfer_trigger BEFORE INSERT ON transfer_operation
  FOR EACH ROW EXECUTE PROCEDURE transfer();


/* Присваивает стутус "PENDING" только что добавленным ордерам */


CREATE OR REPLACE FUNCTION new_order() RETURNS TRIGGER AS $$
  BEGIN
    INSERT INTO order_status (order_id, order_status_code, valid_from, valid_to)
      VALUES (NEW.order_id, 'PENDING', NEW.order_dttm, '01-01-9999');
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER new_order_trigger AFTER INSERT ON "order"
  FOR EACH ROW EXECUTE PROCEDURE new_order();


/* Обрабатывает ордер, помеченный как "PENDING". В случае если баланс на аккаунте достаточный, замораживает средства
   и ставит ордеру статус "ACTIVE", иначе ордер помечается как "DENIED" */


CREATE OR REPLACE FUNCTION process_order() RETURNS TRIGGER AS $$
  DECLARE
    amount DECIMAL(15, 12) := 0;
  BEGIN

    SELECT INTO amount cast(order_amt * (1 + fr.fee_rate / 100) * (CASE WHEN order_type_code = 'BUY'
                                                                    THEN price_rate
                                                                    ELSE 1 END) AS DECIMAL(15, 12))
        FROM "order"
        INNER JOIN account a
          ON "order".account_id = a.account_id
        INNER JOIN client c
          ON a.client_id = c.client_id
        INNER JOIN client_status cs
          ON c.client_id = cs.client_id AND cs.valid_to = '01-01-9999'
        INNER JOIN fee_rate fr
          ON cs.status_code = fr.status_code
        WHERE "order".order_id = NEW.order_id;

    IF amount <= (SELECT CASE WHEN "order".order_type_code = 'BUY' THEN a2.balance_amt ELSE a.balance_amt END
                  FROM "order" INNER JOIN account a
                    ON "order".account_id = a.account_id
                  INNER JOIN client c
                    ON a.client_id = c.client_id
                  INNER JOIN account a2
                    ON c.client_id = a2.client_id AND a2.currency_id = "order".order_currency_id
                  WHERE NEW.order_id = "order".order_id) THEN

      UPDATE order_status
        SET valid_to = valid_from + INTERVAL '5 seconds'
        WHERE order_status_id = NEW.order_status_id;

      UPDATE account
        SET balance_amt = balance_amt - amount,
            frozen_balance_amt = frozen_balance_amt + amount
        WHERE account_id = (SELECT "order".account_id
                            FROM "order"
                            WHERE "order".order_id = NEW.order_id);

      INSERT INTO order_status (order_id, order_status_code, valid_from, valid_to)
        VALUES (NEW.order_id, 'ACTIVE', (SELECT valid_from FROM order_status
                                         WHERE order_id = NEW.order_id) + INTERVAL '5 seconds', '01-01-9999');

    ELSE

      UPDATE order_status
        SET valid_to = valid_from + INTERVAL '5 seconds'
        WHERE order_status_id = NEW.order_status_id;

      INSERT INTO order_status (order_id, order_status_code, valid_from, valid_to)
        VALUES (NEW.order_id, 'DENIED', (SELECT valid_from FROM order_status
                                         WHERE order_id = NEW.order_id) + INTERVAL '5 seconds', '01-01-9999');

    END IF;
    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER process_order_trigger AFTER INSERT ON order_status
  FOR EACH ROW
  WHEN (new.order_status_code = 'PENDING')
  EXECUTE PROCEDURE process_order();


/* Обновляет время валидности предыдущего статуса клиента при его изменении */


CREATE OR REPLACE FUNCTION change_client_status() RETURNS TRIGGER AS $$
  BEGIN
    IF EXISTS(SELECT 1 FROM client_status WHERE client_id = NEW.client_id) THEN
      UPDATE client_status
      SET valid_to = NEW.valid_from
      WHERE client_id = NEW.client_id AND
            valid_to = '01-01-9999';
    END IF;
    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER change_client_status_trigger BEFORE INSERT ON client_status
  FOR EACH ROW EXECUTE PROCEDURE change_client_status();


/* При добавлении транзакции помечает выполненные ордера как "COMPLETED" и переводит средства клиентам */


CREATE OR REPLACE FUNCTION transaction() RETURNS TRIGGER AS $$
  DECLARE
    buy_amount DECIMAL(15, 12) := 0;
    sell_amount DECIMAL(15, 12) := 0;
    fr1 DOUBLE PRECISION := 0;
    fr2 DOUBLE PRECISION := 0;
  BEGIN

    SELECT order_amt, fr.fee_rate INTO buy_amount, fr1
      FROM "order"
        INNER JOIN account a
          ON "order".account_id = a.account_id
        INNER JOIN client c
          ON a.client_id = c.client_id
        INNER JOIN client_status cs
          ON c.client_id = cs.client_id AND cs.valid_to = '01-01-9999'
        INNER JOIN fee_rate fr
          ON cs.status_code = fr.status_code
        WHERE "order".order_id = NEW.order_a_id;

    SELECT order_amt, fr.fee_rate INTO sell_amount, fr2
      FROM "order"
        INNER JOIN account a
          ON "order".account_id = a.account_id
        INNER JOIN client c
          ON a.client_id = c.client_id
        INNER JOIN client_status cs
          ON c.client_id = cs.client_id AND cs.valid_to = '01-01-9999'
        INNER JOIN fee_rate fr
          ON cs.status_code = fr.status_code
        WHERE "order".order_id = NEW.order_b_id;

    UPDATE order_status
      SET valid_to = NEW.transaction_dttm
      WHERE valid_to = '01-01-9999' AND order_id IN (NEW.order_a_id, NEW.order_b_id);

    INSERT INTO order_status (order_id, order_status_code, valid_from, valid_to)
    VALUES
      (NEW.order_a_id, 'COMPLETED', NEW.transaction_dttm, '01-01-9999'),
      (NEW.order_b_id, 'COMPLETED', NEW.transaction_dttm, '01-01-9999');


      UPDATE account
        SET frozen_balance_amt = frozen_balance_amt - cast(buy_amount * (1 + fr1 / 100) AS DECIMAL(15, 12)) *
                                                      (SELECT price_rate FROM "order"
                                                       WHERE order_id = NEW.order_a_id)
        WHERE account_id = (SELECT "order".account_id
                            FROM "order"
                            WHERE "order".order_id = NEW.order_a_id);

      UPDATE account
        SET balance_amt = balance_amt + buy_amount
        WHERE account_id = (SELECT a2.account_id
                            FROM "order" INNER JOIN account a ON "order".account_id = a.account_id
                            INNER JOIN client c ON a.client_id = c.client_id
                            INNER JOIN account a2 ON a2.client_id = c.client_id
                                                     AND a2.currency_id = "order".order_currency_id
                            WHERE NEW.order_a_id = "order".order_id);

      UPDATE account
        SET frozen_balance_amt = frozen_balance_amt - cast(sell_amount * (1 + fr2 / 100) AS DECIMAL(15, 12))
        WHERE account_id = (SELECT "order".account_id
                            FROM "order"
                            WHERE "order".order_id = NEW.order_b_id);

      UPDATE account
        SET balance_amt = balance_amt + sell_amount * (SELECT price_rate FROM "order"
                                                       WHERE order_id = NEW.order_b_id)
        WHERE account_id = (SELECT a2.account_id
                            FROM "order" INNER JOIN account a ON "order".account_id = a.account_id
                            INNER JOIN client c ON a.client_id = c.client_id
                            INNER JOIN account a2 ON a2.client_id = c.client_id
                                                     AND a2.currency_id = "order".order_currency_id
                            WHERE NEW.order_b_id = "order".order_id);

    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER transaction_trigger AFTER INSERT ON transaction
  FOR EACH ROW EXECUTE PROCEDURE transaction();