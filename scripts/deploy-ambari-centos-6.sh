#!/bin/bash

# Parse Script Parameters
while getopts ":u:p:h:" opt; do
  case "${opt}" in
        u) # Linux Host Username.
             USERNAME=${OPTARG}
             ;;
        p) # Linux Host Password.
             PASSWORD=${OPTARG}
             ;;
        h) # Hostnames.
             HOSTNAMES=${OPTARG}
             ;;
        \?) # Unrecognised option - show help
            echo -e \\n"Option [-${BOLD}$OPTARG${NORM}] is not allowed. All Valid Options are listed below:"
            echo -e "-u USERNAME                 - Linux Host Username."
            echo -e "-p PASSWORD                 - Linux Host Password."
            echo -e "-h HOSTNAMES                - List of Hosts to work on."
            echo -e "An Example of how to use this script is shown below:"
            echo -e "./deploy-ambari-centos-6.sh -u linuxadmin -p DataMein1! -h 'rei-datanode-bo0;rei-datanode-bo1' "\\n
            exit 2
            ;;
  esac
done
shift $((OPTIND-1))

# Verifying the Script Parameters Values exist.
if [ -z "${USERNAME}" ]; then
    echo "A Linux Host Username must be provided."
    exit 2
fi

if [ -z "${PASSWORD}" ]; then
    echo "A Linux Host Password must be provided."
    exit 2
fi

if [ -z "${HOSTNAMES}" ]; then
    echo "A list of Hostnames must be provided."
    exit 2
fi

# Retrieving the currently color scheme of vim.
VIMCOLOR=$(grep "elflord" '/etc/vimrc')

# Checking if the vim color scheme is set to 'elflord'.
if [[ $VIMCOLOR =~ "elflord" ]]; then
        echo "vim is already configured to use the color scheme 'elflord' system-wide."
else
        # Setting the vim color scheme to 'elflord'.
        SETVIMCOLOR=$(sed -i '$ a :color elflord' '/etc/vimrc')

        if [ $? ]; then
                echo "Successfully changed vim to use the color scheme 'elflord' system-wide."
        else
                echo "Failed to change vim to use the color scheme 'elflord' system-wide."
        fi
fi

# Updating yum.
sudo yum update -y

# Installing NTP Service.
sudo yum install ntp -y

# Installing BIND DNS.
sudo yum install bind bind-utils -y

# Commenting out 'listen-on' to listen on all available interfaces.
sed -e '/listen-on port/ s/^#*/#/' -i /etc/named.conf

# Set allow-query to 'any'.
sed -i -e 's/localhost;/any;/' /etc/named.conf

# Set recursion to 'no'.
sed -i -e 's/recursion yes/recursion no/' /etc/named.conf

# Adding in the first domain directly above the 'include' files.
sed -i -e '/zones/i \
zone "lumadeep.com" IN { \
    type master; \
    file "lumadeep.com.zone"; \
    allow-update { none; }; \
    };' /etc/named.conf

# Creating the BIND Zone File for the domain.
touch file /var/named/lumadeep.com.zone

# Adding one word to match for inserting configuration into the BIND Zone file.
echo "new" >> /var/named/lumadeep.com.zone

# Adding configuration file to the BIND Zone File.
sed -i -e '/new/i \
$TTL 86400 \
@   IN  SOA     ns1.lumadeep.com. root.lumadeep.com. ( \
        2013042201  ;Serial \
        3600        ;Refresh \
        1800        ;Retry \
        604800      ;Expire \
        86400       ;Minimum TTL \
) \
; Specify our primary nameserver \
        IN  NS      ns1.lumadeep.com. \
; Resolve nameserver hostnames to IP, replace with your two droplet IP addresses. \
ns1     IN  A       10.0.1.4 \
 \
; Define hostname -> IP pairs which you wish to resolve \
@       IN  A       10.0.1.4 \
www     IN  A       10.0.1.4' /var/named/lumadeep.com.zone

# Removing the 'new' word from the BIND Zone configuration file.
sed -i '/new/d' /var/named/lumadeep.com.zone

# Adding Static IP Address, Hostname and FQDN to /etc/hosts.
sed -i -e '/127/i 10.0.1.4 rei-ambarisrv-bo.lumadeep.com rei-ambarisrv-bo' /etc/hosts

# Installing OpenSSH Server.
sudo yum install openssh-server -y

# Installing expect.
sudo yum install expect -y

# Downloading the Ambari repository file.
wget -nv http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.1.0/ambari.repo -O /etc/yum.repos.d/ambari.repo

# Installing Ambari Server.
sudo yum install ambari-server -y

# Running setup of the Ambari Server.
sudo ambari-server setup -s

