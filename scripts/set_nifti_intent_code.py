import nibabel as nib

def main(fname, new_intent_code):
    img = nib.load(fname)
    img.header.set_intent(new_intent_code)
    img.to_filename(fname)

if __name__ == "__main__":
    import sys
    main(sys.argv[1], sys.argv[2])

