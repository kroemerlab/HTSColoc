# HTSColoc
R functions allowing for the assessment of colocalization in a High-Througput fashion

requirements
-----------

The provided piece of code was tested on both Linux (Ubuntu 16.04) and Windows (Windows 7) distributions. It has not been tested on Mac OS but should theoretically work. In any case, you will need to have the proper Java version (64 or 32 bits according to your machine) installed on your computer in the aim to have rJava package added to R.

For Linux distributions, you might need to install additionnal packages such as fftw3 so that you can install the R tiff package:

- sudo apt-get install libfftw3-dev libfftw3-doc


installation
------------

Before using the provided function you will obviously need to have R installed:

- https://www.r-project.org/ 

I advise you to use a GUI, such as RStudio, to make its use simpler:

- https://www.rstudio.com/

You will need to have a few packages installed. For doing so, open R and run these lines in the console:

- source("https://bioconductor.org/biocLite.R")
- biocLite(pkgs=c('EBImage','flowCore'), ask=F)
- install.packages(pkgs = c('shiny','tiff','reshape','RODBC','foreach','doParallel','stringi','naturalsort','rChoiceDialogs'))

or simply source the InstallPackages.R after opening it with R.

usage
------------
Open RGui/RStudio and open the provided scripts ```GetImInfo.R```,```GetAllSQLInfo-FAST.R```,```ColocPixelAnalysis_Func.R```. After sourcing each of them, you can type in the console :

- coloc.HTS(getImInfo(SQL.use = F)[[1]])

A window will open to select the location of the images you want to analyze. If you want to see a more detailed description of the functions and their arguments, please refer to ```Function description.txt```

file format
------------
```GetImInfo.R``` will only run with a specific nomenclature regarding images names.

- First, the images will need to be in *.tiff file format.
- The names should be given according to the well, site, and channel that have been acquired : *ExpName*_*WellName*_s*SiteNumber*_w*ChannelNumber* 

For example, if you have acquired an image from the well A01 of a plate, on site 1, using the first channel of your microscope, its name should be ```MyExp_A01_s1_w1.TIF```

