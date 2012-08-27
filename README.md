Uses [R][] code to convert [GEIA][] geospatial data from its quirky [native format][GEIA native format] to [netCDF]. Currently does not provide a clean or general-purpose solution! but merely shows code to convert one GEIA file to netCDF using R, with packages [ncdf4][] and [fields][].

[R]: http://en.wikipedia.org/wiki/R_%28programming_language%29
[GEIA]: http://www.geiacenter.org/
[GEIA native format]: /TomRoche/GEIA_to_netCDF/blob/master/GEIA_readme.txt
[netCDF]: http://en.wikipedia.org/wiki/NetCDF#Format_description
[ncdf4]: http://cran.r-project.org/web/packages/ncdf4/
[fields]: http://cran.r-project.org/web/packages/fields/

To run the example (yes, it's crude right now!):

1. Clone this repo.
2. Download [the sample data][GEIA sample N2O data] to the folder containing your clone.
3. Start an R console in that folder.
4. Run the [R example][sample R code].

[GEIA sample N2O data]: /downloads/TomRoche/GEIA_to_netCDF/N2OOC90Y.1A
[sample R code]: /TomRoche/GEIA_to_netCDF/blob/master/GEIA.to.netCDF.r
