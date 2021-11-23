#!/usr/bin/python
# -*- coding: utf_8 -*-
import sys
reload(sys)
sys.setdefaultencoding('utf-8')


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
import HTMLParser
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

import warnings
warnings.filterwarnings("ignore", category=RuntimeWarning)


#######################
#
# GLOBAL VARS
#
#######################
SITE = 'https://www.whoscored.com'
HEADERS = {'User-Agent': 'Mozilla/5.0'}
max_year=date.today().year if date.today().month < 7 else date.today().year+1

cwd=os.getcwd()
csvpath = cwd+'/csv'
jsonpath = cwd+'/json'
#if "Darwin" in platform.system():
#    r = webdriver.Chrome(cwd+'/bin/chromedriver_mac')
#else:
#    r = webdriver.Chrome(cwd+'/bin/chromedriver')


seasonBl=[6135]
matchBl=[1364968, 1364956]


#######################
#
# MAIN PROGRAM
#
#######################
if __name__ == "__main__":
    info = "csv2csve.py"

    matchId=str(sys.argv[1])
    matchId=matchId.split("/")[-1]
    matchId=matchId.split(".")[0]
    fixtures=os.popen("grep -l "+str(matchId)+" csv/*/*/fixtures.csv").read().split("\n")[0]
    print "[",info,"] found",matchId,"in fixtures:",fixtures
    stage=fixtures.split("/")[1]
    season=fixtures.split("/")[2]
    match=os.popen("grep "+str(matchId)+" csv/*/*/fixtures.csv").read().split("\n")[0]
    homeName=match.split(",")[8]
    awayName=match.split(",")[11]
    #get_match(r, matchId, "json/"+ stage + "/" + season, True)
    parse_match(matchId, "json/" + stage + "/" + season, "csv/" + stage + "/" + season, stage, True)
    calc_expg(matchId, "json/" + stage + "/" + season, "csv/" + stage + "/" + season, stage, True)
    #match_map(matchId, homeName, awayName, csvpath, stage, True)
    

