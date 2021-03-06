
# Clear All Variables
rm(list=ls())

#================= INITIAL STEPS ====================

# Import Libraries
library(dplyr)
library(tidyr)
library(ggplot2)
library(corrplot)
library(MASS)
library(car)
library(e1071)
library(caret)
library(caTools)
library(ROCR)
library(DAAG)


# Import Data Files
emp_survey <- read.csv("employee_survey_data.csv", stringsAsFactors = T)
gen_data <- read.csv("general_data.csv",stringsAsFactors = T)
in_time <- read.csv("in_time.csv",stringsAsFactors = T)
out_time <- read.csv("out_time.csv",stringsAsFactors = T)
manager_survey <- read.csv("manager_survey_data.csv",stringsAsFactors = T)

# Function to replace NA by mean
replace_NA_by_mean <- function(DFcolumn){
  DFcolumn[is.na(DFcolumn)] <- round(mean(DFcolumn[!is.na(DFcolumn)]))
  DFcolumn
}


#==================== DATA CLEANING AND PROCESSING ======================

# Checking if Rows are duplicated
  length(unique(gen_data$EmployeeID)) # 4410
  length(unique(emp_survey$EmployeeID)) # 4410
  length(unique(manager_survey$EmployeeID)) # 4410
  length(unique(in_time$X)) # 4410
  length(unique(out_time$X)) # 4410

# Checking if employee ID order is correct in all data frames so that they can be merged/cbind  
  setdiff(gen_data$EmployeeID,emp_survey$EmployeeID)
  setdiff(gen_data$EmployeeID,manager_survey$EmployeeID)
  setdiff(gen_data$EmployeeID,in_time$X)
  setdiff(gen_data$EmployeeID,out_time$X)
  # All have a diff of 0 which indicate them having same IDs
  
# emp_survey : Data Cleaning and Processing

  # Check for NA
  sapply(emp_survey, function(x){sum(is.na(x))}) # NA Values found; EnvironMentalSatisfaction:25, JobSatisfaction:20, WorkLifeBalance:38
  # Replacing with Mean : Since the values are only limited to 1,2,3,4 and very few NA are there 
  emp_survey$EnvironmentSatisfaction <- replace_NA_by_mean(emp_survey$EnvironmentSatisfaction)
  emp_survey$JobSatisfaction <- replace_NA_by_mean(emp_survey$JobSatisfaction)
  emp_survey$WorkLifeBalance <- replace_NA_by_mean(emp_survey$WorkLifeBalance)
  
  # Check Data validity
  sapply(emp_survey, function(x){levels(as.factor(x))}) # Levels are OK and within limit  as mentioned in dictionary, No invalid data
    
# manager_survey : Data Cleaning and Processing
  
  # Check for NA
  sapply(manager_survey, function(x){sum(is.na(x))}) # No NA Values 
  # Check Data Validity
  sapply(manager_survey, function(x){levels(as.factor(x))}) # Levels are OK and within limit as mentioned in dictionary, No invalid data
  
  
# gen_data : Data Cleaning and Processing
  
  # Check for NA
  sapply(gen_data, function(x){sum(is.na(x))}) # NA values found; NumCompaniesWorked:19, TotalWorkingYears:9
  gen_data[which(is.na(gen_data$NumCompaniesWorked)),]
  gen_data[which(is.na(gen_data$TotalWorkingYears)),]
  
  # Imputing NA values with median NumCompaniesWorked based on TotalWorkingYears
  # To achieve this we take the value of TotalWorkingYears for the corresponding row of NA NumCompaniesWorked and compute the median of NumCompaniesWorked with all rows having same TotalWorkingYears
  gen_data[which(is.na(gen_data$NumCompaniesWorked)),"NumCompaniesWorked"] <- sapply(gen_data[which(is.na(gen_data$NumCompaniesWorked)),"TotalWorkingYears"], function(x){
    round(median(gen_data$NumCompaniesWorked[which(gen_data$TotalWorkingYears == x)],na.rm = T))
  })
  
  # Imputing NA values with mean TotalWorkingYears based on NumCompaniesWorked
  # To achieve this we take the value of NumCompaniesWorked for the corresponding row of NA TotalWorkingYears and compute the median of TotalWorkingYears with all rows having same NumCompaniesWorked
  gen_data[which(is.na(gen_data$TotalWorkingYears)),"TotalWorkingYears"] <- sapply(gen_data[which(is.na(gen_data$TotalWorkingYears)),"NumCompaniesWorked"], function(x){
    round(median(gen_data$TotalWorkingYears[which(gen_data$NumCompaniesWorked == x)],na.rm = T))
  })
  
  # Check Data Validity
  sapply(gen_data, function(x){levels(as.factor(x))}) # Levels are OK and within limit, No invalid data
  
