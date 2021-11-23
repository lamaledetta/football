# -*- coding: utf_8 -*-
import sys
### PYTHON 2 ###reload(sys)
### PYTHON 2 ###sys.setdefaultencoding('utf-8')

from time import sleep
from random import random
from statistics import mean

from selenium import webdriver
from selenium.common.exceptions import TimeoutException
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4 import BeautifulSoup

from lxml import html
from datetime import datetime, timedelta, date

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
import unidecode
import dateparser

SITE = 'https://www.whoscored.com'
HEADERS = {'User-Agent': 'Mozilla/5.0'}

cwd=os.getcwd()

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
# function GURL
#
###################################
def gurl(r, page):

    try:
        r.set_page_load_timeout(10)
        r.get(page)
    except:
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()

    wait()

    try:
        r.find_element_by_xpath("//button[contains(text(), 'Continue Using Site')]").click();
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()
    except:
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()
    
    try:
        r.find_element_by_xpath("//button[contains(text(), 'I accept')]").click();
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()
    except:
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()

    try:
        r.find_element_by_xpath("//button[contains(text(), 'Agree')]").click();
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()
    except:
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()

    try:
        r.find_element_by_xpath("//button[contains(text(), 'AGREE')]").click();
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()
    except:
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()

    try:
        r.find_element_by_xpath("//button[contains(text(), 'ACCETTO')]").click();
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()
    except:
        webdriver.ActionChains(r).send_keys(Keys.ESCAPE).perform()

    wait()

    return r.page_source


###################################
#
# function GET_MATCH
#
###################################
def get_match(r, match_id, jsonpath, overwrite=False):
    info="get_match"
    filename = jsonpath + '/' + str(match_id) + ".json"

    if not os.path.exists(jsonpath):
        os.makedirs(jsonpath, 0o755)
        print ("[",info,"] dir", jsonpath, "created")


    if os.path.exists(filename) and overwrite==False:
        #print ("[",info,"] file", filename, "exists, exiting...")
        return False

    print ("[",info,"] fetching match id=", match_id)
    #print ("[",info,"] overwrite=", overwrite)

    page = SITE+'/Matches/{0}/Live'.format(match_id)
    print ("[",info,"] getting match URL=",page)
 
    

    content = gurl(r, page)
    # SERBIAN CHAR SPECIAL FIX
    content=content.replace("&amp;#263;","c")
    # SERBIAN CHAR SPECIAL FIX

    matchId = re.findall("matchId:([^;]+);", content)
    #matchData = re.findall("matchCentreData = ([^;]+});", content)
    matchData = re.findall("matchCentreData:([^;]+});", content)

    #if not matchData:
    #    matchData = re.findall('var matchCentreData = (.+);', content)

    if not matchData:
        print("[error] not a valid matchCentre var found")
        return -1

    dummy = matchData[0].split('\n')
    matchData = dummy[0][:-1]
    matchData = [ matchData ]

    matchEvent = re.findall("matchCentreEventTypeJson:([^;]+});", content)
    dummy = matchEvent[0].split('\n')
    matchEvent = dummy[0][:-1]
    matchEvent = [ matchEvent ]

#    if not matchData:
#        matchData = re.findall('var matchCentreData = (.+);', content)
#        
#    if not matchData:
#        print("[error] not a valid matchCentre var found")
#        return -1

    filename = jsonpath + '/' + str(match_id) + ".json"
    with open(filename, 'w') as f:
        json.dump(matchData, f)

    filename = jsonpath + "/eventdict.json"
    with open(filename, 'w') as f:
        json.dump(matchEvent, f)

    return True

