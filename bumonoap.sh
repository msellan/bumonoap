#!/bin/bash

#-----------------------------------------------------------------------
# Description:  A multipurpose script to manage the backup of MongoDB
# databases in conjunction with NodeJS applications running with the 
# NodeJS PM2 NPM process manager.  The script works modularly for
# getting status of PM2 applications and for MongoDB.  
# 
# The script takes one arument and can provide app or DB status, start
# and stop the apps or database and can take backups of the database 
# both online using mongodump or offline using Rsync. 
#
# Running the script with no arguments shows the full usage information.
#
#-----------------------------------------------------------------------
# Author: Mark Sellan
#-----------------------------------------------------------------------
# Date: 9/1/17
#-----------------------------------------------------------------------
# Modifications:
#----------------------------------------------------------------------- 

RSYNC_HOST=${RSYNC_HOST}
LOG_FILE=/var/log/bumlac.log
BACKUP_LOC=/var/log/mongo_backups
PATH=$PATH:/usr/bin

#=====>  Stop Mongo database <======

stop_dbs() {

	check_dbs_running

    if [[ ${dbstatus} -eq 1 ]]; then
        logit "Processing request to stop MonogDB"
        systemctl stop mongod &>> ${LOG_FILE}
    fi
}

#=====> Start Mongo database <======

start_dbs() {

	check_dbs_running
	
    if [[ ${dbstatus} -eq 0 ]]; then
        logit "Processing request to start MongoDB"	
        systemctl start mongod &>> ${LOG_FILE}
    fi
}

#=====> Check databases running <=====

check_dbs_running() {

	systemctl status mongod | grep -i running 
	
    if [[ $? -eq 0 ]]; then
        dbstatus=1
		logit "Status message: MongoDB is currently up"
    else
        dbstatus=0
		logit "Status message: MongoDB is currently down"
    fi
}

#=====> Backup Mongo Databases <====

backup_dbs() {

    check_app_running

    if [[ ${apps_running} -eq 0 ]]; then
        logit "All apps are down"
    else
        logit "One or more apps are still up - taking down now"
        stop_apps
    fi

    if [[ $? -eq 0 ]]; then
        logit "Request to stop all apps was successful- running Mongodump to take a backup"
        mongodump --out ${BACKUP_LOC}
            
        if [[ $? -eq 0 ]]; then
            start_apps
        else
            logit "WARNING: One or more Apps didn't start - please investigate"
            check_app_running
            exit 1
        fi
    else
        logit "WARNING: Aborting backup - the applications are not down"
        exit 1
    fi
}

#====>  Backup MongoDB using RSYNC <=======

#TO BE COMPLETED - This function is non-operational

backup_dbs_offline() {

	check_dbs_running

    if [[ ${dbstatus} -eq 0 ]]; then
        logit "Databases are down"
    else
        logit "Databases are still up - taking down now"
        stop_dbs
    fi

    if  [[ $? -eq 0 ]]; then
        logit "Mongo is down - ready for backup"
        logit "run mongodump command"
        mongodump --out ${BACKUP_LOC}
	else
        logit "Warning!  The database did not stop properly"
        logit "please investigate.  Backup aborted"
        check_dbs_running	
        exit 1
    fi	
} 

#=====> Check apps running <======

check_app_running() {

    while IFS=  read -r line; do
        if [[ $line == *"online"* ]]; then
            apps_running=1
        elif
            [[ $line == *"stopped"* ]]; then
            apps_running=0
        fi
    done < <(pm2 status all -m) &>> ${LOG_FILE}
}

#=====>  Stop all apps <======

stop_apps() {
       
    check_app_running

    if [[ ${apps_running} -eq 1 ]]; then
        logit "Processing request to stop all apps"
        pm2 stop all &>> ${LOG_FILE}
    fi
}

#=====>  Start all apps <=====

start_apps() {

    check_dbs_running
    
    if [[ ${dbstatus} -eq 0 ]]; then
        logit "Warning!  The database is down - aborting application start
        request"
        exit 1
    fi 
    
    check_app_running

    if [[ ${apps_running} -eq 0 ]]; then
        logit "Processing request to start all apps"
        pm2 start all &>> ${LOG_FILE}
    fi
}

#====> Get app status <=====

app_status() {

    pm2 status all
}

#====> Get db status <=====

dbs_status() {

    systemctl status mongod
}

#====> Log output <=====

logit() {
    
    MSG=$1
    DATE_STR=`date "+%b %d %X"`
    LOG_MSG="${DATE_STR} ${MSG}"
    echo "${LOG_MSG}" >> ${LOG_FILE}

}

show_usage() {

clear

echo "NAME"
echo " "
echo "      bumlac.sh - a multipurpose MongoDB and Node Applications Controller"
echo " "
echo "SYNOPSIS"
echo " "
echo "      ${SCRIPT_NAME} -[argument]"
echo " "
echo "DESCRIPTION"
echo " "
echo "bumlac provides a common control mechanism for starting and stopping"
echo "MongoDB databases and NodeJS applications running under the NPM provided PM2"
echo "process manager.  Its main purpose is to allow for automated backups of a Mongo"
echo "database providing two mechanisms for backup inluding online backups with"
echo "mongodump as well as offline backups using rsync. The script requires one"
echo "arguement to run. " 
echo ""
echo "OPTIONS"
echo "  -check-dbs"
echo "      calls a function check_dbs_running and returns to the bumlac log"
echo ""
echo "  -backup-dbs"
echo "      calls stop_apps fucntion and then uses mongodump to take an online"
echo "      backup of the mongo database"
echo ""
echo "  -backup-dbs-offl"
echo "      calls both stop_apps and stop_dbs functions to stop both the"
echo "      applications and database and then uses rsync to backup the "
echo "      database files to a remote server"
echo ""
echo "  -stop-dbs"
echo "      uses systemctl to stop the mongodb database"
echo ""
echo "  -start-dbs"
echo "      uses systemctl to start the mongodb databses"
echo ""
echo "  -check-apps"
echo "      calls the pm2 process manager for all applications status"
echo ""
echo "  -stop-apps"
echo "      calls the pm2 process manager to stop all applications"
echo ""
echo "  -start-apps"
echo "      calls the pm2 process manager to start all applications"
echo ""
echo "  -app-status"
echo "      calls the pm2 process manager to provide all applications status"
echo "      and sends output to standard out for interactive viewing"
echo ""
echo "  -db-staus"
echo "      calls systemctl status and sends the output to standard out"
echo "      for interactive viewing"
echo ""
echo "  -help"
echo "      displays this usage statement"
echo ""
echo "AUTHOR"
echo ""
echo "Written by Mark Sellan for Washington University Libraries"

}

#====>  Main  <=====

    dbstatus=2

    action=$1

    [[ $# -lt 1 ]] && show_usage && exit

    case ${action} in
    	"-check-dbs")
    	check_dbs_running
    	;;
    	"-backup-dbs")
    	backup_dbs
    	;;
        "-backup-dbs-offl")
        backup_dbs_offline
        ;;
    	"-stop-dbs")
    	stop_dbs
    	;;
    	"-start-dbs")
    	start_dbs
    	;;
    	"-check-apps")
    	check_app_running
    	;;
    	"-stop-apps")
    	stop_apps
    	;;
    	"-start-apps")
    	start_apps
    	;;
    	"-app-status")
    	app_status
    	;;
    	"-db-status")
    	dbs_status
    	;;
    	"-help")
    	show_usage
    	;;
    	*)
        show_usage
        exit 1
    	;;
    esac

