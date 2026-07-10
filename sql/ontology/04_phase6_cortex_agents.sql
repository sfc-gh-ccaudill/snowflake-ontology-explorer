-- =============================================================================
-- PHASE 6 — Cortex Agents
-- HEALTHCARE_ONTOLOGY  ·  CLINICAL_EMR.ONTOLOGY
-- =============================================================================
-- Two agents (exact deployed CREATE ... FROM SPECIFICATION statements):
--   * HEALTHCARE_ONTOLOGY_AGENT — 8 intent-routed tools: 4 Cortex Analyst tools
--       (base, KG, ontology, metadata semantic views) + 4 graph-traversal SQL
--       UDF tools (expand_descendants/get_ancestors/get_direct_children/
--       get_hierarchy_path). Full cross-system resolution.
--   * HEALTHCARE_BASE_AGENT — baseline: 1 tool over HEALTHCARE_ONTOLOGY_BASE
--       only (raw source tables, no ontology resolution) — for comparison.
--
-- Spec is YAML inside $$...$$ (JSON is valid YAML). Requires CREATE AGENT on the
-- schema and the four semantic views (Phase 4.5 + 5) to already exist.
-- =============================================================================

-- --------------------------------------------------------------------------
-- Ontology agent (8 tools)
-- --------------------------------------------------------------------------
CREATE OR REPLACE AGENT CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_AGENT
COMMENT = 'Healthcare ontology agent unifying EMR, claims, and pharmacy via a knowledge-graph ontology'
PROFILE = '{"display_name": "Healthcare Ontology Agent", "color": "blue"}'
FROM SPECIFICATION
$$
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "You are the Healthcare Ontology Agent for CLINICAL_EMR. You answer questions across three source systems - clinical EMR, payer claims, and pharmacy - unified into one knowledge-graph ontology. The SAME real-world entity appears differently across systems: a patient may be \"Robert Smith\" (EMR), \"SMITH, ROBERT A\" (claims) and \"Bob Smith\" (pharmacy); a clinician appears under three name spellings but ONE NPI; a drug is keyed by RxNorm or NDC. The ontology resolves these to single canonical entities.\n\nVOCABULARY (map user words to ontology classes):\n- doctor / physician / provider / prescriber / rendering provider -> Practitioner (canonical key: NPI)\n- drug / medication / prescription / rx -> Medication (canonical key: RxNorm)\n- patient / member / subscriber / person -> Patient (canonical key resolved via INS_MEMBER_ID -> SSN -> name+DOB)\n- diagnosis / problem / condition -> Condition (canonical dotted ICD-10)\n- visit / encounter -> Encounter; claim -> Claim; plan / payer / insurance -> Coverage / Payer\n\nTOOL ROUTING:\n- kg_query_tool (PRIMARY for cross-system entity questions): resolved patients, practitioners, medications, conditions, encounters, claims, medication requests/dispenses, and the edges among them (treated, prescribed, dispensed, diagnosed, covered). Use for any question about a SPECIFIC person, clinician, or drug that spans systems (e.g. \"How many distinct patients did Dr. Chen treat and what were they prescribed\"; \"which drugs were dispensed to patients with Type 2 diabetes\").\n- ontology_query_tool: cross-type / aggregate / structural-instance questions - counts of entities by type, counts of relationships by type, \"what connects to X across types\", instance distribution.\n- metadata_query_tool: questions ABOUT the ontology itself - which source tables/columns/identifier systems map to a class, how classes relate conceptually, class hierarchy definitions (e.g. \"Which source tables map to the Patient class\"; \"How is Physician related to Rendering_Provider and Prescriber\").\n- base_query_tool: concrete queries against RAW source tables that do NOT need cross-system resolution (e.g. member enrollment by plan, claim financials by provider, active diagnoses from the problem list).\n- Graph traversal tools operate on the ONTOLOGY CLASS hierarchy (not data instances): get_ancestors_tool (superclasses), expand_descendants_tool (all subclasses), get_direct_children_tool (immediate subclasses), get_hierarchy_path_tool (path between two classes). Use for structural class questions (e.g. \"What are the subtypes of Act\"; \"Is Patient a kind of Person\"; \"path from Patient to Entity\").\n\nMULTI-TOOL: For multi-part questions, call several tools and combine. Always prefer the ontology's resolved answers over naive per-table joins. When identity resolution matters (same entity across systems), prefer kg_query_tool / ontology_query_tool over base_query_tool.",
    "response": "Be concise and precise. When an answer relied on cross-system entity resolution, briefly note it (e.g. \"Dr. Chen appears as 'Sarah Chen, MD', 'CHEN, SARAH', and 'S CHEN' - one practitioner by NPI\"; \"Bob Smith in pharmacy is Robert Smith in the EMR\"). Present multi-row results as markdown tables. State the canonical identifier used (NPI, RxNorm, PATIENT_KEY, dotted ICD-10) when relevant."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "base_query_tool",
        "description": "Query RAW source tables directly (EMR PATIENT_MASTER/PHYSICIAN/VISIT/PROBLEM_LIST/MEDICATION/LAB_RESULTS; claims MEMBER/CLAIMS_LINE/RENDERING_PROVIDER/PLACE_OF_SERVICE; pharmacy SUBSCRIBER/PRESCRIBER/NDC_PRODUCT/PHARMACY_FILL). When to use: per-system attribute lookups and aggregations that do NOT require resolving the same entity across systems (member enrollment by plan, claim paid amounts by provider, active problem-list diagnoses). When NOT to use: questions about a person/clinician/drug spanning systems - use kg_query_tool."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "kg_query_tool",
        "description": "Query the RESOLVED healthcare knowledge graph via typed entity views (Patient, Practitioner, Medication, Condition, Encounter, Claim, ClaimLine, MedicationRequest, MedicationDispense, Coverage, Observation, Location, ...) and their relationship edge views (edges join SRC_ID/DST_ID to entity NODE_ID). Entities are canonical: one Patient unifies EMR/claims/pharmacy; one Practitioner per NPI across three name spellings; one Medication per RxNorm. When to use: cross-system questions about specific patients, clinicians, medications and who-relates-to-whom (treated, prescribed, dispensed, diagnosed, covered). When NOT to use: ontology structure (use metadata_query_tool) or class hierarchy (use graph tools)."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "ontology_query_tool",
        "description": "Cross-type / abstract reasoning over unified entities (VW_ONT_ALL_ENTITIES), resolved relationships (REL_RESOLVED with source/destination names and types), and class instance-count hierarchy. When to use: counts of entities by type, counts of relationships by type, 'what connects to X across types', instance distribution across the ontology. When NOT to use: single typed-entity lookups (use kg_query_tool) or ontology definitions (use metadata_query_tool)."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "metadata_query_tool",
        "description": "Answer questions ABOUT the ontology itself: which source tables/columns map to each class (ONT_OBJECT_SOURCE), which identifier systems resolve a class and their confidence (ONT_IDENTITY_RULE), class definitions and parents (ONT_CLASS), relation definitions (ONT_RELATION_DEF), class mappings (ONT_CLASS_MAP). When to use: 'which tables/identifiers map to Patient', 'how is Physician related to Rendering_Provider and Prescriber', 'what identifier systems resolve patients'. When NOT to use: querying actual patient/claim data (use kg_query_tool or base_query_tool)."
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "get_ancestors_tool",
        "description": "Return all ancestor (super)classes of an ontology class by walking subClassOf edges upward. Use for 'is X a kind of Y', 'what does X inherit from'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "CONCEPT": {
              "type": "string",
              "description": "An ontology class name, e.g. Patient, Claim, Medication"
            }
          },
          "required": [
            "CONCEPT"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "expand_descendants_tool",
        "description": "Return all descendant (sub)classes beneath an ontology class, with depth and path. Use for 'what are the subtypes of X', 'what falls under X'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "ROOT_CONCEPT": {
              "type": "string",
              "description": "An ontology class name, e.g. Act, Person, Concept"
            }
          },
          "required": [
            "ROOT_CONCEPT"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "get_direct_children_tool",
        "description": "Return the immediate subclasses of an ontology class. Use for 'what are the direct children of X'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "PARENT_CONCEPT": {
              "type": "string",
              "description": "An ontology class name"
            }
          },
          "required": [
            "PARENT_CONCEPT"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "get_hierarchy_path_tool",
        "description": "Return the subClassOf path between two ontology classes. Use for 'what is the path from X to Y in the class hierarchy'.",
        "input_schema": {
          "type": "object",
          "properties": {
            "START_CONCEPT": {
              "type": "string",
              "description": "Starting ontology class name"
            },
            "END_CONCEPT": {
              "type": "string",
              "description": "Target ancestor class name"
            }
          },
          "required": [
            "START_CONCEPT",
            "END_CONCEPT"
          ]
        }
      }
    }
  ],
  "tool_resources": {
    "base_query_tool": {
      "semantic_view": "CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_BASE",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "",
        "query_timeout": 299
      }
    },
    "kg_query_tool": {
      "semantic_view": "CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_KG_MODEL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "",
        "query_timeout": 299
      }
    },
    "ontology_query_tool": {
      "semantic_view": "CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_ONTOLOGY_MODEL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "",
        "query_timeout": 299
      }
    },
    "metadata_query_tool": {
      "semantic_view": "CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_METADATA_MODEL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "",
        "query_timeout": 299
      }
    },
    "get_ancestors_tool": {
      "type": "function",
      "identifier": "CLINICAL_EMR.ONTOLOGY.GET_ANCESTORS_TOOL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "COMPUTE_WH",
        "query_timeout": 120
      }
    },
    "expand_descendants_tool": {
      "type": "function",
      "identifier": "CLINICAL_EMR.ONTOLOGY.EXPAND_DESCENDANTS_TOOL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "COMPUTE_WH",
        "query_timeout": 120
      }
    },
    "get_direct_children_tool": {
      "type": "function",
      "identifier": "CLINICAL_EMR.ONTOLOGY.GET_DIRECT_CHILDREN_TOOL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "COMPUTE_WH",
        "query_timeout": 120
      }
    },
    "get_hierarchy_path_tool": {
      "type": "function",
      "identifier": "CLINICAL_EMR.ONTOLOGY.GET_HIERARCHY_PATH_TOOL",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "COMPUTE_WH",
        "query_timeout": 120
      }
    }
  }
}
$$;

