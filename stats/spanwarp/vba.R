################################################################################
#
#  A script for performing voxel-based analysis with ANTsR
#
#  ANTsR can be installed using these instructions:
#
#    http://stnava.github.io/ANTsR/
#
#  Author: Ryan Cabeen
#
################################################################################

library(ANTsR)


run.vba <- function(input.path, mask.fn, meta.df, output.path)
{
  cat("started vba\n")

  thresh <- 0.05
  ids <- meta.df$subject

  cat("... reading tables\n")
  img.fns <- sapply(ids, function(x) {sprintf(input.path, x)})
  study.df <- merge(meta.df, data.frame(subject=ids, fn=img.fns))

  exists <- lapply(as.character(study.df$fn), function(x) { file.exists(x) })
  study.df <- study.df[exists == TRUE,]

  cat("... reading images \n")

  ilist<-list()
  for ( i in 1:length(study.df$fn) )
  {
    fn <- as.character(study.df$fn[i])
    cat(sprintf("...... reading: %s\n", fn))

    simimg<-antsImageRead(fn)

    cat(sprintf("...... smoothing: %s\n", fn))
    simimg<-smoothImage(simimg,0.10)

    ilist[i]<-simimg
  }

  cat(sprintf("... reading mask: %s\n", mask.fn))
  mask <- antsImageRead(mask.fn)

  cat(sprintf("... creating data matrix\n"))

  mat <- imageListToMatrix( ilist, mask )
  site <- study.df$site
  sex <- study.df$sex
  sleep <- study.df$sleep
  corner <- study.df$corner
  mdl <- lm(mat ~ corner + site + sex * sleep)
  mdli <- bigLMStats(mdl, 1.e-4 )

  beta <- mdli$beta[1,]
  tvals <- mdli$beta.t[1,]
  abst <- abs(mdli$beta.t[1,])
  pvals <- mdli$beta.pval[1,]
  qvals <- p.adjust(pvals, method="fdr")
  sig <- qvals <= thresh

  cat("... writing output\n")

  antsImageWrite(makeImage(mask, beta), sprintf(output.path, "beta"))
  antsImageWrite(makeImage(mask, tvals), sprintf(output.path, "tvals"))
  antsImageWrite(makeImage(mask, pvals), sprintf(output.path, "pvals"))
  antsImageWrite(makeImage(mask, qvals), sprintf(output.path, "qvals"))
  antsImageWrite(makeImage(mask, 1-qvals), sprintf(output.path, "invqvals"))
  antsImageWrite(makeImage(mask, sig), sprintf(output.path, "sig"))

  cat("... finished vba\n")
}

mask.fn <- "masks/brain.mask.nii.gz"
#mask.fn <- "masks/lesion.sub.nii.gz"
meta.df <- merge(read.csv("meta/site.csv"), read.csv("meta/all.csv"))
#meta.df <- meta.df[meta.df$corner > 0.7 | meta.df$corner < 0.3,]

dir.create("stats", showWarnings=FALSE)

param <- "lesion.mask"
input.path <- sprintf("cases/%%s/%s.nii.gz", param)
output.path <- sprintf("stats/%s.%s.%%s.nii.gz", "all", param)
run.vba(input.path, mask.fn, meta.df, output.path)

# for (site in unique(meta.df$site))
# {
#   sub.meta.df <- meta.df[meta.df$site == site,]
# 
# 	#for (param in c("t2_rate", "adc_rate", "lesion.mask"))
# 	for (param in c("lesion.mask"))
# 	{
# 		input.path <- sprintf("cases/%%s/%s.nii.gz", param)
# 		output.path <- sprintf("stats/%s.%s.%%s.nii.gz", site, param)
# 		run.vba(input.path, mask.fn, sub.meta.df, output.path)
# 	}
# }
