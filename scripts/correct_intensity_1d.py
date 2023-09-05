#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import numpy as np
import nibabel as nib
from scipy.ndimage import binary_erosion
# import scipy.optimize as opt
# import pylab as pl


DESCRIPTION =   '''
Heuristic correction of Left/Right intensity bias for 3D image.
The correction is intendend to improve EPI to FLASH ANTS registration. 
Pichael Maquette 2023
'''


def buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument('--in', dest='input', action='store', type=str,
                            help='Name of the input nii file')
    p.add_argument('--out', dest='output', action='store', type=str,
                            help='Name of the output nii file')
    p.add_argument('--mask', dest='mask', action='store', type=str,
                            help='Name of the mask nii file')
    p.add_argument('--ori', dest='orientation', action='store', type=str, default='LR',
                            help='Orientation of the intensity gradient in MNI space. (LR, AP, IS)')
    return p


# default values to params that should probably be in in the argparse
RADIUS = 2.0 # radius for the mask erosion
MIN_N_TH = 10 # minimum of voxels in a slice to accepts it an takes its mean into account


def main():
    # Load parser to read data from command line input
    parser = buildArgsParser()
    args = parser.parse_args()

    data_fname = os.path.realpath(args.input)
    mask_fname = os.path.realpath(args.mask)
    output_fname = os.path.realpath(args.output)
    # orientation of the intensity gradient
    # LR: x, AP: y, IS: z
    if args.orientation not in ['LR', 'AP', 'IS']:
        print('Invalid orientation, must be LR, AP or IS.')
        return None
    else:
        if args.orientation == 'LR':
            ori = 0
        elif args.orientation == 'AP':
            ori = 1
        elif args.orientation == 'IS':
            ori = 2

    # load data
    raw_img = nib.load(data_fname)
    mask_img = nib.load(mask_fname)

    raw = raw_img.get_fdata()
    mask = mask_img.get_fdata().astype(bool)

    # define sphere filter for erosion
    k = int(2*np.ceil(RADIUS)+1) # filter size
    c = k//2 # center of filter
    X, Y, Z = np.meshgrid(np.arange(k), np.arange(k), np.arange(k))
    dist = np.sqrt((X-c)**2 + (Y-c)**2 + (Z-c)**2)
    structure_element = dist <= RADIUS

    mask_ero = binary_erosion(mask, structure_element, 1)

    # mask-aware means
    mask_idx = np.where(mask_ero)
    masksum = np.zeros(mask.shape[ori])
    for i in range(mask.shape[ori]):
        tmp = mask_idx[ori]==i # mask of current slice
        tmp2 = (mask_idx[0][tmp], mask_idx[1][tmp], mask_idx[2][tmp]) # full indexing tuple of current mask slice
        val = raw[tmp2]
        if val.shape[0] > MIN_N_TH:
            masksum[i] = val.mean()
    masksum[np.isnan(masksum)] = 0

    # starting from center, replace zeros with "previous" values
    for i in range(mask.shape[ori]//2, -1, -1):
        if masksum[i] == 0:
            masksum[i] = masksum[i+1]
    for i in range(mask.shape[ori]//2, mask.shape[ori]):
        if masksum[i] == 0:
            masksum[i] = masksum[i-1]

    # compute correction
    corr_1d = 1 / (masksum/masksum.max())
    corr_1d[np.isnan(corr_1d)] = 0
    corr_1d[np.isinf(corr_1d)] = 0
    if ori == 0:
        corr_3d = np.tile(corr_1d[:, None, None], (1, mask.shape[1], mask.shape[2]))
    elif ori == 1:
        corr_3d = np.tile(corr_1d[None, :, None], (mask.shape[0], 1, mask.shape[2]))
    elif ori == 2:
        corr_3d = np.tile(corr_1d[None, None, :], (mask.shape[0], mask.shape[1], 1))
    # correct data
    corrected = raw*corr_3d*mask


    # save output
    nib.Nifti1Image(corrected, affine=raw_img.affine).to_filename(output_fname)




if __name__ == '__main__':
    main()



