####ANN building and running with NeuralNet package####
#---Load and install the necessary package---
library(neuralnet)
library(Metrics)
library(caret)
library(progress)

#---Set the seed and create folder to save the results---
set.seed(1)
dir.create("./Denormalised_LOOcv")
dir.create("./Normalised_LOOcv")

#---Create the function to normalize---
normalize <- function(x) {
  x <- as.numeric(x)
  return( (x - min(x))/ (max(x) - min(x)))
}

#---Import the input data : Dataset1/2/3---
mydata <- read.csv("/Users/ophelielo/Documents/Test/USED_TRAIN_Dataset1B_Detox_pathway_55162.csv",
                   sep=';', header = T)

#---Normalize the input data---
normalisedData <- as.data.frame(apply(mydata[,1:4], 2,normalize))

#---Build the ANN models with the learning data---
n <- nrow(mydata)
## Choose the number of hidden units
nbHU <- 10
## Create a progress bar to follow the progression of the calculation
pb <- progress_bar$new(format = "(:spin) [:bar] :percent [Elapsed time: :elapsedfull || Estimated time remaining: :eta]",
                       total = nbHU,
                       complete = "=",   # Completion bar character
                       incomplete = "-", # Incomplete bar character
                       current = ">",    # Current bar character
                       clear = FALSE,    # If TRUE, clears the bar when finish
                       width = 100) 

## Number of fold (if k = n, LOO)
k <- 10
folds <- caret::createFolds(1:n, k)
for (i in 1:nbHU) {
  pb$tick()
  set.seed(1)
  predValue <- NULL
  nn_result <- NULL
  for (fold in folds){
  #print(fold)
    train_data <- normalisedData[-fold, ]
    #Change the input names according to the dataset
    test_data  <- normalisedData[fold,c("PGAM","ENO","PPDK","Jpred")]
    #Change the input names according to the dataset
    form <- as.formula("Jpred~PGAM+ENO+PPDK")
    #Put lifesign  ="full" when adding a threshold for a big dataset
    NeuralNet <- neuralnet(form, train_data, hidden = i, act.fct = "logistic",lifesign = "full",threshold = 0.1,
                           stepmax = 1e+7)
    nn_result <- predict(NeuralNet, test_data)
    predValue  <- c(predValue, nn_result)
    }
  #---Create a dataframe containing the resulting predicted flux values---
  df = data.frame(normalisedData[unlist(folds),], predValue)
  #Change the input names according to the dataset
  colnames(df) <- c("PGAM","ENO","PPDK","Jpred",'ANN_pred_log')
  
  #---Write the different outputs---
  denormalizeANN_pred_log <- df$ANN_pred_log * (max(mydata$Jpred) - min(mydata$Jpred)) + min(mydata$Jpred)
  denormalizeddata_log <- cbind(mydata[unlist(folds),1:4], denormalizeANN_pred_log)
  colnames(denormalizeddata_log) <- c('PGAM','ENO','PPDK','Jpred', 'ANN_pred_log')

#----------- Writing output ---------------------
  
  write.csv(df, paste0("./Normalised_LOOcv/log_normalised",i,".csv"),row.names = F)
  write.csv(denormalizeddata_log,  paste0("./Denormalised_LOOcv/log_denormalised_loocv",i,".csv"),
            row.names = F)

  rmse_nor<- capture.output(postResample(predValue, normalisedData$Jpred[unlist(folds)]))
  cat(i,rmse_nor,file = "normalised_RMSE_log_loocv.csv", sep = "\n", append = T)

  mse_nor <- mse(predValue, normalisedData$Jpred[unlist(folds)])
  cat(i,mse_nor,file = "normalised_MSE_log_loocv.csv", sep = "\n", append = T)

  denorm_rmse <- postResample(denormalizeddata_log$Jpred, denormalizeddata_log$ANN_pred_log)
  cat(i,denorm_rmse,file = "denormalised_RMSE_log_loocv.txt", sep = "\n", append = T)
  
  denorm_mse <- mse(denormalizeddata_log$Jpred, denormalizeddata_log$ANN_pred_log)
  cat(i,denorm_mse,file = "denormalised_MSE_log_loocv.txt", sep = "\n", append = T)

}

#---Run the best ANN model---
#---Import the Train and Test datasets---


