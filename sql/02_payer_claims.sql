/* =============================================================================
   SYSTEM 2 of 3:  PAYER_CLAIMS  (the health-plan / claims-adjudication side)
   -----------------------------------------------------------------------------
   Demo purpose: messy source data for an ontology-alignment demo.

   This system's vocabulary (DIFFERENT WORDS for the SAME entities):
     - A person is a "MEMBER" / "SUBSCRIBER"   (NOT "patient")
     - A clinician is a "RENDERING_PROVIDER"   (NOT "physician")
     - A place is a "PLACE_OF_SERVICE" (POS code)
     - A visit/service is a "CLAIMS_LINE"      (NOT "visit")
     - Diagnoses are ICD-10 WITHOUT decimals (E119, not E11.9)
     - Gender is coded 1=Male, 2=Female (NOT 'M'/'F')
     - Names are stored "LAST, FIRST M"

   Intentional messiness in this file:
     1. CLAIMS_LINE is heavily OVERLOADED: one row = Claim + ClaimLine +
        Procedure (CPT) + Diagnosis (ICD) + rendering Provider + Coverage +
        Member.  -> maps to 6-7 ontology classes.
     2. Same entities, different names vs CLINICAL_EMR: MEMBER=Patient,
        RENDERING_PROVIDER=Physician, PLACE_OF_SERVICE=Department/Location.
     3. Different code conventions: ICD-10 with no dot, POS numeric codes,
        gender as 1/2, name as "LAST, FIRST".
     4. MEMBER_SSN is NULL for some members (forces name+DOB alignment).

   Cross-system linkage keys (so the ontology CAN traverse later):
     - MEMBER_ID     == CLINICAL_EMR.PATIENT_MASTER.INS_MEMBER_ID (direct link)
     - MEMBER_SSN    -> aligns to CLINICAL_EMR SSN and PHARMACY_OPS PATIENT_SSN
     - RENDERING_NPI == CLINICAL_EMR PHYSICIAN.NPI and PHARMACY_OPS PRESCRIBER_ID
     - (MEMBER_ID + RENDERING_NPI + SERVICE_DATE) aligns a CLAIMS_LINE to a VISIT
     - SUBSCRIBER_ID groups family members under one policy (Coverage)
   =============================================================================*/

-- USE ROLE SYSADMIN;
-- USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS PAYER_CLAIMS;
CREATE SCHEMA   IF NOT EXISTS PAYER_CLAIMS.CLAIMS;
USE SCHEMA PAYER_CLAIMS.CLAIMS;

