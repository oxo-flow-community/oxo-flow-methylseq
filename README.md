# oxo-flow-methylseq — Bisulfite methylation analysis: alignment, methylation calls and QC

> ★ Verified · ⇄ Official port of [`nf-core/methylseq`](https://github.com/nf-core/methylseq) @ `4.2.0` — same tools, same versions, same commands. Part of the [oxo-flow-community catalog](https://oxo-flow-community.github.io/).

[![CI](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml/badge.svg)](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Run end-to-end bisulfite methylation analysis (WGBS, and RRBS-compatible) of
paired-end reads: FastQC quality control of the raw reads, TrimGalore adapter
trimming, alignment to the bisulfite-converted reference genome with Bismark
(bowtie2), PCR-deduplication, samtools sort/index, methylation extraction with
per-context (CpG/CHG/CHH) calls plus bedGraph and coverage output, per-sample
and project-wide Bismark HTML reports, and a final MultiQC report.

## Installation

### 1. Install oxo-flow

Requires **oxo-flow >= 0.12.0**. Recommended: the prebuilt release binary for
Linux x86_64:

```bash
curl -fL -o oxo-flow.tar.gz \
  https://github.com/Traitome/oxo-flow/releases/latest/download/oxo-flow-latest-x86_64-unknown-linux-gnu.tar.gz
tar xzf oxo-flow.tar.gz
sudo mv oxo-flow /usr/local/bin/
```

Alternatively via conda:

```bash
conda install -c bioconda oxo-flow-cli
```

Note the conda package may lag behind releases; other platform binaries are
available on the [releases page](https://github.com/Traitome/oxo-flow/releases).

### 2. Get this workflow

```bash
git clone https://github.com/oxo-flow-community/oxo-flow-methylseq.git
cd oxo-flow-methylseq
```

### 3. Requirements

- **Reference data** — an uncompressed reference genome FASTA
  (`config.fasta`). The Bismark (bowtie2) bisulfite index is built
  automatically from it on the first run (`bismark_genomepreparation`), so no
  prebuilt index is required. The repository default points at the bundled
  tiny test genome (`test/fixtures/refs/genome.fa`); point it at your genome.
- **Input reads** — paired-end FASTQ.gz files named
  `<dir>/<sample>_R1.fastq.gz` and `<dir>/<sample>_R2.fastq.gz`, with
  `config.raw_dir` set to that directory (default: the bundled fixtures in
  `test/fixtures/raw`).
- **Compute** — up to 12 CPUs / 72 GB RAM per rule, the maximum across the
  heavy rules (`bismark_genomepreparation`, `trimgalore`, `bismark_align`,
  `bismark_deduplicate`, `bismark_methylationextractor`). Scale `-j` to what
  your machine can run in parallel.
- **Tools** — delivered as conda environments with pinned versions, one per
  rule group (`envs/*.yaml`, e.g. `bismark=0.25.1`, `fastqc=0.12.1`,
  `samtools=1.22.1`, `multiqc=1.32`), created on demand from
  conda-forge/bioconda. Install conda or mamba to run them.
- **Disk** — allow space in `config.out_dir` (default `results/`) for aligned
  BAMs, methylation calls, and reports.

## Usage

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

Configuration lives in the `[config]` table at the top of `main.oxoflow`.
`fasta` and `raw_dir` point at your reference genome and reads; `out_dir`
(control) controls where results are written. The upstream parameter set is
reproduced as config keys with the same defaults: skip flags
(`skip_fastqc`/`skip_trimming`/`skip_deduplication`/`skip_multiqc`), library
presets (`rrbs`, `pbat`, `single_cell`, `zymo`, `accel`, `em_seq`, `slamseq`),
Bismark options (`cytosine_report`, `nomeseq`, `comprehensive`, `no_overlap`,
`ignore_r1/r2`, `num_mismatches`, ...) and trimming options (`clip_r1/r2`,
`three_prime_clip_r1/r2`, `nextseq_trim`, `length_trim`). Only the `bismark`
(bowtie2) aligner is ported.

## Source

Ported from **[nf-core/methylseq](https://github.com/nf-core/methylseq)**,
version `4.2.0` (MIT) at commit
`5aa56467a85a5e2d6795ea72dfa5a5f0c9babc23`. This port is maintained
independently. Created 2026-08-15; this workflow may lag behind upstream
releases. Full upstream attribution in [NOTICE.md](NOTICE.md).

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

## Test

Run the acceptance test (validate + lint + dry-run):

```bash
bash test/run.sh
```

## License

Apache-2.0. Copyright (c) 2026 oxo-flow-community. Upstream attribution in
[NOTICE.md](NOTICE.md). The upstream nf-core/methylseq pipeline is MIT
licensed; its license is included verbatim at `LICENSE.upstream`.
