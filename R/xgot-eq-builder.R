#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
sink("./log/xg-eq-finder.log")

library("dplyr")
library("lme4")
library("RPostgreSQL")
library("caret")
library("ggplot2")
library("randomForest")
library("png")

#library("smbinning")

closeAllConnections()

##################################
##
##          MAIN PROGRAM
##
##################################

# INPUT ARGUMENTS

print("[info]: Started xgot-eq-builder R script")

# PSQL DB INTERROGATION
drv <- dbDriver("PostgreSQL")

conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")
qtext <- paste0("
select opponentname, id, matchid, season, type, expg, goalmouthy, goalmouthz 
from italyseriea.event
where
    (type='Goal' or type='SavedShot')
	and not (events @> '{penaltyScored}' or events @> '{penaltyMissed}')
    and season >= 2014
    and goalmouthy is not null
    and goalmouthz is not null
    and expg > 0

union all

select opponentname, id, matchid, season, type, expg, goalmouthy, goalmouthz 
from englandpremierleague.event
where
    (type='Goal' or type='SavedShot')
	and not (events @> '{penaltyScored}' or events @> '{penaltyMissed}')
    and season >= 2014
    and goalmouthy is not null
    and goalmouthz is not null
    and expg > 0

union all

select opponentname, id, matchid, season, type, expg, goalmouthy, goalmouthz 
from germanybundesliga.event
where
    (type='Goal' or type='SavedShot')
	and not (events @> '{penaltyScored}' or events @> '{penaltyMissed}')
    and season >= 2014
    and goalmouthy is not null
    and goalmouthz is not null
    and expg > 0

union all 

select opponentname, id, matchid, season, type, expg, goalmouthy, goalmouthz 
from spainlaliga.event
where
    (type='Goal' or type='SavedShot')
	and not (events @> '{penaltyScored}' or events @> '{penaltyMissed}')
    and season >= 2014
    and goalmouthy is not null
    and goalmouthz is not null
    and expg > 0

--union all
--
--select opponentname, id, matchid, season, type, expg, goalmouthy, goalmouthz 
--from europechampionsleague.event
--where
--    (type='Goal' or type='SavedShot')
--	and not (events @> '{penaltyScored}' or events @> '{penaltyMissed}')
--    and season >= 2014
--    and goalmouthy is not null
--    and goalmouthz is not null
--    and expg > 0

;")

query <- dbSendQuery(conn, qtext)

shots <- fetch(query,n=-1)
data <- shots

situation <- "xgot"
#output <- calc_xg(shots)
	#type, expg, goalmouthy, goalmouthz
	data$type[data$type!="Goal"] <- 0
	data$type[data$type=="Goal"] <- 1
	data$type <- as.numeric(data$type)
	
    # Create Training Data
###	input_ones <- data[which(data$type == 1), ]  # all 1's
###	input_zeros <- data[which(data$type == 0), ]  # all 0's
###	
###	set.seed(100)  # for repeatability of samples
###	
###	input_ones_training_rows <- sample(1:nrow(input_ones), 0.7*nrow(input_ones))  # 1's for training
###	input_zeros_training_rows <- sample(1:nrow(input_zeros), 0.7*nrow(input_zeros))  # 0's for training
###	#input_zeros_training_rows <- sample(1:nrow(input_zeros), 0.7*nrow(input_ones))  # 0's for training. Pick as many 0's as 1's
###	
###	training_ones <- input_ones[input_ones_training_rows, ]  
###	training_zeros <- input_zeros[input_zeros_training_rows, ]
###	trainingData <- rbind(training_ones, training_zeros)  # row bind the 1's and 0's 
###
###	# Create Test Data
###	test_ones <- input_ones[-input_ones_training_rows, ]
###	test_zeros <- input_zeros[-input_zeros_training_rows, ]
###	testData <- rbind(test_ones, test_zeros)  # row bind the 1's and 0's 
	
	# Build model
###	logitMod <- glm(type ~ expg + goalmouthy + goalmouthz, data=trainingData, family=binomial(link="logit"))
	logitMod <- glm(type ~ expg + goalmouthy*goalmouthz, data=data, family=binomial)

###	predicted <- plogis(predict(logitMod, testData))  # predicted scores
	predicted <- predict(logitMod, data, type="response")  # predicted scores
	
###	testData$predicted <- predicted
	data$predicted <- predicted
	#sha <- testData[testData$season==2018,]
	#head(aggregate(sha$type, by=list(sha$opponent_name), FUN=sum))
	#head(aggregate(sha$predicted, by=list(sha$opponent_name), FUN=sum))
        modelfile <- paste0("R/glm_", situation, ".rds") 
        saveRDS(logitMod,modelfile)
        print(paste0("Saved model R/glm_", situation, ".rds"))

#write.csv(shots, file="/tmp/all_shots.csv", row.names=FALSE)

dbDisconnect(conn)
quit("no")

