#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#sink("logs/xg-equation-finder.log")
suppressMessages(library("dplyr"))
suppressMessages(library("tidyr"))
#suppressMessages(library("RPostgreSQL"))
suppressMessages(library(png))
suppressMessages(library(ggplot2))
suppressMessages(library(pracma))
#library("ggplot2")
#library("jpeg")
suppressMessages(library("grid"))
#library("extrafont")
suppressMessages(library(gtable))

oldw <- getOption("warn")
options(warn=-1)
closeAllConnections()

info <- "pass-map"

print(paste0("[ ", info, " ] starting R script"))


# PROCEDURES
###ggplot_with_subtitle <- function(gg, 
###                                 label="", 
###                                 fontfamily=NULL,
###                                 fontsize=10,
###                                 hjust=0, vjust=0, 
###                                 bottom_margin=5.5,
###                                 newpage=is.null(vp),
###                                 vp=NULL,
###                                 ...) {
###  
###  if (is.null(fontfamily)) {
###    gpr <- gpar(fontsize=fontsize, ...)
###  } else {
###    gpr <- gpar(fontfamily=fontfamily, fontsize=fontsize, ...)
###  }
###  
###  subtitle <- textGrob(label, x=unit(hjust, "npc"), y=unit(hjust, "npc"), 
###                       hjust=hjust, vjust=vjust,
###                       gp=gpr)
###  
###  data <- ggplot_build(gg)
###  
###  gt <- ggplot_gtable(data)
###  gt <- gtable_add_rows(gt, grobHeight(subtitle), 2)
###  gt <- gtable_add_grob(gt, subtitle, 3, 4, 3, 4, 8, "off", "subtitle")
###  gt <- gtable_add_rows(gt, grid::unit(bottom_margin, "pt"), 3)
###  
###  if (newpage) grid.newpage()
###  
###  if (is.null(vp)) {
###    grid.draw(gt)
###  } else {
###    if (is.character(vp)) seekViewport(vp) else pushViewport(vp)
###    grid.draw(gt)
###    upViewport()
###  }
###  
###  invisible(data)
###  
###}


################
# 
# MAIN PROGRAM
# 
################


# FONT SELECTION
#if (Sys.info()[['sysname']]=="Darwin") { font_f="TeX Gyre Adventor" } else { font_f="AvantGarde" }
font_f="Helvetica"

# ARGUMENTS
if (length(args)==0) {
    print(paste0("[ ", info, " ] I need arguments"))
    quit("no")
} else {
    mid     <- args[1]
    stage   <- args[2]
    homecol <- args[3]
    awaycol <- args[4]
    csvpath <- args[5]
    season  <- args[6]
}

# LOCAL VARS
pitch <- readPNG("misc/pitch_w_land3.png")
stage_ev <- gsub("-", "", stage)
#print(stage_ev)

# DB REQUEST
###drv <- dbDriver("PostgreSQL")
###conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")
###qtext <- paste0("
###select * 
###from ", stage_ev,".event 
###where
###		matchId=", mid,"
###--  and 	(events @> '{pos}'
###--  or     type like 'Substitution%')
###;")
###query <- dbSendQuery(conn, qtext)
###
###sha <- fetch(query,n=-1)

#if(nrow(sha)==0) {
#    print(paste0(csvpath,"/",stage,"/",season,"/",mid,".csve"))
#    sha <- read.csv(paste0(csvpath,"/",stage,"/",season,"/",mid,".csve"))
#    colnames(sha)[which(names(sha) == "satisfiedEventsTypes")] <- "events"
#    print(head(sha))
#}

filepath <- paste0(csvpath,"/",stage,"/",season,"/",mid,".csve")
sha <- read.csv(filepath)

print(paste0("[ ", info, " ] fetched ", nrow(sha), " lines"))

colnames(sha)[which(names(sha) == "satisfiedEventsTypes")] <- "events"
colnames(sha) <- tolower(colnames(sha))
    

#  TITLE LOOP 
home_team_id <- unique(sha$teamid[sha$field=="home"])
away_team_id <- unique(sha$teamid[sha$field=="away"])

home_team_name <- unique(sha$teamname[sha$field=="home"])
away_team_name <- unique(sha$teamname[sha$field=="away"])

home_data <- sha[sha$teamid==home_team_id,]
away_data <- sha[sha$teamid==away_team_id,]

