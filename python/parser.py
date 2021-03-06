# -*- coding: utf_8 -*-
import sys
### PYTHON2 ##reload(sys)
### PYTHON2 ##sys.setdefaultencoding('utf-8')

from time import sleep
from random import random
from statistics import mean

#from selenium import webdriver
#from selenium.common.exceptions import TimeoutException
#from selenium.webdriver.common.by import By
#from selenium.webdriver.common.keys import Keys
#from selenium.webdriver.support.ui import WebDriverWait
#from selenium.webdriver.support import expected_conditions as EC
#from bs4 import BeautifulSoup

#from lxml import html
from datetime import datetime, timedelta, date

import requests
import time
import csv
import subprocess
###import psycopg2
import os
import os.path
import platform
#import HTMLParser
import requests
import json, ast
import re
import unidecode

import pandas as pd

Rscript="/Library/Frameworks/R.framework/Resources/Rscript"

#SITE = 'https://www.whoscored.com'
#HEADERS = {'User-Agent': 'Mozilla/5.0'}
#
#cwd=os.getcwd()
#
#if "Darwin" in platform.system():
#    r = webdriver.Chrome(cwd+'/../bin/chromedriver_mac')
#else:
#    r = webdriver.Chrome(cwd+'/../bin/chromedriver')
    
###################################
#
# function WAIT
#
###################################
def wait(delay=2, variation=1):
    m, x, c = variation, random(), delay - variation / 2
    sleep(m * x + c)

###################################
#
# function PARSE_TOURNAMENTS
#
###################################
def parse_tournaments(jsonpath, csvpath, overwrite=False):
    info="parse_tournaments"
    filename = csvpath + '/all_tournaments' + ".csv"

    if os.path.exists(filename) and overwrite==False:
        #print ("[",info,"] file", filename, "exists, exiting..."
        return False

    print ("[",info,"] getting tournaments .json")

    filename = jsonpath + "/all_tournaments.json"
    with open(filename, 'r') as f:
        tournamentsData = json.load(f)

    filename = csvpath + '/all_tournaments' + ".csv"
    f = csv.writer(open(filename, "wb+"))

    f.writerow(["id", "name", "tournamentId", "tournamentUrl", "tournamentName"])

    for x in tournamentsData:
        for y in x['tournaments']:
            f.writerow([
                x['id'],
                x['name'],
                y['id'],
                y['url'],
                y['name']
                ])
    
    print ("[",info,"] all tournaments in .csv")


