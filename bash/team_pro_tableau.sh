#!/bin/bash

export exedir="/opt/homebrew/bin"
export RUN_ON_EV="$exedir/psql -w -d ev -U giacobba --quiet"
info="loader"

season=2020
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

$RUN_ON_EV -f $HOME/git_repo/ev-rev/sql/progressive.sql -v mins=$mins -v season=$season

$RUN_ON_EV <<SQL

copy (

    (select
    teamName as name,
    'Percentuale duelli vinti' as stats,
    coalesce(round(100*(sum(1) filter (where events @> '{aerialWon}' or events @> '{tackleWon}' or events @> '{dribbleWon}'))/(sum(1) filter (where events @> '{aerialWon}' or events @> '{tackleWon}' or events @> '{dribbleWon}' or events @> '{aerialLost}' or events @> '{dribbleLost}' or events @> '{challengeLost}'))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)
	
	union all 

    (select
    'Media del campionato' as name,
    'Percentuale duelli vinti' as stats,
    coalesce(round(100*(sum(1) filter (where events @> '{aerialWon}' or events @> '{tackleWon}' or events @> '{dribbleWon}'))/(sum(1) filter (where events @> '{aerialWon}' or events @> '{tackleWon}' or events @> '{dribbleWon}' or events @> '{aerialLost}' or events @> '{dribbleLost}' or events @> '{challengeLost}'))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Baricentro medio' as stats,
    coalesce(round(avg(x) filter (where events @> '{touches}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)
	
	union all 

    (select
    'Media del campionato' as name,
    'Baricentro medio' as stats,
    coalesce(round(avg(x) filter (where events @> '{touches}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Altezza media degli interventi difensivi' as stats,
    coalesce(round(avg(x) filter (where type='Tackle' or type='Interception' or type='Clearance' or type='BlockedPass' or events @> '{defensiveDuel}' or events @> '{foulCommitted}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)
	
	union all 

    (select
    'Media del campionato' as name,
    'Altezza media degli interventi difensivi' as stats,
    coalesce(round(avg(x) filter (where type='Tackle' or type='Interception' or type='Clearance' or type='BlockedPass' or events @> '{defensiveDuel}' or events @> '{foulCommitted}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    opponentName as name,
    'xG per tiro concesso' as stats,
    coalesce(round(sum(expgr)/count(*) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}' or events @> '{shotSetPiece}')::numeric,3),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match )

	union all 

    (select
    teamName as name,
    'xG per tiro prodotto' as stats,
    coalesce(round(sum(expgr)/count(*) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}' or events @> '{shotSetPiece}')::numeric,3),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

        union all

    (select
    teamName as name,
    'Recuperi palla offensivi' as stats,
    coalesce(round(sum(1) filter (where events @> '{ballRecovery}' and x > 50)/count(distinct(matchId))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

        union all

    (select
    'Media del campionato' as name,
    'Recuperi palla offensivi' as stats,
    coalesce(round(sum(1) filter (where events @> '{ballRecovery}' and x > 50)/(2*count(distinct(matchId)))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'PPDA' as stats,
    coalesce(round((select sum(1) from italyseriea.event e where (e.events @> '{passAccurate}' or e.events @> '{passInaccurate}') and e.season=italyseriea.event.season and e.opponentName=italyseriea.event.teamName and e.x < 60)/sum(1) filter (where (events @> '{tackleLost}' or events @> '{tackleWon}' or events @> '{interceptionAll}' or events @> '{foulCommitted}') and x > 40)::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name,season order by per_match )

        union all

    (with asd as (select
        teamName as name,
        'PPDA' as stats,
        coalesce(round((select sum(1) from italyseriea.event e where (e.events @> '{passAccurate}' or e.events @> '{passInaccurate}') and e.season=italyseriea.event.season and e.opponentName=italyseriea.event.teamName and e.x < 60)/sum(1) filter (where (events @> '{tackleLost}' or events @> '{tackleWon}' or events @> '{interceptionAll}' or events @> '{foulCommitted}') and x > 40)::numeric,1),0.0) as per_match
        from italyseriea.event
        where   season='$season'
        group by name,season order by per_match )
    select
    'Media del campionato' as name,
    'PPDA' as stats,
    coalesce(round(avg(per_match),1),0.0) as per_match
    from asd
    )

        union all

    (select
    teamName as name,
    'Passaggi completati nel terzo off.' as stats,
    coalesce(round(sum(1) filter (where events @> '{passAccurate}' and endx > 67)/count(distinct(matchId))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

        union all

    (select
    'Media del campionato' as name,
    'Passaggi completati nel terzo off.' as stats,
    coalesce(round(sum(1) filter (where events @> '{passAccurate}' and endx > 67)/(2*count(distinct(matchId)))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Dominio territoriale' as stats,
    coalesce(round(100*sum(1) filter (where events @> '{passAccurate}' and x > 50)/sum(1) filter (where events @> '{passAccurate}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

        union all

    (select
    'Media del campionato' as name,
    'Dominio territoriale' as stats,
    coalesce(round(100*sum(1) filter (where events @> '{passAccurate}' and x > 50)/sum(1) filter (where events @> '{passAccurate}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Passaggi completati in area' as stats,
    coalesce(round(sum(1) filter (where events @> '{passAccurate}' and endx >= 83 and endy >= 21.1 and endy <= 78.9)/count(distinct(matchId))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

	union all 

    (select
    'Media del campionato' as name,
    'Passaggi completati in area' as stats,
    coalesce(round(sum(1) filter (where events @> '{passAccurate}' and endx >= 83 and endy >= 21.1 and endy <= 78.9)/(2*count(distinct(matchId)))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

	union all 

    (select
    opponentName as name,
    'Passaggi concessi in area' as stats,
    coalesce(round(sum(1) filter (where events @> '{passAccurate}' and endx >= 83 and endy >= 21.1 and endy <= 78.9)/count(distinct(matchId))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

	union all 

    (select
    'Media del campionato' as name,
    'Passaggi concessi in area' as stats,
    coalesce(round(sum(1) filter (where events @> '{passAccurate}' and endx >= 83 and endy >= 21.1 and endy <= 78.9)/(2*count(distinct(matchId)))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

	union all 

    (select
    teamName as name,
    'xG prodotti in open-play' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,3),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)
	
	union all 

    (select
    'Media del campionato' as name,
    'xG prodotti in open-play' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,3),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )
	
	union all 

    (select
    teamName as name,
    'xG prodotti da piazzato' as stats,
    coalesce(coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/count(distinct(matchId))::numeric,3),0),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

	union all 

    (select
    'Media del campionato' as name,
    'xG prodotti da piazzato' as stats,
    coalesce(coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/(2*count(distinct(matchId)))::numeric,3),0),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

	union all 

    (select
    opponentName as name,
    'xG concessi in open-play' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,3),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match )
	
	union all 

    (select
    'Media del campionato' as name,
    'xG concessi in open-play' as stats,
    coalesce(round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,3),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )
	
	union all 
	
    (select
    opponentName as name,
    'xG concessi da piazzato' as stats,
    coalesce(coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/count(distinct(matchId))::numeric,3),0),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match )

    	union all 
	
    (select
    'Media del campionato' as name,
    'xG concessi da piazzato' as stats,
    coalesce(coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}')/(2*count(distinct(matchId)))::numeric,3),0),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Tiri prodotti in open-play' as stats,
    coalesce(round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)
	
	union all 

    (select
    'Media del campionato' as name,
    'Tiri prodotti in open-play' as stats,
    coalesce(round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

        union all

    (select
    teamName as name,
    'Tiri prodotti nello specchio in op' as stats,
    coalesce(round(sum(1) filter (where events @> '{shotOnTarget}' and (events @> '{shotOpenPlay}' or events @> '{shotCounter}' or events @> '{shotSetPiece}'))/count(distinct(matchId))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)
	
	union all 

    (select
    'Media del campionato' as name,
    'Tiri prodotti nello specchio in op' as stats,
    coalesce(round(sum(1) filter (where events @> '{shotOnTarget}' and (events @> '{shotOpenPlay}' or events @> '{shotCounter}' or events @> '{shotSetPiece}'))/(2*count(distinct(matchId)))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

	union all 

    (select
    teamName as name,
    '% Conversione gol/tiri prodotti in op' as stats,
    coalesce(round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match desc)

	union all 

    (select
    'Media del campionato' as name,
    '% Conversione gol/tiri prodotti in op' as stats,
    coalesce(round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

	union all 
	
    (select
    opponentName as name,
    'Tiri concessi in open-play' as stats,
    coalesce(round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match )
	
	union all 

    (select
    'Media del campionato' as name,
    'Tiri concessi in open-play' as stats,
    coalesce(round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')/(2*count(distinct(matchId)))::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

	union all 

    (select
    opponentName as name,
    '% Conversione gol/tiri concessi' as stats,
    coalesce(round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    group by name order by per_match )

	union all 

    (select
    'Media del campionato' as name,
    '% Conversione gol/tiri concessi' as stats,
    coalesce(round(100*sum(1) filter (where events @> '{goalOpenPlay}' or events @> '{goalCounter}')/sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,1),0.0) as per_match
    from italyseriea.event
    where   season='$season'
    )

	union all 

    (select 
    name, 
    stats, 
    per_match
    from progression
    where top='team')
	
) to '/tmp/uu_teams_tableau.csv' csv header delimiter ';' ;


SQL


#sed -e 's#\.#,#g' /tmp/uu_teams_tableau.csv > $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ita.csv
#$RUN_ON_EV -f sql/progressive.sql -v mins=$mins -v season=$season
cp /tmp/uu_teams_tableau.csv $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ita.csv
#/usr/bin/tail -n +2 /tmp/prog_per_team.csv >> $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_teams_ita.csv

$exedir/python3 $HOME/git_repo/ev-rev/python/uu_tableau_teams.loader.py
