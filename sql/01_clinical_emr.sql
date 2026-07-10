/* =============================================================================
   SYSTEM 1 of 3:  CLINICAL_EMR  (the electronic medical record / clinical side)
   -----------------------------------------------------------------------------
   Demo purpose: messy source data for an ontology-alignment demo.

   This system's vocabulary:
     - A person is a "PATIENT" (identified by MRN)
     - A clinician is a "PHYSICIAN"
     - A place is a "DEPARTMENT" / facility
     - A visit is a "VISIT"
     - Diagnoses live in "PROBLEM_LIST" (ICD-10 WITH decimal points, e.g. E11.9)
     - Drugs are "MEDICATION" orders (generic names + RxNorm, some RxNorm NULL)

   Intentional messiness in this file:
     1. PATIENT_MASTER is OVERLOADED: one row carries Patient + Address +
        PCP (Provider) + Coverage (insurance) + RelatedPerson (next of kin).
        -> maps to 5 ontology classes.
     2. VISIT is OVERLOADED: Encounter + Provider + Department(Location)
        + primary Condition + vital-sign Observations (wide columns).
     3. LAB_RESULTS is WIDE: one row, many analytes as columns
        -> each column is really an Observation instance (needs unpivot).

   Cross-system linkage keys (so the ontology CAN traverse later):
     - SSN            -> aligns to PAYER_CLAIMS.MEMBER.MEMBER_SSN
                         and PHARMACY_OPS.SUBSCRIBER.PATIENT_SSN
     - INS_MEMBER_ID  -> equals PAYER_CLAIMS.MEMBER.MEMBER_ID (direct link)
     - PCP_NPI / VISIT.PHYSICIAN NPI -> equals RENDERING_PROVIDER.RENDERING_NPI
                         and PHARMACY_OPS.PRESCRIBER.PRESCRIBER_ID
     - MEDICATION.RXNORM_CODE -> crosswalks to NDC via PHARMACY_OPS.NDC_PRODUCT
   =============================================================================*/

-- Run with a role that can CREATE DATABASE (e.g., SYSADMIN).
-- USE ROLE SYSADMIN;
-- USE WAREHOUSE COMPUTE_WH;

CREATE DATABASE IF NOT EXISTS CLINICAL_EMR;
CREATE SCHEMA   IF NOT EXISTS CLINICAL_EMR.EHR;
USE SCHEMA CLINICAL_EMR.EHR;

-- -----------------------------------------------------------------------------
-- PHYSICIAN  (this system's word for a clinician; local id + NPI)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PHYSICIAN (
    PHYSICIAN_ID   NUMBER,          -- local surrogate key
    NPI            STRING,          -- national provider id (universal join key)
    FULL_NAME      STRING,          -- "Sarah Chen, MD"  (free-text formatting)
    SPECIALTY      STRING,
    DEPT_ID        NUMBER
);

INSERT INTO PHYSICIAN VALUES
    (101, '1003000001', 'Sarah Chen, MD',   'Endocrinology',    1),
    (102, '1003000002', 'Robert Patel, MD', 'Cardiology',       2),
    (103, '1003000003', 'Emily Nguyen, MD', 'Internal Medicine',3),
    (104, '1003000004', 'Marcus Lee, MD',   'Family Medicine',  4),
    (105, '1003000005', 'Anita Rao, MD',    'Nephrology',       5),
    (106, '1003000006', 'John O''Brien, MD','Psychiatry',       6);

-- -----------------------------------------------------------------------------
-- DEPARTMENT  (Location/Organization as this system sees it)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE DEPARTMENT (
    DEPT_ID        NUMBER,
    DEPT_NAME      STRING,
    FACILITY_NAME  STRING,
    ADDRESS        STRING,
    CITY           STRING,
    STATE          STRING,
    ZIP            STRING
);

INSERT INTO DEPARTMENT VALUES
    (1, 'Endocrinology Clinic', 'Riverside Medical Center',   '400 Riverside Dr', 'Columbus', 'OH', '43210'),
    (2, 'Cardiology',           'Riverside Medical Center',   '400 Riverside Dr', 'Columbus', 'OH', '43210'),
    (3, 'Internal Medicine',    'Downtown Health Pavilion',   '12 Main St',       'Columbus', 'OH', '43215'),
    (4, 'Family Medicine',      'Downtown Health Pavilion',   '12 Main St',       'Columbus', 'OH', '43215'),
    (5, 'Nephrology',           'Riverside Medical Center',   '400 Riverside Dr', 'Columbus', 'OH', '43210'),
    (6, 'Behavioral Health',    'Downtown Health Pavilion',   '12 Main St',       'Columbus', 'OH', '43215');

