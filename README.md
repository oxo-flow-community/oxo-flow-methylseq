# oxo-flow-methylseq — Bisulfite methylation analysis: alignment, methylation calls and QC

> ★ Verified · ⇄ Official port of [`nf-core/methylseq`](https://github.com/nf-core/methylseq) @ `4.2.0` — same tools, same versions, same commands. Part of the [oxo-flow-community catalog](https://oxo-flow-community.github.io/).

[![CI](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml/badge.svg)](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Run end-to-end bisulfite methylation analysis (WGBS, and RRBS-compatible) of
paired-end reads: FastQC quality control of the raw reads, TrimGalore adapter
trimming, alignment with any of the four upstream aligners — **Bismark
(bowtie2, default)**, Bismark hisat2, **bwameth** (bwa-meth) or **BWA-MEM** —
PCR-deduplication, samtools sort/index, methylation calls (bismark
methylation extraction, MethylDackel on the bwameth branch, rastair for TAPS),
per-sample and project-wide Bismark HTML reports, and a final MultiQC report.
Optional upstream branches (off by default, same gates as the upstream
params): QualiMap BamQC, preseq complexity estimates, targeted-sequencing
analysis (bedtools intersect + Picard HS metrics), MethylKit output and
all-context (CHG/CHH) calls.

## Installation

### 1. Install oxo-flow

Requires **oxo-flow >= 0.14.0** (the picard rules size `-Xmx` from the
`{effective_memory_mb}` placeholder, added in 0.14.0). Recommended: the
prebuilt release binary for
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

- **Reference data** — a reference genome FASTA (`config.fasta`); a gzipped
  FASTA is decompressed automatically before indexing. The Bismark (bowtie2)
  bisulfite index is built automatically from it on the first run
  (`bismark_genomepreparation`), so no prebuilt index is required; a prebuilt
  index archive can be supplied with `config.bismark_index` (untarred by
  `bismark_untar`, like the upstream `--bismark_index`). The repository
  default points at the bundled tiny test genome
  (`test/fixtures/refs/genome.fa`); point it at your genome.
- **Input reads** — paired-end FASTQ.gz files named
  `<dir>/<sample>_R1.fastq.gz` and `<dir>/<sample>_R2.fastq.gz`, with
  `config.raw_dir` set to that directory (default: the bundled fixtures in
  `test/fixtures/raw`).
- **Compute** — up to 12 CPUs / 72 GB RAM per rule, the maximum across the
  heavy rules (`bismark_genomepreparation`, `trimgalore`, `bismark_align`,
  `bismark_deduplicate`, `bismark_methylationextractor`, `bwameth_index`,
  `bwameth_align`, `bwa_mem`). Scale `-j` to what your machine can run in
  parallel.
- **Tools** — delivered as conda environments with pinned versions, one per
  rule group (`envs/*.yaml`, e.g. `bismark=0.25.1`, `fastqc=0.12.1`,
  `samtools=1.22.1`, `bwameth=0.2.9`, `bwa=0.7.19`, `picard=3.4.0`,
  `methyldackel=0.6.1`, `rastair=0.8.2`, `qualimap=2.3`, `preseq=3.2.0`,
  `bedtools=2.31.1`, `multiqc=1.32`), created on demand from
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
# 6. select an alternative branch (e.g. bwameth + TAPS + QualiMap)
oxo-flow run main.oxoflow aligner=bwameth taps=true run_qualimap=true
```

Configuration lives in the `[config]` table at the top of `main.oxoflow`.
`fasta` and `raw_dir` point at your reference genome and reads; `out_dir`
controls where results are written. The upstream parameter set is reproduced
as config keys with the same defaults: the aligner (`aligner`, default
`bismark`; also `bismark_hisat`, `bwameth`, `bwamem`), skip flags
(`skip_fastqc`/`skip_trimming`/`skip_deduplication`/`skip_multiqc`), library
presets (`rrbs`, `pbat`, `single_cell`, `zymo`, `accel`, `em_seq`, `slamseq`),
Bismark options (`cytosine_report`, `nomeseq`, `comprehensive`, `no_overlap`,
`ignore_r1/r2`, `num_mismatches`, ...), trimming options (`clip_r1/r2`,
`three_prime_clip_r1/r2`, `nextseq_trim`, `length_trim`), a prebuilt Bismark
index (`bismark_index`), hisat2 splice sites (`known_splices`), the bwameth
mem2 index variant (`use_mem2`), the optional branches (`taps`,
`run_qualimap`, `run_preseq`, `run_targeted_sequencing`, `collecthsmetrics`,
`bamqc_regions_file`, `target_regions_file`) and MethylDackel options
(`all_contexts`, `merge_context`, `min_depth`, `ignore_flags`, `methyl_kit`).
Every optional branch is off by default, matching the upstream defaults.

### Branch-specific test data

The bundled `test/fixtures/raw` reads are WGBS (bisulfite-converted) and only
map under the bisulfite-aware aligners (bismark / bismark_hisat / bwameth).
The `bwamem` branch is upstream's TAPS/EM-seq path (`bwa mem` on
non-converted reads — see the upstream usage docs' "BWA-MEM align (TAPS)"
diagram), so live-testing it uses the unconverted fixture
`test/fixtures/raw_emseq` (read pairs cut from the reference genome):

```bash
oxo-flow run main.oxoflow aligner=bwamem raw_dir=test/fixtures/raw_emseq
```

Two QC notes for tiny synthetic fixtures (real data is unaffected):

- **MultiQC** (v1.32, the upstream pin) can crash inside its own
  samtools-stats BarPlot when every sample's stats are degenerate (0/constant
  values). Run the branch with `skip_multiqc=true` on ultra-small fixtures.
- **preseq lc_extrap** requires duplicate counts ≥ 4 in the BAM
  ("max count before zero is less than min required count"); the emseq
  fixture ships each read 10× so the bwamem + preseq combination works.
- **rastair mbias on the bwamem branch** — live-verified on the synthetic
  fixture: `rastair mbias` prints header-only rows for the partially
  C→T-converted fixture reads (bwa mem cannot map fully-converted reads, and
  the sparse conversion signal of the fixture yields no per-position counts),
  while the same rule produces full tables on the bwameth branch (WGBS
  fixture). The rules fail fast (`[ -s … ]` guards) instead of silently
  propagating empty files. Real TAPS/EM-seq data has the full conversion
  signal rastair counts; this is a fixture limitation, not a workflow bug.

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
| BISMARK_GENOMEPREPARATION | `bismark_genomepreparation` | bismark 0.25.1, gzip 1.13 | `--bowtie2` (or `--hisat2` for bismark_hisat, `--slam` for slamseq); runs when no prebuilt index is supplied (upstream default) |
| GUNZIP | (merged into the index-preparation shells) | gzip 1.13 | a gzipped reference FASTA is decompressed before index building, as in the upstream fasta_index_methylseq subworkflow |
| UNTAR | `bismark_untar` | tar 1.34 | active only when a prebuilt `--bismark_index` archive is supplied; strips a single top-level directory, like upstream |
| BISMARK_ALIGN | `bismark_align` | bismark 0.25.1 | identical flag order (pbat/non_directional/unmapped/score_min/local/minins/maxins/multicore); hisat2 splice sites via `known_splices` (see deviations) |
| BISMARK_DEDUPLICATE | `bismark_deduplicate` | bismark 0.25.1 | identical command; skipped with `skip_deduplication`/`rrbs` like upstream |
| SAMTOOLS_SORT | `samtools_sort` | samtools 1.22.1, htslib 1.22.1 | upstream prefix `${sample}.deduplicated.sorted` |
| SAMTOOLS_INDEX | `samtools_index` | samtools 1.22.1 | identical command |
| BISMARK_METHYLATIONEXTRACTOR | `bismark_methylationextractor` | bismark 0.25.1 | identical flag order on the **deduplicated** BAM; `--multicore`/`--buffer_size` derived from resources |
| BISMARK_COVERAGE2CYTOSINE | `bismark_coverage2cytosine` | bismark 0.25.1 | off by default; runs with `cytosine_report`/`nomeseq` |
| BISMARK_REPORT | `bismark_report` | bismark 0.25.1 | bismark2report run with the four reports co-located, as in the upstream workdir |
| BISMARK_SUMMARY | `bismark_summary` | bismark 0.25.1 | bismark2summary with upstream BAM-name arguments |
| BWAMETH_INDEX | `bwameth_index` | bwameth 0.2.9 | `bwameth.py index`, or `index-mem2` with `use_mem2`; index dir `refs/BwamethIndex` |
| BWAMETH_ALIGN | `bwameth_align` | bwameth 0.2.9 | identical command (reference symlink re-created in the index dir, `samtools view -bhS`) |
| BWA_INDEX | `bwa_index` | bwa 0.7.19 | `bwa index -p`; upstream sizes memory dynamically (5.37x FASTA) — the port uses a fixed 4 threads/24G/24h budget (see deviations) |
| BWA_MEM | `bwa_mem` | bwa 0.7.19, samtools 1.22.1 | upstream `sort_bam = true`: `bwa mem \| samtools sort`; index prefix found by globbing `*.amb` |
| SAMTOOLS_INDEX_ALIGNMENTS | `samtools_index_alignment` | samtools 1.22.1 | index of the sorted alignment BAM (bwameth/bwamem) |
| SAMTOOLS_FLAGSTAT | `samtools_flagstat` | samtools 1.22.1 | identical command |
| SAMTOOLS_STATS | `samtools_stats` | samtools 1.22.1 | identical command |
| SAMTOOLS_IDXSTATS | `samtools_idxstats` | samtools 1.22.1 | bwamem branch; `--threads cpus-1` as upstream |
| PICARD_MARKDUPLICATES | `picard_markduplicates` / `picard_markduplicates_bwamem` | picard 3.4.0 | identical args (ASSUME_SORTED/REMOVE_DUPLICATES/LENIENT/PROGRAM_RECORD_ID null/TMP_DIR); -Xmx = 0.8 x memory |
| PICARD_ADDORREPLACEREADGROUPS | `picard_addorreplacereadgroups` | picard 3.4.0 | identical args; upstream does not publish this BAM — the port declares it so the DAG can consume it |
| SAMTOOLS_INDEX_DEDUPLICATED | `samtools_index_deduplicated` / `samtools_index_deduplicated_bwamem` | samtools 1.22.1 | index of the deduplicated BAM |
| METHYLDACKEL_EXTRACT | `methyldackel_extract` (+ `_allcontexts`, `_methylkit`) | methyldackel 0.6.1 | same flags (CHG/CHH, mergeContext, ignoreFlags, minDepth, methylKit); the methylKit table and the all-contexts bedGraphs are separate gated rules (see deviations) |
| METHYLDACKEL_MBIAS | `methyldackel_mbias` | methyldackel 0.6.1 | identical command |
| RASTAIR_MBIAS | `rastair_mbias_bwameth` / `rastair_mbias_bwamem` | rastair 0.8.2 | active with `taps` on bwameth and always on bwamem, exactly like the upstream `if (params.taps \|\| aligner == 'bwamem')` |
| RASTAIR_MBIASPARSER | `rastair_mbiasparser` | rastair 0.8.2, r-base 4.4.0 | plot_mbias.R + parse_mbias.R |
| RASTAIR_CALL | `rastair_call_bwameth` / `rastair_call_bwamem` | rastair 0.8.2 | trim values flow from the mbiasparser CSV (see deviations) |
| RASTAIR_METHYLKIT | `rastair_methylkit` | rastair 0.8.2 | `rastair_call_to_methylkit.sh \| gzip` |
| QUALIMAP_BAMQC | `qualimap_bamqc` / `qualimap_bamqc_alt` | qualimap 2.3 | `-p non-strand-specific --collect-overlap-pairs`, `--gff` with `bamqc_regions_file`, `_JAVA_OPTIONS` tmpdir |
| PRESEQ_LCEXTRAP | `preseq_lcextrap` / `preseq_lcextrap_alt` | preseq 3.2.0 | `-verbose -bam -pe`; the `*.command.log` is preseq's own stderr (see deviations) |
| PICARD_CREATESEQUENCEDICTIONARY | `picard_createsequencedictionary` | picard 3.4.0 | runs only when `collecthsmetrics` is requested, like upstream |
| PICARD_BEDTOINTERVALLIST | `picard_bedtointervallist` | picard 3.4.0 | output named `target_regions.intervallist` (fixed name; see deviations) |
| BEDTOOLS_INTERSECT | `bedtools_intersect` (+ `_bwameth`, `_chg`, `_chh`) | bedtools 2.31.1 | prefix = the bedGraph basename, suffix `targeted.bedGraph`, as upstream |
| PICARD_COLLECTHSMETRICS | `picard_collecthsmetrics` / `picard_collecthsmetrics_alt` | picard 3.4.0 | same intervals for bait and target; excluded on the taps/bwamem branches, like the upstream rastair error |
| SAMTOOLS_FAIDX | `samtools_faidx` | samtools 1.22.1, htslib 1.22.1, gzip 1.13 | stages the reference at `refs/FastaRef/reference.fa`; upstream gate (bwameth/bwamem/collecthsmetrics) reproduced |
| MULTIQC | `multiqc` / `multiqc_bwameth` / `multiqc_bwamem` | multiqc 1.32 | one rule per aligner branch; same search space as upstream (fastqc zips, trimgalore logs, samtools stats/flagstat/idxstats, picard metrics + qualimap/preseq/HS extras); the methyldackel/rastair outputs are not fed to MultiQC, exactly like upstream |
| softwareVersionsToYAML + collectFile | `multiqc_versions` | — | upstream extracts versions at runtime; port pins the module versions statically |
| CAT_FASTQ | not ported | — | only active when a sample has >1 fastq pair; single-pair samplesheets cover the default path |

Additional notes: paired-end only (`single_end` samplesheet column is not
ported); `--save_*` / `publish_dir_mode` params are N/A (oxo-flow publishes
every declared output); per-process `withName:` resource overrides are baked
into `[rules.resources]` (upstream labels process_single/low/medium/high +
BISMARK_ALIGN 8d / DEDUPLICATE 2d / METHYLATIONEXTRACTOR 1d time limits).

### Documented deviations

Each deviation is cosmetic or a mechanism swap — the effective commands and
outputs match upstream:

1. **bismark_hisat output names** — hisat2-mode alignments are renamed from
   the upstream `_bismark_hisat2_` infix (bismark 0.24.x names, live-verified)
   to the canonical `_bismark_bt2_` names so the shared downstream chain works
   unchanged (cosmetic).
2. **`--known-splicesite-infile`** — upstream passes
   `<(...)` (process substitution); the port materializes the same
   `hisat2_extract_splice_sites.py` output to a temp file (bash process
   substitution does not survive variable expansion).
3. **`--PROGRAM_RECORD_ID null`** — passed unquoted; the upstream quotes are
   Groovy escaping and the effective value is the bare word `null`.
4. **preseq `*.command.log`** — upstream copies the whole Nextflow task
   stderr (`.command.err`); oxo-flow has no such file, so the port's log is
   preseq's stderr (the informative part of the upstream log).
5. **Canonical staging names** — the Bismark index dir always contains the
   FASTA as `reference.fa`, the bwameth/bwamem/HS branches use
   `refs/FastaRef/reference.fa` + `refs/RefDict/reference.dict`, and
   `picard_bedtointervallist` writes `target_regions.intervallist` (upstream
   uses the BED file's basename). Names differ; content and ordering do not.
6. **Envs consolidated** — the upstream GUNZIP/UNTAR coreutils env is merged
   into the tool envs (gzip added to `bismark_genomeprep`/`samtools_faidx`,
   since the bioconda bismark 0.25.1 build does not depend on gzip), and the
   four upstream rastair envs are consolidated into one
   (`rastair=0.8.2=*_2` + `r-base=4.4.0`, the build that ships the R helper
   scripts) for every rastair rule.
7. **TAPS on the bismark aligners** — upstream builds no fasta index for
   `taps && aligner =~ /bismark/`, so BAM_TAPS_CONVERSION silently produces
   nothing there; the port replicates that (no bismark-family rastair rules)
   instead of the upstream's silent no-op.
8. **`bwa_index` resources** — upstream requests `5.37 x fasta.size()`
   memory dynamically; the port uses a fixed 4 threads / 24G / 24h budget
   (adequate for ~4GB genomes).
9. **`skip_deduplication`/`rrbs` on the bwameth/bwamem branches** — upstream
   passes the *alignment* BAM downstream when dedup is skipped; the port's
   methyldackel/rastair/qualimap/preseq/HS-metrics rules consume the
   deduplicated BAM, so those branches require deduplication. Upstream's
   dedup-independent callers behave identically when dedup runs (the default).
10. **MethylDackel `--methylKit`** — the tool emits only `*.methylKit` files
    when the flag is given, so the port runs `methyldackel_extract_methylkit`
    as a separate gated rule *in addition to* the bedGraph-producing run
    (the upstream module emits both outputs from one invocation; oxo-flow
    validates every declared output, so the split is required).
11. **MultiQC per aligner** — one `multiqc` rule per aligner branch with the
    branch's always-present files declared and the conditional extras
    (qualimap dirs, preseq logs, HS metrics, picard metrics) symlinked
    in-shell when they exist — the engine cannot declare conditional inputs.

## Test

Run the acceptance test (validate + lint + dry-run):

```bash
bash test/run.sh
```

## License

Apache-2.0. Copyright (c) 2026 oxo-flow-community. Upstream attribution in
[NOTICE.md](NOTICE.md). The upstream nf-core/methylseq pipeline is MIT
licensed; its license is included verbatim at `LICENSE.upstream`.
