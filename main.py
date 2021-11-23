#!/opt/homebrew/bin/python3
# -*- coding: utf_8 -*-
import sys
### PYTHON 2 ###reload(sys)
### PYTHON 2 ###sys.setdefaultencoding('utf-8')


#######################
#
# LIBRARIES N PACKAGES
#
#######################
from time import sleep
from random import random
from statistics import mean

from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from bs4 import BeautifulSoup

from lxml import html
from datetime import datetime, timedelta, date
import datetime

import requests
import time
import csv
import subprocess
#import psycopg2
import os
import os.path
import platform
#import HTMLParser
import requests
import json, ast
import re

import pandas as pd

from python.scraper import get_tournaments
from python.scraper import get_seasons
from python.scraper import get_match
from python.scraper import get_fixtures
from python.parser  import parse_tournaments
from python.parser  import parse_match
from python.parser  import wait
from python.parser  import calc_expg
from python.viz     import match_map
from python.viz     import put_in_dbx
from python.build   import expg_build

import warnings
warnings.filterwarnings("ignore", category=RuntimeWarning)


#######################
#
# GLOBAL VARS
#
#######################
SITE = 'https://www.whoscored.com'
HEADERS = {'User-Agent': 'Mozilla/5.0'}
max_year=date.today().year if date.today().month < 8 else date.today().year+1


cwd=os.getcwd()
csvpath = cwd+'/csv'
jsonpath = cwd+'/json'
if "Darwin" in platform.system():
    dbxRoot = "/Users/giacobba/Dropbox/My xG Deliveries/" +str(max_year-1)+"-"+str(max_year)
    options = webdriver.ChromeOptions()
    options.add_experimental_option('prefs', {'intl.accept_languages': 'en,en_GB'})
    options.add_argument("--lang=en-GB");
    
    r = webdriver.Chrome(cwd+'/bin/chromedriver_mac',options=options)
    #r = webdriver.Firefox(capabilities=DesiredCapabilities.FIREFOX)
else:
    dbxRoot = "/home/giacobba/Dropbox/My\ xG\ Deliveries/" +str(max_year-1)+"-"+str(max_year)
    r = webdriver.Chrome(cwd+'/bin/chromedriver')


seasonBl=[6135, 7921, 7707, 8154, 8177, 8178, 7848, 7365, 6872, 6850, 8623, 8741]
matchBl=[1365179, 1364968, 1364956, 1365061, 1365141, 1365145, 1365242, 1365268, 1375134, 1439920, 1495439, 1474617, 1474615, 1463184, 1463176, 1463206, 1509039]

superLeagues=["Europe-Champions-League"]
superLeagues=["England-Premier-League", "Germany-Bundesliga", "France-Ligue-1", "Italy-Serie-A", "Spain-LaLiga", "Europe-Champions-League", "Europe-Europa-League"]
superLeagues=["England-Premier-League", "Germany-Bundesliga", "France-Ligue-1", "Italy-Serie-A", "Spain-LaLiga", "Europe-Champions-League"]


