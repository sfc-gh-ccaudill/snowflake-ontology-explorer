-- =============================================================================
-- PHASE 5 — Ontology-layer semantic views (Cortex Analyst)
-- HEALTHCARE_ONTOLOGY  ·  CLINICAL_EMR.ONTOLOGY
-- =============================================================================
-- Three semantic views over the deployed ontology objects (LIVE definitions
-- captured with GET_DDL('SEMANTIC_VIEW', ...)):
--   * _KG_MODEL       — entity STAR over typed V_{CLASS} views (facts carry
--                       inline FKs -> Patient/Practitioner/Medication dims);
--                       22 relationships. Cross-system multi-hop queries.
--   * _ONTOLOGY_MODEL — VW_ONT_ALL_ENTITIES + REL_RESOLVED + hierarchy; 2 rels.
--                       Cross-type / abstract reasoning.
--   * _METADATA_MODEL — ONT_CLASS hub + provenance/identity/mapping tables;
--                       3 rels. Questions ABOUT the ontology itself.
-- =============================================================================
USE SCHEMA CLINICAL_EMR.ONTOLOGY;

-- --------------------------------------------------------------------------
-- KG semantic view (entity star)
-- --------------------------------------------------------------------------
create or replace semantic view HEALTHCARE_ONTOLOGY_KG_MODEL
	tables (
		CLINICAL_EMR.ONTOLOGY.V_PATIENT primary key (MRN),
		CLINICAL_EMR.ONTOLOGY.V_PRACTITIONER primary key (DEPT_ID) unique (NPI),
		CLINICAL_EMR.ONTOLOGY.V_MEDICATION primary key (RXNORM_CODE),
		CLINICAL_EMR.ONTOLOGY.V_CONDITION primary key (ICD10_DOTTED),
		CLINICAL_EMR.ONTOLOGY.V_PROCEDURE primary key (CPT_CODE),
		CLINICAL_EMR.ONTOLOGY.V_SERVICESETTING primary key (POS_CODE),
		CLINICAL_EMR.ONTOLOGY.V_LOCATION primary key (DEPT_ID),
		CLINICAL_EMR.ONTOLOGY.V_FACILITY primary key (FACILITY_KEY),
		CLINICAL_EMR.ONTOLOGY.V_PAYER primary key (PAYER_NAME),
		CLINICAL_EMR.ONTOLOGY.V_ENCOUNTER primary key (PATIENT_KEY) unique (VISIT_ID),
		CLINICAL_EMR.ONTOLOGY.V_CLAIM primary key (CLAIM_ID) unique (PATIENT_KEY),
		CLINICAL_EMR.ONTOLOGY.V_CLAIMLINE,
		CLINICAL_EMR.ONTOLOGY.V_MEDICATIONREQUEST,
		CLINICAL_EMR.ONTOLOGY.V_MEDICATIONDISPENSE,
		CLINICAL_EMR.ONTOLOGY.V_COVERAGE,
		CLINICAL_EMR.ONTOLOGY.V_OBSERVATION,
		CLINICAL_EMR.ONTOLOGY.V_RELATEDPERSON primary key (PATIENT_KEY)
	)
	relationships (
		V_PRACTITIONER_TO_V_LOCATION as V_PRACTITIONER(DEPT_ID) references V_LOCATION(DEPT_ID),
		V_LOCATION_TO_V_FACILITY as V_LOCATION(FACILITY_KEY) references V_FACILITY(FACILITY_KEY),
		V_ENCOUNTER_TO_V_CONDITION as V_ENCOUNTER(PRIMARY_ICD10) references V_CONDITION(ICD10_DOTTED),
		V_ENCOUNTER_TO_V_LOCATION as V_ENCOUNTER(DEPT_ID) references V_LOCATION(DEPT_ID),
		V_ENCOUNTER_TO_V_PATIENT as V_ENCOUNTER(PATIENT_KEY) references V_PATIENT(MRN),
		V_ENCOUNTER_TO_V_PRACTITIONER as V_ENCOUNTER(NPI) references V_PRACTITIONER(NPI),
		V_CLAIM_TO_V_PATIENT as V_CLAIM(PATIENT_KEY) references V_PATIENT(MRN),
		V_CLAIM_TO_V_PRACTITIONER as V_CLAIM(RENDERING_NPI) references V_PRACTITIONER(NPI),
		V_CLAIM_TO_V_SERVICESETTING as V_CLAIM(POS_CODE) references V_SERVICESETTING(POS_CODE),
		V_CLAIMLINE_TO_V_CLAIM as V_CLAIMLINE(CLAIM_ID) references V_CLAIM(CLAIM_ID),
		V_CLAIMLINE_TO_V_CONDITION as V_CLAIMLINE(DX_CANONICAL) references V_CONDITION(ICD10_DOTTED),
		V_CLAIMLINE_TO_V_PROCEDURE as V_CLAIMLINE(CPT_CODE) references V_PROCEDURE(CPT_CODE),
		V_MEDICATIONREQUEST_TO_V_MEDICATION as V_MEDICATIONREQUEST(RXNORM_RESOLVED) references V_MEDICATION(RXNORM_CODE),
		V_MEDICATIONREQUEST_TO_V_PATIENT as V_MEDICATIONREQUEST(PATIENT_KEY) references V_PATIENT(MRN),
		V_MEDICATIONREQUEST_TO_V_PRACTITIONER as V_MEDICATIONREQUEST(PHYSICIAN_NPI) references V_PRACTITIONER(NPI),
		V_MEDICATIONDISPENSE_TO_V_MEDICATION as V_MEDICATIONDISPENSE(RXNORM_CODE) references V_MEDICATION(RXNORM_CODE),
		V_MEDICATIONDISPENSE_TO_V_PATIENT as V_MEDICATIONDISPENSE(PATIENT_KEY) references V_PATIENT(MRN),
		V_MEDICATIONDISPENSE_TO_V_PRACTITIONER as V_MEDICATIONDISPENSE(PRESCRIBER_NPI) references V_PRACTITIONER(NPI),
		V_COVERAGE_TO_V_PATIENT as V_COVERAGE(PATIENT_KEY) references V_PATIENT(MRN),
		V_COVERAGE_TO_V_PAYER as V_COVERAGE(PAYER_NAME) references V_PAYER(PAYER_NAME),
		V_OBSERVATION_TO_V_ENCOUNTER as V_OBSERVATION(VISIT_ID) references V_ENCOUNTER(VISIT_ID),
		V_OBSERVATION_TO_V_PATIENT as V_OBSERVATION(PATIENT_KEY) references V_PATIENT(MRN)
	)
	dimensions (
		V_PATIENT.NODE_ID as NODE_ID,
		V_PATIENT.NAME as NAME,
		V_PATIENT.MRN as MRN,
		V_PATIENT.MEMBER_ID as MEMBER_ID,
		V_PATIENT.RX_MEMBER_ID as RX_MEMBER_ID,
		V_PATIENT.SSN as SSN,
		V_PATIENT.FULL_NAME as FULL_NAME,
		V_PATIENT.FIRST_NAME as FIRST_NAME,
		V_PATIENT.LAST_NAME as LAST_NAME,
		V_PATIENT.GENDER as GENDER,
		V_PATIENT.CITY as CITY,
		V_PATIENT.STATE as STATE,
		V_PATIENT.ZIP as ZIP,
		V_PATIENT.PHONE as PHONE,
		V_PATIENT.SOURCE_SYSTEMS as SOURCE_SYSTEMS,
		V_PATIENT.PROPS as PROPS,
		V_PATIENT.DOB as DOB,
		V_PRACTITIONER.NODE_ID as NODE_ID,
		V_PRACTITIONER.NAME as NAME,
		V_PRACTITIONER.NPI as NPI,
		V_PRACTITIONER.FULL_NAME as FULL_NAME,
		V_PRACTITIONER.NAME_EMR as NAME_EMR,
		V_PRACTITIONER.NAME_CLAIMS as NAME_CLAIMS,
		V_PRACTITIONER.NAME_PHARMACY as NAME_PHARMACY,
		V_PRACTITIONER.SPECIALTY as SPECIALTY,
		V_PRACTITIONER.SPECIALTY_RAW_CLAIMS as SPECIALTY_RAW_CLAIMS,
		V_PRACTITIONER.LOCAL_PHYSICIAN_ID as LOCAL_PHYSICIAN_ID,
		V_PRACTITIONER.DEPT_ID as DEPT_ID,
		V_PRACTITIONER.DEA_NUMBER as DEA_NUMBER,
		V_PRACTITIONER.SOURCE_SYSTEMS as SOURCE_SYSTEMS,
		V_PRACTITIONER.PROPS as PROPS,
		V_MEDICATION.NODE_ID as NODE_ID,
		V_MEDICATION.NAME as NAME,
		V_MEDICATION.RXNORM_CODE as RXNORM_CODE,
		V_MEDICATION.GENERIC_NAME as GENERIC_NAME,
		V_MEDICATION.BRAND_NAME as BRAND_NAME,
		V_MEDICATION.STRENGTH as STRENGTH,
		V_MEDICATION.DOSAGE_FORM as DOSAGE_FORM,
		V_MEDICATION.NDC_EXAMPLE as NDC_EXAMPLE,
		V_MEDICATION.PROPS as PROPS,
		V_CONDITION.NODE_ID as NODE_ID,
		V_CONDITION.NAME as NAME,
		V_CONDITION.ICD10_DOTTED as ICD10_DOTTED,
		V_CONDITION.ICD10_NODOT as ICD10_NODOT,
		V_CONDITION.ICD10_DESC as ICD10_DESC,
		V_CONDITION.SNOMED_CODE as SNOMED_CODE,
		V_CONDITION.SOURCE_SYSTEMS as SOURCE_SYSTEMS,
		V_CONDITION.PROPS as PROPS,
		V_PROCEDURE.NODE_ID as NODE_ID,
		V_PROCEDURE.NAME as NAME,
		V_PROCEDURE.CPT_CODE as CPT_CODE,
		V_PROCEDURE.CPT_DESC as CPT_DESC,
		V_PROCEDURE.PROPS as PROPS,
		V_SERVICESETTING.NODE_ID as NODE_ID,
		V_SERVICESETTING.NAME as NAME,
		V_SERVICESETTING.POS_CODE as POS_CODE,
		V_SERVICESETTING.POS_DESCRIPTION as POS_DESCRIPTION,
		V_SERVICESETTING.PROPS as PROPS,
		V_LOCATION.NODE_ID as NODE_ID,
		V_LOCATION.NAME as NAME,
		V_LOCATION.DEPT_ID as DEPT_ID,
		V_LOCATION.DEPT_NAME as DEPT_NAME,
		V_LOCATION.FACILITY_NAME as FACILITY_NAME,
		V_LOCATION.FACILITY_KEY as FACILITY_KEY,
		V_LOCATION.ADDRESS as ADDRESS,
		V_LOCATION.CITY as CITY,
		V_LOCATION.STATE as STATE,
		V_LOCATION.ZIP as ZIP,
		V_LOCATION.PROPS as PROPS,
		V_FACILITY.NODE_ID as NODE_ID,
		V_FACILITY.NAME as NAME,
		V_FACILITY.FACILITY_KEY as FACILITY_KEY,
		V_FACILITY.FACILITY_NAME as FACILITY_NAME,
		V_FACILITY.PROPS as PROPS,
		V_PAYER.NODE_ID as NODE_ID,
		V_PAYER.NAME as NAME,
		V_PAYER.PAYER_NAME as PAYER_NAME,
		V_PAYER.SOURCE_SYSTEMS as SOURCE_SYSTEMS,
		V_PAYER.PROPS as PROPS,
		V_ENCOUNTER.NODE_ID as NODE_ID,
		V_ENCOUNTER.NAME as NAME,
		V_ENCOUNTER.VISIT_ID as VISIT_ID,
		V_ENCOUNTER.VISIT_TYPE as VISIT_TYPE,
		V_ENCOUNTER.STATUS as STATUS,
		V_ENCOUNTER.PATIENT_KEY as PATIENT_KEY,
		V_ENCOUNTER.NPI as NPI,
		V_ENCOUNTER.DEPT_ID as DEPT_ID,
		V_ENCOUNTER.PRIMARY_ICD10 as PRIMARY_ICD10,
		V_ENCOUNTER.PROPS as PROPS,
		V_ENCOUNTER.VISIT_DATE as VISIT_DATE,
		V_CLAIM.NODE_ID as NODE_ID,
		V_CLAIM.NAME as NAME,
		V_CLAIM.CLAIM_ID as CLAIM_ID,
		V_CLAIM.MEMBER_ID as MEMBER_ID,
		V_CLAIM.SUBSCRIBER_ID as SUBSCRIBER_ID,
		V_CLAIM.PATIENT_KEY as PATIENT_KEY,
		V_CLAIM.PLAN_NAME as PLAN_NAME,
		V_CLAIM.RENDERING_NPI as RENDERING_NPI,
		V_CLAIM.POS_CODE as POS_CODE,
		V_CLAIM.CLAIM_STATUS as CLAIM_STATUS,
		V_CLAIM.TOTAL_CHARGE as TOTAL_CHARGE,
		V_CLAIM.TOTAL_PAID as TOTAL_PAID,
		V_CLAIM.PROPS as PROPS,
		V_CLAIM.SERVICE_DATE as SERVICE_DATE,
		V_CLAIMLINE.NODE_ID as NODE_ID,
		V_CLAIMLINE.NAME as NAME,
		V_CLAIMLINE.CLAIM_ID as CLAIM_ID,
		V_CLAIMLINE.LINE_NO as LINE_NO,
		V_CLAIMLINE.CPT_CODE as CPT_CODE,
		V_CLAIMLINE.CPT_DESC as CPT_DESC,
		V_CLAIMLINE.DX_CODE as DX_CODE,
		V_CLAIMLINE.DX_CANONICAL as DX_CANONICAL,
		V_CLAIMLINE.CHARGE_AMT as CHARGE_AMT,
		V_CLAIMLINE.ALLOWED_AMT as ALLOWED_AMT,
		V_CLAIMLINE.PAID_AMT as PAID_AMT,
		V_CLAIMLINE.PROPS as PROPS,
		V_MEDICATIONREQUEST.NODE_ID as NODE_ID,
		V_MEDICATIONREQUEST.NAME as NAME,
		V_MEDICATIONREQUEST.MED_ORDER_ID as MED_ORDER_ID,
		V_MEDICATIONREQUEST.PATIENT_KEY as PATIENT_KEY,
		V_MEDICATIONREQUEST.PHYSICIAN_NPI as PHYSICIAN_NPI,
		V_MEDICATIONREQUEST.DRUG_NAME as DRUG_NAME,
		V_MEDICATIONREQUEST.RXNORM_CODE as RXNORM_CODE,
		V_MEDICATIONREQUEST.RXNORM_RESOLVED as RXNORM_RESOLVED,
		V_MEDICATIONREQUEST.RXNORM_WAS_NULL as RXNORM_WAS_NULL,
		V_MEDICATIONREQUEST.SIG as SIG,
		V_MEDICATIONREQUEST.QUANTITY as QUANTITY,
		V_MEDICATIONREQUEST.REFILLS as REFILLS,
		V_MEDICATIONREQUEST.PROPS as PROPS,
		V_MEDICATIONREQUEST.ORDER_DATE as ORDER_DATE,
		V_MEDICATIONDISPENSE.NODE_ID as NODE_ID,
		V_MEDICATIONDISPENSE.NAME as NAME,
		V_MEDICATIONDISPENSE.FILL_ID as FILL_ID,
		V_MEDICATIONDISPENSE.RX_MEMBER_ID as RX_MEMBER_ID,
		V_MEDICATIONDISPENSE.PATIENT_KEY as PATIENT_KEY,
		V_MEDICATIONDISPENSE.PRESCRIBER_NPI as PRESCRIBER_NPI,
		V_MEDICATIONDISPENSE.NDC as NDC,
		V_MEDICATIONDISPENSE.RXNORM_CODE as RXNORM_CODE,
		V_MEDICATIONDISPENSE.DRUG_DESC as DRUG_DESC,
		V_MEDICATIONDISPENSE.DAYS_SUPPLY as DAYS_SUPPLY,
		V_MEDICATIONDISPENSE.QUANTITY as QUANTITY,
		V_MEDICATIONDISPENSE.FILL_STATUS as FILL_STATUS,
		V_MEDICATIONDISPENSE.PROPS as PROPS,
		V_MEDICATIONDISPENSE.WRITTEN_DATE as WRITTEN_DATE,
		V_MEDICATIONDISPENSE.FILL_DATE as FILL_DATE,
		V_COVERAGE.NODE_ID as NODE_ID,
		V_COVERAGE.NAME as NAME,
		V_COVERAGE.COVERAGE_ID as COVERAGE_ID,
		V_COVERAGE.COVERAGE_SOURCE as COVERAGE_SOURCE,
		V_COVERAGE.PATIENT_KEY as PATIENT_KEY,
		V_COVERAGE.PAYER_NAME as PAYER_NAME,
		V_COVERAGE.PLAN_NAME as PLAN_NAME,
		V_COVERAGE.GROUP_NO as GROUP_NO,
		V_COVERAGE.MEMBER_ID as MEMBER_ID,
		V_COVERAGE.SUBSCRIBER_ID as SUBSCRIBER_ID,
		V_COVERAGE.RELATIONSHIP as RELATIONSHIP,
		V_COVERAGE.PROPS as PROPS,
		V_COVERAGE.EFFECTIVE_DATE as EFFECTIVE_DATE,
		V_COVERAGE.TERM_DATE as TERM_DATE,
		V_OBSERVATION.NODE_ID as NODE_ID,
		V_OBSERVATION.NAME as NAME,
		V_OBSERVATION.OBS_KIND as OBS_KIND,
		V_OBSERVATION.OBS_CODE as OBS_CODE,
		V_OBSERVATION.OBS_NAME as OBS_NAME,
		V_OBSERVATION.VALUE_NUM as VALUE_NUM,
		V_OBSERVATION.UNIT as UNIT,
		V_OBSERVATION.PATIENT_KEY as PATIENT_KEY,
		V_OBSERVATION.VISIT_ID as VISIT_ID,
		V_OBSERVATION.PROPS as PROPS,
		V_OBSERVATION.OBS_DATE as OBS_DATE,
		V_RELATEDPERSON.NODE_ID as NODE_ID,
		V_RELATEDPERSON.NAME as NAME,
		V_RELATEDPERSON.KIN_NAME as KIN_NAME,
		V_RELATEDPERSON.KIN_RELATION as KIN_RELATION,
		V_RELATEDPERSON.KIN_PHONE as KIN_PHONE,
		V_RELATEDPERSON.PATIENT_KEY as PATIENT_KEY,
		V_RELATEDPERSON.RESOLVED_PATIENT_KEY as RESOLVED_PATIENT_KEY,
		V_RELATEDPERSON.PROPS as PROPS
	)
	comment='KG semantic view: resolved healthcare knowledge-graph entities as a star schema. Fact entities (Encounter, Claim, ClaimLine, MedicationRequest, MedicationDispense, Coverage, Observation) carry inline foreign keys (PATIENT_KEY->V_PATIENT.MRN, NPI/PHYSICIAN_NPI/PRESCRIBER_NPI/RENDERING_NPI->V_PRACTITIONER.NPI, RXNORM->V_MEDICATION, ICD10->V_CONDITION, CPT->V_PROCEDURE, POS->V_SERVICESETTING, DEPT_ID->V_LOCATION, PAYER_NAME->V_PAYER). Entities are canonical/resolved across EMR, claims, and pharmacy (one Patient per person, one Practitioner per NPI, one Medication per RxNorm). Use for cross-system multi-hop questions: who treated/prescribed/dispensed to whom, patients per practitioner, drugs per patient, diagnoses, coverage.'
	ai_verified_queries (
		"0;1" AS ( 
QUESTION 'How many encounters does each patient have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.FULL_NAME, COUNT(*) AS c FROM v_encounter AS e JOIN v_patient AS p ON p.MRN = e.PATIENT_KEY GROUP BY 1'),
		"1;1" AS ( 
QUESTION 'How many encounters does each practitioner have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT pr.FULL_NAME, COUNT(*) AS c FROM v_encounter AS e JOIN v_practitioner AS pr ON pr.NPI = e.NPI GROUP BY 1'),
		"2;1" AS ( 
QUESTION 'How many encounters occurred at each department?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT l.DEPT_NAME, COUNT(*) AS c FROM v_encounter AS e JOIN v_location AS l ON l.DEPT_ID = e.DEPT_ID GROUP BY 1'),
		"3;1" AS ( 
QUESTION 'How many encounters occurred for each primary condition?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT c.ICD10_DESC, COUNT(*) AS n FROM v_encounter AS e JOIN v_condition AS c ON c.ICD10_DOTTED = e.PRIMARY_ICD10 GROUP BY 1'),
		"4;1" AS ( 
QUESTION 'How many medication orders does each patient have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.FULL_NAME, COUNT(*) AS c FROM v_medicationrequest AS mr JOIN v_patient AS p ON p.MRN = mr.PATIENT_KEY GROUP BY 1'),
		"5;1" AS ( 
QUESTION 'How many medication orders has each practitioner placed?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT pr.FULL_NAME, COUNT(*) AS c FROM v_medicationrequest AS mr JOIN v_practitioner AS pr ON pr.NPI = mr.PHYSICIAN_NPI GROUP BY 1'),
		"6;1" AS ( 
QUESTION 'How many medication orders were placed for each drug?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT m.GENERIC_NAME, COUNT(*) AS c FROM v_medicationrequest AS mr JOIN v_medication AS m ON m.RXNORM_CODE = mr.RXNORM_RESOLVED GROUP BY 1'),
		"7;1" AS ( 
QUESTION 'How many medication dispenses has each patient received?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.FULL_NAME, COUNT(*) AS c FROM v_medicationdispense AS d JOIN v_patient AS p ON p.MRN = d.PATIENT_KEY GROUP BY 1'),
		"8;1" AS ( 
QUESTION 'How many medication dispenses has each prescriber handled?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT pr.FULL_NAME, COUNT(*) AS c FROM v_medicationdispense AS d JOIN v_practitioner AS pr ON pr.NPI = d.PRESCRIBER_NPI GROUP BY 1'),
		"9;1" AS ( 
QUESTION 'How many times has each medication been dispensed?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT m.GENERIC_NAME, COUNT(*) AS c FROM v_medicationdispense AS d JOIN v_medication AS m ON m.RXNORM_CODE = d.RXNORM_CODE GROUP BY 1'),
		"10;1" AS ( 
QUESTION 'How many claims does each patient have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.FULL_NAME, COUNT(*) AS c FROM v_claim AS cl JOIN v_patient AS p ON p.MRN = cl.PATIENT_KEY GROUP BY 1'),
		"11;1" AS ( 
QUESTION 'How many claims does each rendering practitioner have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT pr.FULL_NAME, COUNT(*) AS c FROM v_claim AS cl JOIN v_practitioner AS pr ON pr.NPI = cl.RENDERING_NPI GROUP BY 1'),
		"12;1" AS ( 
QUESTION 'How many claims were processed for each service setting?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT s.POS_DESCRIPTION, COUNT(*) AS c FROM v_claim AS cl JOIN v_servicesetting AS s ON s.POS_CODE = cl.POS_CODE GROUP BY 1'),
		"13;1" AS ( 
QUESTION 'How many lines does each claim have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT cl.CLAIM_ID, COUNT(*) AS c FROM v_claimline AS cll JOIN v_claim AS cl ON cl.CLAIM_ID = cll.CLAIM_ID GROUP BY 1'),
		"14;1" AS ( 
QUESTION 'How many claim lines are there for each type of medical procedure?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT pr.CPT_DESC, COUNT(*) AS c FROM v_claimline AS cll JOIN v_procedure AS pr ON pr.CPT_CODE = cll.CPT_CODE GROUP BY 1'),
		"15;1" AS ( 
QUESTION 'What is the distribution of claim lines by diagnosis?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT c.ICD10_DESC, COUNT(*) AS n FROM v_claimline AS cll JOIN v_condition AS c ON c.ICD10_DOTTED = cll.DX_CANONICAL GROUP BY 1'),
		"16;1" AS ( 
QUESTION 'How many insurance coverages does each patient have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.FULL_NAME, COUNT(*) AS c FROM v_coverage AS cov JOIN v_patient AS p ON p.MRN = cov.PATIENT_KEY GROUP BY 1'),
		"17;1" AS ( 
QUESTION 'How many coverage records does each insurance payer have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT py.PAYER_NAME, COUNT(*) AS c FROM v_coverage AS cov JOIN v_payer AS py ON py.PAYER_NAME = cov.PAYER_NAME GROUP BY 1'),
		"18;1" AS ( 
QUESTION 'How many observations does each patient have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.FULL_NAME, COUNT(*) AS c FROM v_observation AS o JOIN v_patient AS p ON p.MRN = o.PATIENT_KEY GROUP BY 1'),
		"19;1" AS ( 
QUESTION 'How many observations are recorded for each type of encounter?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT e.VISIT_TYPE, COUNT(*) AS c FROM v_observation AS o JOIN v_encounter AS e ON e.VISIT_ID = o.VISIT_ID GROUP BY 1'),
		"20;1" AS ( 
QUESTION 'How many practitioners work at each department?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT l.DEPT_NAME, COUNT(*) AS c FROM v_practitioner AS pr JOIN v_location AS l ON l.DEPT_ID = pr.DEPT_ID GROUP BY 1'),
		"21;1" AS ( 
QUESTION 'How many locations does each facility have?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT f.FACILITY_NAME, COUNT(*) AS c FROM v_location AS l JOIN v_facility AS f ON f.FACILITY_KEY = l.FACILITY_KEY GROUP BY 1'),
		"22;1" AS ( 
QUESTION 'How many distinct patients did Dr. Chen prescribe medications to?' 
VERIFIED_AT 1783673845
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT COUNT(DISTINCT mr.PATIENT_KEY) AS patients FROM v_medicationrequest AS mr JOIN v_practitioner AS pr ON pr.NPI = mr.PHYSICIAN_NPI WHERE pr.FULL_NAME ILIKE ''%Chen%''')
	)
	with extension (CA='{"tables":[{"name":"V_PATIENT","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"MRN"},{"name":"MEMBER_ID"},{"name":"RX_MEMBER_ID"},{"name":"SSN"},{"name":"FULL_NAME"},{"name":"FIRST_NAME"},{"name":"LAST_NAME"},{"name":"GENDER"},{"name":"CITY"},{"name":"STATE"},{"name":"ZIP"},{"name":"PHONE"},{"name":"SOURCE_SYSTEMS"},{"name":"PROPS"}],"time_dimensions":[{"name":"DOB"}]},{"name":"V_PRACTITIONER","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"NPI"},{"name":"FULL_NAME"},{"name":"NAME_EMR"},{"name":"NAME_CLAIMS"},{"name":"NAME_PHARMACY"},{"name":"SPECIALTY"},{"name":"SPECIALTY_RAW_CLAIMS"},{"name":"LOCAL_PHYSICIAN_ID"},{"name":"DEPT_ID"},{"name":"DEA_NUMBER"},{"name":"SOURCE_SYSTEMS"},{"name":"PROPS"}]},{"name":"V_MEDICATION","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"RXNORM_CODE"},{"name":"GENERIC_NAME"},{"name":"BRAND_NAME"},{"name":"STRENGTH"},{"name":"DOSAGE_FORM"},{"name":"NDC_EXAMPLE"},{"name":"PROPS"}]},{"name":"V_CONDITION","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"ICD10_DOTTED"},{"name":"ICD10_NODOT"},{"name":"ICD10_DESC"},{"name":"SNOMED_CODE"},{"name":"SOURCE_SYSTEMS"},{"name":"PROPS"}]},{"name":"V_PROCEDURE","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"CPT_CODE"},{"name":"CPT_DESC"},{"name":"PROPS"}]},{"name":"V_SERVICESETTING","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"POS_CODE"},{"name":"POS_DESCRIPTION"},{"name":"PROPS"}]},{"name":"V_LOCATION","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"DEPT_ID"},{"name":"DEPT_NAME"},{"name":"FACILITY_NAME"},{"name":"FACILITY_KEY"},{"name":"ADDRESS"},{"name":"CITY"},{"name":"STATE"},{"name":"ZIP"},{"name":"PROPS"}]},{"name":"V_FACILITY","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"FACILITY_KEY"},{"name":"FACILITY_NAME"},{"name":"PROPS"}]},{"name":"V_PAYER","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"PAYER_NAME"},{"name":"SOURCE_SYSTEMS"},{"name":"PROPS"}]},{"name":"V_ENCOUNTER","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"VISIT_ID"},{"name":"VISIT_TYPE"},{"name":"STATUS"},{"name":"PATIENT_KEY"},{"name":"NPI"},{"name":"DEPT_ID"},{"name":"PRIMARY_ICD10"},{"name":"PROPS"}],"time_dimensions":[{"name":"VISIT_DATE"}]},{"name":"V_CLAIM","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"CLAIM_ID"},{"name":"MEMBER_ID"},{"name":"SUBSCRIBER_ID"},{"name":"PATIENT_KEY"},{"name":"PLAN_NAME"},{"name":"RENDERING_NPI"},{"name":"POS_CODE"},{"name":"CLAIM_STATUS"},{"name":"TOTAL_CHARGE"},{"name":"TOTAL_PAID"},{"name":"PROPS"}],"time_dimensions":[{"name":"SERVICE_DATE"}]},{"name":"V_CLAIMLINE","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"CLAIM_ID"},{"name":"LINE_NO"},{"name":"CPT_CODE"},{"name":"CPT_DESC"},{"name":"DX_CODE"},{"name":"DX_CANONICAL"},{"name":"CHARGE_AMT"},{"name":"ALLOWED_AMT"},{"name":"PAID_AMT"},{"name":"PROPS"}]},{"name":"V_MEDICATIONREQUEST","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"MED_ORDER_ID"},{"name":"PATIENT_KEY"},{"name":"PHYSICIAN_NPI"},{"name":"DRUG_NAME"},{"name":"RXNORM_CODE"},{"name":"RXNORM_RESOLVED"},{"name":"RXNORM_WAS_NULL"},{"name":"SIG"},{"name":"QUANTITY"},{"name":"REFILLS"},{"name":"PROPS"}],"time_dimensions":[{"name":"ORDER_DATE"}]},{"name":"V_MEDICATIONDISPENSE","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"FILL_ID"},{"name":"RX_MEMBER_ID"},{"name":"PATIENT_KEY"},{"name":"PRESCRIBER_NPI"},{"name":"NDC"},{"name":"RXNORM_CODE"},{"name":"DRUG_DESC"},{"name":"DAYS_SUPPLY"},{"name":"QUANTITY"},{"name":"FILL_STATUS"},{"name":"PROPS"}],"time_dimensions":[{"name":"WRITTEN_DATE"},{"name":"FILL_DATE"}]},{"name":"V_COVERAGE","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"COVERAGE_ID"},{"name":"COVERAGE_SOURCE"},{"name":"PATIENT_KEY"},{"name":"PAYER_NAME"},{"name":"PLAN_NAME"},{"name":"GROUP_NO"},{"name":"MEMBER_ID"},{"name":"SUBSCRIBER_ID"},{"name":"RELATIONSHIP"},{"name":"PROPS"}],"time_dimensions":[{"name":"EFFECTIVE_DATE"},{"name":"TERM_DATE"}]},{"name":"V_OBSERVATION","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"OBS_KIND"},{"name":"OBS_CODE"},{"name":"OBS_NAME"},{"name":"VALUE_NUM"},{"name":"UNIT"},{"name":"PATIENT_KEY"},{"name":"VISIT_ID"},{"name":"PROPS"}],"time_dimensions":[{"name":"OBS_DATE"}]},{"name":"V_RELATEDPERSON","dimensions":[{"name":"NODE_ID"},{"name":"NAME"},{"name":"KIN_NAME"},{"name":"KIN_RELATION"},{"name":"KIN_PHONE"},{"name":"PATIENT_KEY"},{"name":"RESOLVED_PATIENT_KEY"},{"name":"PROPS"}]}],"relationships":[{"name":"V_CLAIMLINE_TO_V_CLAIM","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_CLAIMLINE_TO_V_CONDITION","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_CLAIMLINE_TO_V_PROCEDURE","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_CLAIM_TO_V_PATIENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_CLAIM_TO_V_PRACTITIONER","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_CLAIM_TO_V_SERVICESETTING","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_COVERAGE_TO_V_PATIENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_COVERAGE_TO_V_PAYER","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_ENCOUNTER_TO_V_CONDITION","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_ENCOUNTER_TO_V_LOCATION","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_ENCOUNTER_TO_V_PATIENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_ENCOUNTER_TO_V_PRACTITIONER","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_LOCATION_TO_V_FACILITY","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_MEDICATIONDISPENSE_TO_V_MEDICATION","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_MEDICATIONDISPENSE_TO_V_PATIENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_MEDICATIONDISPENSE_TO_V_PRACTITIONER","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_MEDICATIONREQUEST_TO_V_MEDICATION","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_MEDICATIONREQUEST_TO_V_PATIENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_MEDICATIONREQUEST_TO_V_PRACTITIONER","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_OBSERVATION_TO_V_ENCOUNTER","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_OBSERVATION_TO_V_PATIENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"V_PRACTITIONER_TO_V_LOCATION","relationship_type":"many_to_one","join_type":"inner"}]}');

-- --------------------------------------------------------------------------
-- Ontology semantic view (cross-type reasoning)
-- --------------------------------------------------------------------------
create or replace semantic view HEALTHCARE_ONTOLOGY_ONTOLOGY_MODEL
	tables (
		CLINICAL_EMR.ONTOLOGY.VW_ONT_ALL_ENTITIES primary key (ENTITY_ID),
		CLINICAL_EMR.ONTOLOGY.REL_RESOLVED,
		CLINICAL_EMR.ONTOLOGY.VW_ONT_HIERARCHY_STATS primary key (CLASS_NAME),
		CLINICAL_EMR.ONTOLOGY.VW_ONT_SUBCLASS_OF primary key (CHILD_CLASS)
	)
	relationships (
		REL_RESOLVED_TO_VW_ONT_ALL_ENTITIES as REL_RESOLVED(DST_ID) references VW_ONT_ALL_ENTITIES(ENTITY_ID),
		VW_ONT_SUBCLASS_OF_TO_VW_ONT_HIERARCHY_STATS as VW_ONT_SUBCLASS_OF(CHILD_CLASS) references VW_ONT_HIERARCHY_STATS(CLASS_NAME)
	)
	facts (
		REL_RESOLVED.WEIGHT as WEIGHT
	)
	dimensions (
		VW_ONT_ALL_ENTITIES.ENTITY_ID as ENTITY_ID,
		VW_ONT_ALL_ENTITIES.ENTITY_TYPE as ENTITY_TYPE,
		VW_ONT_ALL_ENTITIES.ENTITY_NAME as ENTITY_NAME,
		VW_ONT_ALL_ENTITIES.PROPS as PROPS,
		REL_RESOLVED.REL_NAME as REL_NAME,
		REL_RESOLVED.SRC_ID as SRC_ID,
		REL_RESOLVED.SRC_NAME as SRC_NAME,
		REL_RESOLVED.SRC_TYPE as SRC_TYPE,
		REL_RESOLVED.DST_ID as DST_ID,
		REL_RESOLVED.DST_NAME as DST_NAME,
		REL_RESOLVED.DST_TYPE as DST_TYPE,
		REL_RESOLVED.EFFECTIVE_START as EFFECTIVE_START,
		REL_RESOLVED.EFFECTIVE_END as EFFECTIVE_END,
		VW_ONT_HIERARCHY_STATS.CLASS_NAME as CLASS_NAME,
		VW_ONT_HIERARCHY_STATS.PARENT_CLASS_NAME as PARENT_CLASS_NAME,
		VW_ONT_HIERARCHY_STATS.IS_ABSTRACT as IS_ABSTRACT,
		VW_ONT_HIERARCHY_STATS.DESCENDANT_COUNT as DESCENDANT_COUNT,
		VW_ONT_HIERARCHY_STATS.DEPTH_FROM_ROOT as DEPTH_FROM_ROOT,
		VW_ONT_HIERARCHY_STATS.INSTANCE_COUNT as INSTANCE_COUNT,
		VW_ONT_SUBCLASS_OF.CHILD_CLASS as CHILD_CLASS,
		VW_ONT_SUBCLASS_OF.PARENT_CLASS as PARENT_CLASS
	)
	comment='Ontology semantic view for cross-type reasoning: unified entities (VW_ONT_ALL_ENTITIES), resolved relationships (REL_RESOLVED, edges join SRC_ID/DST_ID to entity ENTITY_ID), and class hierarchy. Traverse from an edge to the properties/types of the connected source and destination entities.'
	ai_verified_queries (
		"0;1" AS ( 
QUESTION 'How many entities of each type are there in the healthcare ontology?' 
VERIFIED_AT 1783672979
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT ENTITY_TYPE, COUNT(*) AS c FROM vw_ont_all_entities GROUP BY 1'),
		"1;1" AS ( 
QUESTION 'How many relationships of each type are there in the healthcare ontology?' 
VERIFIED_AT 1783672979
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT REL_NAME, COUNT(*) AS c FROM rel_resolved GROUP BY 1'),
		"2;1" AS ( 
QUESTION 'What types of entities are most commonly targeted in relationships?' 
VERIFIED_AT 1783672979
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT e.ENTITY_TYPE, COUNT(*) AS c FROM rel_resolved AS r JOIN vw_ont_all_entities AS e ON e.ENTITY_ID = r.DST_ID GROUP BY 1'),
		"3;1" AS ( 
QUESTION 'What are the different types of entities that serve as sources in relationships and how many of each type are there?' 
VERIFIED_AT 1783672979
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT e.ENTITY_TYPE, COUNT(*) AS c FROM rel_resolved AS r JOIN vw_ont_all_entities AS e ON e.ENTITY_ID = r.SRC_ID GROUP BY 1'),
		"4;1" AS ( 
QUESTION 'How many instances are there for each subclass?' 
VERIFIED_AT 1783672979
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT sc.CHILD_CLASS, h.INSTANCE_COUNT FROM vw_ont_subclass_of AS sc JOIN vw_ont_hierarchy_stats AS h ON h.CLASS_NAME = sc.CHILD_CLASS')
	)
	with extension (CA='{"tables":[{"name":"VW_ONT_ALL_ENTITIES","dimensions":[{"name":"ENTITY_ID"},{"name":"ENTITY_TYPE"},{"name":"ENTITY_NAME"},{"name":"PROPS"}]},{"name":"REL_RESOLVED","dimensions":[{"name":"REL_NAME"},{"name":"SRC_ID"},{"name":"SRC_NAME"},{"name":"SRC_TYPE"},{"name":"DST_ID"},{"name":"DST_NAME"},{"name":"DST_TYPE"}],"facts":[{"name":"WEIGHT"}],"time_dimensions":[{"name":"EFFECTIVE_START"},{"name":"EFFECTIVE_END"}]},{"name":"VW_ONT_HIERARCHY_STATS","dimensions":[{"name":"CLASS_NAME"},{"name":"PARENT_CLASS_NAME"},{"name":"IS_ABSTRACT"},{"name":"DESCENDANT_COUNT"},{"name":"DEPTH_FROM_ROOT"},{"name":"INSTANCE_COUNT"}]},{"name":"VW_ONT_SUBCLASS_OF","dimensions":[{"name":"CHILD_CLASS"},{"name":"PARENT_CLASS"}]}],"relationships":[{"name":"REL_RESOLVED_TO_VW_ONT_ALL_ENTITIES","relationship_type":"many_to_one","join_type":"inner"},{"name":"VW_ONT_SUBCLASS_OF_TO_VW_ONT_HIERARCHY_STATS","relationship_type":"one_to_one","join_type":"inner"}]}');

-- --------------------------------------------------------------------------
-- Metadata & governance semantic view (about the ontology itself)
-- --------------------------------------------------------------------------
create or replace semantic view HEALTHCARE_ONTOLOGY_METADATA_MODEL
	tables (
		CLINICAL_EMR.ONTOLOGY.ONT_CLASS primary key (CLASS_NAME),
		CLINICAL_EMR.ONTOLOGY.ONT_RELATION_DEF primary key (REL_NAME),
		CLINICAL_EMR.ONTOLOGY.ONT_OBJECT_SOURCE primary key (ONTOLOGY_NAME,OBJ_TYPE,SOURCE_TABLE),
		CLINICAL_EMR.ONTOLOGY.ONT_IDENTITY_RULE,
		CLINICAL_EMR.ONTOLOGY.ONT_CLASS_MAP primary key (CLASS_NAME,MAP_ID)
	)
	relationships (
		ONT_OBJECT_SOURCE_TO_ONT_CLASS as ONT_OBJECT_SOURCE(OBJ_TYPE) references ONT_CLASS(CLASS_NAME),
		ONT_IDENTITY_RULE_TO_ONT_CLASS as ONT_IDENTITY_RULE(CLASS_NAME) references ONT_CLASS(CLASS_NAME),
		ONT_CLASS_MAP_TO_ONT_CLASS as ONT_CLASS_MAP(CLASS_NAME) references ONT_CLASS(CLASS_NAME)
	)
	dimensions (
		ONT_CLASS.CLASS_NAME as CLASS_NAME,
		ONT_CLASS.PARENT_CLASS_NAME as PARENT_CLASS_NAME,
		ONT_CLASS.IS_ABSTRACT as IS_ABSTRACT,
		ONT_CLASS.DESCRIPTION as DESCRIPTION,
		ONT_CLASS.ONTOLOGY_NAME as ONTOLOGY_NAME,
		ONT_CLASS.TYPE_CLASS as TYPE_CLASS,
		ONT_CLASS.CREATED_AT as CREATED_AT,
		ONT_RELATION_DEF.REL_NAME as REL_NAME,
		ONT_RELATION_DEF.DOMAIN_CLASS as DOMAIN_CLASS,
		ONT_RELATION_DEF.RANGE_CLASS as RANGE_CLASS,
		ONT_RELATION_DEF.CARDINALITY as CARDINALITY,
		ONT_RELATION_DEF.IS_HIERARCHICAL as IS_HIERARCHICAL,
		ONT_RELATION_DEF.IS_TRANSITIVE as IS_TRANSITIVE,
		ONT_RELATION_DEF.INVERSE_REL_NAME as INVERSE_REL_NAME,
		ONT_RELATION_DEF.DESCRIPTION as DESCRIPTION,
		ONT_RELATION_DEF.ONTOLOGY_NAME as ONTOLOGY_NAME,
		ONT_OBJECT_SOURCE.ONTOLOGY_NAME as ONTOLOGY_NAME,
		ONT_OBJECT_SOURCE.OBJ_TYPE as OBJ_TYPE,
		ONT_OBJECT_SOURCE.SOURCE_TABLE as SOURCE_TABLE,
		ONT_OBJECT_SOURCE.FILTER_SQL as FILTER_SQL,
		ONT_OBJECT_SOURCE.MAPPING as MAPPING,
		ONT_IDENTITY_RULE.ONTOLOGY_NAME as ONTOLOGY_NAME,
		ONT_IDENTITY_RULE.CLASS_NAME as CLASS_NAME,
		ONT_IDENTITY_RULE.PRIORITY as PRIORITY,
		ONT_IDENTITY_RULE.ID_SYSTEM as ID_SYSTEM,
		ONT_IDENTITY_RULE.MATCH_KEYS as MATCH_KEYS,
		ONT_IDENTITY_RULE.CONFIDENCE as CONFIDENCE,
		ONT_IDENTITY_RULE.DESCRIPTION as DESCRIPTION,
		ONT_IDENTITY_RULE.CREATED_AT as CREATED_AT,
		ONT_CLASS_MAP.MAP_ID as MAP_ID,
		ONT_CLASS_MAP.CLASS_NAME as CLASS_NAME,
		ONT_CLASS_MAP.SOURCE_DATABASE as SOURCE_DATABASE,
		ONT_CLASS_MAP.SOURCE_SCHEMA as SOURCE_SCHEMA,
		ONT_CLASS_MAP.SOURCE_TABLE as SOURCE_TABLE,
		ONT_CLASS_MAP.FILTER_COL as FILTER_COL,
		ONT_CLASS_MAP.FILTER_VAL as FILTER_VAL,
		ONT_CLASS_MAP.ID_EXPR as ID_EXPR,
		ONT_CLASS_MAP.NAME_EXPR as NAME_EXPR,
		ONT_CLASS_MAP.SUBTYPE_EXPR as SUBTYPE_EXPR,
		ONT_CLASS_MAP.ONTOLOGY_NAME as ONTOLOGY_NAME
	)
	comment='Metadata & governance semantic view over the ontology''s own structure: classes and parents (ONT_CLASS), relation definitions (ONT_RELATION_DEF), source-table provenance per class (ONT_OBJECT_SOURCE), identity-resolution rules (ONT_IDENTITY_RULE), and class mappings. Use for questions ABOUT the ontology itself - which tables/identifiers map to a class, how classes relate.'
	ai_verified_queries (
		"0;1" AS ( 
QUESTION 'Which source tables map to the Patient class?' 
VERIFIED_AT 1783671758
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT c.CLASS_NAME, s.SOURCE_TABLE FROM ont_class AS c JOIN ont_object_source AS s ON s.OBJ_TYPE = c.CLASS_NAME WHERE c.CLASS_NAME = ''Patient'''),
		"1;1" AS ( 
QUESTION 'What identifier systems and matching rules are used to resolve Patient identities?' 
VERIFIED_AT 1783671758
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT c.CLASS_NAME, ir.ID_SYSTEM, ir.MATCH_KEYS, ir.CONFIDENCE FROM ont_class AS c JOIN ont_identity_rule AS ir ON ir.CLASS_NAME = c.CLASS_NAME WHERE c.CLASS_NAME = ''Patient'' ORDER BY ir.PRIORITY'),
		"2;1" AS ( 
QUESTION 'Which source tables and identifier systems map to the Practitioner class?' 
VERIFIED_AT 1783671758
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT c.CLASS_NAME, s.SOURCE_TABLE, ir.ID_SYSTEM FROM ont_class AS c JOIN ont_object_source AS s ON s.OBJ_TYPE = c.CLASS_NAME JOIN ont_identity_rule AS ir ON ir.CLASS_NAME = c.CLASS_NAME WHERE c.CLASS_NAME = ''Practitioner'''),
		"3;1" AS ( 
QUESTION 'How do source tables and class mappings relate for each class?' 
VERIFIED_AT 1783671758
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT c.CLASS_NAME, s.SOURCE_TABLE, m.SOURCE_TABLE AS mapped FROM ont_class AS c JOIN ont_class_map AS m ON m.CLASS_NAME = c.CLASS_NAME JOIN ont_object_source AS s ON s.OBJ_TYPE = c.CLASS_NAME')
	)
	with extension (CA='{"tables":[{"name":"ONT_CLASS","dimensions":[{"name":"CLASS_NAME"},{"name":"PARENT_CLASS_NAME"},{"name":"IS_ABSTRACT"},{"name":"DESCRIPTION"},{"name":"ONTOLOGY_NAME"},{"name":"TYPE_CLASS"}],"time_dimensions":[{"name":"CREATED_AT"}]},{"name":"ONT_RELATION_DEF","dimensions":[{"name":"REL_NAME"},{"name":"DOMAIN_CLASS"},{"name":"RANGE_CLASS"},{"name":"CARDINALITY"},{"name":"IS_HIERARCHICAL"},{"name":"IS_TRANSITIVE"},{"name":"INVERSE_REL_NAME"},{"name":"DESCRIPTION"},{"name":"ONTOLOGY_NAME"}]},{"name":"ONT_OBJECT_SOURCE","dimensions":[{"name":"ONTOLOGY_NAME"},{"name":"OBJ_TYPE"},{"name":"SOURCE_TABLE"},{"name":"FILTER_SQL"},{"name":"MAPPING"}]},{"name":"ONT_IDENTITY_RULE","dimensions":[{"name":"ONTOLOGY_NAME"},{"name":"CLASS_NAME"},{"name":"PRIORITY"},{"name":"ID_SYSTEM"},{"name":"MATCH_KEYS"},{"name":"CONFIDENCE"},{"name":"DESCRIPTION"}],"time_dimensions":[{"name":"CREATED_AT"}]},{"name":"ONT_CLASS_MAP","dimensions":[{"name":"MAP_ID"},{"name":"CLASS_NAME"},{"name":"SOURCE_DATABASE"},{"name":"SOURCE_SCHEMA"},{"name":"SOURCE_TABLE"},{"name":"FILTER_COL"},{"name":"FILTER_VAL"},{"name":"ID_EXPR"},{"name":"NAME_EXPR"},{"name":"SUBTYPE_EXPR"},{"name":"ONTOLOGY_NAME"}]}],"relationships":[{"name":"ONT_CLASS_MAP_TO_ONT_CLASS","relationship_type":"many_to_one","join_type":"inner"},{"name":"ONT_IDENTITY_RULE_TO_ONT_CLASS","relationship_type":"many_to_one","join_type":"inner"},{"name":"ONT_OBJECT_SOURCE_TO_ONT_CLASS","relationship_type":"many_to_one","join_type":"inner"}]}');
