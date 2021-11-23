#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
#sink("logs/xg-equation-finder.log")
suppressMessages(library("plyr"))
#library("dplyr")
suppressMessages(library("tidyr"))
#library("RPostgreSQL")
suppressMessages(library(png))
suppressMessages(library(ggplot2))
suppressMessages(library(pracma))
#library("ggplot2")
#library("jpeg")
suppressMessages(library("grid"))
#library("extrafont")
suppressMessages(library(gtable))

#font_import()
if (Sys.info()[['sysname']]=="Darwin") { font_f="TeX Gyre Adventor" } else { font_f="AvantGarde" }

print("[heat]: Starting heatmap R script")
#print(paste0("homecol=",homecol," awaycol=",awaycol))

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


if(strcmp(getwd(),"/Users/giacobba")) { 
	setwd("git/my-analytics/sz-rev")
}

pitch <- readPNG("misc/pitch_w_land5.png")

#################
#
# MAIN
#
#################

if (length(args)==0) {
    #stop("Need color params", call.=FALSE)
    tname     <- "Juventus"
} else {
    tname     <- args[1]
}

preevents <- read.csv("/tmp/left.csv")
prematches <- length(levels(as.factor((preevents$matchid))))
preevents <- round(preevents[,38:39],0)
preplus <- count(round(preevents/10,0)*10,vars=c("x","y"))

postevents <- read.csv("/tmp/right.csv")
postmatches <- length(levels(as.factor((postevents$matchid))))
postevents <- round(postevents[,38:39],0)
postplus <- count(round(postevents/10,0)*10,vars=c("x","y"))

preplus <- preplus[preplus$x>50,]
postplus <- postplus[preplus$x>50,]

#preplus$x <- preplus$x - 105
#preplus$y <- preplus$y - 50
preplus$freq <- 100*preplus$freq/prematches
#postplus$x <- postplus$x - 52
#postplus$y <- postplus$y - 50
postplus$freq <- 100*postplus$freq/postmatches
#
plus <- rbind(preplus,postplus)

title <- paste0(tname,": da dove partono i passaggi chiave")
subtitle <- "Zone di alta (verde) o bassa (blu) frequenza dei passaggi chiave"
#subtitle <- paste0(subtitle,"\nSinistra: ",tsx,"%   Centro: ",tcx,"%   Destra: ",tdx,"%")

gg <- ggplot(data=preplus, mapping=aes(x=-x+100-45,y=54*(-y+50)/50)) + theme_classic(base_family = font_f) +
  annotation_raster(pitch, -52, 54, -54, 52) + 
  ylim(c(-50,50)) + xlim(c(-50,52)) + 
  guides(fill=FALSE)

gg <- gg + theme(axis.title.y=element_blank(),axis.text.y = element_blank(),axis.line=element_blank(),axis.text.x=element_blank(),axis.ticks=element_blank(),axis.title.x=element_blank(),legend.position="none",panel.background=element_rect(fill="white"),panel.border=element_blank(),panel.grid.major=element_blank(),panel.grid.minor=element_blank(),plot.background=element_rect(fill="white"))

gg <- gg + geom_tile(color="white", size=0.25, aes(fill=freq,alpha=0.5)) + scale_fill_gradient(low="#6677AE",high="#00FF00")
gg <- gg + geom_tile(data=postplus, color="white", size=0.25, mapping=aes(x=-x+100+7,y=54*(-y+50)/50, fill=freq, alpha=0.5))
#gg <- gg + geom_tile(data=postplus, color="white", size=0.25, aes(fill=freq,alpha=0.5)) + scale_fill_gradient(low="#6677AE",high="#00FF00")

gg <- gg + labs(x=NULL,y=NULL,title=title)
gg <- gg + theme(plot.title=element_text(hjust=0, face="bold"))


outpath <- paste("output/",title,".png")
try(ggsave(outpath, plot=ggplot_with_subtitle(gg, subtitle, fontfamily = font_f), width=7, height=4.46),silent=TRUE)

fn <- "Rplots.pdf"
if (file.exists(fn)) file.remove(fn)

#dbDisconnect(conn)
print("[heat]: End of heatmap R script")
#quit("no")
