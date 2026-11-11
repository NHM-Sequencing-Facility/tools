# SOP: Running EPI2ME wf-amplicon on the NHM HPC

- [EPI2ME page](https://epi2me.nanoporetech.com/epi2me-docs/workflows/wf-amplicon/)
- [GitHub page](https://github.com/epi2me-labs/wf-amplicon)
- [Amplicon sequencing from DNA using SQK-RBK114](https://nanoporetech.com/document/rapid-sequencing-v14-amplicon-sequencing-sqk-rbk114-24-or-sqk#downstream-analysis-using-epi2me)

NHM Sequencing Facility | 2026-11-11 | Author: Dan Parsons

## Purpose and scope
This SOP takes you from a first test run to analysing your own ONT amplicon data with EPI2ME wf-amplicon on the NHM HPC, using one script you copy, edit and submit with `sbatch`.

wf-amplicon builds one consensus sequence per barcode from ONT reads of **haploid** amplicons (de novo consensus mode). It is not suitable for diploid samples or for mixed communities such as metabarcoding / 16S.

Everything except your run script and its outputs is shared and maintained centrally: Nextflow, the workflow code (pinned at v1.2.2) and its software containers. You never install anything yourself.

## Before you start
You must have an NHM HPC account with MBL group permissions (`dg-mbl-mbl-group-rw`).

## Step 1 - First-time test run on the demo data
Do this once before analysing real data. It confirms your account, permissions and the shared install all work, and takes about 2 minutes once the job starts.

1. Make a working folder and copy the template into it (in this case in your `/home/$USER/` directory):
    ```bash
    mkdir -p ~/wf-amplicon_runs && cd ~/wf-amplicon_runs
    cp /hpc/groups/mbl-group/ont/epi2me/templates/run_wf-amplicon.sh run_wf-amplicon.sh
    ```

2. Set a run name. 
`FASTQ` already points at the demo data, so `RUN_NAME` is the only edit. Open up YOUR COPY of run_wf-amplicon.sh and edit `RUN_NAME` - The outputs folder (`/hpc/groups/mbl-group/ont/outputs`) is shared by the whole facility, so every run needs a `RUN_NAME` nobody else has used. The script refuses to start without one.

3. Submit it:
    ```bash
    sbatch run_wf-amplicon.sh
    ```

SLURM replies `Submitted batch job <jobid>`. The job log is written to `wf-amplicon_<jobid>.out` in the folder you ran the script from.

## Step 2 - Monitor the job and check the test
A successful test ends with a `Finished.` line in the log file, reports **2 consensus sequences** (one per demo barcode), and the output file(s) location.

The last lines of a good run look like this:

```text
[c0/4d4b1d] Submitted process > publish (8)

Finished. Report: /hpc/groups/mbl-group/ont/outputs/demo_test_<user>/wf-amplicon-report.html
Consensus sequences: 2 in /hpc/groups/mbl-group/ont/outputs/demo_test_<user>/all-consensus-seqs.fasta
```

You should see `wf-amplicon-report.html`, `all-consensus-seqs.fasta`, one folder per barcode and an `execution/` folder. If instead the log ends with `ERROR`, please seek support before proceeding further.

## Step 3 - Run your own data
1. Edit the `EDIT ME` block in `run_wf-amplicon.sh`. Only `RUN_NAME` and `FASTQ` are required; anything left `""` uses the workflow default:

```bash
RUN_NAME="2026-11-12_coi-plate3_dp"           # required, unique
FASTQ="/path/to/run/fastq_pass"               # see input layouts below
SAMPLE_SHEET="/path/to/sample_sheet.csv"      # optional; If left empty then samples are named by their barcodes (e.g. barcode01)

READS_DOWNSAMPLING_SIZE=""                    # default 1500
MIN_READ_LENGTH=""                            # default 300
MAX_READ_LENGTH=""                            # default none
MINIMUM_MEAN_DEPTH=""                         # default 30

EXTRA_ARGS=()                                 # any other workflow option, see below
```

2. Submit and monitor exactly as above for demo data
### Input layouts

`FASTQ` can be any one of:
- a folder of barcode sub-folders, e.g. MinKNOW's `fastq_pass/` containing `barcode01/`, `barcode02/` … (the usual case; `unclassified/` is skipped);
- a single folder of FASTQ files from one sample;
- a single `.fastq` / `.fastq.gz` file.

> Files can be gzipped or not. Point at the folder, not at individual files inside it.

### Sample sheet (optional)
A CSV that names samples after something more useful than their barcode. `alias` must be unique, with no spaces. `type` must be one of `test_sample`, `positive_control`, `negative_control` or `no_template_control`.

```csv
barcode,alias,type
barcode01,NHMUK010123456,test_sample
barcode02,NHMUK010123457,test_sample
barcode96,NTC_plate3,no_template_control
```

### Settings
The defaults suit most amplicons of 500–5,000 bp.

| Script variable | Default | What it does / when to change |
| --- | --- | --- |
| `READS_DOWNSAMPLING_SIZE` | 1500 | Reads used per barcode after filtering. 1500 gives >150× for most amplicons; `0` uses all reads (more memory, rarely better). |
| `MIN_READ_LENGTH` | 300 | Shorter reads are dropped. **Lower it for amplicons under ~350 bp**, or every read is discarded. |
| `MAX_READ_LENGTH` | none | Longer reads are dropped. Set ~20% above the amplicon length to remove concatemers. |
| `MINIMUM_MEAN_DEPTH` | 30 | A consensus with lower mean depth fails QC and is not reported. Lower (e.g. 20) for low-yield barcodes, accepting less confidence. |

Other options go in `EXTRA_ARGS`, e.g.:

| Option | Default | When to use |
| --- | --- | --- |
| `--min_read_qual` | 10 | Lower (e.g. 7) only for degraded / low-quality runs |
| `--min_n_reads` | 40 | Barcodes with fewer reads after filtering are skipped |
| `--force_spoa_length_threshold` | 2000 | Choose the assembler, see below |
| `--reference <fasta>` | none | Switches to variant-calling mode against known reference sequences |

Example: `EXTRA_ARGS=(--min_read_qual 7 --min_n_reads 20)`.

### miniasm or spoa?

Every sample is assembled with **miniasm first**. The workflow switches that sample to **spoa** if miniasm fails, if its longest contig is not longer than `--force_spoa_length_threshold` (2,000 bp by default), or if the miniasm consensus fails QC. So amplicons under 2 kb, which covers most barcoding work, effectively always end up with spoa.

To see which method produced each consensus, check the **method** column of the QC table in the HTML report (`miniasm_1`, `spoa_1`, …). Any `deNovoPipeline_spoa:` lines in the job log mean at least one sample fell back to spoa.

### Job size

The default job (12 CPUs, 40 GB, up to 24h on `day`) handles a full 96-barcode plate. Leave the `#SBATCH` lines alone unless a job runs out of time or memory.

## Step 4 - Review results and clean up
Open the HTML report first, then pick up the consensus sequences. Delete your scratch folder (/hpc/scratch/$USER/nextflow/wf-amplicon/<RUN_NAME>) once you're happy.

| File in `outputs/<RUN_NAME>/` | What it is |
| --- | --- |
| `wf-amplicon-report.html` | Read counts, length/quality, coverage and consensus QC per barcode. Download and open in a browser. |
| `all-consensus-seqs.fasta` | Every passing consensus in one FASTA, headed by sample alias |
| `<alias>/consensus/consensus.fastq` | Consensus for one sample, with per-base quality |
| `<alias>/alignments/` | Reads re-aligned to the consensus (BAM + index) |
| `execution/` | Nextflow report, timeline, trace and `nextflow.log` (send these if asking for help) |

Barcodes missing from `all-consensus-seqs.fasta` either had too few reads (`--min_n_reads`) or failed consensus QC (mean depth under `MINIMUM_MEAN_DEPTH`, or too few primary alignments). The report says which.

> When the results look right, free the scratch space:
> 
> ```bash
> rm -rf /hpc/scratch/$USER/nextflow/wf-amplicon/<RUN_NAME>
> ```



## Notes for maintainers

Users can skip this section. The install is pinned and locally patched. Change it only deliberately, then re-run the demo test (Step 1) before telling users.

- **Versions:** Nextflow 25.10.4 + OpenJDK 17 in `epi2me/envs/nextflow`; wf-amplicon v1.2.2 in `epi2me/workflows/wf-amplicon_v1.2.2` (read-only). The run template sets `NXF_SYNTAX_PARSER=v1`, which v1.2.2 needs.
- **Local patch:** v1.2.2 has `label = "…"` (with `=`) on the `spoa`, `miniasm` and `racon` processes in `modules/local/de-novo.nf`. Nextflow 25.10+ ignores that form, so those steps ran without containers and failed. The shared clone is patched to `label "…"`, and `git -C <clone> diff` shows the change. The upstream repo is no longer maintained, so any fresh clone needs the same fix:

    ```bash
    F=<clone>/modules/local/de-novo.nf
    chmod u+w "$F" && sed -i -E 's/^(\s*)label = "/\1label "/' "$F" && chmod a-w "$F"
    ```

- **Containers:** pre-pulled `.sif` images in `epi2me/singularity_cache/`, one each for `wf-common`, `wf-amplicon` and `medaka`. Runs never download images.
- **Cluster settings:** `epi2me/configs/nhm_hpc.config` runs every task inside the user's single SLURM job, sized from its `#SBATCH` request (minus 4 GB for Nextflow).
- **Upgrading:** set the new tag as `WF_VERSION` and re-run `setup/setup_wf-amplicon.sh` (it pulls the new containers too). Apply any needed patch, run the demo, then update `WF_DIR` in the template. Users' existing copies keep pointing at the old version until they re-copy.
