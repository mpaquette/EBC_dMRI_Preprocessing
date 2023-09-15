#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh
source ${FSL_LOCAL}/../etc/fslconf/fsl.sh



# # Copy nii files to topup directory
# echo "Copy nii files to topup directory"
# cp ${NII_RAW_DIR}/*X${TOPUP_LR_RUN}P1.nii.gz ${TOPUP_DIR}/data_LR.nii.gz

# if [ $FLAG_TOPUP_RETRO_RECON == "NO" ]; then
#     cp ${NII_RAW_DIR}/*X${TOPUP_RL_RUN}P1.nii.gz ${TOPUP_DIR}/data_RL.nii.gz

# elif [[ $FLAG_TOPUP_RETRO_RECON == "YES" ]]; then
#     cp ${NII_RAW_DIR}/*X${TOPUP_RL_RUN}P${RETRO_RECON_NUMBER}.nii.gz ${TOPUP_DIR}/data_RL.nii.gz

# else
#     echo 'Please Specify $FLAG_TOPUP_RETRO_RECON'
# fi

# grab wrap raw data for rolling
RAW_LR=${NII_RAW_DIR}/*X${TOPUP_LR_RUN}P1.nii.gz

if [ $FLAG_TOPUP_RETRO_RECON == "NO" ]; then
    RAW_RL=${NII_RAW_DIR}/*X${TOPUP_RL_RUN}P1.nii.gz

elif [[ $FLAG_TOPUP_RETRO_RECON == "YES" ]]; then
    RAW_RL=${NII_RAW_DIR}/*X${TOPUP_RL_RUN}P${RETRO_RECON_NUMBER}.nii.gz

else
    echo 'Please Specify $FLAG_TOPUP_RETRO_RECON'
fi




# invert and shift in raw_nift space
python3 ${SCRIPTS}/roll_align_data.py \
    --in $RAW_RL \
    --ref $RAW_LR \
    --out ${UNWRAP_PROC_DIR}/RL_shift_raw.nii.gz \
    --axis 1 \
    --inv




# Prep FOV EPI space mask list variable
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
done
FOVARRDWI=($FOV_MASK_DWI_PATHS)
OVERARRDWI=($FOV_OVERLAP_DWI_PATHS)





# this doesnt really work, it cuts little part off
# because of mask mismatch
IM_IN=${UNWRAP_PROC_DIR}/RL_shift_raw.nii.gz
IM_OUT=${UNWRAP_DIR}/$(basename $RAW_RL)
python3 ${SCRIPTS}/data_FOV_patch.py --data $IM_IN \
        --mask $FOVARRDWI \
        --maskover $OVERARRDWI \
        --out $IM_OUT \
        --pad $(cat ${UNWRAP_PROC_DIR}/total_padding.txt)


cp ${UNWRAP_DIR}/*X${TOPUP_LR_RUN}P1.nii.gz ${TOPUP_DIR}/data_LR.nii.gz
cp $IM_OUT ${TOPUP_DIR}/data_RL.nii.gz


echo "Reshape image matrix to resemble MNI space"
python3 ${SCRIPTS}/reshape_volume.py \
    --in ${TOPUP_DIR}/data_LR.nii.gz \
    --out ${TOPUP_DIR}/data_LR_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}

python3 ${SCRIPTS}/reshape_volume.py \
    --in ${TOPUP_DIR}/data_RL.nii.gz \
    --out ${TOPUP_DIR}/data_RL_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}


echo "Combine the corrected data"
${FSL_LOCAL}/fslmerge -t \
    ${TOPUP_DIR}/data.nii.gz \
    ${TOPUP_DIR}/data_LR_reshape.nii.gz \
    ${TOPUP_DIR}/data_RL_reshape.nii.gz




echo "Runing Multiple N4 on dMRI b0 Data"
for i in $(seq 1 $N4_ITER)
do 
        CURRENT_ITER_B0=${TOPUP_DIR}/data_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                PREVIOUS_ITER_B0=${TOPUP_DIR}/data.nii.gz
        else
                PREVIOUS_ITER_B0=${TOPUP_DIR}/data_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 b0 dMRI: Run '${i}

        N4BiasFieldCorrection -d 4 \
                -i ${PREVIOUS_ITER_B0} \
                -o ${CURRENT_ITER_B0} -v
done


# Display Topup Corrected Data
echo "Show Data for Topup"
mrview \
    -load ${CURRENT_ITER_B0} \
    -interpolation 0 \
    -mode 2





# Run Topup Algorithm
echo "Run Topup Algorithm"
${FSL_LOCAL}/topup \
    --imain=${CURRENT_ITER_B0} \
    --datain=${CONFIG_DIR}/topup/acqp \
    --config=${CONFIG_DIR}/topup/b02b0.cnf \
    --out=${TOPUP_DIR}/topup \
    --fout=${TOPUP_DIR}/topup_field.nii.gz \
    --iout=${TOPUP_DIR}/data_unwarp.nii.gz \
    -v 

# Display Topup Corrected Data
echo "Show Corrected Data"
mrview \
    -load ${CURRENT_ITER_B0} \
    -interpolation 0 \
    -load ${TOPUP_DIR}/data_unwarp.nii.gz \
    -interpolation 0 \
    -load ${TOPUP_DIR}/topup_field.nii.gz \
    -interpolation 0 \
    -mode 2


echo $0 " Done" 