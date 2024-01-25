import argparse
import numpy as np
from datetime import datetime
import os


DESCRIPTION =   """
Put some ordering in the strange Bruker Scanlist
Cornelius Eichner 2021

Now sorting by timestamp
Michael Paquette 2023
"""


def func(elem):
    try:
        num = int(elem.split(' (E')[1].split(')>')[0])
    except:
        num = np.nan    
    return num

def buildArgsParser():
    p = argparse.ArgumentParser(description=DESCRIPTION)
    p.add_argument('--in', dest='input', action='store', type=str,
                            help='Name of the input SCANLIST file')
    p.add_argument('--time', dest='input_time', action='store', type=str,
                            help='Name of the input SCANDATE file')
    p.add_argument('--out', dest='output', action='store', type=str,
                            help='Name of the output SCANLIST file')

    return p


def main():

    # Load parser to read data from command line input
    parser = buildArgsParser()
    args = parser.parse_args()

    # Load input variables
    PATH_IN = os.path.realpath(args.input)
    PATH_TIME = os.path.realpath(args.input_time)
    PATH_OUT = os.path.realpath(args.output)
    
    with open(PATH_IN) as f:
        content = f.readlines()

    with open(PATH_TIME) as f:
        dates = f.readlines()

    content = [x.strip() for x in content] # remote newlines
    dates = [x.strip() for x in dates] # remote newlines


    # strip empty
    empty_content = np.array([l == '' for l in content])

    # clean
    content = [content[i] for i in range(len(content)) if ~empty_content[i]]
    dates = [dates[i] for i in range(len(dates)) if ~empty_content[i]]

    # find broken from timestamp
    time_broken = np.array([l[:6] == 'FAILED' for l in dates])

    # make date object
    fmt = '%Y-%m-%d :: %H:%M:%S'
    fmt_failed = 'FAILED at %Y-%m-%d %H:%M:%S.%f'
    date_obj = []
    for i in range(len(dates)):
        if time_broken[i]:
            obj = datetime.strptime(dates[i].split(' +')[0], fmt_failed)
        else:
            obj = datetime.strptime(dates[i], fmt)
        date_obj.append(obj)


    sort_idx = np.argsort(date_obj)


    sorted_names = [content[i] for i in sort_idx]
    sorted_time = [dates[i] for i in sort_idx]
    sorted_broken = [time_broken[i] for i in sort_idx]


    with open(PATH_OUT, 'w') as f:
        for i in range(len(sorted_names)):
            if sorted_broken[i]:
                f.write('FAILED                  {:}\n'.format(sorted_names[i]))
            else:
                f.write('{:}  {:}\n'.format(sorted_time[i], sorted_names[i]))


    # # Extract Scan Numbers from ' (E??)>' Format
    # scan_numbers = []
    # for i_scan,scan in enumerate(content):
    #     scan_numbers.append(func(scan))

    # content_array = np.array(content, dtype=object)
    # content_array_sort = np.array(list(filter(None, content_array[np.argsort(scan_numbers)])), dtype=object)
    
    # np.savetxt(PATH_OUT, content_array_sort, fmt="%s")


if __name__ == '__main__':
    main()

