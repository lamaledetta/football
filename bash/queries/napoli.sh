#!/bin/bash

export exedir="/usr/local/bin/"
export RUN_ON_EV="$exedir/psql -w -d ev -U giacobba --quiet"
info="loader"

season=2019
mins=90

# SEASON PERIOD
month=$(date +%-m)
season=$(date +%Y)
if [[ $month -lt 7 ]]; then 
	season=$((season-1))
fi

mins=`$exedir/psql ev --tuples-only -A -c "select 4.5*count(distinct(matchId)) from italyseriea.event where season='$season'"`
mins=`echo ${mins%%.*}`
###cp -f $HOME/git_repo/ws-rev/bin/credentials.json bin

$RUN_ON_EV -f $HOME/git_repo/ev-rev/sql/progressive.sql -v mins=$mins -v season=$season

$RUN_ON_EV <<SQL

    (select
    teamName as name,
    'Recuperi palla offensivi' as stats,
    round(sum(1) filter (where events @> '{ballRecovery}' and x > 50)/count(distinct(matchId))::numeric,1) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name
    order by per_match desc)

;

    (select
    teamName as name,
    'PPDA' as stats,
    round((select sum(1) from italyseriea.event e where (e.events @> '{passAccurate}' or e.events @> '{passInaccurate}') and e.season=italyseriea.event.season and e.opponentName=italyseriea.event.teamName and e.x < 60)/sum(1) filter (where (events @> '{tackleLost}' or events @> '{tackleWon}' or events @> '{interceptionAll}' or events @> '{foulCommitted}') and x > 40)::numeric,1) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name,season
    order by per_match )

;

    (select
    teamName as name,
    'Passaggi completati nel terzo off.' as stats,
    round(sum(1) filter (where events @> '{passAccurate}' and endx > 67)/count(distinct(matchId))::numeric,1) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name
    order by per_match desc)

;

    (select
    teamName as name,
    'Passaggi completati dalla propria metà campo' as stats,
    round(sum(1) filter (where events @> '{passAccurate}' and x < 50)/count(distinct(matchId))::numeric,1) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name
    order by per_match desc)

;

    (select
    teamName as name,
    'xG prodotti in open-play' as stats,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,3) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name
    order by per_match desc)
	
;

    (select
    opponentName as name,
    'xG concessi in open-play' as stats,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,3) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name
    order by per_match )
	
;

    (select
    teamName as name,
    'Tiri prodotti in open-play' as stats,
    round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,1) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name
    order by per_match desc)
	
;

    (select
    opponentName as name,
    'Tiri concessi in open-play' as stats,
    round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,1) as per_match
    from italyseriea.event
    where   season='$season'
    and starttime::date <= '2019-12-11'
    group by name
    order by per_match )
	
;

SQL


###sed -e 's#\.#,#g' /tmp/uu_teams_tableau.csv > $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ita.csv
#$RUN_ON_EV -f sql/progressive.sql -v mins=$mins -v season=$season
#/usr/bin/tail -n +2 /tmp/prog_per_team.csv >> $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ita.csv

