/**
 * Instance-level knowledge graph builder.
 *
 * Unlike ontology.js (which describes the *classes*), this assembles a graph of
 * the ACTUAL DATA: real patients resolved and stitched across the three source
 * systems (EHR + Claims + Pharmacy) into one connected graph.
 *
 * Entity resolution keys (verified against the sample data):
 *   - EHR <-> Claims : PATIENT_MASTER.INS_MEMBER_ID = MEMBER.MEMBER_ID = CLAIMS_LINE.MEMBER_ID
 *   - EHR <-> Pharmacy: SUBSCRIBER matched on SSN, else DOB (DOB is unique across
 *     all patients, so it covers the null-SSN pharmacy rows) -> RX_MEMBER_ID
 *   - Practitioner    : NPI (universal across all three systems)
 *   - Medication      : RxNorm; the NDC<->RxNorm crosswalk resolves EMR orders
 *     even when their RxNorm is NULL
 *
 * "Concept" classes (Practitioner, Medication, Procedure, Condition, Location)
 * are SHARED hub nodes keyed by their code, so different patients connect
 * through the same doctor / drug / diagnosis — showing the value of unification.
 */

import { query } from './snowflake.js';
import { GROUPS } from './ontology.js';
import { EHR, CLAIMS, RX } from './dbconfig.js';

// class -> ontology group (drives node colour, reusing the ontology palette)
const CLASS_GROUP = {
    Patient: 'person',
    Practitioner: 'person',
    RelatedPerson: 'person',
    Address: 'place',
    Location: 'place',
    Encounter: 'clinical',
    Condition: 'clinical',
    Medication: 'medication',
    MedicationRequest: 'medication',
    MedicationDispense: 'medication',
    Coverage: 'financial',
    Claim: 'financial',
    Procedure: 'financial',
};
const colorFor = (cls) => GROUPS[CLASS_GROUP[cls]]?.color || '#8595a6';

// Canonicalize an ICD-10 code: strip the decimal so E11.9 (EMR) == E119 (claims).
const canonIcd = (c) => String(c || '').replace('.', '').toUpperCase().trim();

// Build a safe SQL IN-list from an array of string values.
const inList = (arr) => {
    const vals = [...new Set(arr.filter((v) => v != null && v !== ''))];
    if (!vals.length) return `''`;
    return vals.map((v) => `'${String(v).replace(/'/g, "''")}'`).join(',');
};

/**
 * Build the instance graph for the first `limit` patients (ordered by MRN).
 * Returns { nodes, links, groups, stats }.
 */
