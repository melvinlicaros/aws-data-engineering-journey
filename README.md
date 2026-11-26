# Weather Data Pipeline: API → Snowflake → dbt → Fabric / Power BI

An end-to-end data pipeline that ingests hourly weather data for two Philippine cities (Mabalacat and Manila), loads it into Snowflake, transforms it with dbt, and serves it in a Power BI report on Microsoft Fabric. Ingestion and transformation run daily on GitHub Actions, and every pull request is tested by CI before it reaches production.

![Dashboard](docs/images/dashboard.png)

## Architecture

```mermaid
flowchart LR
    A[Open-Meteo API] -->|fetch_weather.py| B[JSON files]
    B -->|PUT + COPY INTO| C[(Snowflake RAW)]
    C -->|dbt build| D[(DBT_PROD)]
    D -->|Fabric notebook| E[(lh_gold Delta)]
    E -->|Direct Lake| F[sm_weather]
    F --> G[rpt_weather]

    subgraph GitHub Actions
        B
        C
        D
    end
```

## Tech Stack

| Layer | Tools |
|---|---|
| Ingestion | Python, Open-Meteo API |
| Warehouse | Snowflake (stages, COPY INTO, VARIANT, FLATTEN) |
| Transformation | dbt (staging, marts, incremental model, SCD2 snapshot, 27 tests) |
| Orchestration and CI/CD | GitHub Actions (daily schedule, PR checks) |
| Serving | Microsoft Fabric (Lakehouse, PySpark notebook, Direct Lake semantic model) |
| Reporting | Power BI (DAX measures) |

## How It Works

1. **Ingest:** `fetch_weather.py` pulls hourly weather data from the Open-Meteo API and saves raw JSON.
2. **Load:** `load_weather.py` uploads the files to a Snowflake stage and runs `COPY INTO` a `VARIANT` column in `RAW.WEATHER_RAW`.
3. **Transform:** dbt flattens the JSON in staging, then builds a star schema:
   - `dim_location`, `dim_date`
   - `fct_weather_hourly`, `fct_weather_daily`
   - `weather_hourly_history` (incremental, appends only new loads)
   - `locations_snapshot` (SCD Type 2, tracks changes to location attributes)
4. **Test:** 27 dbt tests (not_null, unique, relationships, accepted_values, and custom singular tests).
5. **Serve:** A Fabric notebook copies the marts into a Lakehouse as Delta tables. A Direct Lake semantic model powers the Power BI report.

## CI/CD

| Workflow | Trigger | What it does | Target |
|---|---|---|---|
| `pipeline.yml` | Daily cron + manual | fetch → load → `dbt build` | `DBT_PROD` |
| `ci.yml` | Pull request to `main` | `dbt build` + all tests | `DBT_CI` (sandbox) |

Broken models are caught in `DBT_CI` before they can reach production.

![Pipeline run](docs/images/pipeline-run.png)
![PR with passing CI check](docs/images/pr-ci-check.png)

## Security

- **Least privilege:** a dedicated `PIPELINE_USER` (Snowflake `TYPE = SERVICE`) with `PIPELINE_ROLE`, which can only load to RAW and build in `DBT_PROD` / `DBT_CI`. Fabric reads with a separate read-only `FABRIC_USER`.
- **Key-pair authentication:** no passwords for service users.
- **No secrets in the repo:** credentials live in GitHub Secrets and are passed as environment variables. `profiles.yml` only contains `env_var()` references.

![Snowflake schemas](docs/images/snowflake-schemas.png)

## Lessons Learned

Real issues I hit and fixed while building this:

- **Invalid cron YAML failed silently.** A missing `-` and unspaced `***` made GitHub unable to parse the workflow, so the schedule never fired. Now I check the Actions tab after every push.
- **GitHub cron is best-effort.** My first scheduled run started about 3 hours late. Fine for daily weather data, but SLA-bound pipelines need a real orchestrator (Airflow, Fabric Data Pipeline).
- **Custom roles must roll up to SYSADMIN.** Tables owned by `PIPELINE_ROLE` were invisible even to `ACCOUNTADMIN` until the role was granted to `SYSADMIN`.
- **`USAGE` on the schema comes before `SELECT` on tables,** and you need both `ALL` (existing objects) and `FUTURE` (objects dbt recreates every run) grants.
- **Relative paths in CI.** Scripts must be referenced from the repo root, and the key path uses `${{ github.workspace }}` because dbt runs inside a subfolder.
- **Grain matters.** The history model's uniqueness test failed until `loaded_at` was added to the grain, because the same file can be reloaded.


