#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse 
import nibabel as nib
import numpy as np
import os
from scipy import interp


DESCRIPTION = """
Drift Correction of dMRI Data, Based on Linear Interpolation Between b0s
"""


EPILOG = """
Created by Cornelius Eichner, MPI CBS, 2021.
Updated with timestamps by Michael Paquette, MPI CBS, 2021.
"""


class CustomFormatter(argparse.ArgumentDefaultsHelpFormatter, argparse.RawTextHelpFormatter):
    pass


def buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION,
                                epilog=EPILOG,
                                formatter_class=CustomFormatter)
    p.add_argument('--in', dest='input', action='store', type=str,
                            help='Input Data Path')
    
    p.add_argument('--mask', dest='mask', action='store', type=str, default='',
                                help='Mask Path')

    p.add_argument('--bval', dest='bval', action='store', type=str,
                            help='BVALS Path')

    p.add_argument('--time', dest='timestamp', action='store', type=str,
                            help='Timestamps Path')

    p.add_argument('--image', dest='image', action='store', type=str, default='./',
                            help='Output Path for correction png')

    p.add_argument('--out', dest='out', action='store', type=str,
                            help='Output Path')

    return p


def main():

    # Load parser to read data from command line input
    parser = buildArgsParser()
    args = parser.parse_args()

    # Load input variables
    PATH_IN     = os.path.realpath(args.input)
    PATH_BVAL   = os.path.realpath(args.bval)
    PATH_TIME   = os.path.realpath(args.timestamp)
    PATH_IMAGE  = os.path.realpath(args.image) 
    PATH_OUT    = os.path.realpath(args.out) 

    # Load Data
    print('Loading Data')
    data = nib.load(PATH_IN).get_fdata().astype(np.float32)
    data = np.clip(data, 0, np.inf)
    aff = nib.load(PATH_IN).affine
    dims = data.shape

    if len(args.mask) > 0:
        PATH_MASK = os.path.realpath(args.mask)
        mask = nib.load(PATH_MASK).get_fdata().astype(bool)
    else:
        mask = np.ones(data.shape[:3], dtype=bool)

    bvals = np.genfromtxt(PATH_BVAL)

    timestamps = np.genfromtxt(PATH_TIME, dtype=int)


    print('Running Drift Correction')

    b0_idx = np.where(bvals < 100.0)[0]
    nonb0 = bvals > 100.0

    print('b0 index: {}'.format(b0_idx))

    # timestamps of b0s
    x_ = timestamps[b0_idx]
    A_ = np.vstack([x_, np.ones(len(x_))]).T

    # Calculate B0 mean 
    data_mean = data[mask].mean(axis=0)

    # fit slope m_ and y-intercept c_
    m_, c_ = np.linalg.lstsq(A_, data_mean[b0_idx], rcond=None)[0]

    # correction = (m*x_prime + c) / (m*0 + c) = (m*x_prime / c) + 1
    drift_scaling = ((timestamps*m_) / c_) + 1
    data_drift_corr = data[..., :] / drift_scaling

    data_corr_mean = data_drift_corr[mask].mean(axis=0)



    # Save Data
    print('Saving clipped Data')
    nib.save(nib.Nifti1Image(np.clip(data_drift_corr, 0, np.inf), aff), PATH_OUT)




    import pylab as pl
    from matplotlib.collections import LineCollection 
    pl.figure()
    pl.subplot(2,1,1)
    pl.plot(timestamps, m_*timestamps + c_)
    pl.scatter(x_, data_mean[b0_idx])
    pl.title('Fit on B0s')
    pl.subplot(2,1,2)
    # pl.semilogy(timestamps, data_mean, label='before', alpha=0.5)
    pl.scatter(timestamps[nonb0], data_mean[nonb0], label='before', alpha=0.5)
    # pl.semilogy(timestamps, data_drift_corr[mask].mean(axis=0), label='after', alpha=0.5)
    pl.scatter(timestamps[nonb0], data_corr_mean[nonb0], label='after', alpha=0.5)
    pl.legend()
    pl.title('Drift correction on data')
    pl.gca().set_yscale('log')

    # add connecting line for each point pair
    lines = [[(timestamps[nonb0][i], data_mean[nonb0][i]), (timestamps[nonb0][i], data_corr_mean[nonb0][i])] for i in range(nonb0.sum())]
    lc = LineCollection(lines, color='black', linestyle='dashed', alpha=0.5)
    pl.gca().add_collection(lc)
    pl.savefig(PATH_IMAGE, dpi=100)
    pl.show()




if __name__ == '__main__':
    main()
