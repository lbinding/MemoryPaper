#!/bin/bash
#
#Anatomically Targeted Automated Tractography Version 2
#   Ventral Cingulum Reconstruction 
#
# Modified for the public 
#   Created by Lawrence Binding (at various points of his career)

# Set python
export PATH="/opt/anaconda3/bin:${PATH}"
# Set right MRtrix3 version
export PATH="/opt/mrtrix3/bin:${PATH}"
# Set FSL settings
export FSLDIR=/usr2/mrtools/fsl-6.0.3/
export FSLOUTPUTTYPE=NIFTI_GZ
export PATH=${FSLDIR}/bin:${PATH}
#Freesurfer Developmental 
export PATH="/home/lawrence/Freesurfer/freesurfer_dev/:${PATH}"
export PATH="/home/lawrence/Freesurfer/freesurfer_dev/bin:${PATH}"
export FREESURFER_HOME="/home/lawrence/Freesurfer/freesurfer_dev"

#Assign scripts to varaibles
script_dir="$(dirname "$(realpath "$0")")"
parent_dir="$(dirname "$script_dir")"

dilation=${script_dir}/Dilate_mask.py
pruning=${script_dir}//prune_tck_LB.sh
ROIsplit=${script_dir}/split_parcel_long_axis.py

#Assign where the 7T masks are located
anatomical_priors="$parent_dir/anatomical_constraints"

#Setup default Variables
niftyReg="false"