# In_time and Out_time : Data Cleaning and Processing

  # NA values in these simply mean the employee didn't come to office and the biometric was not registered, hence not imputing
  
  # Coverting time to POSIXlt data for easy calculation of times  
  in_time_1 <- data.frame(sapply(in_time[,-1], function(x){ as.POSIXlt(x, format = "%Y-%m-%d %H:%M:%S")} ))
  out_time_1 <- data.frame(sapply(out_time[,-1], function(x){ as.POSIXlt(x, format = "%Y-%m-%d %H:%M:%S")} ))


#====================== DERIVE VARIABLES =========================    
  
  # Derive variable : worked_hours
  time_1 <- out_time_1 - in_time_1 # Subtracting (OutTime - Intime)
  class(time_1$X2015.01.01)

  time_df <- cbind(out_time$X,time_1) # Binding Employee ID and derived variable to time_df
  colnames(time_df)[1]  <- "EmployeeID"
  
  time_df[-1] <- lapply(time_df[-1], unclass)
  time_df[-1] <- lapply(time_df[-1], as.numeric) # Converting to numeric
  
  time_df$worked_hours_mean <- rowMeans(time_df[-1],na.rm = T) # Finding mean of worked_hours_mean

  time_df <- time_df[,c("EmployeeID","worked_hours_mean")]  
   
  # Derive Variable : out_of_office
  
  # calculating number of days on off/leave/out of office 
  time_df$out_of_office <- rowSums(is.na(time_1))
  
  # Derive Variable : overtime_count
  
  # calculating number of days worked overtime
  time_df$overtime_count <- rowSums(time_1 > 8,na.rm = T)
  
  # Derive Variable : undertime_count
  
  # calculating number of days worked undertime (less than 6 hours)
  time_df$undertime_count <- rowSums(time_1 < 6,na.rm = T)
  
  # Check order of Employee ID before merging  
  setdiff(time_df$EmployeeID,gen_data$EmployeeID)
  
# Merging all Data frames
  
  mainDF <- merge(gen_data,emp_survey,by = "EmployeeID")
  mainDF <- merge(mainDF,manager_survey,by = "EmployeeID")
  mainDF <- merge(mainDF,time_df,by = "EmployeeID")  

# Checking for any remaining NA  
  sapply(mainDF, function(x){sum(is.na(x))})  
  

