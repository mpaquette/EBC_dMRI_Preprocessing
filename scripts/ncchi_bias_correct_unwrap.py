#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import nibabel as nib
import numpy as np
import os
import pylab as plt


DESCRIPTION =   'Removal of non-central chi bias with simple method of moments. Pichael Maquette 2020'


def buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument('--in', dest='input', action='store', type=str,
                            help='Name of the input nii file')

    p.add_argument('--out', dest='output', action='store', type=str,
                            help='Name of the output folder')

    p.add_argument('--sigma', dest='sigma', action='store', type=str,
                            help='Path of sigma nii file from noisemap characterization')

    p.add_argument('--N', dest='N', action='store', type=str,
                            help='Path of N nii file from noisemap characterization')

    p.add_argument('--axes', dest='axes', action='store', type=str,
                            help='Correct Sigma along which axes (e.g., 0,2)')

    p.add_argument('--mask', dest='mask', action='store', type=str,
                            help='Path of mask nii file from the unwraping step')

    return p


def main():
    # Load parser to read data from command line input
    parser = buildArgsParser()
    args = parser.parse_args()

    # Load input variables
    PATH_IN     = os.path.realpath(args.input)
    PATH_OUT    = os.path.realpath(args.output)
    PATH_SIG    = os.path.realpath(args.sigma)
    PATH_N      = os.path.realpath(args.N)
    PATH_MASK   = os.path.realpath(args.mask)
    AXES        = eval(args.axes) 


    # Load input file and sigma
    print('Loading Input Data {}'.format(PATH_IN))
    data = nib.load(PATH_IN).get_fdata()
    aff = nib.load(PATH_IN).affine
    dims = data.shape

    print('Data Dimensions {}'.format(dims))
    
    
    print('Loading Sigma {}'.format(PATH_SIG))
    sigma = nib.load(PATH_SIG).get_fdata()
    print('Sigma Dimensions {}'.format(sigma.shape))

    print('Loading N {}'.format(PATH_N))
    N = nib.load(PATH_N).get_fdata()
    print('N Dimensions {}'.format(N.shape))

    print('Loading MASK {}'.format(PATH_MASK))
    mask = nib.load(PATH_MASK).get_fdata().astype(bool)
    print('mask Dimensions {}'.format(mask.shape))


    # clean N and sigma a bit
    sigma_min, sigma_max = np.quantile(sigma[mask], [0.005, 0.995])
    # plt.figure()
    # plt.hist(sigma[mask], 1000)
    # plt.axvline(sigma_min)
    # plt.axvline(sigma_max)
    # plt.show()
    N_min, N_max = np.quantile(N[mask], [0.005, 0.995])
    # plt.figure()
    # plt.hist(N[mask], 1000)
    # plt.axvline(N_min)
    # plt.axvline(N_max)
    # plt.show()
    sigma_clip = np.clip(sigma, sigma_min, sigma_max)
    sigma_clip *= mask
    N_clip = np.clip(N, N_min, N_max)
    N_clip *= mask

    # average the estimation over AXES
    # taking into account mask
    masksum = mask.sum(axis = AXES)
    mean_sigma_along_axes = sigma_clip.sum(axis = AXES) / masksum
    mean_sigma_along_axes[masksum==0] = 0
    mean_N_along_axes = N_clip.sum(axis = AXES) / masksum
    mean_N_along_axes[masksum==0] = 0

    # build a tuple with the right slices to reproject 1D to 3D
    # for example, with AXES == (0, 2) 
    # we build broadcast_idx == (None, slice(0, None), None)
    # which act on the data the same as [None, :, None]
    # which then "repeat" the data in the "None" axis
    broadcast_idx = [None]*3
    for i in set([0,1,2]).difference(set(AXES)):
        broadcast_idx[i] = slice(0, None)

    sigma_array = np.zeros_like(sigma)
    sigma_array[:,:,:] = mean_sigma_along_axes[tuple(broadcast_idx)]

    N_array = np.zeros_like(N)
    N_array[:,:,:] = mean_N_along_axes[tuple(broadcast_idx)]


    print("Debiasing Data")
    data_debias = np.sqrt(np.abs(data**2 - 2*N_array[..., None] * sigma_array[..., None]**2))

    data_debias[np.isnan(np.abs(data_debias))] = 0
    data_debias[np.isinf(np.abs(data_debias))] = 0

    data_vmin = 0
    data_vmax = np.percentile(data[...,0], 95)

    sigma_vmin = 0
    sigma_vmax = np.percentile(sigma_array, 95)


    # Plot the noisemap and the sigma variation along the specific axes
    plt.figure()
    plt.subplot(4,3,1)
    plt.title('Orig')
    plt.imshow(data[round(dims[0]/2), :, :, 0], vmin = data_vmin, vmax = data_vmax)
    plt.axis('off')

    plt.subplot(4,3,2)
    plt.title('Orig')
    plt.imshow(data[:, round(dims[1]/2), :, 0], vmin = data_vmin, vmax = data_vmax)
    plt.axis('off')
    
    plt.subplot(4,3,3)
    plt.title('Orig')
    plt.imshow(data[:, :, round(dims[2]/2), 0], vmin = data_vmin, vmax = data_vmax)
    plt.axis('off')

    plt.subplot(4,3,4)
    plt.title('Sigma')
    plt.imshow(sigma_array[round(dims[0]/2), :, :], vmin = sigma_vmin, vmax = sigma_vmax)
    plt.axis('off')

    plt.subplot(4,3,5)
    plt.title('Sigma')
    plt.imshow(sigma_array[:, round(dims[1]/2), :], vmin = sigma_vmin, vmax = sigma_vmax)
    plt.axis('off')
    
    plt.subplot(4,3,6)
    plt.title('Sigma')
    plt.imshow(sigma_array[:, :, round(dims[2]/2)], vmin = sigma_vmin, vmax = sigma_vmax)
    plt.axis('off')

    plt.subplot(4,3,7)
    plt.title('Corr')
    plt.imshow(data_debias[round(dims[0]/2), :, :, 0], vmin = data_vmin, vmax = data_vmax)
    plt.axis('off')

    plt.subplot(4,3,8)
    plt.title('Corr')
    plt.imshow(data_debias[:, round(dims[1]/2), :, 0], vmin = data_vmin, vmax = data_vmax)
    plt.axis('off')
    
    plt.subplot(4,3,9)
    plt.title('Corr')
    plt.imshow(data_debias[:, :, round(dims[2]/2), 0], vmin = data_vmin, vmax = data_vmax)
    plt.axis('off')

    plt.subplot(4,3,10)
    plt.title('')
    plt.imshow(np.log(np.abs(data - data_debias))[round(dims[0]/2), :, :, 0])
    plt.axis('off')

    plt.subplot(4,3,11)
    plt.title('Log Residual')
    plt.imshow(np.log(np.abs(data - data_debias))[:, round(dims[1]/2), :, 0])
    plt.axis('off')
    
    plt.subplot(4,3,12)
    plt.title('Log Residual')
    plt.imshow(np.log(np.abs(data - data_debias))[:, :, round(dims[2]/2), 0])
    plt.axis('off')

    plt.tight_layout()

    plt.show()


    print("Saving Debiased Data")
    nib.nifti1.Nifti1Image(data_debias.astype(np.float32), aff).to_filename(PATH_OUT)


if __name__ == '__main__':
    main()
