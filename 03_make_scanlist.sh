#!/bin/bash


# EBC pipeline: Generate list of scane names
# inputs:
# - acqp files from raw Bruker data


# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/03.sh
echo "# START-OF-PROC" > $THISLOG


# Generate New Scanlist File
>SCANLIST.txt

# Loop over directories in Bruker raw folder
for Scan in ${BRUKER_RAW_DIR}/*/; do
    if test -f "${Scan}/acqp"; then
        echo "Scanning File $Scan";
        python3 ${SCRIPTS}/print_scan_name.py "${Scan}/acqp" >> SCANLIST.txt
    fi
done

mv SCANLIST.txt ${CONFIG_DIR}/SCANLIST_unsorted.txt

python3 ${SCRIPTS}/sort_scanlist.py --in ${CONFIG_DIR}/SCANLIST_unsorted.txt --out SCANLIST.txt


cat ${LOCAL_DIR}/SCANLIST.txt


echo -e "\necho \"list scans.\"" >> $THISLOG
echo "cat ${LOCAL_DIR}/SCANLIST.txt" >> $THISLOG


# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG
#
echo $0 " Done" 
