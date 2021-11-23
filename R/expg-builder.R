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

closeAllConnections()

rm(list=ls())
info <- "expg-builder"

print(paste0("[ ", info, " ] starting R script"))

# PSQL DB INTERROGATION
if (!file.exists("/tmp/newevents.csv")) {

    drv <- dbDriver("PostgreSQL")
    
    conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")
    qtext <- paste0("
        with allc as (
            select * from italyseriea.event where not events @> '{shotBlocked}' and not events @> '{penaltyScored}' and not events @> '{penaltyMissed}' and not events @> '{goalOwn}'
            union all
            select * from germanybundesliga.event where not events @> '{shotBlocked}' and not events @> '{penaltyScored}' and not events @> '{penaltyMissed}' and not events @> '{goalOwn}'
            union all
            select * from englandpremierleague.event where not events @> '{shotBlocked}' and not events @> '{penaltyScored}' and not events @> '{penaltyMissed}' and not events @> '{goalOwn}'
            union all
            select * from spainlaliga.event where not events @> '{shotBlocked}' and not events @> '{penaltyScored}' and not events @> '{penaltyMissed}' and not events @> '{goalOwn}'
            union all
            select * from europechampionsleague.event where not events @> '{shotBlocked}' and not events @> '{penaltyScored}' and not events @> '{penaltyMissed}' and not events @> '{goalOwn}'
        ) 
        select * from allc
    ;")
    
    query <- dbSendQuery(conn, qtext)
    events <- fetch(query,n=-1)
    
    dbDisconnect(conn)
    
    print(paste0("[ ", info, " ] fetched ", nrow(events), " lines"))
    print(paste0("[ ", info, " ] going into the loop..."))

    events$type[events$type!='Goal'] <- 0
    events$type[events$type=='Goal'] <- 1
    events$type <- as.integer(events$type)
    
    table(as.integer(events$type))

    dummy <- events
    dummy$relatedevents <- 0
    newevents <- slice(dummy,0)
    
    for(i in unique(events$matchid)) { 
        df <- events[events$matchid==i,]
    
        team <- unique(df$teamid)
    
        df_a <- df[df$teamid==team[1],]
        df_b <- df[df$teamid==team[2],]
        
        lookup_a <- unique(df_a)
        lookup_b <- unique(df_b)
    
        df_a$relatedevents <- with(lookup_a,
                             events[match(df_a$relatedeventid,
                                           eventid)])
    
        df_b$relatedevents <- with(lookup_b,
                             events[match(df_b$relatedeventid,
                                           eventid)])
    
        newevents <- rbind(newevents,df_a)
        newevents <- rbind(newevents,df_b)
        
    }

    write.csv(newevents, "/tmp/newevents.csv")
    events <- newevents

} else {
    
    events <- read.csv("/tmp/newevents.csv")
}

shots <- events[grepl("shotsTotal", events$events),]

# SHOT EVENTS
shots$shotFoot<-grepl("shotLeftFoot",shots$events) | grepl("shotRightFoot",shots$events)
shots$shotHead<-grepl("shotHead",shots$events)

shots$shotOpenPlay<-grepl("shotOpenPlay",shots$events)
shots$shotSetPiece<-grepl("shotSetPiece",shots$events)
shots$shotCounter<-grepl("shotCounter",shots$events)

# ASSIST EVENTS
shots$keyPassShort<-grepl("keyPassShort",shots$relatedevents)
shots$keyPassLong<-grepl("keyPassLong",shots$relatedevents)
shots$keyPassCross<-grepl("keyPassCross",shots$relatedevents)
shots$keyPassFreekick<-grepl("keyPassFreekick",shots$relatedevents)
shots$keyPassCorner<-grepl("keyPassCorner",shots$relatedevents)
shots$keyPassThroughball<-grepl("keyPassThroughball",shots$relatedevents)
shots$keyPassThrowin<-grepl("keyPassThrowin",shots$relatedevents)
#shots$keyPassOther<-grepl("keyPassOther",shots$relatedevents)

shots$turnover<-grepl("turnover",shots$relatedevents)
shots$overrun<-grepl("overrun",shots$relatedevents)
shots$tackleWon<-grepl("tackleWon",shots$relatedevents)
shots$interceptionWon<-grepl("interceptionWon",shots$relatedevents)
shots$clearanceEffective<-grepl("clearanceEffective",shots$relatedevents)
shots$outfielderBlockedPass<-grepl("outfielderBlockedPass",shots$relatedevents) | grepl("outfielderBlock",shots$relatedevents)

shots$passAccurate<-grepl("passAccurate",shots$relatedevents)
shots$passInaccurate<-grepl("passInaccurate",shots$relatedevents)

shots$passForward<-grepl("passForward",shots$relatedevents)
shots$passBack<-grepl("passBack",shots$relatedevents)
shots$passLeft<-grepl("passLeft",shots$relatedevents)
shots$passRight<-grepl("passRight",shots$relatedevents)

shots$bigChanceCreated<-grepl("bigChanceCreated",shots$relatedevents)

shots$passHead<-grepl("passHead",shots$relatedevents)

# COORDINATES
shots$x1 <- 100 - shots$x
#shots$y1 <- 50 - shots$y
shots$y1 <- 54.8
shots$y2 <- 45.2
shots$yd <- 50.0

#d1 <- sqrt(x^2+(y-y1)^2)
shots$dist1 <- sqrt(shots$x1^2+(shots$y-shots$y1)^2)
shots$dist2 <- sqrt(shots$x1^2+(shots$y-shots$y2)^2)
shots$dist  <- sqrt(shots$x1^2+(shots$y-shots$yd)^2)

#alpha <- asin((y-y2)/d2)
shots$alpha <- asin((shots$y-shots$y2)/shots$dist2)
shots$alpha[is.na(shots$alpha)==TRUE] <- pi/2
#gamma <- asin((y-y1)/d1)
shots$gamma <- asin((shots$y-shots$y1)/shots$dist1)
shots$gamma[is.na(shots$gamma)==TRUE] <- -pi/2
shots$angle <- round((shots$alpha - shots$gamma)*180/pi,1)
#shots$angle <- asin(shots$y1/shots$dist)
#shots$angle <- round(shots$angle*180/pi,1)
#shots$angle[is.na(shots$angle)==TRUE] <- pi/2
#shots$angle[shots$angle==0] <- 0.001

#shots$inv_dist <- 1/shots$dist
#shots$inv_angle <- 1/shots$angle
#shots$inv_dist_angle <- 1/(shots$dist*shots$angle)


# FIX FOR NO SITUATION SHOTS
shots$shotOpenPlay[shots$shotOpenPlay==FALSE & shots$shotSetPiece==FALSE & shots$shotCounter==FALSE] <- TRUE 


print(paste0("[ ", info, " ] calculating formula..."))

# MODEL FORMULA 
formula <- type ~ dist1 + dist2 + angle +
			shotFoot + shotHead + 
			shotOpenPlay + shotSetPiece + shotCounter +
			keyPassShort + keyPassLong + keyPassCross + keyPassFreekick + keyPassCorner + keyPassThroughball + keyPassThrowin + 
			turnover + overrun + tackleWon + interceptionWon + clearanceEffective + outfielderBlockedPass +
			passAccurate + passInaccurate +
			passForward + passBack + passLeft + passRight +
			bigChanceCreated +
			passHead +
                        avgpossession +
                        goalmouthz + goalmouthy


# NEAR RANGE SHOTS
situation <- "near"
opshots <- shots[shots$dist1 <= 2 | shots$dist2 <= 2 | shots$angle >= 63,]
opmodel <- glm(formula, opshots, family=binomial)
opshots$expg <- predict(opmodel, opshots, type="response")

modelfile <- paste0("R/glm_", situation, ".rds") 
saveRDS(opmodel,modelfile)
print(paste0("Saved model R/glm_", situation, ".rds"))

# MEDIUM RANGE SHOTS
situation <- "medium"
cntshots <- shots[(shots$dist1 > 2 & shots$dist2 > 2 & shots$angle < 63) & shots$dist < 9.6,]
cntmodel <- glm(formula, cntshots, family=binomial)
cntshots$expg <- predict(cntmodel, cntshots, type="response")

modelfile <- paste0("R/glm_", situation, ".rds") 
saveRDS(cntmodel,modelfile)
print(paste0("Saved model R/glm_", situation, ".rds"))

#LONG RANGE SHOTS
situation <- "long"
spshots <- shots[shots$dist >= 9.6,]
spmodel <- glm(formula, spshots, family=binomial)
spshots$expg <- predict(spmodel, spshots, type="response")

modelfile <- paste0("R/glm_", situation, ".rds") 
saveRDS(spmodel,modelfile)
print(paste0("Saved model R/glm_", situation, ".rds"))


                    
###### OPEN-PLAY SHOTS
#####situation <- "open-play"
#####opshots <- shots[shots$shotOpenPlay==TRUE & shots$shotSetPiece==FALSE & shots$shotCounter==FALSE,]
#####opshots <- shots
#####formula <- type ~ dist + angle + inv_dist + inv_angle + inv_dist_angle +
#####			shotFoot + shotHead + keyPassShort + bigChanceCreated + avgpossession + shotOpenPlay
#####opmodel <- glm(formula, opshots, family=binomial)
#####opshots$expg <- predict(opmodel, opshots, type="response")
#####
#####modelfile <- paste0("R/glm_", situation, ".rds") 
#####saveRDS(opmodel,modelfile)
#####print(paste0("Saved model R/glm_", situation, ".rds"))
#####
#####
###### SHOTS ON COUNTER
#####situation <- "counter"
#####cntshots <- shots[shots$shotOpenPlay==FALSE & shots$shotSetPiece==FALSE & shots$shotCounter==TRUE,]
#####cntshots <- shots
#####formula <- type ~ dist + angle + inv_dist + inv_angle + inv_dist_angle +
#####			shotFoot + shotHead + keyPassShort + bigChanceCreated + avgpossession + shotCounter
#####cntmodel <- glm(formula, cntshots, family=binomial)
#####cntshots$expg <- predict(cntmodel, cntshots, type="response")
#####
#####modelfile <- paste0("R/glm_", situation, ".rds") 
#####saveRDS(cntmodel,modelfile)
#####print(paste0("Saved model R/glm_", situation, ".rds"))
#####
#####
###### SET-PIECE SHOTS
#####situation <- "set-piece"
#####spshots <- shots[shots$shotOpenPlay==FALSE & shots$shotSetPiece==TRUE & shots$shotCounter==FALSE,]
#####spshots <- shots
#####formula <- type ~ dist + angle + inv_dist + inv_angle + inv_dist_angle +
#####			shotFoot + shotHead + keyPassShort + bigChanceCreated + avgpossession + shotSetPiece
#####spmodel <- glm(formula, spshots, family=binomial)
#####spshots$expg <- predict(spmodel, spshots, type="response")
#####
#####modelfile <- paste0("R/glm_", situation, ".rds") 
#####saveRDS(spmodel,modelfile)
#####print(paste0("Saved model R/glm_", situation, ".rds"))


print(paste0("[ ", info, " ] ending R script"))
#quit("no")
