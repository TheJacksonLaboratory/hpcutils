#!/bin/bash

## Transfer files using globus CLI
## Author: Samir Amin, @sbamin

# usage
show_help() {
cat << EOF

Script to start and monitor file transfers using globus.
Read doc at https://docs.globus.org/cli/reference/transfer/ for command line options.

 Currently supports only intra-institute transfers, i.e., GLOBUS EP id is identical for source and target path.
 Default mode is single: This prefers directory level recursive copy, a single file path may not work.

 Requires globus endpoint activation while transfer session is alive:
 Read https://docs.globus.org/api/transfer/endpoint_activation/

 On completion, globus task wait may quit without any informative msg but with the correct exit code, 
 i.e., exit 0 for successful download.

 ####
 WARN: Overwrites files, dirs with identical names on the target path
 WARN: Transfer skips md5 based verification on the target path, i.e., --sync-level mtime is hardcoded.
 ####

 NB: /tier2/verhaak-lab/ is globus equivalent of verhaak-dev:/verhaak-temp/ path. The latter path will not work in globus.

Usage: ${0##*/} -i <sample_id> -g <globus ep> -s <path to source dir> -t <path to destination dir>

    	-h  display this help and exit
        -i  sample id or label used with globus label directive (required)
        -g  globus EP id matching institute wide license: Defaults to GLOBUSEP env variable
        -s  globus compatible full path to source directory (required)
        -t  globus compatible full path to target destination (required)
        -m  transfer mode: BATCH (requires batchfile) or single directory/file (default)
        -f  absolute path to batchfile: required if -m BATCH ; Note that batchfile must have relative paths to -s and -t
        -w  run globus task wait (default: no). YES to enable. Useful for running transfer in an non-interactive session.
        -d  mirror image (Default: NO) - Use at your own risk! Not available with -m BATCH.

Example recursive transfer of files from tier2 to /fastscratch space for all of sampel1 files and subdirs.
${0##*/} -i sample1 -s /tier2/verhaak-lab/mydir/sample1 -t /fastscratch/foo/temp/sample1

Example batch mode transfer: Note that -s and -t are used to prepend to relative paths specified in batchfile.
${0##*/} -i mybatch -s /tier2/verhaak-lab/mydir -t /fastscratch/foo/temp -m BATCH -f /home/foo/batchmode/batch1.tsv

EOF
}

if [[ $# -lt 3 ]] || [[ $1 == "--help" ]];then show_help;exit 1;fi

while getopts "i:g:s:t:m:f:w:d:h" opt; do
    case "$opt" in
        h) show_help;exit 0;;
        i) SAMPLEID=$OPTARG;;
        g) MYGLOBUSEP=$OPTARG;;
        s) SRC=$OPTARG;;
        t) DEST=$OPTARG;;
		m) MODE=$OPTARG;;
		f) BATCHFILE=$OPTARG;;
		w) TASKWAIT=$OPTARG;;
		d) DELMODE=$OPTARG;;
       '?') show_help >&2 exit 1 ;;
    esac
done

if [[ -z "${SAMPLEID}" ]] || [[ -z "${SRC}" ]] || [[ -z "${DEST}" ]]; then
    echo -e "ERROR: Invalid required arguments\\nOne or more of -i, -s, or -t is empty\\nSAMPLEID: ${SAMPLEID}\\nSRC: ${SRC}\\nDEST: ${DEST}\\nWork dir: $(pwd)\\n" >&2
    show_help
    exit 1
fi

## Defaults to GLOBUSEP env variable if -g is not specified or empty
MYGLOBUSEP=${MYGLOBUSEP:-"$GLOBUSEP"}
TASKWAIT=${TASKWAIT:-"no"}

#### check globus command ####
CHK_GLOBUS="$(command -v globus)"
exit_chk_globus=$?

if [[ "$exit_chk_globus" != 0 ]]; then
    echo -e "\nERROR: globus command not found in the current enviornment\nSkipping transfer\n" >&2
    exit 1
fi

