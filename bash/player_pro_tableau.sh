#!/bin/bash

export exedir="/opt/homebrew/bin/"
export RUN_ON_EV="$exedir/psql -w -d ev -U giacobba --quiet"
info="loader"

season=2019
mins=90

# SEASON PERIOD
month=$(date +%-m)
season=$(date +%Y)
if [[ $month -lt 9 ]]; then 
	season=$((season-1))
fi

mins=`$exedir/psql ev --tuples-only -A -c "select 4.5*count(distinct(matchId)) from italyseriea.event where season='$season'"`
mins=`echo ${mins%%.*}`
cp -f $HOME/git_repo/ws-rev/bin/credentials.json json

$RUN_ON_EV -f $HOME/git_repo/ev-rev/sql/progressive.sql -v mins=$mins -v season=$season
$RUN_ON_EV -f $HOME/git_repo/ev-rev/sql/plus_minus.sql -v mins=$mins -v season=$season

$RUN_ON_EV <<SQL

copy (
    (with asd as (select	
    playerName as name,
    'Open-play Expected Goals' as stats,
    matchId,
    coalesce(round(sum(expg) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3),0) as expected,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins), 3) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all
        
    (with asd as (select	
    playerName as name,
    'Set-pieces Expected Goals' as stats,
    matchId,
    coalesce(round(sum(expg) filter (where events @> '{shotSetPiece}'),3),0) as expected,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins), 3) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all

    (with asd as (select	
    playerName as name,
    'Open-play non-penalty goals' as stats,
    matchId,
    coalesce(round(sum(1) filter (where events @> '{goalNormal}' and (events @> '{shotOpenPlay}' or events @> '{shotCounter}')),3),0) as expected,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins), 3) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all
        
    (with asd as (select	
    playerName as name,
    'Set-pieces non-penalty goals' as stats,
    matchId,
    coalesce(round(sum(1) filter (where events @> '{goalNormal}' and events @> '{shotSetPiece}'),3),0) as expected,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins), 3) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins 
        order by p90 desc 
        limit 30)

        union all

    (with asd as (select	
    playerName as name,
    'Open-play Expected Assist' as stats,
    matchId,
    coalesce(round(sum(expa) filter (where not events @> '{keyPassFreekick}' and not events @> '{keyPassCorner}' and not events @> '{keyPassThrowin}'),3),0) as expected,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins), 3) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all
        
    (with asd as (select	
    playerName as name,
    'Set-pieces Expected Assist' as stats,
    matchId,
    coalesce(round(sum(expa) filter (where events @> '{keyPassFreekick}' or events @> '{keyPassCorner}' or events @> '{keyPassThrowin}'),3),0) as expected,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins), 3) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all

    (with asd as (select	
    playerName as name,
    'Passaggi riusciti in area in open-play' as stats,
    matchId,
    coalesce(round(count(*) filter (where events @> '{passAccurate}' and endx >= 83 and endy >= 21.1 and endy <= 78.9 and not events @> '{passFreekick}' and not events @> '{passCorner}' and not events @> '{passThrowin}'),3),0) as expected,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins), 1) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all
        
    (with asd as (select	
    playerName as name,
    'Recuperi palla offensivi (aggiustati per possesso)' as stats,
    matchId,
    coalesce(round(sum(1) filter (where events @> '{ballRecovery}'),3),0) as expected,
    min(matchPossession) as poss,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
    and     x>50
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected * 2/(1 + exp(-0.1*(poss-50))))/sum(mins),1) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all
        
    (with asd as (select	
    playerName as name,
    'Tackle riusciti (aggiustati per possesso)' as stats,
    matchId,
    coalesce(round(sum(1) filter (where events @> '{tackleWon}'),3),0) as expected,
    min(matchPossession) as poss,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected * 2/(1 + exp(-0.1*(poss-50))))/sum(mins),1) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all
        
    (with asd as (select	
    playerName as name,
    'Intercetti riusciti (aggiustati per possesso)' as stats,
    matchId,
    coalesce(round(sum(1) filter (where events @> '{interceptionWon}'),3),0) as expected,
    min(matchPossession) as poss,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected * 2/(1 + exp(-0.1*(poss-50))))/sum(mins),1) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all
        
    (with asd as (select	
    playerName as name,
    'Dribbling riusciti' as stats,
    matchId,
    coalesce(round(sum(1) filter (where events @> '{dribbleWon}'),3),0) as expected,
    min(matchPossession) as poss,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season='$season'
--    and     expg is not null
    group by name, matchId)
        select name, stats, round(90.0*sum(expected)/sum(mins),1) as p90
        from asd
        where expected is not null
        group by name,stats
        having sum(mins) >= $mins
        order by p90 desc 
        limit 30)

        union all

    (select 
    name as name, 
    'xG plus/minus' as stats, 
    round(90*expg_for/mins-90*expg_aga/mins,2) as per_match 
    from plx 
    where mins>'$mins' 
    order by per_match desc 
    limit 30)

        union all
        
    (select 
    name, 
    stats, 
    per_match as p90
    from progression
    where top='player')

) to '/tmp/uu_players_tableau.csv' csv header delimiter ';' ;

SQL

#sed -e 's#\.#,#g' /tmp/uu_players_tableau.csv > $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_players_ita.csv
#$RUN_ON_EV -f sql/progressive.sql -v mins=$mins -v season=$season
cp /tmp/uu_players_tableau.csv $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_players_ita.csv
#/usr/bin/tail -n +2 /tmp/prog_per_player.csv >> $HOME/Dropbox/My\ xG\ deliveries/pro-tableau/csv-factory/uu_players_ita.csv

$exedir/python3 $HOME/git_repo/ev-rev/python/uu_tableau_players.loader.py

