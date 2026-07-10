/* =============================================================================
   SYSTEM 3 of 3:  PHARMACY_OPS  (the pharmacy / dispensing side)
   -----------------------------------------------------------------------------
   Demo purpose: messy source data for an ontology-alignment demo.

   This system's vocabulary (DIFFERENT WORDS again):
     - A person is a "SUBSCRIBER" (rx member); names stored as NICKNAMES
       ("Bob Smith", "Jim Johnson", "Beth Moore")
     - A clinician is a "PRESCRIBER" (keyed by NPI-as-string)
     - Drugs are "NDC_PRODUCT" (keyed by NDC; brand names common)
     - A dispensing event is a "PHARMACY_FILL"

   Intentional messiness in this file:
     1. PHARMACY_FILL is OVERLOADED: one row = MedicationRequest (the order) +
        MedicationDispense (the fill) + Medication (the drug) + Patient +
        Prescriber.  -> maps to ~5 ontology classes.
     2. Same people as the other 2 systems but under NICKNAMES, its own
        RX_MEMBER_ID, and some SSNs NULL -> hardest alignment case
        (must fall back to name+DOB, or nickname resolution).
     3. Drugs identified by NDC + brand name here vs generic + RxNorm in the
        EMR.  NDC_PRODUCT provides the NDC<->RxNorm crosswalk that stitches
        CLINICAL_EMR.MEDICATION to PHARMACY_FILL.

   Cross-system linkage keys (so the ontology CAN traverse later):
     - PATIENT_SSN   -> aligns to CLINICAL_EMR SSN / PAYER_CLAIMS.MEMBER_SSN
                        (NULL for some -> use PATIENT_NAME + DOB)
     - PRESCRIBER_ID == CLINICAL_EMR PHYSICIAN.NPI == PAYER_CLAIMS RENDERING_NPI
     - NDC_PRODUCT.RXNORM_CODE == CLINICAL_EMR.MEDICATION.RXNORM_CODE (crosswalk)
   =============================================================================*/

-- USE ROLE SYSADMIN;
-- USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS PHARMACY_OPS;
CREATE SCHEMA   IF NOT EXISTS PHARMACY_OPS.RX;
USE SCHEMA PHARMACY_OPS.RX;

-- -----------------------------------------------------------------------------
-- SUBSCRIBER  (this system's word for a Patient; NICKNAMES + own member id)
--   PATIENT_SSN NULL for some rows -> forces name+DOB alignment.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE SUBSCRIBER (
    RX_MEMBER_ID    STRING,         -- pharmacy's own person id (NOT the claims MEMBER_ID)
    PATIENT_SSN     STRING,         -- nullable (messy)
    PATIENT_NAME    STRING,         -- NICKNAME form: "Bob Smith", "Beth Moore"
    DOB             DATE,
    SEX             STRING          -- 'M'/'F'
);

INSERT INTO SUBSCRIBER VALUES
    ('RX90001','111-22-3001','Bob Smith',       '1958-03-14','M'),  -- Robert Smith
    ('RX90002','111-22-3002','Maria Garcia',    '1972-07-22','F'),
    ('RX90003','111-22-3003','Jim Johnson',     '1965-11-30','M'),  -- James Johnson
    ('RX90004','111-22-3004','Linda Williams',  '1980-01-05','F'),
    ('RX90005',NULL,         'Michael Brown',   '1990-09-18','M'),  -- SSN NULL -> name+DOB
    ('RX90006','111-22-3006','Patricia Jones',  '1955-12-02','F'),
    ('RX90007','111-22-3007','Dave Miller',     '1978-04-27','M'),  -- David Miller
    ('RX90008','111-22-3008','Jennifer Davis',  '1985-06-11','F'),
    ('RX90009','111-22-3009','Bill Wilson',     '1949-02-19','M'),  -- William Wilson
    ('RX90010',NULL,         'Beth Moore',      '1968-08-08','F'),  -- Elizabeth Moore, SSN NULL + nickname
    ('RX90011','111-22-3011','Rich Taylor',     '1970-10-15','M'),  -- Richard Taylor
    ('RX90012','111-22-3012','Susan Anderson',  '1962-05-25','F');

-- -----------------------------------------------------------------------------
-- PRESCRIBER  (this system's word for a Physician; PRESCRIBER_ID = NPI string)
--   Name in yet another format ("S CHEN"); apostrophe dropped for O'Brien.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PRESCRIBER (
    PRESCRIBER_ID   STRING,         -- == NPI (CLINICAL_EMR PHYSICIAN.NPI / PAYER RENDERING_NPI)
    PRESCRIBER_NAME STRING,
    DEA_NUMBER      STRING
);

INSERT INTO PRESCRIBER VALUES
    ('1003000001','S CHEN',   'BC1111111'),
    ('1003000002','R PATEL',  'BP2222222'),
    ('1003000003','E NGUYEN', 'BN3333333'),
    ('1003000004','M LEE',    'BL4444444'),
    ('1003000005','A RAO',    'BR5555555'),
    ('1003000006','J OBRIEN', 'BO6666666');

-- -----------------------------------------------------------------------------
-- NDC_PRODUCT  (drug reference; the NDC <-> RxNorm crosswalk)
--   BRAND_NAME differs from EMR's generic DRUG_NAME (extra messiness).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE NDC_PRODUCT (
    NDC             STRING,
    RXNORM_CODE     STRING,         -- == CLINICAL_EMR.MEDICATION.RXNORM_CODE
    BRAND_NAME      STRING,
    GENERIC_NAME    STRING,
    STRENGTH        STRING,
    DOSAGE_FORM     STRING
);