###################################
#
# function GET_TOURNAMENTS
#
###################################
def get_tournaments(r, jsonpath, csvpath, overwrite=False):
    info="get_tournaments"
    filename = csvpath + "/detailed_tournaments.csv"

    if os.path.exists(filename) and overwrite==False:
        print ("[",info,"] file", filename, "exists, exiting...")
        return False

    print ("[",info,"] scraping tournaments")
 
    content = gurl(r, SITE)
    fromcontent = html.fromstring(content)
    content = re.sub(r'( &amp; )', r' and ', content)

    all_regions = re.findall("allRegions = ([^;]+);", content)[0].replace("'", '"')
    all_regions = re.sub(r'(\w+):', r'"\1":', all_regions)
    all_regions = json.loads(all_regions)

    filename = jsonpath + "/all_tournaments.json"
    with open(filename, 'w') as f:
        json.dump(all_regions, f)
	
    print ("[",info,"] all tournaments in .json")

    detailed_link = fromcontent.xpath("//div[@id='popular']/ul/li/a[text()]/@href")
    detailed_title = fromcontent.xpath("//div[@id='popular']/ul/li/a[text()]/@title")
    detailed_text = fromcontent.xpath("//div[@id='popular']/ul/li/a[text()]")
	
    # "/Regions/252/Tournaments/2/England-Premier-League"
    detour = {}
    detour[0] = {}
    for dl in detailed_link:
        t = dl.split("/")
        detour[t[4]] = {}
        detour[t[4]]['id'] = t[2]
        detour[t[4]]['name'] = unidecode.unidecode(t[5].split("-")[0])
        detour[t[4]]['tournamentUrl'] = unidecode.unidecode(dl)
        detour[t[4]]['tournamentName'] = unidecode.unidecode(t[5])
        #detour[t[4]]['tournamentName'] = t[5].lstrip(t[5].split("-")[0]+'-')
        #detour[t[4]]['tournamentName'] = ' '.join((t[5].lstrip(t[5].split("-")[0]+'-')).split("-"))

    detour.pop(0)
    
    filename = csvpath + "/detailed_tournaments.csv"
    
    f = csv.writer(open(filename, "wt+"))    

    f.writerow(["id", "name", "tournamentId", "tournamentUrl", "tournamentName"])
    
    for k in detour.keys():
        f.writerow([
            detour[k]['id'],
            detour[k]['name'],
            k,
            detour[k]['tournamentUrl'],
            detour[k]['tournamentName']
            ])

    print ("[",info,"] detailed tournaments in .csv")
	
	
###################################
#
# function GET_SEASONS
#
###################################
def get_seasons(r, jsonpath, csvpath, overwrite=False):
    info="get_seasons"
    filename = csvpath + "/detailed_tournaments.csv"

    with open(filename, "r") as f:
        rows = csv.reader(f)
        line=0
        for row in rows:
            if line==0:
                line=+1
            else:
                #print ("[",info,"]", row)
                tournamentPath = csvpath + "/" + row[4]
                if not os.path.exists(tournamentPath):
                    os.mkdir(tournamentPath, 0o755)
                    print ("[",info,"] dir", tournamentPath, "created")
                #else:
                #    print ("[",info,"] dir", tournamentPath, "exists")

                filename = tournamentPath + "/seasons.csv"

                if os.path.exists(filename) and overwrite==False:
                    #print ("[",info,"] file", filename, "exists, skipping...")
                    pass

                else:
                    page = SITE+row[3]
                    content = html.fromstring(gurl(r, page))
                    season_links = content.xpath('//select[@id="seasons"]/option/@value')
                    season_names = content.xpath('//select[@id="seasons"]/option/text()')
                    #stage_links = content.xpath('//select[@id="stages"]/option/@value')
                    #stage_names = content.xpath('//select[@id="stages"]/option/text()')

                    #print "stage_links:", stage_links
                    #print "stage_names:", stage_names

                    f = csv.writer(open(filename, "wt+"))    
                    f.writerow(["seasonId", "seasonName", "regionId", "tournamentId", "tournamentName"])

                    for season_link, season_name in zip(season_links, season_names):

                        try:
                            shortname=int(season_name.split('/')[-2])
                        except:
                            shortname=int(season_name.split(' ')[0])

                        season = {
                            'seasonId': int(season_link.split('/')[-2]),
                            'seasonName': int(shortname),
                            #'seasonName': int(season_name.split('/')[0]),
                            #'shortname': int(season_name.split('/')[-2]),
                            'tournamentName': row[4],
                            'regionId': row[0],
                            'tournamentId': row[2],
                            #'stageUrl': stage_link,
                            #'stageName': stage_name,
                        }

                        f.writerow([
                            season['seasonId'],
                            season['seasonName'],
                            season['regionId'],
                            season['tournamentId'],
                            season['tournamentName'],
                            #season['stageUrl'],
                            #season['stageName']
                            ])

                    print ("[",info,"] seasons.csv created for", season['tournamentName'])

    print ("[",info,"] done with seasons")
    

