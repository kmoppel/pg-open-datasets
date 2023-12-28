set -e
set +x

# Available vars:
# DATASET_NAME
# TEST_NAME
# TEST_OUT_DIR
# TEST_START_TIME

for LVL in {0..9} ; do

T1=$(date +%s%3N) # Epoch millis
BYTES=$(pg_dump -Z $LVL $DATASET_NAME | wc -c)
T2=$(date +%s%3N)
DURATION=$((T2-T1))

SQL_INS=$(cat <<-EOF
INSERT INTO dataset_test_results (
    test_start_time, dataset_name, test_script_name, test_id, test_id_num, test_value, test_value_info, test_value_2, test_value_info_2
) VALUES (
    '${TEST_START_TIME}', '${DATASET_NAME}', '${TEST_NAME}', 'gzip', '${LVL}', $DURATION, 'duration millis', ${BYTES}, 'compressed size bytes'
);
EOF
)
echo "Adding test results to RDB for $TEST_SCRIPT GZIP LVL $LVL ..."
psql "$RDB_CONNSTR" -X -c "$SQL_INS"

done
