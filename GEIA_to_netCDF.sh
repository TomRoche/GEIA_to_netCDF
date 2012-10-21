#!/usr/bin/env bash
# Driver for GEIA.to.netCDF.r on one cluster--fiddle for your platform.
# NOTE regarding R and source-ing below!

# for netcdf4 on EMVL:
# I may need to run from CLI, not here
# You may not need this at all!
module add netcdf-4.1.2

export TEST_DIR='.' # keep it simple for now: same dir as top of git repo
TEST_RUNNER_R="${TEST_DIR}/GEIA.to.netCDF.r"

# for plotting
PDF_VIEWER='xpdf'  # whatever works on your platform
DATE_FORMAT='%Y%m%d_%H%M'
export PDF_DIR="${TEST_DIR}"
PDF_FN="test_$(date +${DATE_FORMAT}).pdf"
export PDF_FP="${TEST_DIR}/${PDF_FN}"

# get GEIA input text from my repository (stable location, no unzip)
GEIA_INPUT_URI='https://github.com/downloads/TomRoche/GEIA_to_netCDF/N2OOC90Y.1A'
GEIA_INPUT_FN="$(basename ${GEIA_INPUT_URI})"
export GEIA_INPUT_FP="${TEST_DIR}/${GEIA_INPUT_FN}"
if [[ ! -r "${GEIA_INPUT_FP}" ]] ; then
  for CMD in \
    "wget --no-check-certificate -c -O ${GEIA_INPUT_FP} ${GEIA_INPUT_URI}" \
  ; do
    echo -e "$ ${CMD}"
    eval "${CMD}"
  done
fi

# this fails
# Rscript "${TEST_RUNNER_R}" # TODO: fixme!
# so just start R and source
R
# source('./GEIA.to.netCDF.r')
# Note this currently gets error like
# > Error in as.double(y) : 
# >   cannot coerce type 'closure' to vector of type 'double'
# but runs successfully, but cannot exit successfully :-( # TODO: fixme!

# exit from R and
for CMD in \
  "ls -alht ${TEST_DIR}" \
  "${PDF_VIEWER} ${PDF_FP}" \
; do
  echo -e "$ ${CMD}"
  eval "${CMD}"
done
