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
controls where results are written. The upstream parameter set is reproduced
as config keys with the same defaults: `aligner` (`bismark` / `bismark_hisat`
/ `bwameth` / `bwamem`; the first is live-verified, the others are DRAFT),
`align_suffix` (`bt2` for bowtie2, `hisat2` for hisat2 — keep in sync with
`aligner`), `taps`, `known_splices`, `use_mem2`, MethylDackel options
(`min_depth`, `all_contexts`, `merge_context`, `methyl_kit`, `ignore_flags`),
rastair trimming (`trim_ot`/`trim_ob`), QC toggles (`run_qualimap`,
`bamqc_regions_file`, `run_preseq`), targeted sequencing
(`run_targeted_sequencing`, `target_regions_file`, `collecthsmetrics`), skip
flags (`skip_fastqc`/`skip_trimming`/`skip_deduplication`/`skip_multiqc`),
library presets (`rrbs`, `pbat`, `single_cell`, `zymo`, `accel`, `em_seq`,
`slamseq`), Bismark options (`cytosine_report`, `nomeseq`, `comprehensive`,
`no_overlap`, `ignore_r1/r2`, `num_mismatches`, ...) and trimming options
(`clip_r1/r2`, `three_prime_clip_r1/r2`, `nextseq_trim`, `length_trim`).

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
| BISMARK_GENOMEPREPARATION | `bismark_genomepreparation` | bismark 0.25.1 | `--bowtie2`, or `--hisat2` with `aligner = bismark_hisat` (+ `--slam` with slamseq); runs when no prebuilt index is supplied (upstream default) |
| BISMARK_ALIGN | `bismark_align` | bismark 0.25.1 | identical flag order (hisat2/known_splices, pbat/non_directional/unmapped/score_min/local/minins/maxins/multicore); output names follow `align_suffix` (`_bismark_bt2_pe` / `_bismark_hisat2_pe`) |
| BISMARK_DEDUPLICATE | `bismark_deduplicate` | bismark 0.25.1 | identical command; skipped with `skip_deduplication`/`rrbs` like upstream |
| SAMTOOLS_SORT | `samtools_sort` | samtools 1.22.1, htslib 1.22.1 | upstream prefix `${sample}.deduplicated.sorted` |
| SAMTOOLS_INDEX | `samtools_index` | samtools 1.22.1 | identical command |
| BISMARK_METHYLATIONEXTRACTOR | `bismark_methylationextractor` | bismark 0.25.1 | identical flag order on the **deduplicated** BAM; `--multicore`/`--buffer_size` derived from resources |
| BISMARK_COVERAGE2CYTOSINE | `bismark_coverage2cytosine` | bismark 0.25.1 | off by default; runs with `cytosine_report`/`nomeseq` |
| BISMARK_REPORT | `bismark_report` | bismark 0.25.1 | bismark2report run with the four reports co-located, as in the upstream workdir |
| BISMARK_SUMMARY | `bismark_summary` | bismark 0.25.1 | bismark2summary with upstream BAM-name arguments |
| MULTIQC | `multiqc` | multiqc 1.32 | same search space + `assets/multiqc_config.yml`; versions pinned statically |
| softwareVersionsToYAML + collectFile | `multiqc_versions` | — | upstream extracts versions at runtime; port pins the module versions statically |
| BWAMETH_INDEX / BWAMETH_ALIGN | `bwameth_index` / `bwameth_align` | bwameth 0.2.9, bwa 0.7.19 | DRAFT (not yet live-tested). `use_mem2` selects `bwameth.py index-mem2`; upstream symlink dance preserved; `BWA_METH_SKIP_TIME_CHECKS=1`; BWAMETH_ALIGN time limit 6d |
| SAMTOOLS_FLAGSTAT / SAMTOOLS_STATS (bwameth) | `bwameth_samtools_flagstat` / `bwameth_samtools_stats` | samtools 1.22.1 | DRAFT; prefix `${sample}.sorted`, published under `{aligner}/alignments/samtools_stats/` |
| PICARD_MARKDUPLICATES (bwameth) | `bwameth_picard_markduplicates` | picard 3.4.0 | DRAFT; `-Xmx` = 80% of rule memory; skipped with `skip_deduplication`/`rrbs` like upstream |
| BAM_METHYLDACKEL | `methyldackel_extract` (+ `_nodedup`, `_methylkit`, `_methylkit_nodedup`), `methyldackel_mbias` (+ `_nodedup`) | methyldackel 0.6.1 | DRAFT; active only when `aligner = bwameth` and `!taps`; `--methylKit` variant is exclusive (upstream module semantics); outputs named from the BAM baseName; mbias uses the explicit prefix arg |
| BWA_INDEX / BWA_MEM | `bwa_index` / `bwa_mem` | bwa 0.7.19 | DRAFT; upstream scales index memory with FASTA size — the port uses the base process default (1 cpu / 6G); `bwa mem | samtools sort` pipeline with `sort_bam = true` |
| SAMTOOLS_STATS / FLAGSTAT / IDXSTATS (bwamem) | `bwamem_samtools_stats` / `bwamem_samtools_flagstat` / `bwamem_samtools_idxstats` | samtools 1.22.1 | DRAFT; idxstats uses upstream's `--threads (cpus - 1)` |
| PICARD_ADDORREPLACEREADGROUPS | `bwamem_picard_addorreplacereadgroups` | picard 3.4.0 | DRAFT; skipped with `skip_deduplication`; upstream does not publish this intermediate BAM — the port publishes all declared outputs |
| PICARD_MARKDUPLICATES (bwamem) | `bwamem_picard_markduplicates` | picard 3.4.0 | DRAFT |
| BAM_TAPS_CONVERSION (rastair) | `rastair_mbias` / `rastair_mbiasparser` / `rastair_call` / `rastair_methylkit` | rastair 0.8.2 | DRAFT; active when `taps` or `aligner = bwamem` (upstream semantics). The upstream channel-based trim_OT/trim_OB hand-off is reimplemented by re-parsing the mbiasparser CSV inside `rastair_call`, with `trim_ot`/`trim_ob` config fallback |
| QUALIMAP_BAMQC | `qualimap_bamqc_bismark` / `qualimap_bamqc_bwameth` / `qualimap_bamqc_bwamem` | qualimap 2.3 | DRAFT; `--run_qualimap`. Upstream `-gd HUMAN/MOUSE` (from `--genome`) is not ported; `bamqc_regions_file` is passed via `--gff` but is not a declared input (not checkpoint-tracked). The bwameth/bwamem variants consume the deduplicated BAM and stay inactive with `skip_deduplication` |
| PRESEQ_LCEXTRAP | `preseq_lcextrap_bismark` / `preseq_lcextrap_bwameth` / `preseq_lcextrap_bwamem` | preseq 3.2.0 | DRAFT; `--run_preseq`. Upstream's `.command.err` log copy is replaced by a direct stderr redirect into the declared log output |
| TARGETED_SEQUENCING | `bedtools_intersect` (+ `_methyldackel`), `picard_createsequencedictionary`, `picard_bedtointervallist`, `picard_collecthsmetrics_bismark` / `picard_collecthsmetrics_bwameth` | bedtools 2.31.1, picard 3.4.0 | DRAFT; `--run_targeted_sequencing` (+ `--collecthsmetrics`). Upstream hard-errors on taps/bwamem; the port's when-gates leave the chain inactive instead. `CreateSequenceDictionary` writes `{fasta}.dict` next to the reference; the interval-list name is pinned to `target_regions.intervallist` (upstream names it after the BED file). The bwameth bedGraph source is inactive with `methyl_kit`/`skip_deduplication` |
| MultiQC (bwameth/bwamem) | `multiqc_bwameth` / `multiqc_bwamem` | multiqc 1.32 | DRAFT; upstream mixes qualimap/preseq/targeted metrics into the report — the port keeps those out (the upstream asset config defines no custom sections for them) |
| CAT_FASTQ | not ported | — | only active when a sample has >1 fastq pair; single-pair samplesheets cover the default path |
| GUNZIP / UNTAR | not ported | — | only active when a prebuilt `--bismark_index` is supplied; the port always builds the index |
| PARABRICS_FQ2BAMMETH | not ported | — | GPU-only path (nvcr.io container, conda-incompatible); errors under conda/mamba upstream |

Additional notes: paired-end only (`single_end` samplesheet column is not
ported); `--save_*` / `publish_dir_mode` params are N/A (oxo-flow publishes
every declared output); per-process `withName:` resource overrides are baked
into `[rules.resources]` (upstream labels process_single/low/medium/high +
BISMARK_ALIGN 8d / DEDUPLICATE 2d / METHYLATIONEXTRACTOR 1d / BWAMETH_ALIGN
6d time limits). All rules added in this porting round are **DRAFT** —
ported from upstream 4.2.0 and gate-verified with dry-runs, but not yet
live-tested against real reads; the default `aligner = bismark` path remains
live-verified. `all_contexts` (`--CHG --CHH`) extends the MethylDackel output
set but the port declares only the default CpG outputs (DRAFT — the CHG/CHH
files are not checkpoint-tracked).

## Test

Run the acceptance test (validate + lint + dry-run):

```bash
bash test/run.sh
```

## License

Apache-2.0. Copyright (c) 2026 oxo-flow-community. Upstream attribution in
[NOTICE.md](NOTICE.md). The upstream nf-core/methylseq pipeline is MIT
licensed; its license is included verbatim at `LICENSE.upstream`.
