#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh

# Init or clear viz log file 
THISLOG=${LOG_DIR}/08.sh
echo "# START-OF-PROC" > $THISLOG


####################################
# Put together the data from various files

# Assemble all DIFF_SCANS from raw nifti folder
SCANPATHS=''
for t in ${DIFF_SCANS[@]}; do
    SCANPATHS+=${UNWRAP_DIR}'/*X'${t}'P1.nii.gz '
done
echo "Loading Data"
${FSL_LOCAL}/fslmerge -t ${DIFF_DATA_DIR}/data.nii.gz \
                         ${SCANPATHS}



# Load bvecs and bvals from Bruker method file
echo "Loading bvecs bvals"
rm -f ${DIFF_DATA_DIR}/data.bv* 
>${DIFF_DATA_DIR}/data.bvec 
>${DIFF_DATA_DIR}/data.bval 

# Loop over raw data folder and concatenate bvecs bvals files 
for i_scan in ${DIFF_SCANS[*]}
do
    python3 ${SCRIPTS}/bvec_bval_from_method.py ${BRUKER_RAW_DIR}/${i_scan}/method ${DIFF_DATA_DIR}/${i_scan}.bvec ${DIFF_DATA_DIR}/${i_scan}.bval
    paste -d ' ' ${DIFF_DATA_DIR}/${i_scan}.bvec >> ${DIFF_DATA_DIR}/data.bvec
    paste -d ' ' ${DIFF_DATA_DIR}/${i_scan}.bval >> ${DIFF_DATA_DIR}/data.bval

    rm -f ${DIFF_DATA_DIR}/${i_scan}.bvec ${DIFF_DATA_DIR}/${i_scan}.bval
done

#
##################



####################################
# Reshape Data to match MNI orientation

echo 'Reshape Data to match MNI orientation'

python3 ${SCRIPTS}/reshape_volume.py \
    --in ${DIFF_DATA_DIR}/data.nii.gz \
    --out ${DIFF_DATA_DIR}/data_reshape.nii.gz \
    --ord ${RESHAPE_ARRAY_ORD} \
    --inv ${RESHAPE_ARRAY_INV} \
    --res ${RES}
    #
# FOV extent mask was already reshaped for EPI space
cp ${NOISEMAP_DIR}/mask_FOV_extent.nii.gz ${DIFF_DATA_DIR}/mask_FOV_extent.nii.gz

python3 ${SCRIPTS}/reorder_bvec.py \
    --in ${DIFF_DATA_DIR}/data.bvec \
    --ord ${RESHAPE_BVECS_ORD} \
    --out ${DIFF_DATA_DIR}/bvec_reshape

# Overwrite non-oriented volumes
mv -f ${DIFF_DATA_DIR}/data_reshape.nii.gz ${DIFF_DATA_DIR}/data.nii.gz
mv -f ${DIFF_DATA_DIR}/bvec_reshape ${DIFF_DATA_DIR}/data.bvec

#
##################


####################################
# Rescale Data to prevent very small numbers

echo 'Rescale Data to prevent very small numbers'

mv -f ${DIFF_DATA_DIR}/data.nii.gz ${DIFF_DATA_DIR}/data_unscaled.nii.gz 
${FSL_LOCAL}/fslmaths ${DIFF_DATA_DIR}/data_unscaled.nii.gz \
    -div ${DATA_RESCALING} \
    ${DIFF_DATA_DIR}/data.nii.gz \
    -odt float 

#
##################








####################################
# Generate mask from b0 values

echo 'Generate mask from b0 values'

# round the bvals file to use dwiextract -b0
python3 ${SCRIPTS}/round_bvals.py \
    --in ${DIFF_DATA_DIR}/data.bval \
    --out ${DIFF_DATA_DIR}/data.bval_round

# Extract b0 volumes
dwiextract \
    -force \
    -bzero \
    -fslgrad ${DIFF_DATA_DIR}/data.bvec ${DIFF_DATA_DIR}/data.bval_round \
    ${DIFF_DATA_DIR}/data.nii.gz \
    ${DIFF_DATA_DIR}/data_b0s.nii.gz

${MRDEGIBBS3D} -force \
    ${DIFF_DATA_DIR}/data_b0s.nii.gz \
    ${DIFF_DATA_DIR}/data_b0s_degibbs.nii.gz \
    -nthreads ${N_CORES}


# MC correct the b0 volumes with flirt
mkdir -p ${DIFF_DATA_DIR}/mc_tmp # tmp folder for flirt
#
${FSL_LOCAL}/fslsplit \
        ${DIFF_DATA_DIR}/data_b0s_degibbs.nii.gz \
        ${DIFF_DATA_DIR}/mc_tmp/
