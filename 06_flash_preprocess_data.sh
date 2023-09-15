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






# # Show reoriented data alongside with MNI brain
# mrview \
#     -load ${FLASH_DIR_FA25}/data.nii.gz \
#     -interpolation 0  \
#     -mode 2 &

# mrview \
#     -load /data/pt_02101_dMRI/software/fsl6/data/standard/MNI152_T1_1mm_brain.nii.gz \
#     -interpolation 0 \
#     -mode 2 &
#
echo -e "\necho \"Show reoriented data alongside with MNI brain.\"" >> $THISLOG
echo "mrview -load ${FLASH_DIR_FA25}/data.nii.gz -interpolation 0 -mode 2 &" >> $THISLOG
echo "mrview -load /data/pt_02101_dMRI/software/fsl6/data/standard/MNI152_T1_1mm_brain.nii.gz -interpolation 0 -mode 2" >> $THISLOG




# Compare distortions between FLASH and 3DEPI Acqusitions
# fsleyes \
#     ${FLASH_DIR_FA25}/data.nii.gz \
#     ${REORIENT_DIR}/data_reshape.nii.gz &
#
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
echo "mrview -load ${FLASH_DIR_WARP}/data_flash.nii.gz -interpolation 0 -load ${current_iter_flash} -interpolation 0" >> $THISLOG







echo "Creating mask for Ernst Angle FLASH data "
# Get initial mask threshold from average image intensity
MASK_THRESHOLD_FLASH=$(${FSL_LOCAL}/fslstats $current_iter_flash -m)
#
MASKING_DONE=0
while [ $MASKING_DONE == 0 ]; do

    # Generate mask by median filtering and thresholding (FSL maths)
    ${FSL_LOCAL}/fslmaths \
            $current_iter_flash \
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
            -load $current_iter_flash \
            -interpolation 0  \
            -mode 2 \
            -overlay.load ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz \
            -overlay.opacity 0.5 \
            -overlay.interpolation 0 \
            -overlay.colourmap 3 

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
                --his $current_iter_flash \
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



bet2 $current_iter_flash \
     ${FLASH_DIR_WARP}/flash_bet \
     -m \
     -n \
     -f 0.5 \
     -r 60 

# mrview -load ${current_iter_flash} -interpolation 0 -mode 2 -overlay.load ${FLASH_DIR_WARP}/flash_bet_mask.nii.gz -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3




# add threshold mask and BET mask ofr final FLASH mask
fslmaths      ${FLASH_DIR_WARP}/mask_flash_connect_dil.nii.gz \
         -add ${FLASH_DIR_WARP}/flash_bet_mask.nii.gz \
         -bin \
              ${FLASH_DIR_WARP}/mask_flash.nii.gz



rm -f ${FLASH_DIR_WARP}/mask_flash_*.nii.gz
rm -f ${FLASH_DIR_WARP}/flash_bet_mask.nii.gz



echo -e "\necho \"Check FLASH mask.\"" >> $THISLOG
echo "mrview -load ${current_iter_flash} -interpolation 0 -mode 2 -overlay.load ${FLASH_DIR_WARP}/mask_flash.nii.gz -overlay.opacity 0.5 -overlay.interpolation 0 -overlay.colourmap 3" >> $THISLOG







# add END-OF-PROC print to logfile
echo -e "\n# END-OF-PROC" >> $THISLOG
#
echo $0 " Done" 
