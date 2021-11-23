begin;
    create temporary table tempfor (
        name text,
        teamname text,
        matchid integer,
        min integer,
        max integer,
        minsplayed integer,
        delta numeric
    );

    insert into tempfor (
        name, teamname, matchid, min, max, minsplayed, delta
    ) (
    with asd as (
    select 
    playername, 
    teamname,
    teamid,
    matchid, 
    min(minsplayed) as minsplayed,
    case when position='Sub' then min(minute) else 0 end as mins,
    case when position='Sub' then min(minute)+min(minsplayed) else min(minsplayed) end as maxs
    from italyseriea.event
    where
    season=:'season'
    group by playername, teamname, teamid, matchid, position
    )
    (
    select a.playername, a.teamname, a.matchid, a.mins, a.maxs, a.minsplayed, sum(e.expg)
    from asd a, italyseriea.event e 
    where
    e.season=:'season' and
    e.matchid=a.matchid and
    e.teamid=a.teamid and
    e.minute >= a.mins and e.minute <= a.maxs
    --and e.starttime > '2020-05-01'
    group by a.playername, a.teamname, a.matchid, a.mins, a.maxs, a.minsplayed
    )
    );



    create temporary table tempaga (
        name text,
        teamname text,
        matchid integer,
        min integer,
        max integer,
        minsplayed integer,
        delta numeric
    );

    insert into tempaga (
        name, teamname, matchid, min, max, minsplayed, delta
    ) (
    with asd as (
    select 
    playername, 
    teamname,
    teamid,
    matchid, 
    min(minsplayed) as minsplayed,
    case when position='Sub' then min(minute) else 0 end as mins,
    case when position='Sub' then min(minute)+min(minsplayed) else min(minsplayed) end as maxs
    from italyseriea.event
    where
    season=:'season'
    group by playername, teamname, teamid, matchid, position
    )
    (
    select a.playername, a.teamname, a.matchid, a.mins, a.maxs, a.minsplayed, sum(e.expg) 
    from asd a, italyseriea.event e 
    where
    e.season=:'season' and
    e.matchid=a.matchid and
    e.opponentid=a.teamid and
    e.minute >= a.mins and e.minute <= a.maxs
    --and e.starttime > '2020-05-01'
    group by a.playername, a.teamname, a.matchid, a.mins, a.maxs, a.minsplayed
    )
    );



    drop table if exists plx;

    create table plx (
        name text,
        teamname text,
        expg_for numeric,
        expg_aga numeric,
        delta numeric,
        mins  numeric,
        primary key (name, teamname)
    );

    insert into plx (
        name, teamname, expg_for, expg_aga, delta, mins
    ) (
        select
        f.name,
        f.teamname,
        sum(f.delta),
        (select sum(a.delta) from tempaga a where a.name=f.name),
        sum(f.delta)-(select sum(a.delta) from tempaga a where a.name=f.name),
        sum(f.minsplayed)
        from tempfor f
        group by f.name, f.teamname
        order by f.name 
    );

    --select name as name, teamname, 'xG plus/minus' as stats, round(90*expg_for/mins-90*expg_aga/mins,2) as per_match from plx where mins>:'mins' order by per_match desc ;
    copy(
        select name as name, 'xG plus/minus' as stats, round(90*expg_for/mins-90*expg_aga/mins,2) as per_match from plx where mins>:'mins' order by per_match desc limit 30)
    to '/tmp/plus_minus_player.csv' csv header delimiter ';';

commit;
