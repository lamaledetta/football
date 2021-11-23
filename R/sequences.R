#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
sink("./log/xg-eq-finder.log")

oldw <- getOption("warn")
options(warn=-1)

suppressMessages(library("dplyr"))
#library("lme4")
library("RPostgreSQL")
#library("caret")
#library("ggplot2")
#library("randomForest")
#library("png")

closeAllConnections()

info <- "sequences"




################
# 
# MAIN PROGRAM
# 
################


#font_import())
#if (Sys.info())[['sysname']]=="Darwin")) { font_f="TeX Gyre Adventor" } else { font_f="AvantGarde" }

# ARGUMENTS
if (length(args)==0) {
    print("I need arguments...")
	quit("no")
} else {
    stage    <- args[1]
    season   <- args[2]
}

print(paste0("[ ", info, " ] starting R script"))

# DB REQUEST
drv <- dbDriver("PostgreSQL")
conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")

qtext <- paste0("
select * 
from ", stage,".event 
where
		season=", season,"
;")
query <- dbSendQuery(conn, qtext)

sha <- fetch(query,n=-1)

#sha <- read.csv("match.csv")

events <- sha
events$position[events$position!='GK'] <- 'AA'
events$position[grepl("outfielderBlock", events$events)] <- 'GK'

#events <- events[order(events$matchid, events$expandedminute, events$second, events$position),]
#events$ex_second <- events$expandedminute*60 + events$second
events$ex_second <- 0

events$shot_time <- 0
events$shot_space <- 0
events$passes <- 0
events$poss_start <- 0
events$poss_min <- 0
events$shot_x <- 0
events$is_shot <- 1*grepl("shotsTotal", events$events)


events <- events[!grepl("challengeLost", events$events),]
events <- events[!grepl("tackleLost", events$events),]
#events <- events[!grepl("clearanceTotal", events$events),]
events <- events[!grepl("CornerAwarded", events$events),]
events <- events[!grepl("cornerAwarded", events$events),]
events <- events[!grepl("duelAerialLost", events$events),]

collected <- slice(events,0)

uniqueids <- unique(events$matchid)

for (i in uniqueids) { 
    for (j in 1:2) {
        #print(i) 
        halfmatch <- events[events$matchid == i & events$period == j,]


        halfmatch$ex_second <- halfmatch$expandedminute*60 + halfmatch$second
        halfmatch$relatedeventid[is.na(halfmatch$relatedeventid)] <- 0
        halfmatch <- halfmatch[order(halfmatch$ex_second, halfmatch$position, halfmatch$relatedeventid),]
        
        halfmatch$turnover <- c(0,diff(halfmatch$teamid))
        halfmatch$turnover <- ifelse(halfmatch$turnover!=0, 1, 0)
	halfmatch$turnover <- 1*(halfmatch$is_shot | grepl("throwIn", halfmatch$events) | grepl("keyPassFreekick", halfmatch$events) | grepl("passFreekickAccurate", halfmatch$events) | grepl("passFreekick", halfmatch$events) | grepl("passFreekickInaccurate", halfmatch$events) |  halfmatch$turnover)
        halfmatch$turnover[1] <- 1

        time_to_turnover <- 0
        mt_to_turnover <- 0
        pass_to_turnover <- 0
        min_pass <- 999
        FK <- 0


        for(k in 1:nrow(halfmatch)) {
            
            if (halfmatch$turnover[k] == 1 && halfmatch$is_shot[k] == 0) {
                time_to_turnover <- halfmatch$ex_second[k]
                mt_to_turnover <- halfmatch$x[k]
                min_pass <- halfmatch$x[k]
                pass_to_turnover <- 0
                FK <- 1 * (grepl("passFreekick", halfmatch$events[k]) | grepl("penaltyConceded", halfmatch$events[k])) # penaltyWon, penaltyConceded # passCorner,passCornerAccurate,passFreekick
            }
            
            else if (halfmatch$turnover[k] == 0 && halfmatch$is_shot[k] == 1) {
                if (FK == 1) {
                    halfmatch$is_shot[k] <- 0
                    FK <- 0
                }
                halfmatch$shot_time[k] <- halfmatch$ex_second[k] - time_to_turnover
                halfmatch$shot_space[k] <- halfmatch$x[k] - mt_to_turnover
                halfmatch$passes[k] <- pass_to_turnover
                halfmatch$poss_start[k] <- mt_to_turnover
                halfmatch$poss_min[k] <- min_pass
                halfmatch$shot_x[k] <- halfmatch$x[k] 
                time_to_turnover <- 0
                mt_to_turnover <- 0
                pass_to_turnover <- 0
                min_pass <- 999
            }
        
            else if (halfmatch$turnover[k] == 1 && halfmatch$is_shot[k] == 1) {
                if (FK == 1) {
                    halfmatch$is_shot[k] <- 0
                    FK <- 0
                }
                halfmatch$shot_time[k] <- halfmatch$ex_second[k] - time_to_turnover
                halfmatch$shot_space[k] <- halfmatch$x[k] - mt_to_turnover
                halfmatch$passes[k] <- pass_to_turnover
                halfmatch$poss_start[k] <- mt_to_turnover
                halfmatch$poss_min[k] <- min_pass
                halfmatch$shot_x[k] <- halfmatch$x[k] 
                time_to_turnover <- 0
                mt_to_turnover <- 0
                pass_to_turnover <- 0
                min_pass <- 999
                
                time_to_turnover <- halfmatch$ex_second[k]
                mt_to_turnover <- halfmatch$x[k]
                min_pass <- halfmatch$x[k]
                pass_to_turnover <- 0
                FK <- 1 * (grepl("passFreekick", halfmatch$events[k]) | grepl("penaltyConceded", halfmatch$events[k])) # penaltyWon, penaltyConceded # passCorner,passCornerAccurate,passFreekick
            }

            if (halfmatch$x[k] < min_pass) {
                min_pass <- halfmatch$x[k]
            }
            pass_to_turnover <- pass_to_turnover + 1
            
        }


        collected <- rbind(collected, halfmatch)
        
    }
}

tump <- data.frame(collected$matchid, collected$starttime, collected$teamname, collected$field, collected$playername, collected$period, collected$minute, collected$second, collected$events, collected$shot_time, collected$shot_space, collected$passes, collected$is_shot, collected$poss_start, collected$poss_min, collected$shot_x)
print(paste0("tump rows count: ",nrow(tump)))
write.csv(tump, "/tmp/collected.csv", row.names=F, na="")

df <- data.frame(collected$teamname, collected$shot_time, collected$shot_space, collected$passes, collected$is_shot, collected$poss_start, collected$poss_min, collected$shot_x)
names(df) <- c("teamname", "time", "space", "passes", "isshot", "startx", "minx", "endx")

df <- df[df$isshot==1,]
df <- df[!(df$time==0 | df$space==0 | df$passes==0),]
df <- df[df$space>0,]
df <- df[df$passes>1,]

df <- df %>% group_by(teamname) %>% summarise_all(funs(mean))
names(df) <- c("teamname", "time", "space", "passes", "speed","startx","minx","endx")
df$speed <- (df$endx-df$minx)/df$time


write.csv(df, "/tmp/team_sequences.csv", row.names=F, na="")
try(system("sed -e 's#\\,#;#g' -i '' /tmp/team_sequences.csv" ))
try(system("sed -e 's#\\.#,#g' /tmp/team_sequences.csv > /Users/giacobba/Desktop/team_sequences.csv" ))
dbDisconnect(conn)
#print(paste0("[ ", info, " ] End of script"))
quit("no")


### DEPRECATED ###events$turnover <- c(0,diff(events$teamid))
### DEPRECATED ###events$turnover <- ifelse(events$turnover!=0, 1, 0)
### DEPRECATED ###events$turnover[1] <- 1
### DEPRECATED ####events$turnover2 <- c(0,diff(events$matchid))
### DEPRECATED ####events$turnover2 <- ifelse(events$turnover2!=0, 1, 0)
### DEPRECATED ####events$turnover[events$turnover2 == 1] <- 0
### DEPRECATED ###
### DEPRECATED ###time_to_turnover <- 0
### DEPRECATED ###mt_to_turnover <- 0
### DEPRECATED ###pass_to_turnover <- 0
### DEPRECATED ###min_pass <- 999
### DEPRECATED ###FK <- 0
### DEPRECATED ###
### DEPRECATED ###for(i in 1:nrow(events)) {
### DEPRECATED ###    
### DEPRECATED ###    if (events$turnover[i] == 1) {
### DEPRECATED ###        time_to_turnover <- events$ex_second[i]
### DEPRECATED ###        mt_to_turnover <- events$x[i]
### DEPRECATED ###        min_pass <- events$x[i]
### DEPRECATED ###        pass_to_turnover <- 0
### DEPRECATED ###        FK <- 1 * (grepl("passFreekick", events$events[i]) | grepl("penaltyConceded", events$events[i])) # penaltyWon, penaltyConceded # passCorner,passCornerAccurate,passFreekick
### DEPRECATED ###    }
### DEPRECATED ###    
### DEPRECATED ###    else if (events$is_shot[i] == 1) {
### DEPRECATED ###        if (FK == 1) {
### DEPRECATED ###            events$is_shot[i] <- 0
### DEPRECATED ###            FK <- 0
### DEPRECATED ###        }
### DEPRECATED ###        events$shot_time[i] <- events$ex_second[i] - time_to_turnover
### DEPRECATED ###        events$shot_space[i] <- events$x[i] - mt_to_turnover
### DEPRECATED ###        events$passes[i] <- pass_to_turnover
### DEPRECATED ###        events$poss_start[i] <- mt_to_turnover
### DEPRECATED ###        events$poss_min[i] <- min_pass
### DEPRECATED ###        events$shot_x[i] <- events$x[i] 
### DEPRECATED ###        time_to_turnover <- 0
### DEPRECATED ###        mt_to_turnover <- 0
### DEPRECATED ###        pass_to_turnover <- 0
### DEPRECATED ###        min_pass <- 999
### DEPRECATED ###    }
### DEPRECATED ###
### DEPRECATED ###    if (events$x[i] < min_pass) {
### DEPRECATED ###        min_pass <- events$x[i]
### DEPRECATED ###    }
### DEPRECATED ###    pass_to_turnover <- pass_to_turnover + 1
### DEPRECATED ###    
### DEPRECATED ###}
### DEPRECATED ###
### DEPRECATED ###df <- data.frame(events$teamname, events$shot_time, events$shot_space, events$passes, events$is_shot, events$poss_start, events$poss_min, events$shot_x)
### DEPRECATED ###names(df) <- c("teamname", "time", "space", "passes", "isshot", "startx", "minx", "endx")
### DEPRECATED ###df <- df[df$isshot==1,]
### DEPRECATED ###df <- df[!(df$time==0 | df$space==0 | df$passes==0),]
### DEPRECATED ###
### DEPRECATED ###df <- df[df$space>0,]
### DEPRECATED ###df <- df[df$passes>1,]
### DEPRECATED ###
### DEPRECATED ###df <- df %>% group_by(teamname) %>% summarise_all(funs(mean))
### DEPRECATED ###names(df) <- c("teamname", "time", "space", "passes", "speed","startx","minx","endx")
### DEPRECATED ###df$speed <- (df$endx-df$minx)/df$time
### DEPRECATED ###
### DEPRECATED ###
### DEPRECATED ###write.csv(df, "/tmp/team_sequences.csv", row.names=F, na="")
### DEPRECATED ###try(system("sed -e 's#\\,#;#g' -i '' /tmp/team_sequences.csv" ))
### DEPRECATED ###try(system("sed -e 's#\\.#,#g' /tmp/team_sequences.csv > /Users/giacobba/Desktop/team_sequences.csv" ))
### DEPRECATED ###dbDisconnect(conn)
### DEPRECATED ####print(paste0("[ ", info, " ] End of script"))
### DEPRECATED ###quit("no")
