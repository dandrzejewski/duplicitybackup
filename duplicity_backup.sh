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
export LOG_ARCHIVE_DIR=/root/backuplogs
export LOG_ARCHIVE_DAYS=30
export PASSPHRASE=""

. $(dirname $0)/.vars.sh

export DUPLICITY=/usr/local/bin/duplicity
export MACHINE_NAME=`hostname`

export GPG_OPTIONS="pinentry-mode=loopback"

# Freebsd's crontab can set this to strange values. GPG and duplicity need $HOME to be 
# the actual home so they behave the same whether running from cron or 
# a terminal.
export HOME="/root"


# ************* Hopefully you shouldn't need to modify anything below here.


if [ -z ${1} ]; then
	echo "You must specify full or incremental."
	exit 1
fi

# Get the date
repDate=`date +%Y%m%d%H%M`


export BACKUP_LOG=${LOG_ARCHIVE_DIR}/${BACKUP_TYPE}_backup_log_${repDate}_${MACHINE_NAME}.log
export SCRIPT_NAME=$( basename ${0} )

logit()
{
	local header="$1"
	local body="$2"

	echo "${header} $( ${date} "+%b %d %Y: %H:%M" ) ${body}" >> ${BACKUP_LOG}
}



echo >> ${BACKUP_LOG}
echo "********************************************" >> ${BACKUP_LOG}
echo >> ${BACKUP_LOG}

pgrep -f ${SCRIPT_NAME}
if [ $? -ne 1 ]; then
	echo "Duplicity backup process failed - already running!" >> ${BACKUP_LOG}
	mail -s "Duplicity backup failure" ${MAIL_USER} < ${BACKUP_LOG}
	exit 1
fi	

# Remove old backup logs


LEN=${#LOG_ARCHIVE_DIR}

if [ ${LEN} -lt 5 ]; then
	echo "You should check your log archive directory config.  Currently: ${LOG_ARCHIVE_DIR}"
	exit 1
fi	
find ${LOG_ARCHIVE_DIR} -mtime +${LOG_ARCHIVE_DAYS} -type f -delete

# Do the backup
echo "Performing Backup..." >> ${BACKUP_LOG}
${DUPLICITY} ${BACKUP_TYPE} --encrypt-key "${KEYID}" ${EXCLUDES} --gpg-options "${GPG_OPTIONS}" --ssh-options "${SSH_OPTIONS}" ${DIRLIST} sftp://${SSH_USER}@${SERVER}/${MACHINE_NAME} 2>&1 >> ${BACKUP_LOG}

# Clean Up
echo "Cleaning up older than ${RETAIN}" >> ${BACKUP_LOG}
${DUPLICITY} remove-older-than ${RETAIN} --force --gpg-options "${GPG_OPTIONS}" --ssh-options "${SSH_OPTIONS}" sftp://${SSH_USER}@${SERVER}/${MACHINE_NAME} 2>&1 >> ${BACKUP_LOG}

echo >> ${BACKUP_LOG}
# Get list of backups
${DUPLICITY} collection-status --gpg-options "${GPG_OPTIONS}" --ssh-options "${SSH_OPTIONS}" sftp://${SSH_USER}@${SERVER}/${MACHINE_NAME} 2>&1 >> ${BACKUP_LOG}
echo >> ${BACKUP_LOG}

# Get the disk space
echo >> ${BACKUP_LOG}
echo "Quota on Server" >> ${BACKUP_LOG}
echo >> ${BACKUP_LOG}
/usr/bin/ssh ${SSH_OPTIONS} ${SSH_USER}@${SERVER} quota 2>&1 >> ${BACKUP_LOG}

# Mail me the results
mail -s "${MACHINE_NAME} Backup ${BACKUP_TYPE}" ${MAIL_USER} < ${BACKUP_LOG}

