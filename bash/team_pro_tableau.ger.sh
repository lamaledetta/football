#!/bin/bash

exedir="/usr/local/bin/"
RUN_ON_EV="$exedir/psql -w -d ev -U giacobba --quiet"
info="loader"

season=2019
mins=90

# SEASON PERIOD
month=$(date +%-m)
season=$(date +%Y)
if [[ $month -lt 8 ]]; then 
	season=$((season-1))
fi

mins=`$exedir/psql ev --tuples-only -A -c "select 4.5*count(distinct(matchId)) from germanybundesliga.event where season='$season'"`
mins=`echo ${mins%%.*}`
###cp -f $HOME/git_repo/ws-rev/bin/credentials.json bin

$RUN_ON_EV <<SQL

copy (
    (select
    teamName as name,
    'Recuperi palla offensivi' as stats,
    round(sum(1) filter (where events @> '{ballRecovery}' and x > 50)/count(distinct(matchId))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)

        union all

    (select
    'Media del campionato' as name,
    'Recuperi palla offensivi' as stats,
    round(sum(1) filter (where events @> '{ballRecovery}' and x > 50)/(2*count(distinct(matchId)))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'PPDA' as stats,
    round((select sum(1) from germanybundesliga.event e where (e.events @> '{passAccurate}' or e.events @> '{passInaccurate}') and e.season=germanybundesliga.event.season and e.opponentName=germanybundesliga.event.teamName and e.x < 60)/sum(1) filter (where (events @> '{tackleLost}' or events @> '{tackleWon}' or events @> '{interceptionAll}' or events @> '{foulCommitted}') and x > 40)::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name,season)

        union all

    (with asd as (select
        teamName as name,
        'PPDA' as stats,
        round((select sum(1) from germanybundesliga.event e where (e.events @> '{passAccurate}' or e.events @> '{passInaccurate}') and e.season=germanybundesliga.event.season and e.opponentName=germanybundesliga.event.teamName and e.x < 60)/sum(1) filter (where (events @> '{tackleLost}' or events @> '{tackleWon}' or events @> '{interceptionAll}' or events @> '{foulCommitted}') and x > 40)::numeric,1) as per_match
        from germanybundesliga.event
        where   season='$season'
        group by name,season)
    select
    'Media del campionato' as name,
    'PPDA' as stats,
    round(avg(per_match),1) as per_match
    from asd
    )

        union all

    (select
    teamName as name,
    'Passaggi completati nel terzo off.' as stats,
    round(sum(1) filter (where events @> '{passAccurate}' and x > 67)/count(distinct(matchId))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)

        union all

    (select
    'Media del campionato' as name,
    'Passaggi completati nel terzo off.' as stats,
    round(sum(1) filter (where events @> '{passAccurate}' and x > 67)/(2*count(distinct(matchId)))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Passaggi completati in area' as stats,
    round(sum(1) filter (where events @> '{passAccurate}' and x >= 83 and y >= 21.1 and y >= 78.9)/count(distinct(matchId))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)

	union all 

    (select
    'Media del campionato' as name,
    'Passaggi completati in area' as stats,
    round(sum(1) filter (where events @> '{passAccurate}' and x >= 83 and y >= 21.1 and y >= 78.9)/(2*count(distinct(matchId)))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

	union all 

    (select
    teamName as name,
    'xG prodotti in open-play' as stats,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,3) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)
	
	union all 

    (select
    'Media del campionato' as name,
    'xG prodotti in open-play' as stats,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,3) as per_match
    from germanybundesliga.event
    where   season='$season'
    )
	
	union all 

    (select
    teamName as name,
    'xG prodotti da piazzato' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/count(distinct(matchId))::numeric,3),0) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)

	union all 

    (select
    'Media del campionato' as name,
    'xG prodotti da piazzato' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/(2*count(distinct(matchId)))::numeric,3),0) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

	union all 

    (select
    opponentName as name,
    'xG concessi in open-play' as stats,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,3) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)
	
	union all 

    (select
    'Media del campionato' as name,
    'xG concessi in open-play' as stats,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,3) as per_match
    from germanybundesliga.event
    where   season='$season'
    )
	
	union all 
	
    (select
    opponentName as name,
    'xG concessi da piazzato' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/count(distinct(matchId))::numeric,3),0) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)

    	union all 
	
    (select
    'Media del campionato' as name,
    'xG concessi da piazzato' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/(2*count(distinct(matchId)))::numeric,3),0) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Tiri prodotti in open-play' as stats,
    round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)
	
	union all 

    (select
    'Media del campionato' as name,
    'Tiri prodotti in open-play' as stats,
    round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    )
	
	union all 

    (select
    teamName as name,
    '% Conversione gol/tiri prodotti' as stats,
    round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)

	union all 

    (select
    'Media del campionato' as name,
    '% Conversione gol/tiri prodotti' as stats,
    round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

	union all 
	
    (select
    opponentName as name,
    'Tiri concessi in open-play' as stats,
    round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)
	
	union all 

    (select
    'Media del campionato' as name,
    'Tiri concessi in open-play' as stats,
    round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

	union all 

    (select
    opponentName as name,
    '% Conversione gol/tiri concessi' as stats,
    round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    group by name)

	union all 

    (select
    'Media del campionato' as name,
    '% Conversione gol/tiri concessi' as stats,
    round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1) as per_match
    from germanybundesliga.event
    where   season='$season'
    )

--	
--	union all 
--	
--    (select
--    opponentName as name,
--    'Ranking difensivo per squadra' as stats,
--    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) as expected,
--    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as actual,
--    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) + coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as total
--    from germanybundesliga.event
--    where   season='$season'
--    group by name)
--	
--	union all 
--
--    (with asd as (select	
--    playerName as name,
--    'Top 15 per Expected Goals (p90)' as stats,
--    matchId,
--    round(sum(expg) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) as expected,
--    round(sum(expg) filter (where events @> '{shotSetPiece}'),3) as actual,
--    min(minsPlayed) as mins
--    from germanybundesliga.event
--    where   season='$season'
--    and     expg is not null
--    group by name, matchId)
--        select name, stage, round(90.0*sum(expected)/sum(mins), 3) as expected, coalesce(round(90.0*sum(actual)/sum(mins),3),0) as actual, round(90.0*sum(expected)/sum(mins), 3) + coalesce(round(90.0*sum(actual)/sum(mins),3),0) as total
--        from asd
--        where expected is not null
--        group by name,stage
--        having sum(mins) >= $mins
--        order by expected desc 
--        limit 15)
--
--        union all
--	
--    (with asd as (select	
--    playerName as name,
--    'Top 15 per Expected Assists (p90)' as stats,
--	matchId,
--    round(sum(expa) filter (where not events @> '{keyPassFreekick}' and not events @> '{keyPassCorner}' and not events @> '{keyPassThrowin}'),3) as expected,
--    round(sum(expa) filter (where events @> '{keyPassFreekick}' or events @> '{keyPassCorner}' or events @> '{keyPassThrowin}'),3) as actual,
--    min(minsPlayed) as mins
--    from germanybundesliga.event
--    where   season='$season'
--    and     expa is not null
--    group by name, matchId)
--        select name, stage, round(90.0*sum(expected)/sum(mins), 3) as expected, coalesce(round(90.0*sum(actual)/sum(mins),3),0) as actual, round(90.0*sum(expected)/sum(mins), 3) + coalesce(round(90.0*sum(actual)/sum(mins),3),0) as total
--        from asd
--        where expected is not null
--        group by name,stage
--        having sum(mins) >= $mins
--        order by expected desc 
--        limit 15)
	
) to '/tmp/uu_teams_tableau.csv' csv header delimiter ';' ;


SQL


###sed -e 's#\.#,#g' /tmp/uu_teams_tableau.csv > $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ita.csv
$RUN_ON_EV -f sql/progressive.ger.sql -v mins=$mins -v season=$season
cp /tmp/uu_teams_tableau.csv $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ger.csv
tail -n +2 /tmp/prog_per_team.csv >> $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ger.csv

#/usr/bin/python $HOME/git_repo/ev-rev/python/uu_tableau_teams.loader.py
