Uses [R][] code to convert [GEIA][] geospatial data from its quirky [native format][GEIA native format] to [netCDF]. Currently does not provide a clean or general-purpose solution! but merely shows code to convert one GEIA file to netCDF using R, with packages [ncdf4][] and [fields][].

[R]: http://en.wikipedia.org/wiki/R_%28programming_language%29
[GEIA]: http://www.geiacenter.org/
[GEIA native format]: /TomRoche/GEIA_to_netCDF/blob/master/GEIA_readme.txt
[netCDF]: http://en.wikipedia.org/wiki/NetCDF#Format_description
[ncdf4]: http://cran.r-project.org/web/packages/ncdf4/
[fields]: http://cran.r-project.org/web/packages/fields/

To run the examples:

1. Clone this repo.
2. `cd` to its working directory.

To run the first example:

1. Open the driver (bash) script `GEIA_to_netCDF.sh`! You will probably need to edit it to make it work on your platform. Notably you will probably want to point it to your R and PDF viewer.
2. Run the driver:
    `$ ./GEIA_to_netCDF.sh`
3. This will download input, then run an R script to convert the input to a netCDF file, and plot that file.
4. After the R script exits, the driver should display the PDF (if properly configured in step=3). The most recent version of the PDF is also available for [download](https://github.com/downloads/TomRoche/GEIA_to_netCDF/GEIA_N2O_oceanic.pdf).
