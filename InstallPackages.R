source("https://bioconductor.org/biocLite.R")
biocLite(pkgs=c('EBImage','flowCore'), ask=F)
install.packages(pkgs = c('shiny','tiff','reshape','RODBC','foreach','doParallel','stringi','naturalsort','rChoiceDialogs'))
