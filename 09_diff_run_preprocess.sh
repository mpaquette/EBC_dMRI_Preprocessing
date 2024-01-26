#!/bin/bash


# EBC pipeline: Process the diffusion data (noise bias, denoising, degibbs, drift, temperature artefact, eddy)
# inputs:
#
# Previous Steps:
# - Setting $DRIFT_CORRECTION       in SET_VARIABLES.sh
# - Setting $HEAT_CORRECTION        in SET_VARIABLES.sh
# - Setting $FLAG_TOPUP_RETRO_RECON in SET_VARIABLES.sh
# - Setting $RETRO_RECON_NUMBER     in SET_VARIABLES.sh
# - Creating a ${CONFIG_DIR}/temp_corr_index.txt file 
#     or using the commented code in HEAT_CORRECTION section
#     using the info from mean intensity plot in 8.sh (which is in $DIFF_SCANS ordering)
#     and the info from SCANDATE.txt
#


echo 'Running dMRI processing'

# Load Local Variables
source ./SET_VARIABLES.sh


# Init or clear viz log file 
THISLOG=${LOG_DIR}/09.sh
echo "# START-OF-PROC" > $THISLOG


####################################
# Noise Nias Correction
echo 'Noise Bias Correction'
#
python3 ${SCRIPTS}/ncchi_bias_correct_unwrap.py \
    --in ${DIFF_DATA_DIR}/data.nii.gz \
    --sig ${NOISEMAP_DIR}/sigmas.nii.gz \
    --N ${NOISEMAP_DIR}/Ns.nii.gz \
    --axes 0,2 \
    --mask ${DIFF_DATA_DIR}/mask_FOV_extent.nii.gz \
    --out ${DIFF_DATA_DIR}/data_debias.nii.gz
#
${FSL_LOCAL}/fslmaths ${DIFF_DATA_DIR}/data.nii.gz \
    -sub ${DIFF_DATA_DIR}/data_debias.nii.gz \
    -abs \
    ${DIFF_DATA_DIR}/data_debias_residual_abs.nii.gz

#
##################

# log After debiasing and abs residual
echo -e "\necho \"Data Debias and abs residual.\"" >> $THISLOG
echo "mrview -load ${DIFF_DATA_DIR}/data_debias.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_debias_residual_abs.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG





####################################
# MP PCA Denoising
echo 'MP PCA Denoising'
#
dwidenoise -f ${DIFF_DATA_DIR}/data_debias.nii.gz \
    ${DIFF_DATA_DIR}/data_debias_denoise.nii.gz \
    -noise ${DIFF_DATA_DIR}/data_noise.nii.gz \
    -nthreads ${N_CORES} \
    -mask ${DIFF_DATA_DIR}/mask.nii.gz \
#
${FSL_LOCAL}/fslmaths ${DIFF_DATA_DIR}/data_debias.nii.gz \
    -sub ${DIFF_DATA_DIR}/data_debias_denoise.nii.gz \
    -mas ${DIFF_DATA_DIR}/mask.nii.gz \
    -abs \
    ${DIFF_DATA_DIR}/data_noise_residual_abs.nii.gz

#
##################

# log Before and After denoising and abs residual
echo -e "\necho \"Data Denoised and abs residual.\"" >> $THISLOG
echo "mrview -load ${DIFF_DATA_DIR}/data_debias.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_debias_denoise.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_noise_residual_abs.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG





####################################
# Unringing
echo 'Gibbs Ringing Correction'

${MRDEGIBBS3D} -force \
    ${DIFF_DATA_DIR}/data_debias_denoise.nii.gz \
    ${DIFF_DATA_DIR}/data_debias_denoise_degibbs.nii.gz \
    -nthreads ${N_CORES}

${FSL_LOCAL}/fslmaths ${DIFF_DATA_DIR}/data_debias_denoise_degibbs.nii.gz \
    -sub ${DIFF_DATA_DIR}/data_debias_denoise.nii.gz \
    ${DIFF_DATA_DIR}/data_degibbs_residual.nii.gz


# log Before and After denoising and abs residual
echo -e "\necho \"Data Degibbs and residual.\"" >> $THISLOG
echo "mrview -load ${DIFF_DATA_DIR}/data_debias_denoise.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_debias_denoise_degibbs.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_degibbs_residual.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG








####################################
# Detrending the tissue heating effect of increased diffusivity
echo 'Signal Detrending'


