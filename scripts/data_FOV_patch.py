#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse

import nibabel as nib
import numpy as np
import pylab as pl
from skimage import measure
from scipy.ndimage import binary_dilation, binary_erosion
from scipy.optimize import minimize, brute


DESCRIPTION = """
Correct image FOV wrap by padding image and cut/paste image part using manual masks.
In the case where structure overlapped, they are partially duplicated in the process
"""

EPILOG = """
Michael Paquette, MPI CBS, 2023.
Modified in 08/2023 to add option for overlap intensities.
Modified in 08/2023 to add the option of strict size.
"""


DEFAULT_EXTRA_PAD = 10



class CustomFormatter(argparse.ArgumentDefaultsHelpFormatter, argparse.RawTextHelpFormatter):
    pass


def buildArgsParser():

    p = argparse.ArgumentParser(description=DESCRIPTION,
                                epilog=EPILOG,
                                formatter_class=CustomFormatter)

    p.add_argument('--data', type=str,
                   help='Path of the input data.')

    p.add_argument('--mask', type=str, nargs='*', default=[],
                   help='Path of the FOV-wrapped structure mask (zero or more).')

    p.add_argument('--maskover', type=str, nargs='*', default=[],
                   help='Path of the structure-overlapping FOV-wrapped structure mask (zero or more).')

    p.add_argument('--out', type=str,
                   help='Path for unwrapped image')

    p.add_argument('--outmask', type=str, default=None,
                   help='Path for unwrapped mask of image')

    p.add_argument('--outpad', type=str, default=None,
                   help='Path for the final padding used')

    p.add_argument('--overmode', type=str, default='copy',
                   help='How the algorithm handles overlaps. (copy, half, smartmean or smartTV)')

    p.add_argument('--masksmart', type=str, default=None,
                   help='Path of the Image mask for smart overlap.')

    p.add_argument('--pad', type=int, nargs='*', default=[],
                   help='Desired final padding size (x-, x+, y-, y+, z-, z+). \
                   If given only a single number, will act as extra padding instead. \
                   If left empty, defaults to [{:}]'.format(DEFAULT_EXTRA_PAD))  


    return p





