#!/usr/bin/env bash
# Acceptance test for oxo-flow-methylseq port.
# Usage: ./test/run.sh            (uses ./main.oxoflow)
set -euo pipefail
cd "$(dirname "$0")/.."
OXO=${OXO:-oxo-flow}

echo "==> validate"
"$OXO" validate main.oxoflow

echo "==> lint (warnings are acceptable, errors are not)"
"$OXO" lint main.oxoflow

echo "==> dry-run with default config"
# oxo-flow prints the plan to stderr; capture both streams
"$OXO" dry-run main.oxoflow --samples first:1 > /tmp/oxo-dryrun-$$.txt 2>&1
grep -q "would execute" /tmp/oxo-dryrun-$$.txt

echo "==> dry-run per aligner chain (DRAFT branches must gate correctly)"
dryrun_gate() {
    local desc="$1"; shift
    local expect="$1"; shift
    local out="/tmp/oxo-dryrun-$$-$(echo "$desc" | tr ' ' '_').txt"
    "$OXO" dry-run main.oxoflow --samples first:1 "$@" > "$out" 2>&1
    grep -q "would execute" "$out"
    grep -q "$expect" "$out"
    echo "  ok: $desc ($expect)"
}
dryrun_gate "bismark_hisat naming" "bismark_align_cohort_S1" aligner=bismark_hisat align_suffix=hisat2
dryrun_gate "bwameth chain" "bwameth_align_cohort_S1" aligner=bwameth
dryrun_gate "bwameth skip_dedup -> nodedup extract" "methyldackel_extract_nodedup_cohort_S1" aligner=bwameth skip_deduplication=true
dryrun_gate "bwameth methyl_kit exclusive variant" "methyldackel_extract_methylkit_cohort_S1" aligner=bwameth methyl_kit=true
dryrun_gate "bwamem chain" "bwa_mem_cohort_S1" aligner=bwamem
dryrun_gate "bwamem taps -> rastair chain" "rastair_call_cohort_S1" aligner=bwamem taps=true
dryrun_gate "targeted sequencing (bismark)" "bedtools_intersect_cohort_S1" run_targeted_sequencing=true
dryrun_gate "collecthsmetrics" "picard_collecthsmetrics_bismark_cohort_S1" run_targeted_sequencing=true collecthsmetrics=true
dryrun_gate "qualimap + preseq (bismark)" "qualimap_bamqc_bismark_cohort_S1" run_qualimap=true run_preseq=true
dryrun_gate "qualimap + preseq (bwameth)" "qualimap_bamqc_bwameth_cohort_S1" aligner=bwameth run_qualimap=true run_preseq=true

echo "==> debug: expanded commands contain no literal {wildcards}"
"$OXO" debug main.oxoflow 2>&1 | grep -q '{sample}' && { echo "unexpanded wildcards in debug output"; exit 1; } || true

echo "PASS"