#
NFILES=$(ls diff/data/mc_tmp | wc -l)
mv ${DIFF_DATA_DIR}/mc_tmp/0000.nii.gz ${DIFF_DATA_DIR}/mc_tmp/0000_mc.nii.gz
for n in $(seq -w 0001 $( expr $NFILES - 1 )); do 
    echo $n;
    flirt -in ${DIFF_DATA_DIR}'/mc_tmp/'$n'.nii.gz' \
          -ref ${DIFF_DATA_DIR}/mc_tmp/0000_mc.nii.gz \
          -omat ${DIFF_DATA_DIR}'/mc_tmp/mat_'$n'.txt' \
          -dof 6 \
          -out ${DIFF_DATA_DIR}'/mc_tmp/'$n'_mc.nii.gz'     
done
#
SCANPATHS=''
for n in $(seq -w 0000 $( expr $NFILES - 1 )); do
    SCANPATHS+=${DIFF_DATA_DIR}'/mc_tmp/'$n'_mc.nii.gz '
done
${FSL_LOCAL}/fslmerge -t ${DIFF_DATA_DIR}/data_b0s_mc.nii.gz \
                         ${SCANPATHS}
rm -Rf ${DIFF_DATA_DIR}/mc_tmp/
#
# 
# ${FSL_LOCAL}/mcflirt \
#     -in ${DIFF_DATA_DIR}/data_b0s_degibbs.nii.gz \
#     -out ${DIFF_DATA_DIR}/data_b0s_mcflirt.nii.gz \
#     -refvol 0 -v


echo -e "\necho \"Compare Before and After motion correction.\"" >> $THISLOG
echo "mrview -load ${DIFF_DATA_DIR}/data_b0s_degibbs.nii.gz -interpolation 0 -colourmap 1 -mode 2 -load ${DIFF_DATA_DIR}/data_b0s_mc.nii.gz -interpolation 0 -colourmap 1 -mode 2" >> $THISLOG





