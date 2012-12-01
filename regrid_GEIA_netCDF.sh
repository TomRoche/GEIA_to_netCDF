#!/usr/bin/env bash
# Driver for regrid.global.to.AQMEII.r--configure as needed for your platform.

# start setup code copied from GEIA_to_netCDF.sh----------------------
# TODO: refactor

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

#   end setup code copied from GEIA_to_netCDF.sh----------------------

REGRID_R="${TEST_DIR}/regrid.global.to.AQMEII.r"

# Input data is GEIA marine N2O emissions converted to netCDF:
# see code @ https://github.com/TomRoche/GEIA_to_netCDF

DATA_INPUT_URI='https://github.com/downloads/TomRoche/GEIA_to_netCDF/GEIA_N2O_oceanic.nc'
DATA_INPUT_FN="$(basename ${DATA_INPUT_URI})"
export DATA_INPUT_FP="${TEST_DIR}/${DATA_INPUT_FN}"
if [[ ! -r "${DATA_INPUT_FP}" ]] ; then
  for CMD in \
    "wget --no-check-certificate -c -O ${DATA_INPUT_FP} ${DATA_INPUT_URI}" \
  ; do
    echo -e "$ ${CMD}"
    eval "${CMD}"
  done
fi
# TODO: automate getting this metadata
export DATA_VAR_NAME='emi_n2o'            # see ncdump output
export DATA_VAR_LONGNAME='N2O emissions'  # see ncdump output
export DATA_VAR_UNIT='ton N2O-N/yr'       # see ncdump output
export DATA_VAR_NA='-999.0'      # missing_value, _Fill_Value
export DATA_INPUT_BAND='3' # index of dim=TIME in emi_n2o(time, lat, lon)

# output name is variant of input name

DATA_INPUT_FN_ROOT="${DATA_INPUT_FN%.*}"
DATA_INPUT_FN_EXT="${DATA_INPUT_FN#*.}"
DATA_OUTPUT_FN="${DATA_INPUT_FN_ROOT}_regrid.${DATA_INPUT_FN_EXT}"
export DATA_OUTPUT_FP="${TEST_DIR}/${DATA_OUTPUT_FN}"

# The template input is a copy of some meteorological data with 52 "real" datavars.
# That data is in the IOAPI format, which here is basically a wrapper around netCDF.
# (IOAPI can be used with other data, and similar wrappers exist for other models.)
# I removed all but one of the datavars (with NCO 'ncks'). TODO: automate!
export TEMPLATE_VAR_NAME='emi_n2o'

TEMPLATE_INPUT_URI='https://github.com/downloads/TomRoche/GEIA_to_netCDF/emis_mole_all_20080101_12US1_cmaq_cb05_soa_2008ab_08c.EXTENTS_INPUT.nc'
TEMPLATE_INPUT_FN="$(basename ${TEMPLATE_INPUT_URI})"
export TEMPLATE_INPUT_FP="${TEST_DIR}/${TEMPLATE_INPUT_FN}"
if [[ ! -r "${TEMPLATE_INPUT_FP}" ]] ; then
  for CMD in \
    "wget --no-check-certificate -c -O ${TEMPLATE_INPUT_FP} ${TEMPLATE_INPUT_URI}" \
  ; do
    echo -e "$ ${CMD}"
    eval "${CMD}"
  done
fi
export TEMPLATE_INPUT_BAND='1' # `ncks` makes dim=TSTEP first

# map...dat is used to create a map for image.plot-ing
# use one of following, depending on units

# units=km
# MAP_TABLE_URI='https://github.com/downloads/TomRoche/GEIA_to_netCDF/map.CMAQkm.world.dat'
# units=m
MAP_TABLE_URI='https://github.com/downloads/TomRoche/GEIA_to_netCDF/map.CMAQm.world.dat'
MAP_TABLE_FN="$(basename ${MAP_TABLE_URI})"
export MAP_TABLE_FP="${TEST_DIR}/${MAP_TABLE_FN}"
if [[ ! -r "${MAP_TABLE_FP}" ]] ; then
  for CMD in \
    "wget --no-check-certificate -c -O ${MAP_TABLE_FP} ${MAP_TABLE_URI}" \
  ; do
    echo -e "$ ${CMD}"
    eval "${CMD}"
  done
fi

# This repo file should have been cloned into the working directory, so no need to download.
STAT_SCRIPT_URI='https://github.com/TomRoche/GEIA_to_netCDF/raw/master/netCDF.stats.to.stdout.r'
STAT_SCRIPT_FN="$(basename ${STAT_SCRIPT_URI})"
export STAT_SCRIPT_FP="${TEST_DIR}/${STAT_SCRIPT_FN}"

# this script drives image.plot, and is copied from ioapi-hack-R (also on github)
# TODO: R-package my code

PLOT_SCRIPT_URI='https://github.com/TomRoche/GEIA_to_netCDF/raw/master/plotLayersForTimestep.r'
PLOT_SCRIPT_FN="$(basename ${PLOT_SCRIPT_URI})"
export PLOT_SCRIPT_FP="${TEST_DIR}/${PLOT_SCRIPT_FN}"

# payload-------------------------------------------------------------

# If this fails ...
"${RSCRIPT}" "${REGRID_R}"
# ... just start R ...
# "${R}"
# ... and source ${REGRID_R}, e.g.,
# source('./regrid.global.to.AQMEII.r')

# start exit code copied from GEIA_to_netCDF.sh-----------------------
# TODO: refactor

# After exiting R, show cwd and display output PDF.
for CMD in \
  "ls -alht ${TEST_DIR}" \
  "${PDF_VIEWER} ${PDF_FP} &" \
; do
  echo -e "$ ${CMD}"
  eval "${CMD}"
done

#   end exit code copied from GEIA_to_netCDF.sh-----------------------
