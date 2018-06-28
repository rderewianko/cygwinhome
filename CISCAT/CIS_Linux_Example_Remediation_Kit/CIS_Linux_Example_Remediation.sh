#!/bin/bash
PROFILE=${1:-Level 1}
LOGFILE=/tmp/ciscat.deploy
cat /dev/null > ${LOGFILE}

if [ "$PROFILE" = "Level 1" ] || [ "$PROFILE" = "Level 2" ]; then
	echo \*\*\*\* Executing Level 1 profile remediation >> ${LOGFILE}

	# Set nodev option for /tmp Partition
	echo >> ${LOGFILE}
	echo \*\*\*\* Set\ nodev\ option\ for\ /tmp\ Partition >> ${LOGFILE}
	#egrep -q "^(\s*\S+\s+)/tmp(\s+\S+\s+\S+)(\s+\S+\s+\S+)(\s*#.*)?\s*$" /etc/fstab && sed -ri "s/^(\s*\S+\s+)/tmp(\s+\S+\s+\S+)(\s+\S+\s+\S+)(\s*#.*)?\s*$/\1/tmp\2nodev\3\4/" /etc/fstab
 	TMPMNTOPTS=$(grep "/tmp " /etc/fstab | awk '{print $4}'
  

	# Create separate /var/tmp file system
	df -h /var/tmp > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		/sbin/lvcreate -n lv_var_tmp -L 4G /dev/vg_root
		if [ $? -ne 0 ]; then
			mailx -s "Creation of /var/tmp lv failed" >> {$LOGFILE}
		else	
			/sbin/mkfs -t ext4 /dev/vg_root/lv_var_tmp
			/bin/mount /dev/vg_root/lv_var_tmp /mnt
			/usr/bin/rsync -avuz /var/tmp /mnt
			/bin/rm -fr /var/tmp
			/bin/mkdir -m 755 /var/tmp

			grep /var/tmp /etc/fstab > /dev/null
			if [ $? -ne 0 ]; then
				/usr/bin/printf "/dev/mapper/vg_root-lv_var_tmp\t/var/tmp\t\text4\tnosuid,nodev,noexec\t1 2\n" >> /etc/fstab
			fi

			/bin/umount /mnt
			/bin/mount /var/tmp
		fi
	fi

  # Restrict Core Dumps
  echo
  echo \*\*\*\* Restrict\ Core\ Dumps
  egrep -q "^(\s*)\*\s+hard\s+core\s+\S+(\s*#.*)?\s*$" /etc/security/limits.conf && sed -ri "s/^(\s*)\*\s+hard\s+core\s+\S+(\s*#.*)?\s*$/\1* hard core 0\2/" /etc/security/limits.conf || echo "* hard core 0" >> /etc/security/limits.conf
  egrep -q "^(\s*)fs.suid_dumpable\s*=\s*\S+(\s*#.*)?\s*$" /etc/sysctl.conf && sed -ri "s/^(\s*)fs.suid_dumpable\s*=\s*\S+(\s*#.*)?\s*$/\1fs.suid_dumpable = 0\2/" /etc/sysctl.conf || echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf

  # Enable Randomized Virtual Memory Region Placement
  echo
  echo \*\*\*\* Enable\ Randomized\ Virtual\ Memory\ Region\ Placement
  egrep -q "^(\s*)kernel.randomize_va_space\s*=\s*\S+(\s*#.*)?\s*$" /etc/sysctl.conf && sed -ri "s/^(\s*)kernel.randomize_va_space\s*=\s*\S+(\s*#.*)?\s*$/\1kernel.randomize_va_space = 2\2/" /etc/sysctl.conf || echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf

  # Remove telnet-server
  echo
  echo \*\*\*\* Remove\ telnet-server
  rpm -q telnet-server && yum -y remove telnet-server

  # Disable tcpmux-server
  echo
  echo \*\*\*\* Disable\ tcpmux-server
  rpm -q xinetd && chkconfig tcpmux-server off

  # Disable Print Server - CUPS
  echo
  echo \*\*\*\* Disable\ Print\ Server\ -\ CUPS
  chkconfig cups off

  # Verify Permissions on /etc/hosts.allow
  echo
  echo \*\*\*\* Verify\ Permissions\ on\ /etc/hosts.allow
  chmod u+r+w-x,g+r-w-x,o+r-w-x /etc/hosts.allow

  # Disable SSH X11 Forwarding
  echo
  echo \*\*\*\* Disable\ SSH\ X11\ Forwarding
  egrep -q "^(\s*)X11Forwarding\s+\S+(\s*#.*)?\s*$" /etc/ssh/sshd_config && sed -ri "s/^(\s*)X11Forwarding\s+\S+(\s*#.*)?\s*$/\1X11Forwarding no\2/" /etc/ssh/sshd_config || echo "X11Forwarding no" >> /etc/ssh/sshd_config

  # Lock Inactive User Accounts
  echo
  echo \*\*\*\* Lock\ Inactive\ User\ Accounts
  useradd -D -f 35

  # Disable unused file systems
  echo
  echo \*\*\*\* Disable\ cramfs
  echo "install cramfs /bin/true" >> /etc/modprobe.d/CIS.conf
  echo \*\*\*\* Disable\ freevxfs
  echo "install freevxfs /bin/true" >> /etc/modprobe.d/CIS.conf
  echo \*\*\*\* Disable\ jffs2
  echo "install jffs2 /bin/true" >> /etc/modprobe.d/CIS.conf
  echo \*\*\*\* Disable\ hfs
  echo "install hfs /bin/true" >> /etc/modprobe.d/CIS.conf
  echo \*\*\*\* Disable\ hfsplus
  echo "install hfsplus /bin/true" >> /etc/modprobe.d/CIS.conf
  echo \*\*\*\* Disable\ squashfs
  echo "install squashfs /bin/true" >> /etc/modprobe.d/CIS.conf
  echo \*\*\*\* Disable\ fat
  echo "install fat /bin/true" >> /etc/modprobe.d/CIS.conf
  echo \*\*\*\* Disable\ vfat
  echo "install vfat /bin/true" >> /etc/modprobe.d/CIS.conf
 
fi

if [ "$PROFILE" = "Level 2" ]; then
  echo \*\*\*\* Executing Level 2 profile remediation

  # Install AIDE
  echo
  echo \*\*\*\* Install\ AIDE
  rpm -q aide || yum -y install aide

  # Implement Periodic Execution of File Integrity
  echo
  echo \*\*\*\* Implement\ Periodic\ Execution\ of\ File\ Integrity
  (crontab -u root -l; crontab -u root -l | egrep -q "^0 5 \* \* \* /usr/sbin/aide --check$" || echo "0 5 * * * /usr/sbin/aide --check" ) | crontab -u root -

  # Enable auditd Service
  echo
  echo \*\*\*\* Enable\ auditd\ Service
  chkconfig auditd on

  # Collect System Administrator Actions (sudolog)
  echo
  echo \*\*\*\* Collect\ System\ Administrator\ Actions\ \(sudolog\)
  egrep -q "^\s*-w\s+/var/log/sudo.log\s+-p\s+wa\s+-k\s+actions\s*(#.*)?$" /etc/audit/audit.rules || echo "-w /var/log/sudo.log -p wa -k actions" >> /etc/audit/audit.rules

fi
