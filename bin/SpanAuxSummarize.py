#! /usr/bin/env python 
################################################################################

"""create a table summarizing the imaging data"""

from sys import argv
from sys import path
from sys import exit

from os import getenv
from os import makedirs
from os import chmod
from os import chdir
from os import getenv
from os import wait
from os import remove
from os import rmdir
from os import pathsep

from os.path import join
from os.path import basename
from os.path import dirname
from os.path import exists
from os.path import abspath
from os.path import isfile
from os.path import isdir
from os.path import pardir

import subprocess
from subprocess import STDOUT
from subprocess import call
from datetime import datetime
from inspect import getargspec
from random import randint
from time import time
from optparse import OptionParser
from shutil import rmtree
from shutil import move
from string import Template

from glob import glob

import json
import nibabel

def main():
  usage = "qit %s [opts]" % basename(argv[0])
  parser = OptionParser(usage=usage, description=__doc__)
  parser.add_option("--input", metavar="<dir>", \
    help="specify the input directory")
  parser.add_option("--output", metavar="<fn>", \
    help="specify the output table")

  (opts, pos) = parser.parse_args()

  if len(pos) != 0 or len(argv) == 1:
    parser.print_help()
    return

  if not opts.input:
    print("no input specified")

  if not opts.output:
    print("no output specified")

  print("started")

  fns = glob(join(opts.input, "**/native.convert/*.json"))
  print("found %d json files" % len(fns))

  keys = []
  keys.append("subject")
  keys.append("scan_id")
  keys.append("meta_fn")
  keys.append("img_fn")
  keys.append("nifti_dim_0")
  keys.append("nifti_dim_1")
  keys.append("nifti_dim_2")
  keys.append("nifti_dim_3")
  keys.append("nifti_dim_4")
  keys.append("nifti_pixdim_1")
  keys.append("nifti_pixdim_2")
  keys.append("nifti_pixdim_3")
  keys.append("nifti_pixdim_4")

  entries = []
  for fn in fns:

    scan_id = basename(fn).split(".json")[0]
    subject_id = basename(dirname(dirname(fn)))

    entry = json.load(open(fn))
    entry["subject"] = subject_id 
    entry["scan_id"] = scan_id 
    entry["meta_fn"] = fn

    img_fn = fn.replace("json", "nii.gz")
    
    img = nibabel.load(img_fn)
    entry["img_fn"] = img_fn
    entry["nifti_dim_0"] = img.header['dim'][0]
    entry["nifti_dim_1"] = img.header['dim'][1]
    entry["nifti_dim_2"] = img.header['dim'][2]
    entry["nifti_dim_3"] = img.header['dim'][3]
    entry["nifti_dim_4"] = img.header['dim'][4]
    entry["nifti_pixdim_1"] = img.header['pixdim'][1]
    entry["nifti_pixdim_2"] = img.header['pixdim'][2]
    entry["nifti_pixdim_3"] = img.header['pixdim'][3]
    entry["nifti_pixdim_4"] = img.header['pixdim'][4]

    for key in entry:
      if isinstance(entry[key], (float, int, str)) and key not in keys:
        keys.append(key)

    entries.append(entry)
  
  print("found %d keys" % len(keys))
  print(keys)

  fp = open(opts.output, "w")

  printit = lambda row : fp.write("%s\n" % ",".join(map(str,row)))

  printit(keys)

  for entry in entries:
    row = []
    for key in keys:
      if key in entry:
        row.append(entry[key])
      else:
        row.append("NA")
    printit(row)
  
  fp.close()

  print("finished")

if __name__ == "__main__":
    main()
