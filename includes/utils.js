/**
 * includes/utils.js
 *
 * Small JS helpers used from .sqlx files via ${ } templating, replacing a
 * handful of dbt-synthea/dbt-utils macros that don't have a Dataform-native
 * equivalent. Dataform's SQLX compiler runs arbitrary JS inside ${...} and
 * `js { }` blocks, so these are plain functions returning SQL text - not a
 * warehouse-introspection layer (Dataform has no dbt-style
 * adapter.get_columns_in_relation() at compile time, so nothing here reads
 * the warehouse; it only assembles static SQL strings).
 *
 * Substituted macros:
 *   - safe_hash(columns)      (dbt-synthea macro) -> safeHash(columns)
 *       MD5 of the COALESCE-and-concatenated columns, used as a stable
 *       natural key for locations built from FHIR address fields.
 *   - string_truncate(expr,n) (dbt-synthea macro) -> handled inline as
 *       SUBSTR(expr, 1, n) directly in the ported SQL (no helper needed).
 *   - regexp_like(expr, pat)  (dbt-synthea macro) -> handled inline as
 *       REGEXP_CONTAINS(expr, r'pat') directly in the ported SQL.
 *   - dbt.cast / dbt_date.date_part / dbt.dateadd / dbt.datediff / dbt.replace
 *       -> translated inline to CAST(... AS ...), EXTRACT(... FROM ...),
 *          DATE_ADD/DATE_SUB, DATE_DIFF, REPLACE(...) respectively, at each
 *          call site (BigQuery has native equivalents, so no helper needed).
 */

/**
 * MD5 hash of a list of SQL column-reference expressions, each COALESCEd to
 * empty string before concatenation. Mirrors dbt-synthea's safe_hash() macro
 * (macros/safe_hash.sql), used to build a stable natural key (e.g. for
 * deduplicating locations parsed out of FHIR address structs).
 *
 * @param {string[]} columns - raw SQL expressions (already-qualified column
 *   references), e.g. ["p.patient_address", "p.patient_city"]
 * @returns {string} a `TO_HEX(MD5(CONCAT(...)))` SQL expression
 */
function safeHash(columns) {
  const coalesced = columns.map((c) => `COALESCE(CAST(${c} AS STRING), '')`);
  return `TO_HEX(MD5(CONCAT(${coalesced.join(", ")})))`;
}

module.exports = { safeHash };
