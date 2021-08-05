#! /bin/bash
################################################################################

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [ ! -e ${ROOT}/env ]; then
  PREV=$PWD
  cd ${ROOT}
  python3 -m venv env
  source env/bin/activate
  pip install wheel torch torchvision nibabel scipy numpy torchsummary albumentations
  cd ${PREV} 
fi

source ${ROOT}/env/bin/activate
export PATH=$PATH:${ROOT}/env/bin

################################################################################
