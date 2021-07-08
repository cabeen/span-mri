#! /bin/bash

cd /ifs/loni/postdocs/rcabeen/studies/current/span/pilot

for s in $(cat lookup.txt); do mm=$(echo ${s} | cut -f 1 -d ,); ear=$(echo ${s} | cut -f 3 -d ,); for d in level1/*/${mm}; do mv $d $(dirname ${d})/${ear}; done done
