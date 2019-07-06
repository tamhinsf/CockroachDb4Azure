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

# login to Azure
az login --identity

# Create a cockroach user
COCKROACH_USER=cockroach
COCKROACH_USER_HOME=/home/cockroach
useradd -m -d $COCKROACH_USER_HOME -s /bin/bash $COCKROACH_USER

# Set the variable COCKROACHDB_PATH to the default, re-use it in this script 
COCKROACHDB_PATH=/cockroach-data
mkdir $COCKROACHDB_PATH 
chown -R $COCKROACH_USER $COCKROACHDB_PATH

# install coackroach db
wget -qO- https://binaries.cockroachdb.com/cockroach-v19.1.2.linux-amd64.tgz | tar  xvz
cp -i cockroach-v19.1.2.linux-amd64/cockroach /usr/local/bin
mkdir /var/lib/cockroach
chown -R $COCKROACH_USER:$COCKROACH_USER /var/lib/cockroach

# get the resource name of the keyvault using tags
KEYVAULT_NAME=`az resource list --tag crdb=crdb-keyvault --query [].name -o tsv`

# prep for cockroach db certs
COCKROACHDB_CERTS_PATH=$COCKROACH_USER_HOME/certs
mkdir $COCKROACHDB_CERTS_PATH
chown -R cockroach $COCKROACHDB_CERTS_PATH

# install jq
sudo apt install jq -y

# generate the private key
cockroach cert create-ca --certs-dir=$COCKROACHDB_CERTS_PATH --ca-key=$COCKROACHDB_CERTS_PATH/ca.key

# make a cert for the root user so we can connect later on
cockroach cert create-client root --certs-dir=$COCKROACHDB_CERTS_PATH --ca-key=$COCKROACHDB_CERTS_PATH/ca.key

# put the private key into keyvault
az keyvault secret set --vault-name $KEYVAULT_NAME -n crdbkey -f $COCKROACHDB_CERTS_PATH/ca.key
az keyvault secret set --vault-name $KEYVAULT_NAME -n crdbcrt -f $COCKROACHDB_CERTS_PATH/ca.crt

# Exit script with 0 code to tell Azure that the deployment is done
exit 0 

