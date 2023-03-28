#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh



# Prepare Juna template by padding
mrgrid ${JUNA_T1_TEMPLATE} pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/juna_template_pad.nii.gz'

# Prepare the N4'd flash contrast by padding
mrgrid ${TISSUE_SEGMENTATION_DIR}'/flash_contr1_degibbs_N4_5x.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/flash1_degibbs_N4_5x_pad.nii.gz'
mrgrid ${TISSUE_SEGMENTATION_DIR}'/flash_contr2_degibbs_N4_5x.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/flash2_degibbs_N4_5x_pad.nii.gz'
mrgrid ${TISSUE_SEGMENTATION_DIR}'/flash_contr3_degibbs_N4_5x.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/flash3_degibbs_N4_5x_pad.nii.gz'
mrgrid ${TISSUE_SEGMENTATION_DIR}'/flash_contr4_degibbs_N4_5x.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/flash4_degibbs_N4_5x_pad.nii.gz'
mrgrid ${TISSUE_SEGMENTATION_DIR}'/flash_contr5_degibbs_N4_5x.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/flash5_degibbs_N4_5x_pad.nii.gz'

# Prepare mask by filling holes, dilating and paddind
${SCRIPTS}'/closure_mask.py' ${FLASH_DIR_WARP}'/mask_flash.nii.gz' ${JUNA_DIR}'/mask_flash_closed.nii.gz' 10 2
mrgrid ${JUNA_DIR}'/mask_flash_closed.nii.gz' pad -uniform ${JUNA_PAD} ${JUNA_DIR}'/mask_flash_pad.nii.gz'





FIXED1=${JUNA_DIR}'/flash1_degibbs_N4_5x_pad.nii.gz'
FIXED2=${JUNA_DIR}'/flash2_degibbs_N4_5x_pad.nii.gz'
FIXED3=${JUNA_DIR}'/flash3_degibbs_N4_5x_pad.nii.gz'
FIXED4=${JUNA_DIR}'/flash4_degibbs_N4_5x_pad.nii.gz'
FIXED5=${JUNA_DIR}'/flash5_degibbs_N4_5x_pad.nii.gz'
FIXEDMASK=${JUNA_DIR}'/mask_flash_pad.nii.gz'
MOVING=${JUNA_DIR}'/juna_template_pad.nii.gz'
OUTPUT=${JUNA_DIR}'/Juna_T1_warped.nii.gz'
PREFIX=${JUNA_DIR}'/Juna_to_flash_'


# Register Juna Template to Flash 
antsRegistration --dimensionality 3 --float 0 \
                 --output [$PREFIX, $OUTPUT] \
                 --interpolation Linear \
                 --winsorize-image-intensities [0.005,0.995] \
                 --use-histogram-matching 0 \
                 --initial-moving-transform [$FIXED3, $MOVING,1] \
                 --transform Rigid[0.1] \
                 --metric MI[$FIXED1, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED2, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED3, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED4, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED5, $MOVING,0.2,32,Regular,0.25] \
                 --convergence [1000x1000x500x250x100,1e-6,10] \
                 --shrink-factors 16x8x4x2x1 \
                 --smoothing-sigmas 4x3x2x1x0vox \
                 --transform Affine[0.1] \
                 --metric MI[$FIXED1, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED2, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED3, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED4, $MOVING,0.2,32,Regular,0.25] \
                 --metric MI[$FIXED5, $MOVING,0.2,32,Regular,0.25] \
                 --convergence [1000x1000x500x250x100,1e-6,10] \
                 --shrink-factors 16x8x4x2x1 \
                 --smoothing-sigmas 4x3x2x1x0vox \
                 --transform SyN[0.3,7.5,0] \
                 --metric MI[$FIXED1, $MOVING,0.2,64,Regular,0.25] \
                 --metric MI[$FIXED2, $MOVING,0.2,64,Regular,0.25] \
                 --metric MI[$FIXED3, $MOVING,0.2,64,Regular,0.25] \
                 --metric MI[$FIXED4, $MOVING,0.2,64,Regular,0.25] \
                 --metric MI[$FIXED5, $MOVING,0.2,64,Regular,0.25] \
                 --convergence [400x200x100x75x50,1e-6,10] \
                 --shrink-factors 16x8x4x2x1 \
                 --smoothing-sigmas 4x3x2x1x0vox \
                 --masks [$FIXEDMASK]


# Warp N4 Flash to Juna 
antsApplyTransforms \
    --dimensionality 3 \
    --input $FIXED1 \
    --reference-image $MOVING \
    --transform [$PREFIX'0GenericAffine.mat', 1] \
    --transform $PREFIX'1InverseWarp.nii.gz' \
    --output ${JUNA_DIR}'/flash1_degibbs_N4_5x_Juna_space.nii.gz'

antsApplyTransforms \
    --dimensionality 3 \
    --input $FIXED2 \
    --reference-image $MOVING \
    --transform [$PREFIX'0GenericAffine.mat', 1] \
    --transform $PREFIX'1InverseWarp.nii.gz' \
    --output ${JUNA_DIR}'/flash2_degibbs_N4_5x_Juna_space.nii.gz'

antsApplyTransforms \
    --dimensionality 3 \
    --input $FIXED3 \
    --reference-image $MOVING \
    --transform [$PREFIX'0GenericAffine.mat', 1] \
    --transform $PREFIX'1InverseWarp.nii.gz' \
    --output ${JUNA_DIR}'/flash3_degibbs_N4_5x_Juna_space.nii.gz'

antsApplyTransforms \
    --dimensionality 3 \
    --input $FIXED4 \
    --reference-image $MOVING \
    --transform [$PREFIX'0GenericAffine.mat', 1] \
    --transform $PREFIX'1InverseWarp.nii.gz' \
    --output ${JUNA_DIR}'/flash4_degibbs_N4_5x_Juna_space.nii.gz'

antsApplyTransforms \
    --dimensionality 3 \
    --input $FIXED5 \
    --reference-image $MOVING \
    --transform [$PREFIX'0GenericAffine.mat', 1] \
    --transform $PREFIX'1InverseWarp.nii.gz' \
    --output ${JUNA_DIR}'/flash5_degibbs_N4_5x_Juna_space.nii.gz'


