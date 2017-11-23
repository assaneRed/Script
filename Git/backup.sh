/usr/bin/mysqldump -u backup -pb@ckUp redmine | gzip > /home/red/Scripts/db/redmine_db_`date +%y_%m_%d`.gz
# echo "test" > /home/red/Scripts/`date +%y_%m_%d_%H_%M_%S`.txt