if(nrow(home_data[grepl("penaltyScored", home_data$events),]) | nrow(away_data[grepl("goalOwn", away_data$events),])) {
	subt_a <- "("
	if(nrow(home_data[grepl("penaltyScored", home_data$events),])) {
	 subt_a <- paste(subt_a, "+", nrow(home_data[grepl("penaltyScored", home_data$events),]), "pen")
	}
	if(nrow(away_data[grepl("goalOwn", away_data$events),])) {
	 subt_a <- paste(subt_a, "+", nrow(away_data[grepl("goalOwn", away_data$events),]), "og")
	}
	subt_a <- paste(subt_a, ")")
	} else {
	subt_a <- paste("")
}

if(nrow(away_data[grepl("penaltyScored", away_data$events),]) | nrow(home_data[grepl("goalOwn", home_data$events),])) {
	subt_b <- "("
	if(nrow(away_data[grepl("penaltyScored", away_data$events),])) {
	 subt_b <- paste(subt_b, "+", nrow(away_data[grepl("penaltyScored", away_data$events),]), "pen")
	}
	if(nrow(home_data[grepl("goalOwn", home_data$events),])) {
	 subt_b <- paste(subt_b, "+", nrow(home_data[grepl("goalOwn", home_data$events),]), "og")
	}
	subt_b <- paste(subt_b, ")")
	} else {
	subt_b <- paste("")
}

title1 <- paste(home_team_name, "-", away_team_name)
title2 <- paste(nrow(home_data[grepl("goalNormal", home_data$events),])+nrow(away_data[grepl("goalOwn", away_data$events),])+nrow(home_data[grepl("penaltyScored", home_data$events),]), "-", nrow(away_data[grepl("goalNormal", away_data$events),])+nrow(home_data[grepl("goalOwn", home_data$events),])+nrow(away_data[grepl("penaltyScored", away_data$events),]))
title3 <- paste("Shots: ", nrow(home_data[grepl("shotsTotal", home_data$events),]), "-" , nrow(away_data[grepl("shotsTotal", away_data$events),]))
title4 <- paste("ExpG: ", round(sum(home_data$expgr[grepl("shotsTotal", home_data$events)]),digits=1), subt_a, "-" , round(sum(away_data$expgr[grepl("shotsTotal", away_data$events)]), digits=1), subt_b)
sum5a <- nrow(home_data[grepl("shotOnTarget", home_data$events),])
sum5b <- nrow(away_data[grepl("shotOnTarget", away_data$events),])
title5 <- paste("On target: ", sum5a, "-", sum5b)

title <- paste(title1, " ", title2)
subtitle <- paste(title4, " ", " ", " ", " ", title3, " ", " ", " ", " ", title5)


# DATA ORGANIZATION
sha$expandedsecond <- 60*sha$expandedminute + sha$second
sha <- sha[order(sha$expandedsecond),]
sha$receiverid <- c(sha$playerid[2:nrow(sha)],0)
sha$receiverid[!grepl("passAccurate", sha$events)] <- 0

sha$diff <- c(diff(sha$teamid),0)
sha$diff <- c(0,sha$diff[-nrow(sha)])
sha$receiverid[sha$diff != 0] <- 0


home_team_id <- unique(sha$teamid[sha$field=="home"])
away_team_id <- unique(sha$teamid[sha$field=="away"])

home_team_name <- unique(sha$teamname[sha$field=="home"])
away_team_name <- unique(sha$teamname[sha$field=="away"])

home_data <- sha[sha$teamid==home_team_id,]
away_data <- sha[sha$teamid==away_team_id,]

home_starting <- unique(home_data$playerid[home_data$position!="Sub"])
away_starting <- unique(away_data$playerid[away_data$position!="Sub"])

home_starting <- home_starting[!is.na(home_starting)]
away_starting <- away_starting[!is.na(away_starting)]

home_minsplayed<-  unique(home_data$playerid[home_data$minsplayed < 31 & home_data$position!='Sub'])
away_minsplayed <- unique(away_data$playerid[away_data$minsplayed < 31 & away_data$position!='Sub'])

home_minsplayed <- home_minsplayed[!is.na(home_minsplayed)]
away_minsplayed <- away_minsplayed[!is.na(away_minsplayed)]

if(length(home_minsplayed)!=0) {
    home_subs <- home_data[home_data$type=='SubstitutionOn',]
    home_subs <- home_subs[order(-home_subs$minsplayed),]
    for (i in 1:length(home_minsplayed)) {
        home_starting <- gsub(home_minsplayed[i], home_subs$playerid[i], home_starting)
    }
}

if(length(away_minsplayed)!=0) {
    away_subs <- away_data[away_data$type=='SubstitutionOn',]
    away_subs <- away_subs[order(-away_subs$minsplayed),]
    for (i in 1:length(away_minsplayed)) {
        away_starting <- gsub(away_minsplayed[i], away_subs$playerid[i], away_starting)
    }
}


