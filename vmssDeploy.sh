# Log parameters passed to this script. 
echo $@ 

# Basic info
date 
whoami 

# Store parameters passed to this script
NUM_OF_DATA_DISKS=${1}
KEYVAULT_NAME=${2}

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

# Set the variable COCKROACHDB_PATH to the default, re-use it in this script 
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
wget -qO- https://binaries.cockroachdb.com/cockroach-v19.1.2.linux-amd64.tgz | tar  xvz
cp -i cockroach-v19.1.2.linux-amd64/cockroach /usr/local/bin
useradd cockroach
chown cockroach /var/lib/cockroach
chown -R cockroach:cockroach $COCKROACHDB_PATH

# prep for cockroach db certs
COCKROACHDB_CERTS_PATH=$COCKROACHDB_PATH/certs
mkdir $COCKROACHDB_CERTS_PATH
chmod -R go-rwx $COCKROACHDB_CERTS_PATH

# install jq
sudo apt install jq -y

echo done  
# Exit script with 0 code to tell Azure that the deployment is done
exit 0 
