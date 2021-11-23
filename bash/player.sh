#!/bin/bash

exedir="/usr/local/bin/"
RUN_ON_EV="$exedir/psql -w -d ev -U giacobba"
info="player"

#START=$(date +%s);

for stage in csv/*/; do

    tournament=`sed -e 's#csv/\(.*\)/#\1#' <<< $stage` 
    echo "[ $info ] working on stage: $tournament"

    schema_name=`sed -e 's/-//g' <<< $tournament`

$RUN_ON_EV <<SQL

    SET SEARCH_PATH TO $schema_name;
    DROP TABLE IF EXISTS player;

    CREATE TABLE IF NOT EXISTS player (

        id              integer,
        name            text,
        team_id         integer,
        team_name       text,
        stage_name      text,
        season          integer,
        age             integer,
        height          numeric,
        weight          numeric,
        position        text,
        first_eleven    integer,
        from_bench      integer,
        mins_played     integer,
	primary key (id, team_id, season)
    );


    INSERT INTO player (
        id              ,
        name            ,
        team_id         ,
        team_name       ,
        stage_name      ,
        season          ,
        height          ,
        weight  
    ) (
    SELECT
        distinct(playerid),
        playername,
        teamid,
        teamname,
        '$tournament',
        season,
        height,
        weight

        FROM event
        WHERE playerid is not null and playerid!=0
    ) ON CONFLICT DO NOTHING;

SQL

done

