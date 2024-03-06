#!/bin/bash

# EBC pipeline: Register Flash to EPI (Junarot), register HR and UHR to Flash
# inputs:
#
# Previous Steps:
#


# Load Local Variables
source ./SET_VARIABLES.sh



USE_VCORR=false
# USE_VCORR=true


# Init or clear viz log file 
THISLOG=${LOG_DIR}/11.sh
echo "# START-OF-PROC" > $THISLOG




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


DATA_B0=${FLASH_DIR_WARP}/data_epi.nii.gz
MASK_EPI=${DIFF_DATA_DIR}/mask_junarot.nii.gz
# MASK_EPI_VCORR=${FLASH_DIR_WARP}/mask_junarot_patched_for_vcorr.nii.gz
MASK_EPI_VCORR=${MASK_EPI}



if [ "$USE_VCORR" = true ] ; then
    echo "Using vcorr on B0 for Flash registration";
    #
    python3 ${SCRIPTS}/correct_intensity_1d.py \
            --in ${DATA_B0} \
            --out ${FLASH_DIR_WARP}/data_epi_vcorr.nii.gz \
            --mask ${MASK_EPI_VCORR} \
            --ori LR
    #
    DATA_B0=${FLASH_DIR_WARP}/data_epi_vcorr.nii.gz
    #
fi



# Multiple rounds of N4
echo 'Runing N4 on EPI Data'
for i in $(seq 1 $N4_ITER)
do 

        current_iter_epi=${FLASH_DIR_WARP}/data_epi_N4_${i}x.nii.gz
        current_iter_epi_field=${FLASH_DIR_WARP}/field_epi_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_epi=${DATA_B0}
        else
                previous_iter_epi=${FLASH_DIR_WARP}/data_epi_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 EPI: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_epi \
                -x $MASK_EPI \
                -o [$current_iter_epi,$current_iter_epi_field]

done




