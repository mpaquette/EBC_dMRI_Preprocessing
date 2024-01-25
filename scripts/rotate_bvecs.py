import numpy as np

def main(bvec_path, mat_path, output_path):
    # load un-rotated bvecs
    bvec = np.genfromtxt(bvec_path)
    # make sure bvec is shape 3xN
    if bvec.shape[1] == 3:
        bvec = bvec.T
    # take only the rotation part of the transform
    flirt_mat = np.genfromtxt(mat_path)
    U, s, V = np.linalg.svd(flirt_mat[:3, :3])
    mat = np.dot(U, V)
    # rotate bvec
    bvec_rot = mat.dot(bvec)
    # save
    np.savetxt(output_path, bvec_rot)


if __name__ == "__main__":
    import sys
    main(*sys.argv[1:])