INSERT INTO NDC_PRODUCT VALUES
    ('00093-1045-01','860975','Glucophage','Metformin HCl',      '500 mg','TABLET'),
    ('00071-0155-23','617312','Lipitor',   'Atorvastatin Calcium','20 mg','TABLET'),
    ('00093-0058-01','314076','Zestril',   'Lisinopril',         '10 mg','TABLET'),
    ('00185-0674-01','866924','Lopressor', 'Metoprolol Tartrate','50 mg','TABLET'),
    ('00378-0208-01','312940','Zoloft',    'Sertraline HCl',     '50 mg','TABLET'),
    ('00054-0319-25','310429','Lasix',     'Furosemide',         '40 mg','TABLET'),
    ('00006-0749-54','979485','Cozaar',    'Losartan Potassium', '50 mg','TABLET'),
    ('00169-0413-11','261551','Lantus',    'Insulin Glargine',   '100 U/mL','SOLUTION');

-- -----------------------------------------------------------------------------
-- PHARMACY_FILL  (OVERLOADED: MedicationRequest + MedicationDispense +
--                 Medication + Patient + Prescriber)
--   Links back to CLINICAL_EMR.MEDICATION via
--   (patient [SSN or name+DOB] + PRESCRIBER_ID=NPI + NDC->RxNorm crosswalk).
--   DRUG_DESC uses BRAND names to differ from EMR generic names.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PHARMACY_FILL (
    FILL_ID         STRING,
    RX_MEMBER_ID    STRING,         -- Patient (pharmacy id)
    PRESCRIBER_ID   STRING,         -- Prescriber (NPI)
    NDC             STRING,         -- Medication (crosswalks to RxNorm)
    DRUG_DESC       STRING,         -- brand-ish free text
    WRITTEN_DATE    DATE,           -- MedicationRequest aspect
    FILL_DATE       DATE,           -- MedicationDispense aspect
    DAYS_SUPPLY     NUMBER,
    QUANTITY        NUMBER,
    REFILLS_LEFT    NUMBER,
    FILL_STATUS     STRING          -- Dispensed/Pending (overloaded STATUS again)
);