home_data <- home_data[home_data$playerid %in% home_starting,]
away_data <- away_data[away_data$playerid %in% away_starting,]

home_avgx <- aggregate(home_data$x, by=list(home_data$playerid), FUN=mean)
names(home_avgx) <- c("playerid","x")
home_avgx <- home_avgx[order(home_avgx$playerid),]

home_avgy <- aggregate(home_data$y, by=list(home_data$playerid), FUN=mean)
names(home_avgy) <- c("playerid","y")
home_avgy <- home_avgy[order(home_avgy$playerid),]

home_avgx <- cbind(home_avgx,home_avgy$y)
names(home_avgx) <- c("playerid","x","y")

away_avgx <- aggregate(away_data$x, by=list(away_data$playerid), FUN=mean)
names(away_avgx) <- c("playerid","x")
away_avgx <- away_avgx[order(away_avgx$playerid),]

away_avgy <- aggregate(away_data$y, by=list(away_data$playerid), FUN=mean)
names(away_avgy) <- c("playerid","y")
away_avgy <- away_avgy[order(away_avgy$playerid),]

away_avgx <- cbind(away_avgx,away_avgy$y)
names(away_avgx) <- c("playerid","x","y")


home_data <- home_data[home_data$receiverid!=0,]
away_data <- away_data[away_data$receiverid!=0,]
home_data <- home_data[home_data$receiverid %in% home_starting,]
away_data <- away_data[away_data$receiverid %in% away_starting,]

home_matrix <- aggregate(home_data$playerid, by=list(home_data$playerid,home_data$receiverid), FUN=length)
names(home_matrix) <- c("playerid","receiverid","count")

away_matrix <- aggregate(away_data$playerid, by=list(away_data$playerid,away_data$receiverid), FUN=length)
names(away_matrix) <- c("playerid","receiverid","count")

home_matrix$x <- 0
home_matrix$y <- 0
home_matrix$endx <- 0
home_matrix$endy <- 0
home_matrix$playername <- 0
home_matrix$numtouch <- 0

away_matrix$x <- 0
away_matrix$y <- 0
away_matrix$endx <- 0
away_matrix$endy <- 0
away_matrix$playername <- 0
away_matrix$numtouch <- 0

for(i in 1:nrow(home_matrix)) { 
    home_matrix$x[i] <- home_avgx$x[home_avgx$playerid==home_matrix$playerid[i]] 
    home_matrix$y[i] <- home_avgx$y[home_avgx$playerid==home_matrix$playerid[i]] 
    home_matrix$endx[i] <- home_avgx$x[home_avgx$playerid==home_matrix$receiverid[i]]
    home_matrix$endy[i] <- home_avgx$y[home_avgx$playerid==home_matrix$receiverid[i]]
    home_matrix$playername[i] <- home_data$playername[home_data$playerid==home_matrix$playerid[i]][1]
    home_matrix$numtouch[i] <- nrow(home_data[home_data$playerid==home_matrix$playerid[i],])
}

for(i in 1:nrow(away_matrix)) { 
    away_matrix$x[i] <- away_avgx$x[away_avgx$playerid==away_matrix$playerid[i]] 
    away_matrix$y[i] <- away_avgx$y[away_avgx$playerid==away_matrix$playerid[i]] 
    away_matrix$endx[i] <- away_avgx$x[away_avgx$playerid==away_matrix$receiverid[i]]
    away_matrix$endy[i] <- away_avgx$y[away_avgx$playerid==away_matrix$receiverid[i]]
    away_matrix$playername[i] <- away_data$playername[away_data$playerid==away_matrix$playerid[i]][1]
    away_matrix$numtouch[i] <- nrow(away_data[away_data$playerid==away_matrix$playerid[i],])
}

#xx <- 12*(1.42-exp(-home_matrix$numtouch/31.4))
xx <- home_matrix$numtouch/3.4
zz <- home_matrix$count/2
zz[zz<=1.5] <- 0.1

cnt <- home_data %>% count(playername)
cnt <- cnt[order(-cnt$n),]
subtitle <- paste("Successful passes: ", nrow(home_data), "-", nrow(away_data), " ", " ", " ", "Most involved: ", cnt$playername[1], "(", cnt$n[1],")")