#======================== PLOTS ===========================
   
  # Univariate
  # Attrition, JobSatisfaction, WorkLifeBalance, YearsSinceLastPromotion
  
  # Bivariate
  # MariatlStatus~Attrition , OverTime~Attrition , Business-Travel~Attrition , YearWithCurrManager~Attrition

  # Attrition Frequency  
  mainDF %>%
    ggplot(aes(x = Attrition)) +
    geom_bar(aes(y = (..count..), fill = Attrition)) +
    geom_text(aes(y = (..count..), label = scales::percent((..count..)/sum(..count..))), stat = "count", vjust = -0.25) +
    labs(title = "Attrition Frequency", y = "Count", x = "Attrition")+
    scale_fill_manual(values = c("Yes" = "darkred", "No" = "darkgreen"))
  
  # There is an attrition of 16.1%
  

  # Job Satisfaction
  mainDF %>%
    ggplot(aes(x = as.factor(JobSatisfaction))) +
    geom_bar(aes(y = (..count..), fill = JobSatisfaction)) +
    geom_text(aes(y = (..count..), label = scales::percent((..count..)/sum(..count..))), stat = "count", vjust = -0.25) +
    labs(title = "Job Satisfaction Score", y = "Count", x = "Job Satisfaction Levels")+
    scale_fill_continuous(low = "darkred", high = "darkgreen")
  
  # Though Job Satisfaction seems to be quite good , still there are about 40% employees with 2 or lower Job satisfaction rating
  
  
  # Work Life balance
  mainDF %>%
    ggplot(aes(x = as.factor(WorkLifeBalance))) +
    geom_bar(aes(y = (..count..), fill = WorkLifeBalance)) +
    geom_text(aes(y = (..count..), label = scales::percent((..count..)/sum(..count..))), stat = "count", vjust = -0.25) +
    labs(title = "Work-Life Balance Score", y = "Count", x = "Work-Life Balance Levels")+
    scale_fill_continuous("Work-Life Balance",low = "darkred", high = "darkgreen")
  
  # Work Life balance seems to be quite average and about 28.5% people are not so happy with the Work-Life balance
  
  
  # Years Since Last Promotion
  mainDF %>%
    ggplot(aes(x = as.factor(YearsSinceLastPromotion))) +
    geom_bar(aes(y = (..count..), fill = YearsSinceLastPromotion)) +
    geom_text(aes(y = (..count..), label = scales::percent((..count..)/sum(..count..))), stat = "count", vjust = 0.5, hjust=-0.1 ,angle = 90) +
    labs(title = "Years Since Last Promotion", y = "Count", x = "Years Since Last Promotion")+
    scale_fill_continuous("Years",low = "darkred", high = "darkgreen")
  
  # Though there are very few people don't get promoted for a long time, about 25% employees don't get promotion for more than 3 years 
  
  

  # MaritalStatus~Attrition
  mainDF %>%
    ggplot(aes(x = MaritalStatus, group = Attrition)) + 
    geom_bar(aes(y = ..prop.., fill = as.factor(..x..)), stat="count") + 
    scale_y_continuous(labels=scales::percent) +
    geom_text(aes(y = (..prop..), label = scales::percent((..prop..)/sum(..prop..))), stat = "count", vjust = -0.5)+
    labs(title = "Marital-Status Vs Attrition", y = "Percentage Attrition", x = "Marital Status")+
    facet_grid(~Attrition)
  
  # Clearly people who are single tend to leave the company more often, whereas married and divorced people tend to stay back longer
  
  
  # OverTime~Attrition
  mainDF[which(mainDF$overtime_count > 1),] %>%
    ggplot(aes(x = overtime_count, group = Attrition)) + 
    geom_bar(aes(y = ..prop..)) + 
    scale_y_continuous(labels=scales::percent) +
    labs(title = "Overtiming Vs Attrition", y = "Percentage Attrition", x = "Overtime Frequency")+
    facet_grid(~Attrition)
  
  # More people who overtime a lot throughout the year tend to leave the company
  
  
  # BusinessTravel~Attrition
  mainDF %>%
    ggplot(aes(x = BusinessTravel, group = Attrition)) + 
    geom_bar(aes(y = ..prop.., fill = as.factor(..x..)), stat="count") + 
    scale_y_continuous(labels=scales::percent) +
    geom_text(aes(y = (..prop..), label = scales::percent((..prop..)/sum(..prop..))), stat = "count", vjust = -0.5)+
    labs(title = "Business Travel Vs Attrition", y = "Percentage Attrition", x = "Business Travel")+
    facet_grid(~Attrition)+
    theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust=0.5))
  
  # People travelling more tend to stay back with the company 
  
  
  # YearsWithCurrManager~Attrition
  mainDF %>%
    ggplot(aes(x = YearsWithCurrManager, group = Attrition)) + 
    geom_bar(aes(y = ..prop..)) + 
    scale_y_continuous(labels=scales::percent) +
    labs(title = "Years With Current Manager Vs Attrition", y = "Percentage Attrition", x = "Years With Current Manager")+
    facet_grid(~Attrition)

  # People under same manager for a longer time tend to stay back
  
    
      
#================== OUTLIER TREATMENT =====================  
  
