begin;

    --\! clear

    create temporary table progress (
        match_id    integer,
        player_id integer,
        player_name text,
        team_id integer,
        team_name text,
        min_run_x numeric,
        max_run_x numeric,
        min_pass_x numeric,
        max_pass_x numeric,
        mins    integer
    );


    ---
    ---
    --- CREATE TABLE FOR RUNS
    ---
    ---

    create temporary table temp_progress as table progress;

    insert into temp_progress (
        match_id, player_id, player_name, team_id, team_name, 
        min_run_x, max_run_x,
        min_pass_x, max_pass_x, mins
    ) (

        select 
            matchid, 
            playerid,
            playername, 
            teamid,
            teamname,
            x,
            x,
            0,
            0,
            minsplayed
            from germanybundesliga.event where season=:'season'
            and position!='GK'
            and x>40 
            order by matchid,expandedminute,second

    );


    alter table temp_progress add column id serial primary key;

    insert into progress (
        match_id, player_id, player_name, team_id, team_name, 
        min_run_x, max_run_x,
        min_pass_x, max_pass_x,mins
    ) (
    with t as (
        select 
            match_id,
            player_id,
            player_name,
            team_id,
            team_name,
            min_run_x,
            max_run_x,
            min_pass_x,
            max_pass_x,
            mins,
            cast(id as integer)
            from temp_progress 
        ) 
    select
        match_id,
        player_id,
        player_name,
        team_id,
        team_name,
        min(min_run_x),
        max(max_run_x),
        0,
        0,
        mins
        from (
            select match_id, id, player_id, player_name, team_id, team_name, min_run_x, max_run_x, mins,
            row_number() over(order  by match_id,id)   -
            row_number() over(partition by player_id order by match_id,id) as grp
        from t
      ) tt
      group by match_id, player_id, player_name, team_id, team_name, mins, grp
      order by min(id)
    );

    delete from progress where min_run_x=max_run_x;
    
    ---
    ---
    --- CREATE TABLE FOR PASSES
    ---
    ---
    
    insert into progress (
        match_id, player_id, player_name, team_id, team_name, 
        min_run_x, max_run_x,
        min_pass_x, max_pass_x,mins
    ) (
        select matchid, playerid, playername, teamid, teamname,
        0,
        0,
        x as min_start_x, endx as max_start_x,
        minsplayed
        from germanybundesliga.event where season=:'season' 
        and endx>x and events @> '{passAccurate}'
        and position!='GK' 
        and x>40
    );

    ---
    ---
    --- CREATE RANKS  
    ---
    ---

    --select * from progress where max_pass_x=min_pass_x;

    copy(
        (select team_name as name, 'Progressive passes' as stats, round(sum(max_pass_x - min_pass_x)/count(distinct(match_id)),1) as per_match from progress group by team_name order by team_name)
        union all
        (with asd as (select team_name as name, 'Progressive passes' as stats, sum(max_pass_x - min_pass_x)/count(distinct(match_id)) as per_match from progress group by team_name order by team_name)
            select 'Media del campionato' as name, 'Progressive passes' as stats, round(avg(per_match),1) as per_match from asd)
        union all
        (select team_name as name, 'Progressive runs' as stats, round(sum(max_run_x - min_run_x)/count(distinct(match_id)),1) as per_match from progress group by team_name order by team_name)
        union all
        (with asd as (select team_name as name, 'Progressive runs' as stats, sum(max_run_x - min_run_x)/count(distinct(match_id)) as per_match from progress group by team_name order by team_name)
            select 'Media del campionato' as name, 'Progressive runs' as stats, round(avg(per_match),1) as per_match from asd)
    ) to '/tmp/prog_per_team.csv' csv header delimiter ';';



    create temporary table ranks (
        player_id integer,
        player_name text,
        team_id integer,
        team_name text,
        runs numeric,
        passes numeric,
        total numeric
    );


    insert into ranks (
        player_id, player_name, team_id, team_name,
        runs, passes
    ) (
        with tt as (
            select match_id, player_id, player_name, team_id, team_name, sum(max_run_x - min_run_x) as deltax, min(mins) as mins from progress where max_pass_x=min_pass_x group by match_id,player_name,player_id,team_id,team_name
        )
        select player_id,player_name,team_id,team_name, round(90.0*sum(deltax)/sum(mins),1), 0 from tt group by player_id,player_name,team_id,team_name having sum(mins)>:'mins'
    );


    insert into ranks (
        player_id, player_name, team_id, team_name, 
        runs, passes
    ) (
        with tt as (
            select match_id, player_id, player_name, team_id, team_name, sum(max_pass_x - min_pass_x) as deltax, min(mins) as mins from progress where max_run_x=min_run_x group by match_id,player_name,player_id,team_id,team_name
        )
        select player_id,player_name,team_id,team_name, 0, round(90.0*sum(deltax)/sum(mins),1) from tt group by player_id,player_name,team_id,team_name having sum(mins)>:'mins'
    );

--    alter table ranks add column mins_played integer;
--    update ranks set mins_played=(select mins_played from player_rankings p where p.stage_id=:'stage_id' and p.id=ranks.player_id and p.team_id=ranks.team_id);
--
--    update ranks set total=90*run_x/mins_played where pass_x=0;
--    update ranks set total=90*pass_x/mins_played where run_x=0;

    --select player_name, team_name, sum(runs) as runs, sum(passes) as passes, sum(runs+passes) as total from ranks group by player_name,team_name order by total desc;

    copy(
        (select player_name as name, 'Progressive passes' as stats, sum(passes) as per_match from ranks group by player_name order by per_match desc limit 30)
        union all
        (select player_name as name, 'Progressive runs' as stats, sum(runs) as per_match from ranks group by player_name order by per_match desc limit 30)
        union all
        (select player_name as name, 'Progressive passes & runs' as stats, sum(passes+runs) as per_match from ranks group by player_name order by per_match desc limit 30)
    ) to '/tmp/prog_per_player.csv' csv header delimiter ';';

commit;