## prep for DRIFT CORR using real timestamp
ALLMETHODPATH=''
for t in ${DIFF_SCANS[@]}; do
  ALLMETHODPATH+=$BRUKER_RAW_DIR$t'/method '
done
# echo $ALLMETHODPATH

python3 ${SCRIPTS}/get_timestamp.py $ALLMETHODPATH ${DIFF_DATA_DIR}'/dwi_volume_timestamp.txt'



if [[ ${DRIFT_CORRECTION} == "YES" ]]
then
    echo 'Performing Drift Correction';
    echo 'Make sure first_b0 isnt included';
    python3 ${SCRIPTS}/drift_corr_data_timestamp.py \
        --in ${DIFF_DATA_DIR}/data_debias_denoise_degibbs.nii.gz \
        --mask ${DIFF_DATA_DIR}/mask.nii.gz \
        --bval ${DIFF_DATA_DIR}/data.bval \
        --time ${DIFF_DATA_DIR}'/dwi_volume_timestamp.txt' \
        --image ${DIFF_DATA_DIR}'/dwi_drift_corr.png' \
        --out ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr.nii.gz;
    # log Before and After drift corr
    echo -e "\necho \"Data B0 Drift Correction.\"" >> $THISLOG
    echo "mrview -load ${DIFF_DATA_DIR}/data_debias_denoise_degibbs.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_degibbs_residual.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG

else
    echo 'Skiping Drift Correction';
    cp -f ${DIFF_DATA_DIR}/data_debias_denoise_degibbs.nii.gz ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr.nii.gz;
    # Log that we skip this
    echo -e "\necho Skipping B0 Drift Correction" >> $THISLOG
    echo -e "read -p \"Press key to continue...\"" >> $THISLOG
fi


if [[ ${HEAT_CORRECTION} == "YES" ]]
then
    echo 'Performing Heat Correction';
    echo 'Make sure first_b0 isnt included';
    echo 'Make sure other b0s are included';
    # Build index of volume to use for calibration
    # TODO helper script to make simple index
    # acquisition order was: 
    # 1_reheat, 3, middle_b0, 2, 4, 5, 6, final_b0
    # data order is: 
    # middle_b0, 1_reheat, 2, 3, 4, 5, 6, final_b0
    #
    #
    # rm -f ${CONFIG_DIR}/temp_corr_index.txt 
    # >${CONFIG_DIR}/temp_corr_index.txt
    # #
    # echo '1' >> ${CONFIG_DIR}/temp_corr_index.txt; # include middle_b0
    # #
    # for i in {1..10}; do # exclude 1_of_6_reheat 
    #     echo '0' >> ${CONFIG_DIR}/temp_corr_index.txt;
    # done
    # #
    # for i in {1..5}; do # exclude 2_of_6
    #     echo '0' >> ${CONFIG_DIR}/temp_corr_index.txt;
    # done
    # #
    # for i in {1..10}; do # exclude 3_of_6
    #     echo '0' >> ${CONFIG_DIR}/temp_corr_index.txt;
    # done
    # #
    # for i in {1..10}; do # include 4_of_6
    #     echo '1' >> ${CONFIG_DIR}/temp_corr_index.txt;
    # done
    # #
    # for i in {1..10}; do # include 5_of_6
    #     echo '1' >> ${CONFIG_DIR}/temp_corr_index.txt;
    # done
    # #
    # for i in {1..10}; do # include 6_of_6
    #     echo '1' >> ${CONFIG_DIR}/temp_corr_index.txt;
    # done
    # #
    # echo '1' >> ${CONFIG_DIR}/temp_corr_index.txt; # include final_b0
    #
    #
    #
    if test -f ${CONFIG_DIR}/temp_corr_index.txt; then
        echo "Using the following index for temperature correction"
        cat -n ${CONFIG_DIR}/temp_corr_index.txt;
    else
        echo "You need to define the indexes for temperature correction";
        exit 1
    fi

    #
    # erode mask with sphere r=4vox for heat
    fslmaths ${DIFF_DATA_DIR}/mask.nii.gz \
             -kernel sphere 2.0 \
             -ero \
             -bin \
             ${DIFF_DATA_DIR}/mask_ero_for_temp.nii.gz \
             -odt int
    # Compute corrected data
    python3 ${SCRIPTS}/dti_temp_correction.py \
                ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr.nii.gz \
                ${DIFF_DATA_DIR}/data.bval \
                ${DIFF_DATA_DIR}/data.bvec \
                ${CONFIG_DIR}/temp_corr_index.txt \
                ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend.nii.gz \
                ${DIFF_DATA_DIR}/computed_temp_diff_mult.txt \
                ${DIFF_DATA_DIR}/computed_temp_signal_mult.nii.gz \
         --mask ${DIFF_DATA_DIR}/mask_ero_for_temp.nii.gz






    # log Before and After heat corr
    echo -e "\necho \"Data Heat Correction.\"" >> $THISLOG
    echo "cat -n ${CONFIG_DIR}/temp_corr_index.txt" >> $THISLOG
    echo "echo -e \"set title \\\"Log-Signal Temperature Coefs\\\"\\nset term x11\\nplot \\\"${DIFF_DATA_DIR}/computed_temp_diff_mult.txt\\\" with linespoints\\nexit\" | gnuplot -p" >> $THISLOG
    echo "mrview -load ${DIFF_DATA_DIR}/computed_temp_signal_mult.nii.gz -interpolation 0 -mode 2" >> $THISLOG
    echo "mrview -load ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG

