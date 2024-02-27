#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh


# Init or clear viz log file 
THISLOG=${LOG_DIR}/13.sh
echo "# START-OF-PROC" > $THISLOG


echo 'Copy Files to Segmentation Directory'
# Copy FLASH Data to segmentation directory
ln -s ${FLASH_DIR_FA05}/data_degibbs.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr1_degibbs.nii.gz
ln -s ${FLASH_DIR_FA12p5}/data_degibbs.nii.gz  ${TISSUE_SEGMENTATION_DIR}/flash_contr2_degibbs.nii.gz
ln -s ${FLASH_DIR_FA25}/data_degibbs.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr3_degibbs.nii.gz
ln -s ${FLASH_DIR_FA50}/data_degibbs.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr4_degibbs.nii.gz
ln -s ${FLASH_DIR_FA80}/data_degibbs.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr5_degibbs.nii.gz



# Copy DTI Data to segmentation directory
ln -s ${DTI_DIR}/dti_FA.nii.gz ${TISSUE_SEGMENTATION_DIR}/dti_FA.nii.gz
ln -s ${DTI_DIR}/dti_MD.nii.gz ${TISSUE_SEGMENTATION_DIR}/dti_MD.nii.gz
ln -s ${DTI_DIR}/dti_RD.nii.gz ${TISSUE_SEGMENTATION_DIR}/dti_RD.nii.gz

# Copy b0 data from dti fit to segmentation directory
ln -s ${DTI_DIR}/dti_S0.nii.gz ${TISSUE_SEGMENTATION_DIR}/data_b0.nii.gz

# Copy mean diff data from releasre norm forlder to segmentation directory
ln -s ${DIFF_DATA_NORM_RELEASE_DIR}/data_norm_mean.nii.gz ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz


# Copy mask to segmentation directory
ln -s ${DIFF_DATA_RELEASE_DIR}/mask.nii.gz ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz



echo "Runing 5 x N4 on dMRI b0 Data"
for i in $(seq 1 $N4_ITER)
do 
        current_iter_b0=${TISSUE_SEGMENTATION_DIR}/data_b0_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_b0=${TISSUE_SEGMENTATION_DIR}/data_b0.nii.gz
        else
                previous_iter_b0=${TISSUE_SEGMENTATION_DIR}/data_b0_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 b0 dMRI: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_b0 \
                -x ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz \
                -o $current_iter_b0
done



ln -s ${FLASH_DIR_FA05}/data_degibbs_N4_${N4_ITER}x.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr1_degibbs_N4_${N4_ITER}x.nii.gz
ln -s ${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x.nii.gz  ${TISSUE_SEGMENTATION_DIR}/flash_contr2_degibbs_N4_${N4_ITER}x.nii.gz
ln -s ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr3_degibbs_N4_${N4_ITER}x.nii.gz
ln -s ${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr4_degibbs_N4_${N4_ITER}x.nii.gz
ln -s ${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr5_degibbs_N4_${N4_ITER}x.nii.gz


ln -s ${FLASH_DIR_FA05}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr1_warp.nii.gz
ln -s ${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz  ${TISSUE_SEGMENTATION_DIR}/flash_contr2_warp.nii.gz
ln -s ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr3_warp.nii.gz
ln -s ${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr4_warp.nii.gz
ln -s ${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x_junarot.nii.gz    ${TISSUE_SEGMENTATION_DIR}/flash_contr5_warp.nii.gz





echo 'Run fuzzy 2-class segmentation without FA'
python3 ${SCRIPTS}/fuzzyseg.py \
    --data  ${TISSUE_SEGMENTATION_DIR}/dti_MD.nii.gz \
            $current_iter_b0 \
            ${TISSUE_SEGMENTATION_DIR}/dti_RD.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr1_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr2_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr3_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr4_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr5_warp.nii.gz \
    --mask  ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz \
    --n 2 \
    --out   ${TISSUE_SEGMENTATION_DIR}'/noFA_'


echo 'Run fuzzy 3-class segmentation without FA'
python3 ${SCRIPTS}/fuzzyseg.py \
    --data  ${TISSUE_SEGMENTATION_DIR}/dti_MD.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_RD.nii.gz \
            $current_iter_b0 \
            ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr1_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr2_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr3_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr4_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr5_warp.nii.gz \
    --mask  ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz \
    --n 3 \
    --out   ${TISSUE_SEGMENTATION_DIR}'/noFA_'


echo 'Run fuzzy 4-class segmentation without FA'
python3 ${SCRIPTS}/fuzzyseg.py \
    --data  ${TISSUE_SEGMENTATION_DIR}/dti_MD.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_RD.nii.gz \
            $current_iter_b0 \
            ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr1_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr2_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr3_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr4_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr5_warp.nii.gz \
    --mask  ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz \
    --n 4 \
    --out   ${TISSUE_SEGMENTATION_DIR}'/noFA_'




echo 'Run fuzzy 2-class segmentation with FA'
python3 ${SCRIPTS}/fuzzyseg.py \
    --data  ${TISSUE_SEGMENTATION_DIR}/dti_MD.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_FA.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_RD.nii.gz \
            $current_iter_b0 \
            ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr1_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr2_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr3_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr4_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr5_warp.nii.gz \
    --mask  ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz \
    --n 2 \
    --out   ${TISSUE_SEGMENTATION_DIR}'/'


echo 'Run fuzzy 3-class segmentation with FA'
python3 ${SCRIPTS}/fuzzyseg.py \
    --data  ${TISSUE_SEGMENTATION_DIR}/dti_MD.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_FA.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_RD.nii.gz \
            $current_iter_b0 \
            ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr1_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr2_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr3_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr4_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr5_warp.nii.gz \
    --mask  ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz \
    --n 3 \
    --out   ${TISSUE_SEGMENTATION_DIR}'/'


echo 'Run fuzzy 4-class segmentation with FA'
python3 ${SCRIPTS}/fuzzyseg.py \
    --data  ${TISSUE_SEGMENTATION_DIR}/dti_MD.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_FA.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/dti_RD.nii.gz \
            $current_iter_b0 \
            ${TISSUE_SEGMENTATION_DIR}/data_norm_mean.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr1_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr2_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr3_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr4_warp.nii.gz \
            ${TISSUE_SEGMENTATION_DIR}/flash_contr5_warp.nii.gz \
    --mask  ${TISSUE_SEGMENTATION_DIR}/mask.nii.gz \
    --n 4 \
    --out   ${TISSUE_SEGMENTATION_DIR}'/'


echo -e "\necho \"Check FLASH mask in JUNAROT space.\"" >> $THISLOG
echo "mrview -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_2class_idx_0.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_2class_idx_1.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_3class_idx_0.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_3class_idx_1.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_3class_idx_2.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_4class_idx_0.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_4class_idx_1.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_4class_idx_2.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/noFA_fuzzy_label_4class_idx_3.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_2class_idx_0.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_2class_idx_1.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_3class_idx_0.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_3class_idx_1.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_3class_idx_2.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_4class_idx_0.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_4class_idx_1.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_4class_idx_2.nii.gz -interpolation 0 -mode 2 -load ${TISSUE_SEGMENTATION_DIR}/fuzzy_label_4class_idx_3.nii.gz -interpolation 0 -mode 2" >> $THISLOG





# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG

echo 'Done'

