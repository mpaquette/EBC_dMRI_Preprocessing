#!/bin/bash


# EBC pipeline: Generate raw Nifti images
# inputs:
# - Raw Bruker data
#
# Previous Steps:
# - Setting $BRUKER_RAW_DIR in SET_VARIABLES.sh
#


# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/02.sh
echo "# START-OF-PROC" > $THISLOG

# Convert Bruker Data to Nifti
${SOFTWARE}/bru2/Bru2 -a -p -z -v ${BRUKER_RAW_DIR}/subject
mv ${BRUKER_RAW_DIR}/*.nii.gz ${NII_RAW_DIR}

echo -e "\necho \"list raw data folder.\"" >> $THISLOG
echo "ls -lhr ${NII_RAW_DIR}" >> $THISLOG 


# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG
#
echo $0 " Done" 