#!/bin/bash


# Load Local Variables
source ./SET_VARIABLES.sh


# Set filenames for FLASH masks

# FLASH mask to unwrap processing folder
FOVARR=($FOV_MASK_PATHS)
FOV_MASK=''
for t in ${FOVARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    newfilename=${UNWRAP_PROC_DIR}/$filename'_flash.nii.gz' # add flash tag to original masks
    FOV_MASK+=$newfilename' '
done

OVERARR=($FOV_OVERLAP_PATHS)
FOV_OVERLAP=''
for t in ${OVERARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    newfilename=${UNWRAP_PROC_DIR}/$filename'_flash.nii.gz' # add flash tag to original masks
    FOV_OVERLAP+=$newfilename' '
done

FOVARR=($FOV_MASK)
OVERARR=($FOV_OVERLAP)







# # visual test and tweak of the mask over FLASH
# FLASHSCAN=${NII_RAW_DIR}/*X${FLASH_FA_25}P1.nii.gz
# # visual test and tweak of the mask over DWI
# B0SCAN=${NII_RAW_DIR}/*X${TOPUP_LR_RUN}P1.nii.gz





# # Create a quick mask from FLASH (5x N4, filtered thresholding and BET)
# IMAGE_FOR_MASK=${NII_RAW_DIR}/*X${FLASH_FA_25}P1.nii.gz






# APPLY FLASH MASK

# Apply correction for the 5 0.5mm FLASH
# Apply correction on the FA25 (where the FOV mask where done)
# We save the paddings from FA25 and force them on the other flash
IM_IN=${NII_RAW_DIR}/*X${FLASH_FA_25}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK \
        --maskover $FOV_OVERLAP \
        --out $IM_OUT \
        --outmask ${UNWRAP_DIR}/mask_FOV_extent_flash.nii.gz \
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




# IMAGE_FOR_MASK=${UNWRAP_PROC_DIR}/B0_vcorr_flashmaskdil.nii.gz


# # ANTs registration FLASH to DWI
# data_fix_N4=${UNWRAP_PROC_DIR}/data_dwi_N4_${N4_ITER}x.nii.gz
# #
# data_move_N4=${UNWRAP_PROC_DIR}/data_flash_mask_N4_${N4_ITER}x.nii.gz





# SET Mask names for DWI and Noise

# Wrap FOV mask to EPI raw space
FOV_MASK_DWI_PATHS=''
for t in ${FOVARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_dwi.nii.gz' # add _dwi
    FOV_MASK_DWI_PATHS+=$NEWNAME' '

done
# Wrap FOV mask to EPI raw space
FOV_OVERLAP_DWI_PATHS=''
for t in ${OVERARR[@]}; do
    filename=$(basename $t) # strip directory
    filename=${filename%.*} # string first extension
    filename=${filename%.*} # string second extension
    filename=${filename::-6} # strip the "_flash_"
    NEWNAME=${UNWRAP_PROC_DIR}/$filename'_dwi.nii.gz' # add _dwi
    FOV_OVERLAP_DWI_PATHS+=$NEWNAME' '
    
done



FOVARRDWI=($FOV_MASK_DWI_PATHS)
OVERARRDWI=($FOV_OVERLAP_DWI_PATHS)





# # visual test and tweak
# B0SCAN=${NII_RAW_DIR}/*X${TOPUP_LR_RUN}P1.nii.gz



# Apply to DWI and Noise

# Noisemap
IM_IN=${NII_RAW_DIR}/*X${NOISE_SCAN}P1.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK_DWI_PATHS \
        --maskover $FOV_OVERLAP_DWI_PATHS \
        --out $IM_OUT \
        --outmask ${UNWRAP_DIR}/mask_FOV_extent_noise.nii.gz \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)

# loop over DIFF_SCANS
# save FOV extent mask of EPI
for t in ${DIFF_SCANS[@]}; do
    IM_IN=${NII_RAW_DIR}/*X${t}P1.nii.gz;
    IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN);
    python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOV_MASK_DWI_PATHS \
        --maskover $FOV_OVERLAP_DWI_PATHS \
        --out $IM_OUT \
        --outmask ${UNWRAP_DIR}/mask_FOV_extent_epi.nii.gz \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)
done








if [ -n "$FLASH_HIGHRES" ]; then
  echo "Processing Flash Highres"

    # IM_FIX=${NII_RAW_DIR}/*X${FLASH_HIGHRES}P1.nii.gz
    # IM_MOV=${UNWRAP_PROC_DIR}/data_flash_mask_N4_${N4_ITER}x.nii.gz

    # Wrap FOV mask to HR FLASH raw space
    FOV_MASK_HR_PATHS=''
    for t in ${FOVARR[@]}; do
        filename=$(basename $t) # strip directory
        filename=${filename%.*} # string first extension
        filename=${filename%.*} # string second extension
        filename=${filename::-6} # strip the "_flash_"
        NEWNAME=${UNWRAP_PROC_DIR}/$filename'_hr.nii.gz' # add _hr

        FOV_MASK_HR_PATHS+=$NEWNAME' '

    done
    #
    FOV_OVERLAP_HR_PATHS=''
    for t in ${OVERARR[@]}; do
        filename=$(basename $t) # strip directory
        filename=${filename%.*} # string first extension
        filename=${filename%.*} # string second extension
        filename=${filename::-6} # strip the "_flash_"
        NEWNAME=${UNWRAP_PROC_DIR}/$filename'_hr.nii.gz' # add _hr
        
        FOV_OVERLAP_HR_PATHS+=$NEWNAME' '

    done


    FOVARRHR=($FOV_MASK_HR_PATHS)
    OVERARRHR=($FOV_OVERLAP_HR_PATHS)



    # # visual test and tweak of the mask over FLASH
    # HRSCAN=${NII_RAW_DIR}/*X${FLASH_HIGHRES}P1.nii.gz




    # HIGHRES
    IM_IN=${NII_RAW_DIR}/*X${FLASH_HIGHRES}P1.nii.gz
    IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
    python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
            --mask $FOV_MASK_HR_PATHS \
            --maskover $FOV_OVERLAP_HR_PATHS \
            --out $IM_OUT \
            --outmask ${UNWRAP_DIR}/mask_FOV_extent_HR.nii.gz \
            --pad 20




else
  echo "No Flash Highres specified, skipping"

fi





















if [ -n "$FLASH_ULTRA_HIGHRES" ]; then
  echo "Processing Flash Ultra Highres"

    # IM_FIX=${NII_RAW_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz
    # IM_MOV=${UNWRAP_PROC_DIR}/data_flash_mask_N4_${N4_ITER}x.nii.gz
    #


    # Wrap FOV mask to UHR FLASH raw space
    FOV_MASK_UHR_PATHS=''
    for t in ${FOVARR[@]}; do
        filename=$(basename $t) # strip directory
        filename=${filename%.*} # string first extension
        filename=${filename%.*} # string second extension
        filename=${filename::-6} # strip the "_flash_"
        NEWNAME=${UNWRAP_PROC_DIR}/$filename'_uhr.nii.gz' # add _uhr
        FOV_MASK_UHR_PATHS+=$NEWNAME' '

    done
    #
    FOV_OVERLAP_UHR_PATHS=''
    for t in ${OVERARR[@]}; do
        filename=$(basename $t) # strip directory
        filename=${filename%.*} # string first extension
        filename=${filename%.*} # string second extension
        filename=${filename::-6} # strip the "_flash_"
        NEWNAME=${UNWRAP_PROC_DIR}/$filename'_uhr.nii.gz' # add _uhr
        FOV_OVERLAP_UHR_PATHS+=$NEWNAME' '
        #

    done


    FOVARRUHR=($FOV_MASK_UHR_PATHS)
    OVERARRUHR=($FOV_OVERLAP_UHR_PATHS)








    # # visual test and tweak of the mask over FLASH
    # UHRSCAN=${NII_RAW_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz


    # ULTRAHIGHRES
    IM_IN=${NII_RAW_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz
    IM_OUT=${UNWRAP_DIR}/$(basename $IM_IN)
    python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
            --mask $FOV_MASK_UHR_PATHS \
            --maskover $FOV_OVERLAP_UHR_PATHS \
            --out $IM_OUT \
            --outmask ${UNWRAP_DIR}/mask_FOV_extent_UHR.nii.gz \
            --pad 40



else
  echo "No Flash Ultra Highres specified, skipping"

fi








echo $0 " Done" 

