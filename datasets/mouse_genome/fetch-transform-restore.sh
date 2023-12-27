### Env vars set by the "executor":
# DATASET_NAME
# TEMP_FOLDER
# DO_FETCH
# DO_TRANSFORM
# DO_RESTORE
# DROP_INPUT_FILES_AFTER_IMPORT
# RESTORE_JOBS
# SET_UNLOGGED
# PGHOST
# PGPORT
# PGUSER

DATASET_NAME=mouse_genome
DESCRIPTION="Mouse Genome sample data set"
PROVIDER="https://www.informatics.jax.org/software.shtml"
URL="http://www.informatics.jax.org/downloads/database_backups/mgd.postgres.dump"
OUT_FILENAME="mouse_genome.dump"


DUMP_FILE="$TEMP_FOLDER/$DATASET_NAME/$OUT_FILENAME"

if [ "$DO_FETCH" -gt 0 ]; then
  result=1
  if [ -f ./vars/fetch_result ]; then
    result=`cat ./vars/fetch_result`
  fi
  if [ "$result" -eq 0 ]; then
    echo "Skipping fetch based on fetch_result marker"
  else
    DUMP_SIZE=$(cat ./attrs/dump_size)
    echo "Fetching $DUMP_SIZE GB from $URL ..."
    echo "wget -O $DUMP_FILE $URL"
    wget -O $DUMP_FILE $URL
    result=$?
    echo -n "$result" > ./vars/fetch_result
  fi
fi


if [ "$DO_RESTORE" -gt 0 ]; then
  result=1
  if [ -f ./vars/restore_result ]; then
    result=`cat ./vars/restore_result`
  fi
  if [ "$result" -eq 0 ]; then
    echo "Skipping restore based on restore_result marker"
  else
    DUMP_SIZE=$(cat ./attrs/dump_size)

    echo "dropdb --if-exists $DATASET_NAME"
    dropdb --if-exists $DATASET_NAME
    echo "createdb $DATASET_NAME"
    createdb $DATASET_NAME

    RESTORE_PREREQ_SQL="CREATE ROLE mgd_public"
    psql -Xc "$RESTORE_PREREQ_SQL"

    if [ "$DATA_ONLY_RESTORE" -gt 0 ]; then
      echo "pg_restore --section pre-data -O -j $RESTORE_JOBS -d $DATASET_NAME -Fc $RESTORE_FLAGS $DUMP_FILE"
      pg_restore --section pre-data -O -j $RESTORE_JOBS -d $DATASET_NAME -Fc $RESTORE_FLAGS $DUMP_FILE
      echo "pg_restore --section data -O -j $RESTORE_JOBS -d $DATASET_NAME -Fc $RESTORE_FLAGS $DUMP_FILE"
      pg_restore --section data -O -j $RESTORE_JOBS -d $DATASET_NAME -Fc $RESTORE_FLAGS $DUMP_FILE
    else
      echo "pg_restore -O -j $RESTORE_JOBS -d $DATASET_NAME -Fc $RESTORE_FLAGS $DUMP_FILE"
      pg_restore -O -j $RESTORE_JOBS -d $DATASET_NAME -Fc $RESTORE_FLAGS $DUMP_FILE
    fi
    result=$?
    echo -n "$result" > ./vars/restore_result
    # Optional post restore step
    if [ "$result" -eq 0 ]; then
      psql -Xc "alter database $DATASET_NAME set search_path to mgd, mgd_public"
      if [ "$DROP_INPUT_FILES_AFTER_IMPORT" -gt 0 ]; then
        rm $DUMP_FILE
      fi
    fi
  fi
fi
