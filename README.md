# HTCondor-processing

Snakemake workflow that runs CMSSW RAW2RECO reconstruction over CMS Open Data
(2013 pPb/heavy-ion `HIRun2013` datasets) on CERN's HTCondor batch system,
inside the `cmssw_5_3_8_hi_patch2-slc5_amd64_gcc462` container image.

Each job takes a chunk of input RAW files, runs `cmsDriver.py` + `cmsRun` to
produce RECO output, and writes results + logs to EOS.

Run from afs!

## Prerequisites

- An lxplus account with AFS home + EOS storage.
- [pixi](https://pixi.sh) installed (manages the Python/Snakemake/HTCondor
  environment in `.pixi/`, resolved from `pixi.toml`/`pixi.lock`).

## One-time environment setup
setup kerberos token
Bind the directory you're running the script from in apptainer-args
Bind the directory results go to in apptainer-args

Apptainer needs a cache/tmp location with more space than AFS's small home
quota, and EOS's FUSE mount doesn't support the hard links Apptainer's build
step uses, so cache and tmp need to live in different places. 
Add this to `~/.bashrc` (must persist across logins: lxplus load-balances you to a
different host, e.g. `lxplus919` vs `lxplus982`, each session):

```bash
export APPTAINER_CACHEDIR=/your/eos/dir/cache #/eos/home-a/aalatalo/apptainer/cache
export APPTAINER_TMPDIR=/your/eos/dir/tmp   #/eos/home-a/aalatalo/apptainer/tmp
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
```

Install the pixi environment once:

```bash
pixi install
```

## Configuration

`config.yaml` - dataset/processing parameters:

| Key | Meaning |
|---|---|
| `events` | Events per job (`-1` = all) |
| `files_per_job` | Input files per HTCondor job (chunk size) |
| `files_amount` | Cap on total input files used (`-1` = all) |
| `image` | CMSSW container image (`docker://...`) |
| `eos_path` | Output base directory on EOS, must be covered by an `apptainer-args --bind` in `profiles/config.yaml`, or output silently vanishes |
| `global_tag` | CMSSW GlobalTag for conditions/calibration |
| `eos_mgm_url` | xrootd redirector prefixed onto input file paths |
| `input_file_list` | Which file under `files/` to process (see below) |

`files/*.txt` - one CMS Open Data RAW file path per line, grouped by dataset
(`PAMinBias2.txt`, `PAHighPt.txt`, etc). `input_file_list` selects one of
these.

`profiles/config.yaml` - Snakemake/HTCondor executor settings (job resources,
`apptainer-args` container binds, HTCondor classads).



## Running

Notice that running this script should be done from afs.

From the project root, in a `tmux`/`screen` session (a plain SSH session
dying mid-run kills the workflow)

```bash
pixi run snakemake --workflow-profile profiles --executor htcondor --software-deployment-method apptainer
```

(`executor`, `jobs`, and `software-deployment-method` are all set as defaults
in `profiles/config.yaml`, so they don't need to be passed on the CLI.)

Output lands under `{eos_path}/{dataset_name}/files/` (RECO `.root` files)
and `{eos_path}/{dataset_name}/logs/` (cmsRun logs + processed-file lists).


## For dataset size runs
profiles/config.yaml
- set correct amount of jobs, cores, job runtime ,memory and disk in profiles/config
- store full list of filenames in files/  (note format of /eos/opendata/cms/upload or /eos/opendata/cms/upload/hidata)
- Bind the directory you're running the script from (apptainer-args)
- Bind the directory results want to be stored (apptainer-args)

config.yaml (root)
- set events and files to -1, files per job should be 3ish (PA) or 1 (PP)
- set image to CMSSW_5_3_8_HI_patch2 (PA) or CMSSW_5_3_8_patch3 (PP)
- set eos_path to same as the one bound in profiles/config
- set input_file_list to dataset to be processed