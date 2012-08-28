# R code to write GEIA emissions from the distributed text format
# (space separated values, 10-line header, no comments)
# to netCDF format. Unfortunately all hardcoded.

# libraries also read separately below, for input and output processing
library(maps)   # on tlrPanP5 as well as clusters
library(ncdf4)  # on clusters only
library(fields) # on tlrPanP5 as well as clusters

# constants-----------------------------------------------------------

this.fn <- 'GEIA.to.netCDF.r'      # TODO: get like $0

# input metadata
# for details, see http://geiacenter.org/presentData/geiadfrm.html
GEIA.emis.txt.dir <- '.'           # folder containing ...
GEIA.emis.txt.fn <- 'N2OOC90Y.1A'  # ... text file from GEIA ...
# GEIA.emis.txt.fn <- 'N2OOC90Y.1A.short'  # ... text file from GEIA ...
# GEIA.emis.txt.fn <- 'N2OOC90Y.1A.sorted'  # ... text file from GEIA ...
GEIA.emis.txt.n.header <- 10       # ... with n.header lines to skip @ top

# GEIA data is 1° x 1° so
grid.lat.degree.start <- -90.0   # 90 S, scalar
grid.lat.degree.per.cell <- 1.0
grid.lon.degree.start <- -180.0  # 180 W, scalar
grid.lon.degree.per.cell <- 1.0
GEIA.emis.lat.dim <- 180.0 / grid.lat.degree.per.cell # total lats, scalar
GEIA.emis.lon.dim <- 360.0 / grid.lon.degree.per.cell # total lons, scalar
GEIA.emis.grids.dim <-
  GEIA.emis.lat.dim * GEIA.emis.lon.dim # total gridcells, scalar

# output metadata
netcdf.dir <- '.'                      # folder containing ...
netcdf.fn <- 'GEIA_N2O_oceanic.nc'     # ... netCDF emissions
netcdf.title <- 'GEIA annual oceanic N2O emissions'
netcdf.source_file <-
  "http://geiacenter.org/data/n2ooc90y.1a.zip, 'GEIA Inventory n2ocg90yr1.1a  18 Dec 95'"
netcdf.Conventions <-
  "Contact: A.F. Bouwman, RIVM; Box 1, 3720 BA Bilthoven, Netherlands; tel.31-30-2743635; fax.31-30-2744417; email lex.bouwman@rivm.nl"
time.var.name <- "time"                # like CLM-CN, EDGAR, GFED
time.var.long_name <- "time"           # like CLM-CN, EDGAR, GFED
time.var.units <- "year"               # for now
time.var.calendar <- "none: emissions attributed to no particular year"
lat.var.name <- "lat"                  # like CLM-CN, EDGAR, GFED
lat.var.long_name <- "latitude"        # like CLM-CN, EDGAR, GFED
lat.var.units <- "degrees_north"       # like CLM-CN, EDGAR, GFED
lat.var.comment <- "center_of_cell"    # like EDGAR
lon.var.name <- "lon"                  # like CLM-CN, EDGAR, GFED
lon.var.long_name <- "longitude"       # like CLM-CN, EDGAR, GFED
lon.var.units <- "degrees_east"        # like CLM-CN, EDGAR, GFED
lon.var.comment <- "center_of_cell"    # like EDGAR
emis.var.name <- "emi_n2o"             # like EDGAR
emis.var.long_name <- "N2O emissions"  # like CLM-CN
emis.var.total_emi_n2o <-              # EDGAR-style,
  3.5959E+06                           # value from header(GEIA.emis.txt.fn)
emis.var.units <- "ton N2O-N/yr"       # value from header(GEIA.emis.txt.fn)
emis.var._FillValue <- -999.0          # like GFED

# functions-----------------------------------------------------------

# for metadata, see http://geiacenter.org/presentData/geiadfrm.html
# all indices are 1-based
col.row.to.GEIA.grid.number <- function(
  col.index,
  row.index
) {
  (row.index * 1000) + col.index # return
}

