#!/bin/bash
# This script needs to live on the Nitro ESM node (not a receiver).
# To run the script, SSH to the ESM and login with the admin or root 
# user. Then navigate to the location of the script.
# (example: /tmp/tcpdump_siemlogging.sh) Type "./tcpdump_siemlogging.sh" 
# without quotes to start the script. When you choose a receiver, the program
# will start another SSH session on that receiver. No need to provide credentials 
# becuase you are logged in with the admin or root account already. Then 
# tcpdump is run from the receiver to capture any traffic from the logsource
# you input.
# the "echo" lines below contained a SIEM receiver and it's IP address
# enclosed in parenthesis. That way you have a reference for your choices
# each time you run the script.
echo "receiver1 8.8.8.1"
echo "receiver2 8.8.8.2"
echo "receiver3 8.8.8.3"
echo "receiver4 8.8.8.4"
echo "receiver5 8.8.8.5"

    read -p "Enter IP address of logsource : " logsource
    read -p "Enter IP address of Nitro Receiver : " receiver
echo "You chose to see if $logsource is sending logs to $receiver"
    newfile="$logsource.pcap"
    cd /root/tmp
    touch /root/tmp/$newfile
while true
do
    ssh -o ConnectTimeout=300 root@$receiver tcpdump -U -vvvnnA src host $logsource -w /tmp/$newfile & pid=$! && tcpdump -qns 0 -A -r $newfile | cat >> $newfile.txt
    sleep 2m
    kill $pid
    scp -r root@$receiver:/tmp/$newfile /root/tmp/

done