# Loop over arguments looking for -i and -o
args=("$@")
i=0
while [ $i -lt $# ]; do
    if ( [ ${args[i]} = "-gif" ] || [ ${args[i]} = "-g" ] ) ; then
      # Set destrieux parcellation
      let i=$i+1
      gif_parc=${args[i]}
    elif ( [ ${args[i]} = "-T1" ] || [ ${args[i]} = "-t1" ] ) ; then
      # Set gif parcellation
      let i=$i+1
      T1=${args[i]}
    elif ( [ ${args[i]} = "-fivett" ] ) ; then
      # Set fivett 
      let i=$i+1
      fivett=${args[i]}
    elif ( [ ${args[i]} = "-FOD" ] || [ ${args[i]} = "-fod" ] ) ; then
      # Set FOD 
      let i=$i+1
      FOD=${args[i]}
    elif ( [ ${args[i]} = "-output" ] || [ ${args[i]} = "-o" ] || [ ${args[i]} = "-out" ]) ; then
      # Set output dir 
      let i=$i+1
      out_dir=${args[i]}
    elif ( [ ${args[i]} = "-roi_dir" ] || [ ${args[i]} = "-roi" ]) ; then
      # Set ROI dir 
      let i=$i+1
      base_roi_dir=${args[i]}
    elif ( [ ${args[i]} = "-niftyReg" ] ) ; then
      # Set ROI dir 
      let i=$i+1
      niftyReg="true"
    elif ( [ ${args[i]} = "-alg" ] ) ; then
      # Set ROI dir 
      let i=$i+1
      algorithm=${args[i]}
    fi
    let i=$i+1
done

# Check if user gave correct inputs
if ( [ -z ${gif_parc} ] || [ -z ${fivett} ] || [ -z ${FOD} ]) ; then
    correct_input=0
else 
    correct_input=1
fi

# In case user wants to do deterministic tractography 
if ( [ "${algorithm}" == "prob" ] ) ; then
    algorithm=iFOD2
    options="-backtrack -cutoff 0.1"
  elif ( [ "${algorithm}" == "det" ] ) ; then
    algorithm=SD_Stream
  elif ( [ -z ${algorithm} ] ) ; then
    algorithm=iFOD2
    options="-backtrack -cutoff 0.1"
  else 
  echo "Algorithm not recognised, please select 'det' or 'prob'"
  exit 
fi

#Check the user has provided the correct inputs
if ( [[ ${correct_input} -eq 0 ]] ) ; then
  echo ""
  echo "Incorrect input. Please see below for correct use"
  echo ""
  echo "Options:"
  echo " -gif:          Input GIF parcellation -- REQUIRED"
  echo " -T1:           Input T1 parcellation -- REQUIRED"
  echo " -fivett:       Input 5tt image -- REQUIRED"  
  echo " -FOD:          Input CSD image -- REQUIRED"  
  echo " -out:          Output folder for tracts -- REQUIRED"  
  echo " -roi_dir:      Output folder for tract ROIs -- REQUIRED"  
  echo " -niftyReg:     Use NiftyReg registration tract mask -- OPTIONAL"  
  echo " -alg:          Select default algorithm: det or prob (default=prob) -- OPTIONAL"  
  echo ""
  echo "${script_name} -gif gif_parc.nii.gz -fivett 5tt_hsvs.nii.gz -fod wm.mif -tracts tractography/tracts -roi_dir tractography/tract_ROIs"
  echo ""
  exit
fi

#If base ROI directory is not set, set it as the output directory
if [ -z ${base_roi_dir} ]; then 
    base_roi_dir=${out_dir}/roi
fi 

# Add bundle name to roi_dir
roi_dir=${base_roi_dir}/vCing
mask_dir=${base_roi_dir}/masks

# Create folders if needed
if [ ! -d ${out_dir} ] ; then mkdir -p ${out_dir} ; fi
if [ ! -d ${roi_dir} ] ; then mkdir -p ${roi_dir} ; fi
if [ ! -d ${mask_dir} ] ; then mkdir -p ${mask_dir} ; fi

#If user specifies niftyReg instead of easyReg then use this:
if [ ${niftyReg} = "true" ]; then
  echo "Registering MNI masks to subjects T1 using NiftyReg..." 
  #Make output directory
  if [ ! -d ${base_roi_dir}/niftiReg/ ]; then mkdir -p ${base_roi_dir}/niftiReg/; fi 
  #Extract brainMask 
  if [ ! -f ${base_roi_dir}/niftiReg/T1_brain.nii.gz ]; then 
      mri_synthstrip -i ${T1} -o ${base_roi_dir}/niftiReg/T1_brain.nii.gz
  fi 
  #Align brain T1 to MNI brain 
  if [ ! -f ${base_roi_dir}/niftiReg/T1_to_MNI_affine.mat ]; then 
      reg_aladin -ref ${FSLDIR}/data/standard/MNI152_T1_1mm_brain -flo ${base_roi_dir}/niftiReg/T1_brain.nii.gz -aff ${base_roi_dir}/niftiReg/T1_to_MNI_affine.mat
  fi 
  if [ ! -f ${base_roi_dir}/niftiReg/MNI_to_T1_affine.mat ]; then 
      convert_xfm -omat ${base_roi_dir}/niftiReg/MNI_to_T1_affine.mat -inverse ${base_roi_dir}/niftiReg/T1_to_MNI_affine.mat 
  fi 
  if [ ! -f ${base_roi_dir}/niftiReg/MNI_to_T1_f3d.nii.gz ]; then 
      reg_f3d -ref ${T1} -flo ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz -aff ${base_roi_dir}/niftiReg/MNI_to_T1_affine.mat -cpp ${base_roi_dir}/niftiReg/MNI_to_T1_cpp.nii.gz -res ${base_roi_dir}/niftiReg/MNI_to_T1_f3d.nii.gz
  fi 
  #Threshold image 
  if [ ! -f ${mask_dir}/left_vCing_MNI_dil.nii.gz ]; then 
      reg_resample -flo ${anatomical_priors}/left_vCing_MNI_dil.nii.gz -ref ${T1} -trans ${base_roi_dir}/niftiReg/MNI_to_T1_cpp.nii.gz -res ${mask_dir}/left_vCing_MNI_dil.nii.gz
  fi 
  if [ ! -f ${mask_dir}/right_vCing_MNI_dil.nii.gz ]; then 
      reg_resample -flo ${anatomical_priors}/right_vCing_MNI_dil.nii.gz -ref ${T1} -trans ${base_roi_dir}/niftiReg/MNI_to_T1_cpp.nii.gz -res ${mask_dir}/right_vCing_MNI_dil.nii.gz
  fi 
else 
  echo "Registering MNI masks to subjects T1 using EasyReg..." 
  #Make output directory
  if [ ! -d ${base_roi_dir}/easyReg/ ]; then mkdir -p ${base_roi_dir}/easyReg/; fi 
  #Use synthSeg to parcellate the T1 image 
  if [ ! -f ${base_roi_dir}/easyReg/T1_synthseg.nii.gz ]; then 
    mri_synthseg --i ${T1} --o ${base_roi_dir}/easyReg/T1_synthseg.nii.gz --robust --parc --threads 1
  fi 
  #easyReg
  if [ ! -f ${base_roi_dir}/easyReg/MNI_to_T1_fwd.nii.gz ]; then 
    mri_easyreg --flo ${FSLDIR}/data/standard/MNI152_T1_1mm.nii.gz --ref ${T1} --flo_seg /mounts/auto/p1802LanguageFT/AT_ATv3/priors_anatomical/MNI152_T1_1mm_synthSeg.nii.gz --ref_seg ${base_roi_dir}/easyReg/T1_synthseg.nii.gz --flo_reg ${base_roi_dir}/easyReg/MNI_to_T1.nii.gz --fwd_field ${base_roi_dir}/easyReg/MNI_to_T1_fwd.nii.gz --threads 15
  fi 
  #EasyWarp 
  if [ ! -f ${mask_dir}/left_vCing_MNI_dil.nii.gz ]; then 
      mri_easywarp --i ${anatomical_priors}/left_vCing_MNI_dil.nii.gz --o ${mask_dir}/left_vCing_MNI_dil.nii.gz --field ${base_roi_dir}/easyReg/MNI_to_T1_fwd.nii.gz --threads 15 
  fi 
  if [ ! -f ${mask_dir}/right_vCing_MNI_dil.nii.gz ]; then 
      mri_easywarp --i ${anatomical_priors}/right_vCing_MNI_dil.nii.gz --o ${mask_dir}/right_vCing_MNI_dil.nii.gz --field ${base_roi_dir}/easyReg/MNI_to_T1_fwd.nii.gz --threads 15 
  fi 
fi 

#Left Seeds
if ( [ ! -f ${roi_dir}/left_vCingANT_seed.nii.gz ] && [ ! -f ${roi_dir}/left_vCingMID_seed.nii.gz ] && [ ! -f ${roi_dir}/left_vCingPOS_seed.nii.gz ] ); then 
    ${ROIsplit} --parc ${gif_parc} --label 49 --sections 3 --out ${roi_dir}/left_hippo_split.nii.gz
    ${ROIsplit} --parc ${gif_parc} --label 172 --sections 3 --out ${roi_dir}/left_PHG_split.nii.gz
    #Split anterior
    fslmaths ${roi_dir}/left_hippo_split.nii.gz -thr 2.5 -uthr 3.5 ${roi_dir}/left_HIPPOant_seed.nii.gz
    fslmaths ${roi_dir}/left_PHG_split.nii.gz -thr 2.5 -uthr 3.5 ${roi_dir}/left_PHGant_seed.nii.gz
    #Split Mid
    fslmaths ${roi_dir}/left_hippo_split.nii.gz -thr 1.5 -uthr 2.5 ${roi_dir}/left_HIPPOmid_seed.nii.gz
    fslmaths ${roi_dir}/left_PHG_split.nii.gz -thr 1.5 -uthr 2.5 ${roi_dir}/left_PHGmid_seed.nii.gz
    #Split posterior
    fslmaths ${roi_dir}/left_hippo_split.nii.gz -thr 0.5 -uthr 1.5 ${roi_dir}/left_HIPPOpos_seed.nii.gz
    fslmaths ${roi_dir}/left_PHG_split.nii.gz -thr 0.5 -uthr 1.5 ${roi_dir}/left_PHGpos_seed.nii.gz
    #Combine 
    fslmaths ${roi_dir}/left_HIPPOant_seed.nii.gz -add ${roi_dir}/left_PHGant_seed.nii.gz -bin ${roi_dir}/left_vCingANT_seed.nii.gz
    fslmaths ${roi_dir}/left_HIPPOmid_seed.nii.gz -add ${roi_dir}/left_PHGmid_seed.nii.gz -bin ${roi_dir}/left_vCingMID_seed.nii.gz
    fslmaths ${roi_dir}/left_HIPPOpos_seed.nii.gz -add ${roi_dir}/left_PHGpos_seed.nii.gz -bin ${roi_dir}/left_vCingPOS_seed.nii.gz
fi

#Right seeds 
if ( [ ! -f ${roi_dir}/right_vCingANT_seed.nii.gz ] && [ ! -f ${roi_dir}/right_vCingMID_seed.nii.gz ] && [ ! -f ${roi_dir}/right_vCingPOS_seed.nii.gz ] ); then 
    ${ROIsplit} --parc ${gif_parc} --label 48 --sections 3 --out ${roi_dir}/right_hippo_split.nii.gz
    ${ROIsplit} --parc ${gif_parc} --label 171 --sections 3 --out ${roi_dir}/right_PHG_split.nii.gz
    #Split anterior
    fslmaths ${roi_dir}/right_hippo_split.nii.gz -thr 2.5 -uthr 3.5 ${roi_dir}/right_HIPPOant_seed.nii.gz
    fslmaths ${roi_dir}/right_PHG_split.nii.gz -thr 2.5 -uthr 3.5 ${roi_dir}/right_PHGant_seed.nii.gz
    #Split Mid
    fslmaths ${roi_dir}/right_hippo_split.nii.gz -thr 1.5 -uthr 2.5 ${roi_dir}/right_HIPPOmid_seed.nii.gz
    fslmaths ${roi_dir}/right_PHG_split.nii.gz -thr 1.5 -uthr 2.5 ${roi_dir}/right_PHGmid_seed.nii.gz
    #Split posterior
    fslmaths ${roi_dir}/right_hippo_split.nii.gz -thr 0.5 -uthr 1.5 ${roi_dir}/right_HIPPOpos_seed.nii.gz
    fslmaths ${roi_dir}/right_PHG_split.nii.gz -thr 0.5 -uthr 1.5 ${roi_dir}/right_PHGpos_seed.nii.gz
    #Combine 
    fslmaths ${roi_dir}/right_HIPPOant_seed.nii.gz -add ${roi_dir}/right_PHGant_seed.nii.gz -bin ${roi_dir}/right_vCingANT_seed.nii.gz
    fslmaths ${roi_dir}/right_HIPPOmid_seed.nii.gz -add ${roi_dir}/right_PHGmid_seed.nii.gz -bin ${roi_dir}/right_vCingMID_seed.nii.gz
    fslmaths ${roi_dir}/right_HIPPOpos_seed.nii.gz -add ${roi_dir}/right_PHGpos_seed.nii.gz -bin ${roi_dir}/right_vCingPOS_seed.nii.gz
fi

if [ ! -f ${roi_dir}/left_cinGv_termination.nii.gz ]; then 
    fslmaths ${gif_parc} -thr 169.5 -uthr 170.5 -bin ${roi_dir}/left_precuneus.nii.gz
    fslmaths ${gif_parc} -thr 167.5 -uthr 168.5 -bin ${roi_dir}/left_PCgG.nii.gz
    fslmaths ${roi_dir}/left_precuneus.nii.gz -add ${roi_dir}/left_PCgG.nii.gz -bin ${roi_dir}/left_cinGv_termination.nii.gz

fi
if [ ! -f ${roi_dir}/right_cinGv_termination.nii.gz ]; then 
    fslmaths ${gif_parc} -thr 168.5 -uthr 169.5 -bin ${roi_dir}/right_precuneus.nii.gz
    fslmaths ${gif_parc} -thr 166.5 -uthr 167.5 -bin ${roi_dir}/right_PCgG.nii.gz
    fslmaths ${roi_dir}/right_precuneus.nii.gz -add ${roi_dir}/right_PCgG.nii.gz -bin ${roi_dir}/right_cinGv_termination.nii.gz
fi


#Dilation of ventral stem cortical terminations
if [ ! -f ${roi_dir}/left_vCingANT_seed_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/left_vCing_MNI_dil.nii.gz --in ${roi_dir}/left_vCingANT_seed.nii.gz --out ${roi_dir}/left_vCingANT_seed_dil.nii.gz
fi 
if [ ! -f ${roi_dir}/left_vCingMID_seed_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/left_vCing_MNI_dil.nii.gz --in ${roi_dir}/left_vCingMID_seed.nii.gz --out ${roi_dir}/left_vCingMID_seed_dil.nii.gz
fi 
if [ ! -f ${roi_dir}/left_vCingPOS_seed_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/left_vCing_MNI_dil.nii.gz --in ${roi_dir}/left_vCingPOS_seed.nii.gz --out ${roi_dir}/left_vCingPOS_seed_dil.nii.gz
fi 
if [ ! -f ${roi_dir}/left_cinGv_termination_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/left_vCing_MNI_dil.nii.gz --in ${roi_dir}/left_cinGv_termination.nii.gz --out ${roi_dir}/left_cinGv_termination_dil.nii.gz
fi 
if [ ! -f ${roi_dir}/right_vCingANT_seed_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/right_vCing_MNI_dil.nii.gz --in ${roi_dir}/right_vCingANT_seed.nii.gz --out ${roi_dir}/right_vCingANT_seed_dil.nii.gz
fi 
if [ ! -f ${roi_dir}/right_vCingMID_seed_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/right_vCing_MNI_dil.nii.gz --in ${roi_dir}/right_vCingMID_seed.nii.gz --out ${roi_dir}/right_vCingMID_seed_dil.nii.gz
fi 
if [ ! -f ${roi_dir}/right_vCingPOS_seed_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/right_vCing_MNI_dil.nii.gz --in ${roi_dir}/right_vCingPOS_seed.nii.gz --out ${roi_dir}/right_vCingPOS_seed_dil.nii.gz
fi 
if [ ! -f ${roi_dir}/right_cinGv_termination_dil.nii.gz ]; then 
    ${dilation} --hsvs_5tt ${fivett} --mask ${mask_dir}/right_vCing_MNI_dil.nii.gz --in ${roi_dir}/right_cinGv_termination.nii.gz --out ${roi_dir}/right_cinGv_termination_dil.nii.gz
fi 

#Tckgen Probabilistic (LEFT: cinGv)
if [ ! -f ${out_dir}/left_vCing_combined.tck ]; then 
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/left_vCingANT_seed_dil.nii.gz -include ${roi_dir}/left_cinGv_termination_dil.nii.gz -maxlength 300 ${out_dir}/left_vCingANT_SW.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/left_vCing_MNI_dil.nii.gz -select 5k
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/left_cinGv_termination_dil.nii.gz -include ${roi_dir}/left_vCingANT_seed_dil.nii.gz -maxlength 300 ${out_dir}/left_vCingANT_WS.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/left_vCing_MNI_dil.nii.gz -select 5k
    tckedit ${out_dir}/left_vCingANT_SW.tck ${out_dir}/left_vCingANT_WS.tck ${out_dir}/left_vCingANT.tck -force
    tckedit ${out_dir}/left_vCingANT.tck -include ${roi_dir}/left_vCingANT_seed_dil.nii.gz -include ${roi_dir}/left_cinGv_termination_dil.nii.gz -ends_only ${out_dir}/left_vCingANT_ends.tck -force
    #
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/left_vCingMID_seed_dil.nii.gz -include ${roi_dir}/left_cinGv_termination_dil.nii.gz -maxlength 300 ${out_dir}/left_vCingMID_SW.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/left_vCing_MNI_dil.nii.gz -select 5k
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/left_cinGv_termination_dil.nii.gz -include ${roi_dir}/left_vCingMID_seed_dil.nii.gz -maxlength 300 ${out_dir}/left_vCingMID_WS.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/left_vCing_MNI_dil.nii.gz -select 5k
    tckedit ${out_dir}/left_vCingMID_SW.tck ${out_dir}/left_vCingMID_WS.tck ${out_dir}/left_vCingMID.tck -force
    tckedit ${out_dir}/left_vCingMID.tck -include ${roi_dir}/left_vCingMID_seed_dil.nii.gz -include ${roi_dir}/left_cinGv_termination_dil.nii.gz -ends_only ${out_dir}/left_vCingMID_ends.tck -force
    #
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/left_vCingPOS_seed_dil.nii.gz -include ${roi_dir}/left_cinGv_termination_dil.nii.gz -maxlength 300 ${out_dir}/left_vCingPOS_SW.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/left_vCing_MNI_dil.nii.gz -select 5k
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/left_cinGv_termination_dil.nii.gz -include ${roi_dir}/left_vCingPOS_seed_dil.nii.gz -maxlength 300 ${out_dir}/left_vCingPOS_WS.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/left_vCing_MNI_dil.nii.gz -select 5k
    tckedit ${out_dir}/left_vCingPOS_SW.tck ${out_dir}/left_vCingPOS_WS.tck ${out_dir}/left_vCingPOS.tck -force
    tckedit ${out_dir}/left_vCingPOS.tck -include ${roi_dir}/left_vCingPOS_seed_dil.nii.gz -include ${roi_dir}/left_cinGv_termination_dil.nii.gz -ends_only ${out_dir}/left_vCingPOS_ends.tck -force
    #
    tckedit ${out_dir}/left_vCingANT_ends.tck  ${out_dir}/left_vCingMID_ends.tck ${out_dir}/left_vCingPOS_ends.tck ${out_dir}/left_vCingCOMBINED_ends.tck 
    #
    ${pruning} -in ${out_dir}/left_vCingCOMBINED_ends.tck  -templ_im ${T1} -out ${out_dir}/left_vCing_combined.tck -thr 0.01
    if [ -f ${out_dir}/left_vCing_combined.tck ]; then 
        rm -r ${out_dir}/left_vCingANT_SW.tck ${out_dir}/left_vCingANT_WS.tck ${out_dir}/left_vCingMID_SW.tck ${out_dir}/left_vCingMID_WS.tck ${out_dir}/left_vCingPOS_SW.tck ${out_dir}/left_vCingPOS_WS.tck
    fi 
fi
#Tckgen Probabilistic (RIGHT: cinGv)
if [ ! -f ${out_dir}/right_vCing_combined.tck ]; then 
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/right_vCingANT_seed_dil.nii.gz -include ${roi_dir}/right_cinGv_termination_dil.nii.gz -maxlength 300 ${out_dir}/right_vCingANT_SW.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/right_vCing_MNI_dil.nii.gz -select 5k
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/right_cinGv_termination_dil.nii.gz -include ${roi_dir}/right_vCingANT_seed_dil.nii.gz -maxlength 300 ${out_dir}/right_vCingANT_WS.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/right_vCing_MNI_dil.nii.gz -select 5k
    tckedit ${out_dir}/right_vCingANT_SW.tck ${out_dir}/right_vCingANT_WS.tck ${out_dir}/right_vCingANT.tck -force
    tckedit ${out_dir}/right_vCingANT.tck -include ${roi_dir}/right_vCingANT_seed_dil.nii.gz -include ${roi_dir}/right_cinGv_termination_dil.nii.gz -ends_only ${out_dir}/right_vCingANT_ends.tck -force
    #
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/right_vCingMID_seed_dil.nii.gz -include ${roi_dir}/right_cinGv_termination_dil.nii.gz -maxlength 300 ${out_dir}/right_vCingMID_SW.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/right_vCing_MNI_dil.nii.gz -select 5k
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/right_cinGv_termination_dil.nii.gz -include ${roi_dir}/right_vCingMID_seed_dil.nii.gz -maxlength 300 ${out_dir}/right_vCingMID_WS.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/right_vCing_MNI_dil.nii.gz -select 5k
    tckedit ${out_dir}/right_vCingMID_SW.tck ${out_dir}/right_vCingMID_WS.tck ${out_dir}/right_vCingMID.tck -force
    tckedit ${out_dir}/right_vCingMID.tck -include ${roi_dir}/right_vCingMID_seed_dil.nii.gz -include ${roi_dir}/right_cinGv_termination_dil.nii.gz -ends_only ${out_dir}/right_vCingMID_ends.tck -force
    #
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/right_vCingPOS_seed_dil.nii.gz -include ${roi_dir}/right_cinGv_termination_dil.nii.gz -maxlength 300 ${out_dir}/right_vCingPOS_SW.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/right_vCing_MNI_dil.nii.gz -select 5k
    tckgen ${FOD} -algorithm ${algorithm} -act ${fivett} -seed_image ${roi_dir}/right_cinGv_termination_dil.nii.gz -include ${roi_dir}/right_vCingPOS_seed_dil.nii.gz -maxlength 300 ${out_dir}/right_vCingPOS_WS.tck  -force ${options} -seeds 25000000 -mask ${mask_dir}/right_vCing_MNI_dil.nii.gz -select 5k
    tckedit ${out_dir}/right_vCingPOS_SW.tck ${out_dir}/right_vCingPOS_WS.tck ${out_dir}/right_vCingPOS.tck -force
    tckedit ${out_dir}/right_vCingPOS.tck -include ${roi_dir}/right_vCingPOS_seed_dil.nii.gz -include ${roi_dir}/right_cinGv_termination_dil.nii.gz -ends_only ${out_dir}/right_vCingPOS_ends.tck -force
    #
    tckedit ${out_dir}/right_vCingANT_ends.tck  ${out_dir}/right_vCingMID_ends.tck ${out_dir}/right_vCingPOS_ends.tck ${out_dir}/right_vCingCOMBINED_ends.tck 
    #
    ${pruning} -in ${out_dir}/right_vCingCOMBINED_ends.tck  -templ_im ${T1} -out ${out_dir}/right_vCing_combined.tck -thr 0.01
    if [ -f ${out_dir}/right_vCing_combined.tck ]; then 
        rm -r ${out_dir}/right_vCingANT_SW.tck ${out_dir}/right_vCingANT_WS.tck ${out_dir}/right_vCingMID_SW.tck ${out_dir}/right_vCingMID_WS.tck ${out_dir}/right_vCingPOS_SW.tck ${out_dir}/right_vCingPOS_WS.tck
    fi 
fi
