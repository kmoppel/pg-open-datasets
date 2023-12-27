# The osm2pgsql utility is assumed + postgis installed (apt install -y osm2pgsql)
# TODO add larger areas https://download.geofabrik.de/

URL=https://download.geofabrik.de/australia-oceania-latest.osm.pbf
DUMP_FILE="$TEMP_FOLDER/$DATASET_NAME/$DATASET_NAME.osm.pbf"

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

    RESTORE_PREREQ_SQL="CREATE EXTENSION IF NOT EXISTS postgis;"
    psql -Xc "$RESTORE_PREREQ_SQL"

    if [ "$DATA_ONLY_RESTORE" -gt 0 ]; then
      echo "NOT IMPL" # Can be done ?
    else
      echo "osm2pgsql -d $DATASET_NAME --number-processes $RESTORE_JOBS $DUMP_FILE"
      osm2pgsql -d $DATASET_NAME --number-processes $RESTORE_JOBS $DUMP_FILE
    fi
    result=$?
    echo  -n "$result" > ./vars/restore_result
    if [ "$result" -eq 0 ]; then
      if [ "$DROP_INPUT_FILES_AFTER_IMPORT" -gt 0 ]; then
        rm $DUMP_FILE
      fi
    fi
  fi
fi

