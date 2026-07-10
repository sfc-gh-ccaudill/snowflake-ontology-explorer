-- =============================================================================
-- PHASE 4.5 — Base semantic view (Cortex Analyst over the 15 raw source tables)
-- HEALTHCARE_ONTOLOGY  ·  CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_BASE
-- =============================================================================
-- Concrete data layer for direct per-system queries. 15 source tables, 19
-- relationships (within-system FKs + cross-system NPI/member/RxNorm links).
-- Built via FastGen, then relationship cardinalities corrected. This is the
-- LIVE definition captured with GET_DDL('SEMANTIC_VIEW', ...).
-- =============================================================================
USE SCHEMA CLINICAL_EMR.ONTOLOGY;

create or replace semantic view HEALTHCARE_ONTOLOGY_BASE
	tables (
		CLINICAL_EMR.EHR.PATIENT_MASTER primary key (INS_MEMBER_ID) unique (MRN),
		CLINICAL_EMR.EHR.PHYSICIAN primary key (PHYSICIAN_ID) unique (NPI) unique (DEPT_ID),
		CLINICAL_EMR.EHR.DEPARTMENT primary key (DEPT_ID),
		CLINICAL_EMR.EHR.VISIT primary key (MRN),
		CLINICAL_EMR.EHR.PROBLEM_LIST,
		CLINICAL_EMR.EHR.MEDICATION,
		CLINICAL_EMR.EHR.LAB_RESULTS primary key (MRN),
		PAYER_CLAIMS.CLAIMS.MEMBER primary key (MEMBER_ID),
		PAYER_CLAIMS.CLAIMS.RENDERING_PROVIDER primary key (RENDERING_NPI),
		PAYER_CLAIMS.CLAIMS.PLACE_OF_SERVICE primary key (POS_CODE),
		PAYER_CLAIMS.CLAIMS.CLAIMS_LINE,
		PHARMACY_OPS.RX.SUBSCRIBER primary key (RX_MEMBER_ID),
		PHARMACY_OPS.RX.PRESCRIBER primary key (PRESCRIBER_ID),
		PHARMACY_OPS.RX.NDC_PRODUCT primary key (RXNORM_CODE) unique (NDC),
		PHARMACY_OPS.RX.PHARMACY_FILL
	)
	relationships (
		PATIENT_MASTER_TO_MEMBER as PATIENT_MASTER(INS_MEMBER_ID) references MEMBER(MEMBER_ID),
		PATIENT_MASTER_TO_PHYSICIAN as PATIENT_MASTER(PCP_NPI) references PHYSICIAN(NPI),
		PHYSICIAN_TO_DEPARTMENT as PHYSICIAN(DEPT_ID) references DEPARTMENT(DEPT_ID),
		PHYSICIAN_TO_PRESCRIBER as PHYSICIAN(NPI) references PRESCRIBER(PRESCRIBER_ID),
		PHYSICIAN_TO_RENDERING_PROVIDER as PHYSICIAN(NPI) references RENDERING_PROVIDER(RENDERING_NPI),
		VISIT_TO_DEPARTMENT as VISIT(DEPT_ID) references DEPARTMENT(DEPT_ID),
		VISIT_TO_PATIENT_MASTER as VISIT(MRN) references PATIENT_MASTER(MRN),
		VISIT_TO_PHYSICIAN as VISIT(PHYSICIAN_ID) references PHYSICIAN(PHYSICIAN_ID),
		PROBLEM_LIST_TO_PATIENT_MASTER as PROBLEM_LIST(MRN) references PATIENT_MASTER(MRN),
		MEDICATION_TO_NDC_PRODUCT as MEDICATION(RXNORM_CODE) references NDC_PRODUCT(RXNORM_CODE),
		MEDICATION_TO_PATIENT_MASTER as MEDICATION(MRN) references PATIENT_MASTER(MRN),
		MEDICATION_TO_PHYSICIAN as MEDICATION(PHYSICIAN_ID) references PHYSICIAN(PHYSICIAN_ID),
		LAB_RESULTS_TO_PATIENT_MASTER as LAB_RESULTS(MRN) references PATIENT_MASTER(MRN),
		CLAIMS_LINE_TO_MEMBER as CLAIMS_LINE(MEMBER_ID) references MEMBER(MEMBER_ID),
		CLAIMS_LINE_TO_PLACE_OF_SERVICE as CLAIMS_LINE(POS_CODE) references PLACE_OF_SERVICE(POS_CODE),
		CLAIMS_LINE_TO_RENDERING_PROVIDER as CLAIMS_LINE(RENDERING_NPI) references RENDERING_PROVIDER(RENDERING_NPI),
		PHARMACY_FILL_TO_NDC_PRODUCT as PHARMACY_FILL(NDC) references NDC_PRODUCT(NDC),
		PHARMACY_FILL_TO_PRESCRIBER as PHARMACY_FILL(PRESCRIBER_ID) references PRESCRIBER(PRESCRIBER_ID),
		PHARMACY_FILL_TO_SUBSCRIBER as PHARMACY_FILL(RX_MEMBER_ID) references SUBSCRIBER(RX_MEMBER_ID)
	)
	facts (
		VISIT.WEIGHT_KG as WEIGHT_KG,
		VISIT.A1C_PCT as A1C_PCT,
		LAB_RESULTS.HBA1C_PCT as HBA1C_PCT,
		LAB_RESULTS.CREATININE_MGDL as CREATININE_MGDL,
		CLAIMS_LINE.CHARGE_AMT as CHARGE_AMT,
		CLAIMS_LINE.ALLOWED_AMT as ALLOWED_AMT,
		CLAIMS_LINE.PAID_AMT as PAID_AMT
	)
	dimensions (
		PATIENT_MASTER.MRN as MRN,
		PATIENT_MASTER.SSN as SSN,
		PATIENT_MASTER.FIRST_NAME as FIRST_NAME,
		PATIENT_MASTER.MIDDLE_NAME as MIDDLE_NAME,
		PATIENT_MASTER.LAST_NAME as LAST_NAME,
		PATIENT_MASTER.SEX as SEX,
		PATIENT_MASTER.ADDR_LINE1 as ADDR_LINE1,
		PATIENT_MASTER.CITY as CITY,
		PATIENT_MASTER.STATE as STATE,
		PATIENT_MASTER.ZIP as ZIP,
		PATIENT_MASTER.PHONE as PHONE,
		PATIENT_MASTER.PCP_NPI as PCP_NPI,
		PATIENT_MASTER.INS_PAYER_NAME as INS_PAYER_NAME,
		PATIENT_MASTER.INS_MEMBER_ID as INS_MEMBER_ID,
		PATIENT_MASTER.INS_GROUP as INS_GROUP,
		PATIENT_MASTER.KIN_NAME as KIN_NAME,
		PATIENT_MASTER.KIN_RELATION as KIN_RELATION,
		PATIENT_MASTER.KIN_PHONE as KIN_PHONE,
		PATIENT_MASTER.DOB as DOB,
		PHYSICIAN.PHYSICIAN_ID as PHYSICIAN_ID,
		PHYSICIAN.NPI as NPI,
		PHYSICIAN.FULL_NAME as FULL_NAME,
		PHYSICIAN.SPECIALTY as SPECIALTY,
		PHYSICIAN.DEPT_ID as DEPT_ID,
		DEPARTMENT.DEPT_ID as DEPT_ID,
		DEPARTMENT.DEPT_NAME as DEPT_NAME,
		DEPARTMENT.FACILITY_NAME as FACILITY_NAME,
		DEPARTMENT.ADDRESS as ADDRESS,
		DEPARTMENT.CITY as CITY,
		DEPARTMENT.STATE as STATE,
		DEPARTMENT.ZIP as ZIP,
		VISIT.VISIT_ID as VISIT_ID,
		VISIT.MRN as MRN,
		VISIT.PHYSICIAN_ID as PHYSICIAN_ID,
		VISIT.DEPT_ID as DEPT_ID,
		VISIT.VISIT_TYPE as VISIT_TYPE,
		VISIT.PRIMARY_ICD10 as PRIMARY_ICD10,
		VISIT.BP_SYSTOLIC as BP_SYSTOLIC,
		VISIT.BP_DIASTOLIC as BP_DIASTOLIC,
		VISIT.STATUS as STATUS,
		VISIT.VISIT_DATE as VISIT_DATE,
		PROBLEM_LIST.PROBLEM_ID as PROBLEM_ID,
		PROBLEM_LIST.MRN as MRN,
		PROBLEM_LIST.ICD10_CODE as ICD10_CODE,
		PROBLEM_LIST.ICD10_DESC as ICD10_DESC,
		PROBLEM_LIST.SNOMED_CODE as SNOMED_CODE,
		PROBLEM_LIST.STATUS as STATUS,
		PROBLEM_LIST.ONSET_DATE as ONSET_DATE,
		MEDICATION.MED_ORDER_ID as MED_ORDER_ID,
		MEDICATION.MRN as MRN,
		MEDICATION.PHYSICIAN_ID as PHYSICIAN_ID,
		MEDICATION.DRUG_NAME as DRUG_NAME,
		MEDICATION.RXNORM_CODE as RXNORM_CODE,
		MEDICATION.SIG as SIG,
		MEDICATION.QUANTITY as QUANTITY,
		MEDICATION.REFILLS as REFILLS,
		MEDICATION.ORDER_DATE as ORDER_DATE,
		LAB_RESULTS.LAB_ID as LAB_ID,
		LAB_RESULTS.MRN as MRN,
		LAB_RESULTS.GLUCOSE_MGDL as GLUCOSE_MGDL,
		LAB_RESULTS.LDL_MGDL as LDL_MGDL,
		LAB_RESULTS.EGFR as EGFR,
		LAB_RESULTS.COLLECT_DATE as COLLECT_DATE,
		MEMBER.MEMBER_ID as MEMBER_ID,
		MEMBER.SUBSCRIBER_ID as SUBSCRIBER_ID,
		MEMBER.MEMBER_SSN as MEMBER_SSN,
		MEMBER.MEMBER_NAME as MEMBER_NAME,
		MEMBER.GENDER as GENDER,
		MEMBER.RELATIONSHIP as RELATIONSHIP,
		MEMBER.PLAN_NAME as PLAN_NAME,
		MEMBER.GROUP_NO as GROUP_NO,
		MEMBER.DOB as DOB,
		MEMBER.EFFECTIVE_DATE as EFFECTIVE_DATE,
		MEMBER.TERM_DATE as TERM_DATE,
		RENDERING_PROVIDER.RENDERING_NPI as RENDERING_NPI,
		RENDERING_PROVIDER.PROVIDER_NAME as PROVIDER_NAME,
		RENDERING_PROVIDER.PROVIDER_TYPE as PROVIDER_TYPE,
		RENDERING_PROVIDER.TAX_ID as TAX_ID,
		PLACE_OF_SERVICE.POS_CODE as POS_CODE,
		PLACE_OF_SERVICE.POS_DESCRIPTION as POS_DESCRIPTION,
		CLAIMS_LINE.CLAIM_ID as CLAIM_ID,
		CLAIMS_LINE.LINE_NO as LINE_NO,
		CLAIMS_LINE.MEMBER_ID as MEMBER_ID,
		CLAIMS_LINE.SUBSCRIBER_ID as SUBSCRIBER_ID,
		CLAIMS_LINE.PLAN_NAME as PLAN_NAME,
		CLAIMS_LINE.RENDERING_NPI as RENDERING_NPI,
		CLAIMS_LINE.POS_CODE as POS_CODE,
		CLAIMS_LINE.DX_CODE as DX_CODE,
		CLAIMS_LINE.CPT_CODE as CPT_CODE,
		CLAIMS_LINE.CPT_DESC as CPT_DESC,
		CLAIMS_LINE.CLAIM_STATUS as CLAIM_STATUS,
		CLAIMS_LINE.SERVICE_DATE as SERVICE_DATE,
		SUBSCRIBER.RX_MEMBER_ID as RX_MEMBER_ID,
		SUBSCRIBER.PATIENT_SSN as PATIENT_SSN,
		SUBSCRIBER.PATIENT_NAME as PATIENT_NAME,
		SUBSCRIBER.SEX as SEX,
		SUBSCRIBER.DOB as DOB,
		PRESCRIBER.PRESCRIBER_ID as PRESCRIBER_ID,
		PRESCRIBER.PRESCRIBER_NAME as PRESCRIBER_NAME,
		PRESCRIBER.DEA_NUMBER as DEA_NUMBER,
		NDC_PRODUCT.NDC as NDC,
		NDC_PRODUCT.RXNORM_CODE as RXNORM_CODE,
		NDC_PRODUCT.BRAND_NAME as BRAND_NAME,
		NDC_PRODUCT.GENERIC_NAME as GENERIC_NAME,
		NDC_PRODUCT.STRENGTH as STRENGTH,
		NDC_PRODUCT.DOSAGE_FORM as DOSAGE_FORM,
		PHARMACY_FILL.FILL_ID as FILL_ID,
		PHARMACY_FILL.RX_MEMBER_ID as RX_MEMBER_ID,
		PHARMACY_FILL.PRESCRIBER_ID as PRESCRIBER_ID,
		PHARMACY_FILL.NDC as NDC,
		PHARMACY_FILL.DRUG_DESC as DRUG_DESC,
		PHARMACY_FILL.DAYS_SUPPLY as DAYS_SUPPLY,
		PHARMACY_FILL.QUANTITY as QUANTITY,
		PHARMACY_FILL.REFILLS_LEFT as REFILLS_LEFT,
		PHARMACY_FILL.FILL_STATUS as FILL_STATUS,
		PHARMACY_FILL.WRITTEN_DATE as WRITTEN_DATE,
		PHARMACY_FILL.FILL_DATE as FILL_DATE
	)
	comment='Base data-layer semantic view over the raw clinical EMR, payer claims, and pharmacy source tables. Use for concrete entity lookups, attribute filtering, and aggregations directly against source tables (patients, physicians, visits, problems, medications, labs, members, claims lines, providers, prescribers, fills, NDC products). Not for cross-system entity resolution - that is handled by the ontology-layer semantic view.'
	ai_verified_queries (
		"0;1" AS ( 
QUESTION 'How many members are enrolled in each health plan?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT PLAN_NAME, COUNT(DISTINCT MEMBER_ID) AS member_count FROM member GROUP BY PLAN_NAME'),
		"1;1" AS ( 
QUESTION 'What is the total paid amount and claim count by rendering provider?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT RENDERING_NPI, SUM(PAID_AMT) AS total_paid, COUNT(DISTINCT CLAIM_ID) AS claims FROM claims_line GROUP BY RENDERING_NPI'),
		"2;1" AS ( 
QUESTION 'What are the most common active diagnoses?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT ICD10_CODE, ICD10_DESC, COUNT(*) AS patients FROM problem_list WHERE STATUS = ''Active'' GROUP BY ICD10_CODE, ICD10_DESC ORDER BY patients DESC'),
		"3;1" AS ( 
QUESTION 'How many visits are there by physician specialty?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.SPECIALTY, COUNT(DISTINCT v.VISIT_ID) AS visits FROM visit AS v JOIN physician AS p ON p.PHYSICIAN_ID = v.PHYSICIAN_ID GROUP BY p.SPECIALTY'),
		"4;1" AS ( 
QUESTION 'Which generic drugs were dispensed most often?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT n.GENERIC_NAME, COUNT(*) AS fills FROM pharmacy_fill AS f JOIN ndc_product AS n ON n.NDC = f.NDC WHERE f.FILL_STATUS = ''Dispensed'' GROUP BY n.GENERIC_NAME ORDER BY fills DESC'),
		"5;1" AS ( 
QUESTION 'How many visits does each patient have?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.MRN, COUNT(*) AS c FROM visit AS v JOIN patient_master AS p ON p.MRN = v.MRN GROUP BY 1'),
		"6;1" AS ( 
QUESTION 'How many visits occurred in each department?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT d.DEPT_NAME, COUNT(*) AS c FROM visit AS v JOIN department AS d ON d.DEPT_ID = v.DEPT_ID GROUP BY 1'),
		"7;1" AS ( 
QUESTION 'How many physicians are there in each department?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT d.DEPT_NAME, COUNT(*) AS c FROM physician AS ph JOIN department AS d ON d.DEPT_ID = ph.DEPT_ID GROUP BY 1'),
		"8;1" AS ( 
QUESTION 'How many problems does each patient have?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.MRN, COUNT(*) AS c FROM problem_list AS pl JOIN patient_master AS p ON p.MRN = pl.MRN GROUP BY 1'),
		"9;1" AS ( 
QUESTION 'How many medication orders does each patient have?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.MRN, COUNT(*) AS c FROM medication AS m JOIN patient_master AS p ON p.MRN = m.MRN GROUP BY 1'),
		"10;1" AS ( 
QUESTION 'How many medication orders does each physician have?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT ph.FULL_NAME, COUNT(*) AS c FROM medication AS m JOIN physician AS ph ON ph.PHYSICIAN_ID = m.PHYSICIAN_ID GROUP BY 1'),
		"11;1" AS ( 
QUESTION 'How many lab results does each patient have?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT p.MRN, COUNT(*) AS c FROM lab_results AS l JOIN patient_master AS p ON p.MRN = l.MRN GROUP BY 1'),
		"12;1" AS ( 
QUESTION 'Who are the primary care physicians for our patients?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT ph.FULL_NAME FROM patient_master AS p JOIN physician AS ph ON ph.NPI = p.PCP_NPI'),
		"13;1" AS ( 
QUESTION 'What are the generic drug names for all medication orders?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT n.GENERIC_NAME FROM medication AS m JOIN ndc_product AS n ON n.RXNORM_CODE = m.RXNORM_CODE'),
		"14;1" AS ( 
QUESTION 'What is the total amount paid by each insurance plan?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT mb.PLAN_NAME, SUM(cl.PAID_AMT) AS paid FROM claims_line AS cl JOIN member AS mb ON mb.MEMBER_ID = cl.MEMBER_ID GROUP BY 1'),
		"15;1" AS ( 
QUESTION 'How many claim lines does each rendering provider have?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT rp.PROVIDER_NAME, COUNT(*) AS c FROM claims_line AS cl JOIN rendering_provider AS rp ON rp.RENDERING_NPI = cl.RENDERING_NPI GROUP BY 1'),
		"16;1" AS ( 
QUESTION 'How many claim lines are there for each place of service?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT pos.POS_DESCRIPTION, COUNT(*) AS c FROM claims_line AS cl JOIN place_of_service AS pos ON pos.POS_CODE = cl.POS_CODE GROUP BY 1'),
		"17;1" AS ( 
QUESTION 'How many prescription fills does each patient have?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT s.PATIENT_NAME, COUNT(*) AS c FROM pharmacy_fill AS f JOIN subscriber AS s ON s.RX_MEMBER_ID = f.RX_MEMBER_ID GROUP BY 1'),
		"18;1" AS ( 
QUESTION 'How many prescriptions has each prescriber filled?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT pr.PRESCRIBER_NAME, COUNT(*) AS c FROM pharmacy_fill AS f JOIN prescriber AS pr ON pr.PRESCRIBER_ID = f.PRESCRIBER_ID GROUP BY 1'),
		"19;1" AS ( 
QUESTION 'What insurance plans are associated with each patient in our EMR system?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT mb.PLAN_NAME FROM patient_master AS p JOIN member AS mb ON mb.MEMBER_ID = p.INS_MEMBER_ID'),
		"20;1" AS ( 
QUESTION 'How do EMR physicians map to claims rendering providers by NPI?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT ph.FULL_NAME, rp.PROVIDER_NAME FROM physician AS ph JOIN rendering_provider AS rp ON rp.RENDERING_NPI = ph.NPI'),
		"21;1" AS ( 
QUESTION 'How do EMR physicians map to pharmacy prescribers by NPI?' 
VERIFIED_AT 1783672568
VERIFIED_BY 'Semantic Model Generator'
ONBOARDING_QUESTION false
SQL 'SELECT ph.FULL_NAME, pr.PRESCRIBER_NAME FROM physician AS ph JOIN prescriber AS pr ON pr.PRESCRIBER_ID = ph.NPI')
	)
	with extension (CA='{"tables":[{"name":"PATIENT_MASTER","dimensions":[{"name":"MRN"},{"name":"SSN"},{"name":"FIRST_NAME"},{"name":"MIDDLE_NAME"},{"name":"LAST_NAME"},{"name":"SEX"},{"name":"ADDR_LINE1"},{"name":"CITY"},{"name":"STATE"},{"name":"ZIP"},{"name":"PHONE"},{"name":"PCP_NPI"},{"name":"INS_PAYER_NAME"},{"name":"INS_MEMBER_ID"},{"name":"INS_GROUP"},{"name":"KIN_NAME"},{"name":"KIN_RELATION"},{"name":"KIN_PHONE"}],"time_dimensions":[{"name":"DOB"}]},{"name":"PHYSICIAN","dimensions":[{"name":"PHYSICIAN_ID"},{"name":"NPI"},{"name":"FULL_NAME"},{"name":"SPECIALTY"},{"name":"DEPT_ID"}]},{"name":"DEPARTMENT","dimensions":[{"name":"DEPT_ID"},{"name":"DEPT_NAME"},{"name":"FACILITY_NAME"},{"name":"ADDRESS"},{"name":"CITY"},{"name":"STATE"},{"name":"ZIP"}]},{"name":"VISIT","dimensions":[{"name":"VISIT_ID"},{"name":"MRN"},{"name":"PHYSICIAN_ID"},{"name":"DEPT_ID"},{"name":"VISIT_TYPE"},{"name":"PRIMARY_ICD10"},{"name":"BP_SYSTOLIC"},{"name":"BP_DIASTOLIC"},{"name":"STATUS"}],"facts":[{"name":"WEIGHT_KG"},{"name":"A1C_PCT"}],"time_dimensions":[{"name":"VISIT_DATE"}]},{"name":"PROBLEM_LIST","dimensions":[{"name":"PROBLEM_ID"},{"name":"MRN"},{"name":"ICD10_CODE"},{"name":"ICD10_DESC"},{"name":"SNOMED_CODE"},{"name":"STATUS"}],"time_dimensions":[{"name":"ONSET_DATE"}]},{"name":"MEDICATION","dimensions":[{"name":"MED_ORDER_ID"},{"name":"MRN"},{"name":"PHYSICIAN_ID"},{"name":"DRUG_NAME"},{"name":"RXNORM_CODE"},{"name":"SIG"},{"name":"QUANTITY"},{"name":"REFILLS"}],"time_dimensions":[{"name":"ORDER_DATE"}]},{"name":"LAB_RESULTS","dimensions":[{"name":"LAB_ID"},{"name":"MRN"},{"name":"GLUCOSE_MGDL"},{"name":"LDL_MGDL"},{"name":"EGFR"}],"facts":[{"name":"HBA1C_PCT"},{"name":"CREATININE_MGDL"}],"time_dimensions":[{"name":"COLLECT_DATE"}]},{"name":"MEMBER","dimensions":[{"name":"MEMBER_ID"},{"name":"SUBSCRIBER_ID"},{"name":"MEMBER_SSN"},{"name":"MEMBER_NAME"},{"name":"GENDER"},{"name":"RELATIONSHIP"},{"name":"PLAN_NAME"},{"name":"GROUP_NO"}],"time_dimensions":[{"name":"DOB"},{"name":"EFFECTIVE_DATE"},{"name":"TERM_DATE"}]},{"name":"RENDERING_PROVIDER","dimensions":[{"name":"RENDERING_NPI"},{"name":"PROVIDER_NAME"},{"name":"PROVIDER_TYPE"},{"name":"TAX_ID"}]},{"name":"PLACE_OF_SERVICE","dimensions":[{"name":"POS_CODE"},{"name":"POS_DESCRIPTION"}]},{"name":"CLAIMS_LINE","dimensions":[{"name":"CLAIM_ID"},{"name":"LINE_NO"},{"name":"MEMBER_ID"},{"name":"SUBSCRIBER_ID"},{"name":"PLAN_NAME"},{"name":"RENDERING_NPI"},{"name":"POS_CODE"},{"name":"DX_CODE"},{"name":"CPT_CODE"},{"name":"CPT_DESC"},{"name":"CLAIM_STATUS"}],"facts":[{"name":"CHARGE_AMT"},{"name":"ALLOWED_AMT"},{"name":"PAID_AMT"}],"time_dimensions":[{"name":"SERVICE_DATE"}]},{"name":"SUBSCRIBER","dimensions":[{"name":"RX_MEMBER_ID"},{"name":"PATIENT_SSN"},{"name":"PATIENT_NAME"},{"name":"SEX"}],"time_dimensions":[{"name":"DOB"}]},{"name":"PRESCRIBER","dimensions":[{"name":"PRESCRIBER_ID"},{"name":"PRESCRIBER_NAME"},{"name":"DEA_NUMBER"}]},{"name":"NDC_PRODUCT","dimensions":[{"name":"NDC"},{"name":"RXNORM_CODE"},{"name":"BRAND_NAME"},{"name":"GENERIC_NAME"},{"name":"STRENGTH"},{"name":"DOSAGE_FORM"}]},{"name":"PHARMACY_FILL","dimensions":[{"name":"FILL_ID"},{"name":"RX_MEMBER_ID"},{"name":"PRESCRIBER_ID"},{"name":"NDC"},{"name":"DRUG_DESC"},{"name":"DAYS_SUPPLY"},{"name":"QUANTITY"},{"name":"REFILLS_LEFT"},{"name":"FILL_STATUS"}],"time_dimensions":[{"name":"WRITTEN_DATE"},{"name":"FILL_DATE"}]}],"relationships":[{"name":"CLAIMS_LINE_TO_MEMBER","relationship_type":"many_to_one","join_type":"inner"},{"name":"CLAIMS_LINE_TO_PLACE_OF_SERVICE","relationship_type":"many_to_one","join_type":"inner"},{"name":"CLAIMS_LINE_TO_RENDERING_PROVIDER","relationship_type":"many_to_one","join_type":"inner"},{"name":"LAB_RESULTS_TO_PATIENT_MASTER","relationship_type":"many_to_one","join_type":"inner"},{"name":"MEDICATION_TO_NDC_PRODUCT","relationship_type":"many_to_one","join_type":"inner"},{"name":"MEDICATION_TO_PATIENT_MASTER","relationship_type":"many_to_one","join_type":"inner"},{"name":"MEDICATION_TO_PHYSICIAN","relationship_type":"many_to_one","join_type":"inner"},{"name":"PATIENT_MASTER_TO_MEMBER","relationship_type":"one_to_one","join_type":"inner"},{"name":"PATIENT_MASTER_TO_PHYSICIAN","relationship_type":"many_to_one","join_type":"inner"},{"name":"PHARMACY_FILL_TO_NDC_PRODUCT","relationship_type":"many_to_one","join_type":"inner"},{"name":"PHARMACY_FILL_TO_PRESCRIBER","relationship_type":"many_to_one","join_type":"inner"},{"name":"PHARMACY_FILL_TO_SUBSCRIBER","relationship_type":"many_to_one","join_type":"inner"},{"name":"PHYSICIAN_TO_DEPARTMENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"PHYSICIAN_TO_PRESCRIBER","relationship_type":"one_to_one","join_type":"inner"},{"name":"PHYSICIAN_TO_RENDERING_PROVIDER","relationship_type":"one_to_one","join_type":"inner"},{"name":"PROBLEM_LIST_TO_PATIENT_MASTER","relationship_type":"many_to_one","join_type":"inner"},{"name":"VISIT_TO_DEPARTMENT","relationship_type":"many_to_one","join_type":"inner"},{"name":"VISIT_TO_PATIENT_MASTER","relationship_type":"many_to_one","join_type":"inner"},{"name":"VISIT_TO_PHYSICIAN","relationship_type":"many_to_one","join_type":"inner"}]}');
