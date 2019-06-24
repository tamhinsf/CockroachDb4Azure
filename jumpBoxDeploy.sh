# Log parameters passed to this script. 
echo $@ 

# Basic info
date 
whoami 

# install Azure CLI
sudo apt-get install apt-transport-https lsb-release software-properties-common dirmngr -y 
AZ_REPO=$(lsb_release -cs) 
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    sudo tee /etc/apt/sources.list.d/azure-cli.list 
sudo apt-key --keyring /etc/apt/trusted.gpg.d/Microsoft.gpg adv \
     --keyserver packages.microsoft.com \
     --recv-keys BC528686B50D79E339D3721CEB3E94ADBE1229CF 
sudo apt-get update 
sudo apt-get install azure-cli 

# Set the /cockroach-data data disk path
COCKROACHDB_PATH=/cockroach-data
mkdir $COCKROACHDB_PATH 

# install coackroach db
wget -qO- https://binaries.cockroachdb.com/cockroach-v19.1.1.linux-amd64.tgz | tar  xvz
cp -i cockroach-v19.1.1.linux-amd64/cockroach /usr/local/bin
mkdir /var/lib/cockroach
useradd cockroach
chown cockroach /var/lib/cockroach
chown -R cockroach:cockroach $COCKROACHDB_PATH

echo done  
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 
