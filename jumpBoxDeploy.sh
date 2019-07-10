# login to Azure
az login --identity

# get information about the current environment
AZ_RG_NAME=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2018-10-01&format=text"`
LB_PIP_NAME=`az resource list --tag crdb=crdb-lb-pip --query [].name -o tsv`
VMSS_NAME=`az resource list --tag crdb=crdb-vmss --query [].name -o tsv`

# get the resource name of the keyvault using tags
KEYVAULT_NAME=`az resource list --tag crdb=crdb-keyvault --query [].name -o tsv`

COCKROACH_USER=cockroach
COCKROACH_USER_HOME=/home/cockroach
COCKROACHDB_CERTS_PATH=$COCKROACH_USER_HOME/certs

AZ_LB_PUBLIC_HOSTNAME=`az network public-ip show --name $LB_PIP_NAME --resource-group $AZ_RG_NAME --query dnsSettings.fqdn | tr -d '"'`

AZ_FIRST_VMSS_NAME=`az vmss get-instance-view --resource-group $AZ_RG_NAME --name $VMSS_NAME --instance-id 0 --query computerName -o tsv`

cockroach init --certs-dir=$COCKROACHDB_CERTS_PATH --host=$AZ_FIRST_VMSS_NAME
sleep 30
cockroach sql  --certs-dir=$COCKROACHDB_CERTS_PATH --host=$AZ_LB_PUBLIC_HOSTNAME --execute="CREATE USER ${1} WITH PASSWORD '${2}'"

# Exit script with 0 code to tell Azure that the deployment is done
exit 0 

