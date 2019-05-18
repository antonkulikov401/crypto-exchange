import random
import string

random.seed(a=322)

def random_string(stringLength=32):
    lettersAndDigits = string.ascii_letters + string.digits
    return ''.join(random.choice(lettersAndDigits) for i in range(stringLength))

with open('account.sql', 'w') as output:
    output.write('SET SEARCH_PATH = crypto_exchange;\n\n')
    output.write('''INSERT INTO account (client_id, wallet_no, currency_id, balance_amt, frozen_balance_amt)\nVALUES\n''')
    for i in range(1, 51):
        query1 = '''  ({}, '{}', {}, {}, {}),\n'''.format(i, random_string(), 1, 0, 0)
        query2 = '''  ({}, '{}', {}, {}, {}),\n'''.format(i, random_string(), 2, 0, 0)
        query3 = '''  ({}, '{}', {}, {}, {}),\n'''.format(i, random_string(), 3, 0, 0)
        query4 = '''  ({}, '{}', {}, {}, {}),\n'''.format(i, random_string(), 4, 0, 0)
        output.write(query1)
        output.write(query2)
        output.write(query3)
        output.write(query4)
