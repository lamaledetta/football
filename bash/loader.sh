#!/bin/bash

exedir="/opt/homebrew/bin"
RUN_ON_EV="$exedir/psql -w -d ev -U giacobba"
info="loader"
#START=$(date +%s);

# TOP LEAGUES ARRAY
my_array=("England-Championship")
my_array=("Belgium-Jupiler-Pro-League" "Netherlands-Eredivisie" "Portugal-Liga-NOS" "Russia-Premier-League")
my_array=("England-Championship" "Argentina-Liga-Profesional") 
my_array=("Italy-Serie-A" "England-Premier-League" "Spain-LaLiga" "Germany-Bundesliga" "France-Ligue-1")
my_array=("Italy-Serie-A" "England-Premier-League" "Spain-LaLiga" "Germany-Bundesliga" "France-Ligue-1" "Europe-Champions-League")

# SEASON PERIOD
month=$(date +%-m)
season=$(date +%Y)
if [[ $month -lt 8 ]]; then 
	season=$((season-1))
fi

if [ -z "$1" ]
  then
    echo "[ $info ] restarting sql server"
    $exedir/pg_ctl -D $exedir/postgres restart

    echo "[ $info ] reassessing whole db"
    echo "[ $info ] disconnecting ev users..."

$RUN_ON_EV <<SQL
    SELECT pg_terminate_backend(pg_stat_activity.pid)
    FROM pg_stat_activity
    WHERE pg_stat_activity.datname = 'ev'
      AND pid <> pg_backend_pid();
SQL

    sleep 1
    echo "[ $info ] deleting ev db..."
    $exedir/dropdb -w ev
    $exedir/createdb -w ev
    echo "[ $info ] ev db created empty"
    
    sudo rm -f /tmp/*.csve
    sudo find csv -name "*.csv" ! -name "seasons.csv" ! -name "fixtures.csv" ! -name "colors.csv" ! -name "*tournaments.csv" -exec rm -f {} \;
    
    for i in "${my_array[@]}"; do
        tournament=$i
        stage="csv/$tournament"
    #for stage in csv/*/; do
    #    tournament=`sed -e 's#csv/\(.*\)/#\1#' <<< $stage` 
    
        echo "[ $info ] working on stage: $tournament"

        matches=`find "$stage" -name '[[:digit:]]*.csve'`
    
        if [ -f "$stage/$tournament.csve" ]; then
            # can take old $tournament.csve
            #sudo rm /tmp/$tournament.csve
            cp $stage/$tournament.csve /tmp/$tournament.csve
            echo "[ $info ] found $tournament.csve file"
    
        else
            # need new $tournament.csve
            #sudo rm /tmp/$tournament.csve
            echo "[ $info ] generating new $tournament.csve"
            for match in ${matches[@]}; do
    
                #elab=`sed -e 's#\(.*\).csv#\1.csve#' <<< $match`
                elab=$match
                if [ ! -f "/tmp/$tournament.csve" ]; then
                    cat $elab > /tmp/$tournament.csve
                else
                    tail -n +2 $elab >> /tmp/$tournament.csve
                fi
            done
            #cp /tmp/$tournament.csve $stage/$tournament.csve 
            echo "[ $info ] done with stage: $tournament"
        fi
    
    
    done


    leagues_name="leagues"
    echo "[ $info ] create empty table $leagues_name.event"

$RUN_ON_EV <<SQL

    --CREATE EXTENSION IF NOT EXISTS UNACCENT;
    CREATE SCHEMA $leagues_name;
    SET SEARCH_PATH TO $leagues_name;
    CREATE TABLE event (

        matchId                 integer,
        startTime               date,
        tournamentName          text,
        season                  integer,
        status                  text,
        htScore                 text,
        etScore                 text,
        pkScore                 text,
        ftScore                 text,
        teamId                  integer,
        teamName                text,
        managerName             text,
        refereeName             text,
        field                   text,
        formation               text,
        matchPossession         numeric,
        avgPossession           numeric,
        opponentId              integer,
        opponentName            text,
        id                      text,
        eventId                 integer,
        playerId                integer,
        playerName              text,
        age                     integer,
        height                  integer,
        weight                  integer,
        position                text,
        isFirstEleven           boolean,
        minsPlayed              integer,
        rating                  numeric,
        relatedPlayerId         integer,
        relatedEventId          integer,
        OppositeRelatedEvent    integer,
        expandedMinute          integer,
        period                  integer,
        minute                  integer,
        second                  integer,
        x                       numeric,
        y                       numeric,
        endX                    numeric,
        endY                    numeric,
        goalMouthZ              numeric,
        goalMouthY              numeric,
        blockedX                numeric,
        blockedY                numeric,
        isTouch                 boolean,
        type                    text,
        outcomeType             text,
        events                  text[],
        expg                    numeric,
        expgr                   numeric,
        expa                    numeric,
        primary key (matchId,id,teamId)

    );
    
    CREATE INDEX i_event ON event(matchId);
    CREATE INDEX i_event_id ON event(Id);
    CREATE INDEX i_event_events ON event USING GIN (events);
  
