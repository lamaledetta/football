#!/usr/bin/python3

import sys
import csv
import datetime
import psycopg2
import os
import time

import numpy as np

import pandas as pd

#comp_id=sys.argv[1]
season=sys.argv[1]
comp_id=0
stage_id=0

try:
    conn = psycopg2.connect("dbname='ev'")
except:
    print("Can't connect to database.")
    sys.exit()

today = datetime.datetime.now()
start = today.strftime("%F")
end = today + datetime.timedelta(days=6)

PWD=os.getcwd()

#stageId,stageName,season,matchId,startDate,status,result,homeTeamId,homeTeamName,homeTeamUrl,awayTeamId,awayTeamName,awayTeamUrl,matchUrl,homeScore,awayScore
create_fixtures = """
drop table if exists _fixtures_;
create table _fixtures_ (
    stageId     integer,
    stageName   text,
    season      integer,
    matchId     integer,
    startDate   date,
    status      text,
    result      text,
    homeTeamId  integer,
    homeTeamName text,
    homeTeamUrl text,
    awayTeamId  integer,
    awayTeamName text,
    awayTeamUrl text,
    matchUrl    text,
    homeScore   integer,
    awayScore   integer,
    primary key (matchId)

);

copy _fixtures_ from '""" + PWD + '/../csv/Italy-Serie-A/'+season+'/fixtures.csv' + """' csv header;

select * from _fixtures_ ;
"""

cur = conn.cursor()
cur.execute(create_fixtures)

fixtures = cur.fetchall()

select_games = """
select
--t.team_name as team_name,
--o.team_name as opponent_name,
g.hometeamname as team_name,
g.awayteamname as opponent_name,

tf.exp_factor*sft.offensive as etg,
of.exp_factor*sfo.offensive as eog

from _fixtures_ g
--join _results_ t
--  on (t.team_id,t.year)=(g.homeTeamId,g.season)
join _schedule_factors sft
  on (sft.team_id,sft.year)=(g.homeTeamId,g.season)
--join _results_ o
--  on (o.team_id,o.year)=(g.awayTeamId,g.season)
join _schedule_factors sfo
  on (sfo.team_id,sfo.year)=(g.awayTeamId,g.season)
join _factors tf on
  tf.level='offense_home'
join _factors of on
  of.level='defense_home'
where
--    not(g.date='LIVE')
--and g.competition='Prem'
      g.startdate::date >= current_date
--and   g.status != 'FT'
--and g.home_goals is null
--and g.away_goals is null
--and g.team_id=g.home_team_id
order by g.homeTeamName asc,g.startdate::date asc
;
"""

cur = conn.cursor()
cur.execute(select_games)

games = cur.fetchall()

#stageId,stageName,season,matchId,startDate,status,result,homeTeamId,homeTeamName,homeTeamUrl,awayTeamId,awayTeamName,awayTeamUrl,matchUrl,homeScore,awayScore
select_teams = """
drop table if exists _teams_;

create table _teams_ (
    team_name text,
    team_id integer,
    primary key (team_id)
);

insert into _teams_ (
    team_name, team_id
)(
select
distinct(teamname) as team_name,
teamid as team_id
from italyseriea.event
where season="""+season+"""
);

select * from _teams_;
"""

cur = conn.cursor()
cur.execute(select_teams)

teams = cur.fetchall()

select_table = """
select
s.team_name as team,
sum(
case when s.team_id=g.hometeamid
     and (g.homescore > g.awayscore) then 1
     when s.team_id=g.awayteamid
     and (g.homescore < g.awayscore) then 1
else 0
end) as w,
sum(
case when s.team_id=g.hometeamid
     and (g.homescore=g.awayscore) then 1
     when s.team_id=g.awayteamid
     and (g.homescore=g.awayscore) then 1
else 0
end) as d,
sum(
case when s.team_id=g.hometeamid
     and (g.homescore < g.awayscore) then 1
     when s.team_id=g.awayteamid
     and (g.homescore > g.awayscore) then 1
else 0
end) as l,

sum(
case when s.team_id=g.hometeamid then g.homescore
     when s.team_id=g.awayteamid then g.awayscore
else 0
end) as gf,
sum(
case when s.team_id=g.hometeamid then g.awayscore
     when s.team_id=g.awayteamid then g.homescore
else 0
end) as ga
----sum(
----case when g.team_id=g.home_team_id then g.home_score-g.away_score
----     else g.away_score-g.home_score
----end) as gd

from _fixtures_ g, _teams_ s
where
--    not(g.date='LIVE')
--and g.competition_id = s.competition_id
--and g.season = s.season
--and g.competition='Prem'
    g.startdate::date <= current_date
and g.status = 'FT'
and g.homescore is not null
and g.awayscore is not null
group by s.team_name
order by s.team_name asc
;
"""

cur.execute(select_table)
table = pd.DataFrame(cur.fetchall(),
                     columns=['team','w','d','l','gf','ga'])

with open('sims2.csv', 'wb') as f:
    
    writer = csv.writer(f, delimiter = '|', lineterminator='\n')

    header = ['team','n','rank','w','d','l','gf','ga','gd','pts']
    csv.writer(f).writerows([header])

    r=10000

    for j in range(r):

        team = []
        w = []
        d = []
        l = []
        gf = []
        ga = []

        print "Sim no.: %d \r" %j,
    
        for i,game in enumerate(games):

            tg = np.random.poisson(lam=game[2])
            og = np.random.poisson(lam=game[3])    
    
            team.extend([game[0],game[1]])
            gf.extend([tg, og])
            ga.extend([og, tg])
            #    gd.extend([tg-og, og-tg])
    
            if (tg > og):
                w.extend([1,0])
                d.extend([0,0])
                l.extend([0,1])
            elif (tg == og):
                w.extend([0,0])
                d.extend([1,1])
                l.extend([0,0])
            else:
                w.extend([0,1])
                d.extend([0,0])
                l.extend([1,0])

        sim = {'team' : team,
               'w' : w,
               'd' : d,
               'l' : l,
               'gf' : gf,
               'ga' : ga}

        ros = pd.DataFrame(sim,
                           columns = ['team','w','d','l','gf','ga'])

        df = pd.concat([table, ros], axis=0)

        season = df.groupby(['team']).agg({'w' : sum,
                                           'd' : sum,
                                           'l' : sum,
                                           'gf' : sum,
                                           'ga' : sum})
        season['gd'] = season['gf']-season['ga']
        season['pts'] = 3*season['w']+season['d']
        final = season.sort_values(['pts', 'gd', 'gf'], ascending=[0, 0, 0])

        final['i'] = final['pts']*1000000+(final['gd']+100)*1000+final['gf']

        final['rank'] = final['i'].rank(ascending=0, method='min')

        final.drop(['i'],inplace=True,axis=1)
        final['n'] = j

        final.to_csv(f, columns=['team','n','rank','w','d','l','gf','ga','gd','pts'], header=False)
        #if j==1:
        #    os.system("head -n +1 sims2.csv > sims2.csv.bak")
        #os.system("tail -n +3 sims2.csv >> sims2.csv.bak")
        
    #cur.execute("INSERT INTO _SIMS (team, n, rank, w, d, l, gf, ga, gd, pts) \
    #        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)", \
    #        (final['team'],final['n'],final['rank'],final['w'],final['d'],final['l'],final['gf'],final['ga'],final['gd'],final['pts']));
    conn.commit()
    conn.close()
    