INSERT INTO PHARMACY_FILL VALUES
    ('F0001','RX90001','1003000001','00093-1045-01','Glucophage 500mg', '2025-02-10','2025-02-11',30,60,3,'Dispensed'),  -- Bob Smith / Chen / Metformin
    ('F0002','RX90001','1003000001','00071-0155-23','Lipitor 20mg',     '2025-02-10','2025-02-11',30,30,3,'Dispensed'),  -- Bob Smith / Atorvastatin
    ('F0003','RX90002','1003000003','00093-0058-01','Zestril 10mg',     '2025-03-05','2025-03-06',30,30,5,'Dispensed'),  -- Maria / Nguyen / Lisinopril
    ('F0004','RX90003','1003000002','00185-0674-01','Lopressor 50mg',   '2025-01-20','2025-01-21',30,60,3,'Dispensed'),  -- Jim Johnson / Patel / Metoprolol
    ('F0005','RX90003','1003000002','00054-0319-25','Lasix 40mg',       '2025-01-20','2025-01-21',30,30,3,'Dispensed'),  -- Jim Johnson / Furosemide
    ('F0006','RX90003','1003000002','00093-0058-01','Zestril 10mg',     '2025-01-20','2025-01-21',30,30,3,'Dispensed'),  -- Jim Johnson / Lisinopril
    ('F0007','RX90004','1003000006','00378-0208-01','Zoloft 50mg',      '2025-04-02','2025-04-03',30,30,3,'Dispensed'),  -- Linda / O'Brien / Sertraline
    ('F0008','RX90005','1003000001','00093-1045-01','Glucophage 500mg', '2025-02-25','2025-02-26',30,60,3,'Dispensed'),  -- Michael Brown / Chen / Metformin
    ('F0009','RX90005','1003000001','00169-0413-11','Lantus SoloStar',  '2025-02-25','2025-02-26',30, 1,5,'Dispensed'),  -- Michael Brown / Insulin
    ('F0010','RX90006','1003000005','00006-0749-54','Cozaar 50mg',      '2025-03-18','2025-03-19',30,30,3,'Dispensed'),  -- Patricia / Rao / Losartan
    ('F0011','RX90007','1003000004','00071-0155-23','Lipitor 20mg',     '2025-05-06','2025-05-07',30,30,3,'Dispensed'),  -- Dave Miller / Lee / Atorvastatin (EMR RxNorm was NULL!)
    ('F0012','RX90008','1003000003','00093-0058-01','Zestril 10mg',     '2025-03-12','2025-03-13',30,30,5,'Dispensed'),  -- Jennifer / Nguyen / Lisinopril
    ('F0013','RX90009','1003000002','00185-0674-01','Lopressor 50mg',   '2025-01-28','2025-01-29',30,60,3,'Dispensed'),  -- Bill Wilson / Patel / Metoprolol
    ('F0014','RX90009','1003000002','00054-0319-25','Lasix 40mg',       '2025-01-28','2025-01-29',30,30,3,'Dispensed'),  -- Bill Wilson / Furosemide
    ('F0015','RX90010','1003000001','00093-1045-01','Glucophage 500mg', '2025-04-15','2025-04-16',30,60,3,'Dispensed'),  -- Beth Moore / Chen / Metformin
    ('F0016','RX90010','1003000001','00071-0155-23','Lipitor 20mg',     '2025-04-15','2025-04-16',30,30,3,'Dispensed'),  -- Beth Moore / Atorvastatin
    ('F0017','RX90011','1003000006','00378-0208-01','Zoloft 50mg',      '2025-05-20','2025-05-21',30,30,3,'Dispensed'),  -- Rich Taylor / O'Brien / Sertraline (EMR RxNorm was NULL!)
    ('F0018','RX90012','1003000004','00093-0058-01','Zestril 10mg',     '2025-02-14','2025-02-15',30,30,5,'Dispensed'),  -- Susan / Lee / Lisinopril
    ('F0019','RX90012','1003000004','00071-0155-23','Lipitor 20mg',     '2025-02-14','2025-02-15',30,30,3,'Dispensed');  -- Susan / Atorvastatin

-- ============================================================
-- ADDITIONAL DATA: patients 13-50 (+6 providers/depts/drugs)
-- Same linkage rules as above; alignments preserved.
-- ============================================================

INSERT INTO PRESCRIBER VALUES
    ('1003000007','D KIM','BK7777777'),
    ('1003000008','L MARTINEZ','BM8888888'),
    ('1003000009','T WRIGHT','BW9999999'),
    ('1003000010','N ADAMS','BA1010101'),
    ('1003000011','K BROOKS','BB1111112'),
    ('1003000012','R GREEN','BG1212123');

