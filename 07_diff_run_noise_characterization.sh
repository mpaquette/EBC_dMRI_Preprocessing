#!/bin/bash

# EBC pipeline: Comupute Noise properties from noisemap
# inputs:
#
# Previous Steps:
#

# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/07.sh
echo "# START-OF-PROC" > $THISLOG

# Copy nii files to noisemap directory
echo "Copy nii files to noisemap directory"
cp ${UNWRAP_DIR}/*X${NOISE_SCAN}P1.nii.gz ${NOISEMAP_DIR}/noisemap.nii.gz

# Reshape image matrix to resemble MNI space
echo "Reshape image matrix to resemble MNI space"
python3 ${SCRIPTS}/reshape_volume.py \
    --in ${NOISEMAP_DIR}/noisemap.nii.gz \
    --out ${NOISEMAP_DIR}/noisemap_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}
#
python3 ${SCRIPTS}/reshape_volume.py \
    --in ${UNWRAP_DIR}/mask_FOV_extent_epi.nii.gz \
    --out ${NOISEMAP_DIR}/mask_FOV_extent.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}

mv -f ${NOISEMAP_DIR}/noisemap_reshape.nii.gz ${NOISEMAP_DIR}/noisemap.nii.gz


echo "Rescale noisemap like other data"
mv ${NOISEMAP_DIR}/noisemap.nii.gz ${NOISEMAP_DIR}/noisemap_unscaled.nii.gz 
${FSL_LOCAL}/fslmaths ${NOISEMAP_DIR}/noisemap_unscaled.nii.gz \
    -div ${DATA_RESCALING} \
    ${NOISEMAP_DIR}/noisemap.nii.gz \
    -odt float 



####################################
echo "Compute noise distribution on noise map"
get_distribution -f \
    ${NOISEMAP_DIR}/noisemap.nii.gz \
    ${NOISEMAP_DIR}/sigmas_unmasked.nii.gz \
    ${NOISEMAP_DIR}/Ns_unmasked.nii.gz \
    ${NOISEMAP_DIR}/noise_mask.nii.gz \
    -a 1 \
    --noise_maps \
    --ncores ${N_CORES} \
    -m moments


# mask out the excess value estimated outside of the FOV extent mask mask
mrcalc ${NOISEMAP_DIR}/sigmas_unmasked.nii.gz \
       ${NOISEMAP_DIR}/mask_FOV_extent.nii.gz \
       -mult \
       ${NOISEMAP_DIR}/sigmas.nii.gz

mrcalc ${NOISEMAP_DIR}/Ns_unmasked.nii.gz \
       ${NOISEMAP_DIR}/mask_FOV_extent.nii.gz \
       -mult \
       ${NOISEMAP_DIR}/Ns.nii.gz


# rm ${NOISEMAP_DIR}/sigmas_unmasked.nii.gz
# rm ${NOISEMAP_DIR}/Ns_unmasked.nii.gz


# mrview -load ${NOISEMAP_DIR}/sigmas.nii.gz -interpolation 0 -load ${NOISEMAP_DIR}/Ns.nii.gz -interpolation 0
echo -e "\necho \"Check masked Sigmas and Ns.\"" >> $THISLOG
echo "mrview -load ${NOISEMAP_DIR}/sigmas.nii.gz -interpolation 0 -load ${NOISEMAP_DIR}/Ns.nii.gz -interpolation 0" >> $THISLOG





# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG
#
echo $0 " Done" 
