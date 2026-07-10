#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# deploy.sh — one-shot deploy of the messy-data-ontology demo into YOUR account.
#
#   ./deploy.sh              # render + deploy sources + ontology, then verify
#   ./deploy.sh render       # only render SQL into ./build (no Snowflake calls)
#   ./deploy.sh verify       # run count assertions against the deployed ontology
#   ./deploy.sh teardown      # DROP the three demo databases (asks to confirm)
#   ./deploy.sh check        # prove render-with-defaults == source (no changes)
#
# Configuration comes from ./config.env (git-ignored). If absent, the committed
# defaults in ./config.env.example are used, which reproduce the reference
# deployment exactly. See config.env.example for every knob.
#
# Requires: Snowflake CLI (`snow`) with a connection in connections.toml, and
# perl (present on macOS/Linux by default).
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

# ---- load config ----------------------------------------------------------
if [[ -f config.env ]]; then
  # shellcheck disable=SC1091
  source config.env
else
  echo "note: config.env not found — using defaults from config.env.example"
  # shellcheck disable=SC1091
  source config.env.example
fi

: "${SNOWFLAKE_CONNECTION:=DEMO}"
: "${BUILD_ROLE:=SYSADMIN}"
: "${WAREHOUSE:=COMPUTE_WH}"
: "${EMR_DB:=CLINICAL_EMR}";    : "${EMR_SCHEMA:=EHR}"
: "${ONTOLOGY_DB:=$EMR_DB}";    : "${ONTOLOGY_SCHEMA:=ONTOLOGY}"
: "${CLAIMS_DB:=PAYER_CLAIMS}"; : "${CLAIMS_SCHEMA:=CLAIMS}"
: "${RX_DB:=PHARMACY_OPS}";     : "${RX_SCHEMA:=RX}"
export EMR_DB EMR_SCHEMA ONTOLOGY_DB ONTOLOGY_SCHEMA CLAIMS_DB CLAIMS_SCHEMA RX_DB RX_SCHEMA WAREHOUSE

SOURCE_FILES=(
  sql/data/01_clinical_emr.sql
  sql/data/02_payer_claims.sql
  sql/data/03_pharmacy_ops.sql
)
ONTOLOGY_FILES=(
  sql/ontology/01_phase4_layers_1-3.sql
  sql/ontology/02_phase4.5_base_semantic_view.sql
  sql/ontology/03_phase5_ontology_layer_semantic_views.sql
  sql/ontology/04_phase6_cortex_agents.sql
)

render() {  # render <src> -> ./build/<flattened>.sql ; echoes the output path
  local src="$1" out="build/${1//\//_}"
  mkdir -p build
  perl scripts/render.pl "$src" > "$out"
  echo "$out"
}

run_sql() {  # run_sql <rendered-file>
  snow sql -c "$SNOWFLAKE_CONNECTION" --role "$BUILD_ROLE" --warehouse "$WAREHOUSE" -f "$1"
}

require_snow() {
  command -v snow >/dev/null 2>&1 || {
    echo "error: Snowflake CLI 'snow' not found. Install it, or run the rendered"
    echo "       files in ./build/ manually in a Snowsight worksheet."
    exit 1
  }
}

banner() {
  echo "----------------------------------------------------------------------"
  echo " connection : $SNOWFLAKE_CONNECTION   role: $BUILD_ROLE   wh: $WAREHOUSE"
  echo " databases  : EMR=$EMR_DB.$EMR_SCHEMA  ONTOLOGY=$ONTOLOGY_DB.$ONTOLOGY_SCHEMA"
  echo "              CLAIMS=$CLAIMS_DB.$CLAIMS_SCHEMA  RX=$RX_DB.$RX_SCHEMA"
  echo "----------------------------------------------------------------------"
}

cmd="${1:-deploy}"
case "$cmd" in
  check)
    # Prove the render engine is lossless for the current config's defaults path.
    fail=0
    for f in "${SOURCE_FILES[@]}" "${ONTOLOGY_FILES[@]}"; do
      if diff -q "$f" <(env -u EMR_DB -u EMR_SCHEMA -u ONTOLOGY_DB -u ONTOLOGY_SCHEMA \
           -u CLAIMS_DB -u CLAIMS_SCHEMA -u RX_DB -u RX_SCHEMA -u WAREHOUSE \
           perl scripts/render.pl "$f") >/dev/null; then
        echo "identity ok: $f"
      else
        echo "DIFF: $f"; fail=1
      fi
    done
    exit "$fail"
    ;;

  render)
    banner
    for f in "${SOURCE_FILES[@]}" "${ONTOLOGY_FILES[@]}"; do echo "rendered $(render "$f")"; done
    echo "rendered $(render sql/ontology/verify.sql)"
    echo "rendered $(render sql/ontology/teardown.sql)"
    echo "done. rendered SQL is in ./build/ — deploy it however you like."
    ;;

  deploy)
    require_snow; banner
    echo ">> loading source systems (01 -> 02 -> 03)"
    for f in "${SOURCE_FILES[@]}";   do echo "   $f"; run_sql "$(render "$f")"; done
    echo ">> building ontology (phase 4 -> 6)"
    for f in "${ONTOLOGY_FILES[@]}"; do echo "   $f"; run_sql "$(render "$f")"; done
    echo ">> verifying"
    run_sql "$(render sql/ontology/verify.sql)"
    echo "deploy complete."
    ;;

  verify)
    require_snow; banner
    run_sql "$(render sql/ontology/verify.sql)"
    ;;

  teardown)
    require_snow; banner
    read -r -p "This DROPs databases $EMR_DB, $CLAIMS_DB, $RX_DB. Type 'yes' to proceed: " ans
    [[ "$ans" == "yes" ]] || { echo "aborted."; exit 1; }
    run_sql "$(render sql/ontology/teardown.sql)"
    echo "teardown complete."
    ;;

  *)
    echo "usage: ./deploy.sh [deploy|render|verify|teardown|check]"; exit 2
    ;;
esac
