#!/bin/bash

exedir="/usr/local/bin/"
RUN_ON_EV="$exedir/psql -w -d ev -U giacobba"
info="touch-map"

pi="Gianluigi Donnarumma"
pi="Alex Meret"

psql ev -c "copy(select * from italyseriea.event where playername like '$pi' and endx>50 and season='2018') to '/tmp/left.csv' csv header"
psql ev -c "copy(select * from italyseriea.event where playername like '$pi' and endx>50 and season='2019') to '/tmp/right.csv' csv header"

Rscript --vanilla R/heatmap.endx.R $pi
echo "[ $info ] working on player: $pi"
