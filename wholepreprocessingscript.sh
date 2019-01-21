#!/bin/bash

#Step 1: Fixing of variables.
dwi_cropped=$1
inputname=$2

#Step 2: Preprocessing.
#A. Denoising.
  echo "dwidenoise $dwi_cropped ${inputname}_denoised.mif"
  dwidenoise $dwi_cropped ${inputname}_denoised.mif

#B. Extraction of images with low Bvalue for anatomic reference.

  dwiextract -bvalue_scaling false -shell 660 ${inputname}_denoised.mif - | mrmath -axis 3 - mean ${inputname}_avb660.mif

#C. Correct motion and eddy currents.

  inb_eddy_correct_sge.sh ${inputname}_denoised.mif ${inputname}_denoised_ec.mif ${inputname}_avb660.mif fsl

  while [ ! -f ${inputname}_denoised_ec.mif ]
  do
    echo "No existe el archivo ${inputname}_denoised_ec.mif"
    sleep 10
  done
  sleep 10

#D. New extraction of output images for anatomic reference of the first denoised image.

  dwiextract -bvalue_scaling false -shell 170 ${inputname}_denoised_ec.mif - | mrmath -axis 3 - mean ${inputname}_avb170.mif

#E. Second eddy correction

  inb_eddy_correct_sge.sh ${inputname}_denoised.mif ${inputname}_denoised_ec2.mif ${inputname}_avb170.mif fsl

  while [ ! -f ${inputname}_denoised_ec2.mif ]
  do
    echo "No existe el archivo ${inputname}_denoised_ec2.mif"
    sleep 10
  done 
  sleep 10

#F. Bias field correction

  inb_dwibiascorrect.sh ${inputname}_denoised_ec2.mif nomask ${inputname}_denoised_ec2_bc_mif "-s 2 -v -b 6x6x6x3"

#Step 3: Tensor model
#G. Tensor model calculation

  dwi2tensor ${inputname}_denoised_ec2_bc.mif ${inputname}_dt.mif

  tensor2metric ${inputname}_dt.mif -fa ${inputname}_fa.mif -vector ${inputname}_v1.mif -adc ${inputname}_adc.mif
