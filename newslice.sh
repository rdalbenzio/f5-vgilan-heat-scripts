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

vnfname=$1-SLICE$vnfnumber

cluster_ip=(`openstack stack output show $1 mgmt_ip -c output_value -f value`)
floating_ip=(`openstack stack output show $1 mgmt_floating_ip -c output_value -f value`)

echo Creating a new VE from cluster $1 with IP $cluster_ip
openstack stack create -t f5_vnf.yaml -e testHA.yaml --parameter ve_name=$vnfname --parameter cluster_peer_address=$cluster_ip --wait $vnfname 

vnf_ipaddress=(`openstack stack output show $vnfname network_1_ip -c output_value -f value`)
vnf_ipreturn=(`openstack stack output show $vnfname network_2_ip -c output_value -f value`)
echo Modifying scalout pools adding $vnf_ipaddress on subs side and $vnf_ipreturn on internet side 

#scalout pool
curl -sk -u admin:admin -X POST -H "Content-type: application/json" -d '{"name":"/scaleout/'$vnfname':0","address":"'$vnf_ipaddress'"}' https://$floating_ip/mgmt/tm/ltm/pool/~scaleout~vnf/members | python -m json.tool

#return pool with static route for CARP consistency and a dedicated monitor per pool with gateway-icmp toward network_2
curl -sk -u admin:admin -X POST -H "Content-type: application/json" -d '{ "name": "mon-'$vnfname'","partition": "dag-out","destination": "'$vnf_ipreturn':*" }' https://$floating_ip/mgmt//tm/ltm/monitor/gateway-icmp | python -m json.tool
curl -sk -u admin:admin -X POST -H "Content-type: application/json" -d '{"name":"/dag-out/'$vnfname':0","address":"'$vnf_ipaddress'","monitor": "mon-'$vnfname'"}' https://$floating_ip/mgmt/tm/ltm/pool/~dag-out~vnf-out/members | python -m json.tool
curl -sk -u admin:admin -X POST -H "Content-type: application/json" -d '{ "name": "'$vnfname'","partition": "dag-out","gw": "'$vnf_ipreturn'","network":"'$vnf_ipaddress'/32" }' https://$floating_ip/mgmt/tm/net/route | python -m json.tool