###################################
#
# function PARSE_MATCH
#
###################################
def parse_match(match_id, jsonpath, csvpath, tournamentName, overwrite=False):
    info="parse_match"
    filename = csvpath + '/' + str(match_id) + ".csv"
    filename_e = csvpath + '/' + str(match_id) + ".csve"

    today = date.today()
    log = open("log/"+info+"."+today.strftime("%Y%m%d")+".log","a") 

    if not os.path.exists(csvpath):
        os.makedirs(csvpath, 0o755)
        print ("[",info,"] dir", csvpath, "created")

    if os.path.exists(filename_e) and overwrite==False:
        #print ("[",info,"] file", filename, "exists, exiting...")
        return False

    print ("[",info,"] fetching match id:", match_id)
    #print ("[",info,"] overwrite:", overwrite)

    filename = jsonpath + '/' + str(match_id) + ".json"
    if os.path.isfile(filename):
        print ("[",info,"] loading match file:",filename)
        with open(filename, 'r') as f:
            matchData = json.load(f)
    else:
        print("[error] no file:", filename)
        return False

    filename = jsonpath + "/eventdict.json"
    if os.path.isfile(filename):
        print ("[",info,"] loading eventdict file=",filename)
        with open(filename, 'r') as f:
            matchEvent = json.load(f)
    else:
        print("[error] no file:", filename)
        return False

    matchData = json.loads(matchData[0], strict=False)
    #print json.dumps(matchData, indent=6)

    matchEventDict = json.loads(matchEvent[0], strict=False)
    matchEventDict = dict((k,v) for k,v in matchEventDict.items())
    matchEventDictReverse = dict((v,k) for k,v in matchEventDict.items())

    print ("[",info,"] file loaded successfully")

    season = csvpath.split("/")[-1]

    filename = csvpath + '/' + str(match_id) + ".csv"
    f = csv.writer(open(filename, "wt+"))

    f.writerow(["matchId", "startTime", "stageName", "season", "status", "htScore", "etScore", "pkScore", "ftScore",
                "teamId", "teamName", "managerName", "refereeName", "field", "formation", "matchPossession", "avgPossession", "opponentId", "opponentName",
                "id", "eventId", "playerId", "playerName", "age", "height", "weight", "position", "isFirstEleven", "minsPlayed", "rating",
                "relatedPlayerId", "relatedEventId", "OppositeRelatedEvent", "expandedMinute", "period", "minute", "second",
                "x", "y", "endX", "endY", "goalMouthZ", "goalMouthY", "blockedX", "blockedY", "isTouch", "type", "outcomeType", "satisfiedEventsTypes"])

    try:
        x = json.loads(json.dumps(matchData['events']))
    except TypeError:
        print("[error] no matchData")
        log.write("[error] no matchData matchId: "+str(match_id)+"\n")
        log.close()
        return -1

    # PARSING PLAYERS
    ph = json.loads(json.dumps(matchData['home']['players']))
    pa = json.loads(json.dumps(matchData['away']['players']))

    players = {}
    players[0] = {}
    players[0]['name'] = 'Unknown Player'
    players[0]['age'] = 0
    players[0]['height'] = 0
    players[0]['weight'] = 0
    players[0]['position'] = 'None'
    players[0]['isFirstEleven'] = False
    players[0]['minsPlayed'] = 0
    players[0]['rating'] = 0

    for p in ph:
        players[p['playerId']]={}
        players[p['playerId']]['name']=unidecode.unidecode(p['name'])
        players[p['playerId']]['age']=p['age']
        players[p['playerId']]['height']=p['height']
        players[p['playerId']]['weight']=p['weight']
        players[p['playerId']]['position']=p['position']
        try:
            players[p['playerId']]['rating']=round(mean(p['stats']['ratings'].values()),2)
        except:
            players[p['playerId']]['rating']=0

        try:
            players[p['playerId']]['isFirstEleven']=bool(p['isFirstEleven'])
        except KeyError:
            players[p['playerId']]['isFirstEleven']=False

        try:
            psout = p['subbedOutExpandedMinute']

        except:
            psout = 0

        try:
            psin = p['subbedInExpandedMinute']

        except:
            psin = 0

        players[p['playerId']]['minsPlayed'] = 90 if players[p['playerId']]['isFirstEleven'] and (psout==0 or psout >= 90) else \
                                               psout if players[p['playerId']]['isFirstEleven'] and psout < 90 else \
                                               matchData['minuteExpanded'] - psin if psout==0 and psin > 0 else \
                                               psout - psin 


    for p in pa:
        players[p['playerId']]={}
        players[p['playerId']]['name']=unidecode.unidecode(p['name'])
        players[p['playerId']]['age']=p['age']
        players[p['playerId']]['height']=p['height']
        players[p['playerId']]['weight']=p['weight']
        players[p['playerId']]['position']=p['position']
        try:
            players[p['playerId']]['rating']=round(mean(p['stats']['ratings'].values()),2)
        except:
            players[p['playerId']]['rating']=0

        try:
            players[p['playerId']]['isFirstEleven']=bool(p['isFirstEleven'])
        except KeyError:
            players[p['playerId']]['isFirstEleven']=False

        try:
            psout = p['subbedOutExpandedMinute']

        except:
            psout = 0

        try:
            psin = p['subbedInExpandedMinute']

        except:
            psin = 0

        players[p['playerId']]['minsPlayed'] = 90 if players[p['playerId']]['isFirstEleven'] and (psout==0 or psout >= 90) else \
                                               psout if players[p['playerId']]['isFirstEleven'] and psout < 90 else \
                                               matchData['expandedMaxMinute'] - psin if psout==0 and psin > 0 else \
                                               psout - psin 


    # PARSING FORMATIONS
    fh = json.loads(json.dumps(matchData['expandedMinutes']))
    mh = {}
    ma = {}
    for k,v in fh.items():
        for z,y in v.items():
            mh[y]=0 
            ma[y]=0 

    fh = json.loads(json.dumps(matchData['home']['formations']))
    for v in fh:
        start = v['startMinuteExpanded']
        end = v['endMinuteExpanded']
        name = v['formationName']

        for i in range(start,end):
            mh[i] = name

    for k,v in mh.items():
        if v==0:
            mh[k]=name


    fh = json.loads(json.dumps(matchData['away']['formations']))
    for v in fh:
        start = v['startMinuteExpanded']
        end = v['endMinuteExpanded']
        name = v['formationName']

        for i in range(start,end):
            ma[i] = name


    try:
        fh = json.loads(json.dumps(matchData['home']['stats']['possession']))
        fa = json.loads(json.dumps(matchData['away']['stats']['possession']))
        poss_h=round(100.0*sum(fh.values())/(sum(fh.values())+sum(fa.values())),1)
        poss_a=100-poss_h
    except:
        poss_h=50.0
        poss_a=50.0

    ph = {}
    pa = {}
    for k in mh:
        try:
            ph[k]=fh[str(k)]
        except:
            ph[k]=0.0

    for k in ma:
        try:
            pa[k]=fa[str(k)]
        except:
            pa[k]=0.0

    vh = pd.DataFrame.from_dict(ph, orient='index')
    va = pd.DataFrame.from_dict(pa, orient='index')

    vh.columns = ['poss']
    va.columns = ['poss']

    vh.index = vh.index.astype(int)
    va.index = va.index.astype(int)

    vh=vh.sort_index()
    va=va.sort_index()

    rmh = vh.poss.rolling(window=5).mean()
    rma = va.poss.rolling(window=5).mean()

    try:
        meanh = mean(fh.values())
        meana = mean(fa.values())
    except:
        meanh = 1.0
        meana = 1.0

    rmh = rmh.fillna(meanh)
    rma = rma.fillna(meana)

    pph = rmh/(rmh+rma)
    ppa = rma/(rmh+rma)

    # PARSING EVENTS
    for x in x:
        try:
            if 'PenaltyShootout' in x['period']['displayName']:
                x['expandedMinute'] = max(max(mh.keys()),max(ma.keys()))
            if x['satisfiedEventsTypes']:

                for y in range(0, len(x['satisfiedEventsTypes'])):
                    x['satisfiedEventsTypes'][y] = matchEventDictReverse[int(x['satisfiedEventsTypes'][y])]
                    
                if 'offsideGiven' in x['satisfiedEventsTypes']:
                    continue

                f.writerow([
                    match_id,
                    matchData.get('startTime'),
                    unidecode.unidecode(tournamentName),
	            season,
                    matchData.get('elapsed'),
                    matchData.get('htScore'),
                    matchData.get('etScore'),
                    matchData.get('pkScore'),
                    matchData.get('ftScore'),
                    x.get('teamId'),
                    unidecode.unidecode(matchData.get('home').get('name')) if x.get('teamId') == matchData.get('home').get('teamId') else unidecode.unidecode(matchData.get('away').get('name')),
                    unidecode.unidecode(matchData.get('home').get('managerName')) if x.get('teamId') == matchData.get('home').get('teamId') else unidecode.unidecode(matchData.get('away').get('managerName')),
                    unidecode.unidecode(matchData.get('referee', {}).get('name', 'None')),
                    'home' if x.get('teamId') == matchData.get('home').get('teamId') else 'away',
                    mh.get(x.get('expandedMinute',0)) if x.get('teamId') == matchData.get('home').get('teamId') else ma.get(x.get('expandedMinute',0)),
                    poss_h if x.get('teamId') == matchData.get('home').get('teamId') else poss_a,
                    round(100*pph[x.get('expandedMinute',0)],1) if x.get('teamId') == matchData.get('home').get('teamId') else round(100*ppa[x.get('expandedMinute',0)],1),
                    matchData.get('home').get('teamId') if x.get('teamId') == matchData.get('away').get('teamId') else matchData.get('away').get('teamId'),
                    unidecode.unidecode(matchData.get('home').get('name')) if x.get('teamId') == matchData.get('away').get('teamId') else unidecode.unidecode(matchData.get('away').get('name')),
                    x.get('id'),
                    x.get('eventId'),
                    x.get('playerId'),
                    players[x.get('playerId',0)].get('name') if x.get('playerId') != 'None' else 'Unknown Player',
                    players[x.get('playerId',0)].get('age') if x.get('playerId') != 'None' else 0,
                    players[x.get('playerId',0)].get('height') if x.get('playerId') != 'None' else 0,
                    players[x.get('playerId',0)].get('weight') if x.get('playerId') != 'None' else 0,
                    players[x.get('playerId',0)].get('position') if x.get('playerId') != 'None' else 'None',
                    players[x.get('playerId',0)].get('isFirstEleven') if x.get('playerId') != 'None' else False,
                    players[x.get('playerId',0)].get('minsPlayed') if x.get('playerId') != 'None' else 0,
                    players[x.get('playerId',0)].get('rating') if x.get('playerId') != 'None' else 0,
                    x.get('relatedPlayerId'),
	            x.get('relatedEventId'),
	            x.get('OppositeRelatedEvent'),
                    x.get("expandedMinute",0),
                    x.get('period',{}).get('value',0),
                    x.get('minute'),
                    x.get("second"),
                    x.get("x"),
                    x.get("y"),
                    x.get("endX"),
                    x.get("endY"),
                    x.get("goalMouthZ"),
                    x.get("goalMouthY"),
                    x.get("blockedX"),
                    x.get("blockedY"),
                    x.get('isTouch'),
                    x.get("type").get("displayName"),
                    x.get('outcomeType').get('displayName'),
                    x.get('satisfiedEventsTypes')
                    ])

        except KeyError:
            log.write("matchId: "+str(match_id)+"\n")
            log.write("x: "+str(x)+"\n")
            log.write("[error] "+str(sys.exc_info())+"\n")
            log.write("[error] "+str(sys.exc_info()[1])+"\n")


    log.close() 
    print ("[",info,"] done with match id=", match_id)


