#AUTHOR : Prastut Sapkota

#!/bin/bash

clear
: '
if [ $UID != 0 ]
	then
		echo "Unable to perform this script without root user."
		exit
	fi
echo "Search my.cnf file"
echo
'
#Search Path

if test -s /etc/mysql/my.cnf
	then
		echo "[FOUND] /etc/mysql/my.cnf Default Configuration File"
		CFGFILE="/etc/mysql/my.cnf";
		echo
	else
		echo "[NOT FOUND] /etc/mysql/my.cnf"
		echo
fi

echo "************************************************************************"
echo "Lets Have Fun  Replicating"

echo "Press a key to continue"
read PAUSE

echo "Searching for server-id";
if [ `grep -c "^server-id" $CFGFILE` -gt 0 ]
	then
		echo "You already have a 'server-id'";
		echo "Proceed Next Step";
	else
		echo "NO 'server id' found. Enter value manually later";
		echo
                echo -n "Please enter a unique numerical value (Usually put 1 as value): "$
                read SERVERID;
	fi 

echo "Searching for log_bin"
if [ `grep -c "^log_bin" $CFGFILE` -gt 0 ] 
	then
		echo "You already have a 'log_bin'"
		echo "Proceed Next Step"
	else
		echo "NO 'log_bin' found. Enter value manually later";
		echo
                echo -n "Please enter the binary log file (ex: mysql-bin.log): "$
                read BINLOG;

	fi

echo
echo "************************************************************************";
echo
echo "-----Declare Configuration Settings-----";
echo
echo "We are replicating all the databases";
echo

echo "Replicating All Database";
BINLOGIGNOREDB="mysql";
echo
echo "************************************************************************"
echo

echo "Writing changes to $CFGFILE...";

sed -i 's/^bind-address/bind-address = 192.168.1.1\n#/' /etc/mysql/mysql.conf.d/mysqld.cnf

if [ '`grep -c "^server-id" $CFGFILE` -gt 0' = false ] && ['`grep -c "^log_bin" $CFGFILE` -gt 0' = false ]; 
	then
		if [[ ! -z $BINLOGIGNOREDB ]]
			then
				SARGS="-i 's/^\[mysqld\]/\[mysqld\]\nserver-id=\"$SERVERID\"\nlog_bin=\"$BINLOG\"\nbinlog_ignore_db=\"mysql\"/' $CFGFILE"
				eval sed "$SARGS"
			fi
	fi

echo "[SUCCESS] Configuring Setting"

echo
echo
echo "MySQL DB."
echo
echo "Press any key to continue.."

read BLAH


GetPass() {
echo -n "Please enter the root password for this MySQL instance: "
read -s PW1
echo
echo -n "Please re-type the password to confirm: "
read -s PW2
echo
if [[ $PW1 != $PW2 ]]
        then
                echo "Passwords do not match, try again."
                GetPass
        fi
}


GetRPass() {
echo
echo -n "Please enter the replication user's password: "
read -s RPW1

echo
echo -n "Please retype the password to confirm: "
read -s RPW2

if [[ $RPW1 != $RPW2 ]]
        then
                echo "Passwords do not match, try again."
                GetRPass
        fi
}


GetPass

echo "Restarting MySQL"
service mysql restart

# lock the db tables to create a current dump of the data.
mysql -u root --password="$PW1" -e  'FLUSH TABLES WITH READ LOCK'

# capture binary log filename, and current position ot a text file.
mysql -u root --password="$PW1" -e 'show master status'>/tmp/binlog.txt

echo "Your binary log filename, and it's current position have been saved to ~/tmp/binlog.txt"
echo "You will NEED this information when configuring your Slave MySQL server."

# need to create dumps of ALL existing DB if replication exists for all DB
if [[ ! -z $BINLOGIGNOREDB ]]
	then
	#
	# dump all mysql databases except mysql, information schema and performance_schema'
	echo 'show databases;' | mysql --password="$PW1" | grep -v ^Database$ | grep -v ^information_schema$ | grep -v ^mysql$ | grep -v performance_schema |grep -v ^information_schema | xargs mysqldump --skip-lock-tables --password="$PW1"  --databases >~/tmp/AllDBs.sql

	echo "A SQL Dump of all datases has been created and is located at /tmp/AllDBs.sql"
fi

mysql -u root --password="$PW1" -e "unlock tables"
echo "The MySQL tables have been unlocked and writes may once again occur."


echo
echo
echo "Use an existing Database or Create one for Replication User"
echo
echo -n "Please enter a replication username (ex: repl): "
read REPUSER

GetRPass

echo 
echo
echo -n "Enter IP Address of Slave MySQL Server: "
read SLAVEIP

echo
echo "Review the following:"
echo "Replication user: $REPUSER"
echo "Replication user password: $RPW1"
echo "Slave MySQL Host: $SLAVEIP"
echo
echo -n "Is this correct [Y/N]? ";
read REPOK

if [[ `echo $REPOK |awk '{print tolower($0)}'` == "y" ]]
        then
	RFILE="/home/osboxes/tmp/replication.txt"

        echo "Creating the replication user.."
        mysql -u root --password="$PW1" -e "GRANT REPLICATION SLAVE ON *.* to $REPUSER@$SLAVEIP IDENTIFIED BY '$RPW1'"
	echo "Replication User: $REPUSER" >$RFILE
	echo "Replication User Password: $RPW1" >>$RFILE
	BLOGFILE=`cat /tmp/binlog.txt |tail -1 |awk '{print $1}'`
	BLOGPOS=`cat /tmp/binlog.txt |tail -1 |awk '{print $2}'`

	echo "Binary Log: $BLOGFILE" >>$RFILE
	echo "Log Position: $BLOGPOS" >>$RFILE
        fi
echo
echo
echo "[SUCCESS] You have successfully configured this MySQL Database as a Master.."
echo
echo "Press any key to copy these files  or CTRL-C to exit."

read COPYFILES


echo "Attempting to scp files to /tmp on $SLAVEIP..."

if [[ ! -z $BINLOGIGNOREDB ]]
	then
		scp ~/tmp/AllDBs.sql osboxes@$SLAVEIP:~/tmp
	fi

echo
echo " [SUCCESS] "
exit
