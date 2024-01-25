#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import numpy as np


DESCRIPTION =   'Approximate a dof=6 flirt transform from a dof=9 flirt transform'

def buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument('input', action='store', type=str,
                            help='Path of the input dof=9 flirt transform')

    p.add_argument('output', action='store', type=str,
                            help='Path of the output')

    return p


def main():
    # Load parser to read data from command line input
    parser = buildArgsParser()
    args = parser.parse_args()

    mat = np.genfromtxt(args.input)
    new_mat = mat.copy() # keep the same translations
    U, s, V = np.linalg.svd(mat[:3, :3])
    print(s)
    new_mat[:3, :3] = np.dot(U, V) # removes the scaling part
    np.savetxt(args.output, new_mat)


if __name__ == '__main__':
    main()
