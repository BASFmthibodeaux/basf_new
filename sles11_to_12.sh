#!/bin/bash


CONF=etc
OLDSLES=mnt
LOG=set_configuration.log
COMMAND=systemctl

##set mountpoint from old sles11 server
mount /dev/$1/root /$OLDSLES/
mount /dev/$1/opt /$OLDSLES/opt/
mount /dev/$1/tmp /$OLDSLES/tmp/
mount /dev/$1/home /$OLDSLES/usr2/local/

##check fstab
echo "FSTAB"
grep -v -f /$CONF/fstab /$OLDSLES/$CONF/fstab > fstab_dif
cat fstab_dif 

##modify passwd file
echo "PASSWD"
grep -v -f /$CONF/passwd /$OLDSLES/$CONF/passwd > pass_dif
cat pass_dif
cp -fr /$CONF/passwd /$CONF/passwd$(date  +%Y%m%d)
echo "#users from sles11" >> /$CONF/passwd
cat pass_dif >> /$CONF/passwd

##modify group file
echo "GROUP"
cp -fr /$CONF/group /$CONF/group$(date  +%Y%m%d)
grep -v -f /$CONF/group /$OLDSLES/$CONF/group > group_dif
cat group_dif
echo "#groups from sles11" >> /$CONF/group
cat group_dif >> /$CONF/group

##check sysctl.conf
echo "SYSCTL"
grep -v \# /$CONF/sysctl.conf >> /$CONF/sles12.sys
grep -v \# /$OLDSLES/$CONF/sysctl.conf >> /$CONF/sles11.sys




##links set and check
find /$OLDSLES -maxdepth 1 -xdev -type l -exec ls -l {} \;
find /$OLDSLES -maxdepth 1 -xdev -type l -exec ls -l {} \;|awk {'print $9 "\t"  $11'}
for link in $(find /mnt -maxdepth 1 -xdev -type l -exec ls -l {} \;|awk {'print $11 "\t"  $9'}|cut -c5-3000);do ln -s $link;done
find /$OLDSLES -maxdepth 1 -xdev -type l -exec ls -l {} \;|awk {'print $11 "\t"  $9'} > linklist
sed -i "s/\/$OLDSLES//" linklist
cat linklist
while read p; do ln -s $p;done < linklist
find / -maxdepth 1 -xdev -type l -exec ls -l {} \;
##fstab sincronisation
cp -fr  /$OLDSLES/$CONF/fstab  /$CONF/fstab$(date  +%Y%m%d)
diff /$CONF/fstab /$CONF/fstab$(date  +%Y%m%d)



#transfer inportant files and configuration
rsync -avz  /$OLDSLES/usr/local/bin/  /usr/local/bin/
rsync -avz  /$OLDSLES/$CONF/ssh/ /$CONF/ssh/
rsync -avz  /$OLDSLES/$CONF/BASFfirewall.d/ /$CONF/BASFfirewall.d/
rsync -avz  /$OLDSLES/root/.ssh/ /root/.ssh/
rsync -avz  /$OLDSLES/$CONF/auto.* /$CONF/
cp -fr  /$OLDSLES/$CONF/resolv.conf  /$CONF/resolv.conf
cp -fr  /$OLDSLES/$CONF/nscd.conf /$CONF/nscd.conf

##set rpcbind user
echo "rpc:x:495:65534:user for rpcbind:/var/lib/empty:/sbin/nologin" >> /$CONF/passwd
echo "root:sles11to12" |chpasswd

#cp -fr  /$OLDSLES/$CONF/services /$CONF/services

rsync -avz  /$OLDSLES/root/scripts/ /root/scripts/
rsync -avz  /$OLDSLES/opt/special/ /opt/special/



#check if oracles DB is installed and running

if [ -f /$OLDSLES/etc/oratab ]
 then
   cp -fr  /$OLDSLES/etc/oratab /etc/oratab
   if  [ -f /$OLDSLES/etc/orainst.loc ]
  then
    cp -fr  /$OLDSLES/etc/orainst.loc /etc/orainst.loc
  else
    echo "there is not orainst.loc"
  fi
 else
   echo "There is not oracle DB installed"
fi
##only for HANA
if [ -d /mnt/var/lib/hdb/ ]
 then
   rsync -av /$OLDSLES/var/lib/hdb/ /var/lib/hdb
 else 
   echo "there is not hana running"
fi  

##setup network
for p in {0..1}
do
if [ -f /etc/sysconfig/network/ifcfg-eth$p ]
 then
   ls -la  /$OLDSLES/etc/sysconfig/network/ifcfg-eth$p
   rsync -avz  /$OLDSLES/etc/sysconfig/network/ /etc/sysconfig/network/ &&
   systemctl restart network
  else
    echo "names are difrent"
 fi
done
##local host set
echo 'ypserver localhost' > /etc/yp.conf
echo 'basfad.basf.net' > /etc/defaultdomain
domainname $( cat /etc/defaultdomain )

##set hostname
hostnamectl set-hostname $2
#set corect services boot with OS
systemctl enable rpcbind && systemctl restart rpcbind
systemctl enable nscd && systemctl restart nscd
systemctl enable ypbind && systemctl restart ypbind
systemctl enable vasd && systemctl restart vasd
systemctl enable vasypd && systemctl restart vasypd
systemctl enable autofs && systemctl restart autofs