# Checking for Outliers
  sapply(mainDF, function(x){if(is.numeric(x)){boxplot.stats(x)$out}})
  # MonthlyIncome, NumCompaniesWorked, StockOptionLevels, TotalWorkingYears, TrainingTimesLastYear, YearsAtCompany, YearsSinceLastPromotion, YearsWithCurrManager, PerformanceRating, worked_hours_mean, undertime_count
  
  boxplot(mainDF$MonthlyIncome)
  boxplot.stats(mainDF$MonthlyIncome)  # Since the outliers are not extreme cases and data has considerable number of these, hence not treating outliers
  
  boxplot(mainDF$NumCompaniesWorked)
  boxplot.stats(mainDF$NumCompaniesWorked)
  hist(mainDF$NumCompaniesWorked)  # Since the outliers are not extreme cases and data has considerable number of these, hence not treating outliers
  
  boxplot(mainDF$StockOptionLevel)
  boxplot.stats(mainDF$StockOptionLevel)  
  hist(mainDF$StockOptionLevel)  # Since the outliers are not extreme cases and data has considerable number of these, hence not treating outliers
  
  boxplot(mainDF$TotalWorkingYears)
  boxplot.stats(mainDF$TotalWorkingYears)
  hist(mainDF$TotalWorkingYears) # Since the outliers are not extreme cases and data shows a gradual change, hence not treating outliers
  
  boxplot(mainDF$TrainingTimesLastYear) # Since the outliers are not extreme cases and data has considerable number of these, hence not treating outliers
  
  boxplot(mainDF$YearsAtCompany)
  boxplot.stats(mainDF$YearsAtCompany)
  hist(mainDF$YearsAtCompany) # Need to cap outliers
  mainDF[which(mainDF$YearsAtCompany > 22),"YearsAtCompany"] <- 22 # Capping to 22

  boxplot(mainDF$YearsSinceLastPromotion)  
  boxplot.stats(mainDF$YearsSinceLastPromotion) 
  hist(mainDF$YearsSinceLastPromotion) # Since the outliers are not extreme cases and data has considerable number of these, hence not treating outliers  
  
  boxplot(mainDF$YearsWithCurrManager)  
  boxplot.stats(mainDF$YearsWithCurrManager) # Since the outliers are not extreme cases and data has considerable number of these, hence not treating outliers
  
  boxplot(mainDF$PerformanceRating) 
  hist(mainDF$PerformanceRating) # Since there are only 2 levels and both are quite significant, hence not treating outliers
  
  boxplot(mainDF$worked_hours_mean) # Since the outliers are not extreme cases and data has considerable number of these, hence not treating outliers
  
  boxplot(mainDF$undertime_count)
  boxplot.stats(mainDF$undertime_count) # Since the data is significant and could be vital to the analysis, hence not treating the outliers


#========================= MODEL BUILDING - PREPARATIONS =============================  
    
# Preparing Variables for Model

  # Variables with only one value  
  which(sapply(mainDF, function(x){length(levels(as.factor(x)))}) == 1)
  # Since "EmployeeCount" "Over18" and "StandardHours" have only one variable in columns, hence removing them
  mainDF <- mainDF[,-which(sapply(mainDF, function(x){length(levels(as.factor(x)))}) == 1)]
  
  # Find variables with binary values to convert to 1 and 0
  which(sapply(mainDF, function(x){length(levels(as.factor(x)))}) == 2) # Attrition,Gender,PerformanceRating
  
  levels(mainDF$Attrition)
  levels(mainDF$Attrition) <- c(0,1) # 1 indicates yes
  
  levels(mainDF$Gender)
  levels(mainDF$Gender) <- c(0,1) # 1 indicates Male

  # Convert ordinal variables to numeric
  levels(mainDF$BusinessTravel)
  levels(mainDF$BusinessTravel) <- c(0,2,1) # 0 = Non-Travel , 1 = Travel_Rarely , 2 = Travel_Frequently
  
  mainDF$BusinessTravel <- as.numeric(as.character(mainDF$BusinessTravel))
  
#======================== MODEL BUILDING - DUMMY VARIABLES =============================
  
  # Creating dummies for categorical variables "Department","EducationField","JobRole" and "MaritalStatus"
  mainDF_facts <- mainDF[,colnames(mainDF) %in% c("Department","EducationField","JobRole","MaritalStatus")]
  dummies <- data.frame(sapply( mainDF_facts , function(x){data.frame(model.matrix(~x))[,-1]}))
  mainDF <- cbind(mainDF,dummies)

  # Excluding columns where dummies have been created 
  mainDF <- mainDF[,!colnames(mainDF) %in% c("Department","EducationField","JobRole","MaritalStatus")]
  
  # Normalizing continuous variables
  
  toNormalize <- mainDF[,colnames(mainDF) %in% c("Age","DistanceFromHome","MonthlyIncome","NumCompaniesWorked","PercentSalaryHike","TotalWorkingYears","TrainingTimesLastYear","YearsAtCompany","YearsSinceLastPromotion","YearsSinceLastPromotion","YearsWithCurrManager","worked_hours_mean","out_of_office","overtime_count","undertime_count")]
  
  normalized <- data.frame(sapply(toNormalize,function(x){scale(x)})) # All normalized columns

  mainDF <- cbind(mainDF[,!colnames(mainDF) %in% colnames(toNormalize)],normalized) # Replacing Unscaled columns with scaled columns
  
