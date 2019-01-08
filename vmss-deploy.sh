# Log activity
LOG_PATH=/tmp/azuredeploy.log

# Log parameters passed to this script. 
echo $@ >> $LOG_PATH 2>&1

# Basic info
date > $LOG_PATH 2>&1
whoami >> $LOG_PATH 2>&1

wget -qO- https://binaries.cockroachdb.com/cockroach-v2.1.3.linux-amd64.tgz | tar  xvz >> $LOG_PATH 2>&1
cp -i cockroach-v2.1.3.linux-amd64/cockroach /usr/local/bin  >> $LOG_PATH 2>&1
mkdir /var/lib/cockroach >> $LOG_PATH 2>&1
useradd cockroach >> $LOG_PATH 2>&1
chown cockroach /var/lib/cockroach >> $LOG_PATH 2>&1
wget -qO- /etc/systemd/system/insecurecockroachdb.service https://raw.githubusercontent.com/cockroachdb/docs/master/_includes/v2.1/prod-deployment/insecurecockroachdb.service >> $LOG_PATH 2>&1

echo done  >> $LOG_PATH 2>&1
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 >> $LOG_PATH 2>&1
