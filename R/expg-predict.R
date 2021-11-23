#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
sink("./log/xg-eq-finder.log")

oldw <- getOption("warn")
options(warn=-1)

suppressMessages(library("dplyr"))
#library("lme4")
#library("RPostgreSQL")
#library("caret")
#library("ggplot2")
#library("randomForest")
#library("png")

closeAllConnections()

info <- "expg-predict"

print(paste0("[ ", info, " ] starting R script"))

# INPUT ARGUMENTS
if (length(args)==0) {
    print(paste0("[ ", info, " ] missing input csve file"))
    #filename <- "1317975.csve"
    #mid <- gsub(pattern = "\\.csve$", "", filename)
    #print(paste0("[ ", info, " ] selected match: ", mid))
    quit("no")
} else {
    filename <- args[1]
    mid <- gsub(pattern = "\\.csv$", "", filename)
    print(paste0("[ ", info, " ] selected match: ", mid))
}


# FILE READ
events <- read.csv(filename)
print(paste0("[ ", info, " ] fetched ", nrow(events), " lines"))

events$expg <- rep(0,nrow(events))
events$expgr <- rep(0,nrow(events))
events$expa <- rep(0,nrow(events))


# REL EVENTS LOOP
df <- events
df$relatedEvents <- 0
newevents <- slice(df,0)

team <- unique(df$teamId)

df_a <- df[df$teamId==team[1],]
df_b <- df[df$teamId==team[2],]

lookup_a <- unique(df_a)
lookup_b <- unique(df_b)

df_a$relatedEvents <- with(lookup_a,
                     satisfiedEventsTypes[match(df_a$relatedEventId,
                                   eventId)])

df_b$relatedEvents <- with(lookup_b,
                     satisfiedEventsTypes[match(df_b$relatedEventId,
                                   eventId)])

newevents <- rbind(newevents,df_a)
newevents <- rbind(newevents,df_b)

events <- newevents


# SHOT EVENTS
events$shotFoot<-grepl("shotLeftFoot",events$satisfiedEventsTypes) | grepl("shotRightFoot",events$satisfiedEventsTypes)
events$shotHead<-grepl("shotHead",events$satisfiedEventsTypes)

events$shotOpenPlay<-grepl("shotOpenPlay",events$satisfiedEventsTypes)
events$shotSetPiece<-grepl("shotSetPiece",events$satisfiedEventsTypes)
events$shotCounter<-grepl("shotCounter",events$satisfiedEventsTypes)

# ASSIST EVENTS
events$keyPassShort<-grepl("keyPassShort",events$relatedEvents)
events$keyPassLong<-grepl("keyPassLong",events$relatedEvents)
events$keyPassCross<-grepl("keyPassCross",events$relatedEvents)
events$keyPassFreekick<-grepl("keyPassFreekick",events$relatedEvents)
events$keyPassCorner<-grepl("keyPassCorner",events$relatedEvents)
events$keyPassThroughball<-grepl("keyPassThroughball",events$relatedEvents)
events$keyPassThrowin<-grepl("keyPassThrowin",events$relatedEvents)
#events$keyPassOther<-grepl("keyPassOther",events$relatedEvents)

events$turnover<-grepl("turnover",events$relatedEvents)
events$overrun<-grepl("overrun",events$relatedEvents)
events$tackleWon<-grepl("tackleWon",events$relatedEvents)
events$interceptionWon<-grepl("interceptionWon",events$relatedEvents)
events$clearanceEffective<-grepl("clearanceEffective",events$relatedEvents)
events$outfielderBlockedPass<-grepl("outfielderBlockedPass",events$relatedEvents) | grepl("outfielderBlock",events$relatedEvents)

events$passAccurate<-grepl("passAccurate",events$relatedEvents)
events$passInaccurate<-grepl("passInaccurate",events$relatedEvents)

events$passForward<-grepl("passForward",events$relatedEvents)
events$passBack<-grepl("passBack",events$relatedEvents)
events$passLeft<-grepl("passLeft",events$relatedEvents)
events$passRight<-grepl("passRight",events$relatedEvents)

events$bigChanceCreated<-grepl("bigChanceCreated",events$relatedEvents)

events$passHead<-grepl("passHead",events$relatedEvents)


# COORDINATES
events$x1 <- 100 - events$x
#events$y1 <- 50 - events$y
events$y1 <- 54.8
events$y2 <- 45.2
events$yd <- 50.0

#d1 <- sqrt(x^2+(y-y1)^2)
events$dist1 <- sqrt(events$x1^2+(events$y-events$y1)^2)
events$dist2 <- sqrt(events$x1^2+(events$y-events$y2)^2)
events$dist  <- sqrt(events$x1^2+(events$y-events$yd)^2)

