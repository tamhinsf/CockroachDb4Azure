#!/bin/sh

# install Azure CLI
sudo apt-get update 
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash 

# Create a cockroach user
COCKROACH_USER=cockroach
COCKROACH_USER_HOME=/home/cockroach
useradd -m -d $COCKROACH_USER_HOME -s /bin/bash $COCKROACH_USER

# Set the variable COCKROACHDB_PATH to the default, re-use it in this script 
COCKROACHDB_PATH=/cockroach-data
mkdir $COCKROACHDB_PATH 

# Discover number of data disks and format as a RAID 0 if greater than 1
apt-get install lsscsi -y 
DEVICE_LIST=`lsscsi |grep -v "/dev/sda \|/dev/sdb \|/dev/sr0 " | cut -d "/" -f3`
DEVICE_COUNT=`echo $DEVICE_LIST | wc -l `
DEVICE_NAME_STRING=
if [ $DEVICE_COUNT -eq 1 ]; then
  mkfs -F -t ext4 /dev/sdc 
  echo "UUID=`blkid -s UUID /dev/sdc | cut -d '"' -f2` $COCKROACHDB_PATH ext4  defaults,discard 0 0" | tee -a /etc/fstab 
else
for device in $DEVICE_LIST; do
   DEVICE_NAME_STRING_TMP=`echo /dev/$device`
   DEVICE_NAME_STRING=`echo $DEVICE_NAME_STRING $DEVICE_NAME_STRING_TMP`
done
  mdadm --create /dev/md0 --level 0 --raid-devices=$NUM_OF_DATA_DISKS $DEVICE_NAME_STRING 
  mkfs -F -t ext4 /dev/md0 
  echo "UUID=`blkid -s UUID /dev/md0 | cut -d '"' -f2` $COCKROACHDB_PATH ext4  defaults,discard 0 0" | tee -a /etc/fstab 
fi

mount $COCKROACHDB_PATH
chown -R $COCKROACH_USER:$COCKROACH_USER $COCKROACHDB_PATH

# install coackroach db
wget -qO- https://binaries.cockroachdb.com/cockroach-v20.1.4.linux-amd64.tgz | tar  xvz
cp -i cockroach-v20.1.4.linux-amd64/cockroach /usr/local/bin/
mkdir /var/lib/cockroach
chown -R $COCKROACH_USER:$COCKROACH_USER /var/lib/cockroach

# install jq
sudo apt install jq -y

# put startup script in home directory
cp vmssCrdbStartup.sh $COCKROACH_USER_HOME
chmod u+rx $COCKROACH_USER_HOME/vmssCrdbStartup.sh

# put system service into startup directory
cp cockroachdb.service /etc/systemd/system
chmod g+r /etc/systemd/system/cockroachdb.service 

# clean up permissions
chown -R $COCKROACH_USER:$COCKROACH_USER $COCKROACH_USER_HOME
chmod -R o-rwx $COCKROACH_USER_HOME
chmod -R g+s $COCKROACH_USER_HOME

systemctl enable cockroachdb
systemctl start cockroachdb

# Exit script with 0 code to tell Azure that the deployment is done
exit 0 