INSERT INTO NDC_PRODUCT VALUES
    ('00093-0155-01','197361','Norvasc','Amlodipine Besylate','5 mg','TABLET'),
    ('00186-0740-31','198051','Prilosec','Omeprazole','20 mg','CAPSULE'),
    ('00074-4341-90','966155','Synthroid','Levothyroxine Sodium','50 mcg','TABLET'),
    ('59310-0579-20','745679','ProAir','Albuterol Sulfate','90 mcg','AEROSOL'),
    ('00071-0803-24','310431','Neurontin','Gabapentin','300 mg','CAPSULE'),
    ('00056-0176-70','855334','Coumadin','Warfarin Sodium','5 mg','TABLET');

INSERT INTO SUBSCRIBER VALUES
    ('RX90013','111-22-3013','Jason Baker','1981-04-12','M'),
    ('RX90014','111-22-3014','Amy Adams','1988-07-17','F'),
    ('RX90015','111-22-3015','Greg Nelson','1995-10-22','M'),
    ('RX90016','111-22-3016','Melissa Carter','1947-01-27','F'),
    ('RX90017','111-22-3017','Ben Mitchell','1954-04-05','M'),
    ('RX90018',NULL,'Steph Perez','1961-07-10','F'),
    ('RX90019','111-22-3019','Jack Roberts','1968-10-15','M'),
    ('RX90020','111-22-3020','Nan Turner','1975-01-20','F'),
    ('RX90021','111-22-3021','Frank Phillips','1982-04-25','M'),
    ('RX90022','111-22-3022','Betty Campbell','1989-07-03','F'),
    ('RX90023','111-22-3023','Peter Parker','1996-10-08','M'),
    ('RX90024',NULL,'Sandra Evans','1948-01-13','F'),
    ('RX90025','111-22-3025','Brian Edwards','1955-04-18','M'),
    ('RX90026','111-22-3026','Carol Collins','1962-07-23','F'),
    ('RX90027','111-22-3027','Gary Stewart','1969-10-01','M'),
    ('RX90028','111-22-3028','Sharon Morris','1976-01-06','F'),
    ('RX90029','111-22-3029','Jeff Rogers','1983-04-11','M'),
    ('RX90030',NULL,'Laura Reed','1990-07-16','F'),
    ('RX90031','111-22-3031','Tony Cook','1997-10-21','M'),
    ('RX90032','111-22-3032','Kim Morgan','1949-01-26','F'),
    ('RX90033','111-22-3033','Jason Bell','1956-04-04','M'),
    ('RX90034','111-22-3034','Amy Murphy','1963-07-09','F'),
    ('RX90035','111-22-3035','Greg Bailey','1970-10-14','M'),
    ('RX90036',NULL,'Melissa Rivera','1977-01-19','F'),
    ('RX90037','111-22-3037','Ben Cooper','1984-04-24','M'),
    ('RX90038','111-22-3038','Steph Richardson','1991-07-02','F'),
    ('RX90039','111-22-3039','Jack Cox','1998-10-07','M'),
    ('RX90040','111-22-3040','Nan Thompson','1950-01-12','F'),
    ('RX90041','111-22-3041','Frank White','1957-04-17','M'),
    ('RX90042',NULL,'Betty Harris','1964-07-22','F'),
    ('RX90043','111-22-3043','Peter Martin','1971-10-27','M'),
    ('RX90044','111-22-3044','Sandra Clark','1978-01-05','F'),
    ('RX90045','111-22-3045','Brian Lewis','1985-04-10','M'),
    ('RX90046','111-22-3046','Carol Walker','1992-07-15','F'),
    ('RX90047','111-22-3047','Gary Hall','1999-10-20','M'),
    ('RX90048',NULL,'Sharon Young','1951-01-25','F'),
    ('RX90049','111-22-3049','Jeff King','1958-04-03','M'),
    ('RX90050','111-22-3050','Laura Wright','1965-07-08','F');

