*******************************************************
	backup.sh 
*******************************************************
allows to backup redmine database and files
=> Executed by crontab for red user:
	#m h  dom mon dow   command
	0 1 * * * sh /home/red/Scripts/backup.sh

*******************************************************
	backupSyncthing.py 
*******************************************************
allows to create a zip with
- redmine files
- redmine databases
- all svn files
=> Executed by crontab for root user
	# m h  dom mon dow   command
	5 1 * * * python /home/red/Scripts/backupSyncthing.py