# New York City Taxi Yellow Cab data for 2021
# It's available in many places but fastest downloads seem to come from AWS - needs AWS CLI login though!
# https://aws.amazon.com/marketplace/pp/prodview-okyonroqg5b2u?sr=0-1&ref_=beagle&applicationId=AWSMPContessa#resources
DUMP_FOLDER="$TEMP_FOLDER/$DATASET_NAME"

#DUMP_FOLDER="/tmp"
#DATASET_NAME=nyc_taxi_rides
#DO_FETCH=0
#DO_RESTORE=1
#DATA_ONLY_RESTORE=0
#SET_UNLOGGED=1
#DROP_INPUT_FILES_AFTER_IMPORT=0

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
    for i in $(seq -f "%02g" 1 12)
    do
      echo "aws s3 cp s3://nyc-tlc/csv_backup/yellow_tripdata_2021-${i}.csv $DUMP_FOLDER/ --quiet"
      aws s3 cp s3://nyc-tlc/csv_backup/yellow_tripdata_2021-${i}.csv "$DUMP_FOLDER/" --quiet
    done
    result=$?
    echo -n "$result" > ./vars/fetch_result
  fi
fi

DDL=$(cat <<- "EOF"
DROP TABLE IF EXISTS trips;

CREATE UNLOGGED TABLE trips (
  "VendorID" int,
  tpep_pickup_datetime timestamp,
  tpep_dropoff_datetime timestamp,
  passenger_count float,
  trip_distance numeric,
  "RatecodeID" float,
  store_and_fwd_flag boolean,
  "PULocationID" int,
  "DOLocationID" int,
  payment_type int,
  fare_amount numeric,
  extra numeric,
  mta_tax numeric,
  tip_amount numeric,
  tolls_amount numeric,
  improvement_surcharge numeric,
  total_amount numeric,
  congestion_surcharge numeric
);
EOF
)
DDL_IDX=$(cat <<- "EOF"
create index on trips ( tpep_pickup_datetime );
create index on trips ( tpep_dropoff_datetime );
EOF
)

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

    if [ "$SET_UNLOGGED" -gt 0 ]; then
      echo "$DDL" | psql -Xq $DATASET_NAME
    else
      echo "$DDL" | sed 's/UNLOGGED//g' | psql -Xq $DATASET_NAME
    fi

    for csv in "$DUMP_FOLDER"/*yellow_tripdata*.csv ; do
      echo "Loading file $csv via COPY ..."
      psql -Xq -c "\copy trips from '$csv' csv header" $DATASET_NAME
    done
    result=$?

    if [ "$DATA_ONLY_RESTORE" -eq 0 ]; then
      echo "Creating indexes ..."
      echo "$DDL_IDX"
      echo "$DDL_IDX" | psql -Xq $DATASET_NAME
      result=$?
    fi

    echo -n "$result" > ./vars/restore_result
    if [ "$result" -eq 0 ]; then
      if [ "$DROP_INPUT_FILES_AFTER_IMPORT" -gt 0 ]; then
        rm "$DUMP_FOLDER"/*yellow_tripdata*.csv
      fi
    fi
  fi
fi
