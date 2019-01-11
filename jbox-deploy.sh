# Log activity
LOG_PATH=/tmp/azuredeploy.log

# Log parameters passed to this script. 
echo $@ >> $LOG_PATH 2>&1

# Basic info
date > $LOG_PATH 2>&1
whoami >> $LOG_PATH 2>&1

# install Azure CLI
sudo apt-get install apt-transport-https lsb-release software-properties-common dirmngr -y > $LOG_PATH 2>&1
AZ_REPO=$(lsb_release -cs) > $LOG_PATH 2>&1
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list > $LOG_PATH 2>&1
sudo apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv \
     --keyserver packages.microsoft.com \
     --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF > $LOG_PATH 2>&1
sudo apt-get update > $LOG_PATH 2>&1
sudo apt-get install azure-cli > $LOG_PATH 2>&1

# install coackroach db
wget -qO- https://binaries.cockroachdb.com/cockroach-v2.1.3.linux-amd64.tgz | tar  xvz  >> $LOG_PATH 2>&1
cp -i cockroach-v2.1.3.linux-amd64/cockroach /usr/local/bin  >> $LOG_PATH 2>&1

echo done  >> $LOG_PATH 2>&1
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 >> $LOG_PATH 2>&1
