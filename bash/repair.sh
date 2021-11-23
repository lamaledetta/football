#!/bin/bash

#for stage in csv/*/; do
#    tournament=`sed -e 's#csv/\(.*\)/#\1#' <<< $stage` 
#    rm -f $stage/$tournament.csv
#
#done
#
#for stage in csv/*/*/; do
#    
#    season=`sed -e 's#.*/\(.*\)/$#\1#' <<< $stage` 
#    matches=`find "$stage" -name '[[:digit:]]*.csv*'`
#
#    for match in ${matches[@]}; do
#        
#        sed -i '' -e "s#T00:00:00,#T00:00:00,${season},#" $match
#        sed -i '' -e 's#startDate,#startDate,season,#' $match
#    done
#done

for stage in csv/*/*/; do
    matches=`find "$stage" -name '[[:digit:]]*.csve'`
    for match in ${matches[@]}; do
        
        sed -i '' -e 's#,satisfiedEventsTypes$#,events#' $match
    done

done
