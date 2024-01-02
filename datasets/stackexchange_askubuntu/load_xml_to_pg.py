import psycopg
import sys

if len(sys.argv) != 4:
    print("Usage: load_xml_to_pg.py $file $connstr $tablename")

file = sys.argv[1]
connstr = sys.argv[2]
tablename = sys.argv[3]
print(f"Loading {file} into {tablename} @ {connstr}...")

conn = psycopg.connect(connstr)

sql = f'insert into "{tablename}" values (%s)' # TODO use copy?
limit = 0
i = 0
with conn.cursor() as cur:
    sql_create_table = f'create table if not exists "{tablename}" (data xml);'
    cur.execute(sql_create_table)

    with open(file) as f:
        for l in f:
            # print(l)
            if not l.startswith('  <row'):
                continue
            cur.execute(sql, (l.rstrip(),)) # Remove extra newline
            i += 1
            if limit and i == limit:
                break
conn.commit()
