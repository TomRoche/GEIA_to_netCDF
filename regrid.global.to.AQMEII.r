# R code to write GEIA emissions from the distributed text format
# (space separated values, 10-line header, no comments)
# to netCDF format. Unfortunately all hardcoded.
# If running manually in R console, remember to run setup actions from GEIA_to_netCDF/regrid_GEIA_netCDF.sh

# libraries also read separately below, for input and output processing
library(ncdf4)
library(fields)
library(maptools)
# run if rgeos not available
# gpclibPermit()
library(rgdal)
library(raster)
data(wrld_simpl) # from maptools

# constants-----------------------------------------------------------

this.fn <- 'regrid.global.to.AQMEII.r'  # TODO: get like $0

test.dir <- Sys.getenv('TEST_DIR') # set in driver script; MUST exist
pdf.dir <- Sys.getenv('PDF_DIR')   # set in driver script; MUST exist
pdf.fp <- Sys.getenv('PDF_FP')     # set in driver script

pdf.er <- Sys.getenv('PDF_VIEWER')
in.fp <- Sys.getenv('DATA_INPUT_FP')
in.band <- Sys.getenv('DATA_INPUT_BAND')
data.var.name <- Sys.getenv('DATA_VAR_NAME')
template.in.fp <- Sys.getenv('TEMPLATE_INPUT_FP')
template.band <- Sys.getenv('TEMPLATE_INPUT_BAND')
# coordinate reference system
# out.crs <- '+proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +x_0=-2556 +y_0=-1728'
# Per RWP, make x,y units=meters (to match map, etc)
out.crs <- '+proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +x_0=-2556000 +y_0=-1728000'
out.fp <- Sys.getenv('DATA_OUTPUT_FP')

# package=raster map, for raster::plot
# map.us.unproj <- wrld_simpl[wrld_simpl$ISO3 == 'USA', ]  # unprojected
# map.us.proj <- spTransform(map.us.unproj, CRS(out.crs))  # projected
# use world map for now? fails
# map.us.unproj <- wrld_simpl                              # unprojected
map.us.unproj <-
#  wrld_simpl[wrld_simpl$ISO3 == 'CAN', wrld_simpl$ISO3 == 'MEX', wrld_simpl$ISO3 == 'USA', ]
#  wrld_simpl[wrld_simpl$ISO3 == 'CAN,MEX,USA', ]
  wrld_simpl[wrld_simpl$ISO3 %in% c('CAN', 'MEX', 'USA'),]
map.us.proj <- spTransform(map.us.unproj, CRS(out.crs))  # projected

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

stat.script.fp <- Sys.getenv('STAT_SCRIPT_FP')
source(stat.script.fp)
plot.script.fp <- Sys.getenv('PLOT_SCRIPT_FP')
source(plot.script.fp)

# payload-------------------------------------------------------------

system(sprintf('ncdump -h %s', in.fp))
# netcdf GEIA_N2O_oceanic {
# dimensions:
#         lon = 360 ;
#         lat = 180 ;
#         time = UNLIMITED ; // (1 currently)
# variables:
#         double lon(lon) ;
# ...
#         double lat(lat) ;
# ...
#         double time(time) ;
# ...
#         double emi_n2o(time, lat, lon) ;
#                 emi_n2o:units = "ton N2O-N/yr" ;
#                 emi_n2o:missing_value = -999. ;
#                 emi_n2o:long_name = "N2O emissions" ;
#                 emi_n2o:_FillValue = -999.f ;

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

# make template raster for extents
# look @ input to template/extents raster: truncate 'ncdump' to avoid IOAPI cruft
system(sprintf('ncdump -h %s | head -n 13', template.in.fp))
# netcdf emis_mole_all_20080101_12US1_cmaq_cb05_soa_2008ab_08c.EXTENTS_INPUT {
# dimensions:
#         TSTEP = UNLIMITED ; // (25 currently)
#         LAY = 1 ;
#         ROW = 299 ;
#         COL = 459 ;
# variables:
#         float emi_n2o(TSTEP, LAY, ROW, COL) ;
#                 emi_n2o:long_name = "XYL             " ;
#                 emi_n2o:units = "moles/s         " ;
#                 emi_n2o:var_desc = "Model species XYL                                                               " ;

template.in.raster <- raster(template.in.fp, varname=data.var.name, band=template.band)
template.raster <- projectExtent(template.in.raster, crs=out.crs)
# Warning message:
# In projectExtent(template.in.raster, out.crs) :
#   158 projected point(s) not finite

# is that "projected point(s) not finite" warning important? Probably not, per Hijmans

template.raster
# should resemble the domain specification @
# https://github.com/TomRoche/cornbeltN2O/wiki/AQMEII-North-American-domain#wiki-EPA
# using CRS with x,y units=m
# class       : RasterLayer 
# dimensions  : 299, 459, 137241  (nrow, ncol, ncell)
# resolution  : 53369.55, 56883.69  (x, y)
# extent      : -14802449, 9694173, -6258782, 10749443  (xmin, xmax, ymin, ymax)
# coord. ref. : +proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +x_0=-2556000 +y_0=-1728000 +ellps=WGS84 

