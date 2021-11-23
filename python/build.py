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
import glob
import pandas as pd

import scipy as sp
from sklearn.metrics import average_precision_score, roc_auc_score, f1_score, precision_score, \
recall_score, cohen_kappa_score, classification_report,confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression


SITE = 'https://www.whoscored.com'
HEADERS = {'User-Agent': 'Mozilla/5.0'}

cwd=os.getcwd()

#if "Darwin" in platform.system():
#    r = webdriver.Chrome(cwd+'/../bin/chromedriver_mac')
#else:
#    r = webdriver.Chrome(cwd+'/../bin/chromedriver')
class color:
   PURPLE = '\033[95m'
   CYAN = '\033[96m'
   DARKCYAN = '\033[36m'
   BLUE = '\033[94m'
   GREEN = '\033[92m'
   YELLOW = '\033[93m'
   RED = '\033[91m'
   BOLD = '\033[1m'
   UNDERLINE = '\033[4m'
   END = '\033[0m'
    
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
# function EXPG_BUILD
#
###################################
def expg_build():
    info = "expg_build"
    print("[", info, "] Collecting csv files...")

    path = r'csv/Italy-Serie-A/*'
    path = r'csv/Europe-Europa-League/*'
    all_files = glob.glob(os.path.join(path, "*.csve"))

    df_from_each_file = (pd.read_csv(f) for f in all_files)
    df = pd.concat(df_from_each_file, ignore_index=True)

    print("[", info, "] Data collected:", len(df))
    sha = df[["x", "y", "satisfiedEventsTypes"]]
    sha = sha[sha['satisfiedEventsTypes'].str.contains('shotsTotal')]
    sha = sha[~sha['satisfiedEventsTypes'].str.contains('penaltyScored')]
    sha = sha[~sha['satisfiedEventsTypes'].str.contains('penaltyMissed')]
    sha = sha[~sha['satisfiedEventsTypes'].str.contains('shotBlocked')]
    print('[', info, '] Shots collected:', len(sha))

    sha.loc[~sha['satisfiedEventsTypes'].str.contains('shotOpenPlay'), 'is_op'] = 0
    sha.loc[sha['satisfiedEventsTypes'].str.contains('shotOpenPlay'), 'is_op'] = 1
    sha = sha.astype({"is_op": int})

    sha.loc[~sha['satisfiedEventsTypes'].str.contains('shotHead'), 'is_head'] = 0
    sha.loc[sha['satisfiedEventsTypes'].str.contains('shotHead'), 'is_head'] = 1
    sha = sha.astype({"is_head": int})

    sha.loc[~sha['satisfiedEventsTypes'].str.contains('shotRightFoot'), 'is_footed'] = 0
    sha.loc[~sha['satisfiedEventsTypes'].str.contains('shotLeftFoot'), 'is_footed'] = 0
    sha.loc[sha['satisfiedEventsTypes'].str.contains('shotLeftFoot'), 'is_footed'] = 1
    sha.loc[sha['satisfiedEventsTypes'].str.contains('shotRightFoot'), 'is_footed'] = 1
    sha = sha.astype({"is_footed": int})

    sha.loc[~sha['satisfiedEventsTypes'].str.contains('bigChanceScored'), 'is_bc'] = 0
    sha.loc[~sha['satisfiedEventsTypes'].str.contains('bigChanceMissed'), 'is_bc'] = 0
    sha.loc[sha['satisfiedEventsTypes'].str.contains('bigChanceScored'), 'is_bc'] = 1
    sha.loc[sha['satisfiedEventsTypes'].str.contains('bigChanceMissed'), 'is_bc'] = 1
    sha = sha.astype({"is_bc": int})

    sha.loc[~sha['satisfiedEventsTypes'].str.contains('goalNormal'), 'is_goal'] = 0
    sha.loc[sha['satisfiedEventsTypes'].str.contains('goalNormal'), 'is_goal'] = 1
    sha = sha.astype({"is_goal": int})

    sha.drop('satisfiedEventsTypes', inplace=True, axis=1)

    X = sha.iloc[:,:-1]
    y = sha.iloc[:,-1]
    #global X_train
    #global y_train
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=1)

    from hyperopt import fmin, tpe, hp, STATUS_OK, Trials

    def evaluate_model(params): 
        model = GradientBoostingClassifier(
                            learning_rate=params['learning_rate'],
                            min_samples_leaf=params['min_samples_leaf'],
                            max_depth = params['max_depth'],
                            max_features = params['max_features']
                            )
    
        model.fit(X_train, y_train)
        return {
            'learning_rate': params['learning_rate'],
            'min_samples_leaf': params['min_samples_leaf'],
            'max_depth': params['max_depth'],
            'max_features': params['max_features'],
            'train_ROCAUC': roc_auc_score(y_train, model.predict_proba(X_train)[:, 1]),
            'test_ROCAUC': roc_auc_score(y_test, model.predict_proba(X_test)[:, 1]),
            'recall': recall_score(y_test, model.predict(X_test)),
            'precision': precision_score(y_test, model.predict(X_test)),
            'f1_score': f1_score(y_test, model.predict(X_test)),
            'train_accuracy': model.score(X_train, y_train),
            'test_accuracy': model.score(X_test, y_test),
        }
    
    def objective(params):
        res = evaluate_model(params)
        
        res['loss'] = - res['test_ROCAUC'] # Esta loss es la que hyperopt intenta minimizar
        res['status'] = STATUS_OK # Asi le decimos a hyperopt que el experimento salio bien
        return res 
    
    hyperparameter_space = {
            'learning_rate': hp.uniform('learning_rate', 0.05, 0.3),
            'min_samples_leaf': hp.choice('min_samples_leaf', range(15, 200)),
            'max_depth': hp.choice('max_depth', range(2, 20)),
            'max_features': hp.choice('max_features', range(2, 6))
    }


    trials = Trials()
    fmin(
        objective,
        space=hyperparameter_space,
        algo=tpe.suggest,
        max_evals=50,
        trials=trials
    );

    print(pd.DataFrame(trials.results).sort_values(by='f1_score', ascending=False).head(5))

    model = GradientBoostingClassifier(
                        learning_rate=0.239477,
                        min_samples_leaf=87,
                        max_depth = 17,
                        max_features = 4
                        )
    model.fit(X_train, y_train)

    print('The test set contains {} examples (shots) of which {} are positive (goals).'.format(len(y_test), y_test.sum()))
    print('The accuracy of classifying whether a shot is goal or not is {}%.'.format(round(model.score(X_test, y_test)*100),2))
    print('Our classifier obtains an ROC-AUC of {}%'.format(round(roc_auc_score(y_test, model.predict_proba(X_test)[:, 1])*100),2))

    print(' ')

    print('The baseline performance for PR-AUC is {}%. This is the PR-AUC that what we would get by random guessing.'.format(round(y_train.mean(),2)))
    print('Our model obtains an PR-AUC of {}%.'.format(round(average_precision_score(y_test, model.predict_proba(X_test)[:, 1])*100,2)))
    print('Our classifier obtains a Cohen Kappa of {}.'.format(round(cohen_kappa_score(y_test,model.predict(X_test)),2)))

    print(' ')

    print(color.BOLD + color.YELLOW + 'Confusion Matrix:\n' + color.END)
    print(confusion_matrix(y_test,model.predict(X_test)))
    print(color.BOLD +  color.YELLOW + '\n Report:' + color.END)
    print(classification_report(y_test,model.predict(X_test)))

    print(' ')

    sha['prediction'] = model.predict_proba(X)[:, 1]

    print(sha.loc[sha['is_goal']==1])

    

###################################
#
# MAIN PROGRAM
#
###################################
#if __name__ == "__main__":
#    get_match(r, 1340251, overwrite=True)
#    r.quit()
    

