#!/bin/sh

# get information about the current vmss node
AZ_VMSS_NAME=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmScaleSetName?api-version=2018-10-01&format=text"`
AZ_RG_NAME=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2018-10-01&format=text"`
AZ_VMSS_INSTANCE_PRIVATE_IP=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2018-10-01&format=text"`

# login to azure using managed identity
az login --identity 

# get all the nodes in the vmss
AZ_VMSS_ALL_INSTANCE_PRIVATE_IP=
for PRIVATE_IP in $(az vmss nic list --resource-group $AZ_RG_NAME --vmss-name $AZ_VMSS_NAME --query [].ipConfigurations[].privateIpAddress -o tsv)
do
  AZ_VMSS_ALL_INSTANCE_PRIVATE_IP=$PRIVATE_IP,$AZ_VMSS_ALL_INSTANCE_PRIVATE_IP
done

# clean up any existing local certs
COCKROACHDB_PATH=/cockroach-data
COCKROACH_USER_HOME=/home/`whoami`
COCKROACHDB_CERTS_PATH=$COCKROACH_USER_HOME/certs
rm $COCKROACHDB_CERTS_PATH/*.key
rm $COCKROACHDB_CERTS_PATH/*.crt

# get the resource name of the keyvault and load balancer using tags
KEYVAULT_NAME=`az resource list --tag crdb=crdb-keyvault --query [].name -o tsv`
LB_PIP_NAME=`az resource list --tag crdb=crdb-lb-pip --query [].name -o tsv`

# resolve the current LB public hostname and ip address
AZ_LB_PUBLIC_HOSTNAME=`az network public-ip show --name $LB_PIP_NAME --resource-group $AZ_RG_NAME --query dnsSettings.fqdn | tr -d '"'`
AZ_LB_PUBLIC_IP=`az network public-ip show --name $LB_PIP_NAME --resource-group $AZ_RG_NAME --query ipAddress | tr -d '"'`

# pull the current ca files from keyvault
az keyvault secret show --vault-name $KEYVAULT_NAME -n crdbkey | jq -r .value > $COCKROACHDB_CERTS_PATH/ca.key
az keyvault secret show --vault-name $KEYVAULT_NAME -n crdbcrt | jq -r .value > $COCKROACHDB_CERTS_PATH/ca.crt

# create a certificate for the local machine
cockroach cert create-node $AZ_VMSS_INSTANCE_PRIVATE_IP `hostname` $AZ_LB_PUBLIC_HOSTNAME $AZ_LB_PUBLIC_IP localhost 127.0.0.1 --certs-dir $COCKROACHDB_CERTS_PATH --ca-key=$COCKROACHDB_CERTS_PATH/ca.key

# remove the key file that was downloaded
rm $COCKROACHDB_CERTS_PATH/ca.key

# secure the folder contents
chmod go-rwx $COCKROACHDB_CERTS_PATH/*

# start cockroach db
# use the list of vmss in the start script

# insecure startup
#cockroach start --insecure --advertise-addr=$AZ_VMSS_INSTANCE_PRIVATE_IP --join=$AZ_VMSS_ALL_INSTANCE_PRIVATE_IP --store=/cockroach-data --background 

# secure startup with certs
cockroach start --certs-dir $COCKROACHDB_CERTS_PATH --advertise-addr=$AZ_VMSS_INSTANCE_PRIVATE_IP --join=$AZ_VMSS_ALL_INSTANCE_PRIVATE_IP --store=$COCKROACHDB_PATH --background 

# Exit script with 0 code to tell Azure that the deployment is done
exit 0 
