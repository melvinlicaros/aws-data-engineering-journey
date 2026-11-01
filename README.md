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

## Repository Structure

```
.github/workflows/   pipeline.yml (CD), ci.yml (CI)
week01-python/       fetch_weather.py
week02-snowflake/    setup SQL, roles, service user, load_weather.py
weather_dbt/         dbt project (models, tests, snapshots, ci_profiles)
docs/images/         screenshots
```

## Next Steps

- Automate the Fabric layer with a Fabric Data Pipeline (run notebook, then refresh the semantic model)
- Add `cache: pip` to cut install time in GitHub Actions
- Add an `is_forecast` flag, since the API mixes forecast with observed data

## Author

**Melvin Licaros**: [LinkedIn](https://www.linkedin.com/in/melvin-licaros-1a0653109) · [Portfolio](https://melvinlicaros.github.io)