out.raster <-
  projectRaster(
#    from=in.raster, to=template.raster, method='bilinear', # why no CRS?
    from=in.raster, to=template.raster, method='bilinear', crs=out.crs,
    overwrite=TRUE, progress='window', format='CDF',
    # args from writeRaster
    NAflag=-999.0,  # match emi_n2o:missing_value,_FillValue (TODO: copy)
    varname=data.var.name, 
    varunit='ton N2O-N/yr',
    longname='N2O emissions',
    xname='COL',
    yname='ROW',
    filename=out.fp)
out.raster
# made with CRS
#> class       : RasterLayer 
#> dimensions  : 299, 459, 137241  (nrow, ncol, ncell)
#> resolution  : 53369.55, 56883.69  (x, y)
#> extent      : -14802449, 9694173, -6258782, 10749443  (xmin, xmax, ymin, ymax)
# ??? why still proj=longlat ???
#> coord. ref. : +proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0 
#> data source : /home/rtd/code/R/GEIA_to_netCDF/GEIA_N2O_oceanic_regrid.nc
#> names       : N2O.emissions 
#> zvar        : emi_n2o 

system(sprintf('ls -alht %s', test.dir))
system(sprintf('ncdump -h %s', out.fp))
# netcdf GEIA_N2O_oceanic_regrid {
# dimensions:
#   COL = 459 ;
#   ROW = 299 ;
# variables:
#   double COL(COL) ;
#       COL:units = "meter" ;
#       COL:long_name = "COL" ;
#   double ROW(ROW) ;
#       ROW:units = "meter" ;
#       ROW:long_name = "ROW" ;
#   float emi_n2o(ROW, COL) ;
#       emi_n2o:units = "ton N2O-N/yr" ;
#       emi_n2o:missing_value = -999.f ;
#       emi_n2o:_FillValue = -999.f ;
#       emi_n2o:long_name = "N2O emissions" ;
#       emi_n2o:projection = "+proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +x_0=-2556000 +y_0=-1728000 +ellps=WGS84" ;
#       emi_n2o:projection_format = "PROJ.4" ;
#       emi_n2o:min = 5.9605e-08f ;
#       emi_n2o:max = 783.92f ;

netCDF.stats.to.stdout(netcdf.fp=out.fp, var.name=data.var.name)
# For /tmp/projectRasterTest/GEIA_N2O_oceanic_regrid.nc var=emi_n2o
#   cells=137241
#   obs=53873
#   min=5.96e-08
#   q1=25.1
#   med=55.5
#   mean=81.1
#   q3=93.1
#   max=784

# plot to PDF---------------------------------------------------------
# repeat for each plot file
pdf(file=pdf.fp, width=5.5, height=4.25)

# plot page 1: just plot----------------------------------------------
# plot(out.raster, data.var.name) # only if RasterBrick or RasterStack
plot(out.raster)
# add a projected CONUS map
plot(map.us.proj, add=TRUE)

# plot page 2: try setting plot extents-------------------------------
plot(out.raster, ext=template.raster)
plot(map.us.proj, add=TRUE)

# plot page 3: try raster::crop---------------------------------------
template.raster.extent <- extent(template.raster)
out.raster.crop <-
  # overwrite the uncropped file
  crop(out.raster, template.raster.extent, filename=out.fp, overwrite=TRUE)

# start debugging
out.raster.crop
# same as out.raster (?)
netCDF.stats.to.stdout(netcdf.fp=out.fp, var.name=data.var.name)
# same as out.raster
#   end debugging

plot(out.raster.crop)
plot(map.us.proj, add=TRUE)

# start image.plot----------------------------------------------------

# plot.raster(
#   raster=out.raster,
#   title="foo",
#   subtitle="bar",
#   q.vec=probabilities.vec,
#   colors,
#   map.cmaq
# )
# step through plot.raster

title <- "foo"
subtitle <- "bar"
q.vec <- probabilities.vec
x.centers <- raster.centers.x(out.raster)
y.centers <- raster.centers.y(out.raster)
# fails to set dimensions correctly! -> [1] 137241      1
out.data <- as.matrix(values(out.raster))
quantiles <- quantile(c(out.data), q.vec, na.rm=TRUE)
quantiles.formatted <- format(as.numeric(quantiles), digits=3)

# page 4--------------------------------------------------------------
# close! data is recognizable, but North America position is mirrored

dim(out.data) <- c(length(x.centers), length(y.centers)) # cols, rows
# start debugging
dim(out.data)
#> [1] 459 299
#   end debugging

# plot.data(out.data, title, subtitle, x.centers, y.centers, q.vec, colors, map.cmaq)
# step through plot.data
plot.list <- list(x=x.centers, y=y.centers, z=out.data)

image.plot(plot.list, xlab="", ylab="", axes=F, col=colors(100),
  axis.args=list(at=quantiles, labels=quantiles.formatted),
  main=title)
# map(add=TRUE) # not defined here
lines(map.cmaq)

#   end image.plot----------------------------------------------------

# flush to the plot device
dev.off()