else
    echo 'Skiping Heat Correction';
    cp -f ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr.nii.gz ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend.nii.gz;
    ## TODO create a fake voxel wise multiplier image
    # Log that we skip this
    echo -e "\necho Skipping Heat Correction" >> $THISLOG
    echo -e "read -p \"Press key to continue...\"" >> $THISLOG
fi




####################################
# Eddy correction - Eddy will be performed on B4 bias corrected data. The resulting eddy fields will be applied  to the data
# Incorporate linear registration to FLASH Data

echo 'Eddy Correction'

# Generate files required for eddy 
python3 ${SCRIPTS}/make_fake_eddy_files.py \
    --folder ${DIFF_DATA_DIR}/ \
    --Ndir ${DIFF_DATA_DIR}/data.bval_round \
    --TE ${TE} \
    --PE ${PE_DIRECTION}





# Extract all b0 volumes
dwiextract \
    -force \
    -bzero \
    -fslgrad ${DIFF_DATA_DIR}/data.bvec ${DIFF_DATA_DIR}/data.bval_round \
    ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend.nii.gz \
    ${DIFF_DATA_DIR}/b0s_debias_denoise_degibbs_driftcorr_detrend.nii.gz

# take first b0
fslroi ${DIFF_DATA_DIR}/b0s_debias_denoise_degibbs_driftcorr_detrend.nii.gz \
       ${DIFF_DATA_DIR}/first_b0_debias_denoise_degibbs_driftcorr_detrend.nii.gz \
       0 1

# Estimate N4 Bias Correction on first b0
N4BiasFieldCorrection \
    -i ${DIFF_DATA_DIR}/first_b0_debias_denoise_degibbs_driftcorr_detrend.nii.gz \
    -x ${DIFF_DATA_DIR}/mask.nii.gz \
    -o [${DIFF_DATA_N4_DIR}/first_b0_N4.nii.gz,${DIFF_DATA_N4_DIR}/N4_biasfield.nii.gz] \
    -d 3 \
    -v

# apply biasfield to all
# note, this biasfield as a constant factor to it
# since this is only for EDDY, it doesnt matter
# but if using N4 elsewhere, beware to adjust noise estimation
mrcalc ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend.nii.gz \
       ${DIFF_DATA_N4_DIR}/N4_biasfield.nii.gz \
       -div \
       ${DIFF_DATA_N4_DIR}/data_N4.nii.gz

# cleanup N4 stuff
rm -f ${DIFF_DATA_DIR}/b0s_debias_denoise_degibbs_driftcorr_detrend.nii.gz
rm -f ${DIFF_DATA_DIR}/first_b0_debias_denoise_degibbs_driftcorr_detrend.nii.gz
rm -f ${DIFF_DATA_N4_DIR}/first_b0_N4.nii.gz







# Run Eddy on N4 Corrected data
# eddy_openmp \
${EDDY_PATH} \
    --imain=${DIFF_DATA_N4_DIR}/data_N4.nii.gz \
    --mask=${DIFF_DATA_DIR}/mask.nii.gz \
    --index=${DIFF_DATA_DIR}/index \
    --acqp=${DIFF_DATA_DIR}/acqp \
    --bvecs=${DIFF_DATA_DIR}/data.bvec \
    --bvals=${DIFF_DATA_DIR}/data.bval_round \
    --out=${EDDY_DIR}/eddy \
    --dfields=${EDDY_FIELDS_DIR}/eddy \
    --cnr_maps \
    --residuals \
    --interp=spline \
    --data_is_shelled \
    -v






