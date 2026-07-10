#!/usr/bin/env perl
# ---------------------------------------------------------------------------
# render.pl — parameterize the demo SQL.
#
# Reads one SQL file (path as $1) and writes it to stdout with the demo's
# default database / schema / warehouse names replaced by the values from the
# environment (populated by deploy.sh from config.env).
#
# Design: substitutions run from most-specific to least-specific so the dotted
# forms are consumed before the bare database DDL and quoted-literal forms.
#
# INVARIANT (checked by deploy.sh --check): with all env vars unset — i.e. the
# defaults below — the output is byte-for-byte identical to the input. Renaming
# is therefore always a superset of "do nothing", never a rewrite.
# ---------------------------------------------------------------------------
use strict;
use warnings;

my %v = (
    EMR_DB          => $ENV{EMR_DB}          // 'CLINICAL_EMR',
    EMR_SCHEMA      => $ENV{EMR_SCHEMA}      // 'EHR',
    ONTOLOGY_DB     => $ENV{ONTOLOGY_DB}     // ($ENV{EMR_DB} // 'CLINICAL_EMR'),
    ONTOLOGY_SCHEMA => $ENV{ONTOLOGY_SCHEMA} // 'ONTOLOGY',
    CLAIMS_DB       => $ENV{CLAIMS_DB}       // 'PAYER_CLAIMS',
    CLAIMS_SCHEMA   => $ENV{CLAIMS_SCHEMA}   // 'CLAIMS',
    RX_DB           => $ENV{RX_DB}           // 'PHARMACY_OPS',
    RX_SCHEMA       => $ENV{RX_SCHEMA}       // 'RX',
    WAREHOUSE       => $ENV{WAREHOUSE}       // 'COMPUTE_WH',
);

local $/;                 # slurp whole file
my $s = <>;

# 1) Fully-qualified DB.SCHEMA identifiers (most specific — do these first).
$s =~ s/\bCLINICAL_EMR\.ONTOLOGY\b/$v{ONTOLOGY_DB}.$v{ONTOLOGY_SCHEMA}/g;
$s =~ s/\bCLINICAL_EMR\.EHR\b/$v{EMR_DB}.$v{EMR_SCHEMA}/g;
$s =~ s/\bPAYER_CLAIMS\.CLAIMS\b/$v{CLAIMS_DB}.$v{CLAIMS_SCHEMA}/g;
$s =~ s/\bPHARMACY_OPS\.RX\b/$v{RX_DB}.$v{RX_SCHEMA}/g;

# 2) Provenance rows that store DB + schema as SEPARATE quoted literals,
#    e.g.  ('Patient', 'CLINICAL_EMR', 'ONTOLOGY', 'KG_NODE', ...).
$s =~ s/'CLINICAL_EMR',(\s*)'ONTOLOGY'/'$v{ONTOLOGY_DB}',$1'$v{ONTOLOGY_SCHEMA}'/g;

# 3) Warehouse embedded in the Cortex Agent specification JSON.
$s =~ s/("warehouse"\s*:\s*")COMPUTE_WH(")/$1$v{WAREHOUSE}$2/g;

# 3b) Human-readable deployment label inside the agent's orchestration prose.
$s =~ s/(Ontology Agent for )CLINICAL_EMR\b/$1$v{ONTOLOGY_DB}/g;

# 4) Bare database-level DDL (no schema part).
$s =~ s/CREATE DATABASE IF NOT EXISTS CLINICAL_EMR\b/CREATE DATABASE IF NOT EXISTS $v{EMR_DB}/g;
$s =~ s/CREATE DATABASE IF NOT EXISTS PAYER_CLAIMS\b/CREATE DATABASE IF NOT EXISTS $v{CLAIMS_DB}/g;
$s =~ s/CREATE DATABASE IF NOT EXISTS PHARMACY_OPS\b/CREATE DATABASE IF NOT EXISTS $v{RX_DB}/g;

# 5) The split USE DATABASE / USE SCHEMA pair in the ontology build.
$s =~ s/USE DATABASE CLINICAL_EMR\b/USE DATABASE $v{ONTOLOGY_DB}/g;
$s =~ s/^USE SCHEMA ONTOLOGY;/USE SCHEMA $v{ONTOLOGY_SCHEMA};/mg;

print $s;
