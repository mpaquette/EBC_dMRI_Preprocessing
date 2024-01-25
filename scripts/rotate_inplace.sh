TEMPLATE=$1
DATA=$2
MASK=$3
WORKDIR=$4

TEMPLATE=${JUNA_T1_TEMPLATE}
DATA=${FLASH_DIR_FA80}/data_degibbs.nii.gz
MASK=${FLASH_DIR_WARP}/mask_flash.nii.gz
WORKDIR=${JUNA_DIR}/rotate_space/

# make temp workspace
echo "mkdir ${WORKDIR}"
mkdir -p $WORKDIR

# temp names
DATA_N4=${WORKDIR}/data_N4.nii.gz
PAD=20
TEMPLATE_PAD=${WORKDIR}/template_pad.nii.gz
TEMPLATE_NEW_AFFINE=${WORKDIR}/template_new_affine.nii.gz
TEMPLATE_NEW_AFFINE_TRANS=${WORKDIR}/template_new_affine_trans.nii.gz
FLIRT_MAT_DOF6=${WORKDIR}/dof6.txt
FLIRT_MAT_DOF9=${WORKDIR}/dof9.txt
FLIRT_MAT_ROT=${WORKDIR}/rot.txt
DATA_WARPED=${WORKDIR}/data_rotated_.nii.gz

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

# rigid registration to template
echo "flirt rigid template"
flirt -in $DATA_N4 \
      -ref ${TEMPLATE_NEW_AFFINE_TRANS} \
      -omat $FLIRT_MAT_DOF6 \
      -dof 6 \
      # -v

# rigid + scaling registration to template
echo "flirt dof=9 template"
flirt -in $DATA_N4 \
      -ref ${TEMPLATE_NEW_AFFINE_TRANS} \
      -omat $FLIRT_MAT_DOF9 \
      -dof 9 \
      # -v

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

# check
mrview $DATA_WARPED $TEMPLATE_NEW_AFFINE_TRANS
