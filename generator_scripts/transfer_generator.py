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

with open('transfer_operation.sql', 'w') as output:
    output.write('SET SEARCH_PATH = crypto_exchange;\n\nINSERT INTO transfer_operation (account_id, operation_code, operation_amt, external_wallet_no, operation_dttm)\nVALUES\n')
    for i in range(1, 201):
        x = round(random.random() * 3, 8)
        y = round(random.random() * 3, 8)
        query1 = '''  ({}, '{}', {}, '{}', '{}'),\n'''.format(i, 'REPLENISHMENT', x, random_string(), randomDate('31-5-2019 0:0:0', '15-6-2019 0:0:0', random.random()))
        query2 = '''  ({}, '{}', {}, '{}', '{}'),\n'''.format(i, 'REPLENISHMENT', y, random_string(), randomDate('31-5-2019 0:0:0', '15-6-2019 0:0:0', random.random()))
        query3 = '''  ({}, '{}', {}, '{}', '{}'),\n'''.format(i, 'WITHDRAWAL', min(round(random.random() / 4, 8), x / 2), random_string(), randomDate('15-6-2019 0:0:0', '20-6-2019 0:0:0', random.random()))
        query4 = '''  ({}, '{}', {}, '{}', '{}'),\n'''.format(i, 'WITHDRAWAL', min(round(random.random() / 4, 8), y / 2), random_string(), randomDate('15-6-2019 0:0:0', '20-6-2019 0:0:0', random.random()))
        output.write(query1)
        output.write(query2)
        output.write(query3)
        output.write(query4)
