#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import numpy as np
# from __future__ import division, print_function


desciption = """
Print scan custom name from Bruker acqp file
"""

# TODO:
# check that the pattern finding didnt fail


def _build_args_parser():
    p = argparse.ArgumentParser(description=desciption, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument('acqp', metavar='acqp', help='Path of the acqp file.')
    return p

def main():
    parser = _build_args_parser()
    args = parser.parse_args()


    # read file
    f= open(args.acqp, 'r')
    l = f.readlines()
    f.close()

    # find the line
    pattern = "##$ACQ_scan_name="
    idx = np.where([ll[:len(pattern)] == pattern for ll in l])[0][0]
    # print the next one
    print(l[idx+1])


    # pattern = "##$RG="
    # idx = np.where([ll[:len(pattern)] == pattern for ll in l])[0][0]
    # # read value
    # RG = float(l[idx][len(pattern):].strip())
    # print('RG = {}'.format(RG))


    # # find the line
    # pattern = "##$ACQ_CalibratedRG="
    # idx = np.where([ll[:len(pattern)] == pattern for ll in l])[0][0]
    # # print the next one
    # print('CalibratedRG = {}'.format(l[idx+1]))




if __name__ == "__main__":
    main()
