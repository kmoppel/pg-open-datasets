# Using a dump file found by Googling for now, seems to be from 2019 though
# From https://github.com/RyanMarcus/imdb_pg_dataset/blob/master/vagrant/config.sh

URL=https://dataverse.harvard.edu/api/access/datafile/:persistentId?persistentId=doi:10.7910/DVN/2QYZBT/TGYUNU
DUMP_FILE="$TEMP_FOLDER/$DATASET_NAME/imdb.dump"

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

    RESTORE_PREREQ_SQL="CREATE ROLE imdb"
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
    if [ "$result" -eq 0 ]; then
      if [ "$DROP_INPUT_FILES_AFTER_IMPORT" -gt 0 ]; then
        rm $DUMP_FILE
      fi
    fi
  fi
fi




# TODO dl directly from IMDB to get latest data + convert using smth like https://github.com/ameerkat/imdb-to-sql
#wget -A "*tsv.gz" --mirror "https://datasets.imdbws.com/";
#for f in datasets.imdbws.com/*gz; do
#  echo "Extracting ${f%.*}";
#  pv $f | gunzip > ${f%.*}  || break;
#done
#
