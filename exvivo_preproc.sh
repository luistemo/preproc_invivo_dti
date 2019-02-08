#!/bin/bash

#Script based on onarvaez and ricardo coronado preproc-exvivo-script

#Step 1: Creation of varibles
inputdwi1000_exvivo=$1
inputdwi5000_7000_exvivo=$2
prefix_name=$3

#Step2:Preprocessing
#A. File format and extension conversion
echo "mrconvert $inputdwi1000_exvivo ${prefix_name}_b1000.mif"
mrconvert $inputdwi1000_exvivo ${prefix_name}_b1000.mif
echo "mrconvert $inputdwi5000_7000_exvivo ${prefix_name}_b5000_7000.mif"
mrconvert $inputdwi5000_7000_exvivo ${prefix_name}_b5000_7000.mif

#B. Concatenation of the two sequences
mrcat  ${prefix_name}_b1000.mif ${prefix_name}_b5000_7000.mif ${prefix_name}_b1000_7000.mif

#C.Volumes with certain bvalues extraction
dwiextract ${prefix_name}_b1000_7000.mif -no_bzero ${prefix_name}_no_b0_b1000_7000.mif
dwiextract ${prefix_name}_b1000_7000.mif -bzero ${prefix_name}_b0_b1000_7000.mif

#CH. Concatenation of b0 with no b0 volumes
mrcat ${prefix_name}_b0_b1000_7000.mif ${prefix_name}_no_b0_b1000_7000.mif ${prefix_name}_catallb.mif

#D. Denoising
dwidenoise ${prefix_name}_catallb.mif ${prefix_name}_cab_denoised.mif -noise ${prefix_name}_noise.mif 

#E. Once again, volume extraction, but now, only those with no sensibilization to diffusion
dwiextract ${prefix_name}_cab_denoised.mif -bzero ${prefix_name}_cab_denoised_b0.mif

#F. Selection of the best b0 volumes, those with less distortions are left
inb_dwi_exclude_volumes.sh ${prefix_name}_cab_denoised_b0.mif ${prefix_name}_cab_denoised_b08.mif 9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29

#G. Estimation of the mean of the best b0's
mrmath ${prefix_name}_cab_denoised_b08.mif -axis 3 mean ${prefix_name}_cab_denoised_b08_mean.mif

#H. File extension and format conversion to nifti
echo "mrconvert ${prefix_name}_cab_denoised_b08_mean.mif ${prefix_name}_cab_denoised_b08_mean.nii.gz"
mrconvert ${prefix_name}_cab_denoised_b08_mean.mif ${prefix_name}_cab_denoised_b08_mean.nii.gz
echo "mrconvert ${prefix_name}_cab_denoised_b0.mif ${prefix_name}_cab_denoised_b0.nii.gz"
mrconvert ${prefix_name}_cab_denoised_b0.mif ${prefix_name}_cab_denoised_b0.nii.gz

#I. Splitting a 4 dimensional file into 3 dimensional packages 
fslsplit ${prefix_name}_cab_denoised_b0.nii.gz  ${prefix_name}_3dlot

#J. Linear image registration (new variables i and _3dlot)

for i in ${prefix_name}_3dlot*.nii.gz
do
_3dlot=$(echo $i | cut -d '.' -f 1)
flirt -ref ${prefix_name}_cab_denoised_b08_mean.nii.gz -in $i -out ${_3dlot}_b0_to_b0mean.nii.gz -cost mutualinfo -searchcost mutualinfo -v -nosearch -dof 12
done

#K. Concatenation of the outputs b0 to b0mean
mrcat ${prefix_name}_3dlot*_b0_to_b0mean.nii.gz ${prefix_name}_concat_b0.nii.gz

#L. Estimation of the mean obtained from the concatanated 3dlots of a bzero image, which have been registered in the best b0 volumes
 
mrmath ${prefix_name}_concat_b0.nii.gz -axis 3 mean ${prefix_name}_concat_b0mean.nii.gz

#LL. Elimination of files named 3dlot

rm ${prefix_name}_3dlot*

