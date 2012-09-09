# R code to write simple stats for an input file
# There's gotta be an easier way.

# constants-----------------------------------------------------------

# TODO: fix `strsplit` regexp below to make this unnecessary
library(stringr)

this.fn <- 'netCDF.stats.to.stdout.r'      # TODO: get like $0

# input metadata: pass via `Rscript args`
netcdf.fp <- '/unknown/path/to/netcdf/file' # can be relative or FQ
var.name <- 'unknown_name_of_data_variable'

# pass named arguments: var above separated by '='
# TODO: also support positional
args <- commandArgs(TRUE)
# args is now a list of character vectors
# First check to see if any arguments were passed, then evaluate each argument:
# assign val (RHS) to key (LHS) for arguments of the (required) form 'key=val'
if (length(args)==0) {
  cat("No arguments supplied\n")
  q(status=1) # exit
} else {
# simple positional args work
# TODO: allow this usage
#  netcdf.fp <- args[1]
#  var.name <- args[2]
  # TODO: test arg length: 2 is required!
  for (i in 1:length(args)) {
#    eval(parse(text=args[[i]]))
# `eval(parse())` is unsafe and requires awkward quoting:
# e.g., of the following (bash) commandlines

# - Rscript ./netCDF.stats.to.stdout.r netcdf.fp="GEIA_N2O_oceanic.nc" var.name="emi_n2o"
#   fails

# + Rscript ./netCDF.stats.to.stdout.r 'netcdf.fp="GEIA_N2O_oceanic.nc"' 'var.name="emi_n2o"'
#   succeeds
    args.keyval.list <-
      strsplit(as.character(parse(text=args[[i]])),
        split='[[:blank:]]*<-|=[[:blank:]]*', fixed=FALSE)
#                            split='[ \t]*<-|=[ \t]*', fixed=FALSE)
    args.keyval.vec <- unlist(args.keyval.list, recursive=FALSE, use.names=FALSE)
    # TODO: test vector elements!
    # Neither wants to remove all whitespace from around arguments :-( so
    args.key <- str_trim(args.keyval.vec[1], side="both")
    args.val <- str_trim(args.keyval.vec[2], side="both")
    # A real case statement would be nice to have
    if        (args.key == 'netcdf.fp') {
      netcdf.fp <- args.val
    } else if (args.key == 'var.name') {
      var.name <- args.val
    } else {
      stop(sprintf("unknown argument='%s'", args.key))
      # TODO: show usage
      q(status=1) # exit with error
    }
  } # end for loop over arguments
} # end if testing number of arguments

# start debug
# cat(sprintf('%s: netcdf.fp="%s", var.name="%s"\n', this.fn, netcdf.fp, var.name))
#   end debug

# double-sprintf-ing to set precision by constant: cool or brittle?
stats.precision <- 3 # sigdigs to use for min, median, max of obs
stat.str <- sprintf('%%.%ig', stats.precision)
# use these in function=subtitle.stats as sprintf inputs
max.str <- sprintf('max=%s', stat.str)
mea.str <- sprintf('mean=%s', stat.str)
med.str <- sprintf('med=%s', stat.str)
min.str <- sprintf('min=%s', stat.str)

# code----------------------------------------------------------------

# needed to parse netCDF
library(ncdf4)

# # <simple input check>
# system(sprintf('ls -alth %s', netcdf.fp))
# system(sprintf('ncdump -h %s', netcdf.fp))
# # </simple input check>

# open netCDF file, uncautiously
# NOTE: you must assign when you nc_open!
netcdf.file <- nc_open(
  filename=netcdf.fp,
  write=FALSE,    # will only read below
  readunlim=TRUE) # it's a small file

# uncautiously get the data out of the datavar
var.data <- ncvar_get(
  nc=netcdf.file,
  varid=var.name)

# # <simple output check/>
# dim(var.data) # [1] 360 180

if (is.numeric(var.data) && sum(!is.na(var.data))) {
  unsparse.data <- var.data[!is.na(var.data)]
  obs <- length(unsparse.data)
  if (obs > 0) {
    cells.str <- sprintf('cells=%i', length(var.data))
    obs.str <- sprintf('obs=%i', obs)
    min.str <- sprintf(min.str, min(unsparse.data))
    max.str <- sprintf(max.str, max(unsparse.data))
    mea.str <- sprintf(mea.str, mean(unsparse.data))
    med.str <- sprintf(med.str, median(unsparse.data))

    cat(sprintf('For %s var=%s\n', netcdf.fp, var.name))
    cat(sprintf('\t%s\n', cells.str))
    cat(sprintf('\t%s\n', obs.str))
    cat(sprintf('\t%s\n', min.str))
    cat(sprintf('\t%s\n', max.str))
    cat(sprintf('\t%s\n', mea.str))
    cat(sprintf('\t%s\n', med.str))

  } else {
    cat(sprintf('%s var=%s has no non-NA data',
      var.name, netcdf.fp))
  }
} else {
  cat(sprintf('%s var=%s has no numeric non-NA data',
    var.name, netcdf.fp))
}

# teardown
nc_close(netcdf.file)
