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

cluster_ip=(`openstack stack output show $1 mgmt_ip -c output_value -f value`) 
floating_ip=(`openstack stack output show $1 mgmt_floating_ip -c output_value -f value`)

echo Creating a new VE from cluster $1 with IP $cluster_ip

openstack stack create -t f5_scaleout.yaml -e testscaleoutHA.yaml --parameter ve_name=$vnfname --parameter cluster_peer_address=$cluster_ip --wait $vnfname
vnf_ipaddress=(`openstack stack output show $vnfname network_3_ip -c output_value -f value`)
echo Modifying vnf pools for default route adding $vnf_ipaddress on internet side 

curl -sk -u admin:admin -X POST -H "Content-type: application/json" -d '{"name":"/vnf/'$vnfname':0","address":"'$vnf_ipaddress'"}' https://$floating_ip/mgmt/tm/ltm/pool/~vnf~lbsout/members | python -m json.tool