# Filter Volumes for mask thresholding
${FSL_LOCAL}/fslmaths \
    ${DIFF_DATA_DIR}/data_b0s_mc.nii.gz \
    -Tmean \
    -kernel 3D \
    -fmedian ${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz

# mrview \
#     -load ${DIFF_DATA_DIR}/data_b0s_mc.nii.gz \
#     -interpolation 0 \
#     -load ${DIFF_DATA_DIR}/data_b0s_degibbs.nii.gz \
#     -interpolation 0 \
#     -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz \
#     -interpolation 0 & 







# test 1) N4+TH_loop
#    "mask_mean_median_N4.nii.gz"
#    "mask_mean_median_vcorr_N4.nii.gz"
#    "mask_mean_N4.nii.gz"
#    "mask_mean_vcorr_N4.nii.gz"

# test 2) N4+BET
#    "mean_median_bet_mask.nii.gz"
#    "mean_median_vcorr_bet_mask.nii.gz"
#    "mean_bet_mask.nii.gz"
#    "mean_vcorr_bet_mask.nii.gz"

# test 3) N4+TH_loop+BET
#    "mask_mean_median_vcorr_N4_bet.nii.gz"
#    "mask_mean_vcorr_N4_bet.nii.gz"
#    "mask_mean_median_N4_bet.nii.gz"
#    "mask_mean_N4_bet.nii.gz"

# test 4) FLASH MASK
# test 5) vcorr+N4+TH_loop 
# test 6) vcorr+N4+TH_loop+BET
# test 7) dwi2mask
# test 8) SM based th?
# test 9) normalized dwi based 





# Multiple rounds of N4 before mask generation
echo 'Runing Repeated N4 on EPI b0 Data'
for i in $(seq 1 $N4_ITER)
do 

        current_iter_epi=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_N4_${i}x.nii.gz
        current_iter_epi_field=${DIFF_DATA_DIR}/field_data_b0s_mc_mean_median_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_epi=${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz
        else
                previous_iter_epi=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 EPI: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_epi \
                -o [$current_iter_epi,$current_iter_epi_field]

done


mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2






MASK_INIT=${FLASH_DIR_WARP}/mask_flash.nii.gz
mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz -interpolation 0 -mode 2 \
       -overlay.load ${MASK_INIT} -overlay.opacity 0.4 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1

python3 ${SCRIPTS}/correct_intensity_1d.py --in ${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz \
                                           --out ${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr.nii.gz \
                                           --mask ${MASK_INIT} \
                                           --ori LR


mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr.nii.gz -interpolation 0 -colourmap 1 -mode 2


echo 'Runing Repeated N4 on EPI b0 Data'
for i in $(seq 1 $N4_ITER)
do 

        current_iter_epi_vcorr=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr_N4_${i}x.nii.gz
        current_iter_epi_vcorr_field=${DIFF_DATA_DIR}/field_data_b0s_mc_mean_median_vcorr_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_epi_vcorr=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr.nii.gz
        else
                previous_iter_epi_vcorr=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 EPI: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_epi_vcorr \
                -o [$current_iter_epi_vcorr,$current_iter_epi_vcorr_field]

done

mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2





${FSL_LOCAL}/fslmaths \
    ${DIFF_DATA_DIR}/data_b0s_mc.nii.gz \
    -Tmean \
    ${DIFF_DATA_DIR}/data_b0s_mc_mean.nii.gz




# Multiple rounds of N4 before mask generation
echo 'Runing Repeated N4 on EPI b0 Data'
for i in $(seq 1 $N4_ITER)
do 

        current_iter_epi2=${DIFF_DATA_DIR}/data_b0s_mc_mean_N4_${i}x.nii.gz
        current_iter_epi2_field=${DIFF_DATA_DIR}/field_data_b0s_mc_mean_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_epi2=${DIFF_DATA_DIR}/data_b0s_mc_mean.nii.gz
        else
                previous_iter_epi2=${DIFF_DATA_DIR}/data_b0s_mc_mean_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 EPI: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_epi2 \
                -o [$current_iter_epi2,$current_iter_epi2_field]

done


mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2






python3 ${SCRIPTS}/correct_intensity_1d.py --in ${DIFF_DATA_DIR}/data_b0s_mc_mean.nii.gz \
                                           --out ${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr.nii.gz \
                                           --mask ${MASK_INIT} \
                                           --ori LR


mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr.nii.gz -interpolation 0 -colourmap 1 -mode 2


echo 'Runing Repeated N4 on EPI b0 Data'
for i in $(seq 1 $N4_ITER)
do 

        current_iter_epi2_vcorr=${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_${i}x.nii.gz
        current_iter_epi2_vcorr_field=${DIFF_DATA_DIR}/field_data_b0s_mc_mean_vcorr_N4_${i}x.nii.gz

        if [ $i == 1 ]
        then 
                previous_iter_epi2_vcorr=${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr.nii.gz
        else
                previous_iter_epi2_vcorr=${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_$( expr $i - 1 )x.nii.gz
        fi

        echo 'N4 EPI: Run '${i}

        N4BiasFieldCorrection -d 3 \
                -i $previous_iter_epi2_vcorr \
                -o [$current_iter_epi2_vcorr,$current_iter_epi2_vcorr_field]

done

mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2





${FSL_LOCAL}/fslmaths \
    ${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_${N4_ITER}x.nii.gz \
    -kernel 3D \
    -fmedian ${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_${N4_ITER}x_median.nii.gz




mrview -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_${N4_ITER}x.nii.gz -interpolation 0 -colourmap 1 -mode 2 \
       -load ${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_${N4_ITER}x_median.nii.gz -interpolation 0 -colourmap 1 -mode 2





echo "Creating mask for mean-median-N4 b0 data "
# Get initial mask threshold from average image intensity
IM_IN=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_N4_${N4_ITER}x.nii.gz
MASK_THRESHOLD_FLASH=$(${FSL_LOCAL}/fslstats ${IM_IN} -m)
#
MASKING_DONE=0
while [ $MASKING_DONE == 0 ]; do

    # Generate mask by median filtering and thresholding (FSL maths)
    ${FSL_LOCAL}/fslmaths \
            ${IM_IN} \
            -thr ${MASK_THRESHOLD_FLASH} \
            -bin \
            -fillh26 ${DIFF_DATA_DIR}/mask_tmp.nii.gz \
            -odt int

    # Extract the largest connected volume in generated mask
    maskfilter \
            -force \
            -largest \
            ${DIFF_DATA_DIR}/mask_tmp.nii.gz connect ${DIFF_DATA_DIR}/mask_tmp_connect.nii.gz

    # dilate flash mask with sphere r=2vox
    fslmaths ${DIFF_DATA_DIR}mask_tmp_connect.nii.gz \
             -kernel sphere 1.0 \
             -dilM \
             -bin \
             ${DIFF_DATA_DIR}/mask_tmp_connect_dil.nii.gz \
             -odt int

    # Check the results
    mrview \
            -load ${IM_IN} \
            -interpolation 0  \
            -mode 2 \
            -overlay.load ${DIFF_DATA_DIR}/mask_tmp_connect_dil.nii.gz \
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
                --his ${IM_IN} \
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
mv ${DIFF_DATA_DIR}/mask_tmp_connect_dil.nii.gz ${DIFF_DATA_DIR}/mask_mean_median_N4.nii.gz







IM_IN=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_N4_${N4_ITER}x.nii.gz
#
bet2 $IM_IN \
     ${DIFF_DATA_DIR}/mean_median_bet \
     -m \
     -n \
     -f 0.7 \
     -r 60 
#
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mean_median_bet_mask.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.intensity 1,1




IM_IN=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr_N4_${N4_ITER}x.nii.gz
#
bet2 $IM_IN \
     ${DIFF_DATA_DIR}/mean_median_vcorr_bet \
     -m \
     -n \
     -f 0.6 \
     -r 60 
#
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mean_median_vcorr_bet_mask.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.intensity 1,1




IM_IN=${DIFF_DATA_DIR}/data_b0s_mc_mean_N4_${N4_ITER}x.nii.gz
#
bet2 $IM_IN \
     ${DIFF_DATA_DIR}/mean_bet \
     -m \
     -n \
     -f 0.5 \
     -r 60 
#
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mean_bet_mask.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.intensity 1,1




IM_IN=${DIFF_DATA_DIR}/data_b0s_mc_mean_vcorr_N4_${N4_ITER}x.nii.gz
#
bet2 $IM_IN \
     ${DIFF_DATA_DIR}/mean_vcorr_bet \
     -m \
     -n \
     -f 0.6 \
     -r 60 
#
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mean_vcorr_bet_mask.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.intensity 1,1




#    "mask_mean_median_N4.nii.gz"
#    "mask_mean_median_vcorr_N4.nii.gz"
#    "mask_mean_N4.nii.gz"
#    "mask_mean_vcorr_N4.nii.gz"

# test 2) N4+BET
#    "mean_median_bet_mask.nii.gz"
#    "mean_median_vcorr_bet_mask.nii.gz"
#    "mean_bet_mask.nii.gz"
#    "mean_vcorr_bet_mask.nii.gz"







fslmaths      ${DIFF_DATA_DIR}/mask_mean_median_vcorr_N4.nii.gz \
         -add ${DIFF_DATA_DIR}/mean_median_vcorr_bet_mask.nii.gz \
         -bin \
              ${DIFF_DATA_DIR}/mask_mean_median_vcorr_N4_bet.nii.gz


fslmaths      ${DIFF_DATA_DIR}/mask_mean_vcorr_N4.nii.gz \
         -add ${DIFF_DATA_DIR}/mean_vcorr_bet_mask.nii.gz \
         -bin \
              ${DIFF_DATA_DIR}/mask_mean_vcorr_N4_bet.nii.gz


fslmaths      ${DIFF_DATA_DIR}/mask_mean_median_N4.nii.gz \
         -add ${DIFF_DATA_DIR}/mean_median_bet_mask.nii.gz \
         -bin \
              ${DIFF_DATA_DIR}/mask_mean_median_N4_bet.nii.gz

fslmaths      ${DIFF_DATA_DIR}/mask_mean_N4.nii.gz \
         -add ${DIFF_DATA_DIR}/mean_bet_mask.nii.gz \
         -bin \
              ${DIFF_DATA_DIR}/mask_mean_N4_bet.nii.gz


IM_IN=${DIFF_DATA_DIR}/data_b0s_mc_mean_median_vcorr_N4_${N4_ITER}x.nii.gz
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mask_mean_median_vcorr_N4_bet.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mask_mean_vcorr_N4_bet.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mask_mean_median_N4_bet.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1
mrview -load ${IM_IN} -interpolation 0 -mode 2 \
       -overlay.load ${DIFF_DATA_DIR}/mask_mean_N4_bet.nii.gz -overlay.opacity 0.25 -overlay.colour 1,0,0 -overlay.interpolation 0 -overlay.threshold_min 0.1














# # Get initial mask threshold from average image intensity
# MASK_THRESHOLD=$(${FSL_LOCAL}/fslstats $current_iter_epi -m)

# MASKING_ANSWER="N"
# MASKING_DONE="N"
# while [ "$MASKING_DONE" == "N" ]; do

#     # Generate mask by thresholing the b0 volumes (FLS maths)
#     ${FSL_LOCAL}/fslmaths \
#         $current_iter_epi \
#         -Tmean \
#         -kernel 3D \
#         -fmedian \
#         -thr ${MASK_THRESHOLD} \
#         -bin \
#         -fillh26 ${DIFF_DATA_DIR}/mask.nii.gz \
#         -odt int

#     # Extract the largest connected volume in generated mask
#     maskfilter \
#         -force \
#         -largest \
#         ${DIFF_DATA_DIR}/mask.nii.gz connect ${DIFF_DATA_DIR}/mask_fit_connect.nii.gz

#     # Dilate the mask 
#     maskfilter \
#         -force \
#         -npass 2 \
#         ${DIFF_DATA_DIR}/mask_fit_connect.nii.gz dilate ${DIFF_DATA_DIR}/mask_fit_connect_dil.nii.gz

#     # Check the results
#     mrview \
#         -load $current_iter_epi \
#         -interpolation 0  \
#         -mode 2 \
#         -overlay.load ${DIFF_DATA_DIR}/mask_fit_connect_dil.nii.gz \
#         -overlay.opacity 0.5 \
#         -overlay.interpolation 0 \
#         -overlay.colourmap 3 

#     echo "Did the script choose the correct threshold for the mask ? [Y/N]"
#     read MASKING_ANSWER

#     if [ $MASKING_ANSWER == "N" ]
#     then
#     # Find THRESHOLD VALUE in a histogram
#     echo 'Adapt MASK_THRESHOLD Variable in SET_VARIABLES.sh to exclude noise peak in histogram'
#     python3 ${SCRIPTS}/quickviz.py \
#         --his $current_iter_epi \
#         --loghis 

#     THRS_OLD=$MASK_THRESHOLD # Saving old threshold in variable for replacement in SET_VARIABLES.txt

#     echo "Previous mask threshold value:"
#     echo $MASK_THRESHOLD

#     echo 'Please provide new mask threshold value:'
#     read MASK_THRESHOLD
#     echo "Repeating procedure with new threshold" ${MASK_THRESHOLD}

#     # Saving mask string in set variables file
#     THRS_STR_OLD="MASK_THRESHOLD=$THRS_OLD"
#     THRS_STR_NEW="MASK_THRESHOLD=$MASK_THRESHOLD"

#     sed -i "s/$THRS_STR_OLD/$THRS_STR_NEW/gi" ./SET_VARIABLES.sh

    
#     elif [ $MASKING_ANSWER == "Y" ]
#     then
#     MASKING_DONE="Y"

#     else 
#     echo "Invalid answer, please repeat"


#     fi 

# done 


# # Get rid of the evidence 
# rm -f ${DIFF_DATA_DIR}/mask.nii.gz ${DIFF_DATA_DIR}/mask_fit_connect.nii.gz 
# mv -f ${DIFF_DATA_DIR}/mask_fit_connect_dil.nii.gz ${DIFF_DATA_DIR}/mask.nii.gz


# # mv -f ${DIFF_DATA_DIR}/mask.nii.gz ${DIFF_DATA_DIR}/mask_auto.nii.gz
# # mrcalc ${DIFF_DATA_DIR}/mask_auto.nii.gz ${DIFF_DATA_DIR}/mask_manual_addition.nii.gz -max ${DIFF_DATA_DIR}/mask.nii.gz



# #
# ##################


# ####################################
# # Plot the dMRI timeseries
# echo "Plot the dMRI timeseries"

# python3 ${SCRIPTS}/plot_timeseries.py \
#     --in ${DIFF_DATA_DIR}/data.nii.gz \
#     --mask ${DIFF_DATA_DIR}/mask.nii.gz \
#     --bvals ${DIFF_DATA_DIR}/data.bval \
#     --out ${DIFF_DATA_DIR}

# #
# ##################



# ####################################
# # Check the bvec orientation

# echo "Check the bvec orientation"

# mkdir -p ${DIFF_DATA_DIR}/test_dti
# ${FSL_LOCAL}/dtifit \
#     -k ${DIFF_DATA_DIR}/data.nii.gz \
#     -m ${DIFF_DATA_DIR}/mask.nii.gz \
#     -r ${DIFF_DATA_DIR}/data.bvec \
#     -b ${DIFF_DATA_DIR}/data.bval \
#     -o ${DIFF_DATA_DIR}/test_dti/dti

# fsleyes ${DIFF_DATA_DIR}/test_dti/dti_MD* ${DIFF_DATA_DIR}/test_dti/dti_FA* ${DIFF_DATA_DIR}/test_dti/dti_V1* 
# rm -rf ${DIFF_DATA_DIR}/test_dti

# #
# ##################


# echo $0 " Done" 