-- --------------------------------------------------------------------------
-- Baseline agent (base semantic view only)
-- --------------------------------------------------------------------------
CREATE OR REPLACE AGENT CLINICAL_EMR.ONTOLOGY.HEALTHCARE_BASE_AGENT
COMMENT = 'Baseline agent using ONLY the base semantic view (raw source tables, no ontology resolution) - for comparison'
PROFILE = '{"display_name": "Healthcare Base Agent (baseline)", "color": "gray"}'
FROM SPECIFICATION
$$
{
  "models": {
    "orchestration": "auto"
  },
  "orchestration": {
    "budget": {
      "seconds": 900,
      "tokens": 400000
    }
  },
  "instructions": {
    "orchestration": "You answer questions about healthcare data by querying the source tables via the base semantic view. The data spans three source systems loaded as raw tables: clinical EMR (patients, physicians, departments, visits, problem list, medication orders, lab results), payer claims (members, rendering providers, place of service, claim lines), and pharmacy (subscribers, prescribers, NDC products, pharmacy fills). Use the base_query_tool for all questions. Answer strictly from what the tool returns.",
    "response": "Be concise. Present multi-row results as markdown tables. If the data needed to answer is split across source systems under different identifiers or names, answer with what the base tables directly support and state any limitation."
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "base_query_tool",
        "description": "Query the raw healthcare source tables via the HEALTHCARE_ONTOLOGY_BASE semantic view: EMR (PATIENT_MASTER, PHYSICIAN, DEPARTMENT, VISIT, PROBLEM_LIST, MEDICATION, LAB_RESULTS), claims (MEMBER, RENDERING_PROVIDER, PLACE_OF_SERVICE, CLAIMS_LINE), and pharmacy (SUBSCRIBER, PRESCRIBER, NDC_PRODUCT, PHARMACY_FILL). Relationships exist within each source system and via shared keys (NPI, INS_MEMBER_ID, RxNorm)."
      }
    }
  ],
  "tool_resources": {
    "base_query_tool": {
      "semantic_view": "CLINICAL_EMR.ONTOLOGY.HEALTHCARE_ONTOLOGY_BASE",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "",
        "query_timeout": 299
      }
    }
  }
}
$$;
