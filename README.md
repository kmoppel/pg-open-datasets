# pg-open-datasets

A simplistic framework to automatically download, convert and load a selection of openly available sample Postgres datasets.
Optionally one can also run some custom test scripts on each dataset after restoring.

Dataset "implementations" can inspect some env vars set by the framework and need to set some file based vars / attributes,
to implement download caching and avoid possibly expensive transformations.

## Quick start

1. Get the source `git clone https://github.com/kmoppel/pg-open-datasets.git && cd pg-open-datasets`
2. Create a new Postgres instance if needed set the PG* connection variables declared at top of `process_all_datasets.sh`
3. Review / set the `DATASETS` variable in `process_all_datasets.sh` to choose all / some datasets to download / restore
4. Run `process_all_datasets.sh` - datasets will be downloaded / transformed / restored into Postgres one-by-one
   * Subsequent runs of the script for same datasets will not do any processing if the implementation sets the caching vars correctly

# Datasets

Pretty much any dataset I guess can be made to work with Postgres, but the idea is to choose ones that are little work + 
large enough (1GB+) to be of interest for testing some Postgres features.
 
## Currently implemented datasets

"Implemented" datasets can be found under the "datasets" folder

| Dataset                      | Download size | Restored size | Type       |
|------------------------------|:-------------:|--------------:|------------|
| IMDB                         |      1.2      |           8.5 | textual    |
| Mouse Genome sample data set |      3.7      |            65 | numerical  |
| OSM Australia                |      1.1      |           6.2 | geospatial |
| Pgbench                      |       -       |            15 | mixed      |
| Postgres Pro demo DB big      |      0.3      |           2.6 | mixed      |

## Adding datasets

A dataset currently is basically a script (`fetch-transform-restore.sh`) in a separate folder under `datasets` that
downloads / generates, extracts / transforms and loads / restores the data into a DB provided by the framework.

Following vars can be used in dataset implementation scripts:

  * DATASET_NAME - dataset as well as "to be restored" dbname to create and populate
  * TEMP_FOLDER - to place downloaded dump files into (into $TEMP_FOLDER/$DATASET_NAME subfolder more exactly)
  * DO_FETCH - signals that need to download the dataset
  * DO_TRANSFORM - signals need to run transformations on the dumpfiles if any needed  
  * DO_RESTORE - signals need to do actually import the dump / transformed dump into a DB called $DATASET_NAME 
  * DROP_INPUT_FILES_AFTER_IMPORT - clean up after processing a dataset to save disk space 
  * RESTORE_JOBS - level of restore parellelism / CPUs to use. Defaults to conservative $CPU/8 
  * SET_UNLOGGED - signal that a dataset implementation should use unlogged tables if possible to reduce IO / speed up things 
  * DATA_ONLY_RESTORE - No post-data (indexes / constraints) if possible 
  * PGHOST - set to be able to just use `psql` to get to the current dataset 
  * PGPORT - set to be able to just use `psql` to get to the current dataset
  * PGDATABASE - set to be able to just use `psql` to get to the current dataset
  * PGUSER - set to be able to just use `psql` to get to the current dataset

Datasets can also set some optional "attribute" files which currently are FYI, but later could be used for filtered runs.

* dataset_type - textual | numerical | geospatial | mixed  
* dump_size - approximate download size in GB  
* restore_size - approximate restored-into-postgres size in GB  
* restore_size_data_only - approximate restored-into-postgres size in GB when it supports DATA_ONLY_RESTORE  

## Ideas / sources for adding more datasets

* https://wiki.postgresql.org/wiki/Sample_Databases
* https://dataverse.harvard.edu/

# Running tests on the datasets

WIP

Test scripts can be developed that will execute after restore of each dataset.
These test scripts are expected to be cmdline runnables that after doing "something" enter the results into a results DB
directly, accessible via the $RESULTSDB_CONNSTR env var. The actual DB behind $RESULTSDB_CONNSTR needs to be set up outside of
the current scripting framework. Alternatively test scripts can just also store any textual output under $TEST_OUT_DIR,
pointing to tests/test_output/$DATASET for each dataset.

Relevant env variables that can be used in test scripts:

  * RESULTSDB_CONNSTR - to use a below table to store results for easy analysis
  * SCRIPT_START - to populate the "script_start" column in RESULTSDB_CONNSTR
  * TEST_START - to populate the "test_start" column in RESULTSDB_CONNSTR
  * DATASET_NAME - to populate the "dataset_name" column in RESULTSDB_CONNSTR
  * TEST_NAME - to populate the "test_name" column in RESULTSDB_CONNSTR
  * TEST_OUT_DIR - to store file output for tests if preferred

Schema of the test results storage table:

```sql
create table if not exists public.dataset_test_results (
  created_on timestamptz not null default now(),
  script_start timestamptz not null,
  test_start timestamptz not null,
  dataset_name text not null,
  test_name text not null,
  test_id text not null,
  test_value numeric not null
);
```

Thus a full result-storing SQL for some benchmark on some dataset should look something like:

```
SQL_INS=$(cat <<-EOF
INSERT INTO dataset_test_results (
    script_start, test_start, dataset_name, test_name, test_value
) VALUES (
    '${SCRIPT_START}', '${TEST_START}', '${DATASET_NAME}', 'do_smth', 666
);
psql "$RESULTSDB_CONNSTR" -Xc "$SQL_INS"
```
