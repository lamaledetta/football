# -*- coding: utf_8 -*-
import sys
### PYTHON 2 ###reload(sys)
### PYTHON 2 ###sys.setdefaultencoding('utf-8')

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
import unidecode
import glob

import pandas as pd

Rscript="/Library/Frameworks/R.framework/Resources/Rscript"

###################################
#
# function MATCH_MAP
#
###################################
def match_map(matchId, homeName, awayName, csvpath, season, tournamentName, dbxRoot, overwrite=False):
    info="match_map"
    remotepath = dbxRoot+"/"+tournamentName
    if os.path.exists(remotepath) and overwrite==False:
        for name in glob.glob(remotepath+'/*'+str(matchId)+'*'):
        #print("[",info,"] map present in", tournamentName)
            return False
    elif not os.path.exists(remotepath):
        #os.system("mkdir -p "+remotepath)
        os.makedirs(remotepath, 0o755)

    filename = csvpath + "/colors.csv"
    df = pd.read_csv(filename)
    print("[",info,"]", tournamentName)
	#tournamentName = tournamentName.replace('-','')
    print("[",info,"]", homeName)
    print("[",info,"]", awayName)

    try:
	    homeColor = df.loc[df.name == homeName, 'home'].values[0]
    except:
        homeColor = ""
    try:
	    awayColor = df.loc[df.name == awayName, 'away'].values[0]
    except:
        awayColor = ""

    if not homeColor:
        homeColor = 'lightblue4'

    if not awayColor:
        awayColor = 'lightcoral'
		
    if awayColor in homeColor or homeColor in awayColor:
        awayColor = df.loc[df.name == awayName, 'home'].values[0]

    os.system(Rscript + " --vanilla R/match_map.builder.R " + str(matchId) + " " + tournamentName + " " + homeColor + " " + awayColor + " " + csvpath + " " + str(season))
    os.system(Rscript + " --vanilla R/pass_map.builder.R " + str(matchId) + " " + tournamentName + " " + homeColor + " " + awayColor + " " + csvpath + " " + str(season))
    os.system(Rscript + " --vanilla R/last_third.builder.R " + str(matchId) + " " + tournamentName + " " + homeColor + " " + awayColor + " " + csvpath + " " + str(season))

    remotepath = remotepath.replace(" ","\ ")
    os.system("mv output/* "+remotepath)
        #for name in glob.glob('output/*'+str(matchId)+'*'):
        #    name = name.replace(" ","\ ")
        #    remotepath = remotepath.replace(" ","\ ")
	#    os.system("cp -f "+name+" "+remotepath)

###################################
#
# function PUT_IN_DROPBOX
#
###################################
def put_in_dbx(matchId, homeName, awayName, tournamentName, dbxRoot, overwrite=False):
    info="put_in_dbx"
    for name in glob.glob('output/*'+str(matchId)+'*'):
        if not os.path.exists(dbxRoot+"/"+tournamentName):
            os.system("mkdir -p "+dbxRoot+"/"+tournamentName)
            name = name.replace(" ","\ ")
            newname = re.sub(r'.\\ [0-9]+\\ .jpeg', r'.jpeg', name)
            newname = newname.replace("output/","")
            os.system("mv "+name+" "+dbxRoot+"/"+tournamentName+"/"+newname)

    print("[",info,"] map", newname, "moved")
