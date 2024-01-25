#!/bin/bash


# EBC pipeline: Setup folder structure
# inputs:
# 


# Load Local Variables
source ./SET_VARIABLES.sh


# Generate Diffusion Folders
mkdir -p \
    ${DIFF_DIR} \
    ${LOG_DIR} \
    ${DIFF_DATA_DIR} \
    ${DIFF_DATA_N4_DIR} \
    ${DIFF_DATA_NORM_RELEASE_DIR} \
    ${DIFF_DATA_RELEASE_DIR} \
    ${DIFF_DATA_BEDPOSTX_DIR} \
    ${DTI_DIR} \
    ${EDDY_DIR} \
    ${EDDY_FIELDS_DIR} \
    ${EDDY_FIELDS_REL_DIR} \
    ${EDDY_FIELDS_JAC_DIR} \
    ${NII_RAW_DIR} \
    ${UNWRAP_DIR} \
    ${UNWRAP_PROC_DIR} \
    ${NOISEMAP_DIR} \
    ${REORIENT_DIR} \
    ${SPLIT_DIR} \
    ${SPLIT_WARPED_DIR} \
    ${TOPUP_DIR} \
    ${TISSUE_SEGMENTATION_DIR} \
    ${ODF_DIR} \
    ${JUNA_DIR} \
    ${JUNAROT_DIR} \
    ${QA_DIR}


# Generate FLASH FOLDERS
mkdir -p  \
    ${FLASH_DIR} \
    ${FLASH_DIR_FA05} \
    ${FLASH_DIR_FA12p5} \
    ${FLASH_DIR_FA25} \
    ${FLASH_DIR_FA50} \
    ${FLASH_DIR_FA80} \
    ${FLASH_DIR_HIGHRES} \
    ${FLASH_DIR_ULTRA_HIGHRES} \
    ${FLASH_DIR_WARP}



# Init or clear viz log file 
THISLOG=${LOG_DIR}/01.sh
echo "# START-OF-PROC" > $THISLOG

echo -e "\necho \"list folder structure.\"" >> $THISLOG
echo "ls -lhr ${LOCAL_DIR}" >> $THISLOG 
echo "ls -lhr ${DIFF_DIR}" >> $THISLOG 
echo "ls -lhr ${FLASH_DIR}" >> $THISLOG 

# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG
#
echo $0 " Done" 

