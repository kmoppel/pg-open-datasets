# pg-open-datasets

A simple (Bash) framework to automatically download, convert and load a selection of openly available sample Postgres datasets.
Optionally one can also run some custom test scripts on each dataset after restoring.

Dataset "implementations" are basically Bash scripts that download / generate / extract / load the target dataset.
Also they can inspect some env vars set by the framework to only do more targeted work, e.g. only download the dataset (useful
for testing mostly) and need to set some file based vars / attributes, to implement "caching" to avoid possibly expensive transformations.

The target instance for loading data into, or storing test results, need to be existing already.

## Quick start

1. Get the source `git clone https://github.com/kmoppel/pg-open-datasets.git && cd pg-open-datasets`
2. Create a new Postgres instance if needed, and set the PG* connection variables declared at top of `process_datasets.sh`.
  - One can also leave instance creation to the script - review `DO_INITDB_FOR_EACH_DATASET` / `INITDB_TMP_DIR` then
3. Review / set the `DATASETS` variable in `process_datasets.sh` to choose all (default) or some specific datasets to download / restore
4. Install / verify a few expected dependencies (assuming Ubuntu / Debian)
  - `apt install postgresql 7zip python3-pip osm2pgsql`
  - `pip install psycopg`
5. Run `process_datasets.sh` - datasets will be downloaded / transformed / restored into Postgres one-by-one
   * Subsequent runs of the script for same datasets will not do any processing if the implementation sets the caching vars correctly
6. Additionally one can set `DO_TESTS` / `TESTS_TO_RUN` to choose if some script should be executed for each dataset

# Datasets

Pretty much any dataset I guess can be made to work with Postgres, but the idea is to choose ones that require little work
(ready-made SQL or COPY dumps would be perfect) + large enough (1GB+) to be of interest for testing some Postgres features.
 
## Currently implemented datasets

"Implemented" datasets can be found under the "datasets" folder

| Dataset                      | Download size (GB) | Restored size | Type       |
|------------------------------|:------------------:|--------------:|------------|
| IMDB                         |        1.2         |           8.5 | textual    |
| Mouse Genome sample data set |        3.7         |            65 | numeric    |
| OSM Australia                |        1.1         |           6.2 | geospatial |
| Pgbench                      |         -          |            15 | mixed      |
| Postgres Pro demo DB big     |        0.3         |           2.6 | mixed      |
| stackexchange_askubuntu      |         1          |           5.3 | textual    |
| NYC Yellow Cab trips 2021    |        2.8         |           5.2 | numeric    |

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
* dump_size - approximate download size in MB
* restore_size - approximate restored-into-postgres size in MB
* restore_size_data_only - approximate restored-into-postgres size in MB when it supports DATA_ONLY_RESTORE

To find out how much disk space is needed to load all datasets run the `./calc_approx_datasets_total_size.sh` script.
If the total size is too much to fit all datasets at once one can either leave some out or set `DROP_DB_AFTER_TESTING`
which will process datasets one-by-one and drop after usage.

## Ideas / sources for adding more datasets

* https://wiki.postgresql.org/wiki/Converting_from_other_Databases_to_PostgreSQL
  - Could also import some available dumps for other DB systems
* https://wiki.postgresql.org/wiki/Sample_Databases
* https://dataverse.harvard.edu/
* Sysbench
* https://github.com/timescale/benchmark-postgres
* HammerDB https://www.enterprisedb.com/blog/how-to-benchmark-postgresql-using-hammerdb-open-source-tool
  ./hammerdbcli auto scripts/tcl/postgres/tprocc/pg_tprocc_buildschema.tcl 15G on 32c
* 1B taxi rides https://github.com/toddwschneider/nyc-taxi-data
* https://www.gharchive.org/
* https://ftp.ncbi.nih.gov/gene/DATA/
  https://ftp.ncbi.nih.gov/gene/DATA/gene2accession.gz
* https://archive.org/details/stackexchange
* https://archive.org/download/stackexchange/askubuntu.com.7z 1G
* https://ftp.ebi.ac.uk/pub/databases/RNAcentral/releases/22.0/database_files/
* https://www.ncei.noaa.gov/data/global-hourly/archive/csv/
* https://geoportaal.maaamet.ee/est/Ruumiandmed/Eesti-topograafia-andmekogu/Laadi-ETAK-andmed-alla-p609.html


# Running tests on the datasets

Test scripts can be developed that will execute after restore of each dataset.
These test scripts are expected to be executable scripts, that do "something" with the freshly restored dataset.
Also there's support for having a "test results" DB / table where test implementation can enter test results directly into
a results DB, accessible via the $RESULTSDB_CONNSTR env var, to enable easy results analysing. The actual DB behind
$RESULTSDB_CONNSTR needs to be set up outside of the current scripting framework. Alternatively test scripts can just also
store any textual output under $TEST_OUT_DIR, pointing to tests/test_output/$DATASET for each dataset.

Relevant env variables that can be used in test scripts:

  * RESULTSDB_CONNSTR - to use a below table to store results for easy analysis
  * TEST_START_TIME - to populate the "test_start" column in RESULTSDB_CONNSTR
  * DATASET_NAME - to populate the "dataset_name" column in RESULTSDB_CONNSTR
  * TEST_SCRIPT_NAME - to populate the "test_name" column in RESULTSDB_CONNSTR
  * TEST_OUT_DIR - to store file output for tests if preferred

Schema of the test results storage table:

```sql
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
```

For example "implementations" look in `tests` folder.
