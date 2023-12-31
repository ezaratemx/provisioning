#!/bin/bash

print_dot_wait() {
    local seconds=$1
    for ((i=0; i<seconds; i++)); do
        echo -n "."
        sleep 1
    done
    echo
}

waittime=30

for i in "$@"; do
  case $i in
    -ctid=*|--ctid=*)
      CTID="${i#*=}"
      shift # past argument=value
      ;;
    -cthostname=*|--cthostname=*)
      CTHOSTNAME="${i#*=}"
      shift # past argument=value
      ;;
   -ctwanbridge=*|--ctwanbridge=*)
      CTWANBRIDGE="${i#*=}"
      shift # past argument=value
      ;;
   -hostname=*|--hostname=*)
      HOSTNAME="${i#*=}"
      shift # past argument=value
      ;;
   -zoneid=*|--zoneid=*)
      ZONEID="${i#*=}"
      shift # past argument=value
      ;;
   -nameserver=*|--nameserver=*)
      NAMESERVER="${i#*=}"
      shift # past argument=value
      ;;
   -awsapi=*|--awsapi=*)
      AWSAPI="${i#*=}"
      shift # past argument=value
      ;;
   -awskey=*|--awskey=*)
      AWSKEY="${i#*=}"
      shift # past argument=value
      ;;
 -|--*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      ;;
  esac
done

echo -n "Continer ID ${CTID}"
echo -n "Continer Hostname ${CTHOSTNAME}"
echo -n "Container WAN Bridge ${CTWANBRIDGE}"
echo -n "Hostame ${HOSTNAME}"
echo -n "Zone ID ${ZONEID}"
echo -n "Name Server ID${NAMESERVER}"
echo -n "AWS API ${AWSAPI}"
echo -n "AWS API Key ${AWSKEY}"

pct create $CTID /var/lib/vz/template/cache/ubuntu-23.04-standard_23.04-1_amd64.tar.zst\
                 --hostname $CTHOSTNAME\
                 --cores 1\
                 --memory 512\
                 --net0 name=eth0,bridge=$CTWANBRIDGE,firewall=0,ip=dhcp,type=veth\
                 --storage local-lvm\
                 --rootfs local-lvm:8\
                 --unprivileged 1\
                 --ignore-unpack-errors\
                 --ostype ubuntu\
                 --password="Techxagon2025"\
                 --start 1

echo -n "Waiting for $waittime seconds for network up: "
print_dot_wait $waittime
echo "Done waiting"
echo -n "Executing LXC Setup"
echo -n "Executing LXC Update"
lxc-attach -n $CTID -- apt update
lxc-attach -n $CTID -- apt upgrade -y
print_dot_wait 2
clear
echo -n "Installing additional packages"
lxc-attach -n $CTID -- apt install -y unzip
lxc-attach -n $CTID -- apt install -y curl
echo -n "Done installing additional packages"
print_dot_wait 2
clear
echo -n "Installing AWS CLI"
lxc-attach -n $CTID -- wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
lxc-attach -n $CTID -- unzip /root/awscli-exe-linux-x86_64.zip
lxc-attach -n $CTID -- /root/aws/install
echo -n "Done installing AWS CLI"
print_dot_wait 2
clear
echo -n "Setting up Evironment"
lxc-attach -n $CTID -- aws configure set aws_access_key_id "$AWSAPI"
lxc-attach -n $CTID -- aws configure set aws_secret_access_key "$AWSKEY"
lxc-attach -n $CTID -- aws configure set region "us-east-1"
lxc-attach -n $CTID -- aws configure set output "text"
wget https://raw.githubusercontent.com/ezaratemx/provisioning/main/dnsupdate.sh
sed -i "s/XXXX/$HOSTNAME/g" dnsupdate.sh 
sed -i "s/YYYY/$ZONEID/g" dnsupdate.sh
sed -i "s/ZZZZ/$NAMESERVER/g" dnsupdate.sh
pct push $CTID dnsupdate.sh /opt/dnsupdate.sh
lxc-attach -n $CTID -- chmod +x /opt/dnsupdate.sh
lxc-attach -n $CTID -- crontab -l|sed "\$a*/10 * * * * sh /opt/dnsupdate.sh"|crontab -
rm dnsupdate.sh
echo -n "Finished"
echo -n
echo -n
