/**
 * definitions/sources/vocab_sources.js
 *
 * Declares the OMOP standardized vocabulary tables loaded into BigQuery from
 * the OHDSI Athena vocabulary download (via scripts/load_seeds_to_bq.sh,
 * seeded from the CSVs in seeds/vocabulary/ and seeds/stcm/, ported verbatim
 * from OHDSI/dbt-synthea). Dataform has no native seed-loading mechanism
 * (unlike dbt's `dbt seed`), so these tables must be loaded into BigQuery
 * out-of-band before the staging/vocabulary and intermediate/omop layers
 * can run - see scripts/load_seeds_to_bq.sh and the README.
 *
 * PLACEHOLDER: `vocab_seeds` is a placeholder dataset name - point
 * `dataform.projectConfig.vars.vocabSeedDataset` (see workflow_settings.yaml)
 * at wherever you load the real OMOP vocabulary CSVs.
 *
 * Table/column names and types match OHDSI/dbt-synthea's dbt_project.yml
 * `vars.vocab_tables` block and seeds/vocabulary/*.csv headers exactly.
 */

const dataset = dataform.projectConfig.vars.vocabSeedDataset;

// name -> the *_seed table this project's load script creates in BigQuery
const vocabTables = [
  "concept_seed",
  "concept_ancestor_seed",
  "concept_class_seed",
  "concept_relationship_seed",
  "concept_synonym_seed",
  "domain_seed",
  "drug_strength_seed",
  "relationship_seed",
  "vocabulary_seed",
  "source_to_concept_map_seed",
];

vocabTables.forEach((name) => {
  declare({
    database: dataform.projectConfig.defaultDatabase,
    schema: dataset,
    name,
    description: `OMOP vocabulary seed table (from OHDSI Athena export), loaded via scripts/load_seeds_to_bq.sh from seeds/vocabulary/${name}.csv.`,
  });
});

declare({
  database: dataform.projectConfig.defaultDatabase,
  schema: dataset,
  name: "states_seed",
  description: "US state name <-> abbreviation lookup, loaded from seeds/map/states.csv via scripts/load_seeds_to_bq.sh.",
});
