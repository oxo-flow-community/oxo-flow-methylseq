# oxo-flow-methylseq — Bisulfite methylation analysis: alignment, methylation calls and QC

> ★ Verified · ⇄ Official port of [`nf-core/methylseq`](https://github.com/nf-core/methylseq) @ `4.2.0` — same tools, same versions, same commands. Part of the [oxo-flow-community catalog](https://oxo-flow-community.github.io/).

[![CI](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml/badge.svg)](https://github.com/oxo-flow-community/oxo-flow-methylseq/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Run end-to-end bisulfite methylation analysis (WGBS, and RRBS-compatible) of
paired-end reads (default) and single-end reads (upstream `single_end`
samplesheet column — ported via the engine's metadata binding, see Usage):
FastQC quality control of the raw reads, TrimGalore adapter
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

Requires **oxo-flow >= 0.17.0** (the `cat_fastq` rules use the
`input_groups` primitive, added in 0.17.0; the picard rules size `-Xmx`
from the `{effective_memory_mb}` placeholder, added in 0.14.0). On older
engines `input_groups` is a no-op and the `cat_fastq` rules fail loudly
instead of writing empty fastqs — upgrade, or keep every sample to a single
pair and set `cat_fastq = false`. Recommended: the prebuilt release binary
for Linux x86_64:

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
  `test/fixtures/raw`). Samples with **more than one pair** (upstream
  `CAT_FASTQ` support) name their pairs with a unit segment —
  `<dir>/<sample>_<unit>_R1.fastq.gz` and `<dir>/<sample>_<unit>_R2.fastq.gz`
  per unit — and the port concatenates all units of a sample into one pair
  before QC/trimming, exactly like the upstream `ch_samplesheet.multiple`
  branch. Single-pair samples are untouched (upstream `ch_samplesheet.single`).
  **Single-end samples** (upstream `single_end` = true, no `fastq_2`
  column) ship `<dir>/<sample>_R1.fastq.gz` only and are routed per-sample by
  their row in the metadata samplesheet — see the single-end section under
  Usage.
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
#    (multi-pair samples: <dir>/<sample>_<unit>_R1.fastq.gz / _R2.fastq.gz
#    per unit — all units are concatenated before QC/trimming)
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
(`skip_fastqc`/`skip_trimming`/`skip_deduplication`/`skip_multiqc`),
multi-pair concatenation (`cat_fastq`, default `true` — set `false` only
when every sample has a single pair), library
presets (`rrbs`, `pbat`, `single_cell`, `zymo`, `accel`, `em_seq`, `slamseq`),
Bismark options (`cytosine_report`, `nomeseq`, `comprehensive`, `no_overlap`,
`ignore_r1/r2`, `num_mismatches`, ...), trimming options (`clip_r1/r2`,
`three_prime_clip_r1/r2`, `nextseq_trim`, `length_trim`), a prebuilt Bismark
index (`bismark_index`), hisat2 splice sites (`known_splices`), the bwameth
mem2 index variant (`use_mem2`), the optional branches (`taps`,
`run_qualimap`, `run_preseq`, `run_targeted_sequencing`, `collecthsmetrics`,
`bamqc_regions_file`, `target_regions_file`) and MethylDackel options
(`all_contexts`, `merge_context`, `min_depth`, `ignore_flags`, `methyl_kit`).
Optional branches (`taps`, `run_qualimap`, `run_preseq`,
`run_targeted_sequencing`, `collecthsmetrics`) are off by default, matching
the upstream defaults. One documented divergence: `comprehensive` defaults
to `true` (upstream: `false`) because the port's DAG consumes the merged
(`--comprehensive`) Bismark methylation-call outputs — with the per-strand
split files the declared rule outputs would be left unmoved.

### Single-end mode

Upstream decides endedness per sample from the samplesheet (`fastq_2`
absent ⇒ `single_end`); this port reproduces that through the engine's
metadata binding (`{meta.*}`, oxo-flow >= 0.17.0). To run single-end
samples:

1. Add each sample's endedness to the metadata samplesheet
   (`metadata/samples.tsv`, TSV; `#` comments allowed; a sample **without a
   row stays paired-end**):

   ```tsv
   sample	endedness
   S1	PE
   S3	SE
   ```

2. Enable it in `main.oxoflow` (both switches are off by default, so the
   default configuration is byte-identical to a paired-end-only run):

   ```toml
   [workflow]
   metadata_file = "metadata/samples.tsv"   # uncomment

   [config]
   single_end_mode = true
   ```

3. Ship `raw/<sample>_R1.fastq.gz` (no `_R2` file) for each single-end
   sample and run as usual:

   ```bash
   oxo-flow run main.oxoflow -j 8
   ```

Each single-end sample then runs the upstream single-end variant of the
chain — FastQC on `{sample}.fastq.gz`, TrimGalore SE (`--cores cpus-3`,
R1-side clipping only), `bismark` SE (no `--minins/--maxins`),
`deduplicate_bismark -s`, `bismark_methylation_extractor -s` (no
`--no_overlap`/`--ignore_r2`/`--ignore_3prime_r2`), `bismark2report` on
`*_SE_report.txt` and MultiQC with the SE report names — while the
paired-end rules stay off for that sample (`{meta.endedness} != 'SE'`
when-gates, exactly the upstream `!meta.single_end` gates). The
bwameth/bwamem aligner branches support mixed PE/SE cohorts too: the
per-sample reads selection and the shared downstream rules
(`samtools_sort`, `bismark_coverage2cytosine`, `bismark_summary`,
`bedtools_intersect`, `multiqc`) pick the SE files per sample at run time.
Bismark is the only end-to-end SE live-tested branch; upstream's SE support
is unconditional across all four aligners, so the same gates apply.

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
| FASTQC | `fastqc` / `fastqc_se` | fastqc 0.12.1 | identical command; `--memory` derived from task resources. The `_se` variant runs the single-end chain (reads named `{sample}.fastq.gz`, outputs `{sample}_fastqc.*`) when `single_end_mode` is on |
| TRIMGALORE | `trimgalore` / `trimgalore_se` | trim-galore 0.6.10, cutadapt 4.9, pigz 2.8 | identical command incl. library-preset clipping and `--cores` clamp. The `_se` variant is the upstream SE module: R1-side clipping only, `--cores cpus-3` clamped to [1, 8] |
| BISMARK_GENOMEPREPARATION | `bismark_genomepreparation` | bismark 0.25.1, gzip 1.13 | `--bowtie2` (or `--hisat2` for bismark_hisat, `--slam` for slamseq); runs when no prebuilt index is supplied (upstream default) |
| GUNZIP | (merged into the index-preparation shells) | gzip 1.13 | a gzipped reference FASTA is decompressed before index building, as in the upstream fasta_index_methylseq subworkflow |
| UNTAR | `bismark_untar` | tar 1.34 | active only when a prebuilt `--bismark_index` archive is supplied; strips a single top-level directory, like upstream |
| BISMARK_ALIGN | `bismark_align` / `bismark_align_se` | bismark 0.25.1 | identical flag order (pbat/non_directional/unmapped/score_min/local/minins/maxins/multicore); hisat2 splice sites via `known_splices` (see deviations). The `_se` variant drops `--minins`/`--maxins` (upstream `!meta.single_end` gate), keeps `--multicore` and the hisat2 rename |
| BISMARK_DEDUPLICATE | `bismark_deduplicate` / `bismark_deduplicate_se` | bismark 0.25.1 | identical command (`-s` for single-end, `-p` paired-end); skipped with `skip_deduplication`/`rrbs` like upstream |
| SAMTOOLS_SORT | `samtools_sort` | samtools 1.22.1, htslib 1.22.1 | upstream prefix `${sample}.deduplicated.sorted`; takes the SE deduplicated BAM when the sample is single-end |
| SAMTOOLS_INDEX | `samtools_index` | samtools 1.22.1 | identical command |
| BISMARK_METHYLATIONEXTRACTOR | `bismark_methylationextractor` / `bismark_methylationextractor_se` | bismark 0.25.1 | identical flag order on the **deduplicated** BAM; `--multicore`/`--buffer_size` derived from resources. The `_se` variant uses `-s` and drops `--no_overlap`/`--ignore_r2`/`--ignore_3prime_r2` (upstream `!meta.single_end` gate) |
| BISMARK_COVERAGE2CYTOSINE | `bismark_coverage2cytosine` | bismark 0.25.1 | off by default; runs with `cytosine_report`/`nomeseq`; takes the SE coverage file when the sample is single-end |
| BISMARK_REPORT | `bismark_report` / `bismark_report_se` | bismark 0.25.1 | bismark2report run with the four reports co-located, as in the upstream workdir; the `_se` variant feeds the `*_SE_report.txt` files |
| BISMARK_SUMMARY | `bismark_summary` | bismark 0.25.1 | bismark2summary with upstream BAM-name arguments; per-sample SE/PE detection via a `[ -f ]` probe on the SE alignment report (no per-sample binding; see deviations) |
| BWAMETH_INDEX | `bwameth_index` | bwameth 0.2.9 | `bwameth.py index`, or `index-mem2` with `use_mem2`; index dir `refs/BwamethIndex` |
| BWAMETH_ALIGN | `bwameth_align` | bwameth 0.2.9 | identical command (reference symlink re-created in the index dir, `samtools view -bhS`); one or two reads are passed positionally per sample (SE/PE from its metadata row) |
| BWA_INDEX | `bwa_index` | bwa 0.7.19 | `bwa index -p`; upstream sizes memory dynamically (5.37x FASTA) — the port uses a fixed 4 threads/24G/24h budget (see deviations) |
| BWA_MEM | `bwa_mem` | bwa 0.7.19, samtools 1.22.1 | upstream `sort_bam = true`: `bwa mem \| samtools sort`; index prefix found by globbing `*.amb`; one or two reads passed positionally per sample (SE/PE) |
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
| QUALIMAP_BAMQC | `qualimap_bamqc` / `qualimap_bamqc_alt` | qualimap 2.3 | `-p non-strand-specific`, `--gff` with `bamqc_regions_file`, `_JAVA_OPTIONS` tmpdir; `--collect-overlap-pairs` only for paired-end samples (upstream `!meta.single_end` gate) |
| PRESEQ_LCEXTRAP | `preseq_lcextrap` / `preseq_lcextrap_alt` | preseq 3.2.0 | `-verbose -bam`, `-pe` only for paired-end samples (upstream `!meta.single_end` gate); the `*.command.log` is preseq's own stderr (see deviations) |
| PICARD_CREATESEQUENCEDICTIONARY | `picard_createsequencedictionary` | picard 3.4.0 | runs only when `collecthsmetrics` is requested, like upstream |
| PICARD_BEDTOINTERVALLIST | `picard_bedtointervallist` | picard 3.4.0 | output named `target_regions.intervallist` (fixed name; see deviations) |
| BEDTOOLS_INTERSECT | `bedtools_intersect` (+ `_bwameth`, `_chg`, `_chh`) | bedtools 2.31.1 | prefix = the bedGraph basename, suffix `targeted.bedGraph`, as upstream; the bismark variant takes the SE bedGraph when the sample is single-end |
| PICARD_COLLECTHSMETRICS | `picard_collecthsmetrics` / `picard_collecthsmetrics_alt` | picard 3.4.0 | same intervals for bait and target; excluded on the taps/bwamem branches, like the upstream rastair error |
| SAMTOOLS_FAIDX | `samtools_faidx` | samtools 1.22.1, htslib 1.22.1, gzip 1.13 | stages the reference at `refs/FastaRef/reference.fa`; upstream gate (bwameth/bwamem/collecthsmetrics) reproduced |
| MULTIQC | `multiqc` / `multiqc_bwameth` / `multiqc_bwamem` | multiqc 1.32 | one rule per aligner branch; same search space as upstream (fastqc zips, trimgalore logs, samtools stats/flagstat/idxstats, picard metrics + qualimap/preseq/HS extras), plus the single-end report names (`{sample}_fastqc.zip`, `{sample}.fastq.gz_trimming_report.txt`, `*_SE_report.txt`, ...) which are picked up exactly when present; the methyldackel/rastair outputs are not fed to MultiQC, exactly like upstream |
| softwareVersionsToYAML + collectFile | `multiqc_versions` | — | upstream extracts versions at runtime; port pins the module versions statically |
| CAT_FASTQ | `cat_fastq_r1` / `cat_fastq_r2` | coreutils 9.5 | ported via the engine's `input_groups` primitive (issue #227, oxo-flow >= 0.17.0): one instance per sample with >1 fastq pair, R1s and R2s concatenated into `results/fastq/<sample>_R{1,2}.fastq.gz`; single-pair samples pass through unchanged (downstream falls back to the raw pair). Upstream's single process is split into two rules (one per read); see deviations |

Additional notes: single-end samples are supported via the engine's
metadata binding (see Usage); `--save_*` / `publish_dir_mode` params are N/A
(oxo-flow publishes every declared output); per-process `withName:` resource
overrides are baked into `[rules.resources]` (upstream labels
process_single/low/medium/high + BISMARK_ALIGN 8d / DEDUPLICATE 2d /
METHYLATIONEXTRACTOR 1d time limits).

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
12. **CAT_FASTQ as two rules + a shell fallback** — upstream runs one
    `CAT_FASTQ` process on `ch_samplesheet.multiple` and mixes its outputs
    with `ch_samplesheet.single`. The port splits the merge into
    `cat_fastq_r1` / `cat_fastq_r2` (the engine's `input_groups` allows one
    pattern per rule — see the docs' "Input Groups" section), each
    instantiating only for samples whose raw files carry a unit segment
    (`<sample>_<unit>_R{1,2}.fastq.gz`), and the downstream
    `fastqc`/`trimgalore` rules declare both the concatenated pair
    (`optional = "any"`) and the raw pair, using the concatenated one when
    it exists and the raw pair otherwise. Effective commands and outputs
    match upstream (a sample named with a single unit is copied through —
    `cat` of one file — which is the same content as the pass-through).
    Needs oxo-flow >= 0.17.0; on older engines the `cat_fastq` rules fail
    loudly instead of writing empty fastqs.
13. **Single-end via engine metadata** — upstream decides `single_end` per
    sample from the samplesheet (`fastq_2` absent); the port binds it with
    the engine's metadata feature (`[workflow] metadata_file` +
    `{meta.endedness}`, oxo-flow >= 0.17.0) instead of a samplesheet, gated
    on `config.single_end_mode` (off by default — the default run is
    unchanged). Paired-end rules carry a `{meta.endedness} != 'SE'` when-gate
    (a sample without a metadata row renders `'' != 'SE'` and stays
    paired-end) and six `*_se` variant rules reproduce the upstream SE
    modules verbatim (`-s` extractor/dedup, no `--minins`/`--maxins`, no
    `--collect-overlap-pairs`, no `-pe`, R1-side-only clipping, SE output
    names). The engine bakes the metadata literals into the `when`
    conditions and the per-sample shell selections at plan time.
14. **Per-sample SE detection in cohort rules** — `bismark_summary` and
    `multiqc` run once over the whole cohort (no per-sample binding), so
    they cannot read `{meta.endedness}` per sample. `bismark_summary`
    probes for each sample's SE alignment report with `[ -f ]` and picks the
    SE or PE BAM names accordingly, and the multiqc search loops list the SE
    report names, which are picked up exactly when present. Same effective
    behavior as the upstream per-sample `meta.single_end` branching.

## Test

Run the acceptance test (validate + lint + dry-run, plus the single-end
routing dry-run on engines with metadata support — skipped with a notice on
older engines):

```bash
bash test/run.sh
```

## License

Apache-2.0. Copyright (c) 2026 oxo-flow-community. Upstream attribution in
[NOTICE.md](NOTICE.md). The upstream nf-core/methylseq pipeline is MIT
licensed; its license is included verbatim at `LICENSE.upstream`.