# for metadata, see http://geiacenter.org/presentData/geiadfrm.html
# all indices are 1-based
# ASSERT: GEIA.grid.number always> 0
GEIA.grid.number.to.lon.lat.vec <- function(
  grid.n
) {
  # TODO: throw on grid.n <= 0
  lon.lat.vec <- double(2) # [lon, lat]
  lon.lat.vec[1] <- ((grid.n %% 1000) - 181) + 0.5 # longitude of cell center
  lon.lat.vec[2] <- ((grid.n %/% 1000)- 91) + 0.5  # latitude of cell center
  lon.lat.vec # return
}

# Calculate 1-d vector index from 2-d grid indices.
# Note "grid index" != GEIA grid number !!!

# GEIA numbers with latitude major:
# > Grid Number = (j*1000) + i
# > j   row number starting at 1 for 90S to 89S latitude,
#                                    -90    -89
# ...
# > i   column number starting at 1 for 180W to 179W longitude,
#                                       -180    -179

# We can't do that, since, IN THIS CASE,
# |latitudes| < |longitudes|: hashes will collide.
# (If one has more lats than lons, do oppositely!)
# Instead, smallest grid index == smallest lat index == 1

# ASSERT: grid.index always> 0
lon.lat.vec.to.grid.index <- function(
  lon.lat.vec, # [lon, lat]
  n.lon,       # number of longitudes
  n.lat        # number of latitudes
) {
  lon <- lon.lat.vec[1] - 0.5 # lon NOT of cell center
  lat <- lon.lat.vec[2] - 0.5 # lat NOT of cell center
#  ((lat - 1) * n.lat) + lon # gotta deal with lat,lon < 0
# lat=-90 -> row=1 , lon=-180 -> col=1
#  ((lat + 90) * n.lat) + (lon + 181) # hashes collide
  grid.index <- ((lon + 180) * n.lon) + (lat + 91)
  if (grid.index <= 0) {
    cat(sprintf(
      'ERROR: %s: (lon=%.1f,lat=%.1f) -> global grid index=%.0f <= 0\n',
      this.fn, lon, lat, global.emis.vec.index))
    return # TODO: end execution of caller
  }
  grid.index
}

# Since we have way fewer records than gridcells (36143 << 64800),
# we need to put NAs in the missing gridcells.
# So
# * calculate each grid index "in order"
# * lookup value from GEIA.emis.mx
# * write that value if found, or NA otherwise
# TODO: make this code {more Rish, less procedural}
create.global.emissions.vector <- function(
  GEIA.emis.grids.dim, # total number of all gridcells that could contain values
  GEIA.emis.mx.rows,   # total number of rows providing values
  GEIA.emis.mx         # data structure: grid# -> value
) {
  global.emis.vec <-             # retval
#    integer(GEIA.emis.grids.dim) # int vector for all gridcells
    numeric(GEIA.emis.grids.dim)  # vector for all gridcells
  global.emis.vec <-              # ... with all values=NA by default
    # TODO: make size=(max(lat)*1000) + max(lon)
    rep(NA, GEIA.emis.grids.dim)  # (actually need more space than that!)
  for (i.row in 1:GEIA.emis.mx.rows) {
    # get the GEIA grid# ...
    GEIA.emis.grid.n <- GEIA.emis.mx[i.row,1]
    # ... and the data for that gridcell ...
    GEIA.emis.grid.val <- GEIA.emis.mx[i.row,2]
    # ... and the corresponding index into OUR "grid vector"
    lon.lat.vec <- # only for debugging
      GEIA.grid.number.to.lon.lat.vec(GEIA.emis.grid.n)
    global.emis.vec.index <-
      lon.lat.vec.to.grid.index(
        lon.lat.vec, n.lon=GEIA.emis.lon.dim, n.lat=GEIA.emis.lat.dim)
    # ASSERT: never overwrite anything but NA!
    if (is.na(global.emis.vec[global.emis.vec.index])) {
# start debug
#      cat(sprintf('debug: %s: writing value=%f from GEIA grid#=%.0f to global grid index=%.0f (lon=%.1f,lat=%.1f)\n',
#        this.fn, GEIA.emis.grid.val, GEIA.emis.grid.n, 
#        global.emis.vec.index, lon.lat.vec[1], lon.lat.vec[2]))
#   end debug
      global.emis.vec[global.emis.vec.index] <- GEIA.emis.grid.val
    } else {
# '%i' draws error? and '%d'??
#      cat(sprintf('ERROR: %s: attempting to write value from GEIA grid#=%i to grid index=%i (lon=%d,lat=%d) -> %f',
      cat(sprintf('ERROR: %s: attempting to write value=%f from GEIA grid#=%.0f to global grid index=%.0f (lon=%.1f,lat=%.1f)\n',
        this.fn, GEIA.emis.grid.val, GEIA.emis.grid.n, 
        global.emis.vec.index, lon.lat.vec[1], lon.lat.vec[2]))
      return # TODO: end execution of caller
    }
  } # end for loop over GEIA data values
  global.emis.vec # return
} # end function create.global.emissions.vector

