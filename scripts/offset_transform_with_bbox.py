#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import numpy as np
from numpy.lib.index_tricks import r_ as row
import pickle as pkl
import nibabel as nib


DESCRIPTION = 'Correct transform matrix with bounding box info'
def buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument('--mat', action='store', type=str,
                            help='Path to transform matrix (txt).')
    p.add_argument('--ref', action='store', type=str,
                            help='Path to uncropped ref image (nifti).')
    p.add_argument('--bbox', action='store', type=str,
                            help='Path to bounding box (pkl).')
    p.add_argument('--output', action='store', type=str,
                            help='Path Modified transform matrix (txt).')

    return p



# copied from Scilpy
def world_to_voxel(coord, affine):
    """Takes a n dimensionnal world coordinate and returns its 3 first
    coordinates transformed to voxel space from a given voxel to world affine
    transformation."""

    normalized_coord = row[coord[0:3], 1.0].astype(float)
    iaffine = np.linalg.inv(affine)
    vox_coord = np.dot(iaffine, normalized_coord)
    vox_coord = np.round(vox_coord).astype(int)
    return vox_coord[0:3]



class WorldBoundingBox(object):
    def __init__(self, minimums, maximums, voxel_size):
        self.minimums = minimums
        self.maximums = maximums
        self.voxel_size = voxel_size




def main():
    # Load parser to read data from command line input
    parser = buildArgsParser()
    args = parser.parse_args()

    img = nib.load(args.ref)
    affine = img.affine
    voxel_size = img.header.get_zooms()[0:3]

    with open(args.bbox, 'rb') as f:
        bbox_data = pkl.load(f)

    vox_bb_mins = world_to_voxel(bbox_data.minimums, affine)
    vox_bb_maxs = world_to_voxel(bbox_data.maximums, affine)


    offset_x = voxel_size[0]*(vox_bb_mins[0])
    offset_y = voxel_size[1]*(vox_bb_mins[1])
    offset_z = voxel_size[2]*(vox_bb_mins[2])


    old_mat = np.genfromtxt(args.mat)

    new_mat = old_mat.copy()
    new_mat[0, 3] -= offset_x
    new_mat[1, 3] -= offset_y
    new_mat[2, 3] -= offset_z

    np.savetxt(args.output, new_mat)

if __name__ == '__main__':
    main()