outpath <- paste("output/",title,"home passmatrix.",mid,".jpeg")
gg <- ggplot(home_matrix,aes(x=-0.5+x/100,y=-0.5+y/100,xend=-0.5+endx/100,yend=-0.5+endy/100)) + theme_bw(base_family = font_f) +
  annotation_raster(pitch, -Inf, Inf, -Inf, Inf) +
  geom_segment(colour="lightgrey", size=zz) +
  geom_point(pch=21, colour="black", size=xx, alpha=0.75, aes(fill=c("homecol"))) +
  geom_text(size=3, family=font_f, aes(label=playername, hjust=0, vjust=2)) +
  ylim(c(-0.47,0.47)) + xlim(c(-0.47,0.47)) +
  guides(fill=FALSE)
 
gg <- gg + theme(axis.title.y=element_blank(),axis.text.y = element_blank(),axis.line=element_blank(),axis.text.x=element_blank(),axis.ticks=element_blank(),axis.title.x=element_blank(),legend.position="none",panel.background=element_rect(fill="white"),panel.border=element_blank(),panel.grid.major=element_blank(),panel.grid.minor=element_blank(),plot.background=element_rect(fill="white"))
gg <- gg + scale_fill_manual(values=c(homecol))

gg <- gg + labs(x=NULL,y=NULL,title=title, subtitle=subtitle)
gg <- gg + theme(plot.title=element_text(hjust=0, face="bold"))

gg <- gg + geom_segment(aes(x=-0.5+mean(home_matrix$x)/100,xend=-0.5+mean(home_matrix$x)/100,y=-0.455,yend=0.47), size=0.3, colour="darkgrey", linetype=2) + geom_text(aes(x=-0.49+mean(home_matrix$x)/100, y=0.43), label=paste(round(mean(home_matrix$x),1),"m"), angle=-90, colour="darkgrey",family=font_f, size=2.5)

ggsave(outpath, plot=gg, width=7, height=4.46)

fn <- "Rplots.pdf"
if (file.exists(fn)) file.remove(fn)

#xx <- 12*(1.42-exp(-away_matrix$numtouch/31.4))
xx <- away_matrix$numtouch/3.4
zz <- away_matrix$count/2
zz[zz<=1.5] <- 0.1

cnt <- away_data %>% count(playername)
cnt <- cnt[order(-cnt$n),]
subtitle <- paste("Successful passes: ", nrow(home_data), "-", nrow(away_data), " ", " ", " ", "Most involved: ", cnt$playername[1], "(", cnt$n[1],")")

gg <- ggplot(away_matrix,aes(x=-0.5+x/100,y=-0.5+y/100,xend=-0.5+endx/100,yend=-0.5+endy/100)) + theme_bw(base_family = font_f) +
  annotation_raster(pitch, -Inf, Inf, -Inf, Inf) +
  geom_segment(colour="lightgrey", size=zz) +
  geom_point(pch=21, colour="black", size=xx, alpha=0.75, aes(fill=c("awaycol"))) +
  geom_text(size=3, family=font_f, aes(label=playername, hjust=0, vjust=2)) +
  ylim(c(-0.47,0.47)) + xlim(c(-0.47,0.47)) +
  guides(fill=FALSE)
 
gg <- gg + theme(axis.title.y=element_blank(),axis.text.y = element_blank(),axis.line=element_blank(),axis.text.x=element_blank(),axis.ticks=element_blank(),axis.title.x=element_blank(),legend.position="none",panel.background=element_rect(fill="white"),panel.border=element_blank(),panel.grid.major=element_blank(),panel.grid.minor=element_blank(),plot.background=element_rect(fill="white"))
gg <- gg + scale_fill_manual(values=c(awaycol))

gg <- gg + labs(x=NULL,y=NULL,title=title, subtitle=subtitle)
gg <- gg + theme(plot.title=element_text(hjust=0, face="bold"))

gg <- gg + geom_segment(aes(x=-0.5+mean(away_matrix$x)/100,xend=-0.5+mean(away_matrix$x)/100,y=-0.455,yend=0.47), size=0.3, colour="darkgrey", linetype=2) + geom_text(aes(x=-0.49+mean(away_matrix$x)/100, y=0.43), label=paste(round(mean(away_matrix$x),1),"m"), angle=-90, colour="darkgrey",family=font_f, size=2.5)

outpath <- paste("output/",title,"away passmatrix.",mid,".jpeg")
#try(ggsave(outpath, plot=ggplot_with_subtitle(gg, subtitle, fontfamily = font_f), width=7, height=4.46), silent=TRUE)
ggsave(outpath, plot=gg, width=7, height=4.46)

fn <- "Rplots.pdf"
if (file.exists(fn)) file.remove(fn)


#dbDisconnect(conn)
print(paste0("[ ", info, " ] End of R script"))

options(warn=oldw)
quit("no")