# TODO: refactor! this plot.layer is copy/mod from ioapi::plotLayersForTimestep.r::plot.layer
# changes to arguments:
# * attrs.list -> x.centers, y.centers (since these are in degrees, not km)
# * map not passed: I'm using global map via `map(add=TRUE)`
plot.layer <- function(
  data,             # data to plot (required)
  title,            # string for plot title (required?)
                    # TODO: handle when null!
  subtitle=NULL,    # string for plot subtitle
  x.centers,        # centers of abscissa points
  y.centers,        # centers of ordinate points
  q.vec=NULL,       # for quantiles
  colors
) {
  if (sum(!is.na(data)) && (!is.null(q.vec))) {
    plot.list <- list(x=x.centers, y=y.centers, z=data)
    quantiles <- quantile(c(data), q.vec, na.rm=TRUE)
    quantiles.formatted <- format(as.numeric(quantiles), digits=3)
# start debugging
#      print(paste('Non-null image.plot for source layer==', i.layer, ', quantile bounds=='))
#      print(quantiles)
#   end debugging
    if (is.null(subtitle)) {
      image.plot(plot.list, xlab="", ylab="", axes=F, col=colors(100),
        axis.args=list(at=quantiles, labels=quantiles.formatted),
        main=title)
    } else {
      image.plot(plot.list, xlab="", ylab="", axes=F, col=colors(100),
        axis.args=list(at=quantiles, labels=quantiles.formatted),
        main=title, sub=subtitle)
    }
    lines(map)
  } else {
# debugging
#      print(paste('Null image.plot for source layer=', i.layer))
    if (is.null(subtitle)) {
      plot(0, type="n", axes=F, xlab="", ylab="",
        xlim=range(x.centers), ylim=range(y.centers),
        main=title)
    } else {
      plot(0, type="n", axes=F, xlab="", ylab="",
        xlim=range(x.centers), ylim=range(y.centers),
        main=title, sub=subtitle)
    }
    lines(map)
  } # end testing data
} # end function plot.layer

# TODO: refactor! subtitle.stats is copied from ioapi::plotLayersForTimestep.r
subtitle.stats <- function(vec) {
  return.str <- ""
  # is it numeric, and not empty?
  if (is.numeric(vec) && sum(!is.na(vec))) {
#    unsparse.vec <- subset(vec, !is.na(vec)) # fail: intended for interactive use
#    unsparse.vec <- na.omit(vec) # fail: omits all *rows* containing an NA!
    grids <- length(vec)
    grids.str <- sprintf('(of cells=%i)', grids)
    unsparse.vec <- vec[!is.na(vec)]
    obs <- length(unsparse.vec)
    obs.str <- sprintf('obs=%i', obs)
    # use constants defined above. TODO: compute these once!
    max.str <- sprintf(max.str, max(unsparse.vec))
    med.str <- sprintf(med.str, median(unsparse.vec))
    min.str <- sprintf(min.str, min(unsparse.vec))
    return.str <-
      sprintf('%s %s: %s, %s, %s',
              obs.str, grids.str, min.str, med.str, max.str)
  } else {
    return.str <-"no data"
  }
  return.str
} # end function subtitle.stats

# code----------------------------------------------------------------

# process input
library(maps)  # on tlrPanP5 as well as clusters

