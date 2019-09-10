#!/bin/bash

my="/usr/bin/mysql -A -B -t -h $GROUPERDB "
datecmd='/usr/bin/date'
echo='/usr/bin/echo'
SQLsource=./MariaDB-10/gstat.sql
SQLsource2=./MariaDB-10/gstat.sql2
SQLfile=/tmp/gstat-$$.sql
q2file=/tmp/gstat-$$.q2
p1file=/tmp/gstat-$$.p1
hours=8

limit=40
sleep=7
interval=12
LoaderJobsPrefix='etc:LoaderJobs'

if [ "x$1" == "x-h" ]; then
	echo
        echo "    DelaySec(15 sec) DisplayLimit(50 rows) DisplayInterval(4 hours)"
	echo "    $0 10 40 2"
	echo
	exit
fi

if [ "x$1" != "x" ]; then
	sleep=$1
fi
if [ "x$2" != "x" ]; then
	limit=$2
fi

if [ "x$3" != "x" ]; then
	interval=$3
fi

(( max_iterations = ($hours * (60 * 60)) / ($sleep+2) ))

function finish {
	/bin/rm -f $SQLfile $p1file $q2file
	echo
	echo "ouch."
	exit
}
trap finish EXIT

sed -e "s/DisplayLimit/$limit/" -e "s/DisplayInterval/$interval/" \
	-e "s/LOADERJOBSPREFIX/$LoaderJobsPrefix/" < $SQLsource > $SQLfile

clear
echo "working ... sleep($sleep) limit($limit) interval($interval) iterations($max_iterations)"

while [ true ]; do
	(( max_iterations = max_iterations - 1 ))
	start=`$echo -n "\`$datecmd\`"`
	startsec=`$datecmd +%s`
	res=`echo "source $SQLfile" | $my `
	$my < $SQLsource2 > $q2file
	$my <<"HERE" > $p1file
select	Id,User,DB,Time,State,Info from information_schema.processlist
	where State = 'Executing' and user = 'grouper'
;
/*select	trigger_type as type, trigger_state as state,
	left(FROM_UNIXTIME(START_TIME/1000),19) as start_time,
	left(FROM_UNIXTIME(next_fire_TIME/1000),19) as next_time,
	CASE WHEN LENGTH(REGEXP_REPLACE(job_name, "^(.*)__(.*)__(.*)", '$2')) > 2 THEN
        REGEXP_REPLACE(job_name, "^(.*)__(.*)__(.*)", '$2') ELSE
        REGEXP_REPLACE(job_name, "^(.*)__(.*)__(.*)", '\\2') END as JOB
from grouper_QZ_TRIGGERS
	where trigger_state not in ('WAITING', 'ACQUIRED') -- and trigger_name='triggerChangeLog_grouperChangeLogTempToChangeLog'
;*/
HERE
	endsec=`$datecmd +%s`
	clear
	res2=`/usr/bin/pr --merge --join-lines --omit-header $q2file $p1file`
/bin/cat - <<HERE
$res
$res2
HERE
	execsec=$(($endsec-$startsec))
	echo "$start -`/usr/bin/uptime` / `/usr/bin/hostname` / DB=$GROUPERDB"
	echo -n "                               ${execsec}s for query - $limit rows / $interval hrs back                                   ( sleeping for ${sleep}s / $max_iterations ) "
	sleep $sleep
	echo -n "      working ...            "
	if [ $max_iterations -eq 0 ]; then
		exit
	fi
done