#========================= MODEL BUILDING - LINEAR MODELLING ==============================
  
  # Set seed for random number reproducibility
  set.seed(100)

  # Creating Training Dataset and Testing Dataset
  trainIndices <- sample(1:nrow(mainDF), 0.7*nrow(mainDF))  

  train <- mainDF[trainIndices,]  
  test <- mainDF[-trainIndices,]  

  # Initial Model
  
  model_1 <- glm(Attrition ~ ., data = train , family = "binomial")

  summary(model_1)  # AIC:2099

  # Step AIC
  
  model_2 <- stepAIC(model_1,direction = "both")
  
  summary(model_2) # AIC:2072
  
  sort(vif(model_2))

  
  # Removing worked_hours_mean due to high VIF and low significance
  
  model_3 <- glm(Attrition ~ BusinessTravel+StockOptionLevel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xLife.Sciences+EducationField.xMarketing+EducationField.xMedical+EducationField.xOther+
                   EducationField.xTechnical.Degree+JobRole.xHuman.Resources+JobRole.xManager+JobRole.xManufacturing.Director+
                   JobRole.xSales.Representative+MaritalStatus.xMarried+MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+
                   TrainingTimesLastYear+YearsSinceLastPromotion+YearsWithCurrManager+overtime_count, data = train , family = "binomial")

  summary(model_3) # AIC:2078
  sort(vif(model_3))  

  # Removing EducationField.xMedical  due to high VIF and low significance     
  
  model_4 <- glm(Attrition ~ BusinessTravel+StockOptionLevel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xLife.Sciences+EducationField.xMarketing+EducationField.xOther+
                   EducationField.xTechnical.Degree+JobRole.xHuman.Resources+JobRole.xManager+JobRole.xManufacturing.Director+
                   JobRole.xSales.Representative+MaritalStatus.xMarried+MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+
                   TrainingTimesLastYear+YearsSinceLastPromotion+YearsWithCurrManager+overtime_count, data = train , family = "binomial")
  
  summary(model_4) # AIC:2101    
  sort(vif(model_4))  
  
  # Removing EducationField.xLife.Sciences due to low significance
  
  model_5 <- glm(Attrition ~ BusinessTravel+StockOptionLevel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xMarketing+EducationField.xOther+EducationField.xTechnical.Degree+JobRole.xHuman.Resources+
                   JobRole.xManager+JobRole.xManufacturing.Director+JobRole.xSales.Representative+MaritalStatus.xMarried+
                   MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                 data = train , family = "binomial")
  
  summary(model_5) # AIC:2099.9
  sort(vif(model_5))  
  
  # Removing EducationField.xOther due to low significance
  
  model_6 <- glm(Attrition ~ BusinessTravel+StockOptionLevel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xMarketing+EducationField.xTechnical.Degree+JobRole.xHuman.Resources+
                   JobRole.xManager+JobRole.xManufacturing.Director+JobRole.xSales.Representative+MaritalStatus.xMarried+
                   MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                 data = train , family = "binomial")
  
  summary(model_6) # AIC:2098
  sort(vif(model_6))  

  # Removing EducationField.xMarketing due to low significance
  
  model_7 <- glm(Attrition ~ BusinessTravel+StockOptionLevel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xTechnical.Degree+JobRole.xHuman.Resources+
                   JobRole.xManager+JobRole.xManufacturing.Director+JobRole.xSales.Representative+MaritalStatus.xMarried+
                   MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                 data = train , family = "binomial")
  
  summary(model_7) # AIC : 2098
  sort(vif(model_7))  
  
  # Removing JobRole.xHuman.Resources due to low significance
  
  model_8 <- glm(Attrition ~ BusinessTravel+StockOptionLevel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xTechnical.Degree+JobRole.xManager+JobRole.xManufacturing.Director+JobRole.xSales.Representative+
                   MaritalStatus.xMarried+MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+
                   YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                 data = train , family = "binomial")
  
  summary(model_8) # AIC:2099    
  sort(vif(model_8))

  # Removing JobRole.xSales.Representative due to low significance
  
  model_9 <- glm(Attrition ~ BusinessTravel+StockOptionLevel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xTechnical.Degree+JobRole.xManager+JobRole.xManufacturing.Director+
                   MaritalStatus.xMarried+MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+
                   YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                 data = train , family = "binomial")
  
  summary(model_9) # AIC:2099
  sort(vif(model_9))
  
  # Removing StockOptionLevel to low significance
  
  model_10 <- glm(Attrition ~ BusinessTravel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                   EducationField.xTechnical.Degree+JobRole.xManager+JobRole.xManufacturing.Director+
                   MaritalStatus.xMarried+MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+
                   YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                 data = train , family = "binomial")
  
  summary(model_10) # AIC:2100 
  sort(vif(model_10))
  
  # Removing JobRole.xManager due to low significance
  
  model_11 <- glm(Attrition ~ BusinessTravel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                    EducationField.xTechnical.Degree+JobRole.xManufacturing.Director+
                    MaritalStatus.xMarried+MaritalStatus.xSingle+Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+
                    YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                  data = train , family = "binomial")
  
  summary(model_11) # AIC:2100
  sort(vif(model_11))

  # Removing EducationField.xTechnical.Degree due to low significance    
  
  model_12 <- glm(Attrition ~ BusinessTravel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                    JobRole.xManufacturing.Director+MaritalStatus.xMarried+MaritalStatus.xSingle+
                    Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+
                    YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                  data = train , family = "binomial")
  
  summary(model_12)  # AIC:2102  
  sort(vif(model_12))

  # Removing MaritalStatus.xMarried due to low significance
  
  model_13 <- glm(Attrition ~ BusinessTravel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                    JobRole.xManufacturing.Director+MaritalStatus.xSingle+
                    Age+NumCompaniesWorked+TotalWorkingYears+TrainingTimesLastYear+
                    YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                  data = train , family = "binomial")
  
  summary(model_13) # AIC:2104
  sort(vif(model_13))

  # Removing TrainingTimesLastYear due to low significance    
  
  model_14 <- glm(Attrition ~ BusinessTravel+EnvironmentSatisfaction+JobSatisfaction+WorkLifeBalance+
                    JobRole.xManufacturing.Director+MaritalStatus.xSingle+
                    Age+NumCompaniesWorked+TotalWorkingYears+
                    YearsSinceLastPromotion+YearsWithCurrManager+overtime_count,
                  data = train , family = "binomial")
  
  summary(model_14)  # AIC:2113   
  sort(vif(model_14))

  # All values are significant and AIC seems to be within expected value hence finalizing model  
    
  final_model <- model_14
  summary(final_model)
  
