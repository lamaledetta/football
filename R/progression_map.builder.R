#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#sink("logs/xg-equation-finder.log")
suppressMessages(library("dplyr"))
suppressMessages(library("tidyr"))
suppressMessages(library("RPostgreSQL"))
suppressMessages(library(png))
suppressMessages(library(ggplot2))
suppressMessages(library(pracma))
suppressMessages(library("grid"))
suppressMessages(library(gtable))
suppressMessages(library(ggrepel))
#library("extrafont"))
#library("ggplot2"))
#library("jpeg"))

info <- "progress-map"

print(paste0("[ ", info, " ] starting R script"))

# PROCEDURES
ggplot_with_subtitle <- function(gg, 
                                 label="", 
                                 fontfamily=NULL,
                                 fontsize=10,
                                 hjust=0, vjust=0, 
                                 bottom_margin=5.5,
                                 newpage=is.null(vp),
                                 vp=NULL,
                                 ...) {
  
  if (is.null(fontfamily)) {
    gpr <- gpar(fontsize=fontsize, ...)
  } else {
    gpr <- gpar(fontfamily=fontfamily, fontsize=fontsize, ...)
  }
  
  subtitle <- textGrob(label, x=unit(hjust, "npc"), y=unit(hjust, "npc"), 
                       hjust=hjust, vjust=vjust,
                       gp=gpr)
  
  data <- ggplot_build(gg)
  
  gt <- ggplot_gtable(data)
  gt <- gtable_add_rows(gt, grobHeight(subtitle), 2)
  gt <- gtable_add_grob(gt, subtitle, 3, 4, 3, 4, 8, "off", "subtitle")
  gt <- gtable_add_rows(gt, grid::unit(bottom_margin, "pt"), 3)
  
  if (newpage) grid.newpage()
  
  if (is.null(vp)) {
    grid.draw(gt)
  } else {
    if (is.character(vp)) seekViewport(vp) else pushViewport(vp)
    grid.draw(gt)
    upViewport()
  }
  
  invisible(data)
  
}


################
# 
# MAIN PROGRAM
# 
################


#font_import())
if (Sys.info())[['sysname']]=="Darwin")) { font_f="TeX Gyre Adventor" } else { font_f="AvantGarde" }

# ARGUMENTS
if (length(args)==0) {
    print("I need arguments...")
	quit("no")
} else {
    mid     <- args[1]
    stage   <- args[2]
    homecol <- args[3]
    awaycol <- args[4]
}

# LOCAL VARS
pitch <- readPNG("misc/pitch_w_land3.png")


# DB REQUEST
drv <- dbDriver("PostgreSQL")
conn <- dbConnect(drv,host="localhost",port="5432",dbname="ev")
qtext <- paste0("
select * 
from ", stage,".event 
where
		matchId=", mid,"
  and 	events @> '{shotsTotal}'
;")
query <- dbSendQuery(conn, qtext)

sha <- fetch(query,n=-1)

print(paste0("[ ", info, " ] fetched ", nrow(sha), " lines"))

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
title2 <- paste(nrow(home_data[grepl("goalNormal", home_data$events),])+nrow(away_data[grepl("goalOwn", away_data$events),])+nrow(away_data[grepl("penaltyScored", home_data$events),]), "-", nrow(away_data[grepl("goalNormal", away_data$events),])+nrow(home_data[grepl("goalOwn", home_data$events),])+nrow(away_data[grepl("penaltyScored", away_data$events),]))
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

home_team_id <- unique(sha$teamId[sha$field=="home"])
away_team_id <- unique(sha$teamId[sha$field=="away"])
home_team_name <- unique(sha$teamName[sha$field=="home"])
away_team_name <- unique(sha$teamName[sha$field=="away"])

home_data <- sha[sha$teamId[sha$field=="home"],]
away_data <- sha[sha$teamId[sha$field=="away"],]

home_data$cumsum <- cumsum(home_data$expgr)
away_data$cumsum <- cumsum(away_data$expgr)

home_data$teamName[grepl("goalOwn", home_data$events)] <- away_team_name
home_data$teamId[grepl("goalOwn", home_data$events)] <- away_team_id
away_data$teamName[grepl("goalOwn", away_data$events)] <- home_team_name
away_data$teamId[grepl("goalOwn", away_data$events)] <- home_team_id

data <- rbind(home_data,away_data)




# data$outcome[data$from_penalty==1 & data$outcome=="Goal"] <- 'Goal'
# data$player_name[data$from_penalty==1 & data$outcome=="Goal"] <- paste(data$player_name[data$from_penalty==1],"(pen)")

# data$player_name[data$outcome=='OwnGoal'] <- paste(data$player_name[data$outcome=='OwnGoal'],"(og)")
# data$outcome[data$outcome=='OwnGoal'] <- 'Goal'

# data$goalsize[data$outcome=='Goal'] <- 2
# data$goalsize[data$outcome!='Goal'] <- NA

# data$minute <- data$minute + 1
# data$minute <- paste(data$minute,"'",sep="")
# data$player_name <- paste(data$minute, data$player_name)
# data$player_name[data$outcome!='Goal'] <- NA
# data$minute[data$outcome!='Goal'] <- NA










gg <- ggplot(data=data, aes(x=expanded_minute,y=cumsum, group=factor(field))) + geom_step(aes(col=factor(field)),size=.75)
gg <- gg + theme_classic(base_family = font_f) + guides(fill=FALSE)
gg <- gg + scale_color_manual(values=(c(awaycol,homecol)))
#gg <- gg + theme(axis.title.y=element_blank(),axis.text.y = element_blank(),axis.line=element_blank(),axis.text.x=element_blank(),axis.ticks=element_blank(),axis.title.x=element_blank(),legend.position="none",panel.background=element_rect(fill="white"),panel.border=element_blank(),panel.grid.major=element_blank(),panel.grid.minor=element_blank(),plot.background=element_rect(fill="white"))
gg <- gg + theme(panel.border=element_rect(colour="black", fill=NA, size=.1),
                 axis.title.y=element_blank(),axis.line=element_blank(),axis.ticks.y=element_blank(),
                 legend.position="none",
                 panel.background=element_rect(fill="grey90"),panel.grid.major=element_blank(),
                 panel.grid.minor=element_blank(),plot.background=element_rect(fill="white"))
gg <- gg + labs(x=NULL,y=NULL,title=title)
gg <- gg + theme(plot.title=element_text(hjust=0, face="bold"))
gg <- gg + scale_x_continuous(breaks=seq(0,max(data$expanded_minute),45),limits=c(0,max(data$expanded_minute)))

gg <- gg + geom_point(pch=25,size=data$goalsize,aes(fill=factor(data$field)))
gg <- gg + scale_fill_manual(values=c(awaycol,homecol))

gg <- gg + geom_text_repel(size=2.5, family=font_f, aes(label=data$player_name, hjust=-.75, angle=90))



outpath <- paste("output/",title,"progression.png")
try(ggsave(outpath, plot=ggplot_with_subtitle(gg, subtitle, fontfamily = font_f), width=7, height=4.46),silent=TRUE)

fn <- "Rplots.pdf"
if (file.exists(fn)) file.remove(fn)

dbDisconnect(conn)
#print(paste0("[ ", info, " ] End of script"))
quit("no")