-- -----------------------------------------------------------------------------
-- PATIENT_MASTER  (OVERLOADED: Patient + Address + PCP + Coverage + NextOfKin)
--   NOTE: INS_MEMBER_ID is a direct link to PAYER_CLAIMS.MEMBER.MEMBER_ID.
--         SSN is the fuzzy/universal person link across all 3 systems.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PATIENT_MASTER (
    MRN            STRING,          -- medical record number (this system's patient id)
    SSN            STRING,
    FIRST_NAME     STRING,
    MIDDLE_NAME    STRING,
    LAST_NAME      STRING,
    DOB            DATE,
    SEX            STRING,          -- 'M'/'F'
    ADDR_LINE1     STRING,          -- Address (own ontology class)
    CITY           STRING,
    STATE          STRING,
    ZIP            STRING,
    PHONE          STRING,
    PCP_NPI        STRING,          -- Provider (PCP) embedded in the patient row
    INS_PAYER_NAME STRING,          -- Coverage embedded in the patient row
    INS_MEMBER_ID  STRING,          -- == PAYER_CLAIMS.MEMBER.MEMBER_ID
    INS_GROUP      STRING,
    KIN_NAME       STRING,          -- RelatedPerson (next of kin) embedded here
    KIN_RELATION   STRING,
    KIN_PHONE      STRING
);

INSERT INTO PATIENT_MASTER VALUES
    ('MRN1001','111-22-3001','Robert','Alan','Smith',   '1958-03-14','M','101 Oak St',    'Columbus','OH','43201','614-555-0101','1003000004','Buckeye Health Plan','MBR0001','GRP100','Nancy Smith',   'Spouse','614-555-0111'),
    ('MRN1002','111-22-3002','Maria', 'Elena','Garcia',  '1972-07-22','F','22 Elm Ave',    'Columbus','OH','43202','614-555-0102','1003000003','Buckeye Health Plan','MBR0002','GRP100','Jose Garcia',   'Spouse','614-555-0112'),
    ('MRN1003','111-22-3003','James', 'Robert','Johnson','1965-11-30','M','9 Pine Rd',      'Columbus','OH','43203','614-555-0103','1003000002','Aetna Choice',       'MBR0003','GRP200','Linda Williams','Spouse','614-555-0113'),
    ('MRN1004','111-22-3004','Linda', 'Sue','Williams',  '1980-01-05','F','9 Pine Rd',      'Columbus','OH','43203','614-555-0104','1003000006','Aetna Choice',       'MBR0004','GRP200','James Johnson', 'Spouse','614-555-0103'),
    ('MRN1005','111-22-3005','Michael','David','Brown',  '1990-09-18','M','77 Maple Ct',    'Columbus','OH','43204','614-555-0105','1003000001','UnitedHealthcare',   'MBR0005','GRP300','Karen Brown',   'Parent','614-555-0115'),
    ('MRN1006','111-22-3006','Patricia','Ann','Jones',   '1955-12-02','F','8 Cedar Blvd',   'Columbus','OH','43205','614-555-0106','1003000005','Medicare',           'MBR0006','GRPMCR','Tom Jones',     'Child', '614-555-0116'),
    ('MRN1007','111-22-3007','David',  'Lee','Miller',   '1978-04-27','M','5 Birch Ln',     'Columbus','OH','43206','614-555-0107','1003000004','Buckeye Health Plan','MBR0007','GRP100','Sara Miller',   'Spouse','614-555-0117'),
    ('MRN1008','111-22-3008','Jennifer','Kay','Davis',   '1985-06-11','F','31 Walnut St',   'Columbus','OH','43207','614-555-0108','1003000003','Cigna Open Access',  'MBR0008','GRP400','Mark Davis',    'Spouse','614-555-0118'),
    ('MRN1009','111-22-3009','William','Ray','Wilson',   '1949-02-19','M','14 Spruce Way',  'Columbus','OH','43209','614-555-0109','1003000002','Medicare',           'MBR0009','GRPMCR','Ruth Wilson',   'Spouse','614-555-0119'),
    ('MRN1010','111-22-3010','Elizabeth','Rose','Moore', '1968-08-08','F','60 Ash Dr',      'Columbus','OH','43210','614-555-0110','1003000001','UnitedHealthcare',   'MBR0010','GRP300','Paul Moore',    'Spouse','614-555-0120'),
    ('MRN1011','111-22-3011','Richard','Paul','Taylor',  '1970-10-15','M','2 Hickory Pl',   'Columbus','OH','43211','614-555-0121','1003000006','Cigna Open Access',  'MBR0011','GRP400','Amy Taylor',    'Spouse','614-555-0121'),
    ('MRN1012','111-22-3012','Susan',  'Marie','Anderson','1962-05-25','F','48 Poplar St',  'Columbus','OH','43212','614-555-0122','1003000004','Buckeye Health Plan','MBR0012','GRP100','Greg Anderson', 'Spouse','614-555-0122');

-- -----------------------------------------------------------------------------
-- PROBLEM_LIST  (Conditions; ICD-10 WITH decimals; also a SNOMED code)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE PROBLEM_LIST (
    PROBLEM_ID     NUMBER,
    MRN            STRING,
    ICD10_CODE     STRING,          -- e.g. 'E11.9'  (claims side drops the dot!)
    ICD10_DESC     STRING,
    SNOMED_CODE    STRING,
    ONSET_DATE     DATE,
    STATUS         STRING           -- 'Active' meaning problem status (see: overloaded STATUS across systems)
);

INSERT INTO PROBLEM_LIST VALUES
    (1, 'MRN1001','E11.9','Type 2 diabetes mellitus without complications','44054006','2019-05-01','Active'),
    (2, 'MRN1001','E78.5','Hyperlipidemia, unspecified',                    '55822004','2019-05-01','Active'),
    (3, 'MRN1002','I10',  'Essential (primary) hypertension',               '59621000','2020-02-14','Active'),
    (4, 'MRN1003','I50.9','Heart failure, unspecified',                      '84114007','2018-09-10','Active'),
    (5, 'MRN1003','I10',  'Essential (primary) hypertension',               '59621000','2018-09-10','Active'),
    (6, 'MRN1004','F32.9','Major depressive disorder, single episode',      '370143000','2021-03-22','Active'),
    (7, 'MRN1005','E11.9','Type 2 diabetes mellitus without complications', '44054006','2022-01-11','Active'),
    (8, 'MRN1006','N18.3','Chronic kidney disease, stage 3',                '431857002','2017-06-30','Active'),
    (9, 'MRN1006','I10',  'Essential (primary) hypertension',               '59621000','2017-06-30','Active'),
    (10,'MRN1007','E78.5','Hyperlipidemia, unspecified',                    '55822004','2021-11-05','Active'),
    (11,'MRN1008','I10',  'Essential (primary) hypertension',               '59621000','2022-07-19','Active'),
    (12,'MRN1009','I48.91','Unspecified atrial fibrillation',               '49436004','2016-04-02','Active'),
    (13,'MRN1009','I50.9','Heart failure, unspecified',                     '84114007','2016-04-02','Active'),
    (14,'MRN1010','E11.9','Type 2 diabetes mellitus without complications', '44054006','2020-08-08','Active'),
    (15,'MRN1010','E78.5','Hyperlipidemia, unspecified',                    '55822004','2020-08-08','Active'),
    (16,'MRN1011','F32.9','Major depressive disorder, single episode',      '370143000','2023-01-30','Active'),
    (17,'MRN1012','I10',  'Essential (primary) hypertension',               '59621000','2019-05-25','Active'),
    (18,'MRN1012','E78.5','Hyperlipidemia, unspecified',                    '55822004','2019-05-25','Active');

-- -----------------------------------------------------------------------------
-- VISIT  (OVERLOADED: Encounter + Provider + Department + primary Condition +
--         vital-sign Observations as wide columns)
--   Align to PAYER_CLAIMS.CLAIMS_LINE by (patient + NPI + service date).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE VISIT (
    VISIT_ID       STRING,
    MRN            STRING,
    PHYSICIAN_ID   NUMBER,          -- FK to PHYSICIAN (local id; NPI is the cross-system key)
    DEPT_ID        NUMBER,
    VISIT_DATE     DATE,
    VISIT_TYPE     STRING,
    PRIMARY_ICD10  STRING,          -- primary Condition for the encounter
    -- wide vital-sign Observations below:
    BP_SYSTOLIC    NUMBER,
    BP_DIASTOLIC   NUMBER,
    WEIGHT_KG      NUMBER(6,1),
    A1C_PCT        NUMBER(4,1),
    STATUS         STRING           -- encounter status (overloaded STATUS name again)
);

INSERT INTO VISIT VALUES
    ('V0001','MRN1001',101,1,'2025-02-10','Office',    'E11.9',130,82, 95.3,7.8,'Completed'),
    ('V0002','MRN1002',103,3,'2025-03-05','Office',    'I10',  145,90, 68.0,NULL,'Completed'),
    ('V0003','MRN1003',102,2,'2025-01-20','Office',    'I50.9',128,78, 88.5,NULL,'Completed'),
    ('V0004','MRN1004',106,6,'2025-04-02','Office',    'F32.9',120,76, 62.1,NULL,'Completed'),
    ('V0005','MRN1005',101,1,'2025-02-25','Office',    'E11.9',135,85,102.4,9.1,'Completed'),
    ('V0006','MRN1006',105,5,'2025-03-18','Office',    'N18.3',150,92, 70.2,NULL,'Completed'),
    ('V0007','MRN1007',104,4,'2025-05-06','Office',    'E78.5',122,80, 84.0,NULL,'Completed'),
    ('V0008','MRN1008',103,3,'2025-03-12','Office',    'I10',  138,88, 59.5,NULL,'Completed'),
    ('V0009','MRN1009',102,2,'2025-01-28','Office',    'I48.91',132,79,80.1,NULL,'Completed'),
    ('V0010','MRN1010',101,1,'2025-04-15','Office',    'E11.9',141,86, 77.8,8.3,'Completed'),
    ('V0011','MRN1011',106,6,'2025-05-20','Office',    'F32.9',118,74, 90.6,NULL,'Completed'),
    ('V0012','MRN1012',104,4,'2025-02-14','Office',    'I10',  147,91, 66.3,NULL,'Completed');

-- -----------------------------------------------------------------------------
-- MEDICATION  (drug ORDERS; generic drug names + RxNorm; some RxNorm NULL to
--              force NDC/name crosswalk via PHARMACY_OPS.NDC_PRODUCT)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE MEDICATION (
    MED_ORDER_ID   NUMBER,
    MRN            STRING,
    PHYSICIAN_ID   NUMBER,
    ORDER_DATE     DATE,
    DRUG_NAME      STRING,          -- generic name (pharmacy side often uses brand)
    RXNORM_CODE    STRING,          -- crosswalk key to NDC (nullable = messy)
    SIG            STRING,
    QUANTITY       NUMBER,
    REFILLS        NUMBER
);

INSERT INTO MEDICATION VALUES
    (1, 'MRN1001',101,'2025-02-10','Metformin 500 mg',       '860975','1 tab PO BID',      60,3),
    (2, 'MRN1001',101,'2025-02-10','Atorvastatin 20 mg',     '617312','1 tab PO daily',    30,3),
    (3, 'MRN1002',103,'2025-03-05','Lisinopril 10 mg',       '314076','1 tab PO daily',    30,5),
    (4, 'MRN1003',102,'2025-01-20','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',    60,3),
    (5, 'MRN1003',102,'2025-01-20','Furosemide 40 mg',       '310429','1 tab PO daily',    30,3),
    (6, 'MRN1003',102,'2025-01-20','Lisinopril 10 mg',       '314076','1 tab PO daily',    30,3),
    (7, 'MRN1004',106,'2025-04-02','Sertraline 50 mg',       '312940','1 tab PO daily',    30,3),
    (8, 'MRN1005',101,'2025-02-25','Metformin 500 mg',       '860975','1 tab PO BID',      60,3),
    (9, 'MRN1005',101,'2025-02-25','Insulin Glargine',       '261551','20 units SC nightly',1,5),
    (10,'MRN1006',105,'2025-03-18','Losartan 50 mg',         '979485','1 tab PO daily',    30,3),
    (11,'MRN1007',104,'2025-05-06','Atorvastatin 20 mg',     NULL,    '1 tab PO daily',    30,3),  -- RxNorm intentionally NULL
    (12,'MRN1008',103,'2025-03-12','Lisinopril 10 mg',       '314076','1 tab PO daily',    30,5),
    (13,'MRN1009',102,'2025-01-28','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',    60,3),
    (14,'MRN1009',102,'2025-01-28','Furosemide 40 mg',       '310429','1 tab PO daily',    30,3),
    (15,'MRN1010',101,'2025-04-15','Metformin 500 mg',       '860975','1 tab PO BID',      60,3),
    (16,'MRN1010',101,'2025-04-15','Atorvastatin 20 mg',     '617312','1 tab PO daily',    30,3),
    (17,'MRN1011',106,'2025-05-20','Sertraline 50 mg',       NULL,    '1 tab PO daily',    30,3),  -- RxNorm intentionally NULL
    (18,'MRN1012',104,'2025-02-14','Lisinopril 10 mg',       '314076','1 tab PO daily',    30,5),
    (19,'MRN1012',104,'2025-02-14','Atorvastatin 20 mg',     '617312','1 tab PO daily',    30,3);

-- -----------------------------------------------------------------------------
-- LAB_RESULTS  (WIDE format: many analytes as columns; one row per collection)
--   Each populated column is really an Observation instance (needs unpivot).
--   NULLs are expected/valid (test not ordered).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE LAB_RESULTS (
    LAB_ID          NUMBER,
    MRN             STRING,
    COLLECT_DATE    DATE,
    GLUCOSE_MGDL    NUMBER,
    HBA1C_PCT       NUMBER(4,1),
    LDL_MGDL        NUMBER,
    CREATININE_MGDL NUMBER(4,2),
    EGFR            NUMBER
);

INSERT INTO LAB_RESULTS VALUES
    (1, 'MRN1001','2025-02-10',162,7.8,140,0.95,88),
    (2, 'MRN1002','2025-03-05', 98,NULL,118,0.80,95),
    (3, 'MRN1003','2025-01-20',110,NULL,132,1.30,62),
    (4, 'MRN1005','2025-02-25',205,9.1,155,0.90,90),
    (5, 'MRN1006','2025-03-18',101,NULL,128,1.80,42),
    (6, 'MRN1007','2025-05-06', 95,NULL,168,0.88,92),
    (7, 'MRN1009','2025-01-28',112,NULL,120,1.45,55),
    (8, 'MRN1010','2025-04-15',178,8.3,149,0.92,89),
    (9, 'MRN1012','2025-02-14', 99,NULL,158,0.85,94);

-- ============================================================
-- ADDITIONAL DATA: patients 13-50 (+6 providers/depts/drugs)
-- Same linkage rules as above; alignments preserved.
-- ============================================================

INSERT INTO PHYSICIAN VALUES
    (107,'1003000007','David Kim, MD','Pulmonology',7),
    (108,'1003000008','Laura Martinez, MD','Rheumatology',8),
    (109,'1003000009','Thomas Wright, MD','Gastroenterology',9),
    (110,'1003000010','Nicole Adams, MD','Neurology',10),
    (111,'1003000011','Kevin Brooks, MD','Orthopedics',11),
    (112,'1003000012','Rachel Green, MD','Oncology',12);

INSERT INTO DEPARTMENT VALUES
    (7,'Pulmonology','Riverside Medical Center','400 Riverside Dr','Columbus','OH','43210'),
    (8,'Rheumatology','Downtown Health Pavilion','12 Main St','Columbus','OH','43215'),
    (9,'Gastroenterology','Riverside Medical Center','400 Riverside Dr','Columbus','OH','43210'),
    (10,'Neurology','Downtown Health Pavilion','12 Main St','Columbus','OH','43215'),
    (11,'Orthopedics','Riverside Medical Center','400 Riverside Dr','Columbus','OH','43210'),
    (12,'Oncology','Riverside Medical Center','400 Riverside Dr','Columbus','OH','43210');

INSERT INTO PATIENT_MASTER VALUES
    ('MRN1013','111-22-3013','Jason','N','Baker','1981-04-12','M','113 Baker St','Columbus','OH','43213','614-556-0013','1003000001','Cigna Open Access','MBR0013','GRP400','Pat Baker','Spouse','614-557-0013'),
    ('MRN1014','111-22-3014','Amy','O','Adams','1988-07-17','F','114 Adams St','Columbus','OH','43214','614-556-0014','1003000001','Medicare','MBR0014','GRPMCR','Chris Adams','Spouse','614-557-0014'),
    ('MRN1015','111-22-3015','Gregory','P','Nelson','1995-10-22','M','115 Nelson St','Columbus','OH','43215','614-556-0015','1003000001','Buckeye Health Plan','MBR0015','GRP100','Pat Nelson','Spouse','614-557-0015'),
    ('MRN1016','111-22-3016','Melissa','Q','Carter','1947-01-27','F','116 Carter St','Columbus','OH','43216','614-556-0016','1003000003','Aetna Choice','MBR0016','GRP200','Chris Carter','Spouse','614-557-0016'),
    ('MRN1017','111-22-3017','Benjamin','R','Mitchell','1954-04-05','M','117 Mitchell St','Columbus','OH','43217','614-556-0017','1003000003','UnitedHealthcare','MBR0017','GRP300','Pat Mitchell','Spouse','614-557-0017'),
    ('MRN1018','111-22-3018','Stephanie','S','Perez','1961-07-10','F','118 Perez St','Columbus','OH','43218','614-556-0018','1003000002','Cigna Open Access','MBR0018','GRP400','Chris Perez','Spouse','614-557-0018'),
    ('MRN1019','111-22-3019','Jack','T','Roberts','1968-10-15','M','119 Roberts St','Columbus','OH','43219','614-556-0019','1003000002','Medicare','MBR0019','GRPMCR','Pat Roberts','Spouse','614-557-0019'),
    ('MRN1020','111-22-3020','Nancy','U','Turner','1975-01-20','F','120 Turner St','Columbus','OH','43220','614-556-0020','1003000002','Buckeye Health Plan','MBR0020','GRP100','Chris Turner','Spouse','614-557-0020'),
    ('MRN1021','111-22-3021','Frank','V','Phillips','1982-04-25','M','121 Phillips St','Columbus','OH','43221','614-556-0021','1003000006','Aetna Choice','MBR0021','GRP200','Pat Phillips','Spouse','614-557-0021'),
    ('MRN1022','111-22-3022','Betty','W','Campbell','1989-07-03','F','122 Campbell St','Columbus','OH','43222','614-556-0022','1003000005','UnitedHealthcare','MBR0022','GRP300','Chris Campbell','Spouse','614-557-0022'),
    ('MRN1023','111-22-3023','Peter','X','Parker','1996-10-08','M','123 Parker St','Columbus','OH','43223','614-556-0023','1003000004','Cigna Open Access','MBR0023','GRP400','Pat Parker','Spouse','614-557-0023'),
    ('MRN1024','111-22-3024','Sandra','Y','Evans','1948-01-13','F','124 Evans St','Columbus','OH','43224','614-556-0024','1003000007','Medicare','MBR0024','GRPMCR','Chris Evans','Spouse','614-557-0024'),
    ('MRN1025','111-22-3025','Brian','Z','Edwards','1955-04-18','M','125 Edwards St','Columbus','OH','43225','614-556-0025','1003000007','Buckeye Health Plan','MBR0025','GRP100','Pat Edwards','Spouse','614-557-0025'),
    ('MRN1026','111-22-3026','Carol','A','Collins','1962-07-23','F','126 Collins St','Columbus','OH','43226','614-556-0026','1003000008','Aetna Choice','MBR0026','GRP200','Chris Collins','Spouse','614-557-0026'),
    ('MRN1027','111-22-3027','Gary','B','Stewart','1969-10-01','M','127 Stewart St','Columbus','OH','43227','614-556-0027','1003000009','UnitedHealthcare','MBR0027','GRP300','Pat Stewart','Spouse','614-557-0027'),
    ('MRN1028','111-22-3028','Sharon','C','Morris','1976-01-06','F','128 Morris St','Columbus','OH','43228','614-556-0028','1003000003','Cigna Open Access','MBR0028','GRP400','Chris Morris','Spouse','614-557-0028'),
    ('MRN1029','111-22-3029','Jeffrey','D','Rogers','1983-04-11','M','129 Rogers St','Columbus','OH','43229','614-556-0029','1003000010','Medicare','MBR0029','GRPMCR','Pat Rogers','Spouse','614-557-0029'),
    ('MRN1030','111-22-3030','Laura','E','Reed','1990-07-16','F','130 Reed St','Columbus','OH','43230','614-556-0030','1003000011','Buckeye Health Plan','MBR0030','GRP100','Chris Reed','Spouse','614-557-0030'),
    ('MRN1031','111-22-3031','Anthony','F','Cook','1997-10-21','M','131 Cook St','Columbus','OH','43231','614-556-0031','1003000004','Aetna Choice','MBR0031','GRP200','Pat Cook','Spouse','614-557-0031'),
    ('MRN1032','111-22-3032','Kimberly','G','Morgan','1949-01-26','F','132 Morgan St','Columbus','OH','43232','614-556-0032','1003000012','UnitedHealthcare','MBR0032','GRP300','Chris Morgan','Spouse','614-557-0032'),
    ('MRN1033','111-22-3033','Jason','H','Bell','1956-04-04','M','133 Bell St','Columbus','OH','43233','614-556-0033','1003000001','Cigna Open Access','MBR0033','GRP400','Pat Bell','Spouse','614-557-0033'),
    ('MRN1034','111-22-3034','Amy','I','Murphy','1963-07-09','F','134 Murphy St','Columbus','OH','43234','614-556-0034','1003000001','Medicare','MBR0034','GRPMCR','Chris Murphy','Spouse','614-557-0034'),
    ('MRN1035','111-22-3035','Gregory','J','Bailey','1970-10-14','M','135 Bailey St','Columbus','OH','43235','614-556-0035','1003000001','Buckeye Health Plan','MBR0035','GRP100','Pat Bailey','Spouse','614-557-0035'),
    ('MRN1036','111-22-3036','Melissa','K','Rivera','1977-01-19','F','136 Rivera St','Columbus','OH','43236','614-556-0036','1003000003','Aetna Choice','MBR0036','GRP200','Chris Rivera','Spouse','614-557-0036'),
    ('MRN1037','111-22-3037','Benjamin','L','Cooper','1984-04-24','M','137 Cooper St','Columbus','OH','43237','614-556-0037','1003000003','UnitedHealthcare','MBR0037','GRP300','Pat Cooper','Spouse','614-557-0037'),
    ('MRN1038','111-22-3038','Stephanie','M','Richardson','1991-07-02','F','138 Richardson St','Columbus','OH','43238','614-556-0038','1003000002','Cigna Open Access','MBR0038','GRP400','Chris Richardson','Spouse','614-557-0038'),
    ('MRN1039','111-22-3039','Jack','N','Cox','1998-10-07','M','139 Cox St','Columbus','OH','43239','614-556-0039','1003000002','Medicare','MBR0039','GRPMCR','Pat Cox','Spouse','614-557-0039'),
    ('MRN1040','111-22-3040','Nancy','O','Thompson','1950-01-12','F','140 Thompson St','Columbus','OH','43240','614-556-0040','1003000002','Buckeye Health Plan','MBR0040','GRP100','Chris Thompson','Spouse','614-557-0040'),
    ('MRN1041','111-22-3041','Frank','P','White','1957-04-17','M','141 White St','Columbus','OH','43241','614-556-0041','1003000006','Aetna Choice','MBR0041','GRP200','Pat White','Spouse','614-557-0041'),
    ('MRN1042','111-22-3042','Betty','Q','Harris','1964-07-22','F','142 Harris St','Columbus','OH','43242','614-556-0042','1003000005','UnitedHealthcare','MBR0042','GRP300','Chris Harris','Spouse','614-557-0042'),
    ('MRN1043','111-22-3043','Peter','R','Martin','1971-10-27','M','143 Martin St','Columbus','OH','43243','614-556-0043','1003000004','Cigna Open Access','MBR0043','GRP400','Pat Martin','Spouse','614-557-0043'),
    ('MRN1044','111-22-3044','Sandra','S','Clark','1978-01-05','F','144 Clark St','Columbus','OH','43244','614-556-0044','1003000007','Medicare','MBR0044','GRPMCR','Chris Clark','Spouse','614-557-0044'),
    ('MRN1045','111-22-3045','Brian','T','Lewis','1985-04-10','M','145 Lewis St','Columbus','OH','43245','614-556-0045','1003000007','Buckeye Health Plan','MBR0045','GRP100','Pat Lewis','Spouse','614-557-0045'),
    ('MRN1046','111-22-3046','Carol','U','Walker','1992-07-15','F','146 Walker St','Columbus','OH','43246','614-556-0046','1003000008','Aetna Choice','MBR0046','GRP200','Chris Walker','Spouse','614-557-0046'),
    ('MRN1047','111-22-3047','Gary','V','Hall','1999-10-20','M','147 Hall St','Columbus','OH','43247','614-556-0047','1003000009','UnitedHealthcare','MBR0047','GRP300','Pat Hall','Spouse','614-557-0047'),
    ('MRN1048','111-22-3048','Sharon','W','Young','1951-01-25','F','148 Young St','Columbus','OH','43248','614-556-0048','1003000003','Cigna Open Access','MBR0048','GRP400','Chris Young','Spouse','614-557-0048'),
    ('MRN1049','111-22-3049','Jeffrey','X','King','1958-04-03','M','149 King St','Columbus','OH','43249','614-556-0049','1003000010','Medicare','MBR0049','GRPMCR','Pat King','Spouse','614-557-0049'),
    ('MRN1050','111-22-3050','Laura','Y','Wright','1965-07-08','F','150 Wright St','Columbus','OH','43250','614-556-0050','1003000011','Buckeye Health Plan','MBR0050','GRP100','Chris Wright','Spouse','614-557-0050');

INSERT INTO PROBLEM_LIST VALUES
    (19,'MRN1013','E11.9','Type 2 diabetes mellitus without complications','44054006','2021-01-01','Active'),
    (20,'MRN1014','E11.9','Type 2 diabetes mellitus without complications','44054006','2020-01-01','Active'),
    (21,'MRN1014','E78.5','Hyperlipidemia, unspecified','55822004','2020-01-01','Active'),
    (22,'MRN1015','E11.9','Type 2 diabetes mellitus without complications','44054006','2020-01-01','Active'),
    (23,'MRN1016','I10','Essential (primary) hypertension','59621000','1987-01-01','Active'),
    (24,'MRN1017','I10','Essential (primary) hypertension','59621000','1994-01-01','Active'),
    (25,'MRN1017','E78.5','Hyperlipidemia, unspecified','55822004','1994-01-01','Active'),
    (26,'MRN1018','I50.9','Heart failure, unspecified','84114007','2001-01-01','Active'),
    (27,'MRN1018','I10','Essential (primary) hypertension','59621000','2001-01-01','Active'),
    (28,'MRN1019','I48.91','Unspecified atrial fibrillation','49436004','2008-01-01','Active'),
    (29,'MRN1020','I25.10','Atherosclerotic heart disease of native coronary artery','53741008','2015-01-01','Active'),
    (30,'MRN1020','E78.5','Hyperlipidemia, unspecified','55822004','2015-01-01','Active'),
    (31,'MRN1021','F32.9','Major depressive disorder, single episode','370143000','2022-01-01','Active'),
    (32,'MRN1022','N18.3','Chronic kidney disease, stage 3','431857002','2020-01-01','Active'),
    (33,'MRN1022','I10','Essential (primary) hypertension','59621000','2020-01-01','Active'),
    (34,'MRN1023','E78.5','Hyperlipidemia, unspecified','55822004','2020-01-01','Active'),
    (35,'MRN1024','J44.9','Chronic obstructive pulmonary disease','13645005','1988-01-01','Active'),
    (36,'MRN1025','J45.909','Unspecified asthma, uncomplicated','195967001','1995-01-01','Active'),
    (37,'MRN1026','M06.9','Rheumatoid arthritis, unspecified','69896004','2002-01-01','Active'),
    (38,'MRN1027','K21.9','Gastro-esophageal reflux disease','235595009','2009-01-01','Active'),
    (39,'MRN1028','E03.9','Hypothyroidism, unspecified','40930008','2016-01-01','Active'),
    (40,'MRN1029','G40.909','Epilepsy, unspecified','84757009','2023-01-01','Active'),
    (41,'MRN1030','M54.5','Low back pain','279039007','2020-01-01','Active'),
    (42,'MRN1031','I10','Essential (primary) hypertension','59621000','2020-01-01','Active'),
    (43,'MRN1031','E78.5','Hyperlipidemia, unspecified','55822004','2020-01-01','Active'),
    (44,'MRN1032','E78.5','Hyperlipidemia, unspecified','55822004','1989-01-01','Active'),
    (45,'MRN1033','E11.9','Type 2 diabetes mellitus without complications','44054006','1996-01-01','Active'),
    (46,'MRN1034','E11.9','Type 2 diabetes mellitus without complications','44054006','2003-01-01','Active'),
    (47,'MRN1034','E78.5','Hyperlipidemia, unspecified','55822004','2003-01-01','Active'),
    (48,'MRN1035','E11.9','Type 2 diabetes mellitus without complications','44054006','2010-01-01','Active'),
    (49,'MRN1036','I10','Essential (primary) hypertension','59621000','2017-01-01','Active'),
    (50,'MRN1037','I10','Essential (primary) hypertension','59621000','2020-01-01','Active'),
    (51,'MRN1037','E78.5','Hyperlipidemia, unspecified','55822004','2020-01-01','Active'),
    (52,'MRN1038','I50.9','Heart failure, unspecified','84114007','2020-01-01','Active'),
    (53,'MRN1038','I10','Essential (primary) hypertension','59621000','2020-01-01','Active'),
    (54,'MRN1039','I48.91','Unspecified atrial fibrillation','49436004','2020-01-01','Active'),
    (55,'MRN1040','I25.10','Atherosclerotic heart disease of native coronary artery','53741008','1990-01-01','Active'),
    (56,'MRN1040','E78.5','Hyperlipidemia, unspecified','55822004','1990-01-01','Active'),
    (57,'MRN1041','F32.9','Major depressive disorder, single episode','370143000','1997-01-01','Active'),
    (58,'MRN1042','N18.3','Chronic kidney disease, stage 3','431857002','2004-01-01','Active'),
    (59,'MRN1042','I10','Essential (primary) hypertension','59621000','2004-01-01','Active'),
    (60,'MRN1043','E78.5','Hyperlipidemia, unspecified','55822004','2011-01-01','Active'),
    (61,'MRN1044','J44.9','Chronic obstructive pulmonary disease','13645005','2018-01-01','Active'),
    (62,'MRN1045','J45.909','Unspecified asthma, uncomplicated','195967001','2020-01-01','Active'),
    (63,'MRN1046','M06.9','Rheumatoid arthritis, unspecified','69896004','2020-01-01','Active'),
    (64,'MRN1047','K21.9','Gastro-esophageal reflux disease','235595009','2020-01-01','Active'),
    (65,'MRN1048','E03.9','Hypothyroidism, unspecified','40930008','1991-01-01','Active'),
    (66,'MRN1049','G40.909','Epilepsy, unspecified','84757009','1998-01-01','Active'),
    (67,'MRN1050','M54.5','Low back pain','279039007','2005-01-01','Active');

INSERT INTO VISIT VALUES
    ('V0013','MRN1013',101,1,'2025-08-08','Office','E11.9',123,77,77.1,7.8,'Completed'),
    ('V0014','MRN1014',101,1,'2025-03-21','Office','E11.9',126,79,78.8,7.9,'Completed'),
    ('V0015','MRN1015',101,1,'2025-10-07','Office','E11.9',129,81,80.5,8.0,'Completed'),
    ('V0016','MRN1016',103,3,'2025-05-20','Office','I10',132,83,82.2,NULL,'Completed'),
    ('V0017','MRN1017',103,3,'2025-12-06','Office','I10',135,85,83.9,NULL,'Completed'),
    ('V0018','MRN1018',102,2,'2025-07-19','Office','I50.9',138,87,85.6,NULL,'Completed'),
    ('V0019','MRN1019',102,2,'2025-02-05','Office','I48.91',141,89,87.3,NULL,'Completed'),
    ('V0020','MRN1020',102,2,'2025-09-18','Office','I25.10',144,91,89.0,NULL,'Completed'),
    ('V0021','MRN1021',106,6,'2025-04-04','Office','F32.9',147,72,90.7,NULL,'Completed'),
    ('V0022','MRN1022',105,5,'2025-11-17','Office','N18.3',150,74,92.4,NULL,'Completed'),
    ('V0023','MRN1023',104,4,'2025-06-03','Office','E78.5',119,76,94.1,NULL,'Completed'),
    ('V0024','MRN1024',107,7,'2025-01-16','Office','J44.9',122,78,95.8,NULL,'Completed'),
    ('V0025','MRN1025',107,7,'2025-08-02','Office','J45.909',125,80,97.5,NULL,'Completed'),
    ('V0026','MRN1026',108,8,'2025-03-15','Office','M06.9',128,82,99.2,NULL,'Completed'),
    ('V0027','MRN1027',109,9,'2025-10-01','Office','K21.9',131,84,100.9,NULL,'Completed'),
    ('V0028','MRN1028',103,3,'2025-05-14','Office','E03.9',134,86,102.6,NULL,'Completed'),
    ('V0029','MRN1029',110,10,'2025-12-27','Office','G40.909',137,88,104.3,NULL,'Completed'),
    ('V0030','MRN1030',111,11,'2025-07-13','Office','M54.5',140,90,106.0,NULL,'Completed'),
    ('V0031','MRN1031',104,4,'2025-02-26','Office','I10',143,92,107.7,NULL,'Completed'),
    ('V0032','MRN1032',112,12,'2025-09-12','Office','E78.5',146,73,109.4,NULL,'Completed'),
    ('V0033','MRN1033',101,1,'2025-04-25','Office','E11.9',149,75,56.1,6.8,'Completed'),
    ('V0034','MRN1034',101,1,'2025-11-11','Office','E11.9',118,77,57.8,6.9,'Completed'),
    ('V0035','MRN1035',101,1,'2025-06-24','Office','E11.9',121,79,59.5,7.0,'Completed'),
    ('V0036','MRN1036',103,3,'2025-01-10','Office','I10',124,81,61.2,NULL,'Completed'),
    ('V0037','MRN1037',103,3,'2025-08-23','Office','I10',127,83,62.9,NULL,'Completed'),
    ('V0038','MRN1038',102,2,'2025-03-09','Office','I50.9',130,85,64.6,NULL,'Completed'),
    ('V0039','MRN1039',102,2,'2025-10-22','Office','I48.91',133,87,66.3,NULL,'Completed'),
    ('V0040','MRN1040',102,2,'2025-05-08','Office','I25.10',136,89,68.0,NULL,'Completed'),
    ('V0041','MRN1041',106,6,'2025-12-21','Office','F32.9',139,91,69.7,NULL,'Completed'),
    ('V0042','MRN1042',105,5,'2025-07-07','Office','N18.3',142,72,71.4,NULL,'Completed'),
    ('V0043','MRN1043',104,4,'2025-02-20','Office','E78.5',145,74,73.1,NULL,'Completed'),
    ('V0044','MRN1044',107,7,'2025-09-06','Office','J44.9',148,76,74.8,NULL,'Completed'),
    ('V0045','MRN1045',107,7,'2025-04-19','Office','J45.909',151,78,76.5,NULL,'Completed'),
    ('V0046','MRN1046',108,8,'2025-11-05','Office','M06.9',120,80,78.2,NULL,'Completed'),
    ('V0047','MRN1047',109,9,'2025-06-18','Office','K21.9',123,82,79.9,NULL,'Completed'),
    ('V0048','MRN1048',103,3,'2025-01-04','Office','E03.9',126,84,81.6,NULL,'Completed'),
    ('V0049','MRN1049',110,10,'2025-08-17','Office','G40.909',129,86,83.3,NULL,'Completed'),
    ('V0050','MRN1050',111,11,'2025-03-03','Office','M54.5',132,88,85.0,NULL,'Completed');

INSERT INTO MEDICATION VALUES
    (20,'MRN1013',101,'2025-08-08','Metformin 500 mg','860975','1 tab PO BID',60,3),
    (21,'MRN1014',101,'2025-03-21','Metformin 500 mg','860975','1 tab PO BID',60,3),
    (22,'MRN1014',101,'2025-03-21','Atorvastatin 20 mg',NULL,'1 tab PO daily',30,3),
    (23,'MRN1015',101,'2025-10-07','Metformin 500 mg','860975','1 tab PO BID',60,3),
    (24,'MRN1015',101,'2025-10-07','Insulin Glargine','261551','20 units SC nightly',1,5),
    (25,'MRN1016',103,'2025-05-20','Lisinopril 10 mg','314076','1 tab PO daily',30,5),
    (26,'MRN1017',103,'2025-12-06','Amlodipine 5 mg','197361','1 tab PO daily',30,3),
    (27,'MRN1017',103,'2025-12-06','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (28,'MRN1018',102,'2025-07-19','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',60,3),
    (29,'MRN1018',102,'2025-07-19','Furosemide 40 mg','310429','1 tab PO daily',30,3),
    (30,'MRN1018',102,'2025-07-19','Lisinopril 10 mg','314076','1 tab PO daily',30,5),
    (31,'MRN1019',102,'2025-02-05','Warfarin 5 mg','855334','1 tab PO daily',30,3),
    (32,'MRN1019',102,'2025-02-05','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',60,3),
    (33,'MRN1020',102,'2025-09-18','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (34,'MRN1020',102,'2025-09-18','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',60,3),
    (35,'MRN1021',106,'2025-04-04','Sertraline 50 mg',NULL,'1 tab PO daily',30,3),
    (36,'MRN1022',105,'2025-11-17','Losartan 50 mg','979485','1 tab PO daily',30,3),
    (37,'MRN1023',104,'2025-06-03','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (38,'MRN1024',107,'2025-01-16','Albuterol HFA','745679','2 puffs INH q6h PRN',1,3),
    (39,'MRN1025',107,'2025-08-02','Albuterol HFA','745679','2 puffs INH q6h PRN',1,3),
    (40,'MRN1026',108,'2025-03-15','Gabapentin 300 mg','310431','1 cap PO TID',90,3),
    (41,'MRN1027',109,'2025-10-01','Omeprazole 20 mg','198051','1 cap PO daily',30,3),
    (42,'MRN1028',103,'2025-05-14','Levothyroxine 50 mcg',NULL,'1 tab PO daily',30,5),
    (43,'MRN1029',110,'2025-12-27','Gabapentin 300 mg','310431','1 cap PO TID',90,3),
    (44,'MRN1030',111,'2025-07-13','Gabapentin 300 mg','310431','1 cap PO TID',90,3),
    (45,'MRN1031',104,'2025-02-26','Lisinopril 10 mg','314076','1 tab PO daily',30,5),
    (46,'MRN1031',104,'2025-02-26','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (47,'MRN1032',112,'2025-09-12','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (48,'MRN1033',101,'2025-04-25','Metformin 500 mg','860975','1 tab PO BID',60,3),
    (49,'MRN1034',101,'2025-11-11','Metformin 500 mg','860975','1 tab PO BID',60,3),
    (50,'MRN1034',101,'2025-11-11','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (51,'MRN1035',101,'2025-06-24','Metformin 500 mg','860975','1 tab PO BID',60,3),
    (52,'MRN1035',101,'2025-06-24','Insulin Glargine',NULL,'20 units SC nightly',1,5),
    (53,'MRN1036',103,'2025-01-10','Lisinopril 10 mg','314076','1 tab PO daily',30,5),
    (54,'MRN1037',103,'2025-08-23','Amlodipine 5 mg','197361','1 tab PO daily',30,3),
    (55,'MRN1037',103,'2025-08-23','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (56,'MRN1038',102,'2025-03-09','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',60,3),
    (57,'MRN1038',102,'2025-03-09','Furosemide 40 mg','310429','1 tab PO daily',30,3),
    (58,'MRN1038',102,'2025-03-09','Lisinopril 10 mg','314076','1 tab PO daily',30,5),
    (59,'MRN1039',102,'2025-10-22','Warfarin 5 mg','855334','1 tab PO daily',30,3),
    (60,'MRN1039',102,'2025-10-22','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',60,3),
    (61,'MRN1040',102,'2025-05-08','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (62,'MRN1040',102,'2025-05-08','Metoprolol Tartrate 50 mg','866924','1 tab PO BID',60,3),
    (63,'MRN1041',106,'2025-12-21','Sertraline 50 mg','312940','1 tab PO daily',30,3),
    (64,'MRN1042',105,'2025-07-07','Losartan 50 mg',NULL,'1 tab PO daily',30,3),
    (65,'MRN1043',104,'2025-02-20','Atorvastatin 20 mg','617312','1 tab PO daily',30,3),
    (66,'MRN1044',107,'2025-09-06','Albuterol HFA','745679','2 puffs INH q6h PRN',1,3),
    (67,'MRN1045',107,'2025-04-19','Albuterol HFA','745679','2 puffs INH q6h PRN',1,3),
    (68,'MRN1046',108,'2025-11-05','Gabapentin 300 mg','310431','1 cap PO TID',90,3),
    (69,'MRN1047',109,'2025-06-18','Omeprazole 20 mg','198051','1 cap PO daily',30,3),
    (70,'MRN1048',103,'2025-01-04','Levothyroxine 50 mcg','966155','1 tab PO daily',30,5),
    (71,'MRN1049',110,'2025-08-17','Gabapentin 300 mg',NULL,'1 cap PO TID',90,3),
    (72,'MRN1050',111,'2025-03-03','Gabapentin 300 mg','310431','1 cap PO TID',90,3);

INSERT INTO LAB_RESULTS VALUES
    (10,'MRN1013','2025-08-08',189,7.8,133,0.9,88),
    (11,'MRN1014','2025-03-21',192,7.9,134,0.9,89),
    (12,'MRN1015','2025-10-07',195,8.0,135,0.9,90),
    (13,'MRN1017','2025-12-06',92,NULL,164,0.9,90),
    (14,'MRN1020','2025-09-18',95,NULL,170,0.9,90),
    (15,'MRN1022','2025-11-17',110,NULL,137,2.4,52),
    (16,'MRN1023','2025-06-03',98,NULL,176,0.9,90),
    (17,'MRN1031','2025-02-26',91,NULL,132,0.9,90),
    (18,'MRN1032','2025-09-12',92,NULL,134,0.9,90),
    (19,'MRN1033','2025-04-25',179,6.8,153,0.9,88),
    (20,'MRN1034','2025-11-11',182,6.9,154,0.9,89),
    (21,'MRN1035','2025-06-24',185,7.0,155,0.9,90),
    (22,'MRN1037','2025-08-23',97,NULL,144,0.9,90),
    (23,'MRN1040','2025-05-08',100,NULL,150,0.9,90),
    (24,'MRN1042','2025-07-07',106,NULL,127,2.0,47),
    (25,'MRN1043','2025-02-20',103,NULL,156,0.9,90);

-- Quick sanity check
SELECT 'CLINICAL_EMR loaded' AS status,
       (SELECT COUNT(*) FROM PATIENT_MASTER) AS patients,
       (SELECT COUNT(*) FROM VISIT)          AS visits,
       (SELECT COUNT(*) FROM MEDICATION)     AS med_orders;
