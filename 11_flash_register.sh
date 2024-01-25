#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/11.sh
echo "# START-OF-PROC" > $THISLOG


# cp ${FLASH_DIR_FA05}/data_degibbs.nii.gz ${FLASH_DIR_WARP}/data_flash.nii.gz


# echo 'Runing N4 on FLASH Data'
# for i in $(seq 1 $N4_ITER);
# do 

#         current_iter_flash=${FLASH_DIR_WARP}/data_flash_N4_${i}x.nii.gz
#         current_iter_flash_field=${FLASH_DIR_WARP}/field_flash_N4_${i}x.nii.gz

#         if [ $i == 1 ]
#         then 
#                 previous_iter_flash=${FLASH_DIR_WARP}/data_flash.nii.gz
#         else
#                 previous_iter_flash=${FLASH_DIR_WARP}/data_flash_N4_$( expr $i - 1 )x.nii.gz
#         fi

#         echo 'N4 FLASH: Run '${i}

#         N4BiasFieldCorrection -d 3 \
#                 -i $previous_iter_flash \
#                 -o [$current_iter_flash,$current_iter_flash_field]


# done

# # Get initial mask threshold from average image intensity
# MASK_THRESHOLD_FLASH=$(${FSL_LOCAL}/fslstats $current_iter_flash -m)

# echo "Creating mask for Ernst Angle FLASH data "
# MASKING_DONE="N"
# while [ "$MASKING_DONE" == "N" ]; do

#         # Generate mask by thresholing the b0 volumes (FLS maths)
#         ${FSL_LOCAL}/fslmaths \
#                 $current_iter_flash \
#                 -kernel 3D \
#                 -fmedian \
#                 -thr ${MASK_THRESHOLD_FLASH} \
#                 -bin \
#                 -fillh26 ${FLASH_DIR_WARP}/mask_flash.nii.gz \
#                 -odt int

#         # Extract the largest connected volume in generated mask
#         maskfilter \
#                 -force \
#                 -largest \
#                 ${FLASH_DIR_WARP}/mask_flash.nii.gz connect ${FLASH_DIR_WARP}/mask_flash_connect.nii.gz

#         # Dilate the mask 
#         maskfilter \
#                 -force \
#                 -npass 2 \
#                 ${FLASH_DIR_WARP}/mask_flash_connect.nii.gz dilate ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz

#         # Check the results
#         mrview \
#                 -load $current_iter_flash \
#                 -interpolation 0  \
#                 -mode 2 \
#                 -overlay.load ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz \
#                 -overlay.opacity 0.5 \
#                 -overlay.interpolation 0 \
#                 -overlay.colourmap 3 

#         echo "Did the script choose the correct threshold for the mask ? [Y/N]"
#         read MASKING_ANSWER

#         if [ $MASKING_ANSWER == "N" ]
#         then
#         # Find THRESHOLD VALUE in a histogram
#         echo 'Adapt MASK_THRESHOLD Variable in SET_VARIABLES.sh to exclude noise peak in histogram'
#         python3 ${SCRIPTS}/quickviz.py \
#                 --his $current_iter_flash \
#                 --loghis 

#         THRS_OLD=$MASK_THRESHOLD_FLASH # Saving old threshold in variable for replacement in SET_VARIABLES.txt

#         echo "Previous mask threshold value:"
#         echo $MASK_THRESHOLD_FLASH

#         echo 'Please provide new mask threshold value:'
#         read MASK_THRESHOLD_FLASH
#         echo "Repeating procedure with new threshold" ${MASK_THRESHOLD_FLASH}

#         # Saving mask string in set variables file
#         THRS_STR_OLD="MASK_THRESHOLD_FLASH=$THRS_OLD"
#         THRS_STR_NEW="MASK_THRESHOLD_FLASH=$MASK_THRESHOLD_FLASH"
     
#         elif [ $MASKING_ANSWER == "Y" ]
#         then
#         MASKING_DONE="Y"

#         else 
#         echo "Invalid answer, please repeat"


#         fi 

# done 

# mv -f ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz ${FLASH_DIR_WARP}/mask_flash.nii.gz
# rm -f ${FLASH_DIR_WARP}/mask_flash_*.nii.gz


echo 'Extracting and averaging b0s from Final Release dMRI Data'
# Extract b0 volumes
dwiextract \
        -force \
        -bzero \
        -fslgrad ${DIFF_DATA_DIR}/data.bvec_junarot ${DIFF_DATA_DIR}/data.bval_round \
        ${DIFF_DATA_RELEASE_DIR}/data.nii.gz \
        ${FLASH_DIR_WARP}/data_b0s.nii.gz

