import numpy as np
import nibabel as nib
import pylab as pl


def main(nums):
    imgs = [nib.load('nifti_raw/DtiEpiX{:}P1.nii.gz'.format(n)) for n in nums]
    datas = [img.get_fdata() for img in imgs]
    spatial_means = [data.mean(axis=(0,1,2)) for data in datas]
    Ns = [data.shape[3] for data in datas]
    means = np.concatenate(spatial_means, axis=0)

    pl.figure()
    pl.plot(means, linewidth=3, color='black')
    ii = 0
    pl.axvline(ii-0.5, color='red', linewidth=2, linestyle='dashed', alpha=0.5)
    for n in Ns:
        ii += n
        pl.axvline(ii-0.5, color='red', linewidth=2, linestyle='dashed', alpha=0.5)
    pl.show()



if __name__ == "__main__":
    import sys
    main(sys.argv[1:])

