# oxo-flow-methylseq

[![CI](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml/badge.svg)](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Bisulfite methylation analysis with Bismark: FastQC, TrimGalore (default
presets), Bismark (bowtie2) alignment, deduplication, samtools sort/index,
methylation extraction (per-context calls, bedGraph, coverage), bismark2report
and bismark2summary HTML reports, and a MultiQC report. Port of the default
(paired-end, bismark aligner) execution path of nf-core/methylseq.

## Source

Ported from **[nf-core/methylseq](https://github.com/nf-core/methylseq)**,
version `4.2.0` (MIT). This port is maintained independently and **may lag
the upstream** — check the `4.2.0` above and the fidelity table below for
the exact ported state.

## Fidelity

| Upstream process/rule | oxo-flow rule | Tool (version) | Notes |
|---|---|---|---|
| FASTQC | `fastqc` | fastqc 0.12.1 | identical command; `--memory` derived from task resources |
| TRIMGALORE | `trimgalore` | trim-galore 0.6.10, cutadapt 4.9, pigz 2.8 | identical command incl. library-preset clipping and `--cores` clamp |
| BISMARK_GENOMEPREPARATION | `bismark_genomepreparation` | bismark 0.25.1 | `--bowtie2`; runs when no prebuilt index is supplied (upstream default) |
| BISMARK_ALIGN | `bismark_align` | bismark 0.25.1 | identical flag order (pbat/non_directional/unmapped/score_min/local/minins/maxins/multicore) |
| BISMARK_DEDUPLICATE | `bismark_deduplicate` | bismark 0.25.1 | identical command; skipped with `skip_deduplication`/`rrbs` like upstream |
| SAMTOOLS_SORT | `samtools_sort` | samtools 1.22.1, htslib 1.22.1 | upstream prefix `${sample}.deduplicated.sorted` |
| SAMTOOLS_INDEX | `samtools_index` | samtools 1.22.1 | identical command |
| BISMARK_METHYLATIONEXTRACTOR | `bismark_methylationextractor` | bismark 0.25.1 | identical flag order on the **deduplicated** BAM; `--multicore`/`--buffer_size` derived from resources |
| BISMARK_COVERAGE2CYTOSINE | `bismark_coverage2cytosine` | bismark 0.25.1 | off by default; runs with `cytosine_report`/`nomeseq` |
| BISMARK_REPORT | `bismark_report` | bismark 0.25.1 | bismark2report run with the four reports co-located, as in the upstream workdir |
| BISMARK_SUMMARY | `bismark_summary` | bismark 0.25.1 | bismark2summary with upstream BAM-name arguments |
| MULTIQC | `multiqc` | multiqc 1.32 | same search space + `assets/multiqc_config.yml`; versions pinned statically |
| softwareVersionsToYAML + collectFile | `multiqc_versions` | — | upstream extracts versions at runtime; port pins the module versions statically |
| CAT_FASTQ | not ported | — | only active when a sample has >1 fastq pair; single-pair samplesheets cover the default path |
| GUNZIP / UNTAR | not ported | — | only active when a prebuilt `--bismark_index` is supplied; the port always builds the index |
| QUALIMAP_BAMQC | not ported | — | `--run_qualimap` branch, off by default |
| PRESEQ_LCEXTRAP | not ported | — | `--run_preseq` branch, off by default |
| TARGETED_SEQUENCING (+ PICARD_MARKDUPLICATES / ADDORREPLACEREADGROUPS) | not ported | — | `--run_targeted_sequencing` branch, off by default |
| BAM_TAPS_CONVERSION (rastair) | not ported | — | `--taps` / bwamem branch, off by default |
| BAM_METHYLDACKEL | not ported | — | bwameth branch, off by default |
| aligners bismark_hisat / bwameth / bwamem | not ported | — | `aligner` config accepts only `bismark` (the default) |

Additional notes: paired-end only (`single_end` samplesheet column is not
ported); `--save_*` / `publish_dir_mode` params are N/A (oxo-flow publishes
every declared output); per-process `withName:` resource overrides are baked
into `[rules.resources]` (upstream labels process_single/low/medium/high +
BISMARK_ALIGN 8d / DEDUPLICATE 2d / METHYLATIONEXTRACTOR 1d time limits).

## Quickstart

```bash
# 1. install oxo-flow (see Requirements)
# 2. prepare data: <dir>/<sample>_R1.fastq.gz / <dir>/<sample>_R2.fastq.gz
#    and point config.raw_dir at that dir (default: the bundled fixtures
#    in test/fixtures/raw; config.fasta defaults to the bundled tiny genome)
# 3. preview the plan
oxo-flow dry-run main.oxoflow
# 4. run
oxo-flow run main.oxoflow -j 8
# 5. run a subset
oxo-flow run main.oxoflow -t <final-rule> --samples first:2
```

## Requirements

- **oxo-flow ≥ 0.11.0** — install the prebuilt binary:

```bash
curl -fL -o oxo-flow.tar.gz \
  https://github.com/Traitome/oxo-flow/releases/download/v0.11.0/oxo-flow-v0.11.0-x86_64-unknown-linux-gnu.tar.gz
tar xzf oxo-flow.tar.gz
sudo mv oxo-flow /usr/local/bin/
```

- Conda users may alternatively `conda install -c bioconda oxo-flow-cli`
  (note: the bioconda package currently lags the release binary at 0.10.2 —
  some 0.11.0 format features may not validate).
- Docker/Singularity/conda at runtime, per the environments declared in
  `main.oxoflow`.

## License

Apache-2.0. Copyright (c) 2026 oxo-flow-community. Upstream attribution in
[NOTICE.md](NOTICE.md).

## Community

https://oxo-flow-community.github.io/
