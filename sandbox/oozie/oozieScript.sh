#!/bin/bash

echo ""
cat /etc/hosts
echo ""

if [ $? ]; then
        echo "Contents of /etc/hosts file retrieved Successfully."
        echo ""
else
        echo "Failed to retrieve the contents of the /etc/hosts file."
        echo ""
fi
