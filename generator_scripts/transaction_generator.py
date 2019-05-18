import psycopg2

hostname = 'localhost'
username = 'postgres'
password = 'postgres'
database = 'postgres'

output = open('transaction.sql', 'w')
conn = psycopg2.connect(host=hostname, user=username, password=password, dbname=database)

output.write('SET SEARCH_PATH = crypto_exchange;\n\n')

for i in range(10):
    cur = conn.cursor()
    cur.execute('''
SET SEARCH_PATH = crypto_exchange;
SELECT cid1, cid2, oo1.order_id, oo2.order_id, buy_price, sell_price, greatest(oo1.order_dttm, oo2.order_dttm) + INTERVAL '3 seconds'
FROM (
SELECT o1.order_currency_id as cid1, o2.order_currency_id as cid2, max(o1.price_rate) as buy_price, min(o2.price_rate) as sell_price
FROM ("order" o1 inner join account a1 on o1.account_id = a1.account_id)
       INNER JOIN ("order" o2 inner join account a2 on o2.account_id = a2.account_id)
                  ON o1.order_type_code = 'BUY' AND o2.order_type_code = 'SELL' AND
                     o1.order_currency_id = a2.currency_id AND a1.currency_id = o2.order_currency_id AND
                     o1.price_rate >= o2.price_rate AND o1.order_amt = o2.order_amt
       INNER JOIN order_status os1 ON os1.order_id = o1.order_id AND os1.valid_to = '01-01-9999' AND os1.order_status_code = 'ACTIVE'
       INNER JOIN order_status os2 ON os2.order_id = o2.order_id AND os2.valid_to = '01-01-9999' AND os2.order_status_code = 'ACTIVE'
GROUP BY o1.order_currency_id, o2.order_currency_id) as t
INNER JOIN "order" oo1 on buy_price = oo1.price_rate
INNER JOIN "order" oo2 on sell_price = oo2.price_rate;
    ''')

    for x in cur.fetchall():
        query = '''INSERT INTO transaction (order_a_id, order_b_id, transaction_dttm) VALUES ({}, {}, '{}');'''.format(x[2], x[3], x[6])
        output.write(query + '\n')
        cur.execute(query)
        

output.close()
conn.close()
