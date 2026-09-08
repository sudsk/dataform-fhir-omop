# dataform-fhir-omop

A reference Dataform/BigQuery pipeline that transforms FHIR data - landed in
BigQuery via the Google Cloud Healthcare API's **Analytics V2** export (one
BigQuery table per FHIR resource type, full FHIR structure preserved as
nested `STRUCT`/`ARRAY` columns) - into the [OHDSI OMOP Common Data Model
(CDM) v5.4](https://ohdsi.github.io/CommonDataModel/). Built as a portfolio
reference asset for a biodata platform project (KFUPM); not wired to a live
GCP project - every project/dataset name in this repo is a documented
placeholder (see `workflow_settings.yaml`).

## What this is

This is a from-scratch Dataform port that combines the ideas of two existing
Apache-2.0 open source projects (full attribution in `NOTICE`):

- **[OHDSI/dbt-synthea](https://github.com/OHDSI/dbt-synthea)** - a dbt
  project that goes Synthea-CSV -> OMOP CDM. Its `intermediate` and `omop`
  layers (vocabulary-standardization joins, visit reshaping, and the full
  34-table OMOP CDM DDL/business logic) are largely source-agnostic, so this
  project **mechanically ports them** from dbt/Jinja SQL to Dataform SQLX.
  Its `staging/synthea` layer (Synthea-CSV-specific) was **not** ported - it
  doesn't apply to FHIR-sourced data.
- **[google/fhir-dbt-utils](https://github.com/google/fhir-dbt-utils)** - a
  dbt package that targets exactly the Analytics V2 BigQuery export shape.
  Its macros do dynamic column introspection at dbt-compile-time
  (`adapter.get_columns_in_relation()`), which Dataform's SQLX/JS layer has
  no equivalent for. This project instead **hand-writes static, well
  -commented BigQuery SQL** that replicates its field-extraction idioms
  (`code.coding[...].code`, `subject.patientId`/`reference`,
  `identifier[...].value`, etc.) - see "Known simplifications" below.

## Architecture (medallion-style layering)

```
sources/           Dataform *declarations* for the FHIR Analytics V2 tables
                    and the OMOP vocabulary seed tables (not managed by this
                    project - point them at your real datasets).

staging/fhir/       One flattening VIEW per FHIR resource - turns nested
                    FHIR STRUCT/ARRAY columns into flat, typed columns.
staging/vocabulary/ Thin passthrough VIEWs over the OMOP vocabulary tables.
staging/map/        US state name <-> abbreviation lookup.

intermediate/       TRANSIENT SCAFFOLDING TABLES. Vocabulary-standardization
                    joins, visit-reshaping, and other business logic that
                    exists purely to feed the omop/ layer. Not meant for
                    direct consumption by anything downstream of this repo.

omop/                THE CONFORMED "SILVER" LAYER: all 34 OMOP CDM v5.4
                    tables, fully populated from the layers above. This is
                    the intended integration point for anything else (a BI
                    tool, an OHDSI ATLAS/WebAPI instance, a downstream
                    "gold" layer of use-case-specific marts). Building that
                    gold layer (e.g. a KFUPM-specific cohort or analytics
                    mart) is intentionally OUT OF SCOPE here - a natural
                    next repo, not part of this one.
```

## Setup

1. `npm install`
2. Edit `workflow_settings.yaml` - replace `defaultProject`, `defaultLocation`,
   and every dataset name under `vars` with your real GCP project/datasets.
3. Load the OMOP vocabulary seeds into BigQuery:
   - edit the `PROJECT_ID`/`DATASET` placeholders at the top of
     `scripts/load_seeds_to_bq.sh`
   - `bq mk --location=US <project>:<vocab-dataset>` (if the dataset doesn't exist yet)
   - `./scripts/load_seeds_to_bq.sh`
4. Ensure your Cloud Healthcare API FHIR store's Analytics V2 export has
   landed Patient/Encounter/Condition/Observation/MedicationRequest/
   Procedure/Location/Organization/Practitioner/AllergyIntolerance (plus
   Immunization/Device/Coverage if you want those paths populated too - see
   caveats) tables in the dataset named in `vars.fhirDataset`.
5. `dataform run` (or run a specific tag/layer with `--tags`).

Layers must run in order: `staging` -> `intermediate` -> `omop` (Dataform's
dependency graph, built from `${ref(...)}` calls, handles this automatically
- there's nothing to do manually here, just noting the shape).

## What was ported vs. built new

| Layer | Source | Treatment |
|---|---|---|
| `staging/fhir/*` | new (patterns from fhir-dbt-utils) | hand-written flattening SQL |
| `staging/vocabulary/*`, `staging/map/*` | dbt-synthea | ported (simplified - see below) |
| `intermediate/*` | dbt-synthea | ported, re-pointed at `stg_fhir__*` |
| `omop/*` (all 34 CDM tables) | dbt-synthea | ported |

All 34 OMOP CDM tables compile and are wired end-to-end. Three of them
(`device_exposure`, `payer_plan_period`, and the immunization arm of
`drug_exposure`) depend on FHIR resources (Device, Coverage, Immunization)
that were **not** in this project's required FHIR staging scope (Patient,
Encounter, Condition, Observation, MedicationRequest, Procedure, Location,
Organization, Practitioner, AllergyIntolerance). Rather than leave those
three tables un-compilable, this repo includes minimal, clearly-commented
**stub** staging views (`stg_fhir__device.sqlx`, `stg_fhir__coverage.sqlx`,
`stg_fhir__immunization.sqlx`) that produce the right shape but haven't been
exercised as carefully as the in-scope ones - treat them as a starting point,
not a finished mapping.

## Caveats - read before pointing this at real data

- **FHIR field-extraction paths are illustrative, not verified.** Every
  `staging/fhir/*.sqlx` file's header says this explicitly. Analytics V2's
  exact export shape can vary by Cloud Healthcare API version, FHIR store
  configuration, and which FHIR profile/IG your source data conforms to
  (this project's Patient race/ethnicity extraction, for instance, assumes
  US Core extensions). **Validate every field path against your actual FHIR
  store's BigQuery export schema before running this against real data.**
- **Dynamic schema handling was intentionally not replicated.**
  fhir-dbt-utils does column introspection and multi-table-per-resource
  union handling at dbt-compile-time via `adapter.get_columns_in_relation()`.
  Dataform's SQLX/JS compiler has no equivalent warehouse-introspection API,
  so this is a known simplification/future extension point, not an
  oversight - a schema-drift-tolerant loader would need to be built as a
  custom Dataform "operation" or a pre-processing step outside Dataform.
- **Vocabulary seeds must be loaded before anything else will run** - see
  Setup step 3. `intermediate/int__source_to_standard_vocab_map.sqlx` and
  most of the `omop/` layer read directly or indirectly from them.
- **All project/dataset names are placeholders** - `your-gcp-project`,
  `fhir_analytics`, `vocab_seeds`, `stg_fhir`, `stg_vocabulary`, `int_omop`,
  `cdm_omop`. Swap them for real values in `workflow_settings.yaml` (and in
  `scripts/load_seeds_to_bq.sh`, which is a plain shell script, not
  Dataform-templated).
- **Cost/billing fields are NULL throughout** (`base_encounter_cost`,
  `medication_base_cost`, etc.) - FHIR core has no billing/cost resource
  equivalent to Synthea's CSVs; that data lives in `Claim`/
  `ExplanationOfBenefit` resources, out of scope here.
- Some `_models/*.yml` documentation/test files that existed in the
  dbt-synthea source were not ported - Dataform has its own (different)
  assertion mechanism (`config { assertions: {...} }`), and adding a full
  parallel test suite was out of scope for this reference build.
