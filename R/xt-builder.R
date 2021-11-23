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

closeAllConnections()

rm(list=ls())

info <- "xt-builder"

mid <- "1495478"

print(paste0("[ ", info, " ] starting R script"))

drv <- dbDriver("PostgreSQL")

conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")
qtext <- paste0("
with allc as (
    select x,y,type
    from italyseriea.event
    where 
    (
    type like '%Pass%' or
    type like '%Shot%' or
    type like '%Goal%' 
    )
    union all
    select x,y,type
    from germanybundesliga.event
    where 
    (
    type like '%Pass%' or
    type like '%Shot%' or
    type like '%Goal%' 
    )
    union all
    select x,y,type
    from englandpremierleague.event
    where 
    (
    type like '%Pass%' or
    type like '%Shot%' or
    type like '%Goal%' 
    )
    union all
    select x,y,type
    from spainlaliga.event
    where 
    (
    type like '%Pass%' or
    type like '%Shot%' or
    type like '%Goal%' 
    )
    )
select * from allc
;")

query <- dbSendQuery(conn, qtext)
events <- fetch(query,n=-1)

dbDisconnect(conn)
    
data <- events
data$x<-round(data$x/10,0)
data$y<-round(data$y/10,0)

dummy <- data.frame(c(0:10),c(0:10),c(rep("Goal",11)))
names(dummy) <- c("x","y","type")
data <- rbind(data,dummy)

data$is_shot <- grepl("Shot", data$type) | grepl("Goal", data$type)
data$is_goal <- grepl("Goal", data$type)

#Sha <- aggregate(data,by=list(data$is_shot,data$x,data$y),FUN=length, drop=F)
#Sha[is.na(sha)] <- 0
#Names(sha) <- c("is_shot","x","y", "hm_x", "hm_y", "hm_type", "hm_is_shot")

shots <- xtabs(~x+y, data[data$is_shot==T,])
passes <- xtabs(~x+y, data[data$is_shot==F,])
goals <- xtabs(~x+y, data[data$is_goal==T,])

sxy <- shots/(shots+passes)
mxy <- 1-sxy
gxy <- goals/shots
gxy[is.na(gxy)] <- 0
gxy[gxy==1] <- 0
goals[goals<13] <- 0  # o pezzott