INSERT INTO PHARMACY_FILL VALUES
    ('F0020','RX90013','1003000001','00093-1045-01','Glucophage 500mg','2025-08-08','2025-08-09',30,60,3,'Dispensed'),
    ('F0021','RX90014','1003000001','00093-1045-01','Glucophage 500mg','2025-03-21','2025-03-22',30,60,3,'Dispensed'),
    ('F0022','RX90014','1003000001','00071-0155-23','Lipitor 20mg','2025-03-21','2025-03-22',30,30,3,'Dispensed'),
    ('F0023','RX90015','1003000001','00093-1045-01','Glucophage 500mg','2025-10-07','2025-10-08',30,60,3,'Dispensed'),
    ('F0024','RX90015','1003000001','00169-0413-11','Lantus SoloStar','2025-10-07','2025-10-08',30,1,5,'Dispensed'),
    ('F0025','RX90016','1003000003','00093-0058-01','Zestril 10mg','2025-05-20','2025-05-21',30,30,5,'Dispensed'),
    ('F0026','RX90017','1003000003','00093-0155-01','Norvasc 5mg','2025-12-06','2025-12-07',30,30,3,'Dispensed'),
    ('F0027','RX90017','1003000003','00071-0155-23','Lipitor 20mg','2025-12-06','2025-12-07',30,30,3,'Dispensed'),
    ('F0028','RX90018','1003000002','00185-0674-01','Lopressor 50mg','2025-07-19','2025-07-20',30,60,3,'Dispensed'),
    ('F0029','RX90018','1003000002','00054-0319-25','Lasix 40mg','2025-07-19','2025-07-20',30,30,3,'Dispensed'),
    ('F0030','RX90018','1003000002','00093-0058-01','Zestril 10mg','2025-07-19','2025-07-20',30,30,5,'Dispensed'),
    ('F0031','RX90019','1003000002','00056-0176-70','Coumadin 5mg','2025-02-05','2025-02-06',30,30,3,'Dispensed'),
    ('F0032','RX90019','1003000002','00185-0674-01','Lopressor 50mg','2025-02-05','2025-02-06',30,60,3,'Dispensed'),
    ('F0033','RX90020','1003000002','00071-0155-23','Lipitor 20mg','2025-09-18','2025-09-19',30,30,3,'Dispensed'),
    ('F0034','RX90020','1003000002','00185-0674-01','Lopressor 50mg','2025-09-18','2025-09-19',30,60,3,'Dispensed'),
    ('F0035','RX90021','1003000006','00378-0208-01','Zoloft 50mg','2025-04-04','2025-04-05',30,30,3,'Dispensed'),
    ('F0036','RX90022','1003000005','00006-0749-54','Cozaar 50mg','2025-11-17','2025-11-18',30,30,3,'Dispensed'),
    ('F0037','RX90023','1003000004','00071-0155-23','Lipitor 20mg','2025-06-03','2025-06-04',30,30,3,'Dispensed'),
    ('F0038','RX90024','1003000007','59310-0579-20','ProAir HFA','2025-01-16','2025-01-17',30,1,3,'Dispensed'),
    ('F0039','RX90025','1003000007','59310-0579-20','ProAir HFA','2025-08-02','2025-08-03',30,1,3,'Dispensed'),
    ('F0040','RX90026','1003000008','00071-0803-24','Neurontin 300mg','2025-03-15','2025-03-16',30,90,3,'Dispensed'),
    ('F0041','RX90027','1003000009','00186-0740-31','Prilosec 20mg','2025-10-01','2025-10-02',30,30,3,'Dispensed'),
    ('F0042','RX90028','1003000003','00074-4341-90','Synthroid 50mcg','2025-05-14','2025-05-15',30,30,5,'Dispensed'),
    ('F0043','RX90029','1003000010','00071-0803-24','Neurontin 300mg','2025-12-27','2025-12-28',30,90,3,'Dispensed'),
    ('F0044','RX90030','1003000011','00071-0803-24','Neurontin 300mg','2025-07-13','2025-07-14',30,90,3,'Dispensed'),
    ('F0045','RX90031','1003000004','00093-0058-01','Zestril 10mg','2025-02-26','2025-02-27',30,30,5,'Dispensed'),
    ('F0046','RX90031','1003000004','00071-0155-23','Lipitor 20mg','2025-02-26','2025-02-27',30,30,3,'Dispensed'),
    ('F0047','RX90032','1003000012','00071-0155-23','Lipitor 20mg','2025-09-12','2025-09-13',30,30,3,'Dispensed'),
    ('F0048','RX90033','1003000001','00093-1045-01','Glucophage 500mg','2025-04-25','2025-04-26',30,60,3,'Dispensed'),
    ('F0049','RX90034','1003000001','00093-1045-01','Glucophage 500mg','2025-11-11','2025-11-12',30,60,3,'Dispensed'),
    ('F0050','RX90034','1003000001','00071-0155-23','Lipitor 20mg','2025-11-11','2025-11-12',30,30,3,'Dispensed'),
    ('F0051','RX90035','1003000001','00093-1045-01','Glucophage 500mg','2025-06-24','2025-06-25',30,60,3,'Dispensed'),
    ('F0052','RX90035','1003000001','00169-0413-11','Lantus SoloStar','2025-06-24','2025-06-25',30,1,5,'Dispensed'),
    ('F0053','RX90036','1003000003','00093-0058-01','Zestril 10mg','2025-01-10','2025-01-11',30,30,5,'Dispensed'),
    ('F0054','RX90037','1003000003','00093-0155-01','Norvasc 5mg','2025-08-23','2025-08-24',30,30,3,'Dispensed'),
    ('F0055','RX90037','1003000003','00071-0155-23','Lipitor 20mg','2025-08-23','2025-08-24',30,30,3,'Dispensed'),
    ('F0056','RX90038','1003000002','00185-0674-01','Lopressor 50mg','2025-03-09','2025-03-10',30,60,3,'Dispensed'),
    ('F0057','RX90038','1003000002','00054-0319-25','Lasix 40mg','2025-03-09','2025-03-10',30,30,3,'Dispensed'),
    ('F0058','RX90038','1003000002','00093-0058-01','Zestril 10mg','2025-03-09','2025-03-10',30,30,5,'Dispensed'),
    ('F0059','RX90039','1003000002','00056-0176-70','Coumadin 5mg','2025-10-22','2025-10-23',30,30,3,'Dispensed'),
    ('F0060','RX90039','1003000002','00185-0674-01','Lopressor 50mg','2025-10-22','2025-10-23',30,60,3,'Dispensed'),
    ('F0061','RX90040','1003000002','00071-0155-23','Lipitor 20mg','2025-05-08','2025-05-09',30,30,3,'Dispensed'),
    ('F0062','RX90040','1003000002','00185-0674-01','Lopressor 50mg','2025-05-08','2025-05-09',30,60,3,'Dispensed'),
    ('F0063','RX90041','1003000006','00378-0208-01','Zoloft 50mg','2025-12-21','2025-12-22',30,30,3,'Dispensed'),
    ('F0064','RX90042','1003000005','00006-0749-54','Cozaar 50mg','2025-07-07','2025-07-08',30,30,3,'Dispensed'),
    ('F0065','RX90043','1003000004','00071-0155-23','Lipitor 20mg','2025-02-20','2025-02-21',30,30,3,'Dispensed'),
    ('F0066','RX90044','1003000007','59310-0579-20','ProAir HFA','2025-09-06','2025-09-07',30,1,3,'Dispensed'),
    ('F0067','RX90045','1003000007','59310-0579-20','ProAir HFA','2025-04-19','2025-04-20',30,1,3,'Dispensed'),
    ('F0068','RX90046','1003000008','00071-0803-24','Neurontin 300mg','2025-11-05','2025-11-06',30,90,3,'Dispensed'),
    ('F0069','RX90047','1003000009','00186-0740-31','Prilosec 20mg','2025-06-18','2025-06-19',30,30,3,'Dispensed'),
    ('F0070','RX90048','1003000003','00074-4341-90','Synthroid 50mcg','2025-01-04','2025-01-05',30,30,5,'Dispensed'),
    ('F0071','RX90049','1003000010','00071-0803-24','Neurontin 300mg','2025-08-17','2025-08-18',30,90,3,'Dispensed'),
    ('F0072','RX90050','1003000011','00071-0803-24','Neurontin 300mg','2025-03-03','2025-03-04',30,90,3,'Dispensed');

-- Quick sanity check
SELECT 'PHARMACY_OPS loaded' AS status,
       (SELECT COUNT(*) FROM SUBSCRIBER)    AS subscribers,
       (SELECT COUNT(*) FROM PHARMACY_FILL) AS fills,
       (SELECT COUNT(*) FROM NDC_PRODUCT)   AS products;
