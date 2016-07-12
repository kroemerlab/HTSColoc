library(EBImage)
library(tiff)
library(naturalsort)
library(reshape)
library(rChoiceDialogs)

library("parallel")
library("foreach")
library("doParallel")
library("iterators")

getImInfo = function(SERVER='MDCStore',coID = 'sa', coPD = 'moldev' ,PlateID,SQL.use = T,PlateLoc='...', TimeCourse=F){


if(SQL.use == T){
DB = MX.getAllSQLInfo(SERVER, coID, coPD)
MyPlate = DB[which(DB$PlateID==PlateID),]
PlateLoc = unique(MyPlate$PlateLoc)
}else{
  if(PlateLoc=='...')
  PlateLoc = rchoose.dir(caption = "Select images location")

}
  
if(missing(PlateID) & SQL.use==F){
  PlateID =NA
}else{
  if(missing(PlateID) & SQL.use==T){
    return('Need PlateID !')
  }
}

  
#Get Images
###################################################################################################################################################
if(TimeCourse==F){
MyIm = list.files(PlateLoc,recursive=F)
}else{
  MyIm = list.files(PlateLoc,recursive=T)
  
}
if(length(grep('thumb|Thumbs|HTD|Thumb',MyIm))!=0){
  MyIm = MyIm[-grep('thumb|Thumbs|HTD|Thumb',MyIm)]
}

########################################
cl <- makeCluster(detectCores()-1)
registerDoParallel(cl, cores = detectCores()-1)

opts =list(chunkSize=2)
MyImCl<-foreach(IM = MyIm,i=icount() ,.packages = c("EBImage","tiff","reshape","parallel","foreach","doParallel","iterators"),
                 .combine = 'rbind',.options.nws=opts) %dopar% {
  if(SQL.use==T){
  sChar = unlist((strsplit(gsub(substr(IM,nchar(IM) -39, nchar(IM)),'',IM), split='/')))
    if(TimeCourse ==T){
      cbind(TimePoint=as.numeric(unlist(strsplit(sChar[1],split='_'))[2]),colsplit(sChar[2],split='_',names=c('Name','Well','Site','Channel')))
    }else{
      cbind(TimePoint=1,colsplit(sChar,split='_',names=c('Name','Well','Site','Channel')))
    }
  }else{
    if(TimeCourse ==T){
      cbind(TimePoint=1,colsplit(IM,split='_',names=c('Name','Well','Site','Channel')))
    }else{
      cbind(TimePoint=1,colsplit(IM,split='_',names=c('Name','Well','Site','Channel')))
  }
 }
}
stopCluster(cl)
#######################################

MyImCl$Site = as.numeric(gsub('s','',MyImCl$Site))
MyImCl$Channel = gsub('.TIF|.tiff|.tif','',MyImCl$Channel)
MyImCl = cbind(MyIm = paste(PlateLoc, MyIm, sep='/'),MyImCl) 
MyImCl = MyImCl[order(MyImCl$TimePoint,MyImCl$Well, MyImCl$Site),,drop=F]

########################################

MyImCl$Well = as.character(MyImCl$Well)

return(MyImCl)

###################################################################################################################################################

}
