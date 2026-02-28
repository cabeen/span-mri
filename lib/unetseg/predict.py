#!/usr/bin/env python
########################################################################################################################
#
#  SPAN U-Net Prediction — Command-Line Entry Point
#
#  Purpose:
#    Command-line wrapper for U-Net brain segmentation inference.
#    Loads a pre-trained model and applies it to a multi-channel NIfTI
#    image to produce a binary brain mask.
#
#  Usage:
#    python predict.py --model <model_path> --image <input.nii.gz> --output <output.nii.gz>
#
#  Dependencies: PyTorch, nibabel, scipy, numpy, unetseg module
#
########################################################################################################################
'''
Predict the labels of an image
'''

import os, sys, argparse
from argparse import ArgumentDefaultsHelpFormatter as formatter

import unetseg 

if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=formatter)
    optional=parser._action_groups.pop()
    required=parser.add_argument_group('required arguments')
    required.add_argument('--image', type=str, required=True, help='the input image')
    required.add_argument('--model', required=True, type=str, help='the model to evaluate')
    optional.add_argument('--output', type=str, help='the output')
    parser._action_groups.append(optional)

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    args = parser.parse_args()

    for check in [args.image, args.model]:
        if not os.path.exists(check): 
            print("Invalid input: %s" % check)
            sys.exit(2)

    unetseg.predict_main(args.model, args.image, args.output)

########################################################################################################################
# End
########################################################################################################################
