#!/usr/bin/env bash

set -e # Bail on first error

### DB to import datasets into
# export PGHOST=/var/run/postgresql/
export PGHOST=/tmp
export PGPORT=5555 # Expected to be there
export PGUSER=$USER
export PGDATABASE=postgres
export PATH=/usr/lib/postgresql/16/bin:$PATH

### Dataset handling
export TEMP_FOLDER=`pwd`/tmp_dumps # The downloaded dumps are placed here
export RESTORE_JOBS=$((`nproc`/8)) # Be conservative by default considering default max_parallel_maintenance_workers=2
if [ $RESTORE_JOBS -eq 0 ]; then
  export RESTORE_JOBS=1
fi
export FRESH_START=0 # Drop old fetch / transform results if any
export SET_UNLOGGED=1 # PS Could also prolong restore time due to serialization!
export DROP_INPUT_FILES_AFTER_IMPORT=0 # Immediately drop the dataset source files after restoring
export DO_FETCH=1 # Optional, dataset could also pipe everything on restore
export DO_TRANSFORM=1 # Optional, dataset could also pipe everything on restore
export DO_RESTORE=1
export DATA_ONLY_RESTORE=0 # No post-data (indexes / constraints) - if dataset supports it
export DO_TESTS=0 # Run "test" scripts from the `tests` directory for each DB after restore
TESTS_TO_RUN="pg_dump_compression.sh" # Executes listed scripts from the "tests" folder after restoring a dataset
export RDB_CONNSTR="host=localhost port=5432 dbname=postgres" # ResultsDB connect string
export DROP_DB_AFTER_TESTING=0 # Drop the DB under testing in the end # TODO
DATASETS=$(find ./datasets/ -mindepth 1 -maxdepth 1 -type d | sed 's@\./datasets/@@g')
DATASETS="stackexchange_askubuntu" # PS can do a manual override here to process only listed datasets

mkdir -p $TEMP_FOLDER
export MARKER_FILES="./vars/fetch_result ./vars/transform_result ./vars/restore_result" # Used to skip processing steps on re-run if possible

# Optional output table for "test" scripts to store some benchmark results for easy SQL analyses.
# Max 2 "metrics" per row currently to be able to do some $work_done / $time_spent calculations
SQL_RESULTS_TABLE=$(cat <<-EOF
create table if not exists public.dataset_test_results (
  created_on timestamptz not null default now(),
  test_start_time timestamptz not null, /* test script start time for a dataset */
  dataset_name text not null,
  test_script_name text not null,
  test_id text not null,
  test_id_num numeric,
  test_value numeric not null,
  test_value_info text,
  test_value_2 numeric,
  test_value_info_2 text
);
EOF
)

function init_resultsdb_or_fail() {
  # Initialize the table for storing pg_stat_statement results
  echo "Ensuring public.dataset_test_results in resultsdb ..."
  psql "$RDB_CONNSTR" -Xc "$SQL_RESULTS_TABLE"
  if [ $? -ne 0 ]; then
    echo "Could not conect to resultsdb - exit"
    exit 1
  fi
}

# some basic validation
if [ -z "$DATASETS" ]; then
    echo "No datasets selected"
    exit 1
fi
set +e
psql -XAtc "select 1" &>/dev/null
if [ $? -ne 0 ]; then
  echo "Could not connect to restore target DB. Check PG* env vars"
  exit 1
fi
set -e

START_TIME=$(date +%s)
SCRIPT_START=$(psql -XAtc "select now()")
export SCRIPT_START="$SCRIPT_START"

echo "Starting at $SCRIPT_START ..."

if [ "$DO_TESTS" -gt 0 ]; then
    init_resultsdb_or_fail
fi

echo "DB connstr used for restoring: 'host=$PGHOST port=$PGPORT user=$PGUSER dbname=$PGDATABASE'"

for DS_NAME in ${DATASETS} ; do
  DS_PATH=./datasets/$DS_NAME
  echo -e "\n\n================================\nProcessing dataset ${DS_NAME} ...\n================================"

  if [ "$DO_FETCH" -gt 0 -o "$DO_FETCH" -gt 0 -o "$DO_FETCH" -gt 0 ]; then
    echo "Running dataset init for $DS_NAME..."
    export DATASET_NAME=${DS_NAME}
    export PGDATABASE=${DS_NAME}
    mkdir -p $TEMP_FOLDER/$DATASET_NAME

    if [ -f "${DS_PATH}/fetch-transform-restore.sh" ] ; then
        echo "Calling ${DS_PATH}/fetch-transform-restore.sh ..."
        pushd "${DS_PATH}"

        if [ ! -d "vars" ]; then
          mkdir vars
        fi
        if [ "$FRESH_START" -gt 0 ]; then
            for MARKER in ${MARKER_FILES} ; do
              if [ -f "$MARKER" ] ; then
                rm "$MARKER"
              fi
            done
        fi
        ./fetch-transform-restore.sh
        for MARKER in ${MARKER_FILES} ; do
          if [ -f "$MARKER" ] ; then
            echo "$MARKER: `cat $MARKER`"
          fi
        done
        popd
        echo -e "\nDataset init done for '$DATASET_NAME'"
        echo -n "DB '$DATASET_NAME' size: "
        psql -XAtc "select pg_size_pretty(pg_database_size('$DATASET_NAME'))"
    else
        echo "WARNING: ${DS_PATH}/fetch-transform-restore.sh not found. Skipping dataset ${DS_NAME}"
        continue
    fi
  fi

  if [ "$DO_TESTS" -gt 0 ]; then
    echo -e "\nRunning tests for $DS_NAME..."
    export TEST_OUT_DIR="$PWD/test_output/$DATASET_NAME"
    pushd ./tests
    for TEST_SCRIPT in $TESTS_TO_RUN ; do
      if [ ! -d "vars" ]; then
        mkdir vars
      fi
      if [ ! "$FRESH_START" -gt 0 ]; then
        TEST_STATUS_MARKER=./vars/${TEST_SCRIPT}_${DATASET_NAME}_result
        if [ -f "$TEST_STATUS_MARKER" ] ; then
          TEST_STATUS=$(cat $TEST_STATUS_MARKER)
          if [ "$TEST_STATUS" -eq 0 ]; then
            echo "Skipping test $TEST_SCRIPT as already executed"
            continue
          fi
        fi
      fi
      export TEST_NAME=${TEST_SCRIPT%.sh}
      echo -e "\nStarting test $TEST_SCRIPT ..."
      TEST_START_TIME=$(psql -XAtc "select now()" template1)
      export TEST_START_TIME="$TEST_START_TIME"

      ./${TEST_SCRIPT}
      echo "Finished running test $TEST_SCRIPT ..."
      echo 0 > $TEST_STATUS_MARKER
    done
    popd
  fi

done

END_TIME=$(date +%s)
TIME_SEC=$((END_TIME- START_TIME))
echo -e "\nDone. Script finished in $TIME_SEC seconds"
