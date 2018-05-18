#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Illegal number of parameters"
    echo "$0 user passwd"
fi

TMP=$(mktemp -d)
DT=$(date +"%Y%m%d-%H-%M")
BPATH="${TMP}/lab-db-${DT}.gz"
echo "Backing up database"
mysqldump -h lab-db.local -u $1 -p$2 --all-databases | gzip> "$BPATH"
aws s3 cp "$BPATH" s3://wp-db-bck/
rm -rf $TMP