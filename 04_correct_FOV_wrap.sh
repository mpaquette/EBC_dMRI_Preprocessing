#!/bin/bash


# EBC pipeline: Correct Field-of-View wraping on raw Nifti images
# inputs:
# - raw Nifti DWI
# - raw Nifti Noisemap
# - raw Nifti FLASH
# - raw Nifti HIRES FLASH
# - raw Nifti UHR FLASH
# - hand drawn FOV wrap mask on FLASH image


# Load Local Variables
source ./SET_VARIABLES.sh


# copy mask to unwrap processing folder
FOVARR=($FOV_MASK_PATHS)
FOV_MASK=''
for t in ${FOVARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    newfilename=${UNWRAP_PROC_DIR}/$filename'_flash.nii.gz' # add flash tag to original masks
    cp $t $newfilename
    FOV_MASK+=$newfilename' '
done

OVERARR=($FOV_OVERLAP_PATHS)
FOV_OVERLAP=''
for t in ${OVERARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    newfilename=${UNWRAP_PROC_DIR}/$filename'_flash.nii.gz' # add flash tag to original masks
    cp $t $newfilename
    FOV_OVERLAP+=$newfilename' '
done

FOVARR=($FOV_MASK)
OVERARR=($FOV_OVERLAP)




# # visual test and tweak of the mask over FLASH
# FLASHSCAN=${NII_RAW_DIR}/*X${FLASH_FA_25}P1.nii.gz

# ## craft mrview command for mask
# MRVIEW_STRING_FOVMASK=''
# for t in ${FOVARR[@]}; do
#   MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 0,0,1 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
# done

# MRVIEW_STRING_OVERMASK=''
# for t in ${OVERARR[@]}; do
#   MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
# done

# mrview $FLASHSCAN -interpolation 0 $MRVIEW_STRING_FOVMASK $MRVIEW_STRING_OVERMASK

# # visual test and tweak of the mask over DWI
# B0SCAN=${NII_RAW_DIR}/*X${TOPUP_LR_RUN}P1.nii.gz
# mrview $B0SCAN -interpolation 0 $MRVIEW_STRING_FOVMASK $MRVIEW_STRING_OVERMASK




# Create a quick mask from FLASH (5x N4, filtered thresholding and BET)
IMAGE_FOR_MASK=${NII_RAW_DIR}/*X${FLASH_FA_25}P1.nii.gz

echo 'Runing N4 on FLASH Data'
for i in $(seq 1 $N4_ITER);
do 

    current_iter_flash=${UNWRAP_PROC_DIR}/data_flash_mask_N4_${i}x.nii.gz

    if [ $i == 1 ]
    then 
            previous_iter_flash=$IMAGE_FOR_MASK
    else
            previous_iter_flash=${UNWRAP_PROC_DIR}/data_flash_mask_N4_$( expr $i - 1 )x.nii.gz
    fi

    echo 'N4 FLASH: Run '${i}

    N4BiasFieldCorrection -d 3 \
            -i $previous_iter_flash \
            -o $current_iter_flash


done


# Get initial mask threshold from average image intensity
MASK_THRESHOLD_FLASH=$(${FSL_LOCAL}/fslstats $current_iter_flash -m)
MASK_THRESHOLD_FLASH=$(echo "scale=6 ; $MASK_THRESHOLD_FLASH / 2" | bc)



# Generate mask by thresholding the flash volumes (FSL maths)
${FSL_LOCAL}/fslmaths \
        $current_iter_flash \
        -kernel 3D \
        -fmedian \
        -thr ${MASK_THRESHOLD_FLASH} \
        -bin \
        -fillh26 ${UNWRAP_PROC_DIR}/mask_th_flash.nii.gz \
        -odt int




# mrview $current_iter_flash \
#        -overlay.load ${UNWRAP_PROC_DIR}/mask_th_flash.nii.gz -overlay.opacity 0.4 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1




bet2 $current_iter_flash \
     ${UNWRAP_PROC_DIR}/flash_bet \
     -m \
     -n \
     -f 0.1 \
     -r 60 \
     -v



# mrview $current_iter_flash \
#        -overlay.load ${UNWRAP_PROC_DIR}/flash_bet_mask.nii.gz -overlay.opacity 0.2 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 1 \
#        -overlay.load ${UNWRAP_PROC_DIR}/mask_th_flash.nii.gz  -overlay.opacity 0.2 -overlay.colour 0,0,1 -overlay.interpolation 0 -overlay.threshold_min 1 \



# add threshold mask and BET mask ofr final FLASH mask
fslmaths      ${UNWRAP_PROC_DIR}/mask_th_flash.nii.gz \
         -add ${UNWRAP_PROC_DIR}/flash_bet_mask.nii.gz \
         -bin \
              ${UNWRAP_PROC_DIR}/mask_flash.nii.gz


maskfilter ${UNWRAP_PROC_DIR}/mask_flash.nii.gz \
           connect \
           -largest \
           ${UNWRAP_PROC_DIR}/mask_flash_largest.nii.gz



# mrview $current_iter_flash \
#        -overlay.load ${UNWRAP_PROC_DIR}/mask_flash.nii.gz -overlay.opacity 0.4 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1





# Apply correction for the 5 0.5mm FLASH
# Apply correction on the FA25 (where the FOV mask where done)
# We save the paddings from FA25 and force them on the other flash
IM_IN=${NII_RAW_DIR}/*X${FLASH_FA_25}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK \
        --maskover $FOV_OVERLAP \
        --out $IM_OUT \
        --outmask ${UNWRAP_DIR}/mask.nii.gz \
        --outpad ${UNWRAP_PROC_DIR}/total_padding.txt


IM_IN=${NII_RAW_DIR}/*X${FLASH_FA_05}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK \
        --maskover $FOV_OVERLAP \
        --out $IM_OUT \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)


IM_IN=${NII_RAW_DIR}/*X${FLASH_FA_12p5}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK \
        --maskover $FOV_OVERLAP \
        --out $IM_OUT \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)


IM_IN=${NII_RAW_DIR}/*X${FLASH_FA_50}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK \
        --maskover $FOV_OVERLAP \
        --out $IM_OUT \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)


IM_IN=${NII_RAW_DIR}/*X${FLASH_FA_80}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK \
        --maskover $FOV_OVERLAP \
        --out $IM_OUT \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)




# mrview ${NII_RAW_DIR}/*X${FLASH_FA_05}P1.nii.gz   ${UNWRAP_DIR}/*X${FLASH_FA_05}P1.nii.gz
# mrview ${NII_RAW_DIR}/*X${FLASH_FA_12p5}P1.nii.gz ${UNWRAP_DIR}/*X${FLASH_FA_12p5}P1.nii.gz
# mrview ${NII_RAW_DIR}/*X${FLASH_FA_25}P1.nii.gz   ${UNWRAP_DIR}/*X${FLASH_FA_25}P1.nii.gz
# mrview ${NII_RAW_DIR}/*X${FLASH_FA_50}P1.nii.gz   ${UNWRAP_DIR}/*X${FLASH_FA_50}P1.nii.gz
# mrview ${NII_RAW_DIR}/*X${FLASH_FA_80}P1.nii.gz   ${UNWRAP_DIR}/*X${FLASH_FA_80}P1.nii.gz






# Create DWI mask
# dilate flash mask with sphere r=2vox
fslmaths ${UNWRAP_PROC_DIR}/mask_flash_largest.nii.gz \
         -kernel sphere 1.0 \
         -dilM \
         -bin \
         ${UNWRAP_PROC_DIR}/mask_flash_largest_dil.nii.gz \
         -odt int



# Register FLASH to DWI
# vcorr B0 with dilated flash mask (for ANTs reg)
python3 ${SCRIPTS}/correct_intensity_1d.py --in ${NII_RAW_DIR}/*X${CHECK_REORIENT_SCAN}P1.nii.gz \
                                           --out ${UNWRAP_PROC_DIR}/B0_vcorr_flashmaskdil.nii.gz \
                                           --mask ${UNWRAP_PROC_DIR}/mask_flash_largest_dil.nii.gz \
                                           --ori AP






# 5x N4 the vcorr B0 (for ANTs reg)
IMAGE_FOR_MASK=${UNWRAP_PROC_DIR}/B0_vcorr_flashmaskdil.nii.gz
echo 'Runing N4 on DWI Data'
for i in $(seq 1 $N4_ITER);
do 
    current_iter_dwi=${UNWRAP_PROC_DIR}/data_dwi_N4_${i}x.nii.gz
    if [ $i == 1 ]
    then 
            previous_iter_dwi=$IMAGE_FOR_MASK
    else
            previous_iter_dwi=${UNWRAP_PROC_DIR}/data_dwi_N4_$( expr $i - 1 )x.nii.gz
    fi
    echo 'N4 DWI: Run '${i}
    N4BiasFieldCorrection -d 3 \
            -i $previous_iter_dwi \
            -o $current_iter_dwi
done






# ANTs registration FLASH to DWI
data_fix_N4=$current_iter_dwi
#
data_move_N4=$current_iter_flash
#
echo 'Running SyN between FLASH and EPI'
antsRegistration --dimensionality 3 --float 1 \
        --output [${UNWRAP_PROC_DIR}/flash_to_epi_,${UNWRAP_PROC_DIR}/data_flash_warped_to_epi.nii.gz] \
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
        -v 1





# Wrap FOV mask to EPI raw space
FOV_MASK_DWI_PATHS=''
for t in ${FOVARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_dwi.nii.gz' # add _dwi
    NEWNAMETMP=${UNWRAP_PROC_DIR}/$filename'_dwi_tmp.nii.gz' # add _dwi
    FOV_MASK_DWI_PATHS+=$NEWNAME' '
    #
    antsApplyTransforms --dimensionality 3 --float 1 \
            --input $t \
            --reference-image $data_fix_N4 \
            --interpolation NearestNeighbor \
            --transform ${UNWRAP_PROC_DIR}/flash_to_epi_1Warp.nii.gz \
            --transform [${UNWRAP_PROC_DIR}/flash_to_epi_0GenericAffine.mat,0] \
            --output $NEWNAMETMP \
            -v 1
    #
    ${FSL_LOCAL}/fslmaths \
            $NEWNAMETMP \
            -fillh26 \
            $NEWNAME \
            -odt int
    #
    rm -f $NEWNAMETMP
done
# Wrap FOV mask to EPI raw space
FOV_OVERLAP_DWI_PATHS=''
for t in ${OVERARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_dwi.nii.gz' # add _dwi
    NEWNAMETMP=${UNWRAP_PROC_DIR}/$filename'_dwi_tmp.nii.gz' # add _dwi
    FOV_OVERLAP_DWI_PATHS+=$NEWNAME' '
    #
    antsApplyTransforms --dimensionality 3 --float 1 \
            --input $t \
            --reference-image $data_fix_N4 \
            --interpolation NearestNeighbor \
            --transform ${UNWRAP_PROC_DIR}/flash_to_epi_1Warp.nii.gz \
            --transform [${UNWRAP_PROC_DIR}/flash_to_epi_0GenericAffine.mat,0] \
            --output $NEWNAMETMP \
            -v 1
    #
    ${FSL_LOCAL}/fslmaths \
            $NEWNAMETMP \
            -fillh26 \
            $NEWNAME \
            -odt int
    #
    rm -f $NEWNAMETMP
done



FOVARRDWI=($FOV_MASK_DWI_PATHS)
OVERARRDWI=($FOV_OVERLAP_DWI_PATHS)







# # visual test and tweak
# B0SCAN=${NII_RAW_DIR}/*X${TOPUP_LR_RUN}P1.nii.gz

# ## craft mrview command for mask
# MRVIEW_STRING_FOVMASK=''
# for t in ${FOVARRDWI[@]}; do
#   MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 0,0,1 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
# done

# MRVIEW_STRING_OVERMASK=''
# for t in ${OVERARRDWI[@]}; do
#   MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
# done

# mrview $B0SCAN    -interpolation 0 $MRVIEW_STRING_FOVMASK $MRVIEW_STRING_OVERMASK








# Noisemap
IM_IN=${NII_RAW_DIR}/*X${NOISE_SCAN}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK_DWI_PATHS \
        --maskover $FOV_OVERLAP_DWI_PATHS \
        --out $IM_OUT \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)


# loop over DIFF_SCANS
for t in ${DIFF_SCANS[@]}; do
    IM_IN=${NII_RAW_DIR}/*X${t}P1.nii.gz;
    IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN);
    python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK_DWI_PATHS \
        --maskover $FOV_OVERLAP_DWI_PATHS \
        --out $IM_OUT \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)
done



# viz
for t in ${DIFF_SCANS[@]}; do
    IM_IN=${NII_RAW_DIR}/*X${t}P1.nii.gz;
    IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN);
    mrview $IM_IN $IM_OUT
done










IM_FIX=${NII_RAW_DIR}/*X${FLASH_HIGHRES}P1.nii.gz
IM_MOV=$current_iter_flash
#
# mrview $IM_FIX $IM_MOV

# # dof=6 FLASH to HIGHRES reg
flirt -in $IM_MOV \
      -ref $IM_FIX \
      -omat ${UNWRAP_PROC_DIR}/flash_to_hr_flash.txt \
      -dof 6 \
      -out ${UNWRAP_PROC_DIR}/data_flash_warped_to_hr.nii.gz \
      -v

# mrview $IM_FIX ${UNWRAP_PROC_DIR}/data_flash_warped_to_hr.nii.gz





# Wrap FOV mask to HR FLASH raw space
FOV_MASK_HR_PATHS=''
for t in ${FOVARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_hr.nii.gz' # add _hr
    NEWNAMETMP=${UNWRAP_PROC_DIR}/$filename'_hr_tmp.nii.gz' # add _hr
    FOV_MASK_HR_PATHS+=$NEWNAME' '
    #
    flirt -in $t \
          -ref $IM_FIX \
          -init ${UNWRAP_PROC_DIR}/flash_to_hr_flash.txt \
          -dof 6 \
          -interp trilinear \
          -applyxfm \
          -out $NEWNAMETMP \
          -v
    #
    ${FSL_LOCAL}/fslmaths \
            $NEWNAMETMP \
            -thr 0.1 \
            -bin \
            -fillh26 \
            $NEWNAME \
            -odt int
    #
    rm -f $NEWNAMETMP
done
#
FOV_OVERLAP_HR_PATHS=''
for t in ${OVERARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_hr.nii.gz' # add _hr
    NEWNAMETMP=${UNWRAP_PROC_DIR}/$filename'_hr_tmp.nii.gz' # add _hr
    FOV_OVERLAP_HR_PATHS+=$NEWNAME' '
    #
    flirt -in $t \
          -ref $IM_FIX \
          -init ${UNWRAP_PROC_DIR}/flash_to_hr_flash.txt \
          -dof 6 \
          -interp trilinear \
          -applyxfm \
          -out $NEWNAMETMP \
          -v
    #
    ${FSL_LOCAL}/fslmaths \
            $NEWNAMETMP \
            -thr 0.1 \
            -bin \
            -fillh26 \
            $NEWNAME \
            -odt int
    #
    rm -f $NEWNAMETMP
done


FOVARRHR=($FOV_MASK_HR_PATHS)
OVERARRHR=($FOV_OVERLAP_HR_PATHS)





for t in ${FOVARRHR[@]}; do
    python3 ${SCRIPTS}/fix_hires_fovmask.py \
            $t \
            $t \
            1
done








# # visual test and tweak of the mask over FLASH
# HRSCAN=${NII_RAW_DIR}/*X${FLASH_HIGHRES}P1.nii.gz

# ## craft mrview command for mask
# MRVIEW_STRING_FOVMASK=''
# for t in ${FOVARRHR[@]}; do
#   MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 0,0,1 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
# done

# MRVIEW_STRING_OVERMASK=''
# for t in ${OVERARRHR[@]}; do
#   MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
# done

# mrview $HRSCAN -interpolation 0 $MRVIEW_STRING_FOVMASK $MRVIEW_STRING_OVERMASK






# HIGHRES
IM_IN=${NII_RAW_DIR}/*X${FLASH_HIGHRES}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK_HR_PATHS \
        --maskover $FOV_OVERLAP_HR_PATHS \
        --out $IM_OUT \
        --pad 20




# mrview ${NII_RAW_DIR}/*X${FLASH_HIGHRES}P1.nii.gz   ${UNWRAP_DIR}/*X${FLASH_HIGHRES}P1.nii.gz


















IM_FIX=${NII_RAW_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz
IM_MOV=$current_iter_flash
#
mrview $IM_FIX $IM_MOV

# # dof=6 FLASH to HIGHRES reg
flirt -in $IM_MOV \
      -ref $IM_FIX \
      -omat ${UNWRAP_PROC_DIR}/flash_to_uhr_flash.txt \
      -dof 6 \
      -out ${UNWRAP_PROC_DIR}/data_flash_warped_to_uhr.nii.gz \
      -v

# mrview $IM_FIX ${UNWRAP_PROC_DIR}/data_flash_warped_to_uhr.nii.gz





# Wrap FOV mask to UHR FLASH raw space
FOV_MASK_UHR_PATHS=''
for t in ${FOVARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_uhr.nii.gz' # add _uhr
    NEWNAMETMP=${UNWRAP_PROC_DIR}/$filename'_uhr_tmp.nii.gz' # add _uhr
    FOV_MASK_UHR_PATHS+=$NEWNAME' '
    #
    flirt -in $t \
          -ref $IM_FIX \
          -init ${UNWRAP_PROC_DIR}/flash_to_uhr_flash.txt \
          -dof 6 \
          -interp trilinear \
          -applyxfm \
          -out $NEWNAMETMP \
          -v
    #
    ${FSL_LOCAL}/fslmaths \
            $NEWNAMETMP \
            -thr 0.1 \
            -bin \
            -fillh26 \
            $NEWNAME \
            -odt int
    #
    rm -f $NEWNAMETMP
done
#
FOV_OVERLAP_UHR_PATHS=''
for t in ${OVERARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_uhr.nii.gz' # add _uhr
    NEWNAMETMP=${UNWRAP_PROC_DIR}/$filename'_uhr_tmp.nii.gz' # add _uhr
    FOV_OVERLAP_UHR_PATHS+=$NEWNAME' '
    #
    flirt -in $t \
          -ref $IM_FIX \
          -init ${UNWRAP_PROC_DIR}/flash_to_uhr_flash.txt \
          -dof 6 \
          -interp trilinear \
          -applyxfm \
          -out $NEWNAMETMP \
          -v
    #
    ${FSL_LOCAL}/fslmaths \
            $NEWNAMETMP \
            -thr 0.1 \
            -bin \
            -fillh26 \
            $NEWNAME \
            -odt int
    #
    rm -f $NEWNAMETMP
done


FOVARRUHR=($FOV_MASK_UHR_PATHS)
OVERARRUHR=($FOV_OVERLAP_UHR_PATHS)





for t in ${FOVARRUHR[@]}; do
    python3 ${SCRIPTS}/fix_hires_fovmask.py \
            $t \
            $t \
            2
done








# visual test and tweak of the mask over FLASH
UHRSCAN=${NII_RAW_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz

## craft mrview command for mask
MRVIEW_STRING_FOVMASK=''
for t in ${FOVARRUHR[@]}; do
  MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 0,0,1 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
done

MRVIEW_STRING_OVERMASK=''
for t in ${OVERARRUHR[@]}; do
  MRVIEW_STRING_FOVMASK+='-overlay.load '$t' -overlay.opacity 0.4 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1 '
done

mrview $UHRSCAN -interpolation 0 $MRVIEW_STRING_FOVMASK $MRVIEW_STRING_OVERMASK











# ULTRAHIGHRES
IM_IN=${NII_RAW_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK_UHR_PATHS \
        --maskover $FOV_OVERLAP_UHR_PATHS \
        --out $IM_OUT \
        --pad 40




mrview ${NII_RAW_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz   ${UNWRAP_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz


















