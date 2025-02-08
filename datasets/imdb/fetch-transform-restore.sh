# From IMDB official download site: https://developer.imdb.com/non-commercial-datasets/
# NB! Schema is currently a simplified version where arrays are just comma separated text,
# derived from https://github.com/betafcc/imdb-postgres


BASE_URL=https://datasets.imdbws.com
TSV_FILES="name.basics title.akas title.basics title.crew title.episode title.principals title.ratings"
TSV_FILES="name.basics title.akas"
TSV_FILES_SUFFIX=tsv.gz

set -e

if [ "$DO_FETCH" -gt 0 ]; then
  result=1
  if [ -f ./vars/fetch_result ]; then
    result=`cat ./vars/fetch_result`
  fi
  if [ "$result" -eq 0 ]; then
    echo "Skipping fetch based on fetch_result marker"
  else
    DUMP_SIZE=$(cat ./attrs/dump_size)
    echo "Fetching a total $DUMP_SIZE MB from $BASE_URL ..."

    for file_to_dl in $TSV_FILES ; do
      URL=$BASE_URL/${file_to_dl}.${TSV_FILES_SUFFIX}
      DUMP_FILE="${TEMP_FOLDER}/${DATASET_NAME}/${file_to_dl}.${TSV_FILES_SUFFIX}"
      echo "wget -O $DUMP_FILE $URL"
      wget -O $DUMP_FILE $URL
      result=$?
      echo -n "$result" > ./vars/fetch_result
    done
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

    echo "dropdb --force --if-exists $DATASET_NAME"
    dropdb --force --if-exists $DATASET_NAME
    echo "createdb $DATASET_NAME"
    createdb $DATASET_NAME

    if [ "$SET_UNLOGGED" -gt 0 ]; then
      cat schema_tables.sql | psql -Xq $DATASET_NAME
    else
      cat schema_tables.sql | sed 's/UNLOGGED//g' | psql -Xq $DATASET_NAME
    fi

    for file_to_load in $TSV_FILES ; do
      table_name=$(echo "$file_to_load" | tr '.' '_')
      DUMP_FILE="$TEMP_FOLDER/$DATASET_NAME/${file_to_load}.${TSV_FILES_SUFFIX}"
      echo "zcat $DUMP_FILE | psql -Xc \"copy $table_name from stdin with (format text, header on)"
      zcat $DUMP_FILE | psql -Xc "copy $table_name from stdin with (format text, header on)"

      result=$?
      echo -n "$result" > ./vars/fetch_result
      if [ "$result" -ne 0 ]; then
        break
      fi
    done

    if [ "$DATA_ONLY_RESTORE" -gt 0 ]; then
      echo "Not creating indexes due to DATA_ONLY_RESTORE"
    else
      psql -X -f schema_constraints.sql $DATASET_NAME
    fi
    result=$?
    echo -n "$result" > ./vars/restore_result
    if [ "$result" -eq 0 ]; then
      if [ "$DROP_INPUT_FILES_AFTER_IMPORT" -gt 0 ]; then
        rm $DUMP_FILE
      fi
    fi
  fi
fi