#######################
#
# MAIN PROGRAM
#
#######################
if __name__ == "__main__":
    info = "main"


    #######################
    #
    # INPUT ARGUMENTS
    #
    #######################
    if len(sys.argv)==1:
        r.quit()
        print("[", info, "] ")
        print("[", info, "] *** Greetings, Professor Falken...")
        print("[", info, "] ")
        print("[", info, "] Rebuild the whole db:\t\t\t./main.py rebuild")
        print("[", info, "] Refresh single season:\t\t\t./main.py refresh [season]")
        print("[", info, "] Refresh single season with force:\t./main.py refresh [season] force")
        print("[", info, "] Refresh single match:\t\t\t./main.py match [matchId]")
        print("[", info, "] Refresh single match with force:\t./main.py match [matchId] force")
        print("[", info, "] ")
        sys.exit()

    elif len(sys.argv)==2:

        if sys.argv[1] == 'refresh':
            min_year=max_year-1
            tournamentsOv   = False
            seasonsOv       = False
            fixturesOv      = True
            matchOv         = False
            print ("[", info, "] Refreshing", min_year, "in few seconds...")
            if date.today().month == 8:
                    print("[", info, "] Please delete detailed_tournaments.csv and all seasons.csv at the start of a season")
            wait()

        elif sys.argv[1] == 'expg_build':
            print ("[", info, "] Rebuilding expg...")
            #wait()
            r.quit()
            expg_build()
            sys.exit()
                    
        elif sys.argv[1] == 'predictions':
            min_year=max_year-1
            print ("[", info, "] Rebuilding predictions...")
            #wait()
            r.quit()
            os.system("psql ev -v year="+str(min_year)+" -f sql/standardized_results.sql")
            print ("[", info, "] done standardized results")
            os.system("psql ev -c 'drop table if exists _basic_factors;'")
            os.system("psql ev -c 'drop table if exists _parameter_levels;'")
            os.system("psql ev -c 'drop table if exists _factors;'")
            os.system("psql ev -c 'drop table if exists _schedule_factors;'")
            print ("[", info, "] done drop table")
            os.system("Rscript --vanilla R/lmer.R "+str(min_year))
            print ("[", info, "] done Rscript lmer")
            os.system("psql ev -f sql/normalize_factors.sql")
            print ("[", info, "] done normalize factors")
            os.system("psql ev -v year="+str(min_year)+" -f sql/schedule_factors.sql")
            print ("[", info, "] done schedule factors")
            os.system("psql ev -v year="+str(min_year)+" -f sql/current_ranking.sql > output/current_ranking.txt")
            os.system("cp /tmp/current_ranking.csv output/current_ranking.csv")
            print ("[", info, "] done current ranking")
            os.system("\
                    pushd . ;\
                    cd python ;\
                    rm sims2.csv* ;\
                    python sims2.py "+str(min_year)+" ;\
                    rpl ',team,' ',,' sims2.csv ;\
                    rpl ',,' ',' sims2.csv  ;\
                    rpl -q -f '.0' '' sims2.csv ;\
                    tr -d ';\r' < sims2.csv >/tmp/sims.csv ;\
                    cp /tmp/sims.csv ../output/sims.csv ;\
                    popd ;\
            ") 
            os.system("psql ev -f sql/sims2.sql")
            print ("[", info, "] done sims2 py script")
            os.system("psql ev -f sql/sim_table.sql > output/sim_table.txt")
            os.system("cp /tmp/sim_table.csv output/sim_table.csv")
            print ("[", info, "] done sim table")
            os.system("psql ev -f sql/results.sql > output/sim_results.txt")
            os.system("cp /tmp/results.csv output/sim_results.csv")
            print ("[", info, "] done sim results")
            sys.exit()


        elif sys.argv[1] == 'rebuild':
            min_year=2016
            tournamentsOv   = True
            seasonsOv       = True
            fixturesOv      = True
            matchOv         = True
            print ("[", info, "] Rebuilding whole db in few seconds...")
            wait()
            sys.exit()

    elif len(sys.argv)==3:

        if sys.argv[1] == 'refresh':
            min_year=int(sys.argv[2])
            #max_year=min_year+1
            tournamentsOv   = False
            seasonsOv       = False
            fixturesOv      = False
            matchOv         = False
            print ("[", info, "] Refreshing", min_year, "in few seconds...")
            wait()

        if sys.argv[1] == 'match':
            matchId=int(sys.argv[2])
            fixtures=os.popen("grep -l "+str(matchId)+" csv/*/*/fixtures.csv").read().split("\n")[0]
            print ("[",info,"] found",matchId,"in fixtures:",fixtures)
            stage=fixtures.split("/")[1]
            season=fixtures.split("/")[2]
            match=os.popen("grep "+str(matchId)+" csv/*/*/fixtures.csv").read().split("\n")[0]
            homeName=match.split(",")[8]
            awayName=match.split(",")[11]
            gmrv = get_match(r, matchId, "json/"+ stage + "/" + season, False)
            pmrv = parse_match(matchId, "json/" + stage + "/" + season, "csv/" + stage + "/" + season, stage, False)
            if gmrv != -1 and pmrv != -1:
                calc_expg(matchId, "json/" + stage + "/" + season, "csv/" + stage + "/" + season, stage, stage, False)
            if gmrv != -1 and pmrv != -1 and stage in superLeagues:
                match_map(matchId, homeName, awayName, csvpath, season, stage, dbxRoot, True)
            #put_in_dbx(matchId, homeName, awayName, stage, dbxRoot, False)
            r.quit()
            sys.exit()

    elif len(sys.argv)==4:
        if sys.argv[1] == 'refresh' and sys.argv[3] == 'force':
            min_year=int(sys.argv[2])
            tournamentsOv   = False
            seasonsOv       = False
            fixturesOv      = True
            matchOv         = True
            print ("[", info, "] Refreshing", min_year, "with force in few seconds...")
            wait()
            sys.exit()

        if sys.argv[1] == 'match' and sys.argv[3] == 'force':
            matchId=int(sys.argv[2])
            fixtures=os.popen("grep -l "+str(matchId)+" csv/*/*/fixtures.csv").read().split("\n")[0]
            print ("[",info,"] found",matchId,"in fixtures:",fixtures)
            stage=fixtures.split("/")[1]
            season=fixtures.split("/")[2]
            match=os.popen("grep "+str(matchId)+" csv/*/*/fixtures.csv").read().split("\n")[0]
            homeName=match.split(",")[8]
            awayName=match.split(",")[11]
            gmrv = get_match(r, matchId, "json/"+ stage + "/" + season, True)
            pmrv = parse_match(matchId, "json/" + stage + "/" + season, "csv/" + stage + "/" + season, stage, True)
            if gmrv != -1 and pmrv != -1:
                calc_expg(matchId, "json/" + stage + "/" + season, "csv/" + stage + "/" + season, stage, stage, True)
	        #if gmrv != -1 and pmrv != -1 and stage in superLeagues:
            if gmrv != -1 and pmrv != -1 and stage:
                match_map(matchId, homeName, awayName, csvpath, season, stage, dbxRoot, True)
	        #put_in_dbx(matchId, homeName, awayName, stage, dbxRoot, True)
            r.quit()
            sys.exit()

    start_time = datetime.datetime.now() 

    #######################
    #
    # SCRAPING N PARSING
    #
    #######################
    os.system("find . -name '*.json' -size -10 -exec rm {} \;")
    os.system("find . -name '*.csv' -not -name 'seasons.csv' -not -name '*tournaments.csv' -not -name 'fixtures.csv' -size -2 -exec rm {} \;")

    get_tournaments(r, jsonpath, csvpath, tournamentsOv)
    parse_tournaments(jsonpath, csvpath, tournamentsOv)

    get_seasons(r, jsonpath, csvpath, seasonsOv)

    filename = csvpath + "/detailed_tournaments.csv"
    df = pd.read_csv(filename)

