#!/bin/bash

# Load Local Variables
source ./SET_VARIABLES.sh


# make LSD processing folder
echo "Setting up files for LSD processing"
LSD_DIR=${DIFF_DIR}'/lsd_reprocess/'
mkdir ${LSD_DIR}

# obviously this need a compact version liviing in scripts
python /data/pt_02101_dMRI/data/001_C_W_EMMA/preprocessed/20210127_151556_001_C_W_EMMA_TAI_E_1_1_rr/scripts/round_bvals.py --in ${DIFF_DATA_RELEASE_DIR}'/data.bval' --out ${LSD_DIR}'/rounded.bval'
python /data/hu_paquette/tools/scilpy/scripts/scil_flip_gradients.py ${DIFF_DATA_RELEASE_DIR}'/data.bvec' ${LSD_DIR}'/flipX.bvec' x --fsl




# RATIOS is a vriable,
# why isnt SHMAX, REL_TH and ANGSEP variable too


# write LSD config file
echo "# Path to preprocessed DWI data" > ${LSD_DIR}'/config.txt'
echo "DWI_PATH="${DIFF_DATA_RELEASE_DIR}'/data.nii.gz' >> ${LSD_DIR}'/config.txt'
echo "# Path to b-values file" >> ${LSD_DIR}'/config.txt'
echo "BVAL_PATH="${LSD_DIR}'/rounded.bval' >> ${LSD_DIR}'/config.txt'
echo "# Path to b-vector file" >> ${LSD_DIR}'/config.txt'
echo "BVEC_PATH="${LSD_DIR}'/flipX.bvec' >> ${LSD_DIR}'/config.txt'
echo "# Path to brain mask" >> ${LSD_DIR}'/config.txt'
echo "MASK_PATH="${DIFF_DATA_RELEASE_DIR}'/mask.nii.gz' >> ${LSD_DIR}'/config.txt'
echo "# Path to noise sigmas" >> ${LSD_DIR}'/config.txt'
echo "SIGMA_PATH="${NOISEMAP_DIR}'/sigmas.nii.gz' >> ${LSD_DIR}'/config.txt'
echo "# Path to noise Ns" >> ${LSD_DIR}'/config.txt'
echo "N_PATH="${NOISEMAP_DIR}'/Ns.nii.gz' >> ${LSD_DIR}'/config.txt'
echo "# Basename for outputs" >> ${LSD_DIR}'/config.txt'
echo "OUTPUT_BASE="${LSD_DIR}'/output' >> ${LSD_DIR}'/config.txt'
echo "# List of deconvolution ratios" >> ${LSD_DIR}'/config.txt'
RR='('
for t in ${RATIOS[@]}; do
  RR+=$t' '
done
RR+=')'
# echo "RATIOS=(1.1 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 4.5 5.0 5.5 6.0 7.0 8.0 10.0)" >> ${LSD_DIR}'/config.txt'
echo "RATIOS="${RR} >> ${LSD_DIR}'/config.txt'
echo "# Maximum SH order" >> ${LSD_DIR}'/config.txt'
echo "SHMAX=8" >> ${LSD_DIR}'/config.txt'
echo "# Relative amplitude threshold for peak extraction" >> ${LSD_DIR}'/config.txt'
echo "PEAK_REL_TH=0.25" >> ${LSD_DIR}'/config.txt'
echo "# Minimum separation (in degrees) for peak extraction" >> ${LSD_DIR}'/config.txt'
echo "PEAK_ANG_SEP=25" >> ${LSD_DIR}'/config.txt'
echo "# Patch size for AIC neighborhood (1 to turn OFF)  " >> ${LSD_DIR}'/config.txt'
echo "PATCHSIZE=3" >> ${LSD_DIR}'/config.txt'
echo "# Number of threads for multiprocessing (-1 for all available CPUs)" >> ${LSD_DIR}'/config.txt'
echo "NCORE="${N_CORES} >> ${LSD_DIR}'/config.txt'
echo " " >> ${LSD_DIR}'/config.txt'



# need to launch LSD script from the folder because paths arent setup properly
cd /data/pt_02015/220601_LSD_Paper/lsd/


sh dummy_LSD_script.sh ${LSD_DIR}'/config.txt'


cd ${DIFF_DIR}