export async function getKnowledgeGraph(limit) {
    const n = Math.max(1, Math.min(Number(limit) || 3, 50));

    // 1. Anchor patients (ordered by MRN so presets are stable/repeatable).
    const patients = await query(
        `select MRN, SSN, FIRST_NAME, MIDDLE_NAME, LAST_NAME, DOB, SEX,
            ADDR_LINE1, CITY, STATE, ZIP,
            PCP_NPI, INS_PAYER_NAME, INS_MEMBER_ID, INS_GROUP,
            KIN_NAME, KIN_RELATION
       from ${EHR}.PATIENT_MASTER
      order by MRN
      limit ${n}`
    );

    const mrns = patients.map((p) => p.MRN);
    const memberIds = patients.map((p) => p.INS_MEMBER_ID);
    const mrnList = inList(mrns);
    const memberList = inList(memberIds);

    // 2. Reference / child data (providers + departments are small — fetch all).
    const [physicians, departments, subscribers, visits, problems, medOrders, claims, ndc] =
        await Promise.all([
            query(`select PHYSICIAN_ID, NPI, FULL_NAME, SPECIALTY from ${EHR}.PHYSICIAN`),
            query(`select DEPT_ID, DEPT_NAME, FACILITY_NAME from ${EHR}.DEPARTMENT`),
            query(`select RX_MEMBER_ID, PATIENT_SSN, PATIENT_NAME, DOB from ${RX}.SUBSCRIBER`),
            query(
                `select VISIT_ID, MRN, PHYSICIAN_ID, DEPT_ID, VISIT_DATE, VISIT_TYPE, PRIMARY_ICD10
           from ${EHR}.VISIT where MRN in (${mrnList})`
            ),
            query(
                `select PROBLEM_ID, MRN, ICD10_CODE, ICD10_DESC, STATUS
           from ${EHR}.PROBLEM_LIST where MRN in (${mrnList})`
            ),
            query(
                `select MED_ORDER_ID, MRN, PHYSICIAN_ID, ORDER_DATE, DRUG_NAME, RXNORM_CODE
           from ${EHR}.MEDICATION where MRN in (${mrnList})`
            ),
            query(
                `select CLAIM_ID, LINE_NO, MEMBER_ID, RENDERING_NPI, SERVICE_DATE,
                DX_CODE, CPT_CODE, CPT_DESC, CLAIM_STATUS
           from ${CLAIMS}.CLAIMS_LINE where MEMBER_ID in (${memberList})`
            ),
            query(`select NDC, RXNORM_CODE, BRAND_NAME, GENERIC_NAME from ${RX}.NDC_PRODUCT`),
        ]);

    // ---- lookup maps --------------------------------------------------------
    const physById = new Map(physicians.map((p) => [String(p.PHYSICIAN_ID), p]));
    const physByNpi = new Map(physicians.map((p) => [String(p.NPI), p]));
    const deptById = new Map(departments.map((d) => [String(d.DEPT_ID), d]));

    // NDC -> RxNorm, and generic-name -> RxNorm (for null-RxNorm EMR orders).
    const rxByNdc = new Map();
    const rxByGeneric = new Map();
    const drugByRx = new Map();
    for (const p of ndc) {
        rxByNdc.set(p.NDC, p.RXNORM_CODE);
        if (p.GENERIC_NAME) rxByGeneric.set(p.GENERIC_NAME.toUpperCase(), p.RXNORM_CODE);
        if (!drugByRx.has(p.RXNORM_CODE))
            drugByRx.set(p.RXNORM_CODE, { generic: p.GENERIC_NAME, brand: p.BRAND_NAME });
    }
    // Resolve an EMR order's drug to a canonical RxNorm even when RXNORM_CODE is null.
    const resolveRx = (rxnorm, drugName) => {
        if (rxnorm) return rxnorm;
        const first = String(drugName || '').split(/\s+/)[0].toUpperCase();
        for (const [generic, rx] of rxByGeneric) if (generic.startsWith(first)) return rx;
        return null;
    };

    // Resolve each patient to a pharmacy RX_MEMBER_ID via SSN, else DOB.
    const subBySsn = new Map(subscribers.filter((s) => s.PATIENT_SSN).map((s) => [s.PATIENT_SSN, s]));
    const subByDob = new Map(subscribers.map((s) => [String(s.DOB), s]));
    const rxMemberByMrn = new Map();
    for (const p of patients) {
        const sub = (p.SSN && subBySsn.get(p.SSN)) || subByDob.get(String(p.DOB));
        if (sub) rxMemberByMrn.set(p.MRN, sub.RX_MEMBER_ID);
    }
    const rxMemberToMrn = new Map([...rxMemberByMrn].map(([mrn, rx]) => [rx, mrn]));

    // Now scope pharmacy fills to the resolved rx-member ids.
    const rxMemberList = inList([...rxMemberByMrn.values()]);
    const fillRows = await query(
        `select FILL_ID, RX_MEMBER_ID, PRESCRIBER_ID, NDC, DRUG_DESC,
            WRITTEN_DATE, FILL_DATE, FILL_STATUS
       from ${RX}.PHARMACY_FILL where RX_MEMBER_ID in (${rxMemberList})`
    );

    // ---- graph assembly -----------------------------------------------------
    const nodes = new Map();
    const links = [];
    const addNode = (id, cls, label, detail) => {
        if (!nodes.has(id)) nodes.set(id, { id, cls, label, detail, group: CLASS_GROUP[cls], color: colorFor(cls) });
        return id;
    };
    const linkKeys = new Set();
    const addLink = (source, target, label) => {
        if (!source || !target) return;
        const k = `${source}->${target}:${label}`;
        if (linkKeys.has(k)) return;
        linkKeys.add(k);
        links.push({ source, target, label });
    };

    // Patients (+ their per-patient satellites).
    for (const p of patients) {
        const fullName = [p.FIRST_NAME, p.LAST_NAME].filter(Boolean).join(' ');
        const pid = addNode(`pat:${p.MRN}`, 'Patient', fullName, `MRN ${p.MRN} · resolved across all 3 systems`);

        if (p.INS_PAYER_NAME) {
            const cid = addNode(`cov:${p.MRN}`, 'Coverage', p.INS_PAYER_NAME, `Member ${p.INS_MEMBER_ID} · ${p.INS_GROUP || ''}`);
            addLink(pid, cid, 'has coverage');
        }
        if (p.ADDR_LINE1) {
            const aid = addNode(`addr:${p.MRN}`, 'Address', `${p.ADDR_LINE1}`, `${p.CITY}, ${p.STATE} ${p.ZIP}`);
            addLink(pid, aid, 'has address');
        }
        if (p.KIN_NAME) {
            const kid = addNode(`kin:${p.MRN}`, 'RelatedPerson', p.KIN_NAME, p.KIN_RELATION || 'next of kin');
            addLink(pid, kid, 'related to');
        }
    }

    // Encounters (VISIT) -> Practitioner, Location, primary Condition.
    for (const v of visits) {
        const pid = `pat:${v.MRN}`;
        const eid = addNode(`enc:${v.VISIT_ID}`, 'Encounter', `${v.VISIT_TYPE || 'Visit'} ${fmtDate(v.VISIT_DATE)}`, `Visit ${v.VISIT_ID}`);
        addLink(pid, eid, 'subject of');

        const phys = physById.get(String(v.PHYSICIAN_ID));
        if (phys) {
            const prov = addNode(`prov:${phys.NPI}`, 'Practitioner', phys.FULL_NAME, `NPI ${phys.NPI} · ${phys.SPECIALTY || ''}`);
            addLink(eid, prov, 'performed by');
        }
        const dept = deptById.get(String(v.DEPT_ID));
        if (dept) {
            const loc = addNode(`loc:${v.DEPT_ID}`, 'Location', dept.DEPT_NAME, dept.FACILITY_NAME);
            addLink(eid, loc, 'at');
        }
        if (v.PRIMARY_ICD10) {
            const code = canonIcd(v.PRIMARY_ICD10);
            const cid = addNode(`cond:${code}`, 'Condition', code, 'diagnosis code');
            addLink(eid, cid, 'has diagnosis');
        }
    }

    // Problem list -> shared Condition hubs (patient-level).
    for (const pr of problems) {
        const code = canonIcd(pr.ICD10_CODE);
        const cid = addNode(`cond:${code}`, 'Condition', code, pr.ICD10_DESC || 'diagnosis code');
        addLink(`pat:${pr.MRN}`, cid, 'has condition');
    }

    // Claims (grouped) -> Procedure, Condition, Practitioner, Coverage.
    const memberToMrn = new Map(patients.map((p) => [p.INS_MEMBER_ID, p.MRN]));
    for (const c of claims) {
        const mrn = memberToMrn.get(c.MEMBER_ID);
        if (!mrn) continue;
        const clmId = addNode(`clm:${c.CLAIM_ID}`, 'Claim', c.CLAIM_ID, `${c.CLAIM_STATUS || ''} · ${fmtDate(c.SERVICE_DATE)}`);
        addLink(`pat:${mrn}`, clmId, 'subject of');

        if (c.CPT_CODE) {
            const proc = addNode(`proc:${c.CPT_CODE}`, 'Procedure', c.CPT_CODE, c.CPT_DESC || 'procedure');
            addLink(clmId, proc, 'has procedure');
        }
        if (c.DX_CODE) {
            const code = canonIcd(c.DX_CODE);
            const cid = addNode(`cond:${code}`, 'Condition', code, 'diagnosis code');
            addLink(clmId, cid, 'has diagnosis');
        }
        const prov = physByNpi.get(String(c.RENDERING_NPI));
        if (prov) {
            const provId = addNode(`prov:${prov.NPI}`, 'Practitioner', prov.FULL_NAME, `NPI ${prov.NPI} · ${prov.SPECIALTY || ''}`);
            addLink(clmId, provId, 'rendered by');
        }
        if (nodes.has(`cov:${mrn}`)) addLink(clmId, `cov:${mrn}`, 'covered by');
    }

    // Medication requests (EMR orders) -> Practitioner, Medication (RxNorm).
    const orderIndex = new Map(); // `${mrn}|${npi}|${rx}` -> requestNodeId (to match fills)
    for (const m of medOrders) {
        const rx = resolveRx(m.RXNORM_CODE, m.DRUG_NAME);
        const reqId = addNode(`mreq:${m.MED_ORDER_ID}`, 'MedicationRequest', m.DRUG_NAME, `ordered ${fmtDate(m.ORDER_DATE)}`);
        addLink(`pat:${m.MRN}`, reqId, 'subject of');

        const phys = physById.get(String(m.PHYSICIAN_ID));
        if (phys) {
            const prov = addNode(`prov:${phys.NPI}`, 'Practitioner', phys.FULL_NAME, `NPI ${phys.NPI} · ${phys.SPECIALTY || ''}`);
            addLink(reqId, prov, 'prescribed by');
            if (rx) orderIndex.set(`${m.MRN}|${phys.NPI}|${rx}`, reqId);
        }
        if (rx) {
            const drug = drugByRx.get(rx);
            const medId = addNode(`med:${rx}`, 'Medication', drug?.generic || m.DRUG_NAME, `RxNorm ${rx}${drug?.brand ? ` · ${drug.brand}` : ''}`);
            addLink(reqId, medId, 'of drug');
        }
    }

    // Pharmacy fills (dispenses) -> Medication (NDC->RxNorm), Practitioner, fulfilled-by request.
    for (const f of fillRows) {
        const mrn = rxMemberToMrn.get(f.RX_MEMBER_ID);
        if (!mrn) continue;
        const disId = addNode(`mdis:${f.FILL_ID}`, 'MedicationDispense', f.DRUG_DESC, `${f.FILL_STATUS || ''} · filled ${fmtDate(f.FILL_DATE)}`);
        addLink(`pat:${mrn}`, disId, 'subject of');

        const rx = rxByNdc.get(f.NDC);
        if (rx) {
            const drug = drugByRx.get(rx);
            const medId = addNode(`med:${rx}`, 'Medication', drug?.generic || f.DRUG_DESC, `RxNorm ${rx}${drug?.brand ? ` · ${drug.brand}` : ''}`);
            addLink(disId, medId, 'of drug');
            // Link back to the originating order (fulfilled by) when we can match it.
            const reqId = orderIndex.get(`${mrn}|${f.PRESCRIBER_ID}|${rx}`);
            if (reqId) addLink(reqId, disId, 'fulfilled by');
        }
        const prov = physByNpi.get(String(f.PRESCRIBER_ID));
        if (prov) {
            const provId = addNode(`prov:${prov.NPI}`, 'Practitioner', prov.FULL_NAME, `NPI ${prov.NPI} · ${prov.SPECIALTY || ''}`);
            addLink(disId, provId, 'prescribed by');
        }
    }

    // Degree for node sizing.
    const degree = new Map();
    for (const l of links) {
        degree.set(l.source, (degree.get(l.source) || 0) + 1);
        degree.set(l.target, (degree.get(l.target) || 0) + 1);
    }
    const nodeArr = [...nodes.values()].map((nd) => ({ ...nd, degree: degree.get(nd.id) || 0 }));

    return {
        nodes: nodeArr,
        links,
        groups: GROUPS,
        stats: { patients: n, nodes: nodeArr.length, links: links.length },
    };
}

function fmtDate(d) {
    if (!d) return '';
    const s = typeof d === 'string' ? d : new Date(d).toISOString();
    return s.slice(0, 10);
}