-- -----------------------------------------------------------------------------
-- MEMBER  (this system's word for a Patient; also carries Coverage inline)
--   SUBSCRIBER_ID groups a policy; RELATIONSHIP = self/spouse/child.
--   James Johnson (MBR0003) & Linda Williams (MBR0004) share one policy.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE MEMBER (
    MEMBER_ID       STRING,         -- == CLINICAL_EMR.PATIENT_MASTER.INS_MEMBER_ID
    SUBSCRIBER_ID   STRING,         -- policy grouping (Coverage)
    MEMBER_SSN      STRING,         -- nullable (messy)
    MEMBER_NAME     STRING,         -- "LAST, FIRST M"
    DOB             DATE,
    GENDER          NUMBER,         -- 1=Male, 2=Female
    RELATIONSHIP    STRING,         -- self / spouse / child
    PLAN_NAME       STRING,         -- Coverage
    GROUP_NO        STRING,
    EFFECTIVE_DATE  DATE,
    TERM_DATE       DATE
);

INSERT INTO MEMBER VALUES
    ('MBR0001','SUB0001','111-22-3001','SMITH, ROBERT A',    '1958-03-14',1,'self',  'Buckeye Health Plan',   'GRP100','2024-01-01',NULL),
    ('MBR0002','SUB0002','111-22-3002','GARCIA, MARIA E',    '1972-07-22',2,'self',  'Buckeye Health Plan',   'GRP100','2024-01-01',NULL),
    ('MBR0003','SUBFAM1','111-22-3003','JOHNSON, JAMES R',   '1965-11-30',1,'self',  'Aetna Choice',          'GRP200','2023-06-01',NULL),
    ('MBR0004','SUBFAM1',NULL,         'WILLIAMS, LINDA S',  '1980-01-05',2,'spouse','Aetna Choice',          'GRP200','2023-06-01',NULL),  -- SSN NULL: align by name+DOB
    ('MBR0005','SUB0005','111-22-3005','BROWN, MICHAEL D',   '1990-09-18',1,'self',  'UnitedHealthcare',      'GRP300','2024-03-01',NULL),
    ('MBR0006','SUB0006','111-22-3006','JONES, PATRICIA A',  '1955-12-02',2,'self',  'Medicare',              'GRPMCR','2020-12-01',NULL),
    ('MBR0007','SUB0007','111-22-3007','MILLER, DAVID L',    '1978-04-27',1,'self',  'Buckeye Health Plan',   'GRP100','2024-01-01',NULL),
    ('MBR0008','SUB0008',NULL,         'DAVIS, JENNIFER K',  '1985-06-11',2,'self',  'Cigna Open Access',     'GRP400','2024-02-01',NULL),  -- SSN NULL: align by name+DOB
    ('MBR0009','SUB0009','111-22-3009','WILSON, WILLIAM R',  '1949-02-19',1,'self',  'Medicare',              'GRPMCR','2014-02-01',NULL),
    ('MBR0010','SUB0010','111-22-3010','MOORE, ELIZABETH R', '1968-08-08',2,'self',  'UnitedHealthcare',      'GRP300','2024-03-01',NULL),
    ('MBR0011','SUB0011','111-22-3011','TAYLOR, RICHARD P',  '1970-10-15',1,'self',  'Cigna Open Access',     'GRP400','2024-02-01',NULL),
    ('MBR0012','SUB0012','111-22-3012','ANDERSON, SUSAN M',  '1962-05-25',2,'self',  'Buckeye Health Plan',   'GRP100','2024-01-01',NULL);

-- -----------------------------------------------------------------------------
-- RENDERING_PROVIDER  (this system's word for a Physician; keyed by NPI)
--   Name formatted "LAST, FIRST"; specialty spelled/cased differently.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE RENDERING_PROVIDER (
    RENDERING_NPI   STRING,         -- == CLINICAL_EMR PHYSICIAN.NPI
    PROVIDER_NAME   STRING,         -- "CHEN, SARAH"
    PROVIDER_TYPE   STRING,
    TAX_ID          STRING
);

INSERT INTO RENDERING_PROVIDER VALUES
    ('1003000001','CHEN, SARAH',    'ENDOCRINOLOGY',     '31-1000001'),
    ('1003000002','PATEL, ROBERT',  'CARDIOLOGY',        '31-1000002'),
    ('1003000003','NGUYEN, EMILY',  'INTERNAL MED',      '31-1000003'),
    ('1003000004','LEE, MARCUS',    'FAMILY PRACTICE',   '31-1000004'),
    ('1003000005','RAO, ANITA',     'NEPHROLOGY',        '31-1000005'),
    ('1003000006','OBRIEN, JOHN',   'PSYCHIATRY',        '31-1000006');  -- note: apostrophe dropped

-- -----------------------------------------------------------------------------
-- PLACE_OF_SERVICE  (this system's word for a Location; CMS POS codes)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PLACE_OF_SERVICE (
    POS_CODE        STRING,
    POS_DESCRIPTION STRING
);

INSERT INTO PLACE_OF_SERVICE VALUES
    ('11','Office'),
    ('21','Inpatient Hospital'),
    ('22','On Campus-Outpatient Hospital'),
    ('49','Independent Clinic'),
    ('81','Independent Laboratory');

-- -----------------------------------------------------------------------------
-- CLAIMS_LINE  (HEAVILY OVERLOADED: Claim + ClaimLine + Procedure + Diagnosis +
--               rendering Provider + Coverage + Member, all in one row)
--   Diagnoses stored as ICD-10 WITHOUT the decimal point (E119, I509 ...).
--   Align each line to CLINICAL_EMR.VISIT by (MEMBER_ID+RENDERING_NPI+SERVICE_DATE).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE CLAIMS_LINE (
    CLAIM_ID        STRING,
    LINE_NO         NUMBER,
    MEMBER_ID       STRING,         -- Member (Patient)
    SUBSCRIBER_ID   STRING,         -- Coverage / policy
    PLAN_NAME       STRING,         -- Coverage (denormalized onto the line)
    RENDERING_NPI   STRING,         -- Provider (Physician)
    SERVICE_DATE    DATE,
    POS_CODE        STRING,         -- Location
    DX_CODE         STRING,         -- Diagnosis (ICD-10, NO dot)
    CPT_CODE        STRING,         -- Procedure
    CPT_DESC        STRING,
    CHARGE_AMT      NUMBER(10,2),
    ALLOWED_AMT     NUMBER(10,2),
    PAID_AMT        NUMBER(10,2),
    CLAIM_STATUS    STRING          -- Paid/Denied (overloaded STATUS name again)
);

INSERT INTO CLAIMS_LINE VALUES
    -- Robert Smith (MBR0001) w/ Dr. Chen 2025-02-10  -> aligns to VISIT V0001
    ('CLM0001',1,'MBR0001','SUB0001','Buckeye Health Plan','1003000001','2025-02-10','11','E119', '99214','Office visit, established, moderate',220.00,140.00,112.00,'Paid'),
    ('CLM0001',2,'MBR0001','SUB0001','Buckeye Health Plan','1003000001','2025-02-10','11','E119', '83036','Hemoglobin A1c',                     45.00, 22.00, 22.00,'Paid'),
    -- Maria Garcia (MBR0002) w/ Dr. Nguyen 2025-03-05 -> VISIT V0002
    ('CLM0002',1,'MBR0002','SUB0002','Buckeye Health Plan','1003000003','2025-03-05','11','I10',  '99213','Office visit, established, low',     180.00,120.00, 96.00,'Paid'),
    -- James Johnson (MBR0003) w/ Dr. Patel 2025-01-20 -> VISIT V0003
    ('CLM0003',1,'MBR0003','SUBFAM1','Aetna Choice',       '1003000002','2025-01-20','11','I509', '99214','Office visit, established, moderate',240.00,160.00,128.00,'Paid'),
    ('CLM0003',2,'MBR0003','SUBFAM1','Aetna Choice',       '1003000002','2025-01-20','11','I509', '93000','Electrocardiogram, complete',        75.00, 40.00, 40.00,'Paid'),
    -- Linda Williams (MBR0004) w/ Dr. O'Brien 2025-04-02 -> VISIT V0004
    ('CLM0004',1,'MBR0004','SUBFAM1','Aetna Choice',       '1003000006','2025-04-02','11','F329', '99213','Office visit, established, low',     180.00,120.00, 96.00,'Paid'),
    -- Michael Brown (MBR0005) w/ Dr. Chen 2025-02-25 -> VISIT V0005
    ('CLM0005',1,'MBR0005','SUB0005','UnitedHealthcare',   '1003000001','2025-02-25','11','E119', '99214','Office visit, established, moderate',220.00,145.00,116.00,'Paid'),
    ('CLM0005',2,'MBR0005','SUB0005','UnitedHealthcare',   '1003000001','2025-02-25','11','E119', '83036','Hemoglobin A1c',                     45.00, 22.00, 22.00,'Paid'),
    -- Patricia Jones (MBR0006) w/ Dr. Rao 2025-03-18 -> VISIT V0006
    ('CLM0006',1,'MBR0006','SUB0006','Medicare',           '1003000005','2025-03-18','11','N183', '99214','Office visit, established, moderate',230.00,150.00,150.00,'Paid'),
    ('CLM0006',2,'MBR0006','SUB0006','Medicare',           '1003000005','2025-03-18','11','N183', '80053','Comprehensive metabolic panel',      55.00, 28.00, 28.00,'Paid'),
    -- David Miller (MBR0007) w/ Dr. Lee 2025-05-06 -> VISIT V0007
    ('CLM0007',1,'MBR0007','SUB0007','Buckeye Health Plan','1003000004','2025-05-06','11','E785', '99213','Office visit, established, low',     180.00,120.00, 96.00,'Paid'),
    -- Jennifer Davis (MBR0008) w/ Dr. Nguyen 2025-03-12 -> VISIT V0008
    ('CLM0008',1,'MBR0008','SUB0008','Cigna Open Access',  '1003000003','2025-03-12','11','I10',  '99213','Office visit, established, low',     180.00,120.00, 96.00,'Paid'),
    -- William Wilson (MBR0009) w/ Dr. Patel 2025-01-28 -> VISIT V0009
    ('CLM0009',1,'MBR0009','SUB0009','Medicare',           '1003000002','2025-01-28','11','I4891','99214','Office visit, established, moderate',240.00,160.00,160.00,'Paid'),
    ('CLM0009',2,'MBR0009','SUB0009','Medicare',           '1003000002','2025-01-28','11','I4891','93000','Electrocardiogram, complete',        75.00, 40.00, 40.00,'Paid'),
    -- Elizabeth Moore (MBR0010) w/ Dr. Chen 2025-04-15 -> VISIT V0010
    ('CLM0010',1,'MBR0010','SUB0010','UnitedHealthcare',   '1003000001','2025-04-15','11','E119', '99214','Office visit, established, moderate',220.00,145.00,116.00,'Paid'),
    ('CLM0010',2,'MBR0010','SUB0010','UnitedHealthcare',   '1003000001','2025-04-15','11','E119', '83036','Hemoglobin A1c',                     45.00, 22.00, 22.00,'Paid'),
    -- Richard Taylor (MBR0011) w/ Dr. O'Brien 2025-05-20 -> VISIT V0011
    ('CLM0011',1,'MBR0011','SUB0011','Cigna Open Access',  '1003000006','2025-05-20','11','F329', '99213','Office visit, established, low',     180.00,120.00, 96.00,'Paid'),
    -- Susan Anderson (MBR0012) w/ Dr. Lee 2025-02-14 -> VISIT V0012
    ('CLM0012',1,'MBR0012','SUB0012','Buckeye Health Plan','1003000004','2025-02-14','11','I10',  '99213','Office visit, established, low',     180.00,120.00, 96.00,'Paid');

-- ============================================================
-- ADDITIONAL DATA: patients 13-50 (+6 providers/depts/drugs)
-- Same linkage rules as above; alignments preserved.
-- ============================================================

INSERT INTO RENDERING_PROVIDER VALUES
    ('1003000007','KIM, DAVID','PULMONOLOGY','31-1000007'),
    ('1003000008','MARTINEZ, LAURA','RHEUMATOLOGY','31-1000008'),
    ('1003000009','WRIGHT, THOMAS','GASTROENTEROLOGY','31-1000009'),
    ('1003000010','ADAMS, NICOLE','NEUROLOGY','31-1000010'),
    ('1003000011','BROOKS, KEVIN','ORTHOPEDICS','31-1000011'),
    ('1003000012','GREEN, RACHEL','ONCOLOGY','31-1000012');

INSERT INTO MEMBER VALUES
    ('MBR0013','SUBFAM2','111-22-3013','BAKER, JASON N','1981-04-12',1,'self','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0014','SUBFAM2','111-22-3014','ADAMS, AMY O','1988-07-17',2,'spouse','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0015','SUB0015',NULL,'NELSON, GREGORY P','1995-10-22',1,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL),
    ('MBR0016','SUB0016','111-22-3016','CARTER, MELISSA Q','1947-01-27',2,'self','Aetna Choice','GRP200','2024-01-01',NULL),
    ('MBR0017','SUB0017','111-22-3017','MITCHELL, BENJAMIN R','1954-04-05',1,'self','UnitedHealthcare','GRP300','2024-01-01',NULL),
    ('MBR0018','SUB0018','111-22-3018','PEREZ, STEPHANIE S','1961-07-10',2,'self','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0019','SUB0019','111-22-3019','ROBERTS, JACK T','1968-10-15',1,'self','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0020','SUB0020',NULL,'TURNER, NANCY U','1975-01-20',2,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL),
    ('MBR0021','SUB0021','111-22-3021','PHILLIPS, FRANK V','1982-04-25',1,'self','Aetna Choice','GRP200','2024-01-01',NULL),
    ('MBR0022','SUB0022','111-22-3022','CAMPBELL, BETTY W','1989-07-03',2,'self','UnitedHealthcare','GRP300','2024-01-01',NULL),
    ('MBR0023','SUB0023','111-22-3023','PARKER, PETER X','1996-10-08',1,'self','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0024','SUB0024','111-22-3024','EVANS, SANDRA Y','1948-01-13',2,'self','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0025','SUB0025',NULL,'EDWARDS, BRIAN Z','1955-04-18',1,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL),
    ('MBR0026','SUB0026','111-22-3026','COLLINS, CAROL A','1962-07-23',2,'self','Aetna Choice','GRP200','2024-01-01',NULL),
    ('MBR0027','SUBFAM3','111-22-3027','STEWART, GARY B','1969-10-01',1,'self','UnitedHealthcare','GRP300','2024-01-01',NULL),
    ('MBR0028','SUBFAM3','111-22-3028','MORRIS, SHARON C','1976-01-06',2,'child','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0029','SUB0029','111-22-3029','ROGERS, JEFFREY D','1983-04-11',1,'self','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0030','SUB0030',NULL,'REED, LAURA E','1990-07-16',2,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL),
    ('MBR0031','SUB0031','111-22-3031','COOK, ANTHONY F','1997-10-21',1,'self','Aetna Choice','GRP200','2024-01-01',NULL),
    ('MBR0032','SUB0032','111-22-3032','MORGAN, KIMBERLY G','1949-01-26',2,'self','UnitedHealthcare','GRP300','2024-01-01',NULL),
    ('MBR0033','SUB0033','111-22-3033','BELL, JASON H','1956-04-04',1,'self','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0034','SUB0034','111-22-3034','MURPHY, AMY I','1963-07-09',2,'self','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0035','SUB0035',NULL,'BAILEY, GREGORY J','1970-10-14',1,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL),
    ('MBR0036','SUB0036','111-22-3036','RIVERA, MELISSA K','1977-01-19',2,'self','Aetna Choice','GRP200','2024-01-01',NULL),
    ('MBR0037','SUB0037','111-22-3037','COOPER, BENJAMIN L','1984-04-24',1,'self','UnitedHealthcare','GRP300','2024-01-01',NULL),
    ('MBR0038','SUB0038','111-22-3038','RICHARDSON, STEPHANIE M','1991-07-02',2,'self','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0039','SUB0039','111-22-3039','COX, JACK N','1998-10-07',1,'self','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0040','SUB0040',NULL,'THOMPSON, NANCY O','1950-01-12',2,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL),
    ('MBR0041','SUB0041','111-22-3041','WHITE, FRANK P','1957-04-17',1,'self','Aetna Choice','GRP200','2024-01-01',NULL),
    ('MBR0042','SUB0042','111-22-3042','HARRIS, BETTY Q','1964-07-22',2,'self','UnitedHealthcare','GRP300','2024-01-01',NULL),
    ('MBR0043','SUB0043','111-22-3043','MARTIN, PETER R','1971-10-27',1,'self','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0044','SUB0044','111-22-3044','CLARK, SANDRA S','1978-01-05',2,'self','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0045','SUB0045',NULL,'LEWIS, BRIAN T','1985-04-10',1,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL),
    ('MBR0046','SUB0046','111-22-3046','WALKER, CAROL U','1992-07-15',2,'self','Aetna Choice','GRP200','2024-01-01',NULL),
    ('MBR0047','SUB0047','111-22-3047','HALL, GARY V','1999-10-20',1,'self','UnitedHealthcare','GRP300','2024-01-01',NULL),
    ('MBR0048','SUB0048','111-22-3048','YOUNG, SHARON W','1951-01-25',2,'self','Cigna Open Access','GRP400','2024-01-01',NULL),
    ('MBR0049','SUB0049','111-22-3049','KING, JEFFREY X','1958-04-03',1,'self','Medicare','GRPMCR','2024-01-01',NULL),
    ('MBR0050','SUB0050',NULL,'WRIGHT, LAURA Y','1965-07-08',2,'self','Buckeye Health Plan','GRP100','2024-01-01',NULL);

INSERT INTO CLAIMS_LINE VALUES
    ('CLM0013',1,'MBR0013','SUBFAM2','Cigna Open Access','1003000001','2025-08-08','11','E119','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0013',2,'MBR0013','SUBFAM2','Cigna Open Access','1003000001','2025-08-08','11','E119','83036','Hemoglobin A1c',45.0,22.0,22.0,'Paid'),
    ('CLM0014',1,'MBR0014','SUBFAM2','Medicare','1003000001','2025-03-21','11','E119','99214','Office visit, established, moderate',220.0,145.0,145.0,'Paid'),
    ('CLM0014',2,'MBR0014','SUBFAM2','Medicare','1003000001','2025-03-21','11','E119','83036','Hemoglobin A1c',45.0,22.0,22.0,'Paid'),
    ('CLM0015',1,'MBR0015','SUB0015','Buckeye Health Plan','1003000001','2025-10-07','11','E119','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0015',2,'MBR0015','SUB0015','Buckeye Health Plan','1003000001','2025-10-07','11','E119','83036','Hemoglobin A1c',45.0,22.0,22.0,'Paid'),
    ('CLM0016',1,'MBR0016','SUB0016','Aetna Choice','1003000003','2025-05-20','11','I10','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0017',1,'MBR0017','SUB0017','UnitedHealthcare','1003000003','2025-12-06','11','I10','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0017',2,'MBR0017','SUB0017','UnitedHealthcare','1003000003','2025-12-06','11','I10','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0018',1,'MBR0018','SUB0018','Cigna Open Access','1003000002','2025-07-19','11','I509','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0018',2,'MBR0018','SUB0018','Cigna Open Access','1003000002','2025-07-19','11','I509','93000','Electrocardiogram, complete',75.0,40.0,32.0,'Paid'),
    ('CLM0019',1,'MBR0019','SUB0019','Medicare','1003000002','2025-02-05','11','I4891','99214','Office visit, established, moderate',220.0,145.0,145.0,'Paid'),
    ('CLM0019',2,'MBR0019','SUB0019','Medicare','1003000002','2025-02-05','11','I4891','93000','Electrocardiogram, complete',75.0,40.0,40.0,'Paid'),
    ('CLM0020',1,'MBR0020','SUB0020','Buckeye Health Plan','1003000002','2025-09-18','11','I2510','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0020',2,'MBR0020','SUB0020','Buckeye Health Plan','1003000002','2025-09-18','11','I2510','93000','Electrocardiogram, complete',75.0,40.0,32.0,'Paid'),
    ('CLM0020',3,'MBR0020','SUB0020','Buckeye Health Plan','1003000002','2025-09-18','11','I2510','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0021',1,'MBR0021','SUB0021','Aetna Choice','1003000006','2025-04-04','11','F329','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0022',1,'MBR0022','SUB0022','UnitedHealthcare','1003000005','2025-11-17','11','N183','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0022',2,'MBR0022','SUB0022','UnitedHealthcare','1003000005','2025-11-17','11','N183','80053','Comprehensive metabolic panel',55.0,28.0,28.0,'Paid'),
    ('CLM0023',1,'MBR0023','SUB0023','Cigna Open Access','1003000004','2025-06-03','11','E785','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0023',2,'MBR0023','SUB0023','Cigna Open Access','1003000004','2025-06-03','11','E785','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0024',1,'MBR0024','SUB0024','Medicare','1003000007','2025-01-16','11','J449','99213','Office visit, established, low',180.0,120.0,120.0,'Paid'),
    ('CLM0025',1,'MBR0025','SUB0025','Buckeye Health Plan','1003000007','2025-08-02','11','J45909','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0026',1,'MBR0026','SUB0026','Aetna Choice','1003000008','2025-03-15','11','M069','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0027',1,'MBR0027','SUBFAM3','UnitedHealthcare','1003000009','2025-10-01','11','K219','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0028',1,'MBR0028','SUBFAM3','Cigna Open Access','1003000003','2025-05-14','11','E039','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0029',1,'MBR0029','SUB0029','Medicare','1003000010','2025-12-27','11','G40909','99213','Office visit, established, low',180.0,120.0,120.0,'Paid'),
    ('CLM0030',1,'MBR0030','SUB0030','Buckeye Health Plan','1003000011','2025-07-13','11','M545','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0031',1,'MBR0031','SUB0031','Aetna Choice','1003000004','2025-02-26','11','I10','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0031',2,'MBR0031','SUB0031','Aetna Choice','1003000004','2025-02-26','11','I10','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0032',1,'MBR0032','SUB0032','UnitedHealthcare','1003000012','2025-09-12','11','E785','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0032',2,'MBR0032','SUB0032','UnitedHealthcare','1003000012','2025-09-12','11','E785','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0033',1,'MBR0033','SUB0033','Cigna Open Access','1003000001','2025-04-25','11','E119','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0033',2,'MBR0033','SUB0033','Cigna Open Access','1003000001','2025-04-25','11','E119','83036','Hemoglobin A1c',45.0,22.0,22.0,'Paid'),
    ('CLM0034',1,'MBR0034','SUB0034','Medicare','1003000001','2025-11-11','11','E119','99214','Office visit, established, moderate',220.0,145.0,145.0,'Paid'),
    ('CLM0034',2,'MBR0034','SUB0034','Medicare','1003000001','2025-11-11','11','E119','83036','Hemoglobin A1c',45.0,22.0,22.0,'Paid'),
    ('CLM0035',1,'MBR0035','SUB0035','Buckeye Health Plan','1003000001','2025-06-24','11','E119','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0035',2,'MBR0035','SUB0035','Buckeye Health Plan','1003000001','2025-06-24','11','E119','83036','Hemoglobin A1c',45.0,22.0,22.0,'Paid'),
    ('CLM0036',1,'MBR0036','SUB0036','Aetna Choice','1003000003','2025-01-10','11','I10','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0037',1,'MBR0037','SUB0037','UnitedHealthcare','1003000003','2025-08-23','11','I10','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0037',2,'MBR0037','SUB0037','UnitedHealthcare','1003000003','2025-08-23','11','I10','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0038',1,'MBR0038','SUB0038','Cigna Open Access','1003000002','2025-03-09','11','I509','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0038',2,'MBR0038','SUB0038','Cigna Open Access','1003000002','2025-03-09','11','I509','93000','Electrocardiogram, complete',75.0,40.0,32.0,'Paid'),
    ('CLM0039',1,'MBR0039','SUB0039','Medicare','1003000002','2025-10-22','11','I4891','99214','Office visit, established, moderate',220.0,145.0,145.0,'Paid'),
    ('CLM0039',2,'MBR0039','SUB0039','Medicare','1003000002','2025-10-22','11','I4891','93000','Electrocardiogram, complete',75.0,40.0,40.0,'Paid'),
    ('CLM0040',1,'MBR0040','SUB0040','Buckeye Health Plan','1003000002','2025-05-08','11','I2510','99214','Office visit, established, moderate',220.0,145.0,116.0,'Paid'),
    ('CLM0040',2,'MBR0040','SUB0040','Buckeye Health Plan','1003000002','2025-05-08','11','I2510','93000','Electrocardiogram, complete',75.0,40.0,32.0,'Paid'),
    ('CLM0040',3,'MBR0040','SUB0040','Buckeye Health Plan','1003000002','2025-05-08','11','I2510','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0041',1,'MBR0041','SUB0041','Aetna Choice','1003000006','2025-12-21','11','F329','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0042',1,'MBR0042','SUB0042','UnitedHealthcare','1003000005','2025-07-07','11','N183','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0042',2,'MBR0042','SUB0042','UnitedHealthcare','1003000005','2025-07-07','11','N183','80053','Comprehensive metabolic panel',55.0,28.0,28.0,'Paid'),
    ('CLM0043',1,'MBR0043','SUB0043','Cigna Open Access','1003000004','2025-02-20','11','E785','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0043',2,'MBR0043','SUB0043','Cigna Open Access','1003000004','2025-02-20','11','E785','80061','Lipid panel',50.0,25.0,25.0,'Paid'),
    ('CLM0044',1,'MBR0044','SUB0044','Medicare','1003000007','2025-09-06','11','J449','99213','Office visit, established, low',180.0,120.0,120.0,'Paid'),
    ('CLM0045',1,'MBR0045','SUB0045','Buckeye Health Plan','1003000007','2025-04-19','11','J45909','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0046',1,'MBR0046','SUB0046','Aetna Choice','1003000008','2025-11-05','11','M069','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0047',1,'MBR0047','SUB0047','UnitedHealthcare','1003000009','2025-06-18','11','K219','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0048',1,'MBR0048','SUB0048','Cigna Open Access','1003000003','2025-01-04','11','E039','99213','Office visit, established, low',180.0,120.0,96.0,'Paid'),
    ('CLM0049',1,'MBR0049','SUB0049','Medicare','1003000010','2025-08-17','11','G40909','99213','Office visit, established, low',180.0,120.0,120.0,'Paid'),
    ('CLM0050',1,'MBR0050','SUB0050','Buckeye Health Plan','1003000011','2025-03-03','11','M545','99213','Office visit, established, low',180.0,120.0,96.0,'Paid');

-- Quick sanity check
SELECT 'PAYER_CLAIMS loaded' AS status,
       (SELECT COUNT(*) FROM MEMBER)      AS members,
       (SELECT COUNT(*) FROM CLAIMS_LINE) AS claim_lines,
       (SELECT COUNT(DISTINCT CLAIM_ID) FROM CLAIMS_LINE) AS claims;
