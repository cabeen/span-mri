#! /usr/bin/env qit
################################################################################
#
# SPAN Midline analysis
#
################################################################################

"""SPAN midline analysis"""

from common import *

def main():
    if len(args) == 1:
        print("Usage:")
        print("")
        print("  qit %s brain.mask.nii.gz tissue.mask.nii.gz csf.mask.nii.gz atlas_dir output" % basename(args[0]))
        print("")
        print("Description:")
        print("")
        print("  %s" % __doc__)
        parser.Logging.info_help()
        return

    Logging.info("started")

    brain_mask_fn = args[1]
    tissue_mask_fn = args[2]
    csf_mask_fn = args[3]
    middle_mask_fn = join(args[4], "middle.mask.nii.gz")
    lm_fn = join(args[4], "lm.txt")
    output_dn = args[5]

    tmp_dn = "%s.tmp.%d" % (output_dn, int(time()))
    makedirs(tmp_dn)

    Logging.info("using brain: %s" % brain_mask_fn)
    Logging.info("using tissue: %s" % tissue_mask_fn)
    Logging.info("using csf: %s" % csf_mask_fn)
    Logging.info("using middle: %s" % middle_mask_fn)
    Logging.info("using output: %s" % output_dn)
    Logging.info("using tmp: %s" % tmp_dn)

    for fn in [brain_mask_fn, tissue_mask_fn, csf_mask_fn]:
      if not exists(fn):
        Logging.error("input not found!")

    Logging.info("reading input")
    brain_mask = Mask.read(brain_mask_fn)
    tissue_mask = Mask.read(tissue_mask_fn)
    csf_mask = Mask.read(csf_mask_fn)
    middle_mask = Mask.read(middle_mask_fn)

    Logging.info("loading landmarks")
    lms = [float(x) for x in open(lm_fn, "r").read().split()]
    xCenter, xLeft, xRight, yAnt, yPost, zCenter, zSup, zInf = lms
    thresh = (xRight - xLeft) / 658
    # with mouse voxel size = 0.00159387, this corresponds to more than 9 voxels

    region_mask = MaskUtils.and(csf_mask, middle_mask)
    region_mask = MaskUtils.greater(region_mask, thresh)
    region_mask = MaskHull.apply(region_mask)
    centroids = MaskCentroids.apply(region_mask)

    landmarks = VectsSource.create() 
    hemis_mask = tissue_mask.proto()
    
    if centroids.size() == 0:
        Logging.info("no centroid found, saving NA values")

        f = open(join(tmp_dn, "map.csv"), 'w')
        f.write("name,value\n")
        f.write("shift_mm,NA\n")
        f.write("shift_lat,NA\n")
        f.write("shift_width,NA\n")
        f.write("shift_percent,NA\n")
        f.write("shift_left,NA\n")
        f.write("shift_right,NA\n")
        f.write("shift_min,NA\n")
        f.write("shift_max,NA\n")
        f.write("shift_ratio,NA\n")
        f.write("shift_index,NA\n")
        f.write("tissue_volume_left,NA\n")
        f.write("tissue_volume_right,NA\n")
        f.write("tissue_volume_latidx,NA\n")
        f.close()
    
    else:
        centroid = centroids.get(0)
        x = centroid.getX()
        y = centroid.getY()
        z = centroid.getZ()

        Logging.info("centroid: %g %g %g" % (x, y, z))

        shift = VectSource.create3D(x, y, zCenter)
        center = VectSource.create3D(xCenter, y, zCenter)
        superior = VectSource.create3D(xCenter, y, zSup)
        inferior = VectSource.create3D(xCenter, y, zInf)
        anterior = VectSource.create3D(xCenter, yAnt, zCenter)
        posterior = VectSource.create3D(xCenter, yPost, zCenter)

        sampling = brain_mask.getSampling()
        sample = sampling.nearest(shift)

        iNum = sampling.numI()
        iMin = iNum
        iMax = 0

        for i in range(iNum):
            if brain_mask.foreground(i, sample.getJ(), sample.getK()):
                iMin = min(iMin, i)
                iMax = max(iMax, i)

        Logging.info("iMin, iMax = %d, %d" % (iMin, iMax))

        left = sampling.world(iMin, sample.getJ(), sample.getK())
        right = sampling.world(iMax, sample.getJ(), sample.getK())

        for v in [shift,center,left,right,superior,inferior,anterior,posterior]:
            landmarks.add(v)

        shift_lat = shift.getX() - center.getX()
        shift_mm = shift.dist(center)
        shift_width = left.dist(right)
        shift_percent = 200 * shift_mm / shift_width
        shift_left = shift.dist(left)
        shift_right = shift.dist(right)
        shift_min = min(shift_left, shift_right)
        shift_max = max(shift_left, shift_right)
        shift_ratio = shift_min / shift_max
        shift_mean = (shift_right + shift_left) / 2.0
        shift_index = (shift_right - shift_left) / shift_mean

        hemis_mask = MaskUtils.split(tissue_mask, landmarks)
        vol_left = MaskUtils.volume(hemis_mask, 1)
        vol_right = MaskUtils.volume(hemis_mask, 2)
        vol_index = 2.0 * (vol_left - vol_right) / (vol_left + vol_right)

        f = open(join(tmp_dn, "map.csv"), 'w')
        f.write("name,value\n")
        f.write("shift_mm,%g\n" % shift_mm)
        f.write("shift_lat,%g\n" % shift_lat)
        f.write("shift_width,%g\n" % shift_width)
        f.write("shift_percent,%g\n" % shift_percent)
        f.write("shift_left,%g\n" % shift_left)
        f.write("shift_right,%g\n" % shift_right)
        f.write("shift_min,%g\n" % shift_min)
        f.write("shift_max,%g\n" % shift_max)
        f.write("shift_ratio,%g\n" % shift_ratio)
        f.write("shift_index,%g\n" % shift_index)
        f.write("tissue_volume_left,%g\n" % vol_left)
        f.write("tissue_volume_right,%g\n" % vol_right)
        f.write("tissue_volume_index,%g\n" % vol_index)
        f.close()
        
    centroids.write(join(tmp_dn, "centroid.txt"))
    landmarks.write(join(tmp_dn, "landmarks.txt"))
    hemis_mask.write(join(tmp_dn, "hemis.mask.nii.gz"))

    if exists(output_dn):
      bck = "%s.bck.%d" % (output_dn, int(time()))
      Logging.info("backing previous results to %s" % bck)
      move(output_dn, bck)

    Logging.info("cleaning up")
    move(tmp_dn, output_dn)

    Logging.info("finished")

if __name__ == "__main__":
    main()
