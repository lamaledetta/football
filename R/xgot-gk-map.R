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
suppressMessages(library("grid"))
suppressMessages(library("gtable"))

#library("smbinning")

closeAllConnections()

##################################
##
##          MAIN PROGRAM
##
##################################

#font_import()
print("[info]: Starting xgot_gk_map R script")
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


if (Sys.info()[['sysname']]=="Darwin") { font_f="TeX Gyre Adventor" } else { font_f="AvantGarde" }
pitch <- readPNG("misc/pitch_gk.png")

# INPUT ARGUMENTS
if (length(args)==0) {
    sid <- "italyseriea"
    season <- "2018"
    pname <- "Alex Meret"
    tname <- "Napoli 2018-19"
    homecol <- "deepskyblue"
    print(paste0("default stage_id=", sid))
    print(paste0("default keeper=", pname))
    print(paste0("default team=", tname))
    print(paste0("default color=", homecol))
} else {
    sid <- args[1]
    season <- args[2]
    pname <- args[3]
    tname <- args[4]
    homecol <- args[5]
    print(paste0("selected stage_id=", sid))
    print(paste0("selected keeper=", pname))
    print(paste0("selected team=", tname))
    print(paste0("selected homecol=", homecol))
}

print("[info]: Started xg-gk-map R script")

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

qtext <- paste0("
select playername, matchid, teamid, round(avg(minsplayed),0) as minute
from ", sid, ".event 
where
  position='GK'
and season=", season, " 
and playername like '%", pname, "%'
group by
  playername, matchid, teamid
;")
query <- dbSendQuery(conn, qtext)
lineup <- fetch(query,n=-1)

lineup$subbed_in <- 0
lineup$subbed_out <- 999

data <- shots[FALSE,]
data$playername <- character(0)

for (i in 1:nrow(shots)) {
    #print(i)
    dummy <- shots[i,]
    dummy$playername <- ifelse(identical(lineup$playername[which(lineup$subbed_out>=shots$minute[i] & lineup$teamid==shots$opponentid[i] & lineup$matchid == shots$matchid[i])],character(0)), 'Unknown player', lineup$playername[which(lineup$subbed_out>=shots$minute[i] & lineup$teamid==shots$opponentid[i] & lineup$matchid == shots$matchid[i])])
###    dummy$player_name <- ifelse(identical(lineup$name[which(lineup$minute>=shots$minute[i] & lineup$team_id==shots$opponent_id[i] & lineup$match_id == shots$match_id[i])],character(0)), 'Unknown player', lineup$name[which(lineup$minute>=shots$minute[i] & lineup$team_id==shots$opponent_id[i] & lineup$match_id == shots$match_id[i])])
    data <- rbind(data,dummy)
}

#output <- calc_xg(shots)
	#outcome, expg, goal_y, goal_z
	data$type[data$type!="Goal"] <- 0
	data$type[data$type=="Goal"] <- 1
	data$type <- as.numeric(data$type)
	
    # Create Training Data
	situation <- "xgot"
        modelfile <- paste0("R/glm_", situation, ".rds") 
        model <- readRDS(modelfile)
        data$xgot <- predict(model, data, type="response")
        data <- data[data$playername != "Unknown player",]

        df <- data.frame(data$playername, data$expg, data$xgot, data$type)
        
        names(df) <- c("playername","expg","xgot","goals")
        df <- df %>% group_by(playername) %>% summarise_all(funs(sum))

        df$delta <- df$xgot - df$goals
        output <- data.frame(df$playername, df$expg, df$goals, df$xgot, df$delta)
        #output <- output[output$df.playername != "Unknown player",]

        print(output[order(-output$df.delta),])



title <- paste(pname, " ", "(", tname, ")")
#title <- pname
subtitle <- paste("On target: ",nrow(data), " ", " ", " ", " ", "Conceded: ",sum(data$type), " ", " ", " ", " ", "Expected: ", round(sum(data$xgot),1))

xx <- 36*data$xgot

gg <- ggplot(data, aes(x=-data$goalmouthy, y=data$goalmouthz)) + geom_point(pch=21, colour="black", size=xx, alpha=0.75, aes(fill=factor(data$type))) +
    theme_classic(base_family = font_f) + annotation_raster(pitch, -Inf, Inf, -Inf, Inf) +
    guides(fill=FALSE) + ylim(c(0,38)) + xlim(c(-54.8,-45.2)) + theme_classic(base_family = font_f) 

gg <- gg + theme(axis.title.y=element_blank(),axis.text.y = element_blank(),axis.line=element_blank(),axis.text.x=element_blank(),axis.ticks=element_blank(),axis.title.x=element_blank(),legend.position="none",panel.background=element_rect(fill="white"),panel.border=element_blank(),panel.grid.major=element_blank(),panel.grid.minor=element_blank(),plot.background=element_rect(fill="white"))
gg <- gg + labs(x=NULL,y=NULL,title=title)
gg <- gg + theme(plot.title=element_text(hjust=0, face="bold"))
gg <- gg + scale_fill_manual(values=(c(homecol,"lawngreen")))

outpath <- paste("output/",title,".png")
try(ggsave(outpath, plot=ggplot_with_subtitle(gg, subtitle, fontfamily = font_f), width=7, height=4.46),silent=TRUE)

fn <- "Rplots.pdf"
if (file.exists(fn)) file.remove(fn)

csvfile <- paste0("/tmp/xgot_stage_id_", sid, ".csv")
write.csv(output, csvfile, row.names=FALSE)

dbDisconnect(conn)
quit("no")