def main():
    parser = buildArgsParser()
    args = parser.parse_args()

    if args.data is None:
        print('Need input data fname')
        return None

    if args.out is None:
        print('Need output fname')
        return None

    if len(args.pad) not in [0, 1, 6]:
        print('invalid pad values')
        return None


    # sanity checks for overlap handeling modes
    overmode = args.overmode
    if (args.overmode == 'smartmean') and (args.masksmart is None):
        print('Cannot use "smart" overlap mode without a masksmart, defaulting to "copy" method')
        overmode = 'copy'
    if (args.overmode == 'smartTV') and (args.masksmart is None):
        print('Cannot use "smart" overlap mode without a masksmart, defaulting to "copy" method')
        overmode = 'copy'
    if args.overmode not in ['copy', 'half', 'smartmean', 'smartTV']:
        print('Invalid overlap mode, defaulting to "copy" method')
        overmode = 'copy'


    print('Loading data')
    data_img = nib.load(args.data)
    data = data_img.get_fdata()


    # load and multiply all the mask
    print('Loading Mask')
    mask = np.zeros(data.shape[:3], dtype=bool)
    mask_data = [nib.load(fname).get_fdata().astype(bool) for fname in args.mask]
    for tmp in mask_data:
        mask = np.logical_or(mask, tmp)
    del mask_data


    # split the concatenated FOV mask into connected components
    labels, num = measure.label(mask, background=0, connectivity=None, return_num=True)
    masks = [labels==i+1 for i in range(num)]
    # count_per_id = [np.sum(labels==i+1) for i in range(num)]
    count_per_id = [np.sum(m) for m in masks]
    for i in range(len(count_per_id)):
        print('Found continous mask piece of size {:} vox'.format(count_per_id[i]))


    X_max, Y_max, Z_max = data.shape[:3] # only care about first 3
    # find which edge each mask is touching
    # 0: x=0
    # 1: x=X_max-1
    # 2: y=0
    # 3: y=Y_max-1
    # 4: z=0
    # 5: z=Z_max-1


    # TODO what if it touches more than 1 edge?
    masks_edge = []
    for m in masks:
        Xid, Yid, Zid = np.where(m)
        mask_type = -1
        if Xid.min() == 0:
            print('Found Wrap in low X')
            mask_type = 0
        elif Xid.max() == X_max-1:
            print('Found Wrap in high X')
            mask_type = 1
        elif Yid.min() == 0:
            print('Found Wrap in low Y')
            mask_type = 2
        elif Yid.max() == Y_max-1:
            print('Found Wrap in high Y')
            mask_type = 3
        elif Zid.min() == 0:
            print('Found Wrap in low Z')
            mask_type = 4
        elif Zid.max() == Z_max-1:
            print('Found Wrap in high Z')
            mask_type = 5
        if mask_type == -1:
            print('Mask piece ({:}) not atributed to an edge'.format(m.sum()))
            print(Xid.min(), Xid.max())
            print(Yid.min(), Yid.max())
            print(Zid.min(), Zid.max())
        masks_edge.append(mask_type)
    masks_edge = np.array(masks_edge, dtype=int)









    # load and multiply all the overlap mask
    print('Loading Mask')
    mask_overlap = np.zeros(data.shape[:3], dtype=bool)
    mask_data = [nib.load(fname).get_fdata().astype(bool) for fname in args.maskover]
    for tmp in mask_data:
        mask_overlap = np.logical_or(mask_overlap, tmp)
    del mask_data

    # clean the overlap mask by removing any voxel not included in the regular mask
    # i.e. cannot be an overlapping-pixel if you are not even considered a wrapped-around pixel
    mask_overlap = np.logical_and(mask_overlap, mask)
    print('We have {:} overlapping voxels'.format(mask_overlap.sum()))
    if mask_overlap.sum() > 0:
        print('Using "{:}" method for overlap harmonization'.format(overmode))


    # # assign each overlapping voxel to the proper sub mask id (in masks)
    # mask_overlap_id = -1*np.ones(mask_overlap.shape, np.int32)
    # for i, m in enumerate(masks):
    #     mask_overlap_id[np.logical_and(mask_overlap, m)] = i












    # find minimum padding for each edge
    # ex: find the thickest mask touching X=0, that width is the minimum pading for X=X_max
    # ordering X_lo, X_hi, Y_lo, Y_hi, Z_lo, Z_hi
    minimal_padding = np.zeros(6, dtype=int)

    # X_lo padding: look at mask touching X_hi
    if np.any(masks_edge==1):
        pad = 0
        for i, m in enumerate(masks):
            if masks_edge[i]==1:
                Xid, Yid, Zid = np.where(m)
                pad = max(pad, X_max - Xid.min()) # update pad if this mask is thicker
        minimal_padding[0] = pad
    # X_hi padding: look at mask touching X_lo
    if np.any(masks_edge==0):
        pad = 0
        for i, m in enumerate(masks):
            if masks_edge[i]==0:
                Xid, Yid, Zid = np.where(m)
                pad = max(pad, Xid.max()+1) # update pad if this mask is thicker
        minimal_padding[1] = pad
    # Y_lo padding: look at mask touching Y_hi
    if np.any(masks_edge==3):
        pad = 0
        for i, m in enumerate(masks):
            if masks_edge[i]==3:
                Xid, Yid, Zid = np.where(m)
                pad = max(pad, Y_max - Yid.min()) # update pad if this mask is thicker
        minimal_padding[2] = pad
    # Y_hi padding: look at mask touching Y_lo
    if np.any(masks_edge==2):
        pad = 0
        for i, m in enumerate(masks):
            if masks_edge[i]==2:
                Xid, Yid, Zid = np.where(m)
                pad = max(pad, Yid.max()+1) # update pad if this mask is thicker
        minimal_padding[3] = pad
    # Z_lo padding: look at mask touching Z_hi
    if np.any(masks_edge==5):
        pad = 0
        for i, m in enumerate(masks):
            if masks_edge[i]==5:
                Xid, Yid, Zid = np.where(m)
                pad = max(pad, Z_max - Zid.min()) # update pad if this mask is thicker
        minimal_padding[4] = pad
    # Z_hi padding: look at mask touching Z_lo
    if np.any(masks_edge==4):
        pad = 0
        for i, m in enumerate(masks):
            if masks_edge[i]==4:
                Xid, Yid, Zid = np.where(m)
                pad = max(pad, Zid.max()+1) # update pad if this mask is thicker
        minimal_padding[5] = pad


    print('minimal padding: ', minimal_padding)


    print('Unwrapping data')
    # In a nutshell, we glue together 7 FOV in a 3D-cross shaped
    # the central FOV as all the data, the other 6 the relevant par of the wraped stuff
    # this gluing process naturally put the wrapped around part where they belong
    # we then delete the wrap around data in the main FOV only
    # except if it was also overlapping
    # finally we crop all the remaining data
    #
    # laziest solution
    if data.ndim == 3:
        data = data[..., None] # make it 4D
    data_tmp = np.zeros((3*X_max, 3*Y_max, 3*Z_max, data.shape[3]), np.float32) # this is now always 4D
    mask_tmp = np.zeros((3*X_max, 3*Y_max, 3*Z_max), bool)

    # main block, copy all apart from inside combined FOV wrap mask
    mask_tmp[X_max:2*X_max, Y_max:2*Y_max, Z_max:2*Z_max] = 1
    data_tmp[X_max:2*X_max, Y_max:2*Y_max, Z_max:2*Z_max] = data
    data_tmp[X_max:2*X_max, Y_max:2*Y_max, Z_max:2*Z_max][mask] = 0
    # for the 6 secondary block, loop over mask, group together same type and paste
    for mask_type in range(6):
        if np.any(masks_edge==mask_type):
            new_mask = np.zeros((X_max, Y_max, Z_max), bool)
            for i, m in enumerate(masks):
                if masks_edge[i]==mask_type:
                    new_mask = np.logical_or(new_mask, m)
            # paste properly or each mask type
            if mask_type == 0: # x_lo mask, paste at x_hi
                mask_tmp[2*X_max:3*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = new_mask
                data_tmp[2*X_max:3*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max][new_mask] = data[new_mask]
            elif mask_type == 1: # x_hi mask, paste at x_lo
                mask_tmp[0*X_max:1*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = new_mask
                data_tmp[0*X_max:1*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max][new_mask] = data[new_mask]
            elif mask_type == 2: # y_lo mask, paste at y_hi
                mask_tmp[1*X_max:2*X_max, 2*Y_max:3*Y_max, 1*Z_max:2*Z_max] = new_mask
                data_tmp[1*X_max:2*X_max, 2*Y_max:3*Y_max, 1*Z_max:2*Z_max][new_mask] = data[new_mask]
            elif mask_type == 3: # y_hi mask, paste at y_lo
                mask_tmp[1*X_max:2*X_max, 0*Y_max:1*Y_max, 1*Z_max:2*Z_max] = new_mask
                data_tmp[1*X_max:2*X_max, 0*Y_max:1*Y_max, 1*Z_max:2*Z_max][new_mask] = data[new_mask]
            elif mask_type == 4: # z_lo mask, paste at z_hi
                mask_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 2*Z_max:3*Z_max] = new_mask
                data_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 2*Z_max:3*Z_max][new_mask] = data[new_mask]
            elif mask_type == 5: # z_hi mask, paste at z_lo
                mask_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 0*Z_max:1*Z_max] = new_mask
                data_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 0*Z_max:1*Z_max][new_mask] = data[new_mask]



    mask_save = mask_tmp.copy() # now includes full central block and all secondary poky bits
    mask_save[X_max:2*X_max, Y_max:2*Y_max, Z_max:2*Z_max][mask] = 0 # carve out from main block the poky bits

    # past back the overlapping stuff that was cut out
    data_tmp[X_max:2*X_max, Y_max:2*Y_max, Z_max:2*Z_max][mask_overlap] = data[mask_overlap]
    mask_save[X_max:2*X_max, Y_max:2*Y_max, Z_max:2*Z_max][mask_overlap] = 1 # paste back in main block the duplicated part of poky





    if overmode == 'copy':
        # do nothing
        # the out-of-FOV overlap data was part of the main out-of-FOV mask and was pasted outside
        # and the last few lines corrected the overlap data inside the FOV
        pass
    else:
        # make a overlap mask
        overlap_tmp = np.zeros((3*X_max, 3*Y_max, 3*Z_max), bool)
        overlap_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_overlap
        overlap_tmp[2*X_max:3*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_overlap
        overlap_tmp[0*X_max:1*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_overlap
        overlap_tmp[1*X_max:2*X_max, 2*Y_max:3*Y_max, 1*Z_max:2*Z_max] = mask_overlap
        overlap_tmp[1*X_max:2*X_max, 0*Y_max:1*Y_max, 1*Z_max:2*Z_max] = mask_overlap
        overlap_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 2*Z_max:3*Z_max] = mask_overlap
        overlap_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 0*Z_max:1*Z_max] = mask_overlap
        overlap_tmp = np.logical_and(overlap_tmp, mask_save)
        if overmode == 'half':
            # reduce intensity in the overlap_tmp mask
            data_tmp[overlap_tmp] /= 2.
        elif overmode == 'smartmean':
            # define sphere filter for dilatation
            radius = 5 # voxel
            k = int(2*np.ceil(radius)+1) # filter size
            c = k//2 # center of filter
            X, Y, Z = np.meshgrid(np.arange(k), np.arange(k), np.arange(k))
            dist = np.sqrt((X-c)**2 + (Y-c)**2 + (Z-c)**2)
            structure_element = dist <= radius
            # make a mask of where we have data
            mask_smart = nib.load(args.masksmart).get_fdata().astype(bool)
            smart_tmp = np.zeros((3*X_max, 3*Y_max, 3*Z_max), bool)
            smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[2*X_max:3*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[0*X_max:1*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 2*Y_max:3*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 0*Y_max:1*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 2*Z_max:3*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 0*Z_max:1*Z_max] = mask_smart
            smart_tmp = np.logical_and(smart_tmp, mask_save)
            # make a list of connected component in overlap_tmp
            labels_overlap, num_overlap = measure.label(overlap_tmp, background=0, connectivity=3, return_num=True)
            masks_overlap = [labels_overlap==i+1 for i in range(num_overlap)]
            count_per_id_overlap = [np.sum(m) for m in masks_overlap]
            for i in range(len(count_per_id_overlap)):
                print('Found continous overlap piece of size {:} vox'.format(count_per_id_overlap[i]))
                # overlap_neighbor_mask_raw = binary_dilation(masks_overlap[i], structure_element, 1)
                # attempt at fast dilation with bounding box
                Xidx, Yidx, Zidx = np.nonzero(masks_overlap[i])
                bbox = [(Xidx.min()-(radius+2), Xidx.max()+(radius+2)), (Yidx.min()-(radius+2), Yidx.max()+(radius+2)), (Zidx.min()-(radius+2), Zidx.max()+(radius+2))]
                overlap_neighbor_mask_raw = np.zeros(masks_overlap[i].shape, dtype=bool)
                overlap_neighbor_mask_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] = binary_dilation(masks_overlap[i][bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1], structure_element, 1)
                # remove non-data voxel
                # remove any overlap voxel
                overlap_neighbor_mask = np.logical_and(np.logical_and(overlap_neighbor_mask_raw, smart_tmp), np.logical_not(overlap_tmp))
                # import pylab as pl
                # pl.figure()
                # pl.subplot(1,2,1);
                # pl.hist(data_tmp[masks_overlap[i]], 50)
                # pl.title('data in current overlap patch')
                # pl.subplot(1,2,2)
                # pl.hist(data_tmp[overlap_neighbor_mask], 50)
                # pl.title('data around current overlap patch')
                # pl.show()
                #
                # compute the means
                mean_in_patch = data_tmp[masks_overlap[i]].mean()
                mean_around_patch = data_tmp[overlap_neighbor_mask].mean()
                # correct accordingly to match them
                data_tmp[masks_overlap[i]] *= mean_around_patch/mean_in_patch
        elif overmode == 'smartTV':
            # define sphere filter for dilatation and erosion
            radius = 2 # voxel
            k = int(2*np.ceil(radius)+1) # filter size
            c = k//2 # center of filter
            X, Y, Z = np.meshgrid(np.arange(k), np.arange(k), np.arange(k))
            dist = np.sqrt((X-c)**2 + (Y-c)**2 + (Z-c)**2)
            structure_element = dist <= radius
            # make a mask of where we have data
            mask_smart = nib.load(args.masksmart).get_fdata().astype(bool)
            smart_tmp = np.zeros((3*X_max, 3*Y_max, 3*Z_max), bool)
            smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[2*X_max:3*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[0*X_max:1*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 2*Y_max:3*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 0*Y_max:1*Y_max, 1*Z_max:2*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 2*Z_max:3*Z_max] = mask_smart
            smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 0*Z_max:1*Z_max] = mask_smart
            smart_tmp = np.logical_and(smart_tmp, mask_save)
            # make a list of connected component in overlap_tmp
            labels_overlap, num_overlap = measure.label(overlap_tmp, background=0, connectivity=3, return_num=True)
            masks_overlap = [labels_overlap==i+1 for i in range(num_overlap)]
            count_per_id_overlap = [np.sum(m) for m in masks_overlap]
            for i in range(len(count_per_id_overlap)):
                print('Found continous overlap piece of size {:} vox'.format(count_per_id_overlap[i]))
                # overlap_neighbor_mask_raw = binary_dilation(masks_overlap[i], structure_element, 1)
                # attempt at fast dilation with bounding box
                Xidx, Yidx, Zidx = np.nonzero(masks_overlap[i])
                bbox = [(Xidx.min()-(radius+2), Xidx.max()+(radius+2)), (Yidx.min()-(radius+2), Yidx.max()+(radius+2)), (Zidx.min()-(radius+2), Zidx.max()+(radius+2))]
                overlap_neighbor_mask_raw = np.zeros(masks_overlap[i].shape, dtype=bool)
                overlap_neighbor_mask_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] = binary_dilation(masks_overlap[i][bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1], structure_element, 1)
                # remove non-data voxel
                # remove any overlap voxel
                overlap_neighbor_mask = np.logical_and(np.logical_and(overlap_neighbor_mask_raw, smart_tmp), np.logical_not(overlap_tmp))
                # make a mask of edge of patch by taking mask minus eroded_mask
                overlap_edge_mask = np.zeros(masks_overlap[i].shape, dtype=bool)
                overlap_edge_mask[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] = np.logical_and(masks_overlap[i][bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1], np.logical_not(binary_erosion(masks_overlap[i][bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1], structure_element, 1)))
                # uniform intensity scaling to minimize TV
                # step 1: joint mask
                joint_mask = np.logical_or(overlap_edge_mask, overlap_neighbor_mask)
                # step 2: bbox
                Xidx, Yidx, Zidx = np.nonzero(joint_mask)
                bbox = [(Xidx.min(), Xidx.max()), (Yidx.min(), Yidx.max()), (Zidx.min(), Zidx.max())]
                # setup TV function
                image_data_raw = data_tmp[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1]
                image_data_mask = np.logical_not(joint_mask[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1])
                image_mod_mask = masks_overlap[i][bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1]
                def TV(k=1.0):
                    # compute anisotropic TV in image where mask_overlap[i] pixels are modulated by k
                    # make patch as masked array
                    image = np.ma.array(image_data_raw.copy(), mask=image_data_mask)
                    # modulate
                    image[image_mod_mask] *= k
                    # compute Gx, Gy, Gz
                    image_gx = image[:-1, :, :] - image[1:, :, :]
                    image_gy = image[:, :-1, :] - image[:, 1:, :]
                    image_gz = image[:, :, :-1] - image[:, :, 1:]
                    # compute anisotropic TV
                    totvar = np.abs(image_gx).sum() + np.abs(image_gy).sum() + np.abs(image_gz).sum()
                    return totvar
                # minimize TV for patch
                bounds = [(0, 10)]
                x0 = brute(TV, bounds,  Ns=1000, workers=1)
                res = minimize(TV, x0=x0, bounds=bounds, tol=1e-16)
                # apply modulation to data
                data_tmp[masks_overlap[i]] *= res.x[0]

            # OLD smartTV where we minimized over full mask instead of just a rim at the intersection of patch and neighboor
            # # define sphere filter for dilatation
            # radius = 2 # voxel
            # k = int(2*np.ceil(radius)+1) # filter size
            # c = k//2 # center of filter
            # X, Y, Z = np.meshgrid(np.arange(k), np.arange(k), np.arange(k))
            # dist = np.sqrt((X-c)**2 + (Y-c)**2 + (Z-c)**2)
            # structure_element = dist <= radius
            # # make a mask of where we have data
            # mask_smart = nib.load(args.masksmart).get_fdata().astype(bool)
            # smart_tmp = np.zeros((3*X_max, 3*Y_max, 3*Z_max), bool)
            # smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            # smart_tmp[2*X_max:3*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            # smart_tmp[0*X_max:1*X_max, 1*Y_max:2*Y_max, 1*Z_max:2*Z_max] = mask_smart
            # smart_tmp[1*X_max:2*X_max, 2*Y_max:3*Y_max, 1*Z_max:2*Z_max] = mask_smart
            # smart_tmp[1*X_max:2*X_max, 0*Y_max:1*Y_max, 1*Z_max:2*Z_max] = mask_smart
            # smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 2*Z_max:3*Z_max] = mask_smart
            # smart_tmp[1*X_max:2*X_max, 1*Y_max:2*Y_max, 0*Z_max:1*Z_max] = mask_smart
            # smart_tmp = np.logical_and(smart_tmp, mask_save)
            # # make a list of connected component in overlap_tmp
            # labels_overlap, num_overlap = measure.label(overlap_tmp, background=0, connectivity=3, return_num=True)
            # masks_overlap = [labels_overlap==i+1 for i in range(num_overlap)]
            # count_per_id_overlap = [np.sum(m) for m in masks_overlap]
            # for i in range(len(count_per_id_overlap)):
            #     print('Found continous overlap piece of size {:} vox'.format(count_per_id_overlap[i]))
            #     # overlap_neighbor_mask_raw = binary_dilation(masks_overlap[i], structure_element, 1)
            #     # attempt at fast dilation with bounding box
            #     Xidx, Yidx, Zidx = np.nonzero(masks_overlap[i])
            #     bbox = [(Xidx.min()-(radius+2), Xidx.max()+(radius+2)), (Yidx.min()-(radius+2), Yidx.max()+(radius+2)), (Zidx.min()-(radius+2), Zidx.max()+(radius+2))]
            #     overlap_neighbor_mask_raw = np.zeros(masks_overlap[i].shape, dtype=bool)
            #     overlap_neighbor_mask_raw[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] = binary_dilation(masks_overlap[i][bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1], structure_element, 1)
            #     # remove non-data voxel
            #     # remove any overlap voxel
            #     overlap_neighbor_mask = np.logical_and(np.logical_and(overlap_neighbor_mask_raw, smart_tmp), np.logical_not(overlap_tmp))
            #     # uniform intensity scaling to minimize TV
            #     # step 1: joint mask
            #     joint_mask = np.logical_or(masks_overlap[i], overlap_neighbor_mask)
            #     # step 2: bbox
            #     Xidx, Yidx, Zidx = np.nonzero(joint_mask)
            #     bbox = [(Xidx.min(), Xidx.max()), (Yidx.min(), Yidx.max()), (Zidx.min(), Zidx.max())]
            #     # setup TV function
            #     image_data_raw = data_tmp[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1]
            #     image_data_mask = np.logical_not(joint_mask[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1])
            #     image_mod_mask = masks_overlap[i][bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1]
            #     def TV(k=1.0):
            #         # compute anisotropic TV in image where mask_overlap[i] pixels are modulated by k
            #         # make patch as masked array
            #         image = np.ma.array(image_data_raw.copy(), mask=image_data_mask)
            #         # modulate
            #         image[image_mod_mask] *= k
            #         # compute Gx, Gy, Gz
            #         image_gx = image[:-1, :, :] - image[1:, :, :]
            #         image_gy = image[:, :-1, :] - image[:, 1:, :]
            #         image_gz = image[:, :, :-1] - image[:, :, 1:]
            #         # compute anisotropic TV
            #         totvar = np.abs(image_gx).sum() + np.abs(image_gy).sum() + np.abs(image_gz).sum()
            #         return totvar
            #     # minimize TV for patch
            #     bounds = [(0, 10)]
            #     x0 = brute(TV, bounds,  Ns=1000, workers=1)
            #     res = minimize(TV, x0=x0, bounds=bounds, tol=1e-16)
            #     # apply modulation to data
            #     data_tmp[masks_overlap[i]] *= res.x[0]




    Xidx, Yidx, Zidx = np.nonzero(mask_tmp)
    bbox = [(Xidx.min(), Xidx.max()), (Yidx.min(), Yidx.max()), (Zidx.min(), Zidx.max())]
    print('Bounding box = [({:}  {:}), ({:}  {:}), ({:}  {:})]'.format(bbox[0][0], bbox[0][1], bbox[1][0], bbox[1][1], bbox[2][0], bbox[2][1]))


    data_crop = data_tmp[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] # still 4D
    mask_crop = mask_save[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1]



    # define data bounding box from mask
    Xidx, Yidx, Zidx = np.nonzero(mask_tmp)
    bbox = [(Xidx.min(), Xidx.max()), (Yidx.min(), Yidx.max()), (Zidx.min(), Zidx.max())]
    print('Bounding box = [({:}  {:}), ({:}  {:}), ({:}  {:})]'.format(bbox[0][0], bbox[0][1], bbox[1][0], bbox[1][1], bbox[2][0], bbox[2][1]))


    data_crop = data_tmp[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1] # still 4D
    mask_crop = mask_save[bbox[0][0]:bbox[0][1]+1, bbox[1][0]:bbox[1][1]+1, bbox[2][0]:bbox[2][1]+1]


    # pad by (PADDINGS. PADDING) or (PADDINGS. PADDING+1) (to make in even)
    if len(args.pad) != 6:
        if len(args.pad) == 0:
            PADDING = DEFAULT_EXTRA_PAD
        elif len(args.pad) == 1:
            PADDING = args.pad[0]

        # PADDINGS = [(PADDING, PADDING+(x%2)) for x in data_crop.shape[:3]] # this enforces even
        PADDINGS = [(PADDING, PADDING+((4-1) -((x+2*PADDING-1)%4))) for x in data_crop.shape[:3]] # this enforces mult 4 and doesnt assumes 2*PADDING is div 4
    else:
        # PADDINGS is whatever we want (the pad argument) minus what was already done by the unwrap
        PADDINGS = [(args.pad[i] - minimal_padding[i], args.pad[i+1] - minimal_padding[i+1]) for i in [0, 2, 4]]
        if np.any(np.array(PADDINGS) < 0):
            print('Incompatible unwrap and final padding')
            print(PADDINGS)
            return None

    print('Additional padding: ', PADDINGS)

    mask_crop_pad = np.pad(mask_crop, PADDINGS)
    PADDINGS.append((0, 0)) # null padding for 4th dim
    data_crop_pad = np.pad(data_crop, PADDINGS) # still 4D


    if args.outpad is not None:
        final_pad = [PADDINGS[0][0] + minimal_padding[0], \
                     PADDINGS[0][1] + minimal_padding[1], \
                     PADDINGS[1][0] + minimal_padding[2], \
                     PADDINGS[1][1] + minimal_padding[3], \
                     PADDINGS[2][0] + minimal_padding[4], \
                     PADDINGS[2][1] + minimal_padding[5]]
        with open(args.outpad, 'w') as f:
            f.write(' '.join([str(n) for n in final_pad]))


    print('Adding translation to affine')
    affine = data_img.affine
    Rot_q_to_s = data_img.header.get_sform()[:3,:3]
    translation_q = np.array([-(PADDINGS[0][0]+minimal_padding[0]), -(PADDINGS[1][0]+minimal_padding[2]), -(PADDINGS[2][0]+minimal_padding[4])]) # in voxel # for raw_nifti
    affine[:3, 3] += Rot_q_to_s.dot(translation_q)



    print('Final dims: ', data_crop_pad.squeeze().shape)


    nib.Nifti1Image(data_crop_pad.squeeze(), affine).to_filename(args.out) # squeeze out fake 4th dim for 3D arrays
    if args.outmask is not None:
        nib.Nifti1Image(mask_crop_pad.astype(np.int32), affine).to_filename(args.outmask)


if __name__ == "__main__":
    main()
