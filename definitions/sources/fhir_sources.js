/**
 * definitions/sources/fhir_sources.js
 *
 * Declares the Google Cloud Healthcare API "Analytics V2" BigQuery export
 * tables this project reads from: one declaration per FHIR resource type,
 * each holding the full FHIR resource structure as nested STRUCT/ARRAY
 * columns (this is the standard Analytics V2 export shape - one table per
 * resource type, not one row-per-field).
 *
 * PLACEHOLDER: `fhir_analytics` is a placeholder dataset name. Point
 * `dataform.projectConfig.vars.fhirDataset` (see workflow_settings.yaml) at
 * the real dataset your Cloud Healthcare API FHIR store export lands in.
 *
 * These are declarations only - Dataform does not create or manage this
 * dataset/these tables, it only documents/type-checks against them so
 * downstream staging models can `${ref(...)}` them like any other model.
 */

const dataset = dataform.projectConfig.vars.fhirDataset;

// The 10 core resource types the staging/fhir layer builds flattening views
// for, plus 3 extra resource types used by minimal stub staging views (see
// definitions/staging/fhir/README notes inline in stg_fhir__device.sqlx /
// stg_fhir__immunization.sqlx / stg_fhir__coverage.sqlx) so the full OMOP
// CDM layer still compiles.
const resources = [
  "Patient",
  "Encounter",
  "Condition",
  "Observation",
  "MedicationRequest",
  "Procedure",
  "Location",
  "Organization",
  "Practitioner",
  "AllergyIntolerance",
  // extra resources feeding stub staging models (see caveats in README)
  "Immunization",
  "Device",
  "Coverage",
];

resources.forEach((resourceType) => {
  declare({
    database: dataform.projectConfig.defaultDatabase,
    schema: dataset,
    name: resourceType,
    description: `Analytics V2 export of the FHIR ${resourceType} resource - one row per resource instance, full FHIR structure preserved as nested STRUCT/ARRAY columns. PLACEHOLDER declaration: validate against your actual export's schema.`,
  });
});
