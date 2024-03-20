#!/bin/bash

# EBC pipeline: 
# inputs:
#
# Previous Steps:
#

# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/12.sh
echo "# START-OF-PROC" > $THISLOG

# PARAM for flash mask closure
CLOSE_SPHERE_RADIUS=10
DILATATION_RADIUS=2
# Param for midpoint padding
PAD_AFTER_AFFINE=10
# use the Juna T1 template with cleaned CSF outside the brain?
USE_CLEAN_JUNA=true


# Prepare mask by filling holes, dilating and paddind
python3 ${SCRIPTS}/closure_mask.py ${FLASH_DIR_WARP}/mask_flash_junarot.nii.gz ${JUNA_DIR}/mask_flash_closed.nii.gz $CLOSE_SPHERE_RADIUS $DILATATION_RADIUS





FIXED1=${FLASH_DIR_FA05}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
FIXED2=${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
FIXED3=${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
FIXED4=${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
FIXED5=${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
FIXEDB0=${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz
FIXEDMASK=${JUNA_DIR}/mask_flash_closed.nii.gz


if [ "$USE_CLEAN_JUNA" = true ] ; then
    echo "Using CSF-cleaned Juna template";
    TEMPLATE_CLEAN=/data/pt_02101_dMRI/external_data/Juna_Template/Juna.Chimp_05mm/csf_strip/Juna_Chimp_T1_05mm_csf_strip_0p2_dil.nii.gz
    TEMPLATE_PAD=${JUNAROT_DIR}/juna_clean_pad.nii.gz

    mrgrid ${TEMPLATE_CLEAN} \
           pad -uniform ${JUNA_PAD} \
           ${TEMPLATE_PAD} -force
    
    MOVING=${TEMPLATE_PAD}

else
    echo "Using default Juna template";
    MOVING=${JUNAROT_DIR}/juna_pad.nii.gz
fi



OUTPUT=${JUNA_DIR}/Juna_warped.nii.gz
PREFIX=${JUNA_DIR}/Juna_to_JUNAROT_



echo -e "\necho \"Check FLASH mask in JUNAROT space.\"" >> $THISLOG
echo "mrview -load ${FIXED3} -interpolation 0 -mode 2 -overlay.load ${FIXEDMASK} -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3" >> $THISLOG






# Register Juna Template to Flash with only rigid and affine
MOVING_FOR_AFFINE=${MOVING}
OUTPUT_FOR_AFFINE=${JUNA_DIR}/Juna_rigid_affine.nii.gz
PREFIX_FOR_AFFINE=${PREFIX}
#
antsRegistration --dimensionality 3 --float 0 \
                 --output [$PREFIX_FOR_AFFINE, $OUTPUT_FOR_AFFINE] \
                 --interpolation Linear \
                 --winsorize-image-intensities [0.005,0.995] \
                 --use-histogram-matching 0 \
                 --initial-moving-transform [$FIXED3, $MOVING_FOR_AFFINE,1] \
                 --transform Rigid[0.1] \
                 --metric MI[$FIXED1, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED2, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED3, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED4, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED5, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --convergence [1000x1000x500x250x100,1e-6,10] \
                 --shrink-factors 16x8x4x2x1 \
                 --smoothing-sigmas 4x3x2x1x0vox \
                 --transform Affine[0.1] \
                 --metric MI[$FIXED1, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED2, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED3, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED4, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --metric MI[$FIXED5, $MOVING_FOR_AFFINE,0.2,32,Regular,0.5] \
                 --convergence [1000x1000x500x250x100,1e-6,10] \
                 --shrink-factors 16x8x4x2x1 \
                 --smoothing-sigmas 4x3x2x1x0vox \
                 --masks [$FIXEDMASK] \
                 -v


echo -e "\necho \"Check Juna to Junarot affine registration.\"" >> $THISLOG
echo "mrview -load ${FIXED3} -interpolation 0 -mode 2 -load ${OUTPUT_FOR_AFFINE} -interpolation 0 -mode 2" >> $THISLOG










OUTPUT_FOR_AFFINE_PAD=${JUNA_DIR}/Juna_rigid_affine_pad.nii.gz
#
FIXEDPADMASK=${JUNA_DIR}/mask_flash_closed_pad.nii.gz
#
FIXED1PAD=${FLASH_DIR_FA05}/data_degibbs_N4_${N4_ITER}x_junarot_pad.nii.gz
FIXED2PAD=${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x_junarot_pad.nii.gz
FIXED3PAD=${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot_pad.nii.gz
FIXED4PAD=${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x_junarot_pad.nii.gz
FIXED5PAD=${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x_junarot_pad.nii.gz
FIXEDB0PAD=${JUNA_DIR}/data_epi_N4_${N4_ITER}x_pad.nii.gz
#
#
mrgrid ${OUTPUT_FOR_AFFINE} pad -uniform ${PAD_AFTER_AFFINE} ${OUTPUT_FOR_AFFINE_PAD} -force
#
mrgrid ${FIXED1} pad -uniform ${PAD_AFTER_AFFINE} ${FIXED1PAD} -force
mrgrid ${FIXED2} pad -uniform ${PAD_AFTER_AFFINE} ${FIXED2PAD} -force
mrgrid ${FIXED3} pad -uniform ${PAD_AFTER_AFFINE} ${FIXED3PAD} -force
mrgrid ${FIXED4} pad -uniform ${PAD_AFTER_AFFINE} ${FIXED4PAD} -force
mrgrid ${FIXED5} pad -uniform ${PAD_AFTER_AFFINE} ${FIXED5PAD} -force
mrgrid ${FIXEDB0} pad -uniform ${PAD_AFTER_AFFINE} ${FIXEDB0PAD} -force
#
mrgrid ${FIXEDMASK} pad -uniform ${PAD_AFTER_AFFINE} ${FIXEDPADMASK} -force










MOVING=${OUTPUT_FOR_AFFINE_PAD}
# OUTPUT=${OUTPUT}
# PREFIX=${PREFIX}
MI_FRAC=0.25
#
# antsRegistration --dimensionality 3 --float 0 \
#                  --output [$PREFIX, $OUTPUT] \
#                  --interpolation Linear \
#                  --winsorize-image-intensities [0.005,0.995] \
#                  --use-histogram-matching 0 \
#                  --transform SyN[0.3,7.5,0] \
#                  --metric MI[$FIXED1PAD, $MOVING, 0.2, 64, Regular, ${MI_FRAC}] \
#                  --metric MI[$FIXED2PAD, $MOVING, 0.2, 64, Regular, ${MI_FRAC}] \
#                  --metric MI[$FIXED3PAD, $MOVING, 0.2, 64, Regular, ${MI_FRAC}] \
#                  --metric MI[$FIXED4PAD, $MOVING, 0.2, 64, Regular, ${MI_FRAC}] \
#                  --metric MI[$FIXED5PAD, $MOVING, 0.2, 64, Regular, ${MI_FRAC}] \
#                  --convergence [400x200x100x75x50,1e-6,10] \
#                  --shrink-factors 16x8x4x2x1 \
#                  --smoothing-sigmas 4x3x2x1x0vox \
#                  --masks [$FIXEDPADMASK] \
#                  -v

antsRegistration --dimensionality 3 --float 0 \
                 --output [$PREFIX, $OUTPUT] \
                 --interpolation Linear \
                 --winsorize-image-intensities [0.005,0.995] \
                 --use-histogram-matching 0 \
                 --transform SyN[0.3,7.5,0] \
                 --metric MI[$FIXED1PAD, $MOVING, 0.15, 64, Regular, ${MI_FRAC}] \
                 --metric MI[$FIXED2PAD, $MOVING, 0.15, 64, Regular, ${MI_FRAC}] \
                 --metric MI[$FIXED3PAD, $MOVING, 0.15, 64, Regular, ${MI_FRAC}] \
                 --metric MI[$FIXED4PAD, $MOVING, 0.15, 64, Regular, ${MI_FRAC}] \
                 --metric MI[$FIXED5PAD, $MOVING, 0.15, 64, Regular, ${MI_FRAC}] \
                 --metric MI[$FIXEDB0PAD, $MOVING, 0.25, 64, Regular, ${MI_FRAC}] \
                 --convergence [400x200x100x75x50,1e-6,10] \
                 --shrink-factors 16x8x4x2x1 \
                 --smoothing-sigmas 4x3x2x1x0vox \
                 --masks [$FIXEDPADMASK] \
                 -v

echo -e "\necho \"Check Juna registration to JUNAROT space.\"" >> $THISLOG
echo "mrview  -load ${FIXED3} -interpolation 0 -mode 2 -load ${OUTPUT} -interpolation 0 -mode 2" >> $THISLOG


#
JUNA_TO_JUNAROT_WARP_TMP=${PREFIX}0Warp.nii.gz
JUNAROT_TO_JUNA_WARP_TMP=${PREFIX}0InverseWarp.nii.gz
#
JUNA_TO_JUNAROT_WARP=${PREFIX}1Warp.nii.gz
JUNAROT_TO_JUNA_WARP=${PREFIX}1InverseWarp.nii.gz
JUNA_TO_JUNAROT_AFF=${PREFIX}0GenericAffine.mat

# removing paddind and fixing naming convention
mrgrid ${JUNA_TO_JUNAROT_WARP_TMP} pad -uniform -${PAD_AFTER_AFFINE} ${JUNA_TO_JUNAROT_WARP} -force
mrgrid ${JUNAROT_TO_JUNA_WARP_TMP} pad -uniform -${PAD_AFTER_AFFINE} ${JUNAROT_TO_JUNA_WARP} -force

python ${SCRIPTS}/set_nifti_intent_code.py ${JUNA_TO_JUNAROT_WARP} vector
python ${SCRIPTS}/set_nifti_intent_code.py ${JUNAROT_TO_JUNA_WARP} vector


# # Register Juna Template to Flash 
# antsRegistration --dimensionality 3 --float 0 \
#                  --output [$PREFIX, $OUTPUT] \
#                  --interpolation Linear \
#                  --winsorize-image-intensities [0.005,0.995] \
#                  --use-histogram-matching 0 \
#                  --initial-moving-transform [$FIXED3, $MOVING,1] \
#                  --transform Rigid[0.1] \
#                  --metric MI[$FIXED1, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED2, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED3, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED4, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED5, $MOVING,0.2,32,Regular,0.25] \
#                  --convergence [1000x1000x500x250x100,1e-6,10] \
#                  --shrink-factors 16x8x4x2x1 \
#                  --smoothing-sigmas 4x3x2x1x0vox \
#                  --transform Affine[0.1] \
#                  --metric MI[$FIXED1, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED2, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED3, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED4, $MOVING,0.2,32,Regular,0.25] \
#                  --metric MI[$FIXED5, $MOVING,0.2,32,Regular,0.25] \
#                  --convergence [1000x1000x500x250x100,1e-6,10] \
#                  --shrink-factors 16x8x4x2x1 \
#                  --smoothing-sigmas 4x3x2x1x0vox \
#                  --transform SyN[0.3,7.5,0] \
#                  --metric MI[$FIXED1, $MOVING,0.2,64,Regular,0.25] \
#                  --metric MI[$FIXED2, $MOVING,0.2,64,Regular,0.25] \
#                  --metric MI[$FIXED3, $MOVING,0.2,64,Regular,0.25] \
#                  --metric MI[$FIXED4, $MOVING,0.2,64,Regular,0.25] \
#                  --metric MI[$FIXED5, $MOVING,0.2,64,Regular,0.25] \
#                  --convergence [400x200x100x75x50,1e-6,10] \
#                  --shrink-factors 16x8x4x2x1 \
#                  --smoothing-sigmas 4x3x2x1x0vox \
#                  --masks [$FIXEDMASK]


# echo -e "\necho \"Check Juna registration to JUNAROT space.\"" >> $THISLOG
# echo "mrview  -load ${FIXED3} -interpolation 0 -mode 2 -load ${OUTPUT} -interpolation 0 -mode 2" >> $THISLOG





# extract and pad Juna prior maps
fslroi ${JUNA_TMP_TEMPLATE} ${JUNA_DIR}/Juna_GM.nii.gz 0 1
fslroi ${JUNA_TMP_TEMPLATE} ${JUNA_DIR}/Juna_WM.nii.gz 1 1
fslroi ${JUNA_TMP_TEMPLATE} ${JUNA_DIR}/Juna_CSF.nii.gz 2 1

mrgrid ${JUNA_DIR}/Juna_GM.nii.gz  pad -uniform ${JUNA_PAD} ${JUNA_DIR}/Juna_GM_pad.nii.gz -force
mrgrid ${JUNA_DIR}/Juna_WM.nii.gz  pad -uniform ${JUNA_PAD} ${JUNA_DIR}/Juna_WM_pad.nii.gz -force
mrgrid ${JUNA_DIR}/Juna_CSF.nii.gz pad -uniform ${JUNA_PAD} ${JUNA_DIR}/Juna_CSF_pad.nii.gz -force


# JUNA_TO_JUNAROT_AFF=${JUNA_DIR}/Juna_to_JUNAROT_0GenericAffine.mat
# JUNA_TO_JUNAROT_WARP=${JUNA_DIR}/Juna_to_JUNAROT_1Warp.nii.gz
# JUNAROT_TO_JUNA_WARP=${JUNA_DIR}/Juna_to_JUNAROT_1InverseWarp.nii.gz

# warp prior to flash image space
antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}/Juna_GM_pad.nii.gz \
    --reference-image ${FIXED3} \
    --interpolation BSpline \
    --transform ${JUNA_TO_JUNAROT_WARP} \
    --transform ${JUNA_TO_JUNAROT_AFF} \
    --output ${JUNA_DIR}/Juna_GM_junarot_space_tmp.nii.gz
# clip negatives from spline
mrcalc ${JUNA_DIR}/Juna_GM_junarot_space_tmp.nii.gz 0 -max ${JUNA_DIR}/Juna_GM_junarot_space.nii.gz -force
rm -f ${JUNA_DIR}/Juna_GM_junarot_space_tmp.nii.gz

antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}/Juna_WM_pad.nii.gz \
    --reference-image ${FIXED3} \
    --interpolation BSpline \
    --transform ${JUNA_TO_JUNAROT_WARP} \
    --transform ${JUNA_TO_JUNAROT_AFF} \
    --output ${JUNA_DIR}/Juna_WM_junarot_space_tmp.nii.gz
# clip negatives from spline
mrcalc ${JUNA_DIR}/Juna_WM_junarot_space_tmp.nii.gz 0 -max ${JUNA_DIR}/Juna_WM_junarot_space.nii.gz -force
rm -f ${JUNA_DIR}/Juna_WM_junarot_space_tmp.nii.gz

antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_DIR}/Juna_CSF_pad.nii.gz \
    --reference-image ${FIXED3} \
    --interpolation BSpline \
    --transform ${JUNA_TO_JUNAROT_WARP} \
    --transform ${JUNA_TO_JUNAROT_AFF} \
    --output ${JUNA_DIR}/Juna_CSF_junarot_space_tmp.nii.gz
# clip negatives from spline
mrcalc ${JUNA_DIR}/Juna_CSF_junarot_space_tmp.nii.gz 0 -max ${JUNA_DIR}/Juna_CSF_junarot_space.nii.gz -force
rm -f ${JUNA_DIR}/Juna_CSF_junarot_space_tmp.nii.gz



echo -e "\necho \"Check Juna tissue priors warped to JUNAROT space.\"" >> $THISLOG
echo "mrview -load ${FIXED3} -interpolation 0 -mode 2 -overlay.load ${JUNA_DIR}/Juna_GM_junarot_space.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 1,0,0 -overlay.threshold_min 0.3 -overlay.load ${JUNA_DIR}/Juna_WM_junarot_space.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,1,0 -overlay.threshold_min 0.3 -overlay.load ${JUNA_DIR}/Juna_CSF_junarot_space.nii.gz -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,0,1 -overlay.threshold_min 0.3" >> $THISLOG





# Subcortical "atlas"
LABELS_RAW=${JUNA_DIR}/subcortical_labels_raw.nii.gz

# JUNA_TO_JUNAROT_AFF=${JUNA_DIR}/Juna_to_JUNAROT_0GenericAffine.mat
# JUNA_TO_JUNAROT_WARP=${JUNA_DIR}/Juna_to_JUNAROT_1Warp.nii.gz
# JUNAROT_TO_JUNA_WARP=${JUNA_DIR}/Juna_to_JUNAROT_1InverseWarp.nii.gz

# warp prior to flash image space
antsApplyTransforms \
    --dimensionality 3 \
    --input ${JUNA_PAD_SUBCORTICAL_TEMPLATE} \
    --reference-image ${FIXED3} \
    --interpolation NearestNeighbor \
    --transform ${JUNA_TO_JUNAROT_WARP} \
    --transform ${JUNA_TO_JUNAROT_AFF} \
    --output ${LABELS_RAW}



echo -e "\necho \"Check Juna Subcortical \\\"atlas\\\" warped to JUNAROT space.\"" >> $THISLOG
echo "mrview -load ${FIXED3} -interpolation 0 -mode 2 -overlay.load ${LABELS_RAW}  -overlay.opacity 0.75 -overlay.interpolation 0 -overlay.colourmap 6 -overlay.threshold_min 1.1" >> $THISLOG






# VENTRICULE AND NON-VENTRICULE CSF here







# # Warp N4 Flash to Juna 
# antsApplyTransforms \
#     --dimensionality 3 \
#     --input $FIXED1 \
#     --reference-image $MOVING \
#     --transform [$PREFIX'0GenericAffine.mat', 1] \
#     --transform $PREFIX'1InverseWarp.nii.gz' \
#     --output ${JUNA_DIR}'/flash1_degibbs_N4_5x_Juna_space.nii.gz'

# antsApplyTransforms \
#     --dimensionality 3 \
#     --input $FIXED2 \
#     --reference-image $MOVING \
#     --transform [$PREFIX'0GenericAffine.mat', 1] \
#     --transform $PREFIX'1InverseWarp.nii.gz' \
#     --output ${JUNA_DIR}'/flash2_degibbs_N4_5x_Juna_space.nii.gz'

# antsApplyTransforms \
#     --dimensionality 3 \
#     --input $FIXED3 \
#     --reference-image $MOVING \
#     --transform [$PREFIX'0GenericAffine.mat', 1] \
#     --transform $PREFIX'1InverseWarp.nii.gz' \
#     --output ${JUNA_DIR}'/flash3_degibbs_N4_5x_Juna_space.nii.gz'

# antsApplyTransforms \
#     --dimensionality 3 \
#     --input $FIXED4 \
#     --reference-image $MOVING \
#     --transform [$PREFIX'0GenericAffine.mat', 1] \
#     --transform $PREFIX'1InverseWarp.nii.gz' \
#     --output ${JUNA_DIR}'/flash4_degibbs_N4_5x_Juna_space.nii.gz'

# antsApplyTransforms \
#     --dimensionality 3 \
#     --input $FIXED5 \
#     --reference-image $MOVING \
#     --transform [$PREFIX'0GenericAffine.mat', 1] \
#     --transform $PREFIX'1InverseWarp.nii.gz' \
#     --output ${JUNA_DIR}'/flash5_degibbs_N4_5x_Juna_space.nii.gz'


# antsApplyTransforms \
#     --dimensionality 3 \
#     --input $FIXEDMASK \
#     --reference-image $MOVING \
#     --transform [$PREFIX'0GenericAffine.mat', 1] \
#     --transform $PREFIX'1InverseWarp.nii.gz' \
#     --output ${JUNA_DIR}'/mask_flash_juna_space.nii.gz'


# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG

echo 'Done'

