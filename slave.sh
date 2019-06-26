#AUTHOR : Prastut Sapkota


#!/bin/bash
clear


# verify root is running the script.
if [ $UID != 0 ]
	then
		echo "Sorry, Only root can  execute this script.";
		exit 
	fi

echo -n "Press a key or use CTRL-C to abort"
read READYTOGO

echo "Search my.cnf file...";
echo

# search for common paths to my.cnf
if test -s /etc/mysql/my.cnf 
	then
		echo "[FOUND] /etc/mysql/my.cnf as the default configuration file.";     
		CFGFILE="/etc/mysql/my.cnf";
		echo
	else
		echo "[NOT FOUND] /etc/mysql/my.cnf";
		echo
fi

echo
echo "***************************************************************************************************************************"
echo "Searching for server-id............................";
if [ `grep -c "^server-id" $CFGFILE` -gt 0 ]
	then
		echo "ALready Have a server ID"
	else
		echo "No 'server-id' value.";
		echo
		echo -n "Please enter a unique numerical value (ex: 2) for your server-id: " 
		read SERVERID;
		echo
		echo "Writing changes to $CFGFILE...";
                SARGS="-i 's/^\[mysqld\]/\[mysqld\]\nserver-id=\"$SERVERID\"\n/' $CFGFILE"
                eval sed "$SARGS";
	fi
echo
echo "Applying bind address of the Slave"
sed -i 's/^bind-address/bind-address = 192.168.1.11\n#/' /etc/mysql/mysql.conf.d/mysqld.cnf
echo "DONE"

echo
echo "[SUCCESS] Your replication updates to $CFGFILE are complete."

echo "DB Connection" 
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

GetPass



echo 
echo -n "Enter the replication user's name: "
read REPUSER

GetRPass() {
echo
echo -n "Please enter the replication user's password: "
read -s RPW1

echo
echo -n "Please retype the password to confirm: "
read -s RPW2
echo

if [[ $RPW1 != $RPW2 ]]
        then
                echo "Passwords do not match, try again."
                GetRPass
        fi
}

GetRPass

echo 
echo -n "Enter the binary log filename: "
read BINLOG

echo -n "Enter the position number of the binary log: "
read BINLOGPOS

echo
echo -n "IP Address of Master MySQL Server?: "
read MASTERIP

echo
echo "Review the following:"
echo "Replication user: $REPUSER"
echo "Replication user password: $RPW1"
echo "Master MySQL Host: $MASTERIP"
echo "Binary Log filename: $BINLOG"
echo "Binary Log Position: $BINLOGPOS"

echo
echo -n "Is this correct [Y/N]? ";
read REPOK


if [[ `echo $REPOK |awk '{print tolower($0)}'` == "y" ]]
        then
	echo "Restarting mysqld.."
	service mysqld restart

        echo "Configuring Slave.."
        mysql -u root --password="$PW1" -e "CHANGE MASTER TO MASTER_HOST='$MASTERIP', MASTER_USER='$REPUSER', MASTER_PASSWORD='$RPW1', MASTER_LOG_FILE='$BINLOG', MASTER_LOG_POS=$BINLOGPOS;"
	echo "Starting Slave.."
	mysql -u root --password="$PW1" -e "START SLAVE;"

	echo "Slave Status.."
	mysql -u root --password="$PW1" -e "SHOW SLAVE STATUS\G;"
        fi


echo
echo 
echo "[SUCCESS] You have successfully configured this MySQL Database as a Slave.."
echo 
exit