#========================== MODEL EVALUATION - TESTING MODEL ==========================
  
  # Predicted probabilities for test data
  
  test_pred = predict(final_model, type = "response", newdata = test[-1])
  
  summary(test_pred)
  
  # adding the predicted data to test dataset
  test$prob <- test_pred

  # using the probability cutoff at different values.
  
  test_pred_attrition <- factor(ifelse(test_pred >= 0.5, "Yes", "No"))
  test_actual_attrition <- factor(ifelse(test$Attrition==1,"Yes","No"))  
  
  confusionMatrix(test_pred_attrition, test_actual_attrition, positive = "Yes") # Accuracy : 0.86 , Sensitivity : 0.30 , Specificity : 0.96, Balanced Accuracy : 0.63
  
  test_pred_attrition <- factor(ifelse(test_pred >= 0.2, "Yes", "No"))
  confusionMatrix(test_pred_attrition, test_actual_attrition, positive = "Yes") # Accuracy : 0.78 , Sensitivity : 0.73 , Specificity : 0.78, Balanced Accuracy : 0.76
  
  # Measuring sensitivity, specificity and accuracy with graph

  perform_cutoff_reg <- function(cutoff) 
  {
    predicted_attrition <- factor(ifelse(test_pred >= cutoff, "Yes", "No"))
    conf <- confusionMatrix(predicted_attrition, test_actual_attrition, positive = "Yes")
    accu <- conf$overall[1]
    sens <- conf$byClass[1]
    spec <- conf$byClass[2]
    out <- t(as.matrix(c(sens, spec, accu))) 
    colnames(out) <- c("sensitivity", "specificity", "accuracy")
    return(out)
  }
  
    
  # Creating 100 x 3 matrix of cutoffs ranging from 0.01 to 0.90
  
  s_100 = seq(.01,.90,length=100) # creating a sequence of 100 periods between 0.01 and 0.90

  Out_Mat = matrix(0,100,3)  # Creating a matrix of 100x3

  # filling up matrix with values at different cutoffs
  for(i in 1:100){
    Out_Mat[i,] = perform_cutoff_reg(s_100[i])
  } 

  # plot sensitivity, specificity, accuracy graph
  plot(s_100, Out_Mat[,1],xlab="Cutoff",ylab="Value",cex.lab=1.5,cex.axis=1.5,ylim=c(0,1),type="l",lwd=2,axes=FALSE,col=2)
  axis(1,seq(0,1,length=5),seq(0,1,length=5),cex.lab=1.5)
  axis(2,seq(0,1,length=5),seq(0,1,length=5),cex.lab=1.5)
  lines(s_100,Out_Mat[,2],col="green",lwd=2)
  lines(s_100,Out_Mat[,3],col=4,lwd=2)
  box()
  legend(0,.50,col=c(2,"green",4,"red"),lwd=c(2,2,2,2),c("Sensitivity","Specificity","Accuracy"))

  # finding intersecting values 
  cutoff <- s_100[which(abs(Out_Mat[,1]-Out_Mat[,2])<0.02)]
  # 0.18 is optimal as per calculation based on the intersection
  
  test_cutoff_attrition <- factor(ifelse(test_pred >= 0.18, "Yes", "No"))
  confusionMatrix(test_cutoff_attrition, test_actual_attrition, positive = "Yes") # Accuracy : 0.75 , Sensitivity : 0.76 , Specificity : 0.75, Balanced Accuracy : 0.75

  # Cutoff depends on the business scenario. We will settle at 0.2 since that gives us better sensitivity and specificity and has a good Balanced Accuracy
  # Depending on the business requirement changes, we can be flexible with the cutoff value to suit the needs
  cutoff <- 0.2
  
  
  # KS Statistics
  
  test_cutoff_attrition <- ifelse(test_cutoff_attrition=="Yes",1,0)
  test_actual_attrition <- ifelse(test_actual_attrition=="Yes",1,0)

  pred_object_test<- prediction(test_cutoff_attrition, test_actual_attrition)
  performance_measures_test<- performance(pred_object_test, "tpr", "fpr")  

  ks_table_test <- attr(performance_measures_test, "y.values")[[1]] - 
    (attr(performance_measures_test, "x.values")[[1]])
  
  max(ks_table_test)  # 0.50
  
  plot(performance_measures_test,main=paste0(' KS=',round(max(ks_table_test*100,1)),'%'), colorize = T)
  lines(x=c(0,1),y=c(0,1))

  # Area under the curve
  auc <- performance(pred_object_test, "auc")
  auc@y.values[[1]] # 0.7524349
  
  
  # Lift and Gain Chart
  
  performance_measures_test <- performance(pred_object_test, "lift", "rpp")
  plot(performance_measures_test)
  
  lift <- function(labels,predicted_prob,groups=10){
    if(is.factor(labels)){labels <- as.integer(as.character(labels))}
    if(is.factor(predicted_prob)){predicted_prob <- as.integer(as.character(predicted_prob))}
    helper = data.frame(cbind(labels,predicted_prob))
    helper[,"bucket"] = ntile(-helper[,"predicted_prob"],groups)
    gaintable = helper %>% group_by(bucket) %>%
      summarise_at(vars(labels ),funs(total = n(),totalresp=sum(., na.rm = TRUE))) %>%
      mutate(Cumresp = cumsum(totalresp),Gain=Cumresp/sum(totalresp)*100,Cumlift=Gain/(bucket*(100/groups))) 
    return(gaintable)
  }
  
  Churn_decile = lift(test_actual_attrition, test_pred, groups = 10)
  View(Churn_decile)  

  # K Fold - Cross Validation
  cv.binary(final_model, nfolds = 100)
  # Internal estimate of accuracy = 0.865
  # Cross-validation estimate of accuracy = 0.862
  # We see that the accuracy is quite high after 100 folds, hence we conclude that the model is quite stable
  