#### BE CAREFUL HERE ####
## enable --delete flag: will mirror destination to source dir and DELETE all 
## other contents on destination.
DELMODE=${DELMODE:-"NO"}

## Override user prompt with env variable, GLOBUS_DELMODE set to YES
## DANGER ##
## Make sure you are certain of target path is what you wish and not a parent home or work dir else
## this will delete all of contents except those present in source directory.
GLOBUS_DELMODE="${GLOBUS_DELMODE:-"NO"}"

if [[ -z "${MYGLOBUSEP}" ]]; then
    echo -e "ERROR: Invalid GLOBUSEP defined at -g\\nGLOBUSEP: ${MYGLOBUSEP}\\nGLOBUSEP is required unless you are using VerhaakEnv\\nWork dir: $(pwd)\\n" >&2
    show_help
    exit 1
fi

if [[ "${MODE}" != "BATCH" ]]; then
    echo -e "INFO: MODE is not BATCH but instead $MODE\nDefaults to recursive, directory based globus transfer\n"
	TSTAMP="$(date +%d%b%y_%H%M%S%Z)"
	GLOBUS_TASK_PREFIX="$(printf "globus_%s_%s" "${SAMPLEID}" "${TSTAMP}")"

    if [[ "$GLOBUS_DELMODE" == "YES" ]]; then
        echo -e "\n#### WARN ####\nEnabling DELMODE to YES because you have set an env variable GLOBUS_DELMODE to ${GLOBUS_DELMODE}\n$SRC will be synced to $DEST\nTHIS WILL DELETE EXTRA CONTENTS ON DEST: $DEST\n"
        echo "Ctrl C to abort in 5 seconds"
        sleep 10

		CMD_TRANSFER=$(printf "globus transfer --label %s_dirmode --recursive --delete --no-verify-checksum --sync-level mtime %s:%s %s:%s >| %s.uuid.txt" "${SAMPLEID}" "${MYGLOBUSEP}" "${SRC}" "${MYGLOBUSEP}" "${DEST}" "${GLOBUS_TASK_PREFIX}")        
	elif [[ "$DELMODE" == "YES" ]]; then
		echo -e "\n#### WARN ####\nEnabling DELMODE to $DELMODE\n$SRC will be synced to $DEST\nTHIS WILL DELETE EXTRA CONTENTS ON DEST: $DEST\n"
		read -t 5 -erp "Are you sure? Type YES to consent and run globus transfer..." USERFBK
		USERFBK=${USERFBK:-"NO"}

		if [[ "${USERFBK}" == "YES" ]]; then
			CMD_TRANSFER=$(printf "globus transfer --label %s_dirmode --recursive --delete --no-verify-checksum --sync-level mtime %s:%s %s:%s >| %s.uuid.txt" "${SAMPLEID}" "${MYGLOBUSEP}" "${SRC}" "${MYGLOBUSEP}" "${DEST}" "${GLOBUS_TASK_PREFIX}")
		fi
	else
		CMD_TRANSFER=$(printf "globus transfer --label %s_dirmode --recursive --no-verify-checksum --sync-level mtime %s:%s %s:%s >| %s.uuid.txt" "${SAMPLEID}" "${MYGLOBUSEP}" "${SRC}" "${MYGLOBUSEP}" "${DEST}" "${GLOBUS_TASK_PREFIX}")
	fi
else
    echo -e "INFO: MODE is BATCH, defaults to batch mode transfer\nSeeking batch file\n"

    if [[ ! -s "${BATCHFILE}" ]]; then
    	echo -e "\nERROR: Batchfile at $BATCHFILE is not accessible or zero-byte size.\nQuit transfer\n" >&2
    	show_help
    	exit 1 
    fi

	TSTAMP="$(date +%d%b%y_%H%M%S%Z)"
	GLOBUS_TASK_PREFIX="$(printf "globus_%s_%s" "${SAMPLEID}" "${TSTAMP}")"
	CMD_TRANSFER=$(printf "globus transfer --label %s_batchmode --batch --no-verify-checksum --sync-level mtime %s:%s/ %s:%s/ < %s >| %s.uuid.txt" "${SAMPLEID}" "${MYGLOBUSEP}" "${SRC}" "${MYGLOBUSEP}" "${DEST}" "${BATCHFILE}" "${GLOBUS_TASK_PREFIX}")

	echo -e "\n##### NOTE #####\nBATCH mode will use relative paths to copy files\nThat is it will prepend $SRC to source and $DEST to target paths given in batchfile\n\n"
