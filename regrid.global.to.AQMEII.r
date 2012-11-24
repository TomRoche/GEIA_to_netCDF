# R code to write GEIA emissions from the distributed text format
# (space separated values, 10-line header, no comments)
# to netCDF format. Unfortunately all hardcoded.
# If running manually in R console, remember to run setup actions from GEIA_to_netCDF/regrid_GEIA_netCDF.sh

library(ncdf4)
library(fields)
library(maptools)
# run if rgeos not available
# gpclibPermit()
library(rgdal)
library(raster)
library(M3) # for extents calculation
data(wrld_simpl) # from maptools

# constants-----------------------------------------------------------

this.fn <- 'regrid.global.to.AQMEII.r'  # TODO: get like $0

# all the following env vars must be set and exported in driver script
test.dir <- Sys.getenv('TEST_DIR')
pdf.dir <- Sys.getenv('PDF_DIR')
pdf.fp <- Sys.getenv('PDF_FP')
pdf.er <- Sys.getenv('PDF_VIEWER')
in.fp <- Sys.getenv('DATA_INPUT_FP')
in.band <- Sys.getenv('DATA_INPUT_BAND')
data.var.name <- Sys.getenv('DATA_VAR_NAME')
template.in.fp <- Sys.getenv('TEMPLATE_INPUT_FP')
template.band <- Sys.getenv('TEMPLATE_INPUT_BAND')
out.fp <- Sys.getenv('DATA_OUTPUT_FP')

# coordinate reference system:
# use package=M3 to get CRS from template file
out.crs <- get.proj.info.M3(template.in.fp)
cat(sprintf('out.crs=%s\n', out.crs)) # debugging
# out.crs=+proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +a=6370000 +b=6370000

stat.script.fp <- Sys.getenv('STAT_SCRIPT_FP')
source(stat.script.fp) # produces errant error=
#> netCDF.stats.to.stdout.r: no arguments supplied, exiting
plot.script.fp <- Sys.getenv('PLOT_SCRIPT_FP')
source(plot.script.fp)

# if any of the above failed, check how you ran (e.g., `source`d) driver script
# plot constants below

# payload-------------------------------------------------------------

# check input

system(sprintf('ncdump -h %s', in.fp))
# netcdf GEIA_N2O_oceanic {
# dimensions:
#   lon = 360 ;
#   lat = 180 ;
#   time = UNLIMITED ; // (1 currently)
# variables:
#   double lon(lon) ;
# ...
#   double lat(lat) ;
# ...
#   double time(time) ;
# ...
#   double emi_n2o(time, lat, lon) ;
#     emi_n2o:units = "ton N2O-N/yr" ;
#     emi_n2o:missing_value = -999. ;
#     emi_n2o:long_name = "N2O emissions" ;
#     emi_n2o:_FillValue = -999.f ;

# Note missing/fill values: more below.

netCDF.stats.to.stdout(netcdf.fp=in.fp, var.name=data.var.name)
# For /tmp/projectRasterTest/GEIA_N2O_oceanic.nc var=emi_n2o
#       cells=64800
#       obs=36143
#       min=5.96e-08
#       q1=30.4
#       med=67.7
#       mean=99.5
#       q3=140
#       max=1.17e+03
# Note min and max of the input, and that min > 0.

# make input raster

in.raster <- raster(in.fp, varname=data.var.name, band=in.band)
in.raster
# class       : RasterLayer 
# dimensions  : 180, 360, 64800  (nrow, ncol, ncell)
# resolution  : 1, 1  (x, y)
# extent      : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
# coord. ref. : +proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0 
# values      : /tmp/projectRasterTest/GEIA_N2O_oceanic.nc 
# layer name  : N2O.emissions 
# z-value     : 0 
# zvar        : emi_n2o 

# make template raster to format output.
# Note below that one should be able to projectRaster(...) with a resolution (i.e.,
# from=in.raster, res=c(12e3, 12e3), crs=out.crs,
# ) as well as a template (i.e.,
# from=in.raster, to=template.raster, crs=out.crs,
# ). So why create a template? Because just giving a resolution hangs.