# input file path
GEIA.emis.txt.fp <- sprintf('%s/%s', GEIA.emis.txt.dir, GEIA.emis.txt.fn)
# columns are grid#, mass
GEIA.emis.mx  <-
  as.matrix(read.table(GEIA.emis.txt.fp, skip=GEIA.emis.txt.n.header))
# mask zeros? no, use NA for non-ocean areas
# GEIA.emis.mx[GEIA.emis.mx == 0] <- NA
# <simple input check>
dim(GEIA.emis.mx) ## [1] 36143     2
# start debug
GEIA.emis.mx.rows <- dim(GEIA.emis.mx)[1]
if (GEIA.emis.mx.rows > GEIA.emis.grids.dim) {
  cat(sprintf('ERROR: %s: GEIA.emis.mx.rows=%.0d > GEIA.emis.grids.dim=%.0d\n',
    this.fn, GEIA.emis.mx.rows, GEIA.emis.grids.dim))
} else {
  cat(sprintf('debug: %s: GEIA.emis.mx.rows < GEIA.emis.grids.dim\n',
    this.fn))
}
#   end debug
# </simple input check>

global.emis.vec <-
  create.global.emissions.vector(
    GEIA.emis.grids.dim, GEIA.emis.mx.rows, GEIA.emis.mx)

# <visual input check>
# Need sorted lat and lon vectors: we know what those are a priori
# Add 0.5 since grid centers
lon.vec <- 0.5 +
  seq(from=grid.lon.degree.start, by=grid.lon.degree.per.cell, length.out=GEIA.emis.lon.dim)
lat.vec <- 0.5 +
  seq(from=grid.lat.degree.start, by=grid.lat.degree.per.cell, length.out=GEIA.emis.lat.dim)

# Create emissions matrix corresponding to those dimensional vectors
# (i.e., global.emis.mx is the "projection" of global.emis.vec)
# First, create empty global.emis.mx? No, fill from global.emis.vec.
# Fill using byrow=T? or "bycol" == byrow=FALSE? (row=lat)
# I assigned (using lon.lat.vec.to.grid.index)
# "grid indices" (global.emis.vec.index values) 
# "lon-majorly" (i.e., iterate over lats before incrementing lon),
# so we want to fill byrow=FALSE ... BUT,
# that will "fill from top" (i.e., starting @ 90N) and
# we want to "fill from bottom" (i.e., starting @ 90S) ...
# global.emis.mx <- matrix(
#   global.emis.vec, nrow=GEIA.emis.lat.dim, ncol=GEIA.emis.lon.dim,
# # so flip/reverse rows/latitudes when done
#   byrow=FALSE)[GEIA.emis.lat.dim:1,] 

# NO: I cannot just fill global.emis.mx from global.emis.vec:
# latter's/GEIA's grid numbering system ensures 1000 lons per lat!
# Which overflows the "real-spatial" global.emis.mx :-(
# So I need to fill global.emis.mx using a for loop to decode the grid indices :-(
# (but at least I can fill in whatever direction I want :-)
global.emis.mx <- matrix(
  rep(NA, GEIA.emis.grids.dim), nrow=GEIA.emis.lat.dim, ncol=GEIA.emis.lon.dim)