SQL

    echo "[ $info ] populating db with top leagues data"

    for i in "${my_array[@]}"; do
        tournament=$i
        schema_name=`sed -e 's/-//g' <<< $tournament`

        echo "[ $info ] loading schema $schema_name into db"
        

$RUN_ON_EV <<SQL
    --CREATE EXTENSION IF NOT EXISTS UNACCENT;
    CREATE SCHEMA $schema_name;
    SET SEARCH_PATH TO $schema_name;

    CREATE TABLE $schema_name.event AS TABLE $leagues_name.event WITH NO DATA;
    DELETE FROM $schema_name.event;

    COPY $schema_name.event FROM '/tmp/$tournament.csve' CSV HEADER;

    CREATE INDEX i_event ON $schema_name.event(matchId);
    CREATE INDEX i_event_id ON $schema_name.event(Id);
    CREATE INDEX i_event_events ON $schema_name.event USING GIN (events);

    INSERT INTO $leagues_name.event SELECT * FROM event WHERE season=$season;
    
SQL

    done

    echo "[ $info ] vacuum all"
    $exedir/psql ev -c "VACUUM FULL"

else
    echo "[ $info ] loading $1 into db"

    tournament=$1
    schema_name=`sed -e 's/-//g' <<< $tournament`

    cp csv/$tournament/$tournament.csve /tmp/$tournament.csve

    echo "[ $info ] loading schema $schema_name into db"
        

$RUN_ON_EV <<SQL
    --CREATE EXTENSION IF NOT EXISTS UNACCENT;
    CREATE SCHEMA $schema_name;
    SET SEARCH_PATH TO $schema_name;
    CREATE TABLE event (

        matchId                 integer,
        startTime               date,
        tournamentName          text,
        season                  integer,
        status                  text,
        htScore                 text,
        etScore                 text,
        pkScore                 text,
        ftScore                 text,
        teamId                  integer,
        teamName                text,
        managerName             text,
        refereeName             text,
        field                   text,
        formation               text,
        matchPossession         numeric,
        avgPossession           numeric,
        opponentId              integer,
        opponentName            text,
        id                      text,
        eventId                 integer,
        playerId                integer,
        playerName              text,
        age                     integer,
        height                  integer,
        weight                  integer,
        position                text,
        isFirstEleven           boolean,
        minsPlayed              integer,
        rating                  numeric,
        relatedPlayerId         integer,
        relatedEventId          integer,
        OppositeRelatedEvent    integer,
        expandedMinute          integer,
        period                  integer,
        minute                  integer,
        second                  integer,
        x                       numeric,
        y                       numeric,
        endX                    numeric,
        endY                    numeric,
        goalMouthZ              numeric,
        goalMouthY              numeric,
        blockedX                numeric,
        blockedY                numeric,
        isTouch                 boolean,
        type                    text,
        outcomeType             text,
        events                  text[],
        expg                    numeric,
        expgr                   numeric,
        expa                    numeric,
        primary key (matchId,id,teamId)

    );
    COPY event FROM '/tmp/$tournament.csve' CSV HEADER;
    CREATE INDEX i_event ON event(matchId);
    CREATE INDEX i_event_id ON event(Id);
    CREATE INDEX i_event_events ON event USING GIN (events);
    
SQL

fi

#echo $((END-START)) | awk '{print "[ loader ] elapsed time: "int($1/60)" mins and "int($1%60)" secs"}'