# look @ input (one of the PHASE AQ inputs) to template/extents raster:
# truncate 'ncdump' to avoid IOAPI cruft
system(sprintf('ncdump -h %s | head -n 13', template.in.fp))
# netcdf emis_mole_all_20080101_12US1_cmaq_cb05_soa_2008ab_08c.EXTENTS_INPUT {
# dimensions:
#   TSTEP = UNLIMITED ; // (25 currently)
#   LAY = 1 ;
#   ROW = 299 ;
#   COL = 459 ;
# variables:
#   float emi_n2o(TSTEP, LAY, ROW, COL) ;
#     emi_n2o:long_name = "XYL             " ;
#     emi_n2o:units = "moles/s         " ;
#     emi_n2o:var_desc = "Model species XYL                                                               " ;

# use M3 to get extents from template file (thanks CGN!)
extents.info <- get.grid.info.M3(template.in.fp)
extents.xmin <- extents.info$x.orig
extents.xmax <- max(
  get.coord.for.dimension(
    file=template.in.fp, dimension="col", position="upper", units="m")$coords)
extents.ymin <- extents.info$y.orig
extents.ymax <- max(
  get.coord.for.dimension(
    file=template.in.fp, dimension="row", position="upper", units="m")$coords)
grid.res <- c(extents.info$x.cell.width, extents.info$y.cell.width) # units=m

template.extents <-
  extent(extents.xmin, extents.xmax, extents.ymin, extents.ymax)
template.extents

template.in.raster <- raster(template.in.fp, varname=data.var.name, band=template.band)
template.raster <- projectExtent(template.in.raster, crs=out.crs)
#> Warning message:
#> In projectExtent(template.in.raster, out.crs) :
#>   158 projected point(s) not finite
# is that "projected point(s) not finite" warning important? Probably not, per Hijmans
template.raster@extent <- template.extents
# should resemble the domain specification @
# https://github.com/TomRoche/cornbeltN2O/wiki/AQMEII-North-American-domain#wiki-EPA
template.raster
# class       : RasterLayer 
# dimensions  : 299, 459, 137241  (nrow, ncol, ncell)
# resolution  : 12000, 12000  (x, y)
# extent      : -2556000, 2952000, -1728000, 1860000  (xmin, xmax, ymin, ymax)
# coord. ref. : +proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +a=6370000 +b=6370000 

# start debug---------------------------------------------------------
# regrid.start.time <- system('date', intern=TRUE)
# regrid.start.str <- sprintf('start regrid @ %s', regrid.start.time)
# cat(sprintf('%s\n', regrid.start.str))
#   end debug---------------------------------------------------------

# at last: do the regridding
out.raster <-
  projectRaster(
    # give a template with extents--fast, but gotta calculate extents
    from=in.raster, to=template.raster, crs=out.crs,
    # give a resolution instead of a template? no, that hangs
#    from=in.raster, res=grid.res, crs=out.crs,
    method='bilinear', overwrite=TRUE, format='CDF',
    # args from writeRaster
    NAflag=-999.0,  # match emi_n2o:missing_value,_FillValue (TODO: copy)
    varname=data.var.name, 
    varunit='ton N2O-N/yr',
    longname='N2O emissions',
    xname='COL',
    yname='ROW',
    filename=out.fp)
# above fails to set CRS, so
out.raster@crs <- CRS(out.crs)
out.raster
# class       : RasterLayer 
# dimensions  : 299, 459, 137241  (nrow, ncol, ncell)
# resolution  : 12000, 12000  (x, y)
# extent      : -2556000, 2952000, -1728000, 1860000  (xmin, xmax, ymin, ymax)
# coord. ref. : +proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +a=6370000 +b=6370000 
# data source : /home/rtd/code/R/GEIA_to_netCDF/GEIA_N2O_oceanic_regrid.nc 
# names       : N2O.emissions 
# zvar        : emi_n2o 

# start debug---------------------------------------------------------
# regrid.end.time <- system('date', intern=TRUE)
# cat(sprintf('  end regrid @ %s\n', regrid.end.time))
# cat(sprintf('%s\n', regrid.start.time))
#   end debug---------------------------------------------------------

