import random
import time
import string

def strTimeProp(start, end, format, prop):
    stime = time.mktime(time.strptime(start, format))
    etime = time.mktime(time.strptime(end, format))
    ptime = stime + prop * (etime - stime)
    return time.strftime(format, time.localtime(ptime))

def random_string(stringLength=32):
    lettersAndDigits = string.ascii_letters + string.digits
    return ''.join(random.choice(lettersAndDigits) for i in range(stringLength))

def randomDate(start, end, prop):
    return strTimeProp(start, end, '%d-%m-%Y %H:%M:%S', prop)

random.seed(a=5)

order_type = ['BUY', 'SELL']
ac = {}
rates = {'1': {}, '2': {}, '3': {}, '4': {}}

with open('account_x_currency.txt', 'r') as f:
    data = f.read().splitlines()
    for x in data:
        ac[int(x.split()[0])] = int(x.split()[1])

with open('rates.txt', 'r') as f:
    data = f.read().splitlines()
    for x in data:
        t1, t2 = x.split(':')
        y1, y2 = t1.split('-')
        rates[y1][y2] = float(t2)

with open('order.sql', 'w') as output:
    output.write('''SET SEARCH_PATH = crypto_exchange;\n\nINSERT INTO "order" (account_id, order_type_code, order_amt, order_currency_id, price_rate, order_dttm, expiration_dttm)\nVALUES\n''')
    for i in range(1, 201):
        ch = random.choice(order_type)
        cur = random.choice(list({1, 2, 3, 4} - set([ac[i]])))
        # print(str(ac[i]) + ' ' + str(cur))
        x = rates[str(cur)][str(ac[i])] if ch == 'SELL' else rates[str(ac[i])][str(cur)]
        price = random.uniform(0.97*x, 1.03*x)
        # print('price from ' + str(cur) + ' to ' + str(ac[i]) + ' = ' + str(price))
        query = '''  ({}, '{}', {}, {}, {}, '{}', '{}'),\n'''.format(i, ch, 0.0000005, cur, price, randomDate('01-7-2019 12:0:0', '01-7-2019 13:0:0', random.random()), '03-7-2019 0:0:0')

        output.write(query)
    for i in range(1, 5):
        ch = random.choice(order_type)
        cur = random.choice(list({1, 2, 3, 4} - set([ac[i]])))
        x = rates[str(cur)][str(ac[i])] if ch == 'SELL' else rates[str(ac[i])][str(cur)]
        price = random.uniform(0.97*x, 1.03*x)
        query = '''  ({}, '{}', {}, {}, {}, '{}', '{}'),\n'''.format(i, ch, 15.54247, cur, price, randomDate('01-7-2019 12:0:0', '01-7-2019 13:0:0', random.random()), '03-7-2019 0:0:0')

        output.write(query)

