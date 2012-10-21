#!/usr/bin/env bash
# Driver for GEIA.to.netCDF.r--configure as needed for your platform.
# NOTE regarding R and source-ing below!

# for netcdf4 (ncdf4.so, libnetcdf.so.7) on EMVL:
# I may need to run this from CLI, not here, and
# you may not need this at all!
module add netcdf-4.1.2
# for R on EMVL: don't ask :-(
R_DIR='/usr/local/R-2.15.0/bin'
R="${R_DIR}/R"
RSCRIPT="${R_DIR}/Rscript"

export TEST_DIR='.' # keep it simple for now: same dir as top of git repo
mkdir -p ${TEST_DIR}

# for plotting
PDF_VIEWER='xpdf'  # whatever works on your platform
# temporally disaggregate multiple plots
DATE_FORMAT='%Y%m%d_%H%M'
export PDF_DIR="${TEST_DIR}"
PDF_FN="test_$(date +${DATE_FORMAT}).pdf"
export PDF_FP="${TEST_DIR}/${PDF_FN}" # path to PDF output

# this does the converting and plotting
CONVERT_PLOT_R="${TEST_DIR}/GEIA.to.netCDF.r" 

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

# If this fails ...
"${RSCRIPT}" "${CONVERT_PLOT_R}"
# ... just start R ...
# "${R}"
# ... and source ${CONVERT_PLOT_R}, e.g.,
# source('./GEIA.to.netCDF.r')

# After exiting R, show output files and display output PDF.
for CMD in \
  "ls -alht ${TEST_DIR}" \
  "${PDF_VIEWER} ${PDF_FP}" \
; do
  echo -e "$ ${CMD}"
  eval "${CMD}"
done