${FSL_LOCAL}/fslmaths \
        ${FLASH_DIR_WARP}/data_b0s.nii.gz \
        -Tmean \
        ${FLASH_DIR_WARP}/data_epi.nii.gz


MASK_EPI=${DIFF_DATA_DIR}/mask_junarot.nii.gz
# Multiple rounds of N4
echo 'Runing N4 on EPI Data'
for i in $(seq 1 $N4_ITER)
do 

        current_iter_epi=${FLASH_DIR_WARP}/data_epi_N4_${i}x.nii.gz
        current_iter_epi_field=${FLASH_DIR_WARP}/field_epi_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_epi=${FLASH_DIR_WARP}/data_epi.nii.gz
        else
                previous_iter_epi=${FLASH_DIR_WARP}/data_epi_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 EPI: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_epi \
                -x $MASK_EPI \
                -o [$current_iter_epi,$current_iter_epi_field]


done




data_move_N4=${FLASH_DIR_WARP}/data_flash_N4_${i}x.nii.gz
mask_move=${FLASH_DIR_WARP}/mask_flash.nii.gz

data_fix_N4=$current_iter_epi
mask_fix=$MASK_EPI



JUNAROT_MAT=${JUNAROT_DIR}/junarot.txt
/data/hu_paquette/tools/c3d-1.0.0-Linux-x86_64/bin/./c3d_affine_tool \
            ${JUNAROT_MAT} \
            -src ${data_move_N4} \
            -ref ${data_fix_N4} \
            -fsl2ras \
            -oitk ${FLASH_DIR_WARP}/init_to_junarot.mat



flirt -in ${data_move_N4} \
      -ref ${data_fix_N4} \
      -init ${JUNAROT_MAT} \
      -out ${FLASH_DIR_WARP}/data_flash_N4_${i}x_flirt_junarot.nii.gz \
      -applyxfm \
      -interp spline \
      -v



echo -e "\necho \"FLASH to EPI registration: Init junarot affine.\"" >> $THISLOG
echo "mrview -load ${data_fix_N4} -interpolation 0 -colourmap 1 -mode 2 -load ${FLASH_DIR_WARP}/data_flash_N4_${i}x_flirt_junarot.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG







echo 'Running SyN between FLASH and EPI'
antsRegistration --dimensionality 3 --float 1 \
        --output [${FLASH_DIR_WARP}/flash_to_epi_,${FLASH_DIR_WARP}/data_flash_warped.nii.gz] \
        --initial-moving-transform ${FLASH_DIR_WARP}/init_to_junarot.mat \
        --interpolation Linear \
        --winsorize-image-intensities [0.005,0.995] \
        --use-histogram-matching 0 \
        --transform Rigid[0.1] \
        --metric MI[$data_fix_N4,$data_move_N4,1,32,Regular,0.25] \
        --convergence [1000x500x250x100,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0 \
        --transform Affine[0.1] \
        --metric MI[$data_fix_N4,$data_move_N4,1,32,Regular,0.25] \
        --convergence [1000x500x250x100,1e-6,10] \
        --shrink-factors 8x4x2x1 \
        --smoothing-sigmas 3x2x1x0 \
        --transform SyN[0.1,3,0] \
        --metric CC[$data_fix_N4,$data_move_N4,1,4] \
        --convergence [400x200x100x50x40,1e-6,10] \
        --shrink-factors 16x8x4x2x1 \
        --smoothing-sigmas 4x3x2x1x0 \
        -x [$mask_fix,$mask_move] \
        -v 1



echo -e "\necho \"FLASH to EPI registration: Ants SyN.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_flash_N4_${i}x_flirt_junarot.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${data_fix_N4} -interpolation 0 -colourmap 1 -mode 2 -load ${FLASH_DIR_WARP}/data_flash_warped.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG







# Warp Flash multiple N4 to junarot for later segmentation and juna registration
echo "Warping N4 Flash data to JUNAROT"
AFFINE_FLASH_TO_JUNAROT=${FLASH_DIR_WARP}/flash_to_epi_0GenericAffine.mat
WARP_FLASH_TO_JUNAROT=${FLASH_DIR_WARP}/flash_to_epi_1Warp.nii.gz
IM_FIX=${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz
for TEMP_FOLDER in ${FLASH_DIR_FA05} ${FLASH_DIR_FA12p5} ${FLASH_DIR_FA25} ${FLASH_DIR_FA50} ${FLASH_DIR_FA80}; do
    IM_MOVE=${TEMP_FOLDER}/data_degibbs_N4_${N4_ITER}x.nii.gz
    IM_OUTPUT_tmp=${TEMP_FOLDER}/data_degibbs_N4_${N4_ITER}x_junarot_temp.nii.gz
    IM_OUTPUT=${TEMP_FOLDER}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz
    antsApplyTransforms \
        --dimensionality 3 \
        --input ${IM_MOVE} \
        --reference-image ${IM_FIX} \
        --interpolation BSpline \
        --transform ${WARP_FLASH_TO_JUNAROT} \
        --transform [${AFFINE_FLASH_TO_JUNAROT}, 0] \
        --output ${IM_OUTPUT_tmp}
        # clean the negatives from splines
    mrcalc ${IM_OUTPUT_tmp} 0 -max ${IM_OUTPUT}
    rm -f ${IM_OUTPUT_tmp}
done

IM_MOVE=${FLASH_DIR_WARP}/mask_flash.nii.gz
IM_OUTPUT=${FLASH_DIR_WARP}/mask_flash_junarot.nii.gz
antsApplyTransforms \
    --dimensionality 3 \
    --input ${IM_MOVE} \
    --reference-image ${IM_FIX} \
    --interpolation NearestNeighbor \
    --transform ${WARP_FLASH_TO_JUNAROT} \
    --transform [${AFFINE_FLASH_TO_JUNAROT}, 0] \
    --output ${IM_OUTPUT}




echo -e "\necho \"Check FLASH FA05 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA05}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA12p5 N4 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA25 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA50 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA80 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG

echo -e "\necho \"Check FLASH mask in JUNAROT space.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2 -overlay.load ${FLASH_DIR_WARP}/mask_flash_junarot.nii.gz -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3" >> $THISLOG













# # replace all that with affine UHR to FLASH and than use EPI TO FLASH

# echo 'Register Ultra High Res FLASH and EPI'

# echo "Runing Multiple N4 on UltraHighres FLASH Data"
# tmp_N4_ITER=3

# for i in $(seq 1 $tmp_N4_ITER)
# do 
#         p_CURRENT_ITER=${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_${i}x.nii.gz

#         if [ $i == 1 ]
#         then 
#                 p_PREVIOUS_ITER=${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs.nii.gz
#         else
#                 p_PREVIOUS_ITER=${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_$( expr $i - 1 )x.nii.gz
#         fi

#         echo 'N4 b0 dMRI: Run '${i}

#         N4BiasFieldCorrection -d 3 \
#                 -i ${p_PREVIOUS_ITER} \
#                 -o ${p_CURRENT_ITER}
# done

# echo 'Removing Zero Values from Unringing'
# fslmaths ${p_CURRENT_ITER} -thr 0 $( remove_ext ${p_CURRENT_ITER} )_thr.nii.gz





# p_DATA_MOVE=$current_iter_epi
# p_DATA_FIX=$( remove_ext ${p_CURRENT_ITER} )_thr.nii.gz

# echo 'Run antsRegistration'
# echo 'Data move: '$p_DATA_MOVE
# echo 'Data fix: '$p_DATA_FIX

# antsRegistration --dimensionality 3 --float 1 \
#         --output [${FLASH_DIR_WARP}/epi_to_ultrahighresflash_,${FLASH_DIR_WARP}/data_epi_warped_to_uhrflash.nii.gz] \
#         --interpolation Linear \
#         --winsorize-image-intensities [0.005,0.995] \
#         --use-histogram-matching 0 \
#         --transform Rigid[0.1] \
#         --metric MI[$p_DATA_FIX,$p_DATA_MOVE,1,32,Regular,0.25] \
#         --convergence [1000x500x250x100,1e-6,10] \
#         --shrink-factors 8x4x2x1 \
#         --smoothing-sigmas 3x2x1x0 \
#         --transform Affine[0.1] \
#         --metric MI[$p_DATA_FIX,$p_DATA_MOVE,1,32,Regular,0.25] \
#         --convergence [1000x500x250x100,1e-6,10] \
#         --shrink-factors 8x4x2x1 \
#         --smoothing-sigmas 3x2x1x0 \
#         --transform SyN[0.1,3,0] \
#         --metric CC[$p_DATA_FIX,$p_DATA_MOVE,1,4] \
#         --convergence [400x200x100x50x50,1e-6,10] \
#         --shrink-factors 16x8x4x2x1 \
#         --smoothing-sigmas 4x3x2x1x0 \
#         -v 1

# echo 'Apply Warp'
# antsApplyTransforms --dimensionality 3 --float 1 \
#         --input $p_DATA_FIX \
#         --reference-image $p_DATA_FIX \
#         --interpolation BSpline \
#         --transform ${FLASH_DIR_WARP}/epi_to_ultrahighresflash_1Inverse*nii.gz \
#         --transform [${FLASH_DIR_WARP}/epi_to_ultrahighresflash_0GenericAffine.mat,1] \
#         --output ${FLASH_DIR_WARP}/flash_ultrahighres_N4_3x_thr_reg.nii.gz \
#         -v 1


# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG

echo 'Done'