# Move Eddy Fields to respective folder
mv -f ${EDDY_DIR}/*displacement_fields* ${EDDY_FIELDS_DIR}/

# # Check Eddy Correction
# mrview -mode 2 \
#     -load ${EDDY_DIR}/eddy.nii.gz \
#     -interpolation 0 &

# Split original data
echo "Splitting dataset to specified out_folder" 
${FSL_LOCAL}/fslsplit \
    ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend.nii.gz \
    ${SPLIT_DIR} \


# Force Warp Fields Relative and Calculate Jacobian Determinant
echo "Converting Warp Fields to Relative Convention" 
for filename in ${EDDY_FIELDS_DIR}/* ; do
    echo "Converting Warp Field" ${filename##*/}
    ${FSL_LOCAL}/convertwarp \
        -w ${EDDY_FIELDS_DIR}/${filename##*/} \
        -r ${DIFF_DATA_DIR}/data_b0s_mc_mean.nii.gz \
        -o ${EDDY_FIELDS_REL_DIR}/${filename##*/} \
        --relout 
done



echo "Calculate Jacobi Determinants of Displacement Fields" 
for filename in ${EDDY_FIELDS_REL_DIR}/* ; do
    echo "Calculating Jacobi Determinant of Warp Field" ${filename##*/}
    python3 ${SCRIPTS}/calc_jacobian.py \
        --in ${EDDY_FIELDS_REL_DIR}/${filename##*/} \
        --out ${EDDY_FIELDS_JAC_DIR}/${filename##*/}
done





# loop over volume numer (using simple file count)
NUMVOL=$(ls ${EDDY_FIELDS_REL_DIR} | wc -l)

# apply all eddy warps and move to JUNAROT space
TEMPLATE_JUNAROT=${JUNAROT_DIR}/JUNAROT_space_ref.nii.gz
JUNAROT_MAT=${JUNAROT_DIR}/junarot.txt
for VOLID in $(seq ${NUMVOL}); do
    # echo $((VOLID-1)) ${VOLID};
    echo "Applying Eddy Warp to volume ${VOLID} out of ${NUMVOL}";
    DATAID=$(printf "%04d" $((VOLID-1))); # data is numbered {0..VOLID-1} with 4 digits
    FIELDID=$(printf "%03d" ${VOLID}); # fields is numbered {1..VOLID} with 3 digits
    applywarp \
             -i ${SPLIT_DIR}/${DATAID}.nii.gz \
             -r ${TEMPLATE_JUNAROT} \
             -o ${SPLIT_DIR}/${DATAID}_warped_nojac.nii.gz \
             -w ${EDDY_FIELDS_REL_DIR}/eddy.eddy_displacement_fields.${FIELDID}.nii.gz \
             --postmat=${JUNAROT_MAT} \
             --interp=spline \
             --rel \
             --datatype=float
    #
    flirt -in ${EDDY_FIELDS_JAC_DIR}/eddy.eddy_displacement_fields.${FIELDID}.nii.gz \
      -ref ${TEMPLATE_JUNAROT} \
      -init ${JUNAROT_MAT} \
      -out ${EDDY_FIELDS_JAC_DIR}/eddy.eddy_displacement_fields.junarot.${FIELDID}.nii.gz \
      -applyxfm
    #
    fslmaths \
            ${SPLIT_DIR}/${DATAID}_warped_nojac.nii.gz \
            -mul \
            ${EDDY_FIELDS_JAC_DIR}/eddy.eddy_displacement_fields.junarot.${FIELDID}.nii.gz \
            ${SPLIT_WARPED_DIR}/${DATAID}.nii.gz
done



# # Warp the data and apply jacobi determinant
# echo "Apply Warp Fields to Split Volumes" 
# python3 ${SCRIPTS}/warp_data.py \
#     --split_folder ${SPLIT_DIR} \
#     --warp_folder ${EDDY_FIELDS_REL_DIR} \
#     --jac_folder ${EDDY_FIELDS_JAC_DIR} \
#     --out_folder ${SPLIT_WARPED_DIR}


echo "Stitching together Measurements" 
${FSL_LOCAL}/fslmerge \
    -t \
    ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend_eddy.nii.gz \
    ${SPLIT_WARPED_DIR}/*nii.gz

cp ${EDDY_DIR}/*bvecs ${DIFF_DATA_DIR}/data.bvec_eddy


python3 ${SCRIPTS}/rotate_bvecs.py \
        ${DIFF_DATA_DIR}/data.bvec_eddy \
        ${JUNAROT_MAT} \
        ${DIFF_DATA_DIR}/data.bvec_junarot



flirt -in ${DIFF_DATA_DIR}/mask.nii.gz \
      -ref ${TEMPLATE_JUNAROT} \
      -init ${JUNAROT_MAT} \
      -out ${DIFF_DATA_DIR}/mask_junarot.nii.gz \
      -applyxfm \
      -interp nearestneighbour
      # -v



echo -e "\necho \"Check mask in JUNAROT space.\"" >> $THISLOG
echo "mrview -load ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend_eddy.nii.gz -interpolation 0 -mode 2 -overlay.load ${DIFF_DATA_DIR}/mask_junarot.nii.gz -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3" >> $THISLOG




#
##################


####################################
# DTI Fit for Quality Control

echo 'DTI Fit for Quality Control'

${FSL_LOCAL}/dtifit -k ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend_eddy.nii.gz \
                    -m ${DIFF_DATA_DIR}/mask_junarot.nii.gz \
                    -r ${DIFF_DATA_DIR}/data.bvec_junarot \
                    -b ${DIFF_DATA_DIR}/data.bval \
                    -o ${DTI_DIR}/dti \
                    -w -V --save_tensor 

# Create a scaled FA image for improved visualization contrast
# fsleyes ${DTI_DIR}/dti_MD* ${DTI_DIR}/dti_FA* ${DTI_DIR}/dti_V1* &

# Calculate color FA
mv ${DTI_DIR}/dti_FA.nii.gz ${DTI_DIR}/dti_FA_raw.nii.gz
mrcalc ${DTI_DIR}/dti_FA_raw.nii.gz 0 -max 1 -min ${DTI_DIR}/dti_FA.nii.gz
mrcalc ${DTI_DIR}/dti_FA.nii.gz ${DTI_DIR}/dti_V1.nii.gz -mult ${DTI_DIR}/dti_cFA.nii.gz
rm -f ${DTI_DIR}/dti_FA_raw.nii.gz

# Calculate Radial Diffusivity
mv ${DTI_DIR}/dti_L2.nii.gz ${DTI_DIR}/dti_L2_raw.nii.gz
mrcalc ${DTI_DIR}/dti_L2_raw.nii.gz 0 -max 0.003 -min ${DTI_DIR}/dti_L2.nii.gz
mv ${DTI_DIR}/dti_L3.nii.gz ${DTI_DIR}/dti_L3_raw.nii.gz
mrcalc ${DTI_DIR}/dti_L3_raw.nii.gz 0 -max 0.003 -min ${DTI_DIR}/dti_L3.nii.gz
mrcalc ${DTI_DIR}/dti_L2.nii.gz ${DTI_DIR}/dti_L3.nii.gz -add 0.5 -mult ${DTI_DIR}/dti_RD.nii.gz
rm -f ${DTI_DIR}/dti_L2_raw.nii.gz
rm -f ${DTI_DIR}/dti_L3_raw.nii.gz

mv ${DTI_DIR}/dti_MD.nii.gz ${DTI_DIR}/dti_MD_raw.nii.gz
mrcalc ${DTI_DIR}/dti_MD_raw.nii.gz 0 -max 0.003 -min ${DTI_DIR}/dti_MD.nii.gz
rm -f ${DTI_DIR}/dti_MD_raw.nii.gz


echo -e "\necho \"Check Curated DTI fit (MD, RD, FA, color-FA).\"" >> $THISLOG
echo "mrview -load ${DTI_DIR}/dti_MD.nii.gz -interpolation 0 -mode 2 -load ${DTI_DIR}/dti_RD.nii.gz -interpolation 0 -mode 2 -load ${DTI_DIR}/dti_FA.nii.gz -interpolation 0 -mode 2 -load ${DTI_DIR}/dti_cFA.nii.gz -interpolation 0 -mode 2" >> $THISLOG





#
##################


####################################
# Copy corrected data to release folder
${FSL_LOCAL}/fslmaths ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend_eddy.nii.gz ${DIFF_DATA_RELEASE_DIR}/data.nii.gz -odt float
# cp ${DIFF_DATA_DIR}/mask.nii.gz ${DIFF_DATA_RELEASE_DIR}/mask.nii.gz
cp ${DIFF_DATA_DIR}/mask_junarot.nii.gz ${DIFF_DATA_RELEASE_DIR}/mask.nii.gz
cp ${DIFF_DATA_DIR}/data.bval ${DIFF_DATA_RELEASE_DIR}/data.bval
# cp ${EDDY_DIR}/*bvecs ${DIFF_DATA_RELEASE_DIR}/data.bvec
cp ${DIFF_DATA_DIR}/data.bvec_junarot ${DIFF_DATA_RELEASE_DIR}/data.bvec


####################################
# Normalize Data with b0

echo 'Normalize Data with b0'

flirt -in ${NOISEMAP_DIR}/sigmas.nii.gz \
      -ref ${TEMPLATE_JUNAROT} \
      -init ${JUNAROT_MAT} \
      -out ${NOISEMAP_DIR}/sigmas_junarot.nii.gz \
      -applyxfm \
      -interp trilinear
      # -v

flirt -in ${NOISEMAP_DIR}/Ns.nii.gz \
      -ref ${TEMPLATE_JUNAROT} \
      -init ${JUNAROT_MAT} \
      -out ${NOISEMAP_DIR}/Ns_junarot.nii.gz \
      -applyxfm \
      -interp trilinear
      # -v


python3 ${SCRIPTS}/normalize_data.py \
    --in ${DIFF_DATA_DIR}/data_debias_denoise_degibbs_driftcorr_detrend_eddy.nii.gz \
    --in_sigma ${NOISEMAP_DIR}/sigmas_junarot.nii.gz \
    --in_N ${NOISEMAP_DIR}/Ns_junarot.nii.gz \
    --mask ${DIFF_DATA_DIR}/mask_junarot.nii.gz \
    --bval ${DIFF_DATA_DIR}/data.bval \
    --bvec ${DIFF_DATA_DIR}/data.bvec_junarot \
    --out_folder ${DIFF_DATA_NORM_RELEASE_DIR}

cp ${DIFF_DATA_NORM_RELEASE_DIR}/sigma_norm.nii.gz ${NOISEMAP_DIR}/sigma_norm.nii.gz


if [[ ${HEAT_CORRECTION} == "YES" ]]
then

    flirt -in ${DIFF_DATA_DIR}/computed_temp_signal_mult.nii.gz \
          -ref ${TEMPLATE_JUNAROT} \
          -init ${JUNAROT_MAT} \
          -out ${DIFF_DATA_DIR}/computed_temp_signal_mult_junarot.nii.gz \
          -applyxfm \
          -interp trilinear
          # -v

    mrcalc ${DIFF_DATA_NORM_RELEASE_DIR}/sigma_norm.nii.gz \
           ${DIFF_DATA_DIR}/computed_temp_signal_mult_junarot.nii.gz \
           -mult \
           ${DIFF_DATA_NORM_RELEASE_DIR}/sigma_norm_heatcorr.nii.gz

    cp ${DIFF_DATA_NORM_RELEASE_DIR}/sigma_norm_heatcorr.nii.gz ${NOISEMAP_DIR}/sigma_norm_heatcorr.nii.gz

    DATANORMDIM=($(mrinfo ${DIFF_DATA_NORM_RELEASE_DIR}/data_norm.nii.gz -size))
    # for the NORM release sigmas 4D maps, we crop the last b0
    fslroi ${DIFF_DATA_NORM_RELEASE_DIR}/sigma_norm_heatcorr.nii.gz \
           ${DIFF_DATA_NORM_RELEASE_DIR}/sigma_norm_4d.nii.gz \
           0 "${DATANORMDIM[3]}"
    rm -f ${DIFF_DATA_NORM_RELEASE_DIR}/sigma_norm_heatcorr.nii.gz

fi





echo -e "\necho \"Check Sigma with voxelwise heat correction.\"" >> $THISLOG
echo "mrview -load ${NOISEMAP_DIR}/sigma_norm_heatcorr.nii.gz -interpolation 0 -mode 2" >> $THISLOG




#
##################

# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG


echo $0 " Done" 