## Project 2: Fabric Medallion Pipeline

A second pipeline built entirely inside Microsoft Fabric, with no Snowflake dependency. A Fabric Data Pipeline ingests the same Open-Meteo API, moves the data through Bronze, Silver and Gold lakehouses, and refreshes a Direct Lake semantic model so the Power BI report is always current.

![Fabric dashboard](docs/images/fabric-dashboard.png)

### Architecture

```mermaid
flowchart LR
    A[Open-Meteo API] -->|Copy data x2, parallel| B[(lh_bronze<br/>raw JSON)]
    B -->|Notebook: flatten| C[(lh_silver<br/>hourly Delta)]
    C -->|Notebook: aggregate| D[(lh_gold<br/>daily fact)]
    D -->|Semantic model refresh| E[sm_weather_api]
    E --> F[rpt_weather_api]
```

![Pipeline run, Gantt view](docs/images/fabric-pipeline-gantt.png)

### How It Works

1. **Bronze:** two Copy data activities (HTTP source, Binary format) land the raw API JSON for Mabalacat and Manila in parallel, exactly as received.
2. **Silver:** a PySpark notebook runs only after both copies succeed. It flattens the nested hourly arrays with `posexplode`, casts types, derives `location_name` from the file name, and adds a `loaded_at` timestamp. Writes are idempotent (`overwrite`).
3. **Gold:** a second notebook aggregates hourly data into a daily fact table (avg, max, min temperature, rainfall, rain hours, hot hours), rounding aggregates to remove floating point artifacts.
4. **Serve:** the pipeline refreshes the Direct Lake semantic model on success, so the report never shows partial data.

### Semantic Model

![Semantic model](docs/images/fabric-semantic-model.png)

- Star schema: one daily fact table with conformed `dim_date` and `dim_location` dimensions, many-to-one, single direction
- `dim_date` marked as the date table
- Raw fact columns hidden; report builders only see explicit measures
- 11 DAX measures, including:
  - `% Rainy Days` with `DIVIDE` and `VAR ... RETURN`
  - `Avg Temp Range` built on a calculated column
  - `Avg Temp Prev Day` and `Temp Change vs Prev Day` with `DATEADD`
  - `Avg Temp 3-Day Rolling` with `DATESINPERIOD`
  - `Hottest Day Rank` with `RANKX(ALL(...))`

### Fabric Lessons Learned

- **A stray character broke the API call.** A copied URL picked up extra text, so the source returned HTTP 400. Reading the error code pointed straight to the request, not the connection.
- **Delta protects its schema.** Adding `loaded_at` failed with a schema mismatch until I used `overwriteSchema`, which fits a full overwrite better than `mergeSchema`.
- **Small capacities can queue jobs.** A notebook sat "in progress" for 9 minutes because my interactive session held the F2 Spark resources. Stopping the session freed it immediately.
- **Don't trust auto-detected relationships.** Fabric guessed cardinality from row counts and reversed the date relationship twice. The "one" side is wherever the key is unique, which is the dimension.
- **Hide raw columns once measures exist.** A card dragged from a raw column used an implicit SUM and showed 222.9°C. Hiding the columns makes that mistake impossible.
- **BLANK acts like zero in DAX arithmetic.** Day-over-day change showed a fake -26.9°C drop on a date with no data, so both sides of the comparison need an `ISBLANK` guard.
- **`RANKX` needs `ALL`.** With `VALUES`, each row only sees itself, so every day ranked first.

## Project 3: Snowflake to Fabric Medallion Pipeline

A cross-platform pipeline that picks up where Project 1 ends. Every morning, GitHub Actions loads new weather data into Snowflake and runs dbt. Forty minutes later, a scheduled Fabric pipeline pulls that data into a Bronze, Silver and Gold lakehouse, models it as a star schema, and refreshes the Power BI report. No one has to press a button.

![Medallion report](docs/images/medallion-report.png)

### Architecture

```mermaid
flowchart LR
    subgraph gh["GitHub Actions, 6:17 AM"]
        A[Open-Meteo API] --> B[(Snowflake DBT_PROD)]
    end
    subgraph fab["Fabric Pipeline, 7:00 AM"]
        B -->|key-pair, read-only user| C[(Bronze<br/>full copy + ingested_at)]
        C -->|row_number dedup| D[(Silver<br/>1 row per city per hour)]
        D --> E[(Gold<br/>dim_location + fct_weather_daily)]
        E -->|refresh on success| F[sm_medallion_practice]
        F --> G[rpt_medallion_practice]
    end
```

