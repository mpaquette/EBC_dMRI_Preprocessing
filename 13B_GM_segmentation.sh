#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh


# Gaussian Mixture MAP segmentation in flash image space
# PARAM for MAP iterations
MAP_MAXIT=200
MAP_TH=0.1



# transforms
JUNA_TO_FLASH_AFF=${JUNA_DIR}'/Juna_to_flash_0GenericAffine.mat'
JUNA_TO_FLASH_WARP=${JUNA_DIR}'/Juna_to_flash_1Warp.nii.gz'
FLASH_TO_EPI_AFF=${FLASH_DIR_WARP}'/flash_to_epi_0GenericAffine.mat'
EPI_TO_FLASH_WARP=${FLASH_DIR_WARP}'/flash_to_epi_1InverseWarp.nii.gz'



# Diffusion contrasts
# CLipping negatives
mrcalc ${FLASH_DIR_WARP}'/data_epi_N4_5x.nii.gz' 0 -max ${JUNA_DIR}'/B0_N4_5x_dwi_space.nii.gz'
mrcalc ${TISSUE_SEGMENTATION_DIR}'/data_norm_mean.nii.gz' 0 -max ${JUNA_DIR}'/SM_dwi_space.nii.gz'

# padding 
mrgrid ${JUNA_DIR}'/B0_N4_5x_dwi_space.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/B0_N4_5x_dwi_space_pad.nii.gz'
mrgrid ${JUNA_DIR}'/SM_dwi_space.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/SM_dwi_space_pad.nii.gz'

# warping to flash space
antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}'/B0_N4_5x_dwi_space_pad.nii.gz' \
    --reference-image $FLASH3 \
    --interpolation BSpline \
    --transform [$FLASH_TO_EPI_AFF, 1] \
    --transform $EPI_TO_FLASH_WARP \
    --output ${JUNA_DIR}'/B0_N4_5x_flash_space_pad.nii.gz'

antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}'/SM_dwi_space_pad.nii.gz' \
    --reference-image $FLASH3 \
    --interpolation BSpline \
    --transform [$FLASH_TO_EPI_AFF, 1] \
    --transform $EPI_TO_FLASH_WARP \
    --output ${JUNA_DIR}'/SM_flash_space_pad.nii.gz'


CONTRAST_B0=${JUNA_DIR}'/B0_N4_5x_flash_space_pad.nii.gz'
CONTRAST_SM=${JUNA_DIR}'/SM_flash_space_pad.nii.gz'

# Flash contrasts
CONTRAST_FLASH1=${JUNA_DIR}'/flash1_degibbs_N4_5x_pad.nii.gz'
CONTRAST_FLASH2=${JUNA_DIR}'/flash2_degibbs_N4_5x_pad.nii.gz'
CONTRAST_FLASH3=${JUNA_DIR}'/flash3_degibbs_N4_5x_pad.nii.gz'
CONTRAST_FLASH4=${JUNA_DIR}'/flash4_degibbs_N4_5x_pad.nii.gz'
CONTRAST_FLASH5=${JUNA_DIR}'/flash5_degibbs_N4_5x_pad.nii.gz'
FLASHMASK=${JUNA_DIR}'/mask_flash_pad.nii.gz'





# extract and pad Juna prior maps
fslroi ${JUNA_TMP_TEMPLATE} ${JUNA_DIR}'/Juna_GM.nii.gz' 0 1
fslroi ${JUNA_TMP_TEMPLATE} ${JUNA_DIR}'/Juna_WM.nii.gz' 1 1
fslroi ${JUNA_TMP_TEMPLATE} ${JUNA_DIR}'/Juna_CSF.nii.gz' 2 1

mrgrid ${JUNA_DIR}'/Juna_GM.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/Juna_GM_pad.nii.gz'
mrgrid ${JUNA_DIR}'/Juna_WM.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/Juna_WM_pad.nii.gz'
mrgrid ${JUNA_DIR}'/Juna_CSF.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/Juna_CSF_pad.nii.gz'


# warp prior to flash image space
antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}'/Juna_GM_pad.nii.gz' \
    --reference-image $FLASH3 \
    --interpolation BSpline \
    --transform $JUNA_TO_FLASH_WARP \
    --transform $JUNA_TO_FLASH_AFF \
    --output ${JUNA_DIR}'/Juna_GM_pad_flash_space.nii.gz'
PRIOR_GM_FLASHSPACE=${JUNA_DIR}'/Juna_GM_pad_flash_space.nii.gz'

antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}'/Juna_WM_pad.nii.gz' \
    --reference-image $FLASH3 \
    --interpolation BSpline \
    --transform $JUNA_TO_FLASH_WARP \
    --transform $JUNA_TO_FLASH_AFF \
    --output ${JUNA_DIR}'/Juna_WM_pad_flash_space.nii.gz'
PRIOR_WM_FLASHSPACE=${JUNA_DIR}'/Juna_WM_pad_flash_space.nii.gz'

antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}'/Juna_CSF_pad.nii.gz' \
    --reference-image $FLASH3 \
    --interpolation BSpline \
    --transform $JUNA_TO_FLASH_WARP \
    --transform $JUNA_TO_FLASH_AFF \
    --output ${JUNA_DIR}'/Juna_CSF_pad_flash_space.nii.gz'
PRIOR_CSF_FLASHSPACE=${JUNA_DIR}'/Juna_CSF_pad_flash_space.nii.gz'



OUTPUT_PROB=${TISSUE_SEGMENTATION_DIR}'/multimodal_seg_prob.nii.gz'
OUTPUT_RBG=${TISSUE_SEGMENTATION_DIR}'/multimodal_seg_rgb.nii.gz'
OUTPUT_log=${TISSUE_SEGMENTATION_DIR}'/multimodal_seg_log.txt'
OUTPUT_class=${TISSUE_SEGMENTATION_DIR}'/multimodal_seg_classes'


python3 ${SCRIPTS}'/gaussian_mixture_cluster.py' \
                                     -data      $CONTRAST_FLASH1 \
                                                $CONTRAST_FLASH2 \
                                                $CONTRAST_FLASH3 \
                                                $CONTRAST_FLASH4 \
                                                $CONTRAST_FLASH5 \
                                                $CONTRAST_B0 \
                                                $CONTRAST_SM \
                                     -prior     $PRIOR_WM_FLASHSPACE \
                                                $PRIOR_GM_FLASHSPACE \
                                                $PRIOR_CSF_FLASHSPACE \
                                     -mask      $FLASHMASK \
                                     -maxit     $MAP_MAXIT \
                                     -th        $MAP_TH \
                                     -outprob   $OUTPUT_PROB \
                                     -outrgb    $OUTPUT_RBG \
                                     -outlog    $OUTPUT_log \
                                     -outclass  $OUTPUT_class \















