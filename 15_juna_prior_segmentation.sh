#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/15.sh
echo "# START-OF-PROC" > $THISLOG


# Gaussian Mixture MAP segmentation in flash image space
# PARAM for MAP iterations
MAP_MAXIT=200
MAP_TH=0.1



# everything already in JUNAROT space
CONTRAST_FLASH1=${FLASH_DIR_FA05}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
CONTRAST_FLASH2=${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
CONTRAST_FLASH3=${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
CONTRAST_FLASH4=${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
CONTRAST_FLASH5=${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
FIXEDMASK=${JUNA_DIR}/mask_flash_closed.nii.gz



# everything already in JUNAROT space
CONTRAST_B0=${JUNA_DIR}/B0_N4_${N4_ITER}x.nii.gz
CONTRAST_SM=${JUNA_DIR}/SM.nii.gz
# Diffusion contrasts
# CLipping negatives
mrcalc ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz 0 -max ${CONTRAST_B0} -force
mrcalc ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz 0 -max ${CONTRAST_SM} -force




# everything already in JUNAROT space
PRIOR_GM=${JUNA_DIR}/Juna_GM_junarot_space.nii.gz
PRIOR_WM=${JUNA_DIR}/Juna_WM_junarot_space.nii.gz
PRIOR_CSF=${JUNA_DIR}/Juna_CSF_junarot_space.nii.gz



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
                                     -prior     $PRIOR_WM \
                                                $PRIOR_GM \
                                                $PRIOR_CSF \
                                     -mask      $FIXEDMASK \
                                     -maxit     $MAP_MAXIT \
                                     -th        $MAP_TH \
                                     -outprob   $OUTPUT_PROB \
                                     -outrgb    $OUTPUT_RBG \
                                     -outlog    $OUTPUT_log \
                                     -outclass  $OUTPUT_class \



# extract Tissue maps
fslroi ${TISSUE_SEGMENTATION_DIR}/multimodal_seg_prob.nii.gz ${TISSUE_SEGMENTATION_DIR}/multimodal_WM.nii.gz 0 1
fslroi ${TISSUE_SEGMENTATION_DIR}/multimodal_seg_prob.nii.gz ${TISSUE_SEGMENTATION_DIR}/multimodal_GM.nii.gz 1 1
fslroi ${TISSUE_SEGMENTATION_DIR}/multimodal_seg_prob.nii.gz ${TISSUE_SEGMENTATION_DIR}/multimodal_CSF.nii.gz 2 1

echo -e "\necho \"Check Segmentation from Juna Prior.\"" >> $THISLOG
echo "mrview -load ${CONTRAST_FLASH3} -interpolation 0 -mode 2 -overlay.load ${TISSUE_SEGMENTATION_DIR}/multimodal_GM.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 1,0,0 -overlay.threshold_min 0.3 -overlay.load ${TISSUE_SEGMENTATION_DIR}/multimodal_WM.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,1,0 -overlay.threshold_min 0.3 -overlay.load ${TISSUE_SEGMENTATION_DIR}/multimodal_CSF.nii.gz -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,0,1 -overlay.threshold_min 0.3" >> $THISLOG






JUNA_TO_JUNAROT_WARP=${JUNA_DIR}/Juna_to_JUNAROT_1Warp.nii.gz
JUNAROT_TO_JUNA_WARP=${JUNA_DIR}/Juna_to_JUNAROT_1InverseWarp.nii.gz
JUNA_TO_JUNAROT_AFF=${JUNA_DIR}/Juna_to_JUNAROT_0GenericAffine.mat




SUBCORTICAL=${TISSUE_SEGMENTATION_DIR}/subcortical/
mkdir -p ${SUBCORTICAL}

# RAW_LABELS_JUNAPAD=/data/pt_02101_dMRI/external_data/Juna_Template/Juna.Chimp_05mm/negra_subcortical/labels_juna_pad.nii.gz
# RAW_LABELS_JUNAROT=${SUBCORTICAL}/labels_raw.nii.gz



# antsApplyTransforms \
#     --dimensionality 3 \
#     --input ${RAW_LABELS_JUNAPAD} \
#     --reference-image ${PRIOR_WM} \
#     --transform ${JUNA_TO_JUNAROT_WARP} \
#     --transform ${JUNA_TO_JUNAROT_AFF} \
#     --interpolation NearestNeighbor \
#     --output ${RAW_LABELS_JUNAROT}


RAW_LABELS_JUNAROT=${JUNA_DIR}/subcortical_labels_raw.nii.gz

# remove label 1, 4, 5
LABELS=${SUBCORTICAL}/labels.nii.gz
mrcalc ${RAW_LABELS_JUNAROT} 0.5 -gt ${RAW_LABELS_JUNAROT} 1.5 -lt -mult \
       ${RAW_LABELS_JUNAROT} 3.5 -gt ${RAW_LABELS_JUNAROT} 4.5 -lt -mult \
       ${RAW_LABELS_JUNAROT} 4.5 -gt ${RAW_LABELS_JUNAROT} 5.5 -lt -mult \
       -add -add \
       1 -sub -1 -mult \
       ${RAW_LABELS_JUNAROT} -mult \
       ${LABELS} \
       -force


# make a subcortical mask
LABELS_MASK=${SUBCORTICAL}/labels_mask.nii.gz
mrcalc ${LABELS} 0.5 -gt ${LABELS_MASK} -force



# make data mask without subcortical
MASK_NO_LABELS=${SUBCORTICAL}/mask_no_labels.nii.gz
mrcalc 1 ${LABELS_MASK} -sub ${FIXEDMASK} -mult ${MASK_NO_LABELS} -force





OUTPUT_PROB=${SUBCORTICAL}'/multimodal_seg_prob.nii.gz'
OUTPUT_RBG=${SUBCORTICAL}'/multimodal_seg_rgb.nii.gz'
OUTPUT_log=${SUBCORTICAL}'/multimodal_seg_log.txt'
OUTPUT_class=${SUBCORTICAL}'/multimodal_seg_classes'


python3 ${SCRIPTS}'/gaussian_mixture_cluster.py' \
                                     -data      $CONTRAST_FLASH1 \
                                                $CONTRAST_FLASH2 \
                                                $CONTRAST_FLASH3 \
                                                $CONTRAST_FLASH4 \
                                                $CONTRAST_FLASH5 \
                                                $CONTRAST_B0 \
                                                $CONTRAST_SM \
                                     -prior     $PRIOR_WM \
                                                $PRIOR_GM \
                                                $PRIOR_CSF \
                                     -mask      $MASK_NO_LABELS \
                                     -maxit     $MAP_MAXIT \
                                     -th        $MAP_TH \
                                     -outprob   $OUTPUT_PROB \
                                     -outrgb    $OUTPUT_RBG \
                                     -outlog    $OUTPUT_log \
                                     -outclass  $OUTPUT_class \



# extract Tissue maps
fslroi ${SUBCORTICAL}/multimodal_seg_prob.nii.gz ${SUBCORTICAL}/multimodal_WM.nii.gz 0 1
fslroi ${SUBCORTICAL}/multimodal_seg_prob.nii.gz ${SUBCORTICAL}/multimodal_GM.nii.gz 1 1
fslroi ${SUBCORTICAL}/multimodal_seg_prob.nii.gz ${SUBCORTICAL}/multimodal_CSF.nii.gz 2 1


# mrview -load ${CONTRAST_FLASH3} -interpolation 0 -mode 2 \
#        -overlay.load ${SUBCORTICAL}/multimodal_GM.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 1,0,0 -overlay.threshold_min 0.3 \
#        -overlay.load ${SUBCORTICAL}/multimodal_WM.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,1,0 -overlay.threshold_min 0.3 \
#        -overlay.load ${SUBCORTICAL}/multimodal_CSF.nii.gz -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,0,1 -overlay.threshold_min 0.3 \
#        -overlay.load ${LABELS_MASK} -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 1,1,0 -overlay.threshold_min 0.3


echo -e "\necho \"Check Segmentation from Juna Prior with subcortical removed.\"" >> $THISLOG
echo "mrview -load ${CONTRAST_FLASH3} -interpolation 0 -mode 2 -overlay.load ${SUBCORTICAL}/multimodal_GM.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 1,0,0 -overlay.threshold_min 0.3 -overlay.load ${SUBCORTICAL}/multimodal_WM.nii.gz  -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,1,0 -overlay.threshold_min 0.3 -overlay.load ${SUBCORTICAL}/multimodal_CSF.nii.gz -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 0,0,1 -overlay.threshold_min 0.3 -overlay.load ${LABELS_MASK} -overlay.opacity 0.4 -overlay.interpolation 0 -overlay.colour 1,1,0 -overlay.threshold_min 0.3" >> $THISLOG







# # add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG

echo 'Done'