# Starting the Ambari Server.
sudo ambari-server start

# Checking if SSH Key already exists.
if [ -f "/root/.ssh/id_rsa" ]; then
        echo "'id_rsa' already exists in '/root/.ssh'."
else
        echo "Generating a new SSH Key."

        # Creating a new SSH Key.
        ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P ""

        if [ $? -eq 0 ]; then
                echo "Successfully generated a new SSH Private key in '/root/.ssh/id_rsa'."
        else
                echo "Failed to generate new SSH Private Key in '/root/.ssh/id_rsa'."
                exit 2
        fi

        # Adding the SSH Key to the '/root/.ssh/authorized_keys' locally.
        cat "/root/.ssh/id_rsa.pub" >> "/root/.ssh/authorized_keys"

        if [ $? -eq 0 ]; then
                echo "Successfully concatenated the 'id_rsa.pub' to '/root/.ssh/authorized_keys'."
        else
                echo "Failed to concatenate 'id_rsa.pub' to '/root/.ssh/authorized_keys'."
                exit 2
        fi
fi

# Adding HOSTNAMES into the HOSTS Array, using the semi-colon as the delimiter.
HOSTS=$(echo $HOSTNAMES | tr ";" "\n")

# Start of expect section.
for HOST in $HOSTS
do
        # Running Remote Commands on targeted Hosts using expect.
        /usr/bin/expect <<EOD
        # Copying over the 'id_rsa' file to '/tmp/id_rsa' on the Remote Host.
        spawn scp /root/.ssh/id_rsa $USERNAME@$HOST:/tmp/id_rsa

        # Look for RSA Key fingerprint Prompt and send yes to add it.
        expect "continue connecting*" { send "yes\r" ; exp_continue }

        # Look for Password Prompt and send Password.
        expect "*?assword:*" { send "$PASSWORD\r" ; exp_continue }

        # Copying over the 'id_rsa.pub' file to '/tmp/id_rsa.pub' on the Remote Host.
        spawn scp /root/.ssh/id_rsa.pub $USERNAME@$HOST:/tmp/id_rsa.pub

        # Look for RSA Key fingerprint Prompt and send yes to add it.
        expect "continue connecting*" { send "yes\r" ; exp_continue }

        # Look for Password Prompt and send Password.
        expect "*?assword:*" { send "$PASSWORD\r" ; exp_continue }

        # Copying the 'id_rsa' file in the '/tmp' directory to '/root/.ssh/id_rsa' on the Remote Host.
        spawn ssh -t $USERNAME@$HOST "sudo mkdir -p /root/.ssh && sudo cp /tmp/id_rsa /root/.ssh/id_rsa"
        expect "continue connecting*" { send "yes\r" ; exp_continue }
        expect "*?assword:*" { send "$PASSWORD\r" ; exp_continue }
        expect "*?assword*" { send "$PASSWORD\r" ; exp_continue }

        # Copying the 'id_rsa.pub' feil in the '/tmp' diretory to '/root/.ssh/id_rsa.pub' on the Remote Host.
        spawn ssh -t $USERNAME@$HOST "sudo cp /tmp/id_rsa.pub /root/.ssh/id_rsa.pub"
        expect "*?assword:*" { send "$PASSWORD\r" ; exp_continue }
        expect "*?assword*" { send "$PASSWORD\r" ; exp_continue }

        # Adding 'id_rsa.pub' to the 'authorized_keys' on the Remote Host.
        spawn ssh -t $USERNAME@$HOST "sudo bash -c 'cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys'"
        expect "*?assword:*" { send "$PASSWORD\r" ; exp_continue }
        expect "*?assword*" { send "$PASSWORD\r" ; exp_continue }

        # Enabling root login on the Remote Host.
        spawn ssh -t $USERNAME@$HOST "sudo sed -i -e 's/#PermitRootLogin yes/PermitRootLogin without-password/' /etc/ssh/sshd_config"
        expect "continue connecting*" { send "yes\r" ; exp_continue }
        expect "*?assword:*" { send "$PASSWORD\r" ; exp_continue }
        expect "*?assword*" { send "$PASSWORD\r" ; exp_continue }

        # Disabling SELinux and then restarting the Remote Host.
        spawn ssh -t $USERNAME@$HOST "sudo sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config && sudo shutdown now -r"
        expect "continue connecting*" { send "yes\r" ; exp_continue }
        expect "*?assword:*" { send "$PASSWORD\r" ; exp_continue }
        expect "*?assword*" { send "$PASSWORD\r" ; exp_continue }

EOD

# End of expect section.
done

# End of Script
echo "All SSH Keys copied over to Remote Hosts Successfully!"




# Retrieving IP Address.
ifconfig | grep "inet addr:10" | awk '{print $2}' | cut -c 6-13

