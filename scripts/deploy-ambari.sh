############################################################
############################################################

#!/bin/bash
sudo apt-get install openssh-server -y

sudo wget http://public-repo-1.hortonworks.com/ambari/ubuntu14/2.x/updates/2.1.2/ambari.list -O /etc/apt/sources.list.d/ambari.list

sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com B9733A7A07513CAD

sudo apt-get update -y

sudo apt-get install ambari-server -y

sudo apt-get install ntp -y

sudo ambari-server setup -s

sudo ambari-server start



# http://docs.hortonworks.com/HDPDocuments/Ambari-2.2.1.0/bk_Installing_HDP_AMB/content/_set_up_password-less_ssh.html

#!/bin/bash
#
# This script must be ran as 'root'.
#
ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P ""

if [ $? -eq 0 ]; then
        echo "Successfully generated a new SSH Private key in '/root/.ssh/id_rsa'."
else
        echo "Failed to generate new SSH Private Key in '/root/.ssh/id_rsa'."
        exit 2
fi

cat "/root/.ssh/id_rsa.pub" >> "/root/.ssh/authorized_keys"

if [ $? -eq 0 ]; then
        echo "Successfully concatenated the 'id_rsa.pub' to '/root/.ssh/authorized_keys'."
else
        echo "Failed to concatenate 'id_rsa.pub' to '/root/.ssh/authorized_keys'."
        exit 2
fi


scp /root/.ssh/id_rsa linuxadmin@rei-datanode-540:/tmp/id_rsa
scp /root/.ssh/id_rsa.pub linuxadmin@rei-datanode-540:/tmp/id_rsa.pub

scp /root/.ssh/id_rsa linuxadmin@rei-datanode-541:/tmp/id_rsa
scp /root/.ssh/id_rsa.pub linuxadmin@rei-datanode-541:/tmp/id_rsa.pub

ssh linuxadmin@rei-datanode-540 "sudo cp /tmp/id_rsa /root/.ssh/id_rsa"
ssh linuxadmin@rei-datanode-540 "sudo cp /tmp/id_rsa.pub /root/.ssh/id_rsa.pub"
ssh linuxadmin@rei-datanode-540 "sudo bash -c 'cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys'"

ssh linuxadmin@rei-datanode-541 "sudo cp /tmp/id_rsa /root/.ssh/id_rsa"
ssh linuxadmin@rei-datanode-541 "sudo cp /tmp/id_rsa.pub /root/.ssh/id_rsa.pub"
ssh linuxadmin@rei-datanode-541 "sudo bash -c 'cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys'"


sudo bash -c "ssh root@rei-datanode-bo0"
sudo bash -c "ssh root@rei-datanode-bo1"


# After testing, must use paste in private key:

-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAqMClTOeyiB/ID0rtUu0I/nztBn+1kLuKssALKSqnVgtsqZTt
47+9L2otUGMcLny7vQO9OyrpbK/L/TVmEmD0TUnkwx+cUHecGrNnkrhs8xWsOzq1
fqyPDlQIjxK08y3Ye+MJa+kdwjVhKTQHPYxuGRkwcItBPm1zEA0bN8jGZhngcyEi
NGAl0kFVUIQMbSAnM0ILWAIxC9K9CdgDWjpadUf4WVBMrbJrmpVC92uvsLqy2LX1
jPWrJLRvgjt0ubhr7tHt+VbnWY9toiVoL4ohDWQ0jr4zpNSD6Z8wGiV1l/9dhywt
KL/276gDc/PgfAfHgEF7BJDWU4k8HAS8qUsEwwIDAQABAoIBAQCmUwoZnJxYkoqK
mB0FiN8+hT7REvqPpmjz+ViGwKWhpyz4j/NQcGE05H+5JZZXM1WO3KqcMJVVLIfw
D7uFDc58hwJUV0mn/dv8bSr+b4vio0/YKOtN6SIuyyCMc7GppVwj7wgQNfnAuwAC
rmccgNbbIfqeUoKB1zp7bY+QEfGKGwkp1v9VFTMQZJ/KWfiXlthqTybiYt5Cc1cy
5l5Brr9j4SnhJfWJxQ2/aUwiI/y1wTKH0ZIBEnfa93hYVfLRR8NSCx5nh2IHo46U
A4snrQmtqDrt+81xzF0famLznz2MbDXafEJJWFQ4lky/jxtfPfWc8eeO9kFd9Lp5
wT6s2GlRAoGBANcd7XzSOsHKJc8zRhxndCFO5ONRe1ny8CLlgNwzY7pVmpEvo+2F
3UonU/zI4SaIGthQdf0Tcxi3zaUFq0m5FNRyFhTkTqGEuq6xVXbR+/11Cw5TFBxB
osaSEeeRs/lhOHkBBkkRgqiosQeI76S5/B0syFNVoAjtEojDAZNf6o5tAoGBAMjS
9DbNKKHP2NB11i1FfWpi/5BxNaWvwCOuMtxz60D03U+w/niRncpMGCE9KjnrTlA0
OrNCLHq0Lb5BwXtO6QZg+UKcs7UZPN/idwcEAGq/eTWeD2zWBHG/nK7U3HzHMIbz
IMqNqnZflxOskpq1FKByNsDXpsq8cwFRb4+8RCHvAoGAMPJeV0h+lhmpALxp94yS
oAGTkyW3K4Bbo5UU/QW0a3GO+fodEq6i63yHX71Vfa76bL3iGvOR/M3VvPbNQrka
RDyxSY+pVJce4yD2kVK2Q7WeDmRY7xUANK6H5GkCynuUnfPdukKBuF6p6Uz/OjwX
YYwPCOcywtUuom+8rAvnEwECgYEAiv73aLa22MgzGJV2l/7wvyGmISM6LmNmaUu4
iDzzJxJT20R13J1syQfB67+Z6lyi54A+4LN8dbEft/9rGx2Sy4dy/lfXShEdwRfN
ql1qrHe6PRIZOwsmKFSm7ZsGwJZdUAoXOBq1URj4R/W5wrpyfFqQ6whXuRqVvuPO
g32a6qECgYBzWovEdBon1KxM8c/R+TUOt4nmSCnbdafkl3k/bLuScko69Dfh0SCZ
5hQqFisAdwVXDRTdMVNXgmV0XM6MiuxMig5p+DLMT/eGtMKj8JEKISFegHaFVXzj
LEm4aMbDMaT3XMr5wM/0mHipN00lhoRChZ/hW1S5vWAWe5AsPPVywA==
-----END RSA PRIVATE KEY-----
