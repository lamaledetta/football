BEGIN;

copy (
    (select
    teamName as name,
    'Ranking offensivo per squadra' as stage,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) as expected,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as actual,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) + coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as total
    from italyseriea.event
    where   season=:'season'
    group by name)
	
	union all 
	
    (select
    opponentName as name,
    'Ranking difensivo per squadra' as stage,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) as expected,
    coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as actual,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) + coalesce(round(sum(expgr) filter (where events @> '{shotSetPiece}'),3),0) as total
    from italyseriea.event
    where   season=:'season'
    group by name)
	
	union all 

    (with asd as (select	
    playerName as name,
    'Top 15 per Expected Goals (p90)' as stage,
    matchId,
    round(sum(expg) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}'),3) as expected,
    round(sum(expg) filter (where events @> '{shotSetPiece}'),3) as actual,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season=:'season'
    and     expg is not null
    group by name, matchId)
        select name, stage, round(90.0*sum(expected)/sum(mins), 3) as expected, coalesce(round(90.0*sum(actual)/sum(mins),3),0) as actual, round(90.0*sum(expected)/sum(mins), 3) + coalesce(round(90.0*sum(actual)/sum(mins),3),0) as total
        from asd
        where expected is not null
        group by name,stage
        having sum(mins) >= :'mins'
        order by expected desc 
        limit 15)

        union all
	
    (with asd as (select	
    playerName as name,
    'Top 15 per Expected Assists (p90)' as stage,
	matchId,
    round(sum(expa) filter (where not events @> '{keyPassFreekick}' and not events @> '{keyPassCorner}' and not events @> '{keyPassThrowin}'),3) as expected,
    round(sum(expa) filter (where events @> '{keyPassFreekick}' or events @> '{keyPassCorner}' or events @> '{keyPassThrowin}'),3) as actual,
    min(minsPlayed) as mins
    from italyseriea.event
    where   season=:'season'
    and     expa is not null
    group by name, matchId)
        select name, stage, round(90.0*sum(expected)/sum(mins), 3) as expected, coalesce(round(90.0*sum(actual)/sum(mins),3),0) as actual, round(90.0*sum(expected)/sum(mins), 3) + coalesce(round(90.0*sum(actual)/sum(mins),3),0) as total
        from asd
        where expected is not null
        group by name,stage
        having sum(mins) >= :'mins'
        order by expected desc 
        limit 15)
	
) to '/tmp/uu_tableau.csv' csv header delimiter ';' ;


COMMIT;
