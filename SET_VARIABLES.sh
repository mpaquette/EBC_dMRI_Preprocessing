#!/bin/bash

# This file needs to be copied in the preprocessing folder of each respective subject. Potential changes in processing should be made in this folder.

# Folder of Bruker Data in Bruker Format
BRUKER_RAW_DIR=/data/pt_02101_dMRI/data/053_C_C_JOHNNY/raw/20230418_183125_053_C_C_JOHNNY_1_2/

#########################################
# Select Scans for Processing

# Reorientation Check
CHECK_REORIENT_SCAN=26 # Typically the first B0 

# Noisemap
NOISE_SCAN=14

# Topup (deprecated)
TOPUP_LR_RUN=26 # Typically the first B0 
TOPUP_RL_RUN=8 # Typically the corresponding revB0 


# Diffusion Data
DIFF_SCANS=(26 16 18 17 23 19 20 21 22)
DATA_RESCALING=0.000683 
MASK_THRESHOLD=0.1
HEAT_CORRECTION=YES #YES/NO # YES is now default for all brain


# FLASH Scans
FLASH_FA_05=4
FLASH_FA_12p5=25
FLASH_FA_25=10
FLASH_FA_50=6
FLASH_FA_80=7
FLASH_HIGHRES=29
FLASH_ULTRA_HIGHRES=32

####################################

# FOV wraping mask paths

FOV_MASK_PATHS='/data/pt_02101_dMRI/misc/FOV_wrap/053_C_C_JOHNNY_FOV_wrap_1_mod.nii.gz '\ 

FOV_OVERLAP_PATHS='/data/pt_02101_dMRI/misc/FOV_wrap/053_C_C_JOHNNY_FOV_wrap_overlap_1.nii.gz '\
'/data/pt_02101_dMRI/misc/FOV_wrap/053_C_C_JOHNNY_FOV_wrap_overlap_2.nii.gz '\
'/data/pt_02101_dMRI/misc/FOV_wrap/053_C_C_JOHNNY_FOV_wrap_overlap_3.nii.gz '\


# Flag including an additional one-step nonlinear registration to correct for slight distortions between FLASH and EPI scans
# This issue was mitigated by a recent Bruker Patch
FLAG_FLASH_CORR=YES #YES/NO # YES is still default for all brain even post "patch" 


# Use nonlinear registration to correct for non EPI traj adjusted reversed PE scans
FLAG_TOPUP_RETRO_RECON=NO #YES/NO
RETRO_RECON_NUMBER=

######
# BASIC PARAMETERS, TYPICALLY SHOULD NOT CHANGE

# Reorientation to MNI space
RESHAPE_ARRAY_ORD="1,0,2"
RESHAPE_ARRAY_INV="2"
RESHAPE_BVECS_ORD="1,0,2"
RES=0.5
HIGHRES=0.25
ULTRA_HIGHRES=0.15


# Eddy Parameters
N_DIRECTION="58"
TE="0.1"
PE_DIRECTION="1"

# parameter for LSD
LSD_RATIOS=(1.1 1.2 1.4 1.6 1.8 2.0 2.2 2.4 2.6 2.8 3.0 3.5 4.0 4.5 5.0 5.5 6.0 7.0 8.0 10.0)
LSD_SHMAX=8
LSD_PEAKRELTH=0.25 
LSD_PEAKANGSEP=25 # deg
LSD_PATCHSIZE=3




# Fetch file directory as Variable
LOCAL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


# Check the number of available cores for parallel processing
N_CORES=48


# How often should N4 homogenize the data
declare -i N4_ITER=5

########################
# Local Folders for Processing
# Diffusion Data Folder Variables
DIFF_DIR="${LOCAL_DIR}/diff/"
DIFF_DATA_DIR="${DIFF_DIR}/data/"
DIFF_DATA_N4_DIR="${DIFF_DIR}/data_N4/"
DIFF_DATA_RELEASE_DIR="${DIFF_DIR}/data_release/"
DIFF_DATA_NORM_RELEASE_DIR="${DIFF_DIR}/data_release_norm/"
DIFF_DATA_BEDPOSTX_DIR="${DIFF_DIR}/data_bedpost/"
DTI_DIR=${DIFF_DIR}/dti
EDDY_DIR="${DIFF_DIR}/eddy/"
EDDY_FIELDS_DIR="${DIFF_DIR}/eddy_fields/"
EDDY_FIELDS_REL_DIR="${DIFF_DIR}/eddy_fields_rel/"
EDDY_FIELDS_JAC_DIR="${DIFF_DIR}/eddy_fields_jac/"
NII_RAW_DIR="${LOCAL_DIR}/nifti_raw/"
UNWRAP_PROC_DIR="${LOCAL_DIR}/fov_unwrap_raw/proc/"
UNWRAP_DIR="${LOCAL_DIR}/fov_unwrap_raw/"
NOISEMAP_DIR="${DIFF_DIR}/noisemap/"
REORIENT_DIR="${DIFF_DIR}/mni_reorient_check/"
SPLIT_DIR="${DIFF_DATA_DIR}/split/"
SPLIT_WARPED_DIR="${DIFF_DATA_DIR}/split_warped/"
TOPUP_DIR="${DIFF_DIR}/topup/"
TISSUE_SEGMENTATION_DIR="${DIFF_DIR}/segmentation/"
ODF_DIR="${DIFF_DIR}/odf/"
JUNA_DIR="${DIFF_DIR}/juna_registration/"
QA_DIR="${DIFF_DIR}/quality_metrics/"

# FLASH Data Folder Variables
FLASH_DIR="${LOCAL_DIR}/flash/"
FLASH_DIR_FA05="${FLASH_DIR}/FA05/"
FLASH_DIR_FA12p5="${FLASH_DIR}/FA12p5/"
FLASH_DIR_FA25="${FLASH_DIR}/FA25/"
FLASH_DIR_FA50="${FLASH_DIR}/FA50/"
FLASH_DIR_FA80="${FLASH_DIR}/FA80/"
FLASH_DIR_HIGHRES="${FLASH_DIR}/HIGHRES/"
FLASH_DIR_ULTRA_HIGHRES="${FLASH_DIR}/ULTRA_HIGHRES/"
FLASH_DIR_WARP="${FLASH_DIR}/Reg_to_EPI/"

JUNA_T1_TEMPLATE=/data/pt_02101_dMRI/external_data/Juna_Template/Juna.Chimp_05mm/Juna_Chimp_T1_05mm_skull_stripped.nii.gz
JUNA_TMP_TEMPLATE=/data/pt_02101_dMRI/external_data/Juna_Template/Juna.Chimp_05mm/Juna_Chimp_TPM_05mm.nii.gz
JUNA_PAD=40

########################
# Set Scripts and Software Folders
SCRIPTS=${LOCAL_DIR}/scripts/
SOFTWARE=/data/pt_02101_dMRI/software/
FSL_LOCAL=${SOFTWARE}/fsl6/bin/
MRDEGIBBS3D=${SOFTWARE}/mrtrix3/mrdegibbs3D/bin/deGibbs3D

CONFIG_DIR=${LOCAL_DIR}/config/
EDDY_PATH=/data/pt_02101_dMRI/software/fsl6/eddy_cuda10.2
########################
# Load Local CONDA Environment
eval "$(/data/pt_02101_dMRI/software/anaconda3/bin/conda shell.bash hook)"
# Multithreading for ANTs
ITK_GET_GLOBAL_DEFAULT_NUMBER_OF_THREADS=${N_CORES}
