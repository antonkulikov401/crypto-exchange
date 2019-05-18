CREATE SCHEMA IF NOT EXISTS crypto_exchange;

SET SEARCH_PATH = crypto_exchange;

CREATE TABLE IF NOT EXISTS client (
  client_id SERIAL PRIMARY KEY,
  first_nm VARCHAR(50) NOT NULL,
  second_nm VARCHAR(50) NOT NULL,
  phone_no VARCHAR(15),
  email VARCHAR(50) NOT NULL,
  country_cd VARCHAR(3) NOT NULL,
  passport_series VARCHAR(20) NOT NULL,
  passport_no VARCHAR(20) NOT NULL
);

CREATE TABLE IF NOT EXISTS currency (
  currency_id SERIAL PRIMARY KEY,
  currency_nm VARCHAR(20) NOT NULL,
  currency_cd VARCHAR(3) NOT NULL
);

CREATE TABLE IF NOT EXISTS fee_rate (
  status_code SERIAL PRIMARY KEY,
  status_nm VARCHAR(20) NOT NULL,
  fee_rate DOUBLE PRECISION NOT NULL
);

CREATE TABLE IF NOT EXISTS account (
  account_id SERIAL PRIMARY KEY,
  client_id INTEGER REFERENCES client(client_id),
  wallet_no VARCHAR(100) NOT NULL,
  currency_id INTEGER REFERENCES currency(currency_id),
  balance_amt DECIMAL(15, 12) NOT NULL CHECK (balance_amt >= 0),
  frozen_balance_amt DECIMAL(15, 12) NOT NULL CHECK (frozen_balance_amt >= 0)
);

CREATE TABLE IF NOT EXISTS transfer_operation (
  operation_id SERIAL PRIMARY KEY,
  account_id INTEGER REFERENCES account(account_id),
  operation_code VARCHAR(13) NOT NULL CHECK (operation_code IN ('REPLENISHMENT', 'WITHDRAWAL')),
  operation_amt DECIMAL(15, 12) NOT NULL,
  external_wallet_no VARCHAR(100) NOT NULL,
  operation_dttm TIMESTAMP(0) NOT NULL
);

CREATE TABLE IF NOT EXISTS "order" (
  order_id SERIAL PRIMARY KEY,
  account_id INTEGER REFERENCES account(account_id),
  order_type_code VARCHAR(4) NOT NULL CHECK (order_type_code IN ('BUY', 'SELL')),
  order_amt DECIMAL(15, 12) NOT NULL CHECK (order_amt > 0),
  order_currency_id INTEGER REFERENCES currency(currency_id),
  price_rate DECIMAL(15, 12) NOT NULL CHECK (price_rate > 0),
  order_dttm TIMESTAMP(0) NOT NULL,
  expiration_dttm TIMESTAMP(0)
);

CREATE TABLE IF NOT EXISTS order_status (
  order_status_id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES "order"(order_id),
  order_status_code VARCHAR(9) NOT NULL CHECK (order_status_code IN ('PENDING', 'ACTIVE', 'DENIED', 'COMPLETED')),
  valid_from TIMESTAMP(0) NOT NULL,
  valid_to TIMESTAMP(0) NOT NULL
);

CREATE TABLE IF NOT EXISTS transaction (
  transaction_id SERIAL PRIMARY KEY,
  order_a_id INTEGER REFERENCES "order"(order_id),
  order_b_id INTEGER REFERENCES "order"(order_id),
  transaction_dttm TIMESTAMP(0) NOT NULL
);

CREATE TABLE IF NOT EXISTS client_status (
  client_status_id SERIAL PRIMARY KEY,
  client_id INTEGER REFERENCES client(client_id),
  verified_flg BOOLEAN NOT NULL,
  frozen_flg BOOLEAN NOT NULL,
  status_code INTEGER REFERENCES fee_rate(status_code),
  valid_from TIMESTAMP(0) NOT NULL,
  valid_to TIMESTAMP(0) NOT NULL
);