### How It Works

1. **Bronze:** a PySpark notebook connects to Snowflake with a service user (`FABRIC_USER`, read-only `ANALYST` role, key-pair auth) and copies `WEATHER_HOURLY_HISTORY` as is. The only addition is an `ingested_at` timestamp. Writes use `overwrite` + `overwriteSchema`, so reruns are idempotent.
2. **Silver:** column names are standardized to lowercase. The same hour appears in several daily files (the API returns past and forecast days every run), so duplicates are removed with `row_number()` over `location_name, observed_at`, keeping the most recently loaded version. `dropDuplicates` was not used because it keeps an arbitrary copy.
3. **Gold:** a location dimension with a surrogate key, and a daily fact table at the grain of one city per day (max, min and avg temperature, rainfall, hot hours, and an `is_forecast` flag).
4. **Serve:** a Fabric pipeline runs the notebook, then refreshes the semantic model only on success. It is scheduled daily at 7:00 AM Manila time, after the upstream GitHub Actions run, with failure email alerts.

### Data Quality and Reconciliation

Every layer is checked before it is written. Results from the first full run:

| Check | Result |
|---|---|
| Snowflake rows = Bronze rows | 3,360 = 3,360 |
| Unique city + hour in Bronze = Silver rows | 1,008 = 1,008 |
| Duplicate keys in Silver | 0 |
| Null temperatures | 0 |
| Fact rows with location not found in dim | 0 |
| Days with fewer than 24 hours | 0 |
| Sum of hours in Gold = Silver rows | 1,008 = 1,008 |
| DAX `Actual Days + Forecast Days` = fact rows | 32 + 10 = 42 |

### Lessons Learned

- **"Succeeded" is not the same as "correct."** The first scheduled run passed, but a verification query showed today's date flagged as forecast. `current_date()` runs in UTC on Fabric, and 7:00 AM in Manila is 11:00 PM UTC the day before. Fixed by converting to `Asia/Manila` before comparing dates. The bug only appears in runs before 8:00 AM, so afternoon testing would never catch it.
- **Spark column names are case-insensitive.** Adding `loaded_at` silently overwrote Snowflake's own `LOADED_AT` column instead of creating a new one, losing the audit trail. Renamed mine to `ingested_at`.
- **Check the warehouse, not just the connection.** The Snowflake connection succeeded, but queries failed with "no active warehouse". The configured warehouse name was wrong, and Snowflake ignores it silently. `SELECT CURRENT_WAREHOUSE()` returning `None` and `SHOW WAREHOUSES` found it in seconds.
- **Deleting a table in the UI does not always clear Spark's catalog.** A rewrite failed with a Delta schema mismatch on a table I had already deleted. `SHOW TABLES` confirmed Spark still had it. `overwriteSchema` is now the default for every full refresh.
- **Average of averages is only right by luck.** It matches the true average here because every day has exactly 24 hours. Sums and counts are safe to aggregate; averages and percentages are not.
- **A good-looking chart can still be wrong.** The "Avg Max Temp" line sat at 28 to 30°C, but the fact table's max temperatures were 32 to 34°C. The measure was pointing at `avg_temp_c`. Checking one value against the source caught it.
- **`%pip install` is off in pipeline runs by default.** The notebook needed the `_inlineInstallationEnabled` base parameter to install the Snowflake connector when triggered by the pipeline.

  
## Repository Structure

```
.github/workflows/   pipeline.yml (CD), ci.yml (CI)
week01-python/       fetch_weather.py
week02-snowflake/    setup SQL, roles, service user, load_weather.py
weather_dbt/         dbt project (models, tests, snapshots, ci_profiles)
docs/images/         screenshots
```

## Next Steps

- ~~Automate the Fabric layer with a Fabric Data Pipeline~~ Done, see Project 2
- Add `cache: pip` to cut install time in GitHub Actions
- ~~Add an `is_forecast` flag, since the API mixes forecast with observed data~~ Done, see Project 3

## Author

**Melvin Licaros**: [LinkedIn](https://www.linkedin.com/in/melvin-licaros-1a0653109) · [Portfolio](https://melvinlicaros.github.io)
