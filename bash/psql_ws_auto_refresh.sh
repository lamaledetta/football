#!/bin/bash

if [[ "$OSTYPE" == "darwin"* ]]; then
    export DISPLAY=:1.5
    homedir="/Users/giacobba/git_repo"
    psql="/usr/local/bin/psql"
    Rscript="/usr/local/bin/Rscript"
    python="/usr/bin/python"
else
    export DISPLAY=:1
    homedir="/home/giacobba/my-analytics"
    psql="psql"
    Rscript="Rscript"
    python="/usr/bin/python"
fi

# REFRESH FIXTURES AND MATCHES
cd $homedir/ev-rev && ./bash/reset_psql.sh
sleep 10
cd $homedir/ev-rev && $python main.py refresh
sleep 10
cd $homedir/ev-rev && ./bash/team_pro_tableau.sh
sleep 10
cd $homedir/ev-rev && ./bash/player_pro_tableau.sh
sleep 10
cd $homedir/ev-rev && ./bash/gspread.sh
sleep 10

touch /tmp/crondone