#M. Selection of the volumes with the lowest b value

dwiextract -bvalue_scaling false -shell 1000 ${prefix_name}_cab_denoised.mif ${prefix_name}_cab_denoised_b1000.mif

#N. Conversion of the file format

mrconvert ${prefix_name}_cab_denoised_b1000.mif ${prefix_name}_cab_denoised_b1000.nii.gz

#Ñ. Splitting afresh, in this time the volumes of b1000

fslsplit ${prefix_name}_cab_denoised_b1000.nii.gz ${prefix_name}_3dl_1000

#O. Linear image registration for 1000

for i in ${prefix_name}_3dl_1000*.nii.gz
do
_3dl_1000=$(echo $i | cut -d '.' -f 1)
flirt -ref ${prefix_name}_concat_b0mean.nii.gz -in $i -out ${_3dl_1000}_1000_to_b0mean.nii.gz -cost mutualinfo -searchcost mutualinfo -v -nosearch -dof 12
done

#P. Concatenation of the outputs b1000 to b0meanconcat

mrcat ${prefix_name}_3dl_1000*_1000_to_b0mean.nii.gz ${prefix_name}_concat_b1000.nii.gz

#Q. Mean calculation

mrmath ${prefix_name}_concat_b1000.nii.gz -axis 3 mean ${prefix_name}_concat_b1000mean.nii.gz

#R. Removing the useless files

rm ${prefix_name}_3dl_1000*

#S. All the previous steps from M to S are repeated, but now, for images with a b5000 value

dwiextract -bvalue_scaling false -shell 5000 ${prefix_name}_cab_denoised.mif ${prefix_name}_cab_denoised_b5000.mif
mrconvert ${prefix_name}_cab_denoised_b5000.mif ${prefix_name}_cab_denoised_b5000.nii.gz
fslsplit ${prefix_name}_cab_denoised_b5000.nii.gz ${prefix_name}_3dl_5000
for i in ${prefix_name}_3dl_5000*.nii.gz
do
_3dl_5000=$(echo $i | cut -d '.' -f 1)
flirt -ref ${prefix_name}_concat_b1000mean.nii.gz -in $i -out ${_3dl_5000}_5000_to_b1000mean.nii.gz -cost mutualinfo -searchcost mutualinfo -v -nosearch -dof 12
done
mrcat ${prefix_name}_3dl_5000*_5000_to_b1000mean.nii.gz ${prefix_name}_concat_b5000.nii.gz
mrmath ${prefix_name}_concat_b5000.nii.gz -axis 3 mean ${prefix_name}_concat_b5000mean.nii.gz
rm ${prefix_name}_3dl_5000*

#T. Once again for images with a b7000 value

dwiextract -bvalue_scaling false -shell 7000 ${prefix_name}_cab_denoised.mif ${prefix_name}_cab_denoised_b7000.mif
mrconvert ${prefix_name}_cab_denoised_b7000.mif ${prefix_name}_cab_denoised_b7000.nii.gz
fslsplit ${prefix_name}_cab_denoised_b7000.nii.gz ${prefix_name}_3dl_7000
for i in ${prefix_name}_3dl_7000*.nii.gz
do
_3dl_7000=$(echo $i | cut -d '.' -f 1)
flirt -ref ${prefix_name}_concat_b5000mean.nii.gz -in $i -out ${_3dl_7000}_7000_to_b5000mean.nii.gz -cost mutualinfo -searchcost mutualinfo -v -nosearch -dof 12
done
mrcat ${prefix_name}_3dl_7000*_7000_to_b5000mean.nii.gz ${prefix_name}_concat_b7000.nii.gz
rm ${prefix_name}_3dl_7000*

#U. Exportation of the grandient's values into a .txt file./ Removing and adding the gradient's files 

