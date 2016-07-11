library(EBImage)
library(tiff)
library(naturalsort)
library(reshape)

library("parallel")
library("foreach")
library("doParallel")
library("iterators")

coloc.HTS = function(MyImCl,Blue=1,Green=2, Red=3, auto=T, Cyto = 'Green',Nuc.rm = T,TopSize = 29,  w1OFF = 0.25,w2OFF = 0.15,w3OFF = 0.1,adj = 1,
                     adj.prob = seq(0,1,0.001), exportPath = rchoose.dir(caption = 'Select results folder')){
  
  
  if(missing(MyImCl)){
    return('Need images information to be imported!')
  }
  
  
  Time = unique(MyImCl$TimePoint)
  UniWell = unique(MyImCl$Well)
  UniSite = unique(MyImCl$Site)
  

  MyCols = colorRampPalette(c('white','black','darkblue','blue','green','red','orange','gold','yellow'))
  ###########################################################################################################################################
  
  dir.create(paste(exportPath,'/Results',sep=''))
  
  OS = .Platform$OS.type#####################################################################################################################
  if(OS == 'windows'){
    RAM = shell('wmic OS get FreePhysicalMemory /Value',intern=T)
    RAM = RAM[grep('FreePhysicalMemory', RAM)]
    RAM = as.numeric(gsub('FreePhysicalMemory=','',RAM))
  }else{
    RAM = as.numeric(system(" awk '/MemFree/ {print $2}' /proc/meminfo", intern=T))
  }
  Cores = detectCores()
  Core2RAM = 8e05  # Assuming one core uses approximately 0.8GB of RAM
  MaxCores = floor(RAM/Core2RAM) 
  
  if(MaxCores>=Cores){
    UsedCores = Cores
  }else{
    UsedCores = MaxCores
  }
  
  ###########################################################################################################################################
  t1 = Sys.time()
  
  cl <- makeCluster(UsedCores)
  registerDoParallel(cl, cores = UsedCores)
  opts =list(chunkSize=1)
  
  Summary<-foreach(TI = Time,t=icount() ,.packages = c("EBImage","tiff","reshape","parallel","foreach","doParallel","iterators"),
                   .combine = 'rbind',.options.nws=opts) %do% {
                     
                     T_Name = paste(exportPath,'/Results/','TimePoint_',TI,sep='')                    
                     dir.create(T_Name)
                     
                     foreach(W = UniWell,i=icount() ,.packages = c("EBImage","tiff","reshape","parallel","foreach","doParallel","iterators","flowCore"),
                             .combine = 'rbind',.options.nws=opts) %dopar% {
                               
                               W_Name = paste(T_Name,'/',W,sep='')
                               dir.create(W_Name)
                               
                               WSummary <- foreach(S = UniSite,j=icount(), .packages = c("EBImage","tiff","reshape"),.inorder=FALSE,
                                                   .combine = 'rbind') %do% { 
                                                     
                                                     try({
                                                       
                                                       #################################################################################################################  
                                                       #IMAGE IMPORT
                                                       Im = MyImCl[which(MyImCl$TimePoint==TI & MyImCl$Well==W & MyImCl$Site==S),]
                                                       #
                                                       nch = dim(Im)[1]
                                                       if(nch<2 | nch>3){
                                                         return('Need at least two and at most three channels !')
                                                       }
                                                       
                                                       RAWList = list()
                                                       PList = list()
                                                       MList = list()
                                                       wOFF = c(w1OFF, w2OFF, w3OFF)
                                                       wOFF = wOFF[order(c(Blue, Green,Red))]
                                                       
                                                       ################################################################################################################
                                                       for(i in c(Blue, Green, Red)){
                                                         IP = as.character(Im$MyIm[which(Im$Channel==paste('w',i,sep=''))])
                                                         if(length(IP) == 1){
                                                           RAW = readTIFF(IP, info=F)
                                                           rm(IP)
                                                           #################################################################################################################
                                                           #Gets Masks 
                                                           
                                                           LOG = RAW
                                                           #---
                                                           q = quantile(LOG,probs=adj.prob)
                                                           R = c(head(q,n=2)[2],tail(q,n=2)[1])
                                                           #---
                                                           LOG[which(LOG==0)] = min(LOG[which(LOG!=0)])
                                                           LOG = EBImage::normalize(log10(LOG))
                                                           
                                                           #-------------------------------------------------
                                                           RAW = EBImage::normalize(RAW,inputRange=R)
                                                           #
                                                           P = RAW-gblur(RAW,50)
                                                           P[which(P<0)] = 0
                                                           P = EBImage::normalize(P)
                                                           
                                                           PList = c(PList,list(P))
                                                           
                                                           ##-------------------------------------------------
                                                           #Here we get LOGs and cytosol Mask
                                                           
                                                           if(Cyto =='Green' & i == Green){
                                                             CytoIm = (medianFilter(LOG,10))
                                                           }else if(Cyto=='Red' & i == Red){
                                                             CytoIm = (medianFilter(LOG,10))
                                                           }else if(Cyto == 'Both'){
                                                             if(i == Green){
                                                               LOGG = LOG
                                                             }
                                                             if(i == Red){
                                                               LOGR = LOG
                                                             }
                                                             if(i == tail(c(Blue,Green,Red),n=1)){
                                                               CytoIm = (medianFilter(EBImage::normalize((LOGG+LOGR)/2),10))
                                                               rm(list = c('LOGR','LOGG'))
                                                               
                                                             }
                                                           }
                                                           if(length(grep('CytoIm',ls()))!=0){
                                                             CMask = CytoIm>(otsu(CytoIm))
                                                           }
                                                           
                                                           if((Nuc.rm==T) & i==Blue){
                                                             T1 = opening(closing(fillHull(thresh(RAW,w=50,h=50, offset = w1OFF)),makeBrush(5,'disc')),makeBrush(5,'disc'))
                                                           }
                                                           
                                                           ##-------------------------------------------------
                                                           #Let's get uncleaned masks
                                                           
                                                           TOP = whiteTopHat(LOG,makeBrush(TopSize,'disc'))
                                                           TOP[which(TOP<0)]=0
                                                           TOP = EBImage::normalize(TOP)
                                                           
                                                           if(auto==T){
                                                             C = TOP>(otsu(TOP)*adj)
                                                           }else{
                                                             C = thresh(TOP,TopSize,TopSize,wOFF[i])
                                                           }
                                                           
                                                           MList = c(MList,list(C))
                                                           RAWList = c(RAWList,list(RAW))   
                                                           
                                                           rm(list=c('LOG','TOP','C','RAW'))
                                                           gc()
                                                         }
                                                       }
                                                       
                                                       #############################################################################################################
                                                       if(Nuc.rm==T){
                                                         CMask = ceiling((CMask+T1)/2 - T1)
                                                         rm(T1)
                                                       }
                                                       
                                                       for(i in 1:nch){
                                                         MList[[i]] = floor((MList[[i]]+CMask)/2)
                                                         MList[[i]] = round(gblur(MList[[i]],0.6,3)) # Remove lonely pixels
                                                       }
                                                       
                                                       #COLOC
                                                       COLOC = floor((MList[[Green]]+MList[[Red]])/2)
                                                       
                                                       #UNION
                                                       UNION = ceiling((MList[[Green]]+MList[[Red]])/2) ##OR operation
                                                       
                                                       ############################################################################################################################
                                                       #Converting images to arrays & calculate coeff
                                                       
                                                       pixG = as.numeric(PList[[Green]])
                                                       pixR = as.numeric(PList[[Red]])
                                                       #
                                                       #Mask###
                                                       pixM = as.numeric(UNION)
                                                       
                                                       #Grayscale IN Mask#
                                                       pixGM = pixG[which(pixM!=0)]
                                                       pixRM = pixR[which(pixM!=0)]
                                                       
                                                       ##############################################################################################################################
                                                       
                                                       lim=c(0,1)
                                                       
                                                       ICQ.calc = function(MAT){
                                                         
                                                         if(dim(MAT)[2]!=2){
                                                           return('Must have two columns!')
                                                         }
                                                         Av1 = mean(MAT[,1],na.rm=T)
                                                         Av2 = mean(MAT[,2], na.rm=T)
                                                         
                                                         return(((length(which(lapply(MAT[,1],function(x) (Av1-x))>=0 & (lapply(MAT[,2],function(x) (Av2-x)))>=0)) + length(which(lapply(MAT[,1],function(x) (Av1-x))<0 & (lapply(MAT[,2],function(x) (Av2-x)))<0))) / length(MAT[,1]))-0.5)
                                                         
                                                       }
                                                       ###
                                                       MOC.calc = function(MAT){
                                                         
                                                         if(dim(MAT)[2]!=2){
                                                           return('Must have two columns!')
                                                         }
                                                         
                                                         return((sum(MAT[,1]*MAT[,2]))/sqrt((sum(MAT[,1]^2))*(sum(MAT[,2]^2))))
                                                         
                                                       }

                                                       ##############################################################################################################################
                                                       #Correlation Values calculation on whole image
                                                       
                                                       PCC = cor(pixGM, pixRM)
                                                       
                                                       ICQ = ICQ.calc(cbind(pixGM,pixRM))
                                                       MOC = MOC.calc(cbind(pixGM,pixRM)) #Manders Overlap coefficient
                                                       
                                                       OvR = length(which(COLOC!=0))/length(which(MList[[Red]]==1))  #Manders Overlap coeff for red component
                                                       OvG = length(which(COLOC!=0))/length(which(MList[[Green]]==1))  #Manders Overlap coeff for green component
                                                       OvT = length(which(COLOC!=0))/(length(which(UNION!=0)))
                                                       
                                                       ################################################################################################################################
                                                       
                                                       pdf(paste(W_Name,'/',W,'_s',S,'_PixelProfiling.pdf',sep=''),w=10,h=10)
                                                       smoothScatter(pixGM, pixRM, nrpoints = 0, colramp=MyCols, main=paste(W,'-',S, sep=' '),nbin=512,
                                                                     bandwidth=0.00005,xaxs='i',yaxs='i',xlab='Channel 2',ylab='Channel3',useRaster=T,xlim=lim,ylim=lim)
                                                       legend('topright',bty='n',cex=0.6,legend=c(paste('PCC=',round(PCC,2)),paste('ICQ=',round(ICQ,2)),paste('MOC=',round(MOC,2)),paste('OvT=',round(OvT,2))),text.col='red')
                                                       dev.off()
                                                       
                                                       if(S==1){
                                                         
                                                         if(nch==3){ 
                                                           
                                                           writeImage(paintObjects(MList[[Red]],paintObjects(MList[[Green]], rgbImage(blue = RAWList[[Blue]]*CMask,green=RAWList[[Green]]*CMask,red =RAWList[[Red]]*CMask),col=c('green',NA)),col=c('red',NA)),
                                                                      paste(W_Name,'/',W,'_s',S,'_ImSeg1.tif',sep=''))
                                                         }else{
                                                           
                                                           writeImage(paintObjects(MList[[Red]],paintObjects(MList[[Green]], rgbImage(green=RAWList[[Green]]*CMask,red =RAWList[[Red]]*CMask),col=c('green',NA)),col=c('red',NA)),
                                                                      paste(W_Name,'/',W,'_s',S,'_ImSeg1.tif',sep=''))
                                                         }
                                                         
                                                       }
                                                       
                                                       #Write results in arrays
                                                       data.frame(TI,W,S,PCC,ICQ,OvT,OvR, OvG, MOC)  
                                                       
                                                     })
                                                     
                                                   }
                               
                               WSummary
                               
                             }
                   }
  
  
  stopCluster(cl)
  
  t2 = Sys.time()
  print(difftime(t2, t1))
  
  #################################################################################################################################################
  #FORMAT & EXPORT--------------------------------------------------------------------------------------------------------------------------------
  #################################################################################################################################################
  
  colnames(Summary)[c(1:3)]=c('Time','WellID','SiteID')
  Summary = Summary[order(Summary$Time,Summary$SiteID,Summary$WellID),,drop=F]
  Summary$GlobalID = paste(Summary$Time, Summary$WellID, sep='_')
  ##
  pdf(paste(exportPath,'/Results/','BoxPlot.pdf',sep=''),w=12,h=7)
  bp = boxplot(as.numeric(PCC) ~ GlobalID, data= Summary[!is.na(Summary$WellID),], ylim=c(-1,1), xaxt='n', outline=F, col='green',xpd=T,xaxs='i',yaxs='i',bty='n')
  stripchart(as.numeric(PCC) ~ GlobalID, data= Summary,vertical=T,pch=1,add=T,cex=0.3)
  text(c(1:length(bp$n)), rep(-1,length(bp$n)), gsub('_|NA',' ',bp$names),cex=0.7, srt=45,adj=c(1.1,1.1),xpd=T)
  dev.off()
  ##
  write.table(Summary[!is.na(Summary$WellID),],paste(exportPath,'/Results/','Results.csv',sep=''),sep=',',row.names=F)
  ##
  return(Summary)
  #################################################################################################################################################
  
}
