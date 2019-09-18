select left(rtrim(Start),5+9+2) as "Start", left(rtrim(End),8) as "End", right(rtrim(Run),7) as "Run", left(rtrim(Job_Name),60) as "Job Name", 
	case when length(Tot) < 10 then lpad(format(Tot,0),10,' ') else format(Tot,0) end as "Total", 
	case when length(Ins) <  3 then lpad(format(Ins,0), 3,' ') else format(Ins,0) end as "Ins", 
	case when length(Upd) <  3 then lpad(format(Upd,0), 3,' ') else format(Upd,0) end as "Upd", 
	case when length(Del) <  3 then lpad(format(Del,0), 3,' ') else format(Del,0) end as "Del", 
	case when length(UN ) <  3 then lpad(format(UN ,0), 3,' ') else format(UN ,0) end as "UN", 
	left(Status,9) as "Status", left(Host,4) as "Host", 
	left(REGEXP_REPLACE(Job_Message,"^java.lang.RuntimeException: (.*)",'\\1'), 68) as "Message" From (
SELECT '9' as "Start",' ' as "End", ' ' as "Run",'ChangeLog Main (Last-Seq-# / Cnt)' as Job_Name, clc.x as "Tot",
        ' ' as "Ins", ' ' as "Upd",' ' as "Del",' ' as "UN",' ' as "Status",' ' as "Host",
        CONCAT('CNT( ',format(is_cle.table_rows,0),' ) LOG( ',format(is_log.table_rows,0),
		' ) MSG( ',format(is_msg.table_rows,0), ' - ', is_msg_age.age, ' )') as "Job_Message"
from 
(select table_rows from information_schema.tables  where table_name = 'grouper_change_log_entry') is_cle,
(select table_rows from information_schema.tables  where table_name = 'grouper_loader_log') is_log,
(select table_rows from information_schema.tables  where table_name = 'grouper_message') is_msg,
(select LPAD(TRIM(REGEXP_REPLACE( TIME_FORMAT(SEC_TO_TIME( TIMESTAMPDIFF(SECOND, IFNULL(from_unixtime(round(MIN(SENT_TIME_MICROS)/1000/1000)), NOW()), NOW()) ), '%k:%i:%s' ), '\\b0+:',' ')), 8,' ') as age
	from grouper_message ) is_msg_age,
(select max(last_sequence_processed) as x,name from grouper_change_log_consumer where hibernate_version_number > 0 ) clc
union all
SELECT DATE_FORMAT(now(), '8 %m/%d %H:%i:%s') AS "Start",' ' as "End", ' ' as "Run",'ChangeLog Temp (count)' as Job_Name, ' ' as "Tot", 
        is_clet.table_rows as "Ins", ' ' as "Upd",' ' as "Del",' ' as "UN", ' ' as "Status", ' ' as "Host",' ' as "Job_Message" 
from (select table_rows from information_schema.tables  where table_name = 'grouper_change_log_entry_temp') as is_clet
union all
SELECT 
    DATE_FORMAT(STARTED_TIME, '  %m/%d %H:%i:%s') AS "Start",
    CASE WHEN ENDED_TIME IS NULL THEN ' ' ELSE DATE_FORMAT(ENDED_TIME, '%H:%i:%s') END AS "End",
	LPAD(TRIM(REGEXP_REPLACE(
		CASE WHEN MILLIS IS NULL AND STATUS IN ('STARTED','RUNNING')
		THEN TIME_FORMAT(SEC_TO_TIME(TIMESTAMPDIFF(SECOND,STARTED_TIME,NOW())), '%k:%i:%s' )
		ELSE TIME_FORMAT(SEC_TO_TIME(MILLIS/1000), '%k:%i:%s' ) END,
		'\\b0+:',' ')),9,' ') AS "Run",
    REPLACE(REPLACE(REPLACE(CASE WHEN LENGTH(REGEXP_REPLACE(job_name, "^(.*)__(.*)__(.*)", '$2')) > 2 THEN
    	REGEXP_REPLACE(job_name, "^(.*)__(.*)__(.*)", '$2') ELSE
    	REGEXP_REPLACE(job_name, "^(.*)__(.*)__(.*)", '\\2') END
    	,
    	'CHANGE_LOG_',''), 'subjobFor_','  '), 'LOADERJOBSPREFIX', '') as job_name, /* needs mysql 8+, mariadb v10+ or OracleDB */
    TOTAL_COUNT AS "Tot", INSERT_COUNT AS "Ins", UPDATE_COUNT AS "Upd", DELETE_COUNT AS "Del", UNRESOLVABLE_SUBJECT_COUNT AS "UN",
    IFNULL (CASE WHEN 1 = 0 THEN 'x'
    	WHEN STATUS = 'SUCCESS' THEN CONCAT(JOB_SCHEDULE_PRIORITY,' ok')
    	WHEN STATUS in ('STARTED') THEN CONCAT(JOB_SCHEDULE_PRIORITY, ' ', STATUS)
    	WHEN JOB_SCHEDULE_PRIORITY is NULL THEN CONCAT('- ',STATUS,' - ',JOB_TYPE)
    	ELSE CONCAT(JOB_SCHEDULE_PRIORITY,' ',STATUS,' - ',JOB_TYPE) END, ' - ') AS "Status",
 	HOST as "Host",  /* important if you have >1 host running loader jobs - is container id in Docker */
    CASE WHEN JOB_MESSAGE IS NULL THEN ' ' ELSE 
	 rtrim(REGEXP_REPLACE(JOB_MESSAGE,'^(.+) processed (.+) records,(.+), (.+) of (.+) sub(.+)', 'processing \\2, \\4  /  \\5')) END AS "Job_Message"
FROM grouper_loader_log
WHERE (started_time >= now() - INTERVAL DisplayInterval Hour ) and
		( (JOB_TYPE in ( 'CHANGE_LOG', 'OTHER_JOB')
	        AND ( STATUS != 'SUCCESS' /* AND STATUS != 'ERROR' */
	        		AND ((job_name like '%_consumer_%' or job_name like '%_incremental%') AND total_count != 0 )
        		)
        	OR ( MILLIS/1000 > 60*10 and JOB_NAME not like 'subjobFor_%')
    		)
		OR (JOB_TYPE NOT IN ('CHANGE_LOG', 'MAINTENANCE', 'OTHER_JOB')
			AND (JOB_NAME NOT LIKE 'subjobFor_%'
					AND (INSERT_COUNT != 0 OR UPDATE_COUNT != 0 OR DELETE_COUNT != 0 OR UNRESOLVABLE_SUBJECT_COUNT != 0)
				)
			)
    	OR (job_name not like '%_consumer_%' AND STATUS NOT IN ('SUCCESS','WARNING') /* AND TOTAL_COUNT !=0) */
    	OR (JOB_TYPE = 'OTHER_JOB' and TOTAL_COUNT != 0 and ENDED_TIME = NULL)
    	OR (job_name like '%Report' and ENDED_TIME = NULL)
        OR (job_name = 'CHANGE_LOG_changeLogTempToChangeLog' and STATUS != 'SUCCESS')
        OR ( 
        	JOB_NAME not like 'subjobFor_%' AND TOTAL_COUNT != 0 AND /* comment this line to see subjobs */
        	(INSERT_COUNT != 0 OR UPDATE_COUNT != 0 OR DELETE_COUNT != 0 OR UNRESOLVABLE_SUBJECT_COUNT != 0)
        	)
        )
    )
) Gstat 
ORDER BY  Start DESC, End DESC, Status ASC, Total Desc, "Job Message"
LIMIT DisplayLimit
;
