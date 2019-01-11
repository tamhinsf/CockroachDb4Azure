# Log activity
LOG_PATH=/tmp/azuredeploy.log

# Log parameters passed to this script. 
echo $@ >> $LOG_PATH 2>&1

# Basic info
date > $LOG_PATH 2>&1
whoami >> $LOG_PATH 2>&1

# Store parameters passed to this script
NUM_OF_DATA_DISKS=${1}

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

# Create the /cockroach-data data disk as a RAID 0
COCKROACHDB_PATH=/cockroach-data

mkdir $COCKROACHDB_PATH >> $LOG_PATH 2>&1
if [ $NUM_OF_DATA_DISKS -eq 1 ]; then
  mkfs -F -t ext4 /dev/sdc >> $LOG_PATH 2>&1
  echo "UUID=`blkid -s UUID /dev/sdc | cut -d '"' -f2` $COCKROACHDB_PATH ext4  defaults,discard 0 0" | tee -a /etc/fstab >> $LOG_PATH 2>&1
else
  apt-get install lsscsi -y >> $LOG_PATH 2>&1
  DEVICE_NAME_STRING=
  for device in `lsscsi |grep -v "/dev/sda \|/dev/sdb \|/dev/sr0 " | cut -d "/" -f3`; do 
   DEVICE_NAME_STRING_TMP=`echo /dev/$device`
   DEVICE_NAME_STRING=`echo $DEVICE_NAME_STRING $DEVICE_NAME_STRING_TMP`
  done
  mdadm --create /dev/md0 --level 0 --raid-devices=$NUM_OF_DATA_DISKS $DEVICE_NAME_STRING >> $LOG_PATH 2>&1
  mkfs -F -t ext4 /dev/md0 >> $LOG_PATH 2>&1
  echo "UUID=`blkid -s UUID /dev/md0 | cut -d '"' -f2` $COCKROACHDB_PATH ext4  defaults,discard 0 0" | tee -a /etc/fstab >> $LOG_PATH 2>&1
fi

mount $COCKROACHDB_PATH

# install coackroach db
wget -qO- https://binaries.cockroachdb.com/cockroach-v2.1.3.linux-amd64.tgz | tar  xvz >> $LOG_PATH 2>&1
cp -i cockroach-v2.1.3.linux-amd64/cockroach /usr/local/bin  >> $LOG_PATH 2>&1
mkdir /var/lib/cockroach >> $LOG_PATH 2>&1
useradd cockroach >> $LOG_PATH 2>&1
chown cockroach /var/lib/cockroach >> $LOG_PATH 2>&1
chown cockroach $COCKROACHDB_PATH >> $LOG_PATH 2>&1
wget -qO- https://raw.githubusercontent.com/cockroachdb/docs/master/_includes/v2.1/prod-deployment/insecurecockroachdb.service > /etc/systemd/system/insecurecockroachdb.service >> $LOG_PATH 2>&1


echo done  >> $LOG_PATH 2>&1
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 >> $LOG_PATH 2>&1
