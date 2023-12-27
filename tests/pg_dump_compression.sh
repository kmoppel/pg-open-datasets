set -e
set +x

# Vars:
# TEST_OUT_DIR
# TEST_NAME
# SCRIPT_START
# TEST_START
# DATASET_NAME

for LVL in {1..9} ; do

T1=$(date +%s%3N) # Epoch millis
pg_dump $DATASET_NAME >/dev/null
T2=$(date +%s%3N)
DURATION=$((T2-T1))

SQL_INS=$(cat <<-EOF
INSERT INTO dataset_test_results (
    script_start, test_start, dataset_name, test_name, test_id, test_id_num, test_value, test_value_info
) VALUES (
    '${SCRIPT_START}', '${TEST_START}', '${DATASET_NAME}', '${TEST_NAME}', 'pg_dump_gzip', '${LVL}', $DURATION, 'millis'
);
EOF
)
echo "Adding test results to RDB for $TEST_SCRIPT GZIP LVL $LVL ..."
psql "$RDB_CONNSTR" -X -c "$SQL_INS"

done
