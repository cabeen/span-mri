#! /bin/bash

cd $(dirname $0)

cp table.wide.csv table.clean.csv; for bad in $(for f in fail/*; do echo $(basename ${f%_t2*} | sed); done | sed 's/_/,/g' | awk 'BEGIN{FS=","; OFS=","}{print $2,$1,$3}' | sed 's/ //g'); do cat table.clean.csv | grep -v ${bad} > tmp; mv tmp table.clean.csv; done
