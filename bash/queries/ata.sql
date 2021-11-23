begin;

    select teamname, count(*)/count(distinct(matchid)) as touches from leagues.event where season=2019 and events @> '{pos}' group by teamname order by touches desc limit 20;
    select teamname, count(*)/count(distinct(matchid)) as half from leagues.event where season=2019 and events @> '{pos}' and x>50 group by teamname order by half desc limit 20;
    select teamname, count(*)/count(distinct(matchid)) as center from leagues.event where season=2019 and events @> '{pos}' and x>50 and y>25 and y<75 group by teamname order by center desc limit 20;
    select teamname, count(*)/count(distinct(matchid)) as side from leagues.event where season=2019 and events @> '{pos}' and x>50 and (y<25 or y>75) group by teamname order by side desc limit 20;
    select teamname, count(*) filter (where (y<25 or y>75))/count(*)::numeric as side from leagues.event where season=2019 and events @> '{pos}' and x>50 group by teamname order by side desc limit 20;

    select teamname, count(*)/count(distinct(matchid))::numeric as crossed from leagues.event where season=2019 and (events @> '{passCrossAccurate}' or events @> '{passCrossInaccurate}') and not events @> '{passCorner}'  and endx >= 83 and endy >= 21.1 and endy <= 78.9 group by teamname order by crossed desc limit 20;
    select teamname, count(*)/count(distinct(matchid))::numeric as notcrossed from leagues.event where season=2019 and not (events @> '{passCrossAccurate}' or events @> '{passCrossInaccurate}') and not events @> '{passCorner}' and endx >= 83 and endy >= 21.1 and endy <= 78.9 group by teamname order by notcrossed desc limit 20;
    select teamname, count(*)/count(distinct(matchid))::numeric as throughball from leagues.event where season=2019 and (events @> '{passThroughBallAccurate}' or events @> '{passThroughBallInaccurate}') and not events @> '{passCorner}' and endx >= 83 and endy >= 21.1 and endy <= 78.9 group by teamname order by throughball desc limit 20;

    select teamname, count(*)/count(distinct(matchid))::numeric as trequarti from leagues.event where season=2019 and (events @> '{passAccurate}') and endx >= 67 group by teamname order by trequarti desc limit 20;
    select teamname, count(*)/count(distinct(matchid))::numeric as area from leagues.event where season=2019 and (events @> '{passAccurate}') and endx >= 83 and endy >= 21.1 and endy <= 78.9 group by teamname order by area desc limit 20;


    select
    teamName as name,
    'Tiri totali open-play' as stats,
    round(sum(1) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}' )/count(distinct(matchId))::numeric,1) as per_match
    from leagues.event
    where   season=2019
    group by name
    order by per_match desc
    limit 20
    ;

    select
    teamName as name,
    'Tiri nello specchio op' as stats,
    round(sum(1) filter (where events @> '{shotPenaltyArea}' and (events @> '{shotOpenPlay}' or events @> '{shotCounter}' ))/count(distinct(matchId))::numeric,1) as per_match
    from leagues.event
    where   season=2019
    group by name
    order by per_match desc
    limit 20
    ;

    select
    teamName as name,
    'expg a partita op' as stats,
    round(sum(expgr) filter (where  events @> '{shotOpenPlay}' or events @> '{shotCounter}')/count(distinct(matchId))::numeric,3) as per_match
    from leagues.event
    where   season=2019
    group by name
    order by per_match desc
    limit 20
    ;

    select
    teamName as name,
    'expg per tiro op' as stats,
    round(sum(expgr) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}' )/count(*) filter (where events @> '{shotOpenPlay}' or events @> '{shotCounter}')::numeric,3) as per_match
    from leagues.event
    where   season=2019
    group by name
    order by per_match desc
    limit 20
    ;


commit;
