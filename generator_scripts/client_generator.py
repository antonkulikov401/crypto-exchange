import random

random.seed(a=322)

fn = []
sn = []
codes = ['FRA', 'FIN', 'NOR', 'RUS', 'USA', 'NGA', 'ITA', 'CHN']

with open('names.txt', 'r') as f:
    data = f.read().splitlines()
    for x in data:
        first, second = x.split()
        fn.append(first)
        sn.append(second)

with open('phones.txt', 'r') as f:
    ph = f.read().splitlines()

with open('emails.txt', 'r') as f:
    em = f.read().splitlines()

with open('client.sql', 'w') as output:
    output.write('SET SEARCH_PATH = crypto_exchange;\n\nINSERT INTO client (first_nm, second_nm, phone_no, email, country_cd, passport_series, passport_no)\nVALUES\n')
    for i in range(50):
        query = '''  ('{}', '{}', '{}', '{}', '{}', '{}', '{}'),\n'''.format(fn[i], sn[i], ph[i], em[i], random.choice(codes),
                                           random.randint(1000, 9999), random.randint(100000, 999999))
        output.write(query)
