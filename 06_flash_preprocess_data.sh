#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/06.sh
echo "# START-OF-PROC" > $THISLOG

# Copy nii files to topup directory
echo "Copy nii files to respective directories"

#FA 5 deg
cp ${UNWRAP_DIR}/*X${FLASH_FA_05}P1.nii.gz ${FLASH_DIR_FA05}/data.nii.gz

#FA 12.5 deg
cp ${UNWRAP_DIR}/*X${FLASH_FA_12p5}P1.nii.gz ${FLASH_DIR_FA12p5}/data.nii.gz

#FA 25 deg
cp ${UNWRAP_DIR}/*X${FLASH_FA_25}P1.nii.gz ${FLASH_DIR_FA25}/data.nii.gz

#FA 50 deg
cp ${UNWRAP_DIR}/*X${FLASH_FA_50}P1.nii.gz ${FLASH_DIR_FA50}/data.nii.gz

#FA 80 deg
cp ${UNWRAP_DIR}/*X${FLASH_FA_80}P1.nii.gz ${FLASH_DIR_FA80}/data.nii.gz

#Highres
cp ${UNWRAP_DIR}/*X${FLASH_HIGHRES}P1.nii.gz ${FLASH_DIR_HIGHRES}/data.nii.gz

#Ultra Highres
cp ${UNWRAP_DIR}/*X${FLASH_ULTRA_HIGHRES}P1.nii.gz ${FLASH_DIR_ULTRA_HIGHRES}/data.nii.gz


# Reshape image matrix to resemble MNI space
echo "Reshape image matrix to resemble MNI space"
python3 ${SCRIPTS}/reshape_volume.py \
    --in ${FLASH_DIR_FA05}/data.nii.gz \
    --out ${FLASH_DIR_FA05}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}

python3 ${SCRIPTS}/reshape_volume.py \
    --in ${FLASH_DIR_FA12p5}/data.nii.gz \
    --out ${FLASH_DIR_FA12p5}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}

python3 ${SCRIPTS}/reshape_volume.py \
    --in ${FLASH_DIR_FA25}/data.nii.gz \
    --out ${FLASH_DIR_FA25}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}

python3 ${SCRIPTS}/reshape_volume.py \
    --in ${FLASH_DIR_FA50}/data.nii.gz \
    --out ${FLASH_DIR_FA50}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}

python3 ${SCRIPTS}/reshape_volume.py \
    --in ${FLASH_DIR_FA80}/data.nii.gz \
    --out ${FLASH_DIR_FA80}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}
#
python3 ${SCRIPTS}/reshape_volume.py \
    --in ${UNWRAP_DIR}/mask_FOV_extent_flash.nii.gz \
    --out ${FLASH_DIR_FA05}/mask_FOV_extent.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}
#
cp ${FLASH_DIR_FA05}/mask_FOV_extent.nii.gz ${FLASH_DIR_FA12p5}/mask_FOV_extent.nii.gz
cp ${FLASH_DIR_FA05}/mask_FOV_extent.nii.gz ${FLASH_DIR_FA25}/mask_FOV_extent.nii.gz
cp ${FLASH_DIR_FA05}/mask_FOV_extent.nii.gz ${FLASH_DIR_FA50}/mask_FOV_extent.nii.gz
cp ${FLASH_DIR_FA05}/mask_FOV_extent.nii.gz ${FLASH_DIR_FA80}/mask_FOV_extent.nii.gz


python3 ${SCRIPTS}/reshape_volume.py \
    --in ${FLASH_DIR_HIGHRES}/data.nii.gz \
    --out ${FLASH_DIR_HIGHRES}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${HIGHRES}
#
python3 ${SCRIPTS}/reshape_volume.py \
    --in ${UNWRAP_DIR}/mask_FOV_extent_HR.nii.gz \
    --out ${FLASH_DIR_HIGHRES}/mask_FOV_extent.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${HIGHRES}

python3 ${SCRIPTS}/reshape_volume.py \
    --in ${FLASH_DIR_ULTRA_HIGHRES}/data.nii.gz \
    --out ${FLASH_DIR_ULTRA_HIGHRES}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${ULTRA_HIGHRES}
#
python3 ${SCRIPTS}/reshape_volume.py \
    --in ${UNWRAP_DIR}/mask_FOV_extent_UHR.nii.gz \
    --out ${FLASH_DIR_ULTRA_HIGHRES}/mask_FOV_extent.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${ULTRA_HIGHRES}



mv -f ${FLASH_DIR_FA05}/data_reshape.nii.gz ${FLASH_DIR_FA05}/data.nii.gz
mv -f ${FLASH_DIR_FA12p5}/data_reshape.nii.gz ${FLASH_DIR_FA12p5}/data.nii.gz
mv -f ${FLASH_DIR_FA25}/data_reshape.nii.gz ${FLASH_DIR_FA25}/data.nii.gz
mv -f ${FLASH_DIR_FA50}/data_reshape.nii.gz ${FLASH_DIR_FA50}/data.nii.gz
mv -f ${FLASH_DIR_FA80}/data_reshape.nii.gz ${FLASH_DIR_FA80}/data.nii.gz
mv -f ${FLASH_DIR_HIGHRES}/data_reshape.nii.gz ${FLASH_DIR_HIGHRES}/data.nii.gz
mv -f ${FLASH_DIR_ULTRA_HIGHRES}/data_reshape.nii.gz ${FLASH_DIR_ULTRA_HIGHRES}/data.nii.gz







echo -e "\necho \"Show reoriented data alongside with MNI brain.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA25}/data.nii.gz -interpolation 0 -mode 2 &" >> $THISLOG
echo "mrview -load /data/pt_02101_dMRI/software/fsl6/data/standard/MNI152_T1_1mm_brain.nii.gz -interpolation 0 -mode 2" >> $THISLOG





echo -e "\necho \"Compare distortions between FLASH and 3DEPI Acqusitions.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA25}/data.nii.gz -interpolation 0 -mode 2 -load ${REORIENT_DIR}/data_reshape.nii.gz -interpolation 0 -mode 2" >> $THISLOG





${MRDEGIBBS3D} -force \
    ${FLASH_DIR_FA05}/data.nii.gz \
    ${FLASH_DIR_FA05}/data_degibbs.nii.gz \
    -nthreads ${N_CORES}
${MRDEGIBBS3D} -force \
    ${FLASH_DIR_FA12p5}/data.nii.gz \
    ${FLASH_DIR_FA12p5}/data_degibbs.nii.gz \
    -nthreads ${N_CORES}
${MRDEGIBBS3D} -force \
    ${FLASH_DIR_FA25}/data.nii.gz \
    ${FLASH_DIR_FA25}/data_degibbs.nii.gz \
    -nthreads ${N_CORES} 
${MRDEGIBBS3D} -force \
    ${FLASH_DIR_FA50}/data.nii.gz \
    ${FLASH_DIR_FA50}/data_degibbs.nii.gz \
    -nthreads ${N_CORES} 
${MRDEGIBBS3D} -force \
    ${FLASH_DIR_FA80}/data.nii.gz \
    ${FLASH_DIR_FA80}/data_degibbs.nii.gz \
    -nthreads ${N_CORES}
${MRDEGIBBS3D} -force \
    ${FLASH_DIR_HIGHRES}/data.nii.gz \
    ${FLASH_DIR_HIGHRES}/data_degibbs.nii.gz \
    -nthreads ${N_CORES}
${MRDEGIBBS3D} -force \
    ${FLASH_DIR_ULTRA_HIGHRES}/data.nii.gz \
    ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs.nii.gz \
    -nthreads ${N_CORES}


# clip zeros
mrcalc ${FLASH_DIR_FA05}/data_degibbs.nii.gz 0 -max ${FLASH_DIR_FA05}/data_degibbs_tmp.nii.gz
mrcalc ${FLASH_DIR_FA12p5}/data_degibbs.nii.gz 0 -max ${FLASH_DIR_FA12p5}/data_degibbs_tmp.nii.gz
mrcalc ${FLASH_DIR_FA25}/data_degibbs.nii.gz 0 -max ${FLASH_DIR_FA25}/data_degibbs_tmp.nii.gz
mrcalc ${FLASH_DIR_FA50}/data_degibbs.nii.gz 0 -max ${FLASH_DIR_FA50}/data_degibbs_tmp.nii.gz
mrcalc ${FLASH_DIR_FA80}/data_degibbs.nii.gz 0 -max ${FLASH_DIR_FA80}/data_degibbs_tmp.nii.gz
mrcalc ${FLASH_DIR_HIGHRES}/data_degibbs.nii.gz 0 -max ${FLASH_DIR_HIGHRES}/data_degibbs_tmp.nii.gz
mrcalc ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs.nii.gz 0 -max ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_tmp.nii.gz

mv -f ${FLASH_DIR_FA05}/data_degibbs_tmp.nii.gz ${FLASH_DIR_FA05}/data_degibbs.nii.gz
mv -f ${FLASH_DIR_FA12p5}/data_degibbs_tmp.nii.gz ${FLASH_DIR_FA12p5}/data_degibbs.nii.gz
mv -f ${FLASH_DIR_FA25}/data_degibbs_tmp.nii.gz ${FLASH_DIR_FA25}/data_degibbs.nii.gz
mv -f ${FLASH_DIR_FA50}/data_degibbs_tmp.nii.gz ${FLASH_DIR_FA50}/data_degibbs.nii.gz
mv -f ${FLASH_DIR_FA80}/data_degibbs_tmp.nii.gz ${FLASH_DIR_FA80}/data_degibbs.nii.gz
mv -f ${FLASH_DIR_HIGHRES}/data_degibbs_tmp.nii.gz ${FLASH_DIR_HIGHRES}/data_degibbs.nii.gz
mv -f ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs_tmp.nii.gz ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs.nii.gz






echo -e "\necho \"Check Before and After degibbs for FLASH.\"" >> $THISLOG
echo -e "echo \"5 deg.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA05}/data.nii.gz -interpolation 0 -load ${FLASH_DIR_FA05}/data_degibbs.nii.gz -interpolation 0" >> $THISLOG
echo -e "echo \"12.5 deg.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA12p5}/data.nii.gz -interpolation 0 -load ${FLASH_DIR_FA12p5}/data_degibbs.nii.gz -interpolation 0" >> $THISLOG
echo -e "echo \"25 deg.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA25}/data.nii.gz -interpolation 0 -load ${FLASH_DIR_FA25}/data_degibbs.nii.gz -interpolation 0" >> $THISLOG
echo -e "echo \"50 deg.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA50}/data.nii.gz -interpolation 0 -load ${FLASH_DIR_FA50}/data_degibbs.nii.gz -interpolation 0" >> $THISLOG
echo -e "echo \"80 deg.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA80}/data.nii.gz -interpolation 0 -load ${FLASH_DIR_FA80}/data_degibbs.nii.gz -interpolation 0" >> $THISLOG
echo -e "echo \"HIGHRES.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_HIGHRES}/data.nii.gz -interpolation 0 -load ${FLASH_DIR_HIGHRES}/data_degibbs.nii.gz -interpolation 0" >> $THISLOG
echo -e "echo \"ULTRAHIGHRES.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_ULTRA_HIGHRES}/data.nii.gz -interpolation 0 -load ${FLASH_DIR_ULTRA_HIGHRES}/data_degibbs.nii.gz -interpolation 0" >> $THISLOG





# Create mask for FLASH
cp ${FLASH_DIR_FA05}/data_degibbs.nii.gz ${FLASH_DIR_WARP}/data_flash.nii.gz

echo 'Runing N4 on FLASH Data'
for i in $(seq 1 $N4_ITER);
do 

        current_iter_flash=${FLASH_DIR_WARP}/data_flash_N4_${i}x.nii.gz
        current_iter_flash_field=${FLASH_DIR_WARP}/field_flash_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_flash=${FLASH_DIR_WARP}/data_flash.nii.gz
        else
                previous_iter_flash=${FLASH_DIR_WARP}/data_flash_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 FLASH: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_flash \
                -o [$current_iter_flash,$current_iter_flash_field]


done


echo -e "\necho \"Check FLASH vs FLASH N4 ${N4_ITER}x.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_flash.nii.gz -interpolation 0 -load ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz -interpolation 0" >> $THISLOG







echo "Creating mask for Ernst Angle FLASH data "
# Get initial mask threshold from average image intensity
MASK_THRESHOLD_FLASH=$(${FSL_LOCAL}/fslstats ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz -m)
#
MASKING_DONE=0
while [ $MASKING_DONE == 0 ]; do

    # Generate mask by median filtering and thresholding (FSL maths)
    ${FSL_LOCAL}/fslmaths \
            ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz \
            -kernel 3D \
            -fmedian \
            -thr ${MASK_THRESHOLD_FLASH} \
            -bin \
            -fillh26 ${FLASH_DIR_WARP}/mask_flash.nii.gz \
            -odt int

    # Extract the largest connected volume in generated mask
    maskfilter \
            -force \
            -largest \
            ${FLASH_DIR_WARP}/mask_flash.nii.gz connect ${FLASH_DIR_WARP}/mask_flash_connect.nii.gz

    # dilate flash mask with sphere r=2vox
    fslmaths ${FLASH_DIR_WARP}/mask_flash_connect.nii.gz \
             -kernel sphere 1.0 \
             -dilM \
             -bin \
             ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz \
             -odt int

    # Check the results
    mrview \
            -load ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz \
            -interpolation 0  \
            -mode 2 \
            -overlay.load ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz \
            -overlay.opacity 0.5 \
            -overlay.colourmap 3 \
            -overlay.interpolation 0

    # Prompt user whether or not its good
    MASKING_ANSWER_ACCEPTED=0
    while [ $MASKING_ANSWER_ACCEPTED == 0 ]; do
        # read GRABGARBAGE
        echo "Did the script choose the correct threshold for the mask? [y/n]"
        read MASKING_ANSWER
        if [ $MASKING_ANSWER == 'y' ] || [ $MASKING_ANSWER == 'Y' ]; then
            MASKING_ANSWER_ACCEPTED=1;
            MASKING_DONE=1;
        elif [ $MASKING_ANSWER == 'n' ] || [ $MASKING_ANSWER == 'N' ]; then
            MASKING_ANSWER_ACCEPTED=1;
            MASKING_DONE=0;
        else # wrong prompt reply
            echo "Invalid answer, please repeat";
            MASKING_ANSWER_ACCEPTED=0;
        fi
    done

    if [ $MASKING_DONE == 0 ]; then
        # Prompt user for new threshold
        echo "Previous threshold was ${MASK_THRESHOLD_FLASH}"
        # Find THRESHOLD VALUE in a histogram
        echo 'Adapt MASK_THRESHOLD Variable in SET_VARIABLES.sh to exclude noise peak in histogram'
        python3 ${SCRIPTS}/quickviz.py \
                --his ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz \
                --loghis \
                --hisvert ${MASK_THRESHOLD_FLASH}

        THRS_OLD=$MASK_THRESHOLD_FLASH # Saving old threshold in variable for replacement in SET_VARIABLES.txt

        TH_ANSWER_ACCEPTED=0
        while [ $TH_ANSWER_ACCEPTED == 0 ]; do
            # read GRABGARBAGE
            echo 'Please provide new mask threshold value:'
            read MASK_THRESHOLD_FLASH
            if [[ "$MASK_THRESHOLD_FLASH" =~ ^[0-9]+(\.[0-9]+)?$ ]]
            then
                TH_ANSWER_ACCEPTED=1;
            else
                echo "Invalid answer, please repeat";
                TH_ANSWER_ACCEPTED=0;
            fi
        done
        echo "Repeating procedure with new threshold" ${MASK_THRESHOLD_FLASH}
        # Saving mask string in set variables file
        THRS_STR_OLD="MASK_THRESHOLD_FLASH=$THRS_OLD"
        THRS_STR_NEW="MASK_THRESHOLD_FLASH=$MASK_THRESHOLD_FLASH"
    fi

done








bet2 ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz \
     ${FLASH_DIR_WARP}/flash_bet \
     -m \
     -n \
     -f 0.5 \
     -r 60 




# add threshold mask and BET mask for final FLASH mask
fslmaths      ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz \
         -add ${FLASH_DIR_WARP}/flash_bet_mask.nii.gz \
         -bin \
              ${FLASH_DIR_WARP}/mask_flash_connect_dil_plus_bet.nii.gz

maskfilter \
        -force \
        -largest \
        ${FLASH_DIR_WARP}/mask_flash_connect_dil_plus_bet.nii.gz connect ${FLASH_DIR_WARP}/mask_flash.nii.gz


rm -f ${FLASH_DIR_WARP}/mask_flash_*.nii.gz
rm -f ${FLASH_DIR_WARP}/flash_bet_mask.nii.gz



echo -e "\necho \"Check FLASH mask.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_WARP}/data_flash_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2 -overlay.load ${FLASH_DIR_WARP}/mask_flash.nii.gz -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3" >> $THISLOG







echo "Prepping for affine registration to Juna"
TEMPLATE=${JUNA_T1_TEMPLATE}
DATA=${FLASH_DIR_FA80}/data_degibbs.nii.gz
MASK=${FLASH_DIR_WARP}/mask_flash.nii.gz
WORKDIR=${JUNAROT_DIR}



# temp names
DATA_N4=${WORKDIR}/data_N4.nii.gz
PAD=${JUNA_PAD}
TEMPLATE_PAD=${WORKDIR}/juna_pad.nii.gz
TEMPLATE_NEW_AFFINE=${WORKDIR}/juna_new_affine.nii.gz
TEMPLATE_NEW_AFFINE_TRANS=${WORKDIR}/juna_new_affine_trans.nii.gz
FLIRT_MAT_DOF6=${WORKDIR}/dof6.txt
FLIRT_MAT_DOF9=${WORKDIR}/dof9.txt
FLIRT_MAT_ROT=${WORKDIR}/rot.txt
DATA_WARPED=${WORKDIR}/data_rotated.nii.gz
FLIRT_MAT_ROT_FINAL=${WORKDIR}/junarot.txt

# process data
echo "N4_correct ${DATA}"
N4BiasFieldCorrection -d 3 \
        -i $DATA \
        -x $MASK \
        -o $DATA_N4


mrgrid ${TEMPLATE} \
       pad -uniform ${PAD} \
       ${TEMPLATE_PAD}

# create temporary template with the data's affine
QFORM_PADDED_DATA=$(fslorient -getsform ${DATA})
cp ${TEMPLATE_PAD} ${TEMPLATE_NEW_AFFINE}
fslorient -setsform $QFORM_PADDED_DATA ${TEMPLATE_NEW_AFFINE}
fslorient -copysform2qform ${TEMPLATE_NEW_AFFINE}

# translate template by match center-of-mass
echo "Align template"
python3 ${SCRIPTS}/translate_COM.py \
        --fixed $DATA_N4 \
        --moving ${TEMPLATE_NEW_AFFINE} \
        --output ${TEMPLATE_NEW_AFFINE_TRANS}


echo -e "\necho \"Check Template vs Data before juna rotation.\"" >> $THISLOG
echo "mrview -load ${DATA_N4} -interpolation 0 -mode 2 -load ${TEMPLATE_NEW_AFFINE_TRANS} -interpolation 0 -mode 2" >> $THISLOG






# rigid registration to template
echo "flirt rigid template"
flirt -in $DATA_N4 \
      -ref ${TEMPLATE_NEW_AFFINE_TRANS} \
      -omat $FLIRT_MAT_DOF6 \
      -dof 6 \
      -v

# rigid + scaling registration to template
echo "flirt dof=9 template"
flirt -in $DATA_N4 \
      -ref ${TEMPLATE_NEW_AFFINE_TRANS} \
      -omat $FLIRT_MAT_DOF9 \
      -dof 9 \
      -v

# combine rotation from dof=9 without scaling and translation from dof=6
echo "Creating inplace rotation ${FLIRT_MAT_ROT}"
python3 ${SCRIPTS}/build_inplace_rot_mat.py \
        --input9 $FLIRT_MAT_DOF9 \
        --input6 $FLIRT_MAT_DOF6 \
        --output $FLIRT_MAT_ROT

# warp data to check
flirt -in $DATA_N4 \
      -ref ${TEMPLATE_NEW_AFFINE_TRANS} \
      -init $FLIRT_MAT_ROT \
      -out $DATA_WARPED \
      -applyxfm \
      # -v


echo -e "\necho \"Check Template vs Data after juna rotation.\"" >> $THISLOG
echo "mrview -load ${DATA_WARPED} -interpolation 0 -mode 2 -load ${TEMPLATE_NEW_AFFINE_TRANS} -interpolation 0 -mode 2" >> $THISLOG



# Dilate flashmask
fslmaths ${FLASH_DIR_WARP}/mask_flash.nii.gz \
         -kernel sphere 2.0 \
         -dilM \
         ${WORKDIR}/mask_flash_dil_2mm.nii.gz \
         -odt float

# mrview ${FLASH_DIR_WARP}/mask_flash.nii.gz ${WORKDIR}/mask_flash_dil_2mm.nii.gz


# Warp dilated flashmask to JUNAROT space
flirt -in ${WORKDIR}/mask_flash_dil_2mm.nii.gz \
      -ref ${TEMPLATE_NEW_AFFINE_TRANS} \
      -init $FLIRT_MAT_ROT \
      -out ${WORKDIR}/mask_flash_dil_2mm_JUNAROT.nii.gz \
      -applyxfm \
      -interp nearestneighbour
      # -v


echo -e "\necho \"Check mask in JUNAROT space for cropping.\"" >> $THISLOG
echo "mrview -load ${DATA_WARPED} -interpolation 0 -mode 2 -overlay.load ${WORKDIR}/mask_flash_dil_2mm_JUNAROT.nii.gz -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3" >> $THISLOG






# Crop mask to obtain final JUNAROT space
scil_crop_volume.py ${WORKDIR}/mask_flash_dil_2mm_JUNAROT.nii.gz \
                    ${WORKDIR}/JUNAROT_space_ref.nii.gz \
                    --output_bbox ${WORKDIR}/junarot_final_crop.pkl






# # note: the y and z value for mrgrid are the low bb
# # for x its img.shape[0] - max bb
# mrgrid ${WORKDIR}/mask_flash_dil_2mm_JUNAROT.nii.gz \
#        crop -axis 0 62,64 \
#             -axis 1 35,45 \
#             -axis 2  2,29 \
#        ${WORKDIR}/mask_flash_dil_2mm_JUNAROT_crop_test.nii.gz

python3 ${SCRIPTS}/offset_transform_with_bbox.py \
        --mat $FLIRT_MAT_ROT \
        --ref ${TEMPLATE_NEW_AFFINE_TRANS} \
        --bbox ${WORKDIR}/junarot_final_crop.pkl \
        --output $FLIRT_MAT_ROT_FINAL




# echo -e "\necho \"Check Rigid to Juna.\"" >> $THISLOG
# echo "mrview -load ${JUNA_DIR}/juna_template_pad.nii.gz -interpolation 0 -mode 2 -load ${JUNA_DIR}/flash_to_juna_dof_approx.nii.gz -interpolation 0 -mode 2" >> $THISLOG







# Run repeated N4 over flash for later registration
echo "Running multiple N4 over FLASH data"
for TEMP_FOLDER in ${FLASH_DIR_FA05} ${FLASH_DIR_FA12p5} ${FLASH_DIR_FA25} ${FLASH_DIR_FA50} ${FLASH_DIR_FA80}; do
    echo "Working on ${TEMP_FOLDER}"
    cp ${TEMP_FOLDER}/data_degibbs.nii.gz ${TEMP_FOLDER}/data_degibbs_N4_0x.nii.gz
    for i in $(seq 1 $N4_ITER)
    do 
        echo "N4BiasFieldCorrection ${i} out of ${N4_ITER}"
        previous_iter_flash=${TEMP_FOLDER}/data_degibbs_N4_$( expr $i - 1 )x.nii.gz
        current_iter_flash=${TEMP_FOLDER}/data_degibbs_N4_${i}x.nii.gz
        #
        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_flash \
                -x ${FLASH_DIR_WARP}/mask_flash.nii.gz \
                -o $current_iter_flash
    done
    rm -f ${TEMP_FOLDER}/data_degibbs_N4_0x.nii.gz
done



echo -e "\necho \"Check FLASH FA05 N4 0x vs ${N4_ITER}x.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA05}/data_degibbs.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA05}/data_degibbs_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA12p5 N4 0x vs ${N4_ITER}x.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA12p5}/data_degibbs.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA12p5}/data_degibbs_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA25 N4 0x vs ${N4_ITER}x.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA25}/data_degibbs.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA25}/data_degibbs_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA50 N4 0x vs ${N4_ITER}x.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA50}/data_degibbs.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA50}/data_degibbs_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2" >> $THISLOG
echo -e "echo \"Check FLASH FA80 N4 0x vs ${N4_ITER}x.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA80}/data_degibbs.nii.gz -interpolation 0 -mode 2 -load ${FLASH_DIR_FA80}/data_degibbs_N4_${N4_ITER}x.nii.gz -interpolation 0 -mode 2" >> $THISLOG





# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG
#
echo $0 " Done" 