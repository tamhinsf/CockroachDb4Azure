# Log parameters passed to this script. 
echo $@ 

# Basic info
date 
whoami 

# Store parameters passed to this script
NUM_OF_DATA_DISKS=${1}

# Set the /cockroach-data data disk path
COCKROACHDB_PATH=/cockroach-data

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
# wget -qO- https://raw.githubusercontent.com/cockroachdb/docs/master/_includes/v19.1/prod-deployment/insecurecockroachdb.service > /etc/systemd/system/insecurecockroachdb.service 
# systemctl start insecurecockroachdb
cockroach start --insecure --listen-addr='hostname' --background

echo done  
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 