#alpha <- asin((y-y2)/d2)
events$alpha <- asin((events$y-events$y2)/events$dist2)
events$alpha[is.na(events$alpha)==TRUE] <- pi/2
#gamma <- asin((y-y1)/d1)
events$gamma <- asin((events$y-events$y1)/events$dist1)
events$gamma[is.na(events$gamma)==TRUE] <- -pi/2
events$angle <- round((events$alpha - events$gamma)*180/pi,1)

# FIX FOR GOALMOUTH NAMES
events$goalmouthz <- events$goalMouthZ 
events$goalmouthy <- events$goalMouthY 
events$goalmouthz[is.na(events$goalmouthz)] <- 30
events$goalmouthy[is.na(events$goalmouthy)] <- 52

# FIX FOR NO SITUATION SHOTS
events$shotOpenPlay[events$shotOpenPlay==FALSE & events$shotSetPiece==FALSE & events$shotCounter==FALSE] <- TRUE 

events$avgpossession <- events$avgPossession
events$avgpossession[is.na(events$avgpossession)] <- 50

# OPEN-PLAY SHOTS
shots <- events[grepl("shotsTotal", events$satisfiedEventsTypes),]
shots <- shots[shots$dist1 <= 2 | shots$dist2 <= 2 | shots$angle >= 63,]

if (nrow(shots) != 0) {
    situation <- "near"
    modelfile <- paste0("R/glm_", situation, ".rds") 
    model <- readRDS(modelfile)
    shots$expg <- round(predict(model, shots, type="response"),3)
    for(i in shots$id) { 
        events$expg[events$id==i] <- shots$expg[shots$id==i] 
        relev <- shots$relatedEventId[shots$id==i]
        relteam <- shots$teamId[shots$id==i]
        events$expa[events$eventId==relev & events$teamId==relteam] <- shots$expg[shots$id==i] 
    }
}

# SHOTS ON COUNTER
shots <- events[grepl("shotsTotal", events$satisfiedEventsTypes),]
shots <- shots[(shots$dist1 > 2 & shots$dist2 > 2 & shots$angle < 63) & shots$dist < 9.6,]

if (nrow(shots) != 0) {
    situation <- "medium"
    modelfile <- paste0("R/glm_", situation, ".rds") 
    model <- readRDS(modelfile)
    shots$expg <- round(predict(model, shots, type="response"),3)
    for(i in shots$id) { 
        events$expg[events$id==i] <- shots$expg[shots$id==i] 
        relev <- shots$relatedEventId[shots$id==i]
        relteam <- shots$teamId[shots$id==i]
        events$expa[events$eventId==relev & events$teamId==relteam] <- shots$expg[shots$id==i] 
    }
}


# SET-PIECE SHOTS
shots <- events[grepl("shotsTotal", events$satisfiedEventsTypes),]
shots <- shots[shots$dist >= 9.6,]

if (nrow(shots) != 0) {
    situation <- "long"
    modelfile <- paste0("R/glm_", situation, ".rds") 
    model <- readRDS(modelfile)
    shots$expg <- round(predict(model, shots, type="response"),3)
    for(i in shots$id) { 
        events$expg[events$id==i] <- shots$expg[shots$id==i] 
        relev <- shots$relatedEventId[shots$id==i]
        relteam <- shots$teamId[shots$id==i]
        events$expa[events$eventId==relev & events$teamId==relteam] <- shots$expg[shots$id==i] 
    }
}


# EXPGR CALCULATION
events$expgr <- events$expg
shots <- events[grepl("shotsTotal", events$satisfiedEventsTypes),]
print(paste0("[ ", info, " ] worked ", nrow(shots), " shots"))

shots$expanded_second <- shots$expandedMinute*60 + shots$second
shots <- shots[order(shots$expanded_second),]

shots$diff <- c(diff(shots$expanded_second),999)

saved <- 0
savedminus <- 0

for (i in 1:nrow(shots)) {

	if (shots$diff[i] <= 5) {
		
		if (saved == 0) {
			# first shot of a sequence
			saved <- shots$expgr[i]
			savedminus <- 1 - shots$expgr[i]
			shots$expgr[i] <- 0
		} else {
			# another shot of a sequence
			saved <- saved + shots$expgr[i]*savedminus
			savedminus <- savedminus*(1 - shots$expgr[i])
			shots$expgr[i] <- 0
		}
		
	} else {
		
		if (saved != 0) {
			# last shot of a sequence
			shots$expgr[i] <- saved + shots$expgr[i]*savedminus
			saved <- 0
			savedminus <- 0
		}
	}
}

shots$expgr <- round(shots$expgr,3)
for(i in shots$id) { events$expgr[events$id==i] <- shots$expgr[shots$id==i] }
print(aggregate(shots$expgr, by=list(shots$teamName), FUN=sum))

# SAVE FILE
write.csv(events[,1:52], paste0(mid,".csve"), na="", quote=F, row.names=F)

options(warn=oldw)
print(paste0("[ ", info, " ] ending R script"))
quit("no")

