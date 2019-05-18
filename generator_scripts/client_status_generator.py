import random
import time

def strTimeProp(start, end, format, prop):
    stime = time.mktime(time.strptime(start, format))
    etime = time.mktime(time.strptime(end, format))
    ptime = stime + prop * (etime - stime)
    return time.strftime(format, time.localtime(ptime))


def randomDate(start, end, prop):
    return strTimeProp(start, end, '%d-%m-%Y', prop)

random.seed(a=322)

with open('client_status.sql', 'w') as output:
    output.write('SET SEARCH_PATH = crypto_exchange;\n\n')
    output.write('INSERT INTO client_status (client_id, verified_flg, frozen_flg, status_code, valid_from, valid_to)\nVALUES\n')
    for i in range(1, 51):
        query = '''  ({}, {}, {}, {}, '{}', '{}'),\n'''.format(i, 'TRUE', 'FALSE', random.randint(1, 4), randomDate('1-4-2019', '31-5-2019', random.random()), '01-01-9999')
        output.write(query)
    output.write('''  ({}, {}, {}, {}, '{}', '{}'),\n'''.format(5, 'TRUE', 'FALSE', random.randint(1, 4), randomDate('1-6-2019', '5-6-2019', random.random()), '01-01-9999'))
    output.write('''  ({}, {}, {}, {}, '{}', '{}'),\n'''.format(11, 'TRUE', 'FALSE', random.randint(1, 4), randomDate('1-6-2019', '5-6-2019', random.random()), '01-01-9999'))
