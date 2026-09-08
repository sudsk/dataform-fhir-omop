#!/usr/bin/env bash
#
# scripts/load_seeds_to_bq.sh
#
# Loads the OMOP vocabulary seed CSVs (ported verbatim from
# OHDSI/dbt-synthea's seeds/ directory) into BigQuery. Dataform has no
# native seed-loading mechanism (unlike dbt's `dbt seed`), so this is a
# one-time (or CI-triggered) `bq load` script that must be run BEFORE
# `dataform run`, since staging/vocabulary/*.sqlx and everything downstream
# of it depend on these tables existing.
#
# *** PLACEHOLDERS: edit PROJECT_ID and DATASET below before running. ***
# These must match workflow_settings.yaml's defaultProject and
# vars.vocabSeedDataset.
#
# Usage:
#   ./scripts/load_seeds_to_bq.sh
#
# Requires: gcloud/bq CLI authenticated against the target project, and the
# target dataset to already exist (`bq mk --location=US $PROJECT_ID:$DATASET`).

set -euo pipefail

PROJECT_ID="your-gcp-project"   # <-- REPLACE with your real GCP project ID
DATASET="vocab_seeds"           # <-- REPLACE if you changed vars.vocabSeedDataset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEEDS_DIR="$SCRIPT_DIR/../seeds"

echo "Loading OMOP vocabulary seeds into ${PROJECT_ID}:${DATASET} ..."

# --- seeds/vocabulary/*.csv -> vocab_tables (column names/types match
#     OHDSI/dbt-synthea's dbt_project.yml `vars.vocab_tables` block) ---

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="concept_id:INTEGER,concept_name:STRING,domain_id:STRING,vocabulary_id:STRING,concept_class_id:STRING,standard_concept:STRING,concept_code:STRING,valid_start_date:DATE,valid_end_date:DATE,invalid_reason:STRING" \
  "${PROJECT_ID}:${DATASET}.concept_seed" \
  "$SEEDS_DIR/vocabulary/concept_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="ancestor_concept_id:INTEGER,descendant_concept_id:INTEGER,min_levels_of_separation:INTEGER,max_levels_of_separation:INTEGER" \
  "${PROJECT_ID}:${DATASET}.concept_ancestor_seed" \
  "$SEEDS_DIR/vocabulary/concept_ancestor_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="concept_class_id:STRING,concept_class_name:STRING,concept_class_concept_id:INTEGER" \
  "${PROJECT_ID}:${DATASET}.concept_class_seed" \
  "$SEEDS_DIR/vocabulary/concept_class_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="concept_id_1:INTEGER,concept_id_2:INTEGER,relationship_id:STRING,valid_start_date:DATE,valid_end_date:DATE,invalid_reason:STRING" \
  "${PROJECT_ID}:${DATASET}.concept_relationship_seed" \
  "$SEEDS_DIR/vocabulary/concept_relationship_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="concept_id:INTEGER,concept_synonym_name:STRING,language_concept_id:INTEGER" \
  "${PROJECT_ID}:${DATASET}.concept_synonym_seed" \
  "$SEEDS_DIR/vocabulary/concept_synonym_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="domain_id:STRING,domain_name:STRING,domain_concept_id:INTEGER" \
  "${PROJECT_ID}:${DATASET}.domain_seed" \
  "$SEEDS_DIR/vocabulary/domain_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="drug_concept_id:INTEGER,ingredient_concept_id:INTEGER,amount_value:FLOAT,amount_unit_concept_id:INTEGER,numerator_value:FLOAT,numerator_unit_concept_id:INTEGER,denominator_value:FLOAT,denominator_unit_concept_id:INTEGER,box_size:INTEGER,valid_start_date:DATE,valid_end_date:DATE,invalid_reason:STRING" \
  "${PROJECT_ID}:${DATASET}.drug_strength_seed" \
  "$SEEDS_DIR/vocabulary/drug_strength_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="relationship_id:STRING,relationship_name:STRING,is_hierarchical:STRING,defines_ancestry:STRING,reverse_relationship_id:STRING,relationship_concept_id:INTEGER" \
  "${PROJECT_ID}:${DATASET}.relationship_seed" \
  "$SEEDS_DIR/vocabulary/relationship_seed.csv"

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="vocabulary_id:STRING,vocabulary_name:STRING,vocabulary_reference:STRING,vocabulary_version:STRING,vocabulary_concept_id:INTEGER" \
  "${PROJECT_ID}:${DATASET}.vocabulary_seed" \
  "$SEEDS_DIR/vocabulary/vocabulary_seed.csv"

# --- seeds/stcm/*.csv -> custom source-to-concept mappings ---

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="source_code:STRING,source_concept_id:INTEGER,source_vocabulary_id:STRING,source_code_description:STRING,source_domain_id:STRING,source_concept_class_id:STRING,target_concept_id:INTEGER,target_concept_name:STRING,target_vocabulary_id:STRING,target_domain_id:STRING,target_concept_class_id:STRING,valid_start_date:DATE,valid_end_date:DATE,invalid_reason:STRING" \
  "${PROJECT_ID}:${DATASET}.source_to_concept_map_seed" \
  "$SEEDS_DIR/stcm/source_to_concept_map_seed.csv"

# --- seeds/map/*.csv -> US state name <-> abbreviation lookup ---

bq load --project_id="$PROJECT_ID" --replace --source_format=CSV --skip_leading_rows=1 \
  --schema="state_name:STRING,state_abbreviation:STRING" \
  "${PROJECT_ID}:${DATASET}.states_seed" \
  "$SEEDS_DIR/map/states.csv"

echo "Done. Loaded 10 seed tables into ${PROJECT_ID}:${DATASET}."