# Adding Static IP Address, Hostname and FQDN to /etc/hosts.
sed -i -e '/127/i 10.0.1.4 rei-ambarisrv-bo rei-ambarisrv-bo.lumadeep.com' /etc/hosts

# Disable iptables at startup.
chkconfig iptables off

# Stop iptables service.
/etc/init.d/iptables stop

# Disabling Transparent Huge Pages.
echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag

# Disabling Transparent Huge Pages on startup.
sed -i -e '/touch/a \
 \
#disable THP at boot time \
if test -f /sys/kernel/mm/redhat_transparent_hugepage/enabled; then \
        echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled \
fi \
if test -f /sys/kernel/mm/redhat_transparent_hugepage/defrag; then \
        echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag \
fi ' /etc/rc.local

# Update Hostname in /etc/sysconfig/network.
sed -i -e 's/HOSTNAME=rei-ambarisrv-bo/HOSTNAME=rei-ambarisrv-bo.lumadeep.com/' /etc/sysconfig/network
sed -i -e 's/HOSTNAME=rei-datanode-bo0/HOSTNAME=rei-datanode-bo0.lumadeep.com/' /etc/sysconfig/network
sed -i -e 's/HOSTNAME=rei-datanode-bo1/HOSTNAME=rei-datanode-bo1.lumadeep.com/' /etc/sysconfig/network

# Restart network service.
/etc/init.d/network restart

# Set hostname using hostname command. (this will require an auto-answer again for no/yes to ssh key) and standard hostname will no longer resolve for commands.
hostname rei-datanode-bo1.lumadeep.com

# Hosts File
cat /etc/hosts
10.0.1.4 rei-ambarisrv-bo.lumadeep.com rei-ambarisrv-bo
10.0.1.6 rei-datanode-bo0.lumadeep.com rei-datanode-bo0
10.0.1.5 rei-datanode-bo1.lumadeep.com rei-datanode-bo1
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6







# Retrieve the IP Address of the Remote Host
REMOTE_IP=$(ssh root@rei-datanode-bo0 ip addr | grep eth0 | awk '{ print $2 }' | sed -n '2'p | rev | cut -c 4- | rev)

REMOTE_IP=$(ssh $USERNAME@$HOST ip addr | grep eth0 | awk '{ print $2 }' | sed -n '2'p | rev | cut -c 4- | rev)

# Hosts File Line Entry.
HOSTS_FILE_NAMES="$REMOTE_IP $HOST.DOMAIN_NAME $HOST"
HOSTS_FILE_NAMES="$HOSTS_FILE_NAMES\n $REMOTE_IP $HOST.DOMAIN_NAME $HOST"




#!/bin/bash
DOMAIN_NAME="lumadeep.com"
HOSTNAMES="rei-datanode-bo0;rei-datanode-bo1"

# IP Address of Ambari Server.
AMBARI_SERVER_IP=$(ip addr | grep eth0 | awk '{ print $2 }' | sed -n '2'p | rev | cut -c 4- | rev)

# New Hosts File that contains the IP Address, FQDN and Hostname of the Ambari Server at the top.
HOSTS_FILE_NAMES="$AMBARI_SERVER_IP $HOSTNAME.$DOMAIN_NAME $HOSTNAME"

# Adding HOSTNAMES into the HOSTS Array, using the semi-colon as the delimiter.
HOSTS=$(echo $HOSTNAMES | tr ";" "\n")


for HOST in $HOSTS
do
        # Retrieving the IP Address of the Remote Host.
        REMOTE_IP=$(ssh $USERNAME@$HOST ip addr | grep eth0 | awk '{ print $2 }' | sed -n '2'p | rev | cut -c 4- | rev)

        # Adding the Remote Host IP Address, FQDN, and Hostname entry to the modified Hosts File.
        HOSTS_FILE_NAMES=$(echo -e "$HOSTS_FILE_NAMES\n$REMOTE_IP $HOST.$DOMAIN_NAME $HOST")

done


echo "$HOSTS_FILE_NAMES" > /tmp/hosts_file_names.txt

# Adding new line to top of Ambari Server Hosts File.
sed -i '1i\new'  /etc/hosts

# Adding contents of the hosts_file_names.txt file to the Ambari Server Hosts File after the 'new' entry.
sed -i -e '/new/ r /tmp/hosts_file_names.txt' /etc/hosts

# Removing the top line containing 'new'.
sed -i '/new/d' /etc/hosts


for HOST in $HOSTS
do
        # Copying the Hosts File from the Ambari Server and replacing the Hosts Files on the DataNodes using root.
        scp /etc/hosts root@$HOST:/etc/hosts
done