for trn in df.tournamentName:
    #for trn in superLeagues:
        filename = csvpath + '/' + trn + '/seasons.csv'
        sn = pd.read_csv(filename)
        for i in range(0,len(sn.index)):
            if sn.iloc[i]['seasonId'] in seasonBl:
                continue
            if sn.iloc[i]['seasonName'] in range(min_year,max_year):
                #print ("[", info, "] getting [", trn, ",", sn.iloc[i]['seasonName'], ",", sn.iloc[i]['seasonId'], "]")
                filename = csvpath + "/" + sn.iloc[i]['tournamentName'] + "/" + str(sn.iloc[i]['seasonName']) + "/fixtures.csv"
		#t = os.path.getmtime(filename)
		#then=datetime.datetime.fromtimestamp(t)
		#now=datetime.datetime.now()
		#delta=now-then
		#if delta.seconds > 43200:
		#    # 12 hrs refresh
		#    get_fixtures(r, jsonpath, csvpath, sn.iloc[i]['seasonId'], sn.iloc[i]['seasonName'], sn.iloc[i]['regionId'], sn.iloc[i]['tournamentId'], sn.iloc[i]['tournamentName'], fixturesOv)
                get_fixtures(r, jsonpath, csvpath, sn.iloc[i]['seasonId'], sn.iloc[i]['seasonName'], sn.iloc[i]['regionId'], sn.iloc[i]['tournamentId'], sn.iloc[i]['tournamentName'], fixturesOv)
                #with open(filename,newline='') as csvfile:
                #    data = list(csv.reader(csvfile))

                #print(data)
                
                ft = pd.read_csv(filename)
                print ("[",info,"] found",len(ft.index),"matches in fixtures:",filename)
                arr = ft.to_numpy()
                for elem in arr:
                    #print(elem)
                    matchId=elem[3]
                    status=elem[5]
                    tournamentName=elem[1]
                    seasonName=elem[2]
                    homeTeamName=elem[8]
                    awayTeamName=elem[11]

                    if matchId in matchBl:
                        continue

                    if 'FT' in status or 'FIN' in status:
                        #print(matchId)
                        #print(status)
                        #print(tournamentName)
                        #print(seasonName)
                        #print(homeTeamName)
                        #print(awayTeamName)
                        gmrv = get_match(r, matchId, jsonpath + "/" + tournamentName + "/" + str(seasonName), matchOv)
                        pmrv = parse_match(matchId, jsonpath + "/" + tournamentName + "/" + str(seasonName), csvpath + "/" + tournamentName + "/" + str(seasonName), tournamentName, matchOv)
                        if gmrv != -1 and pmrv != -1:
                            try:
                                calc_expg(matchId, jsonpath + "/" + tournamentName + "/" + str(seasonName), csvpath + "/" + tournamentName + "/" + str(seasonName), tournamentName, superLeagues, matchOv)
                            except:
                                continue
                        if gmrv != -1 and pmrv != -1 and tournamentName in superLeagues:
                            try:
                                match_map(matchId, homeTeamName, awayTeamName, csvpath, str(seasonName), tournamentName, dbxRoot, matchOv)
                            except:
                                continue
			#put_in_dbx(ft.iloc[j]['matchId'], ft.iloc[j]['homeTeamName'], ft.iloc[j]['awayTeamName'], sn.iloc[i]['tournamentName'], dbxRoot, matchOv)

