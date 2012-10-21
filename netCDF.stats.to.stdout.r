# R code to write simple stats (min, mean, median, max) for an input file.
# Run this like
# $ Rscript ./netCDF.stats.to.stdout.r netcdf.fp=./GEIA_N2O_oceanic.nc var.name=emi_n2o
# or
# > source('./netCDF.stats.to.stdout.r')
# > netCDF.stats.to.stdout(...)

# constants-----------------------------------------------------------

this.fn <- 'netCDF.stats.to.stdout.r'      # TODO: get like $0

# functions-----------------------------------------------------------

# syntactic sugar
q1 <- function(vec) { quantile(vec, 0.25) } # first quartile
q3 <- function(vec) { quantile(vec, 0.75) } # third quartile

# the main event
netCDF.stats.to.stdout <- function(
  netcdf.fp, # /path/to/netcdf/file, can be relative or FQ
  var.name   # name_of_data_variable
) {

  # TODO: test arguments!

# start debug
#  cat(sprintf('%s: netcdf.fp==%s, var.name==%s\n', this.fn, netcdf.fp, var.name))
#   end debug

  # <simple input check>
#   system(sprintf('ls -alth %s', netcdf.fp))
#   system(sprintf('ncdump -h %s', netcdf.fp))
  # </simple input check>

  # double-sprintf-ing to set precision by constant: cool or brittle?
  stats.precision <- 3 # sigdigs to use for min, median, max of obs
  stat.str <- sprintf('%%.%ig', stats.precision)
  # use these in function=subtitle.stats as sprintf inputs
  max.str <- sprintf('max=%s', stat.str)
  mea.str <- sprintf('mean=%s', stat.str)
  med.str <- sprintf('med=%s', stat.str)  # median
  min.str <- sprintf('min=%s', stat.str)
  q1.str <- sprintf('q1=%s', stat.str)    # first quartile
  q3.str <- sprintf('q3=%s', stat.str)    # third quartile

  # needed to parse netCDF
  library(ncdf4)

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
      q1.str <- sprintf(q1.str, q1(unsparse.data))
      mea.str <- sprintf(mea.str, mean(unsparse.data))
      med.str <- sprintf(med.str, median(unsparse.data))
      q3.str <- sprintf(q3.str, q3(unsparse.data))
      max.str <- sprintf(max.str, max(unsparse.data))

      cat(sprintf('For %s var=%s\n', netcdf.fp, var.name))
      cat(sprintf('\t%s\n', cells.str))
      cat(sprintf('\t%s\n', obs.str))
      # 6-number summary
      cat(sprintf('\t%s\n', min.str))
      cat(sprintf('\t%s\n', q1.str))
      cat(sprintf('\t%s\n', med.str))
      cat(sprintf('\t%s\n', mea.str))
      cat(sprintf('\t%s\n', q3.str))
      cat(sprintf('\t%s\n', max.str))

    } else {
      cat(sprintf('%s: %s var=%s has no non-NA data',
        this.fn, var.name, netcdf.fp))
    }
  } else {
    cat(sprintf('%s: %s var=%s has no numeric non-NA data',
      this.fn, var.name, netcdf.fp))
  }

  # teardown
  nc_close(netcdf.file)

} # end function netCDF.stats.to.stdout

# code----------------------------------------------------------------

# if this is called as a script, provide a main(): see
# https://stat.ethz.ch/pipermail/r-help/2012-September/323551.html
# https://stat.ethz.ch/pipermail/r-help/2012-September/323559.html
if (!interactive()) {

# start debug
#  cat(sprintf('%s: interactive()==TRUE\n', this.fn))
#   end debug
  
  # TODO: fix `strsplit` regexp below to make this unnecessary
  library(stringr)

  # pass named arguments: var above separated by '='

  args <- commandArgs(TRUE)
  # args is now a list of character vectors
  # First check to see if any arguments were passed, then evaluate each argument:
  # assign val (RHS) to key (LHS) for arguments of the (required) form 'key=val'
  if (length(args)==0) {
    cat(sprintf('%s: no arguments supplied, exiting\n', this.fn))
#    q(status=1) # KLUDGE:
# Currently this is not seeing arguments when called from Rscript,
# so this exit also exits the caller :-(    
  } else {
  # simple positional args work
  # TODO: also support positional usage
  #  netcdf.fp <- args[1]
  #  var.name <- args[2]
    # TODO: test arg length: 2 is required!

# start debug
#    cat(sprintf('%s: got length(args)==%i\n', this.fn, length(args)))
#   end debug

    for (i in 1:length(args)) {
#       eval(parse(text=args[[i]]))
      # `eval(parse())` is unsafe and requires awkward quoting:
      # e.g., of the following (bash) commandlines

      # - Rscript ./netCDF.stats.to.stdout.r netcdf.fp="GEIA_N2O_oceanic.nc" var.name="emi_n2o"
      #   fails

      # + Rscript ./netCDF.stats.to.stdout.r 'netcdf.fp="GEIA_N2O_oceanic.nc"' 'var.name="emi_n2o"'
      #   succeeds

      # so instead
      # TODO: use package `optparse` or `getopt`
      args.keyval.list <-
        strsplit(as.character(parse(text=args[[i]])),
          split='[[:blank:]]*<-|=[[:blank:]]*', fixed=FALSE)
  #                            split='[ \t]*<-|=[ \t]*', fixed=FALSE)
      args.keyval.vec <- unlist(args.keyval.list, recursive=FALSE, use.names=FALSE)
      # TODO: test vector elements!
      # Neither wants to remove all whitespace from around arguments :-( so
      args.key <- str_trim(args.keyval.vec[1], side="both")
      args.val <- str_trim(args.keyval.vec[2], side="both")

# start debug
#       cat(sprintf('%s: got\n', this.fn))
#       cat('\targs.keyval.list==\n')
#       print(args.keyval.list)
#       cat('\targs.keyval.vec==\n')
#       print(args.keyval.vec)
#       cat(sprintf('\targs.key==%s\n', args.key))
#       cat(sprintf('\targs.val==%s\n', args.val))
#   end debug

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

    # payload!
    netCDF.stats.to.stdout(netcdf.fp, var.name)

  } # end if testing number of arguments
} # end if (!interactive())