mrinfo ${prefix_name}_cab_denoised_b0.mif -export_grad_mrtrix ${prefix_name}_b0_1000_7000.txt -bvalue_scaling false
mrconvert ${prefix_name}_concat_b0.nii.gz ${prefix_name}_concat_b0_grad.mif -grad ${prefix_name}_b0_1000_7000.txt
mrinfo ${prefix_name}_cab_denoised_b1000.mif -export_grad_mrtrix ${prefix_name}_b1000.txt -bvalue_scaling false
mrconvert ${prefix_name}_concat_b1000.nii.gz ${prefix_name}_concat_b1000_grad.mif -grad ${prefix_name}_b1000.txt
mrinfo ${prefix_name}_cab_denoised_b5000.mif -export_grad_mrtrix ${prefix_name}_b5000.txt -bvalue_scaling false
mrconvert ${prefix_name}_concat_b5000.nii.gz ${prefix_name}_concat_b5000_grad.mif -grad ${prefix_name}_b5000.txt
mrinfo ${prefix_name}_cab_denoised_b7000.mif -export_grad_mrtrix ${prefix_name}_b7000.txt -bvalue_scaling false
mrconvert ${prefix_name}_concat_b7000.nii.gz ${prefix_name}_concat_b7000_grad.mif -grad ${prefix_name}_b7000.txt

#V. Concatenation of the images already registered with its inmediate lower value and new assignation of the  ordered gradients files

mrcat ${prefix_name}_concat_b0_grad.mif ${prefix_name}_concat_b1000_grad.mif ${prefix_name}_concat_b5000_grad.mif ${prefix_name}_concat_b7000_grad.mif ${prefix_name}_cat_allb_grad.mif

#W. Bias field correction

inb_dwibiascorrect.sh ${prefix_name}_cat_allb_grad.mif nomask ${prefix_name}_cat_allb_grad_bc.mif "-s 2 -v -b 6x6x6x3"

#Step 3. Calculating the tensor model and metrics

dwi2tensor ${prefix_name}_cat_allb_grad_bc.mif ${prefix_name}_ex_dt.mif
tensor2metric -fa ${prefix_name}_ex_fa.mif -adc ${prefix_name}_ex_adc.mif -vector ${prefix_name}_ex_v1.mif -ad ${prefix_name}_ex_ad.mif -rd ${prefix_name}_ex_rd.mif ${prefix_name}_ex_dt.mif

#Step 4. Calculating the csd model
dwi2response dhollander ${prefix_name}_cat_allb_grad_bc.mif ${prefix_name}_ex_wm.txt ${prefix_name}_ex_gm.txt ${prefix_name}_ex_csf.txt

dwi2fod msmt_csd ${prefix_name}_cat_allb_grad_bc.mif ${prefix_name}_ex_wm.txt ${prefix_name}_ex_fod_wm.mif ${prefix_name}_ex_gm.txt ${prefix_name}_ex_fod_gm.mif ${prefix_name}_ex_csf.txt ${prefix_name}_ex_fod_csf.mif

fod2fixel ${prefix_name}_ex_fod_wm.mif fixel -afd ${prefix_name}_ex_afd.mif -peak ${prefix_name}_ex_peak.mif -disp ${prefix_name}_ex_disp.mif

cd fixel
fixel2voxel ${prefix_name}_ex_afd.mif sum ${prefix_name}_ex_afd_sum.mif
fixel2voxel ${prefix_name}_ex_afd.mif mean ${prefix_name}_ex_afd_mean.mif
fixel2voxel ${prefix_name}_ex_afd.mif split_data ${prefix_name}_ex_afd_split.mif
fixel2voxel ${prefix_name}_ex_peak.mif sum ${prefix_name}_ex_peak_sum.mif
fixel2voxel ${prefix_name}_ex_peak.mif mean ${prefix_name}_ex_peak_mean.mif
fixel2voxel ${prefix_name}_ex_peak.mif split_data ${prefix_name}_ex_peak_split.mif
fixel2voxel ${prefix_name}_ex_disp.mif sum ${prefix_name}_ex_disp_sum.mif
fixel2voxel ${prefix_name}_ex_disp.mif mean ${prefix_name}_ex_disp_mean.mif
fixel2voxel ${prefix_name}_ex_disp.mif split_data ${prefix_name}_ex_disp_split.mif







