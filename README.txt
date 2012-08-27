following copied from
http://geiacenter.org/presentData/geiadfrm.html

Data Format

Overall Structure of Data Files

GEIA Inventories include a 10 line header followed by the data. Documentation is provided in separate files. The file structures and formats are set up for ease of reading and viewing by a wide variety of users.

For hints on checking to see that you downloaded your data correctly, visit the data checking page.

Tools:

Download the fortran program readGeia.f

http://geiacenter.org/other/readgeia.zip

or view the program [see end of this file, or ./readgeia.f]. It contains a program that will read the data into arrays. It can be used as a starting point to put the data into a format needed.

The data files are compressed using the pkzip utilities. If the user does not have the software to de-compress the files it can be downloaded as shareware from the pk-zip site.

GEIA Headers

There are 10 lines of header information.

line 1:         
[n chars    content]
15          GEIA label
15          filename
10          file creation date

line 2:         
10          specie
10          reference year for the data
10          resolution of the data (monthly, seasonal or annual)
20          units (metric units chosen to best capture the range of values for the chemical) 
2           number of levels

line 3:     Documentation name and location plus contact persons' complete address

lines 4-10: Data range and additional clarifying information. Format for the data.

> GEIA label:

> This is a general identifier common to all GEIA data bases. The label identifies each file as a GEIA file and list the type of file. The labels are as follows: "GEIA Inventory" Data for one of the species "GEIA Document" Documention for one of the inventories "GEIA Auxiliary" Additional information (e.g., population files).

> File names:

> The file name includes the following: specie, reference year for the data, temporal period, number of levels, and the inventory version. See the description below. 

> Example:  for filename: SO285sn1.1a = SO2, seasonal resolution, one level, version 1a Species: SO2, NOX, VOC, CO, ... Year: 85, 90, ... Temporal resolution of the data: by month, season, or annually denoted as mn, sn, yr Inventory Version: 1a, 1b,....., 2a, 2b,..... The corresponding header for this inventory would be:

> GEIA Inventory SO285sn1.1a    28 Jun 94 
> SO2       1985      seasonal  tons/yr             1
> Documentation in Hopkins et al. Documentation Name Here
> Contact: D. Hopkins, Science & Policy, 2385 Panorama Ave 
> Boulder Co 80304  
> FAX: 303-442-6958  Phone: (303) 442-6866  E-mail: hopkins@rmii.com

> Values: minimum: .6 maximum: 59.9528 sum: 4834.03 million tonnes C

> Data Structure

> Each line of data consists of an integer grid number and real specie values for the temporal resolution of the data, for each level with the format (I6,1x,12(E10.6,1x)). The E10.6 can be varied slightly to E10.x where x is the preferred decimal level for the inventory being presented. The specific metric units used are chosen to best accommodate the range of values. The format is chosen for ease of reading and viewing information by a wide variety of users. Given the wide variation of emissions magnitudes for some chemicals, the E format is adopted.

> Given the variability in number of levels and temporal resolution for different inventories, the following guidelines are presented. If the specie data is provided with yearly resolution at one level only, then there is only one data point per line. If the species data is provided with seasonal or monthly resolution for one level only, then each line has 4 or 12 data points per line, depending on whether the information is available seasonally or monthly. The data in this case is listed with January first or winter first, again depending on whether the resolution is monthly or seasonal. If the species data is provided with annual resolution and multiple levels, then each data line has information for each of the levels going from 1 to the last level. If there are multiple levels and temporal resolution by month or season, then information for each level appears first with each data line containing values for each month or season. For example, for an inventory with two levels and seasonal resolution, then the data is presented for level one first with the information for each season appearing on each data line associated with each grid. These guidelines are different for the aircraft data. This information will be treated as a special case.

> Each data file contains at most (360x180 data lines) with the grid number starting at lower left. For the inventories where there are more than one levels and the temporal resolution is seasonal or monthly, then each data file contains at most (360x180) * #levels data lines. Any grid with zeros for the emissions is not included in the data file.

> Grid number is defined as follows:
> Grid Number = (j*1000) + i
> j   row number starting at 1 for 90S to 89S latitude, 
>     to 180 for 89N to 90N latitude

> i   column number starting at 1 for 180W to 179W longitude, 
>     to 360 for 179E to 180E longitude. 

> The coordinates represent the center of the grid.

> The latitude and longitude of the center of the grid is given by:
>     latitude = (j-91) + 0.5
>     longitude = (i-181) + 0.5

> Documentation on each inventory is prepared by the inventory developers. Notes on documentation can be found in the header information, and in "docs" directory when it is available.

> The following is a short fortran program that will read in the data and put it into arrays.

see ./readgeia.f
