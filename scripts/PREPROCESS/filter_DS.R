library(MASS)
library(data.table)
read.eec <- function(file,nint){
   #nint is the number of intervals (rows) in the file to read. 
   matrix(scan(file),nrow=nint,byrow=TRUE)
}
FileProcessing <-function(proposedFilters,file,originPath,destinationPath,nint){
    ## Function to write output file after filters being computed
    ## proposedFilters a matrix with the filter
    ## file to be written output
    ##origin and destination path should finish with / 
     S <-  exp(read.eec(paste(originPath,file,sep=""),nint))%*%proposedFilters
     Sabs<-abs(S)
     Slog<-(Sabs>1)
     outputfile <-  gzfile(paste(destinationPath,file,sep=""))
     write.table(sign(S)*log(Sabs*Slog+1*(!Slog)),outputfile,sep=" ",col.names=FALSE,row.names=FALSE)
}

########

BlockProcessing <- function(indiv,channels,
                            bandsFQ=list(9:327,328:655,656:983,984:2457,2458:5734,5735:16384),
                            epsilon=1e-4,
                            max.iter=40,
                            originPath= "TMP/FFT_60s_30s_COMPRESS",
                            destinationPath="TMP/Filtros_Pot_60s_global"){
  
  

  
  destinationPath <- paste(destinationPath,"/",sep="")  
  if(!file.exists(destinationPath)){
     dir.create(destinationPath)
  }

  filesPre <- dir(originPath,pattern=paste(indiv,"_preictal",sep=""))
 
  nint <- as.integer(fread(paste("zcat ",originPath,"/",filesPre[1]," | wc -l",sep="")))
  nfreq <- as.integer(fread(paste("zcat ",originPath,"/",filesPre[1]," | wc -w",sep="")))/nint
  ng<-length(bandsFQ)
    for(k in channels){  
        filesPre <- dir(originPath,pattern=paste(indiv,"_preictal_segment_.....channel_",sprintf("%02d",k),sep=""))
        filesInter <- dir(originPath,pattern=paste(indiv,"_interictal_segment_.....channel_",sprintf("%02d",k),sep=""))
        testFiles <- dir(originPath,pattern=paste(indiv,"_test_segment_.....channel_",sprintf("%02d",k),sep=""))
        allFiles<-c(filesPre,filesInter,testFiles)
        if(!all(file.exists(paste(destinationPath,allFiles,sep="")))){
           proposedFilters <- list()
           for(g in bandsFQ){
             NumberBands<-length(g)
             proposedFilters[[length(proposedFilters)+1]] <- matrix(1/sqrt(NumberBands),nrow=NumberBands,ncol=1)
           } #close for initialization proposed Filters 
           error <- 1
           iter<-0
           while(error>epsilon){
             iter<-iter +1
             if(iter>max.iter){
                write.matrix(errorvector,file=paste(destinationPath,"Warning_No_Convergencia_",indiv,"_channel_",k ,".txt",sep=""))
                break()
             } #closeif condition met to break
             vanew <- list()
             vbnew <- list()
             errorvector <- numeric(ng)
             for(ig in 1:ng){
                vanew[[ig]] <- matrix(0,nrow=1,ncol=length(bandsFQ[[ig]]))
                vbnew[[ig]] <- matrix(0,nrow=1,ncol=length(bandsFQ[[ig]]))
             }

             for(f in filesPre){
                fileName <- paste(originPath,"/",f,sep="")
                data.files <- exp(read.eec(fileName,nint))
                for(ig in 1:ng){
                   g <- bandsFQ[[ig]]
                   wa<-c(data.files[,g]%*%proposedFilters[[ig]])
                   vanew[[ig]]<-vanew[[ig]]+ apply(diag(wa)%*%(data.files[,g]),2,sum)
                }
            } #close multiplication by filesPre

            for(f in filesInter){
                fileName <- paste(originPath,"/",f,sep="")
                data.files <- exp(read.eec(fileName,nint))
                for(ig in 1:ng){
                   g <- bandsFQ[[ig]]
                   wb<-c(data.files[,g]%*%proposedFilters[[ig]])
                   vbnew[[ig]] <- vbnew[[ig]]+ apply(diag(wb)%*%(data.files[,g]),2,sum)
                 }
             } #close multiplication by filesInter
      
             for(ig in 1:ng){
                 vnew <- t((1/length(filesPre))*vanew[[ig]]-(1/length(filesInter))*vbnew[[ig]])
                 #Taking into account the sign to normalize
                 vnew <- sign(sum(proposedFilters[[ig]]*vnew))*vnew/sqrt(sum(vnew^2))
                 errorvector[ig] <- sqrt(sum((proposedFilters[[ig]]-vnew)^2))
                 proposedFilters[[ig]] <- vnew
              }  # close for calculation new interate 
              error <- max(errorvector)
       
              cat(errorvector,"  \n")
           }#close loop power method
           filterMatrix <- matrix(nrow=nfreq,ncol=0)
           for(ig in 1:ng){
             g<-bandsFQ[[ig]]
             filterMatrix <- cbind(filterMatrix,rbind(as.matrix(rep(0,g[1]-1)),proposedFilters[[ig]],as.matrix(rep(0,nfreq-g[length(g)]))))
           } # close for with filter matrix  
           write.matrix(filterMatrix,file=paste(destinationPath,indiv,"_channel_",k ,"_DS.txt",sep=""))
           for( f in allFiles){
                 FileProcessing(filterMatrix,f,paste(originPath,"/",sep=""),destinationPath,nint)
           }
      } # close if checking if files are now calculated 
  } # close loop for channel
} # close function


subjects <- c(unlist(strsplit(Sys.getenv("SUBJECTS"), " ")))
sources <- Sys.getenv("FFT_COMPRESS_PATH")
for(indiv in subjects){
    if(indiv %in% c("Patient_1","Patient_2")){
        bandsFQ <- list(83:3354,3355:6709,6710:10065,10066:25164,25165:58719,58720:262144)
    } else{
        bandsFQ <- list(9:327,328:655,656:983,984:2457,2458:5734,5735:16384)
    }
     i=0
     while(TRUE) {
          i=i+1
          match <- sprintf("^%s_(.*)ictal(.*)channel_%02d.csv.gz$", indiv, i)
          list <- list.files(path = sources, pattern = match, full.names=TRUE)
          if (length(list) == 0) break;
     }
    channels <- 1:(i-1)
    BlockProcessing(indiv,channels,
                            bandsFQ=bandsFQ,
                            epsilon=1e-4,
                            max.iter=40,
                            originPath=sources,
                            destinationPath=Sys.getenv("DS_PATH"))
}


####### EOF 
