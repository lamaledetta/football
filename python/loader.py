# -*- coding: utf_8 -*-
import sys
reload(sys)
sys.setdefaultencoding('utf-8')

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
#import psycopg2
import os
import os.path
import platform
#import HTMLParser
import requests
import json, ast
import re

import pandas as pd

#SITE = 'https://www.whoscored.com'
#HEADERS = {'User-Agent': 'Mozilla/5.0'}
#
#cwd=os.getcwd()
#
#if "Darwin" in platform.system():
#    r = webdriver.Chrome(cwd+'/../bin/chromedriver_mac')
#else:
#    r = webdriver.Chrome(cwd+'/../bin/chromedriver')
    
max_year=date.today().year-1 if date.today().month < 8 else date.today().year

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
# MAIN PROGRAM
#
###################################
if __name__ == "__main__":
    info = "pre_loader"

    csvname = sys.argv[1]
    jsonpath = sys.argv[2]

    csvename = csvname + 'e'
    if os.path.isfile(csvename):
        sys.exit()

    filename = "json/" + jsonpath + "/" + str(max_year) + "/eventdict.json"

    if os.path.isfile(filename):
        with open(filename, 'r') as f:
            matchEvent = json.load(f)

    matchEventDict = json.loads(matchEvent[0], strict=False)
    matchEventDict = dict((k.encode('ascii','ignore'),v) for k,v in matchEventDict.iteritems())
    matchEventDictReverse = dict((v,k.encode('ascii','ignore')) for k,v in matchEventDict.iteritems())

    filename = csvname

    df = pd.read_csv(filename)

    replacecol = []
    #replacecol2 = []

    for i in range(0,len(df.index)):
        if df.iloc[i]['satisfiedEventsTypes'] != '[]':
            eventlist = df.iloc[i]['satisfiedEventsTypes'][1:-1].split(",")
            dummylist = []
            for j in eventlist:
                dummylist.append(matchEventDictReverse[int(j)])
            #print "df", df.iloc[i]['satisfiedEventsTypes'], "dummylist", dummylist 
            replacecol.append(dummylist)
            #replacecol2.append(int(df.iloc[i]['id']))
        else:
            replacecol.append('{}')
            #replacecol2.append('0.0')

    df['newcol'] = replacecol
    del df['satisfiedEventsTypes']
    df = df.rename(columns={'newcol': 'events'})

    df['eventId'] =df['eventId'].astype(int)
    df['playerId'] =df['playerId'].astype(int)
    df['relatedPlayerId'] =df['relatedPlayerId'].astype(int)
    df['relatedEventId'] =df['relatedEventId'].astype(int)
    df['OppositeRelatedEvent'] =df['OppositeRelatedEvent'].astype(int)
    df['expandedMinute'] =df['expandedMinute'].astype(int)
    df['period'] =df['period'].astype(int)
    df['minute'] =df['minute'].astype(int)
    df['second'] =df['second'].astype(int)

    #df['newcol'] = replacecol2
    #del df['id']
    #df = df.rename(columns={'newcol': 'id'})

    filename = csvename
    #print "[", info, "] writing", filename
    df.to_csv(filename, encoding='utf-8', index=False)


