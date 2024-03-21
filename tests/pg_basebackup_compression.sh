set -e

# Available vars:
# DATASET_NAME
# TEST_NAME
# TEST_OUT_DIR
# TEST_START_TIME

METHOD_LVLS="gzip:1 gzip:3 gzip:5 gzip:7 gzip:9 lz4:1 lz4:3 lz4:5 lz4:7 lz4:9 lz4:11 zstd:1 zstd:5 zstd:9 zstd:13 zstd:17 zstd:21"
#METHOD_LVLS="gzip:1 lz4:1 zstd:1"

echo "Doing a cache warmup pg_basebackups ..."
T1=$(date +%s%3N) # Epoch millis
#BYTES=$(pg_dump -Z $METHOD:$LVL $DATASET_NAME | wc -c)
pg_basebackup -c fast -Ft -D- -X none --no-manifest &>/dev/null
T2=$(date +%s%3N)
DURATION=$((T2-T1))
echo "Done in $DURATION s"

for ML in $METHOD_LVLS ; do

IFS=':' splits=($ML)
METHOD=${splits[0]}
LVL=${splits[1]}
IFS=

echo "Testing pg_basebackup $METHOD:$LVL on $DATASET_NAME"
T1=$(date +%s%3N) # Epoch millis
#BYTES=$(pg_dump -Z $METHOD:$LVL $DATASET_NAME | wc -c)
BYTES=$(pg_basebackup -c fast -Ft -D- -X none --no-manifest --compress=server-$METHOD:$LVL | wc -c)
T2=$(date +%s%3N)
DURATION=$((T2-T1))
echo "Done in $DURATION s"

SQL_INS=$(cat <<-EOF
INSERT INTO dataset_test_results (
    test_start_time, dataset_name, test_script_name, test_id, test_id_num, test_value, test_value_info, test_value_2, test_value_info_2
) VALUES (
    '${TEST_START_TIME}', '${DATASET_NAME}', '${TEST_NAME}', '${METHOD}', '${LVL}', $DURATION, 'duration millis', ${BYTES}, 'compressed size bytes'
);
EOF
)
echo "Adding test results to RDB for $TEST_SCRIPT $METHOD LVL $LVL ..."
psql "$RDB_CONNSTR" -X -c "$SQL_INS"

done
