#!/usr/bin/env python3

import argparse
import numpy as np
import nibabel as nib
from time import time
# import pickle

# import warnings
# warnings.simplefilter("ignore", RuntimeWarning)
# with np.errstate(divide='ignore', invalid='ignore'):

# VERBOSE=True
VERBOSE=False


DESCRIPTION = """
"""

np.set_printoptions(precision=2)

def _buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument('-data', type=str, nargs='+',
                            help='Name of the input(s)')
    p.add_argument('-mask', type=str,
                            help='Name of the mask')
    p.add_argument('-prior', type=str, nargs='+',
                            help='Name of the prior(s)')
    p.add_argument('-maxit', type=int, default=100,
                            help='Maximum number of EM iterations [%(default)s]')
    p.add_argument('-th', type=float, default=1.0,
                            help='Log-likeliood change threshold [%(default)s]')
    p.add_argument('-outprob', type=str, default=None,
                            help='Name of the output tissue probability maps (.nii.gz)')
    p.add_argument('-outrgb', type=str, default=None,
                            help='Name of the output tissue clasification maps (.nii.gz)')
    p.add_argument('-outlog', type=str, default=None,
                            help='Name of the output log file (.ntxt)')
    p.add_argument('-outclass', type=str, default=None,
                            help='Name of the output class parameters file (no-ext)')
    return p



def _cluster_param(data, belong):
    # compute cluster Normal params from data and current belonging probs
    K = belong.shape[-1]
    n = data.shape[-1]
    sum_idx = tuple(range(data.ndim - 1))

    mus = np.zeros((K, n)) # in the ref v_k
    sigmas = np.zeros((K, n, n)) # in the ref: c_k
    counts = np.zeros(K) # in the ref: h_k

    for i in range(K): 
        counts[i] = belong[..., i].sum()

    for i in range(K):
        mus[i] = (belong[..., i, None]*data).sum(axis=sum_idx) / counts[i]

    for i in range(K):
        diff = data-mus[i]
        sigmas[i] = np.sum(belong[..., i, None, None]*np.einsum('...i,...j->...ij', diff, diff), axis=sum_idx) / counts[i]

    return counts, mus, sigmas


def _assign_probability(data, prior, counts, mus, sigmas, mask):
    K = prior.shape[-1]
    n = data.shape[-1]

    intensity_likelihoods = np.zeros_like(prior)  # in the ref: r_ij_k
    for i in range(K):
        diff = (data-mus[i])
        intensity_likelihoods[..., i] = (2*np.pi)**(-n/2) * np.linalg.det(sigmas[i])**(-1/2) * np.exp(-0.5*np.einsum('...i,ij,...j->...', diff, np.linalg.inv(sigmas[i]), diff))

    # patch for voxel with all likelihood at 0, due to precision limitations
    intensity_likelihoods[np.all(intensity_likelihoods==0, axis=-1)] = [1e-100, 1e-100, 1e-100]


    current_prior = np.zeros_like(prior) # in the ref: s_ij_k
    for i in range(K):
        current_prior[..., i] = (counts[i]*prior[..., i]) / prior[..., i].sum()

    tmp = intensity_likelihoods*current_prior
    tmpclustersum = tmp.sum(axis=-1)
    with np.errstate(divide='ignore', invalid='ignore'):
        new_belong = tmp / tmpclustersum[..., None] # in the ref: p_ij_k
    new_belong[~mask] = 0

    loglike = np.log(tmpclustersum[mask]).sum() # in the ref: log-likelihood function

    return new_belong, loglike


def print_cluster(counts, mus, sigmas, it=0, loglike=0):
    K = mus.shape[0]
    print('Iter {:d}, loglike = {:.1f}'.format(it, loglike))
    for i in range(K):
        print('cluster {:} ({:.0f}): (mu, sig) = ({:.2e}, {:.2e})'.format(i, counts[i], mus[i].mean(), sigmas[i].mean()))
    print(' ')



