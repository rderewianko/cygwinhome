#!/bin/bash

DATE=`date +%d%m%Y`
OSVER=`lsb_release -sr | cut -d. -f1`

URGET() {
	if [ -f /etc/at.allow ]; then
		chmod 600 /etc/at.allow
		chown root:root /etc/at.allow
	else
		touch /etc/at.allow
		chmod 600 /etc/at.allow
		chown root:root /etc/at.allow
	fi

	if [ -f /etc/at.deny ]; then
		rm /etc/at.deny
	fi

	if [ -f /etc/cron.allow ]; then
		chmod 600 /etc/cron.allow
		chown root:root /etc/cron.allow
	else
		touch /etc/cron.allow
		chmod 600 /etc/cron.allow
		chown root:root /etc/cron.allow
	fi

	if [ -f /etc/cron.deny ]; then
		rm /etc/cron.deny
	fi

	chmod 700 /etc/cron.hourly
	chmod 700 /etc/cron.daily
	chmod 700 /etc/cron.weekly
	chmod 700 /etc/cron.d

	if [ -f /etc/ssh/sshd_config]; then
		perl -pi".${DATE}" -e "s/^PermitRootLogin yes/PermitRootLogin no" /etc/ssh/sshd_config
		perl -pi".${DATE}" -e "s/^#PermitRootLogin yes/PermitRootLogin no" /etc/ssh/sshd_config
		if [ "${OSVER}" = "7" ]; then
			systemctl restart sshd
		else
			service sshd restart
		fi
	fi

	if [ -f /etc/login.defs ]; then
		perl -pi".${DATE}" -e "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/" /etc/login.defs
		perl -pi -e "s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t7/" /etc/login.defs
	fi
}

URGENT
