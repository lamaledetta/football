#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
sink("./log/xg-eq-finder.log")

suppressMessages(library("dplyr"))
suppressMessages(library("lme4"))
suppressMessages(library("RPostgreSQL"))
suppressMessages(library("caret"))
suppressMessages(library("ggplot2"))
suppressMessages(library("randomForest"))
suppressMessages(library("png"))

#library("smbinning")

closeAllConnections()

##################################
##
##          MAIN PROGRAM
##
##################################

# INPUT ARGUMENTS
if (length(args)==0) {
    sid <- "italyseriea"
    season <- "2018"
    print(paste0("default stage_id=", sid))
    print(paste0("default season=", sid))
} else {
    sid <- args[1]
    season <- args[2]
    print(paste0("selected stage_id=", sid))
    print(paste0("selected season=", season))
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
    and goalmouthy is not null
    and goalmouthz is not null
    and season = ", season," 
;")
query <- dbSendQuery(conn, qtext)
shots <- fetch(query,n=-1)

qtext <- paste0("
select playername, matchid, teamid, round(avg(minsplayed),0) as minute
from ", sid, ".event 
where
  position='GK'
group by
  playername, matchid, teamid
;")
query <- dbSendQuery(conn, qtext)
lineup <- fetch(query,n=-1)

lineup$subbed_in <- 0
lineup$subbed_out <- 999

if (nrow(lineup[lineup$minute!=90,]) !=0 ) {

    print("[info]: Found GKs with less than 90 mins")
    
    qtext <- paste0("
    select playername, matchid, teamid, expandedminute as minute
    from ", sid, ".event 
    where
      position='GK'
    and (events @> '{subOff}' or events @> '{subOn}') 
    ;")
    query <- dbSendQuery(conn, qtext)
    subs <- fetch(query,n=-1)

}

data <- shots[FALSE,]
data$playername <- character(0)

for (i in 1:nrow(shots)) {
    #print(i)
    dummy <- shots[i,]
    dummy$playername <- ifelse(identical(lineup$playername[which(lineup$subbed_out>=shots$minute[i] & lineup$teamid==shots$opponentid[i] & lineup$matchid == shots$matchid[i])],character(0)), 'Unknown player', lineup$playername[which(lineup$subbed_out>=shots$minute[i] & lineup$teamid==shots$opponentid[i] & lineup$matchid == shots$matchid[i])])
    #print(dummy)
    #if (shots$minute[i])
    data <- rbind(data,dummy)
}

#output <- calc_xg(shots)
	#outcome, expg, goal_y, goal_z
	data$type[data$type!="Goal"] <- 0
	data$type[data$type=="Goal"] <- 1
	data$type <- as.numeric(data$type)

        data$saves <- 1 - data$type
        data$shots <- 1
	
    # Create Training Data
	situation <- "xgot"
        modelfile <- paste0("R/glm_", situation, ".rds") 
        model <- readRDS(modelfile)
        data$xgot <- predict(model, data, type="response")

        df <- data.frame(data$playername, data$expg, data$xgot, data$type, data$saves, data$shots)
        
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

        print(output[order(-output$df.delta),])

csvfile <- paste0("/tmp/xgot_stage_id_", sid, ".csv")
write.csv(output, csvfile, row.names=FALSE)

dbDisconnect(conn)
quit("no")

