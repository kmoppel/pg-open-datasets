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

DATASET_NAME=stackexchange_askubuntu
DESCRIPTION="Stackexchange askubuntu.com archive"
PROVIDER="https://archive.org/download/stackexchange/"
URL="https://archive.org/download/stackexchange/askubuntu.com.7z"
OUT_FILENAME="askubuntu.com.7z"

DUMP_FILE="$TEMP_FOLDER/$DATASET_NAME/$OUT_FILENAME"

# TODO nice-parse later to columns, loading all xml files to rows for now
SQL_SCHEMA_POSTHISTORY=$(cat <<-EOF

CREATE UNLOGGED TABLE IF NOT EXISTS public."PostHistory" (
  "Id" int8,
  "PostHistoryTypeId" int8,
  "RevisionGUID" uuid,
  "CreationDate" timestamp,
  "UserId" int8,
  "Text" text,
  "ContentLicense" text
);

CREATE UNLOGGED TABLE IF NOT EXISTS public."Posts" (
  "Id" int8,
  "PostTypeId" int8,
  "AcceptedAnswerId" int8,
  "CreationDate" timestamp,
  "Score" int8,
  "ViewCount" int8,
  "Body" text,
  "OwnerUserId" int8,
  "LastEditorUserId" int8,
  "LastEditDate" timestamp,
  "LastActivityDate" timestamp,
  "Title" text,
  "Tags" text,
  "AnswerCount" int8,
  "CommentCount" int8,
  "ContentLicense" text
);

EOF
)

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

if [ "$DO_TRANSFORM" -gt 0 ]; then
  result=1
  if [ -f ./vars/transform_result ]; then
    result=`cat ./vars/transform_result`
  fi
  if [ "$result" -eq 0 ]; then
    echo "Skipping transform based on transform_result marker"
  else
    if [ "$result" -eq 0 ]; then
      echo "Skipping restore based on restore_result marker"
    else
      echo "Extracting the 7zip archive ..."
      echo "7zz x -o$TEMP_FOLDER/$DATASET_NAME $DUMP_FILE"
      7zz x -o"$TEMP_FOLDER/$DATASET_NAME" $DUMP_FILE
      echo $? > ./vars/transform_result
    fi
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

    echo "dropdb --if-exists --force $DATASET_NAME"
    dropdb --if-exists --force $DATASET_NAME
    echo "createdb $DATASET_NAME"
    createdb $DATASET_NAME

    echo "Loading XML rows to PG ..."
    connstr="host=$PGHOST port=$PGPORT user=$PGUSER dbname=$PGDATABASE"

    for f in `ls $TEMP_FOLDER/$DATASET_NAME/*.xml` ; do
      fbase=$(basename ${f})
      tbl=${fbase%%.xml}
      echo "Running python3 load_xml_to_pg.py $f '$connstr' $tbl"
      python3 load_xml_to_pg.py "$f" "$connstr" "$tbl"
      result=$?
      echo -n "$result" > ./vars/restore_result
    done
  fi
fi
