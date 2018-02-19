#!/bin/bash

function usage {
echo Usage: $0 -n slicenumber STACK
echo
exit 1
}

if [[ $# -ne 3 ]]; then
        usage
fi


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "n:" opt; do
  case "${opt}" in
        n)
          vnfnumber=${OPTARG}
          ;;

  \?)
          echo "Invalid option: -$OPTARG" >&2
          usage
    ;;
  :)
          echo "Option -$OPTARG requires an argument." >&2
          usage
    ;;
  esac
done

shift $((OPTIND-1))

if [[ -z "${opt}" ]]; then
  usage
fi

vnfname=$1-LBS$vnfnumber


echo s1 $1
echo vnfname is $vnfname

cluster_ip=(`heat output-show $1 mgmt_ip`) 
floating_ip=(`heat output-show $1 mgmt_floating_ip`)
vnf_ip=(`heat output-show $vnfname mgmt_ip`)

echo cluster ip is $cluster_ip
echo floating is $floating_ip

heat stack-delete --yes "$vnfname"

curl1="curl -sk -u admin:admin -X DELETE -H \"Content-type: application/json\"  https://$floating_ip/mgmt/tm/ltm/pool/~vnf~lbsout/members/$vnfname:0"
curl2="curl -sk -u admin:admin -X DELETE -H \"Content-type: application/json\"  https://$floating_ip/mgmt/tm/ltm/node/~vnf~$vnfname"
echo $curl1
echo $curl2
$curl1
$curl2

#revoke license
curl -sk -u admin:admin -X POST -H "Content-type: application/json" -d '{"licensePoolName": "25_best_pool_recyclable_30_day", "command": "revoke", "address": "'$vnf_ip'", "user": "admin", "password": "admin"}' https://10.102.123.203/mgmt/cm/device/tasks/licensing/pool/member-management | python -m json.tool

#remove from the cluster

curl -sk -u admin:admin -X DELETE https://$floating_ip/mgmt/tm/cm/device-group/scaleout/devices/$vnfname.openstack.lab
curl -sk -u admin:admin -X POST -H "Content-type: application/json" -d '{"deviceName":"'$vnfname'.openstack.lab", "command":"run"}'  https://$floating_ip/mgmt/tm/cm/remove-from-trust/