data_move_N4=${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz
mask_move=${FLASH_DIR_WARP}/mask_flash.nii.gz

data_fix_N4=${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz
mask_fix=$MASK_EPI



JUNAROT_MAT=${JUNAROT_DIR}/junarot.txt
${C3D_TOOL} \
            ${JUNAROT_MAT} \
            -src ${data_move_N4} \
            -ref ${data_fix_N4} \
            -fsl2ras \
            -oitk ${FLASH_DIR_WARP}/init_to_junarot.mat



flirt -in ${data_move_N4} \
      -ref ${data_fix_N4} \
      -init ${JUNAROT_MAT} \
      -out ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x_flirt_junarot.nii.gz \
      -applyxfm \
      -interp spline \
      # -v



echo -e "\necho \"FLASH to EPI registration: Init junarot affine.\"" >> $THISLOG
echo "mrview -load ${data_fix_N4} -interpolation 0 -colourmap 1 -mode 2 -load ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x_flirt_junarot.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG







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
echo "mrview -load ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x_flirt_junarot.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${data_fix_N4} -interpolation 0 -colourmap 1 -mode 2 -load ${FLASH_DIR_WARP}/data_flash_warped.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG







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
    mrcalc ${IM_OUTPUT_tmp} 0 -max ${IM_OUTPUT} -force
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
echo -e "echo \"Check FLASH FA12p5 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA25 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA50 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA80 N4 5x JUNAROT.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_epi_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2" >> $THISLOG

echo -e "\necho \"Check FLASH mask in JUNAROT space.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0 -mode 2 -overlay.load ${FLASH_DIR_WARP}/mask_flash_junarot.nii.gz -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3" >> $THISLOG







tmp_N4_ITER=3

if [ -n "$FLASH_HIGHRES" ]; then
    echo "Registering Highres to flash"

    echo "Runing Multiple N4 on Highres FLASH Data"
    cp ${FLASH_DIR_HIGHRES}/data_degibbs.nii.gz ${FLASH_DIR_HIGHRES}/data_degibbs_N4_0x.nii.gz
    for i in $(seq 1 $tmp_N4_ITER)
    do 
        echo "N4BiasFieldCorrection ${i} out of ${tmp_N4_ITER}"
        previous_iter_flash=${FLASH_DIR_HIGHRES}/data_degibbs_N4_$( expr $i - 1 )x.nii.gz
        current_iter_flash=${FLASH_DIR_HIGHRES}/data_degibbs_N4_${i}x.nii.gz
        #
        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_flash \
                -o $current_iter_flash
    done
    rm -f ${FLASH_DIR_HIGHRES}/data_degibbs_N4_0x.nii.gz
    #
    echo -e "\necho \"Check Flash HIGHRES 0x vs ${tmp_N4_ITER}x N4.\"" >> $THISLOG
    echo "mrview -load ${FLASH_DIR_HIGHRES}/data_degibbs.nii.gz -interpolation 0 -load ${FLASH_DIR_HIGHRES}/data_degibbs_N4_${tmp_N4_ITER}x.nii.gz -interpolation 0" >> $THISLOG
    #
    IM_FIX=${FLASH_DIR_HIGHRES}/data_degibbs_N4_${tmp_N4_ITER}x.nii.gz
    IM_MOV=${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz
    #
    # dof=12 FLASH to HIGHRES reg
    flirt -in ${IM_MOV} \
          -ref ${IM_FIX} \
          -omat ${FLASH_DIR_HIGHRES}/flash_to_hr_flash_dof12.txt \
          -dof 12
    #
    # Convert matrix to Ants
    ${C3D_TOOL} \
            ${FLASH_DIR_HIGHRES}/flash_to_hr_flash_dof12.txt \
            -src ${IM_MOV} \
            -ref ${IM_FIX} \
            -fsl2ras \
            -oitk ${FLASH_DIR_HIGHRES}/flash_to_hr_flash_dof12.mat
    #
    # Create Highres Flash space image for warping
    mrgrid \
        -voxel ${HIGHRES} \
        ${IM_MOV} \
        regrid \
        ${FLASH_DIR_HIGHRES}/flash_upsampled.nii.gz \
        -force
    # Warp HR to flash
    antsApplyTransforms \
        --dimensionality 3 \
        --input ${IM_FIX} \
        --reference-image ${FLASH_DIR_HIGHRES}/flash_upsampled.nii.gz \
        --interpolation Bspline \
        --transform [${FLASH_DIR_HIGHRES}/flash_to_hr_flash_dof12.mat, 1] \
        --output ${FLASH_DIR_HIGHRES}/HR_flash_space_tmp.nii.gz
    # clean the negatives from splines
    mrcalc ${FLASH_DIR_HIGHRES}/HR_flash_space_tmp.nii.gz 0 -max ${FLASH_DIR_HIGHRES}/HR_flash_space.nii.gz -force
    rm -f ${FLASH_DIR_HIGHRES}/HR_flash_space_tmp.nii.gz
    rm -f ${FLASH_DIR_HIGHRES}/flash_upsampled.nii.gz
    #
    echo -e "\necho \"Check Flash HIGHRES to FLASH registration.\"" >> $THISLOG
    echo "mrview -load ${IM_FIX} -interpolation 0 -load ${IM_MOV} -interpolation 0 -load ${FLASH_DIR_HIGHRES}/HR_flash_space.nii.gz -interpolation 0" >> $THISLOG

else
  echo "No Flash Highres specified, skipping"

fi



if [ -n "$FLASH_ULTRA_HIGHRES" ]; then
    echo "Registering Ultra Highres to flash"

    echo "Runing Multiple N4 on Ultra Highres FLASH Data"
    cp ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs.nii.gz ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_0x.nii.gz
    for i in $(seq 1 $tmp_N4_ITER)
    do 
        echo "N4BiasFieldCorrection ${i} out of ${tmp_N4_ITER}"
        previous_iter_flash=${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_$( expr $i - 1 )x.nii.gz
        current_iter_flash=${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_${i}x.nii.gz
        #
        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_flash \
                -o $current_iter_flash
    done
    rm -f ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_0x.nii.gz
    #
    echo -e "\necho \"Check Flash Ultra HIGHRES 0x vs ${tmp_N4_ITER}x N4.\"" >> $THISLOG
    echo "mrview -load ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs.nii.gz -interpolation 0 -load ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_${tmp_N4_ITER}x.nii.gz -interpolation 0" >> $THISLOG
    #
    IM_FIX=${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_${tmp_N4_ITER}x.nii.gz
    IM_MOV=${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz
    #
    # dof=12 FLASH to Ultra HIGHRES reg
    flirt -in ${IM_MOV} \
          -ref ${IM_FIX} \
          -omat ${FLASH_DIR_ULTRA_HIGHRES}/flash_to_uhr_flash_dof12.txt \
          -dof 12
    #
    # Convert matrix to Ants
    ${C3D_TOOL} \
            ${FLASH_DIR_ULTRA_HIGHRES}/flash_to_uhr_flash_dof12.txt \
            -src ${IM_MOV} \
            -ref ${IM_FIX} \
            -fsl2ras \
            -oitk ${FLASH_DIR_ULTRA_HIGHRES}/flash_to_uhr_flash_dof12.mat
    #
    # Create Ultra Highres Flash space image for warping
    mrgrid \
        -voxel ${ULTRA_HIGHRES} \
        ${IM_MOV} \
        regrid \
        ${FLASH_DIR_ULTRA_HIGHRES}/flash_upsampled.nii.gz \
        -force
    # Warp UHR to flash
    antsApplyTransforms \
        --dimensionality 3 \
        --input ${IM_FIX} \
        --reference-image ${FLASH_DIR_ULTRA_HIGHRES}/flash_upsampled.nii.gz \
        --interpolation Bspline \
        --transform [${FLASH_DIR_ULTRA_HIGHRES}/flash_to_uhr_flash_dof12.mat, 1] \
        --output ${FLASH_DIR_ULTRA_HIGHRES}/UHR_flash_space_tmp.nii.gz
    # clean the negatives from splines
    mrcalc ${FLASH_DIR_ULTRA_HIGHRES}/UHR_flash_space_tmp.nii.gz 0 -max ${FLASH_DIR_ULTRA_HIGHRES}/UHR_flash_space.nii.gz -force
    rm -f ${FLASH_DIR_ULTRA_HIGHRES}/UHR_flash_space_tmp.nii.gz
    rm -f ${FLASH_DIR_ULTRA_HIGHRES}/flash_upsampled.nii.gz
    #
    echo -e "\necho \"Check Flash Ultra HIGHRES to FLASH registration.\"" >> $THISLOG
    echo "mrview -load ${IM_FIX} -interpolation 0 -load ${IM_MOV} -interpolation 0 -load ${FLASH_DIR_ULTRA_HIGHRES}/UHR_flash_space.nii.gz -interpolation 0" >> $THISLOG

else
  echo "No Flash Ultra Highres specified, skipping"

fi






# Warp HR to JUNAROT
if [ -n "$FLASH_HIGHRES" ]; then
    echo "Warping Flash Highres to JUNAROT (HR) space"
    #
    # Create HR Junarot image for warping
    mrgrid \
        -voxel ${HIGHRES} \
        ${JUNAROT_DIR}/JUNAROT_space_ref.nii.gz \
        regrid \
        ${FLASH_DIR_HIGHRES}/JUNAROT_space_ref_upsampled.nii.gz \
        -force
    #
    antsApplyTransforms \
        --dimensionality 3 \
        --input ${FLASH_DIR_HIGHRES}/data_degibbs_N4_${tmp_N4_ITER}x.nii.gz \
        --reference-image ${FLASH_DIR_HIGHRES}/JUNAROT_space_ref_upsampled.nii.gz \
        --interpolation Bspline \
        --transform ${WARP_FLASH_TO_JUNAROT} \
        --transform [${AFFINE_FLASH_TO_JUNAROT}, 0] \
        --transform [${FLASH_DIR_HIGHRES}/flash_to_hr_flash_dof12.mat, 1] \
        --output ${FLASH_DIR_HIGHRES}/HR_junarot_space_tmp.nii.gz
    # clean the negatives from splines
    mrcalc ${FLASH_DIR_HIGHRES}/HR_junarot_space_tmp.nii.gz 0 -max ${FLASH_DIR_HIGHRES}/HR_junarot_space.nii.gz -force
    rm -f ${FLASH_DIR_HIGHRES}/HR_junarot_space_tmp.nii.gz
    rm -f ${FLASH_DIR_HIGHRES}/JUNAROT_space_ref_upsampled.nii.gz
    #
    echo -e "\necho \"Check Flash HIGHRES Junarot registration.\"" >> $THISLOG
    echo "mrview -load ${FLASH_DIR_HIGHRES}/HR_junarot_space.nii.gz -interpolation 0 -load ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0" >> $THISLOG

fi


# Warp UHR to JUNAROT
if [ -n "$FLASH_ULTRA_HIGHRES" ]; then
    echo "Warping Flash Ultra Highres to JUNAROT (UHR) space"
    #
    # Create HR Junarot image for warping
    mrgrid \
        -voxel ${ULTRA_HIGHRES} \
        ${JUNAROT_DIR}/JUNAROT_space_ref.nii.gz \
        regrid \
        ${FLASH_DIR_ULTRA_HIGHRES}/JUNAROT_space_ref_upsampled.nii.gz \
        -force
    #
    antsApplyTransforms \
        --dimensionality 3 \
        --input ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_N4_${tmp_N4_ITER}x.nii.gz \
        --reference-image ${FLASH_DIR_ULTRA_HIGHRES}/JUNAROT_space_ref_upsampled.nii.gz \
        --interpolation Bspline \
        --transform ${WARP_FLASH_TO_JUNAROT} \
        --transform [${AFFINE_FLASH_TO_JUNAROT}, 0] \
        --transform [${FLASH_DIR_ULTRA_HIGHRES}/flash_to_uhr_flash_dof12.mat, 1] \
        --output ${FLASH_DIR_ULTRA_HIGHRES}/UHR_junarot_space_tmp.nii.gz
    # clean the negatives from splines
    mrcalc ${FLASH_DIR_ULTRA_HIGHRES}/UHR_junarot_space_tmp.nii.gz 0 -max ${FLASH_DIR_ULTRA_HIGHRES}/UHR_junarot_space.nii.gz -force
    rm -f ${FLASH_DIR_ULTRA_HIGHRES}/UHR_junarot_space_tmp.nii.gz
    rm -f ${FLASH_DIR_ULTRA_HIGHRES}/JUNAROT_space_ref_upsampled.nii.gz
    #
    echo -e "\necho \"Check Flash Ultra HIGHRES Junarot registration.\"" >> $THISLOG
    echo "mrview -load ${FLASH_DIR_ULTRA_HIGHRES}/UHR_junarot_space.nii.gz -interpolation 0 -load ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz -interpolation 0" >> $THISLOG

fi






# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG

echo 'Done'