fi

printf '\nINFO: %s\nCommand to run\n\n%s\n\nWork dir: %s\n\nCTRL C to abort!\n' "${TSTAMP}" "${CMD_TRANSFER}" "$(pwd)"
sleep 5

## begin globus transfer, capture task ID, and then execute wait command to wait until transfer is complete or fails.
eval "${CMD_TRANSFER}"
exitstat1=$?

if [[ "${exitstat1}" != 0 ]]; then
    TSTAMP="$(date +%d%b%y_%H%M%S%Z)"
    printf '\nERROR: %s\nglobus transfer for %s failed to start with exit code: %s\nCommand executed:\n%s\nGlobus Task ID: not assigned\nSee log file at %s/globus_%s.uuid.txt\nEND\n' "${TSTAMP}" "${SAMPLEID}" "${exitstat1}" "${CMD_TRANSFER}" "$(pwd)" "${SAMPLEID}" >| "${GLOBUS_TASK_PREFIX}"_failed.log

    exit "${exitstat1}"
else
    echo "Transfer has started"
	sleep 1

	## monitor globus transfer and exit accordingly
	TSTAMP="$(date +%d%b%y_%H%M%S%Z)"
	GLOBUS_TASKID="$(grep -Eo "[a-z0-9-]{36}" "${GLOBUS_TASK_PREFIX}".uuid.txt)"

	echo -e "\nTo check progress, run\n"
	printf "globus task show %s" "${GLOBUS_TASKID}"
	echo -e "\n\nTo cancel background transfer, run following command\nPS: CTRL C will NOT stop the transfer now.\n"
	printf "globus task cancel %s" "${GLOBUS_TASKID}"
	echo -e "\n"
fi

#### Enable globus task wait for non-interactive session and emit valid exit status.

if [[ "${TASKWAIT}" == "YES" ]]; then
	## start wait command
	echo -e "\n\nStarting globus task wait\nPolling at every 30 seconds\n"
	echo -e "\nPrint dot every 30 seconds until transfer is complete or exit due to an error.\n"
	## globus used set -e internally and quits if exit code is non-zero: So workaround is to quit with exit 1 if it fails
	globus task wait --polling-interval 30 -H "${GLOBUS_TASKID}" && exitstat2=0 || exitstat2=1

	## capture exit code and exit program accordingly
	if [[ "${exitstat2}" != 0 ]]; then
	    TSTAMP="$(date +%d%b%y_%H%M%S%Z)"
	    printf '\nERROR: %s\nglobus transfer for %s failed with exit code: %s\nCommand executed:\n%s\nGlobus Task ID: %s\nWork dir: %s\nEND\n' "${TSTAMP}" "${SAMPLEID}" "${exitstat2}" "${CMD_TRANSFER}" "${GLOBUS_TASKID}" "$(pwd)" |& tee -a "${GLOBUS_TASK_PREFIX}"_failed.log

	    exit "${exitstat2}"
	else
	    TSTAMP="$(date +%d%b%y_%H%M%S%Z)"
	    printf '\nINFO: %s\nglobus transfer for %s completed with exit code: %s\nCommand executed: %s\nGlobus Task ID: %s\nWork dir: %s\nEND\n' "${TSTAMP}" "${SAMPLEID}" "${exitstat2}" "${CMD_TRANSFER}" "${GLOBUS_TASKID}" "$(pwd)" |& tee -a "${GLOBUS_TASK_PREFIX}"_success.log

	    exit "${exitstat2}"
	fi
fi

## END ##
