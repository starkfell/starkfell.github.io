#!/bin/bash

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
sed -i -e '/127/i 10.0.1.4 rei-ambarisrv-bo rei-ambarisrv-bo.lumadeep.com' /etc/hosts

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


# misc
# sed -i -e 's/#PermitRootLogin/PermitRootLogin/' /etc/ssh/sshd_config
#PermitRootLogin yes


