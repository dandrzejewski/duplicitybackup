#!/bin/sh

# Duplicity backup script by David Andrzejewski (david@davidandrzejewski.com).
#
# No warranty is provided.  This is my personal backup script.
#

BACKUP_TYPE="incremental"
if [ "$1" == "full" ]; then
	export BACKUP_TYPE="full"
fi

# You'll need to define the following in ./.vars.sh
export SERVER=
export SSH_USER=
export SSH_ID=
export SSH_OPTIONS=
export KEYID=
export RETAIN=
export EXCLUDES=
export DIRLIST=
export MAIL_USER=

. $(dirname $0)/.vars.sh

export DUPLICITY=/usr/local/bin/duplicity
export MACHINE_NAME=`hostname`

# Freebsd's crontab can set this to strange values. GPG and duplicity need $HOME to be 
# the actual home so they behave the same whether running from cron or 
# a terminal.
export HOME="/root"


# ************* Hopefully you shouldn't need to modify anything below here.

# Get the date
repDate=`date +%Y%m%d`

export BACKUP_LOG=/root/backuplogs/incremental_backup_log_${repDate}_${MACHINE_NAME}.log

echo >> ${BACKUP_LOG}
echo "********************************************" >> ${BACKUP_LOG}
echo >> ${BACKUP_LOG}

# Do the backup
echo "Performing Backup..." >> ${BACKUP_LOG}
${DUPLICITY} ${BACKUP_TYPE} --encrypt-key "${KEYID}" ${EXCLUDES} --ssh-options "${SSH_OPTIONS}" ${DIRLIST} sftp://${SSH_USER}@${SERVER}/${MACHINE_NAME} 2>&1 >> ${BACKUP_LOG}

# Clean Up
echo "Cleaning up older than ${RETAIN}" >> ${BACKUP_LOG}
${DUPLICITY} remove-older-than ${RETAIN} --force --ssh-options "${SSH_OPTIONS}" sftp://${SSH_USER}@${SERVER}/${MACHINE_NAME} 2>&1 >> ${BACKUP_LOG}

echo >> ${BACKUP_LOG}
# Get list of backups
${DUPLICITY} collection-status --ssh-options "${SSH_OPTIONS}" sftp://${SSH_USER}@${SERVER}/${MACHINE_NAME} 2>&1 >> ${BACKUP_LOG}
echo >> ${BACKUP_LOG}

# Get the disk space
echo >> ${BACKUP_LOG}
echo "Quota on Server" >> ${BACKUP_LOG}
echo >> ${BACKUP_LOG}
/usr/bin/ssh ${SSH_OPTIONS} ${SSH_USER}@${SERVER} quota 2>&1 >> ${BACKUP_LOG}

# Mail me the results
mail -s "${MACHINE_NAME} Backup Incremental" ${MAIL_USER} < ${BACKUP_LOG}

