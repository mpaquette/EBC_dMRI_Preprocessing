import numpy as np
import nibabel as nib


def main(input_fname, output_fname, maxdist):

    img = nib.load(input_fname)
    raw = img.get_fdata()

    new = raw.copy()
    for i in range(int(maxdist), 0, -1):
        new[i-1, :, :] = new[i, :, :]
        new[-(i), :, :] = new[-(i+1), :, :]
        new[:, i-1, :] = new[:, i, :]
        new[:, -(i), :] = new[:, -(i+1), :]
        new[:, :, i-1] = new[:, :, i]
        new[:, :, -(i)] = new[:, :, -(i+1)]

    nib.Nifti1Image(new.astype(img.get_data_dtype()), affine=img.affine).to_filename(output_fname)


if __name__ == "__main__":
    import sys
    main(*sys.argv[1:])
