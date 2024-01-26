#!/bin/bash

# EBC pipeline: Run Bedpostx on the data
# inputs:
#
# Previous Steps:
# - Need to have a functional CUDA environement matching the xfibres
#

# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/10.sh
echo "# START-OF-PROC" > $THISLOG


echo "Copy Data to Bedpost Folder"

cp ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend_eddy.nii.gz \
   ${DIFF_DATA_BEDPOSTX_DIR}/data.nii.gz

cp ${DIFF_DATA_DIR}/mask_junarot.nii.gz \
   ${DIFF_DATA_BEDPOSTX_DIR}/nodif_brain_mask.nii.gz

cp ${DIFF_DATA_DIR}/data.bval \
   ${DIFF_DATA_BEDPOSTX_DIR}/bvals

cp ${DIFF_DATA_DIR}/data.bvec_junarot \
   ${DIFF_DATA_BEDPOSTX_DIR}/bvecs


#############################
#  Run Bedbpost
echo "Run Bedpost"

# bedpostx_gpu ${DIFF_DATA_BEDPOSTX_DIR}
$SOFTWARE/fsl6/xfibres_gpu/bedpostx_gpu ${DIFF_DATA_BEDPOSTX_DIR}

###############


echo -e "\necho \"Make sure files are not size 0.\"" >> $THISLOG
tmp_var=${DIFF_DATA_BEDPOSTX_DIR%/}.bedpostX
echo "ls -lhr ${tmp_var}" >> $THISLOG 


# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG
#
echo $0 " Done" 