# 1: works if subsequently transposed: TODO: FIXME
for (i.lon in 1:GEIA.emis.lon.dim) {
  for (i.lat in 1:GEIA.emis.lat.dim) {
# 2: fails with 'dimensions of z are not length(x)(-1) times length(y)(-1)'
# for (i.lat in 1:GEIA.emis.lat.dim) {
#   for (i.lon in 1:GEIA.emis.lon.dim) {
# 3: fails with 'dimensions of z are not length(x)(-1) times length(y)(-1)'
# for (i.lon in GEIA.emis.lon.dim:1) {
#   for (i.lat in GEIA.emis.lat.dim:1) {
# 4: fails with 'dimensions of z are not length(x)(-1) times length(y)(-1)'
# for (i.lat in GEIA.emis.lat.dim:1) {
#   for (i.lon in GEIA.emis.lon.dim:1) {
    lon <- lon.vec[i.lon]
    lat <- lat.vec[i.lat]
    GEIA.emis.grid.val <-
      global.emis.vec[
        lon.lat.vec.to.grid.index(c(lon, lat),
          n.lon=GEIA.emis.lon.dim, n.lat=GEIA.emis.lat.dim)]
    if (!is.na(GEIA.emis.grid.val)) {
      if (is.na(global.emis.mx[i.lat, i.lon])) {
        global.emis.mx[i.lat, i.lon] <- GEIA.emis.grid.val
# start debug
#        cat(sprintf(
#          'debug: %s: writing val=%f to global.emis.mx[%.0f,%.0f] for grid center=[%f,%f]\n',
#          this.fn, GEIA.emis.grid.val, i.lon, i.lat, lon, lat))
#   end debug
      } else {
        # error if overwriting presumably-previously-written non-NA!
        cat(sprintf(
          'ERROR: %s: overwriting val=%f with val=%f at global.emis.mx[%.0f,%.0f] for grid center=[%f,%f]\n',
          this.fn, global.emis.mx[i.lat, i.lon], GEIA.emis.grid.val,
          i.lon, i.lat, lon, lat))
        return # TODO: abend
      } # end testing target != NA (thus not previously written)
    } # end testing source != NA (don't write if is.na(lookup)
  } # end for loop over lats
} # end for loop over lons

# Now draw the damn thing
# 1: TODO: FIXME: why do I need to transpose global.emis.mx?
image(lon.vec, lat.vec, t(global.emis.mx))
# 2,3,4: how it should work ?!?
# image(lon.vec, lat.vec, global.emis.mx)
map(add=TRUE)
# </visual input check>

# write output to netCDF
library(ncdf4)

# output file path (not currently used by package=ncdf4)
netcdf.fp <- sprintf('%s/%s', netcdf.dir, netcdf.fn)

# create dimensions and dimensional variables
time.vec <- c(0) # annual value, corresponding to no specific year
time.dim <- ncdim_def(
  name=time.var.name,
  units=time.var.units,
  vals=time.vec,
  unlim=TRUE,
  create_dimvar=TRUE,
  calendar=time.var.calendar,
  longname=time.var.long_name)

lon.dim <- ncdim_def(
  name=lon.var.name,
  units=lon.var.units,
  vals=lon.vec,
  unlim=FALSE,
  create_dimvar=TRUE,
  longname=lon.var.long_name)

lat.dim <- ncdim_def(
  name=lat.var.name,
  units=lat.var.units,
  vals=lat.vec,
  unlim=FALSE,
  create_dimvar=TRUE,
  longname=lat.var.long_name)

# create data variable (as container--can't put data until we have a file)
emis.var <- ncvar_def(
  name=emis.var.name,
  units=emis.var.units,
#  dim=c(time.dim, lat.dim, lon.dim),
#  dim=list(time.dim, lat.dim, lon.dim),
# note dim order desired for result=var(time, lat, lon)
  dim=list(lon.dim, lat.dim, time.dim),
  missval=as.double(emis.var._FillValue),
  longname=emis.var.long_name,
  prec="double")

# get current time for creation_date
# system(intern=TRUE) -> return char vector, one member per output line)
netcdf.timestamp <- system('date', intern=TRUE)

# create netCDF file
netcdf.file <- nc_create(
  filename=netcdf.fn,
#  vars=list(emis.var),
#  verbose=TRUE)
  vars=list(emis.var))

# Write data to data variable: gotta have file first.
# Gotta convert 2d global.emis.mx[lat,lon] to 3d global.emis.arr[time,lat,lon]
# Do this before adding _FillValue to prevent:
# > Error in R_nc4_put_vara_double: NetCDF: Not a valid data type or _FillValue type mismatch
## global.emis.arr <- global.emis.mx
## dim(global.emis.arr) <- c(1, dim(global.emis.mx))
## global.emis.arr[1,,] <- global.emis.mx

# Note
# * global.emis.mx[lat,lon]
# * datavar needs [lon, lat, time] (with time *last*)

ncvar_put(
  nc=netcdf.file,
  varid=emis.var,
#  vals=global.emis.arr,
  vals=t(global.emis.mx),
#  start=rep.int(1, length(dim(global.emis.arr))),
  start=c(1, 1, 1),
#  count=dim(global.emis.arr))
  count=c(-1,-1, 1)) # -1 -> all data