##                for j in range(0,len(ft.index)):
##                    print(j)
##                    #print(ft.iloc[j])
##                    if ft.iloc[j]['matchId'] in matchBl:
##                        continue
##                    if 'FT' in str(ft.iloc[j]['status']) or 'AET' in str(ft.iloc[j]['status']) or 'PEN' in str(ft.iloc[j]['status']):
##                        print("$$$ GOT FT $$$")
##                        gmrv = get_match(r, ft.iloc[j]['matchId'], jsonpath + "/" + sn.iloc[i]['tournamentName'] + "/" + str(sn.iloc[i]['seasonName']), matchOv)
##                        pmrv = parse_match(ft.iloc[j]['matchId'], jsonpath + "/" + sn.iloc[i]['tournamentName'] + "/" + str(sn.iloc[i]['seasonName']), csvpath + "/" + sn.iloc[i]['tournamentName'] + "/" + str(sn.iloc[i]['seasonName']), sn.iloc[i]['tournamentName'], matchOv)
##                        if gmrv != -1 and pmrv != -1:
##                            try:
##                                calc_expg(ft.iloc[j]['matchId'], jsonpath + "/" + sn.iloc[i]['tournamentName'] + "/" + str(sn.iloc[i]['seasonName']), csvpath + "/" + sn.iloc[i]['tournamentName'] + "/" + str(sn.iloc[i]['seasonName']), sn.iloc[i]['tournamentName'], superLeagues, matchOv)
##                            except:
##                                pass
##                        if gmrv != -1 and pmrv != -1 and sn.iloc[i]['tournamentName'] in superLeagues:
##                            try:
##                                match_map(ft.iloc[j]['matchId'], ft.iloc[j]['homeTeamName'], ft.iloc[j]['awayTeamName'], csvpath, str(sn.iloc[i]['seasonName']), sn.iloc[i]['tournamentName'], dbxRoot, matchOv)
##                            except:
##                                pass
##			#put_in_dbx(ft.iloc[j]['matchId'], ft.iloc[j]['homeTeamName'], ft.iloc[j]['awayTeamName'], sn.iloc[i]['tournamentName'], dbxRoot, matchOv)

r.quit()


#######################
#
# LOADING INTO DB
#
#######################
os.system("bash/loader.sh")


time_elapsed = datetime.datetime.now() - start_time
print ("[",info,"] time elapsed (h:m:s):", str(time_elapsed).split('.')[0])
sys.exit()