###################################
#
# function GET_FIXTURES
#
###################################
def get_fixtures(r, jsonpath, csvpath, seasonId, seasonName, regionId, tournamentId, tournamentName, overwrite=False):
    info="get_fixtures"
    filename = csvpath + "/" + tournamentName + "/" + str(seasonName) + "/fixtures.csv"
    
    if os.path.exists(filename) and overwrite==False:
        print ("[",info,"] file", filename, "exists, skipping...")
        return False

    dirname = csvpath + "/" + tournamentName + "/" + str(seasonName)

    if not os.path.exists(dirname):
        os.mkdir(dirname, 0o755)
        print ("[",info,"] dir", dirname, "created")


    try:
        my_file = open(filename, "wt+")
        f = csv.writer(my_file)    
    except:
        print("[",info,"] Error: cannot open", filename)
        return False

    f.writerow(["stageId","stageName", "season", "matchId", "startDate", "status", "result", "homeTeamId", "homeTeamName", "homeTeamUrl", 
        "awayTeamId", "awayTeamName", "awayTeamUrl", "matchUrl", "homeScore", "awayScore"])


    page = SITE + "/Regions/" + str(regionId) + "/Tournaments/" + str(tournamentId) + "/Seasons/" + str(seasonId)

    content = html.fromstring(gurl(r, page))

    stage_links = content.xpath('//select[@id="stages"]/option/@value')
    stage_names = content.xpath('//select[@id="stages"]/option/text()')

    #print "**** STAGE LINKS:", stage_links
    #print "**** STAGE NAMES:", stage_names
    #print "**** TOURNAMENT NAME:", tournamentName

    if not stage_links:
        try:
            fixture_link = content.xpath("//div[@id='sub-navigation']/ul/li/a[text()='Fixtures']/@href")[0]
        except:
            fixture_link = content.xpath("//div[@id='sub-navigation']/ul/li/a[text()='Partite']/@href")[0]
 
        stage_links.append(fixture_link)
        stage_names.append(tournamentName)

    for stage_link, stage_name in zip(stage_links, stage_names):

        stage_link = unidecode.unidecode(stage_link)
        stage_name = unidecode.unidecode(stage_name)

        if ('Playoff' in stage_name or 'Preliminary' in stage_name or 'Qualification' in stage_name or 'Grp.' in stage_name) and (not 'International' in tournamentName):
            print("[",info,"] not a valid stage")
            continue

        else:
            fixture_link = re.sub(r'Show', r'Fixtures',stage_link) 
            stage_id = stage_link.split('/')[-3]
            print ("[",info,"] found fixture_link:", fixture_link)
            print ("[",info,"] found stage_name:", stage_name)
            print ("[",info,"] found stage_id:", stage_id)

            page = SITE + fixture_link

            content = gurl(r, page)
            stopwhile = 0

            while stopwhile ==0:
                try:
                    r.find_element_by_css_selector('a.next.button.ui-state-default.rc-r.is-disabled')
                    stopwhile=1

                except:
                    try:
                        elem = r.find_element_by_css_selector('a.next.button.ui-state-default.rc-r.is-default')
                        elem.click()
                        #wait()
                    except:
                        stopwhile=1

            stopwhile = 0

            wait()
            #while not r.find_element_by_css_selector('a.previous.button.ui-state-default.rc-l.is-disabled'):

            while stopwhile==0:

                content = r.page_source
                soup = BeautifulSoup(content,"lxml")
                #print(soup)
                table = soup.find("div", attrs={'id':'tournament-fixture'})
				
                match_time = []
                match_status = []
                home_team_id = []
                home_team_name = []
                home_team_redcard = []
                home_team_link = []
                away_team_id = []
                away_team_name = []
                away_team_redcard = []
                away_team_link = []
                match_live = []
                result = []
                home_score = []
                away_score = []
                match_id = []
        
                try:
                    for th in table.find_all('div', attrs={'class':'divtable-body'}):
                        for tr in th.find_all('div'):
                            #print(tr)
                            if not tr.attrs.get("class"):
                                continue
                            if 'divtable-header' in tr.attrs.get("class"):
                                match_date =dateparser.parse(tr.get_text()).strftime('%A, %b %d %Y')
                                match_date =datetime.strptime(match_date, '%A, %b %d %Y')
                                #print("match_date=",match_date)
                            if 'divtable-row' in tr.attrs.get("class") and tr.attrs.get("data-id"):
                                match_id.append(tr.attrs.get("data-id"))
                                #print("matchid=",match_id)
                            if 'time' in tr.attrs.get("class"):
                                match_time.append(datetime.combine(match_date.date(), datetime.strptime(tr.get_text(), '%H:%M').time()))
                                #print("match_time=",match_time)
                            if 'status' in tr.attrs.get("class"):
                                match_status.append(tr.get_text())
                                #print("match_status=",match_status)
                            if 'stacked-score-display' in tr.attrs.get("class"):
                                match_live.append(tr.find_all('a')[0].attrs.get("href"))
                                #print("match_live=",match_live)
                            #if 'stacked-teams-display' in tr.attrs.get("class"):
                            #    home_team_name.append(tr.find_all('a')[0].get_text())
                            #    home_team_link.append(tr.find_all('a')[0].attrs.get("href"))
                            #    away_team_name.append(tr.find_all('a')[1].get_text())
                            #    away_team_link.append(tr.find_all('a')[1].attrs.get("href"))
                            #    print("home_team_name=",home_team_name)
                            #    print("home_team_link=",home_team_link)
                            #    print("away_team_name=",away_team_name)
                            #    print("away_team_link=",away_team_link)
                            if 'team' in tr.attrs.get("class") and 'home' in tr.attrs.get("class"):
                                home_team_name.append(tr.find_all('a')[0].get_text())
                                home_team_link.append(tr.find_all('a')[0].attrs.get("href"))
                                home_team_id.append(tr.attrs.get("data-id"))
                                #print("home_team_name=",home_team_name)
                                #print("home_team_link=",home_team_link)
                                #print("home_team_id=",home_team_id)
                            if 'team' in tr.attrs.get("class") and 'away' in tr.attrs.get("class"):
                                away_team_name.append(tr.find_all('a')[0].get_text())
                                away_team_link.append(tr.find_all('a')[0].attrs.get("href"))
                                away_team_id.append(tr.attrs.get("data-id"))
                                #print("away_team_name=",away_team_name)
                                #print("away_team_link=",away_team_link)
                                #print("away_team_id=",away_team_id)
                            if 'result' in tr.attrs.get("class"):
                                result_text = tr.get_text()
                                if result_text == "vs":
                                    #match_live.append(tr.find_all('a')[0].attrs.get("href"))
                                    result.append("")
                                    home_score.append("")
                                    away_score.append("")
                                else:
                                    #match_live.append(tr.find_all('a')[0].attrs.get("href"))
                                    result.append(re.sub(r'\s:\s', ":", result_text))
                                    home_score_d= result_text.split(':')[0]
                                    away_score_d= result_text.split(':')[-1]
                                    home_score_d= re.sub(r'\*', '', home_score_d)
                                    away_score_d= re.sub(r'\*', '', away_score_d)
                                    home_score.append(re.sub(r' ', '', home_score_d))
                                    away_score.append(re.sub(r' ', '', away_score_d))

                except:
                    try:
                        print("[",info,"] missing fixtures table")
                        fixturesData = re.findall("matches:([^;]+});", content)
                        fixturesData = re.sub(r'^["  "]', '', fixturesData)
                        fixturesData = re.sub(r' \n            }"$]', '', fixturesData)
                        print(fixturesData)
                        break
                    except:
                        break
                        ###page = re.sub(r'Fixtures', r'Show', page)
                        ###content = gurl(r, page)
                        ###stopwhile = 0

                        ###while stopwhile ==0:
                        ###    try:
                        ###        r.find_element_by_css_selector('a.next.button.ui-state-default.rc-r.is-disabled')
                        ###        stopwhile=1

                        ###    except:
                        ###        try:
                        ###            elem = r.find_element_by_css_selector('a.next.button.ui-state-default.rc-r.is-default')
                        ###            elem.click()
                        ###            #wait()
                        ###        except:
                        ###            stopwhile=1

                        ###stopwhile = 0

                        ###wait()
                        ####while not r.find_element_by_css_selector('a.previous.button.ui-state-default.rc-l.is-disabled'):

                        ###while stopwhile==0:

                        ###    content = r.page_source
                        ###    content = content.replace('\n', ' ').replace('\r', '')
                        ###    #soup = BeautifulSoup(content,"lxml")
                        ###    fixturesData = re.findall("matches:(.+?)],", content)
                        ###    fixturesData = re.sub(r'^  ', '', fixturesData[0])
                        ###    #fixturesData = re.sub(r'^[', '', fixturesData)
                        ###    fixturesData = re.sub(r' $', '', fixturesData)
                        ###    fixturesData = fixturesData.split(' ,')
                        ###    #fixturesData = re.sub(r' \n            }"$]', '', fixturesData)
                        ###    for f in fixturesData:
                        ###        print(f)
                        ###        f = re.sub(r'["["]+', r'', f)
                        ###        f = re.sub(r']', r'', f)
                        ###        elem = f.split(',')

                        ###        md = elem[2] + elem[3]
                        ###        print(md)
                        ###        match_date =dateparser.parse(tr.get_text()).strftime('%A, %b %d %Y')
                        ###        match_date =datetime.strptime(match_date, '%A, %b %d %Y')
                        ###        print(match_date)

                        ###    stopwhile=1




                        #                match_time.append(datetime.combine(match_date.date(), datetime.strptime(td.get_text(), '%H:%M').time()))
			#	if 'status' in td.attrs.get("class"):
			#		match_status.append(td.get_text())
			#	if 'team' in td.attrs.get("class") and 'home' in td.attrs.get("class"):
			#		home_team_id.append(td.attrs.get("data-id"))
                        #                home_team_name.append(td.find_all('a')[0].get_text())
                        #                home_team_redcard.append(re.sub(r'(\d?)\D+', r'\1',td.get_text()))
                        #                if not home_team_redcard:
			#			home_team_redcard.append(0)
                        #                home_team_link.append(td.find_all('a')[0].attrs.get("href"))
			#	if 'result' in td.attrs.get("class"):
			#		result_text = td.get_text()
                        #                if result_text == "vs":
                        #                    match_live.append(td.find_all('a')[0].attrs.get("href"))
                        #                    result.append("")
                        #                    home_score.append("")
                        #                    away_score.append("")
                        #                else:
                        #                    match_live.append(td.find_all('a')[0].attrs.get("href"))
                        #                    result.append(re.sub(r'\s:\s', ":", result_text))
                        #                    home_score_d= result_text.split(':')[0]
                        #                    away_score_d= result_text.split(':')[-1]
                        #                    home_score.append(re.sub(r'\*', '', home_score_d))
                        #                    away_score.append(re.sub(r'\*', '', away_score_d))
			#	if 'team' in td.attrs.get("class") and 'away' in td.attrs.get("class"):
			#		away_team_id.append(td.attrs.get("data-id"))
                        #                away_team_name.append(td.find_all('a')[0].get_text())
                        #                away_team_redcard.append(re.sub(r'\D+(\d?)', r'\1',td.get_text()))
                        #                if not away_team_redcard:
			#                    away_team_redcard.append(0)
                        #                away_team_link.append(td.find_all('a')[0].attrs.get("href"))
                
                #can_commit = 0
		# print "match_time:", match_time
		# print "match_status:", match_status
		# print "home_team_id:", home_team_id
		# print "home_team_name:", home_team_name
		# print "home_team_redcard:", home_team_redcard
		# print "home_team_link:", home_team_link
		# print "away_team_id:", away_team_id
		# print "away_team_name:", away_team_name
		# print "away_team_redcard:", away_team_redcard
		# print "away_team_link:", away_team_link
		# print "match_live:", match_live
		# print "result:", result
		# print "home_score:", home_score
		# print "away_score:", away_score 
		
                #if can_commit == 1:
                for i in range(0,len(result)):
                   f.writerow([
                       stage_id,
                       tournamentName,
                       seasonName,
                       match_id[i],
                       match_time[i],
                       match_status[i],
		       result[i],
                       home_team_id[i],
                       home_team_name[i],
                       home_team_link[i],
                       away_team_id[i],
                       away_team_name[i],
                       away_team_link[i],
                       match_live[i],
                       home_score[i],
                       away_score[i] 
                       ])
                #can_commit=0



                try:
                    r.find_element_by_css_selector('a.previous.button.ui-state-default.rc-l.is-disabled')
                    stopwhile=1
                
                except:
                    try:
                        elem = r.find_element_by_css_selector('a.previous.button.ui-state-default.rc-l.is-default')
                        elem.click()
                        time.sleep(0.5)
                        #content = r.page_source
                    except:
                        stopwhile=1


    print ("[",info,"] done with fixtures: ", filename)
    my_file.close()
    time.sleep(0.5)
    return True









###################################
#
# MAIN PROGRAM
#
###################################
#if __name__ == "__main__":
#    get_match(r, 1340251, overwrite=True)
#    r.quit()
    

