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

info <- "match-map"

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

#### DB REQUEST
###drv <- dbDriver("PostgreSQL")
###conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")
###
###qtext <- paste0("
###select * 
###from ", stage_ev,".event 
###where
###		matchId=", mid,"
###  and 	(events @> '{shotsTotal}'
###  or     events @> '{goalOwn}')
###;")
###query <- dbSendQuery(conn, qtext)
###
###sha <- fetch(query,n=-1)

filepath <- paste0(csvpath,"/",stage,"/",season,"/",mid,".csve")
sha <- read.csv(filepath)

print(paste0("[ ", info, " ] fetched ", nrow(sha), " lines"))

colnames(sha)[which(names(sha) == "satisfiedEventsTypes")] <- "events"
colnames(sha) <- tolower(colnames(sha))
shots <- sha[grepl("shotsTotal", sha$events) | grepl("goalOwn", sha$events),]

print(paste0("[ ", info, " ] fetched ", nrow(shots), " shots"))

sha <- shots

#if(nrow(sha)==0) {
#    print(paste0(csvpath,"/",stage,"/",season,"/",mid,".csve"))
#    sha <- read.csv(paste0(csvpath,"/",stage,"/",season,"/",mid,".csve"))
#    colnames(sha)[which(names(sha) == "satisfiedEventsTypes")] <- "events"
#    print(head(sha))
#}
    

# DATA ORGANIZATION
sha$x <- 1 - sha$x/100
sha$y <- 0.5 - sha$y/100
sha$x[sha$x<0.030] <- 0.030

home_team_id <- unique(sha$teamid[sha$field=="home"])
away_team_id <- unique(sha$teamid[sha$field=="away"])

home_team_name <- unique(sha$teamname[sha$field=="home"])
away_team_name <- unique(sha$teamname[sha$field=="away"])

home_data <- sha[sha$teamid==home_team_id,]
away_data <- sha[sha$teamid==away_team_id,]


# TITLE AND SUBTITLE
# PENALTY OR OWN
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

#  REMAINING 
title1 <- paste(home_team_name, "-", away_team_name)
title2 <- paste(nrow(home_data[grepl("goalNormal", home_data$events),])+nrow(away_data[grepl("goalOwn", away_data$events),])+nrow(home_data[grepl("penaltyScored", home_data$events),]), "-", nrow(away_data[grepl("goalNormal", away_data$events),])+nrow(home_data[grepl("goalOwn", home_data$events),])+nrow(away_data[grepl("penaltyScored", away_data$events),]))
title3 <- paste("Shots: ", nrow(home_data[grepl("shotsTotal", home_data$events),]), "-" , nrow(away_data[grepl("shotsTotal", away_data$events),]))
title4 <- paste("ExpG: ", round(sum(home_data$expgr[grepl("shotsTotal", home_data$events)]),digits=1), subt_a, "-" , round(sum(away_data$expgr[grepl("shotsTotal", away_data$events)]), digits=1), subt_b)

home_data <- home_data[!grepl("penaltyScored", home_data$events) | !grepl("penaltyMissed", home_data$events),]
away_data <- away_data[!grepl("penaltyScored", away_data$events) | !grepl("penaltyMissed", away_data$events),]

home_data <- home_data[!grepl("goalOwn", home_data$events),]
away_data <- away_data[!grepl("goalOwn", away_data$events),]


sum5a <- nrow(home_data[grepl("shotOnTarget", home_data$events),])
sum5b <- nrow(away_data[grepl("shotOnTarget", away_data$events),])
title5 <- paste("On target: ", sum5a, "-", sum5b)

title <- paste(title1, " ", title2)
subtitle <- paste(title4, " ", " ", " ", " ", title3, " ", " ", " ", " ", title5)

# NEW SUBT
aaa <- rbind(home_data %>% count(playername,expg), away_data %>% count(playername,expg))
cnt <- aaa %>% group_by(playername) %>% summarise_each(funs(sum))
cnt <- cnt[order(-cnt$expg),]

subtitle <- paste("ExpG: ", round(sum(home_data$expgr[grepl("shotsTotal", home_data$events)]),digits=1), subt_a, "-" , round(sum(away_data$expgr[grepl("shotsTotal", away_data$events)]), digits=1), subt_b, " ", " ", title5, " ", " ","Most involved: ", cnt$playername[1], "(", round(cnt$expg[1], digits=1), "xG)")

# DATA TO BE PLOTTED
home_goals <- grepl("goalNormal", home_data$events)
home_goals <- 1*home_goals
home_goals[home_goals==0] <- "hm"

away_goals <- grepl("goalNormal", away_data$events)
away_goals <- 1*away_goals
away_goals[away_goals==0] <- "am"


xx <- 16*(1.02-exp(-0.75*home_data$expg))
yy <- 16*(1.02-exp(-0.75*away_data$expg))

gg <- ggplot(home_data, aes(x=-0.5+x,y=y)) + theme_classic(base_family = font_f) +
  annotation_raster(pitch, -Inf, Inf, -Inf, Inf) + 
  geom_point(pch=21, colour="black", size=(xx), alpha=0.75, aes(fill=factor(home_goals))) + 
  ylim(c(-0.47,0.47)) + xlim(c(-0.47,0.47)) + 
  guides(fill=FALSE)

#gg <- gg + scale_size(limits=c(0,1))

gg <- gg + theme(axis.title.y=element_blank(),axis.text.y = element_blank(),axis.line=element_blank(),axis.text.x=element_blank(),axis.ticks=element_blank(),axis.title.x=element_blank(),legend.position="none",panel.background=element_rect(fill="white"),panel.border=element_blank(),panel.grid.major=element_blank(),panel.grid.minor=element_blank(),plot.background=element_rect(fill="white"))

if (identical(home_goals[home_goals == 1],character(0)) & identical(away_goals[away_goals == 1],character(0))) {
  gg <- gg + geom_point(data=away_data, aes(x=0.5-x,y=-y, fill=factor(away_goals)), alpha=0.75, pch=21, colour="black", size=(yy)) + 
    scale_fill_manual(values=(c(awaycol, homecol))) 

} else {
  gg <- gg + geom_point(data=away_data, aes(x=0.5-x,y=-y, fill=factor(away_goals)), alpha=0.75, pch=21, colour="black", size=(yy)) + 
    scale_fill_manual(values=(c("lawngreen",awaycol, homecol))) 
  
}
gg <- gg + labs(x=NULL,y=NULL,title=title, subtitle=subtitle)
gg <- gg + theme(plot.title=element_text(hjust=0, face="bold"))


outpath <- paste("output/",title,".",mid,".jpeg")
#try(ggsave(outpath, plot=ggplot_with_subtitle(gg, subtitle, fontfamily = font_f), width=7, height=4.46), silent=TRUE)
ggsave(outpath, plot=gg, width=7, height=4.46)

fn <- "Rplots.pdf"
if (file.exists(fn)) file.remove(fn)

#dbDisconnect(conn)
print("[info]: End of match_map R script")
options(warn=oldw)
quit("no")


