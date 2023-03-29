import numpy as np
import nibabel as nib
from scipy.ndimage import binary_dilation, binary_erosion
from skimage import measure




def main(args):
    fname_mask = args[0]
    fname_output = args[1]
    radius = float(args[2]) # for the closure
    radius_final = float(args[3]) # final dilation iteration

    print(' ')
    print('Processing {:}'.format(fname_mask))
    print('Using closure_radius = {:} and final dilation_radius = {:}'.format(radius, radius_final))
    print('Saving at {:}'.format(fname_output))


    # load mask
    mask_img = nib.load(fname_mask)
    mask_raw = mask_img.get_fdata()


    orig_size = mask_raw.shape
    pad = int(np.ceil(radius)) + int(np.ceil(radius_final))
    mask_raw = np.pad(mask_raw, pad)



    #Remove small connected component
    # connected component of mask
    labels_1, num1 = measure.label(mask_raw, background=0, connectivity=None, return_num=True)
    # keep only biggest, ignore background = 0
    count_per_id = [np.sum(labels_1==i+1) for i in range(num1)]
    mask = labels_1==(np.argmax(count_per_id)+1) # back in bool




    # define sphere filter for closure
    k = int(2*np.ceil(radius)+1) # filter size
    c = k//2 # center of filter
    X, Y, Z = np.meshgrid(np.arange(k), np.arange(k), np.arange(k))
    dist = np.sqrt((X-c)**2 + (Y-c)**2 + (Z-c)**2)
    structure_element = dist <= radius


    tmp = binary_dilation(mask, structure_element, 1)
    mask_closure = binary_erosion(tmp, structure_element, 1)


    # define sphere filter for final dilation
    k = int(2*np.ceil(radius_final)+1) # filter size
    c = k//2 # center of filter
    X, Y, Z = np.meshgrid(np.arange(k), np.arange(k), np.arange(k))
    dist = np.sqrt((X-c)**2 + (Y-c)**2 + (Z-c)**2)
    structure_element = dist <= radius_final

    mask_closure_dil = binary_dilation(mask_closure, structure_element, 1)

    mask_closure_dil_unpad = mask_closure_dil[pad:pad+orig_size[0], pad:pad+orig_size[1], pad:pad+orig_size[2]]


    nib.Nifti1Image(mask_closure_dil_unpad.astype(np.float32), mask_img.affine).to_filename(fname_output)




if __name__ == "__main__":
    # usage: python3 closure_mask.py mask.nii.gz, mask_closed.nii.gz, radius_hole, radius_final_dil
    import sys
    main(sys.argv[1:])


