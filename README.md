# grouper-gstat
 Grouper SQL based Loader Log Status viewer

gstat.sh is the driver program.  

i.e. "gstat.sh 5 45" will query every 5 seconds and limit display to 45 lines.

customize the first few lines of gstat.sh to your liking.  It assumes the MariaDB mysql client will be called using the MariaDB 10.3+ SQL code (also has been used on MariaDB 10.4+).  REGEXP calls in the SQL are needed to make things look nice so 10.[34]+ are needed.  This should make it easier for someone using Oracle since it has REGEXP functions.  However, MySQL display is different so there may be some effort to make this tool run against Oracle.  If you do - please let me know so I may include a copy of the code here.

This also assumes you have /usr/bin/pr installed.  pr has an option (--merge) that allows for making more efficient use of screen real estate by having additinal MySQL output appear along-side the change-log consumer list.  So, if you have MySQL analyze or optimize running - you will see this output as well.  And, as an aside, if you are running MariaDB-10 - well, you should be using optimize since this performs the facebook optimize in place capabilities and keeps your GrouperDB running lean and mean.

/mrg