###################################
#
# function CALC_EXPG
#
###################################
def calc_expg(match_id, jsonpath, csvpath, tournamentName, superLeagues, overwrite=False):
    info="calc_expg"

    filecsv = csvpath+"/"+str(match_id)+".csv"
    filecsve = csvpath+"/"+str(match_id)+".csve"
    if os.path.exists(filecsve) and overwrite==False:
        return False

    os.system(Rscript + " --vanilla R/expg-predict.R "+filecsv)

    os.system("./bash/csvesed.sh "+filecsve)
    #os.system("find "+csvpath+"/.. -name '"+tournamentName+".csv' -print -maxdepth 1 -exec rm -f {} \;")

    #print "tournamentName:",tournamentName
    #print "superLeagues:", superLeagues
    print ("[",info,"] tournamentName:", tournamentName)

    ###if tournamentName in superLeagues:
    ###    os.system("cp -f "+filecsve+" /tmp/.")
    ###    ###db = psycopg2.connect(database="ev", user="giacobba", host="127.0.0.1", port="5432")
    ###    ###curr = db.cursor()
    ###    tableName = tournamentName.replace('-','') + ".event"
    ###    matchFile = "'/tmp/" + str(match_id) + ".csve'"
    ###    print ("[",info,"] tableName:", tableName)
    ###    print ("[",info,"] matchFile:", matchFile)
    ###    try:
    ###        ###curr.execute("DELETE FROM "+tableName+" WHERE MATCHID=%s;", (match_id,))
    ###        ###curr.execute("COPY "+tableName+" FROM %s \
    ###        ###    with (format csv, encoding 'UTF8', header true);", (matchFile,));
    ###        os.system("psql ev -c \"ROLLBACK;\"")
    ###        os.system("psql ev -c 'DELETE FROM "+tableName+" WHERE MATCHID=" +match_id+ "';")
    ###        os.system("psql ev -c \"COPY "+tableName+" FROM '" +str(matchFile)+ "' with (format csv, encoding 'UTF8', header true);\"")
    ###    except:
    ###        print ("[",info,"] there was an error in DELETE/COPY onto db")
    ###        pass

    ###    #db.commit()
    ###    #db.close()

    print ("[",info,"] done with csve id=", match_id)
 
###################################
#
# MAIN PROGRAM
#
###################################
#if __name__ == "__main__":
#    parse_match(1340251, overwrite=True)
    