# Write netCDF attributes
# Note: can't pass *.dim as varid, even though these are coordinate vars :-(

# add datavar attributes
ncatt_put(
  nc=netcdf.file,
#  varid=lon.var,
  varid=lon.var.name,
  attname="comment",
  attval=lon.var.comment,
  prec="text")

ncatt_put(
  nc=netcdf.file,
#  varid=lat.var,
  varid=lat.var.name,
  attname="comment",
  attval=lat.var.comment,
  prec="text")

# put _FillValue after putting data!
ncatt_put(
  nc=netcdf.file,
  varid=emis.var,
  attname="_FillValue",
  attval=emis.var._FillValue,
  prec="float") # why is "emi_n2o:missing_value = -999."?

# add global attributes (varid=0)
ncatt_put(
  nc=netcdf.file,
  varid=0,
  attname="creation_date",
  attval=netcdf.timestamp,
  prec="text")

ncatt_put(
  nc=netcdf.file,
  varid=0,
  attname="source_file",
  attval=netcdf.source_file,
  prec="text")

ncatt_put(
  nc=netcdf.file,
  varid=0,
  attname="Conventions",
  attval=netcdf.Conventions,
  prec="text")

# flush to file (there may not be data on disk before this point)
# nc_sync(netcdf.file) # so we don't hafta reopen the file, below
# Nope: per David W. Pierce Mon, 27 Aug 2012 21:35:35 -0700, ncsync is not enough
nc_close(netcdf.file)
nc_open(netcdf.fn,
        write=FALSE,    # will only read below
        readunlim=TRUE) # it's a small file

# <simple output check>
system(sprintf('ls -alth %s', netcdf.fp))
system(sprintf('ncdump -h %s', netcdf.fp))
# </simple output check>

# <visual output check>
# TODO: do plot-related refactoring! allow to work with projects={ioapi, this}
# <copied from plotLayersForTimestep.r>
library(fields)
# double-sprintf-ing to set precision by constant: cool or brittle?
stats.precision <- 3 # sigdigs to use for min, median, max of obs
stat.str <- sprintf('%%.%ig', stats.precision)
# use these in function=subtitle.stats as sprintf inputs
max.str <- sprintf('max=%s', stat.str)
med.str <- sprintf('med=%s', stat.str)
min.str <- sprintf('min=%s', stat.str)
# </copied from plotLayersForTimestep.r>

# Get the data out of the datavar, to test reusability
# target.data <- emis.var[,,1] # fails, with
# > Error in emis.var[, , 1] : incorrect number of dimensions
target.data <- ncvar_get(
  nc=netcdf.file,
#  varid=emis.var,
  varid=emis.var.name,
  # read all the data
#  start=rep(1, emis.var$ndims),
  start=c(1, 1, 1),
#  count=rep(-1, emis.var$ndims)) 
  count=c(-1, -1, 1))
# MAJOR: all of the above fail with
# > Error in if (nc$var[[li]]$hasAddOffset) addOffset = nc$var[[li]]$addOffset else addOffset = 0 : 
# >   argument is of length zero

# Note that, if just using the raw data, the following plot code works.
target.data <- t(global.emis.mx)
# <simple output check/>
dim(target.data) # n.lon, n.lat

# <copied from windowEmissions.r>
palette.vec <- c("grey","purple","deepskyblue2","green","yellow","orange","red","brown")
colors <- colorRampPalette(palette.vec)
probabilities.vec <- seq(0, 1, 1.0/(length(palette.vec) - 1))
# </copied from windowEmissions.r>

# <copy/mod from plotLayersForTimestep.r>
plot.layer(target.data,
  title=netcdf.title,
  subtitle=subtitle.stats(target.data),
  x.centers=lon.vec,
  y.centers=lat.vec,
  q.vec=probabilities.vec,
  colors=colors)
# </copy/mod from plotLayersForTimestep.r>
map(add=TRUE)
# </visual output check>

# teardown
dev.off()
nc_close(netcdf.file)
