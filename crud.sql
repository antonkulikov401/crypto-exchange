SET SEARCH_PATH = crypto_exchange;


INSERT INTO fee_rate (status_nm, fee_rate)
  VALUES ('PLATINUM', 0.01);


UPDATE fee_rate
  SET fee_rate = 0.02
  WHERE status_nm = 'PLATINUM';


DELETE FROM fee_rate
  WHERE status_nm = 'PLATINUM';


SELECT *
FROM account;