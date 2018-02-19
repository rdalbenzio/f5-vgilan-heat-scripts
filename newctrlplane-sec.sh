#!/bin/bash

function usage {
echo Usage: $0 -n ve_name gilanname

echo
echo  "  -n vnfname   OPENSTACK VE NAME"

exit 1
}

if [[ $# -ne 3 ]]; then
        usage
fi


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "n:i:" opt; do
  case "${opt}" in
        n)
          vnfname=${OPTARG}
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


cluster_ip=(`openstack stack output show $1 mgmt_ip -c output_value -f value`)

echo Creating a new VE from cluster $1 with IP $cluster_ip
openstack stack create -t f5_control_slave.yaml -e ctrlplane.yaml --parameter ve_name=$vnfname --parameter cluster_peer_address=$cluster_ip --wait $vnfname
