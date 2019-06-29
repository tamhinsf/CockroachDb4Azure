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
echo $AZ_VMSS_ALL_INSTANCE_PRIVATE_IP

COCKROACHDB_PATH=/cockroach-data
COCKROACHDB_CERTS_PATH=$COCKROACHDB_PATH/certs
chmod -R go-rwx $COCKROACHDB_CERTS_PATH

az keyvault secret show --vault-name $KEYVAULT_NAME -n crdbkey | jq -r .value > $COCKROACHDB_CERTS_PATH/ca.key

# create a certificate for the local machine
cockroach cert create-node $AZ_VMSS_INSTANCE_PRIVATE_IP `hostname` localhost 127.0.0.1 --certs-dir $COCKROACHDB_CERTS_PATH --ca-key=$COCKROACHDB_CERTS_PATH/ca.key

# start cockroach db
# use the list of vmss in the start script
#cockroach start --insecure --advertise-addr=$AZ_VMSS_INSTANCE_PRIVATE_IP --join=$AZ_VMSS_ALL_INSTANCE_PRIVATE_IP --store=/cockroach-data --background 
cockroach start --certs-dir $COCKROACHDB_CERTS_PATH --advertise-addr=$AZ_VMSS_INSTANCE_PRIVATE_IP --join=$AZ_VMSS_ALL_INSTANCE_PRIVATE_IP --store=/cockroach-data --background 

echo done  
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 