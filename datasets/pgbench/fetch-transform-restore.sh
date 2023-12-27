PGBENCH_SCALE=1000
PGBENCH_FLAGS=""

if [ "$DATA_ONLY_RESTORE" -gt 0 ]; then
  PGBENCH_FLAGS="$PGBENCH_FLAGS -I dtgv"
fi
if [ "$SET_UNLOGGED" -gt 0 ]; then
  PGBENCH_FLAGS="$PGBENCH_FLAGS --unlogged"
fi

if [ "$DO_RESTORE" -gt 0 ]; then
  result=1
  if [ -f ./vars/restore_result ]; then
    result=`cat ./vars/restore_result`
  fi
  if [ "$result" -eq 0 ]; then
    echo "Skipping restore based on restore_result marker"
  else
    echo "dropdb --if-exists $DATASET_NAME"
    dropdb --if-exists $DATASET_NAME
    echo "createdb $DATASET_NAME"
    createdb $DATASET_NAME

    echo "pgbench -iq --scale $PGBENCH_SCALE $PGBENCH_FLAGS $DATASET_NAME"
    pgbench -iq --scale $PGBENCH_SCALE $PGBENCH_FLAGS $DATASET_NAME

    result=$?
    echo -n "$result" > ./vars/restore_result
    if [ "$result" -eq 0 ]; then
      if [ "$DROP_INPUT_FILES_AFTER_IMPORT" -gt 0 ]; then # TODO move to main
        rm $DUMP_FILE
      fi
    fi
  fi
fi
