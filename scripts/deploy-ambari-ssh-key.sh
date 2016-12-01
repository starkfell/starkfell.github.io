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
            echo -e "./deploy-ambari-ssh-key.sh -u linuxadmin -p DataMein1! -h 'rei-datanode-bo0;rei-datanode-bo1' "\\n
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
