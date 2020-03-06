## How to GLOBUS CLI

* Download and copy `globus_transfer.sh` to `~/bin/globus_transfer`

### dirmode transfer

*   Default
*   Transfer contents from a single directory

*   Target directory (`-t`) will be created in recursive manner as long as path is writable by an user.
*   Best practice is to specify absolute, valid, and empty target path.

```sh
globus_transfer \
    -i run1_dirmode \
    -s /tier2/verhaak-lab/tape_archived/cgp_sra_v20191117 \
    -t /fastscratch/amins/dirmode/dump
```

### Wait until transfer is complete

*   Useful to include globus transfer in workflows using snakemake, nextflow, etc.
*   Only available for directory level transfers

```sh
globus_transfer \
    -w YES \
    -i run2_dirmode \
    -s /tier2/verhaak-lab/tape_archived/cgp_sra_v20191117 \
    -t /fastscratch/amins/dirmode/dump2
```

***

### BATCH mode

*   Switch to batch mode by `-m BATCH`
*   Use relative path to source and target: One file per row

*   Absolute path to source and intended target location

```
/tier2/verhaak-lab/dir1/subdir/file1.tsv /fastscratch/amins/batchmode/file1.tsv
/tier2/verhaak-lab/dir2/subdir/file2.tsv /fastscratch/amins/batchmode/file2.tsv
/tier2/verhaak-lab/dir3/subdir/file3.tsv /fastscratch/amins/batchmode/file3.tsv
```

*   Relative path: Save this file as `run3_batchmode.tsv`

```
dir1/subdir/file1.tsv file1.tsv
dir2/subdir/file2.tsv file2.tsv
dir3/subdir/file3.tsv file3.tsv
```

*   To begin batch transfer:

```sh
globus_transfer \
    -i run3_batchmode \
    -s /tier2/verhaak-lab/tape_archived \
    -t /fastscratch/amins/batchmode \
    -m BATCH \
    -f /home/amins/globus/batch/run3_batchmode.tsv
```

***

### Mirror source and target destinations

#### ☠ DANGER ☠ ##

*   Make sure target path is not parent home or work dir.
*   Best practice is to **specify absolute, valid, and empty target path**

```sh
globus_transfer \
    -d YES \
    -i run4_dirmode_mirror \
    -s /tier2/verhaak-lab/tape_archived/cgp_sra_v20191117 \
    -t /fastscratch/amins/dirmode
```

END

