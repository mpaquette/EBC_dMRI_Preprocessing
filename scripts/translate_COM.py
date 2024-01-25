#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import numpy as np
import nibabel as nib


# hardcoded 
pixdim = np.array([0.5, 0.5, 0.5])
stride_sign = np.array([-1, 1, 1])



DESCRIPTION = 'Translate images to match Center-of-Mass'
def buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument('--fixed', action='store', type=str,
                            help='Path to fixed data.')
    p.add_argument('--moving', action='store', type=str,
                            help='Path to moving template')

    p.add_argument('--output', action='store', type=str,
                            help='Path to moving image with translated affine.')

    return p



def main():
    # Load parser to read data from command line input
    parser = buildArgsParser()
    args = parser.parse_args()

    fixed_img = nib.load(args.fixed)
    moving_img = nib.load(args.moving)

    fixed_data = fixed_img.get_fdata()
    moving_data = moving_img.get_fdata()




    # compute greyscale weighted center of mass 
    X_moving, Y_moving, Z_moving = np.meshgrid(*[range(x) for x in moving_data.shape], indexing='ij')
    moving_center_X = (X_moving * (moving_data / moving_data.mean())).mean()
    moving_center_Y = (Y_moving * (moving_data / moving_data.mean())).mean()
    moving_center_Z = (Z_moving * (moving_data / moving_data.mean())).mean()
    moving_center = np.array([moving_center_X, moving_center_Y, moving_center_Z])
    #
    X_fixed, Y_fixed, Z_fixed = np.meshgrid(*[range(x) for x in fixed_data.shape], indexing='ij')
    fixed_center_X = (X_fixed * (fixed_data / fixed_data.mean())).mean()
    fixed_center_Y = (Y_fixed * (fixed_data / fixed_data.mean())).mean()
    fixed_center_Z = (Z_fixed * (fixed_data / fixed_data.mean())).mean()
    fixed_center = np.array([fixed_center_X, fixed_center_Y, fixed_center_Z])


    # compute affine with proper translation from center of mass alignement
    trans = np.array([[0.0, 0.0, 0.0, stride_sign[0]*pixdim[0]*(moving_center_X - fixed_center_X)],
                      [0.0, 0.0, 0.0, stride_sign[1]*pixdim[1]*(moving_center_Y - fixed_center_Y)],
                      [0.0, 0.0, 0.0, stride_sign[2]*pixdim[2]*(moving_center_Z - fixed_center_Z)],
                      [0.0, 0.0, 0.0, 0.0]])

    new_affine = moving_img.affine - trans


    nib.Nifti1Image(moving_data, affine=new_affine).to_filename(args.output)



if __name__ == '__main__':
    main()
