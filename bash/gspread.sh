#!/bin/bash

exedir="/opt/homebrew/bin/"
RUN_ON_EV="$exedir/psql -w -d ev -U giacobba"
info="loader"

season=2019
mins=90

# SEASON PERIOD
month=$(date +%-m)
season=$(date +%Y)
if [[ $month -lt 8 ]]; then 
	season=$((season-1))
fi

mins=`$exedir/psql ev --tuples-only -A -c "select 4.5*count(distinct(matchId)) from italyseriea.event where season='$season'"`
mins=`echo ${mins%%.*}`

cp -f $HOME/git_repo/ws-rev/bin/credentials.json json

$RUN_ON_EV <<SQL

copy (
    (select
    teamName as name,
    'Ranking offensivo per squadra' as stage,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) as expected,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as actual,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) + coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as total
    from italyseriea.event
    where   season='$season'
    group by name)
	
	union all 
	
    (select
    opponentName as name,
    'Ranking difensivo per squadra' as stage,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) as expected,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as actual,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) + coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as total
    from italyseriea.event
    where   season='$season'
    group by name)
	
	union all 

    (with asd as (select	
    playerName as name,
    'Top 15 per Expected Goals (p90)' as stage,
    matchId,
    coalesce(round(sum(expg) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3),0) as expected,
    coalesce(round(sum(expg) filter (where events @> '{shotSetPiece}'),3),0) as actual,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stage, round(90.0*sum(expected)/sum(mins), 3) as expected, coalesce(round(90.0*sum(actual)/sum(mins),3),0) as actual, round(90.0*sum(expected)/sum(mins), 3) + coalesce(round(90.0*sum(actual)/sum(mins),3),0) as total
        from asd
        where expected is not null
        group by name,stage
        having sum(mins) >= $mins
        order by total desc 
        limit 15)

        union all
	
    (with asd as (select	
    playerName as name,
    'Top 15 per Expected Assists (p90)' as stage,
	matchId,
    coalesce(round(sum(expa) filter (where not events @> '{keyPassFreekick}' and not events @> '{keyPassCorner}' and not events @> '{keyPassThrowin}'),3),0) as expected,
    coalesce(round(sum(expa) filter (where events @> '{keyPassFreekick}' or events @> '{keyPassCorner}' or events @> '{keyPassThrowin}'),3),0) as actual,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expa is not null
    group by name, matchId)
        select name, stage, round(90.0*sum(expected)/sum(mins), 3) as expected, coalesce(round(90.0*sum(actual)/sum(mins),3),0) as actual, round(90.0*sum(expected)/sum(mins), 3) + coalesce(round(90.0*sum(actual)/sum(mins),3),0) as total
        from asd
        where expected is not null
        group by name,stage
        having sum(mins) >= $mins
        order by total desc 
        limit 15)
	
) to '/tmp/uu_tableau.csv' csv header delimiter ';' ;


SQL


#sed -e 's#\.#,#g' /tmp/uu_tableau.csv > $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_all_ita.csv
cp /tmp/uu_tableau.csv $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_all_ita.csv
$exedir/python3 $HOME/git_repo/ev-rev/python/uu_tableau.loader.py
