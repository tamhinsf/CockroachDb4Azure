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

# get the internal hostname of the first VM in the VMSS so we can init the cluster
# we cannot init the load balancer ip address since the health probe is failng - because we have not init the cluster yet
# to do - check if the VM is actually running, and skip to the next one if not
AZ_FIRST_VMSS_NAME=`az vmss get-instance-view --resource-group $AZ_RG_NAME --name $VMSS_NAME --instance-id 0 --query computerName -o tsv`

# init the first vm in the vmss using its internal hostname
# and give time for the load balancer health probe to suceed
# create a db user that has the same credentials as the admin user on the vm
cockroach init --certs-dir=$COCKROACHDB_CERTS_PATH --host=$AZ_FIRST_VMSS_NAME
sleep 45
cockroach sql  --certs-dir=$COCKROACHDB_CERTS_PATH --host=$AZ_LB_PUBLIC_HOSTNAME --execute="CREATE USER ${1} WITH PASSWORD '${2}'"

# Exit script with 0 code to tell Azure that the deployment is done
exit 0 