def main():

    print(' ')

    parser = _buildArgsParser()
    args = parser.parse_args()


    # stoping criteria
    LOGLIKE_TH = args.th
    MAX_IT = args.maxit


    data_fnames = args.data
    mask_fname = args.mask
    prior_fnames = args.prior

    output_belong_fname = args.outprob
    output_rgb_fname = args.outrgb
    output_log_fname = args.outlog
    output_classes_fname = args.outclass


    # load data, mono-modal for now
    data_imgs = [nib.load(data_fname) for data_fname in data_fnames]
    data_raws = [data_img.get_fdata() for data_img in data_imgs]
    data_raw = np.concatenate([p[..., None] for p in data_raws], axis=-1)

    # load brain mask in subject space
    mask_img = nib.load(mask_fname)
    mask_raw = mask_img.get_fdata().astype(bool)
    print('initial mask size = {:}'.format(mask_raw.sum()))
    missing_data_mask = np.any(data_raw==0, axis=-1)
    mask_raw = np.logical_and(mask_raw, np.logical_not(missing_data_mask))
    print('final mask size = {:}'.format(mask_raw.sum()))

    # data sanitizer
    for i in range(data_raw.shape[-1]):
        qmin, qmax = np.quantile(data_raw[mask_raw][:,i], [0.001, 0.999])
        data_raw[..., i] = np.clip(data_raw[..., i], max(qmin, 0), qmax)


    # load prior
    # these are tissue probability maps from an atlas registered in subject space
    prior_imgs = [nib.load(prior_fname) for prior_fname in prior_fnames]
    prior_raws = [prior_img.get_fdata() for prior_img in prior_imgs] #this is 4D
    prior_raw = np.concatenate([p[..., None] for p in prior_raws], axis=-1)

    # number of class
    K = prior_raw.shape[-1]
    with np.errstate(divide='ignore', invalid='ignore'):
        # can't have priors worth zero
        prior_raw += (1e-4)*np.ones(K)
        prior_raw = prior_raw / prior_raw.sum(axis=-1)[...,None] # renormalized, cant trust registration interpolation
    prior_raw[np.isnan(prior_raw)] = 0


    # define data bounding box from mask
    Xidx, Yidx, Zidx = np.nonzero(mask_raw)
    bbox = [(Xidx.min(), Xidx.max()), (Yidx.min(), Yidx.max()), (Zidx.min(), Zidx.max())]
    print('Bounding box = [({:}  {:}), ({:}  {:}), ({:}  {:})]'.format(bbox[0][0], bbox[0][1], bbox[1][0], bbox[1][1], bbox[2][0], bbox[2][1]))

    # print(mask_raw.sum())
    # print(mask_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1].sum())

    # apply bounding box
    mask = mask_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1]
    # init belonging probabilities
    belong = prior_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] * mask[..., None]
    data = data_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] * mask[..., None]
    prior = prior_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] * mask[..., None]


    # fill-in where mask==1 and prior=0
    missing_prior_idx = np.where(np.logical_and(prior.sum(axis=-1)<0.99, mask))
    prior[missing_prior_idx] = np.ones(K)/K



    start_time = time()

    log = []


    # update cluster from belong map
    counts, mus, sigmas = _cluster_param(data, belong)

    # update belonging probs from cluster param
    belong, loglike = _assign_probability(data, prior, counts, mus, sigmas, mask)
    if VERBOSE:
        print_cluster(counts, mus, sigmas, 0, loglike)
    log.append(loglike)


    for current_iter in range(1, MAX_IT):
        previous_loglike = loglike

        # update cluster from belong map
        counts, mus, sigmas = _cluster_param(data, belong)

        # update belonging probs from cluster param
        belong, loglike = _assign_probability(data, prior, counts, mus, sigmas, mask)
        if VERBOSE:
            print_cluster(counts, mus, sigmas, current_iter, loglike)
        log.append(loglike)

        # check if loglike change enough
        if (loglike - previous_loglike < LOGLIKE_TH):
            break


    end_time = time()
    elapsed_time = end_time - start_time

    print('{:} iterations took {:.1f} secs'.format(current_iter, elapsed_time))

    mask_unbbox = mask_raw

    belong_unbbox = np.zeros(mask_raw.shape+(K,))
    belong_unbbox[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] = belong



    if output_belong_fname is not None:
        nib.Nifti1Image(belong_unbbox.astype(np.float32), data_imgs[0].affine).to_filename(output_belong_fname)

    if output_rgb_fname is not None:
        if K <= 3:
            idx = np.argmax(belong_unbbox, axis=3) + 1
            idx[~mask_unbbox] = 0

            rgb = np.zeros(idx.shape+(3,))
            rgb[idx==1] = [1,0,0]
            rgb[idx==2] = [0,1,0]
            rgb[idx==3] = [0,0,1]

            nib.Nifti1Image(rgb.astype(np.float32), data_imgs[0].affine).to_filename(output_rgb_fname)

        else:
            print('Cannot output RBG map for segmentation with more than 3 classes, skipping')

    if output_log_fname is not None:
        np.savetxt(output_log_fname, log)

    if output_classes_fname is not None:
        # final classes
        counts, mus, sigmas = _cluster_param(data, belong)
        # class_params = {'means':mus, 'sigmas':sigmas, 'priors':[name.split('/')[-1] for name in prior_fnames]}

        # with open(output_classes_fname, 'wb') as f:
        #     pickle.dump(class_params, f)

        np.save(output_classes_fname+'_means.npy', mus)
        np.save(output_classes_fname+'_sigmas.npy', sigmas)
                
    print(' ')


if __name__ == "__main__":
    main()




