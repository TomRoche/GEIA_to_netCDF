Uses [R][] code to

1. convert [GEIA][] geospatial data from its quirky [native format][GEIA native format] to [netCDF].
2. "regrid" netCDF from global/unprojected to a projected subdomain.

Currently does not provide a clean or general-purpose solution! but merely shows how to do these tasks using R, with notable packages including

* [ncdf4][]
* [fields][]
* [raster][]

[R]: http://en.wikipedia.org/wiki/R_%28programming_language%29
[GEIA]: http://www.geiacenter.org/
[GEIA native format]: /TomRoche/GEIA_to_netCDF/blob/master/GEIA_readme.txt
[netCDF]: http://en.wikipedia.org/wiki/NetCDF#Format_description
[ncdf4]: http://cran.r-project.org/web/packages/ncdf4/
[fields]: http://cran.r-project.org/web/packages/fields/
[raster]: http://cran.r-project.org/web/packages/raster/

To run either example:

1. Clone this repo.
2. `cd` to its working directory.

To run the first example (conversion):

1. Open the driver (bash) script `GEIA_to_netCDF.sh` in an editor! You will probably need to edit it to make it work on your platform. Notably you will probably want to point it to your R and PDF viewer.
2. Run the driver:
    `$ ./GEIA_to_netCDF.sh`
3. This will download input, then run an R script to convert the input to a netCDF file, and plot that file.
4. After the R script exits, the driver should display the PDF (if properly configured in step=3). The most recent version of the PDF is also available for [download](https://github.com/downloads/TomRoche/GEIA_to_netCDF/GEIA_N2O_oceanic.pdf).

This appears to successfully complete the task.

To run the second example (regridding, which takes as input the output from the conversion example):

1. Similarly open/edit the driver script `regrid_GEIA_netCDF.sh` and make required changes.
2. Run the driver:
    `$ ./regrid_GEIA_netCDF.sh`
3. This will similarly setup and run an R script to regrid the netCDF, and plot the output.
4. After the R script exits, the driver should display the PDF (if properly configured in step=3). For this example, the PDF currently has multiple pages. The most recent version of the PDF is also available for [download][regridding plot].

Currently, the regridded data appears to be correct in page 1 of the [regridding plot][], which is produced by `raster::plot`. However there are obvious problems (e.g., data orientation, map position) with page 2, which is produced by `fields::image.plot`.

[regridding plot]: https://github.com/downloads/TomRoche/GEIA_to_netCDF/GEIA_N2O_oceanic_regrid.pdf
