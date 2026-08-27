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
# oxo-flow v0.11.0 prints the plan to stderr; capture both streams
"$OXO" dry-run main.oxoflow --samples first:1 > /tmp/oxo-dryrun-$$.txt 2>&1
grep -q "would execute" /tmp/oxo-dryrun-$$.txt

echo "==> debug: expanded commands contain no literal {wildcards}"
"$OXO" debug main.oxoflow 2>&1 | grep -q '{sample}' && { echo "unexpanded wildcards in debug output"; exit 1; } || true

echo "==> single-end mode: engine metadata capability probe"
# Metadata binding ({meta.*} + [workflow] metadata_file) landed in the engine
# after the 0.16.0 release. Old engines render the placeholder literally in
# the dry-run plan; the resolved engine bakes the metadata row in. The
# single-end dry-run below needs the resolved engine, so skip it otherwise.
"$OXO" dry-run test/fixtures/metaprobe/probe.oxoflow > /tmp/oxo-metaprobe-$$.txt 2>&1
if grep -q '{meta\.' /tmp/oxo-metaprobe-$$.txt; then
    echo "SKIP single-end test (engine does not resolve {meta.*}; needs oxo-flow >= 0.17.0)"
else
    echo "==> single-end mode dry-run (metadata_file + single_end_mode = true, sample S3)"
    # Materialize the single-end configuration: the default file keeps both
    # switches off so every sample stays paired-end.
    sed -e 's|^# metadata_file = "metadata/samples.tsv"|metadata_file = "metadata/samples.tsv"|' \
        -e 's/^single_end_mode = false$/single_end_mode = true/' \
        main.oxoflow > .se-tmp.oxoflow
    trap 'rm -f .se-tmp.oxoflow' EXIT
    "$OXO" dry-run .se-tmp.oxoflow --samples @test/fixtures/samples_se.tsv > /tmp/oxo-sedry-$$.txt 2>&1
    grep -q "would execute" /tmp/oxo-sedry-$$.txt
    # the single-end chain runs for S3 ...
    for se_rule in fastqc_se trimgalore_se bismark_align_se bismark_deduplicate_se bismark_methylationextractor_se bismark_report_se; do
        grep -qE "${se_rule}_cohort_S3 +\[run:" /tmp/oxo-sedry-$$.txt
    done
    # ... and the paired-end chain stays off
    for pe_rule in fastqc trimgalore bismark_align bismark_deduplicate bismark_methylationextractor bismark_report; do
        grep -qE "${pe_rule}_cohort_S3 +\[skip" /tmp/oxo-sedry-$$.txt
    done
fi

echo "PASS"
