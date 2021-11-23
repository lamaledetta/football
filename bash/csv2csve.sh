#!/bin/bash

stage="csv"
csv=`find "$stage" -name '[[:digit:]]*.csv'`
csve=`find "$stage" -name '[[:digit:]]*.csve'`

        for match in ${csv[@]}; do
            elab=`sed -e 's#\(.*\).csv#\1.csve#' <<< $match`
            if [ ! -f "$elab" ]; then
                /usr/bin/python python/csv2csve.py $match
            fi
        done

