# https://postgrespro.com/community/demodb

URL=https://edu.postgrespro.com/demo-big-en.zip
DUMP_FILE="$TEMP_FOLDER/$DATASET_NAME/demo-big-en.zip"

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
    RESTORE_SIZE=$(cat ./attrs/restore_size)
    echo "Restoring $DATASET_NAME - expected restore size $RESTORE_SIZE MB ..."

    if [ "$SET_UNLOGGED" -gt 0 ]; then
      unzip -p $DUMP_FILE | sed -E "s/(DATABASE|connect) demo/\1 $DATASET_NAME/g;s/^DROP DATABASE/DROP DATABASE IF EXISTS/g;s/^CREATE TABLE/CREATE UNLOGGED TABLE/g" | psql -X template1
    else
      unzip -p $DUMP_FILE | sed -E "s/(DATABASE|connect) demo/\1 $DATASET_NAME/g;s/^DROP DATABASE/DROP DATABASE IF EXISTS/g" | psql -X template1
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
