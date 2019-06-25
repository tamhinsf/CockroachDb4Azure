# Log parameters passed to this script. 
echo $@ 

# Basic info
date 
whoami 

# Store parameters passed to this script
NUM_OF_DATA_DISKS=${1}

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

if [ $NUM_OF_DATA_DISKS -eq 1 ]; then
  mkfs -F -t ext4 /dev/sdc 
  echo "UUID=`blkid -s UUID /dev/sdc | cut -d '"' -f2` $COCKROACHDB_PATH ext4  defaults,discard 0 0" | tee -a /etc/fstab 
else
  apt-get install lsscsi -y 
  DEVICE_NAME_STRING=
  for device in `lsscsi |grep -v "/dev/sda \|/dev/sdb \|/dev/sr0 " | cut -d "/" -f3`; do 
   DEVICE_NAME_STRING_TMP=`echo /dev/$device`
   DEVICE_NAME_STRING=`echo $DEVICE_NAME_STRING $DEVICE_NAME_STRING_TMP`
  done
  mdadm --create /dev/md0 --level 0 --raid-devices=$NUM_OF_DATA_DISKS $DEVICE_NAME_STRING 
  mkfs -F -t ext4 /dev/md0 
  echo "UUID=`blkid -s UUID /dev/md0 | cut -d '"' -f2` $COCKROACHDB_PATH ext4  defaults,discard 0 0" | tee -a /etc/fstab 
fi

mount $COCKROACHDB_PATH

# install coackroach db
wget -qO- https://binaries.cockroachdb.com/cockroach-v19.1.1.linux-amd64.tgz | tar  xvz
cp -i cockroach-v19.1.1.linux-amd64/cockroach /usr/local/bin
mkdir /var/lib/cockroach
useradd cockroach
chown cockroach /var/lib/cockroach
chown -R cockroach:cockroach $COCKROACHDB_PATH

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
  AZ_VMSS_ALL_INSTANE_PRIVATE_IP=$PRIVATE_IP,$AZ_VMSS_ALL_INSTANCE_PRIVATE_IP
done
echo $AZ_VMSS_ALL_INSTANCE_PRIVATE_IP

# start cockroach db
# use the list of vmss in the start script
cockroach start --insecure --listen-addr=$AZ_VMSS_INSTANCE_PRIVATE_IP --join=$AZ_VMSS_ALL_INSTANCE_PRIVATE_IP --store=$COCKROACHDB_PATH --background

echo done  
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 
