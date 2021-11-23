begin;

    create temporary table temp_progress as table italyseriea.event;
    alter table temp_progress drop column id;
    alter table temp_progress add column id serial primary key;

    with t as (
        select
            matchid,
            teamid,
            teamname,
            second + expandedminute*60 as secs,
            x,
            x,
            cast(id as integer)
        from temp_progress
    ) 
    select
        matchid,
        teamid,
        teamname,
        min(x),
        max(x)
        from (
            select matchid, id, teamid, teamname, secs,
            row_number() over(order  by matchid,id)   -
            row_number() over(partition by teamid order by matchid,id) as grp
        from t
      ) tt
    group by matchid, id, teamid, teamname, secs, grp
    order by min(id)
;


commit;
