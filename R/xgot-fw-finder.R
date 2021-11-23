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
if (length(args)==0) {
    sid <- "englandpremierleague"
    season <- "2020"
    print(paste0("default stage_id=", sid))
} else {
    sid <- args[1]
    season <- args[2]
    print(paste0("selected stage_id=", sid))
}

print("[info]: Started xg-eq-finder2 R script")

# PSQL DB INTERROGATION
drv <- dbDriver("PostgreSQL")

conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")

qtext <- paste0("
select opponentname, opponentid, matchid, season, type, expg, goalmouthy, goalmouthz, expandedminute as minute
from ", sid,".event 
where
    (type='Goal' or type='SavedShot')
    and not (events @> '{penaltyScored}' or events @> '{penaltyMissed}')
    and season = ", season," 
    and goalmouthy is not null
    and goalmouthz is not null
;")
query <- dbSendQuery(conn, qtext)
shots <- fetch(query,n=-1)

###qtext <- paste0("
###select name, match_id, team_id, subbed_out_minute as minute
###from player
###where
###  stage_id=", sid,"
###  and position='GK'
###;")
###query <- dbSendQuery(conn, qtext)
###lineup <- fetch(query,n=-1)
###
###data <- shots[FALSE,]
###data$playername <- character(0)
###
###for (i in 1:nrow(shots)) {
###    #print(i)
###    dummy <- shots[i,]
###    dummy$playername <- ifelse(identical(lineup$name[which(lineup$minute>=shots$minute[i] & lineup$team_id==shots$opponent_id[i] & lineup$match_id == shots$match_id[i])],character(0)), 'Unknown player', lineup$name[which(lineup$minute>=shots$minute[i] & lineup$team_id==shots$opponent_id[i] & lineup$match_id == shots$match_id[i])])
###    #print(dummy)
###    #if (shots$minute[i])
###    data <- rbind(data,dummy)
###}

#output <- calc_xg(shots)
	#type, expg, goal_y, goal_z
data <- shots
	data$type[data$type!="Goal"] <- 0
	data$type[data$type=="Goal"] <- 1
	data$type <- as.numeric(data$type)
	
    # Create Training Data
	situation <- "xgot"
        modelfile <- paste0("R/glm_", situation, ".rds") 
        model <- readRDS(modelfile)
        data$xgot <- predict(model, data, type="response")

        df <- data.frame(data$playername, data$expg, data$xgot, data$type, data$shots)
        
        names(df) <- c("playername","expg","xgot","goals","saves","shots")
        df <- df %>% group_by(playername) %>% summarise_all(funs(sum))

        df$delta <- df$xgot / df$goals

        df$savepct <- 100*(1 - df$goals/df$shots)
        df$expg <- round(df$expg,1)
        df$xgot <- round(df$xgot,1)
        df$delta <- round(df$delta,2)
        df$savepct <- round(df$savepct,1)

        output <- data.frame(df$playername, df$expg, df$shots, df$saves, df$goals, df$xgot, df$delta, df$savepct)
        output <- output[output$df.playername != "Unknown player",]

        print(output[order(-output$delta),])

csvfile <- paste0("/tmp/xgot_stage_id_", sid, ".csv")
write.csv(output, csvfile, row.names=FALSE)

dbDisconnect(conn)
quit("no")