system(sprintf('ls -alht %s', test.dir))
system(sprintf('ncdump -h %s', out.fp))
# netcdf GEIA_N2O_oceanic_regrid {
# dimensions:
#   COL = 459 ;
#   ROW = 299 ;
# variables:
#   double COL(COL) ;
#     COL:units = "meter" ;
#     COL:long_name = "COL" ;
#   double ROW(ROW) ;
#     ROW:units = "meter" ;
#     ROW:long_name = "ROW" ;
#   float emi_n2o(ROW, COL) ;
#     emi_n2o:units = "ton N2O-N/yr" ;
#     emi_n2o:_FillValue = -999. ;
#     emi_n2o:missing_value = -999. ;
#     emi_n2o:long_name = "N2O emissions" ;
#     emi_n2o:projection = "+proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +a=6370000 +b=6370000" ;
#     emi_n2o:projection_format = "PROJ.4" ;
#     emi_n2o:min = 0.83728 ;
#     emi_n2o:max = 522.693774638276 ;
# ...

netCDF.stats.to.stdout(netcdf.fp=out.fp, var.name=data.var.name)
# For ./GEIA_N2O_oceanic_regrid.nc var=emi_n2o
#   cells=137241
#   obs=46473
#   min=0.837
#   q1=11.9
#   med=54.1
#   mean=71.9
#   q3=85.5
#   max=523

# plot to PDF---------------------------------------------------------

# plot constants

# maps from package=raster
# map.us.unproj <- wrld_simpl[wrld_simpl$ISO3 == 'USA', ]  # unprojected
# map.us.proj <- spTransform(map.us.unproj, CRS(out.crs))  # projected
# do North America instead
map.us.unproj <- wrld_simpl[wrld_simpl$ISO3 %in% c('CAN', 'MEX', 'USA'),]
map.us.proj <-
  spTransform(map.us.unproj, CRS(out.crs)) # projected

title <- 'GEIA annual oceanic N2O regridded to AQMEII-NA'
units <- '(ton N2O-N/yr)' # TODO: get this from netCDF file
# combine them. TODO: how to make units smaller, italicized?
title <- sprintf('%s\n%s', title, units)

out.data.vec <- getValues(out.raster) # raster data as vector
subtitle <- subtitle.stats(out.data.vec)

# package=M3 map for fields::image.plot
map.table.fp <- Sys.getenv('MAP_TABLE_FP')
map.cmaq <- read.table(map.table.fp, sep=",")
palette.vec <- c(
# original from KMF, 3 colors added to get deciles in probabilities.vec
  #              R color
  #                code
  "grey",         # 260
  "purple",       # 547
  "deepskyblue2", # 123  
  "green",        # 254
  "greenyellow",  # 259
  "yellow",       # 652
  "orange",       # 498
  "orangered",    # 503
  "red",          # 552
  "red4",         # 556
  "brown"         #  32
)
colors <- colorRampPalette(palette.vec)
# used for quantiling legend
probabilities.vec <- seq(0, 1, 1.0/(length(palette.vec) - 1))
# probabilities.vec
# [1] 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0

x.centers <- raster.centers.x(out.raster)
y.centers <- raster.centers.y(out.raster)
quantiles <- quantile(out.data.vec, probabilities.vec, na.rm=TRUE)
quantiles.formatted <- format(as.numeric(quantiles), digits=3)

# repeat for each plot file
pdf(file=pdf.fp, width=5.5, height=4.25)

# plot page 1: raster::plot-------------------------------------------
# plot(out.raster, main=title, sub=subtitle) # works
plot(out.raster, # remaining args from image.plot
  main=title, sub=subtitle,
  xlab='', ylab='', axes=F, col=colors(100),
  axis.args=list(at=quantiles, labels=quantiles.formatted))
# add a projected CONUS map
plot(map.us.proj, add=TRUE)

# plot page 2: fields::image.plot-------------------------------------

plot.raster(
  raster=out.raster,
  title=title, 
  subtitle=subtitle,
  q.vec=probabilities.vec,
  colors,
  map.cmaq
)

# step through plot.raster:
# package=fields needs data as matrix, not vector
# out.data.mx <- out.data.vec
# dim(out.data.mx) <- c(length(x.centers), length(y.centers)) # cols, rows
# plot.data(out.data.mx, title, subtitle, x.centers, y.centers, probabilities.vec, colors, map.cmaq)

# step through plot.data
# plot.list <- list(x=x.centers, y=y.centers, z=out.data.mx)
# image.plot(plot.list, xlab='', ylab='', axes=F, col=colors(100),
#   axis.args=list(at=quantiles, labels=quantiles.formatted),
#   main=title, sub=subtitle)
# lines(map.cmaq)

#   end image.plot----------------------------------------------------

# flush the plot device
dev.off()
