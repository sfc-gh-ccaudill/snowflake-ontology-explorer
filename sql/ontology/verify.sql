-- ===========================================================================
-- verify.sql — assert the ontology deployed correctly.
--
-- Rendered by deploy.sh (database/schema names come from config.env). Run via:
--   ./deploy.sh verify        (or: snow sql -c <conn> -f build/sql_ontology_verify.sql)
--
-- Expected counts are the validated reference deployment. A row showing FAIL
-- means that object did not build as expected — re-run the matching phase file.
-- ===========================================================================
USE SCHEMA CLINICAL_EMR.ONTOLOGY;

WITH checks AS (
    SELECT 'KG_NODE (instances + TBox)'        AS check_name, (SELECT COUNT(*) FROM KG_NODE)            AS actual,  883 AS expected
    UNION ALL SELECT 'KG_EDGE',                 (SELECT COUNT(*) FROM KG_EDGE),           2260
    UNION ALL SELECT 'ONT_CLASS',              (SELECT COUNT(*) FROM ONT_CLASS),           22
    UNION ALL SELECT 'ONT_RELATION_DEF',       (SELECT COUNT(*) FROM ONT_RELATION_DEF),    33
    UNION ALL SELECT 'ONT_OBJECT_SOURCE',      (SELECT COUNT(*) FROM ONT_OBJECT_SOURCE),   46
    UNION ALL SELECT 'ONT_IDENTITY_RULE',      (SELECT COUNT(*) FROM ONT_IDENTITY_RULE),    9
    UNION ALL SELECT 'ONT_CLASS_MAP',          (SELECT COUNT(*) FROM ONT_CLASS_MAP),       17
)
SELECT
    check_name,
    expected,
    actual,
    IFF(actual = expected, 'PASS', 'FAIL') AS status
FROM checks
ORDER BY status DESC, check_name;

-- Semantic views (expect 4: BASE, KG_MODEL, ONTOLOGY_MODEL, METADATA_MODEL)
SHOW SEMANTIC VIEWS IN SCHEMA CLINICAL_EMR.ONTOLOGY;

-- Agents (expect 2: HEALTHCARE_ONTOLOGY_AGENT, HEALTHCARE_BASE_AGENT)
SHOW AGENTS IN SCHEMA CLINICAL_EMR.ONTOLOGY;
