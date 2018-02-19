#!/bin/bash

function usage {
echo Usage: $0 -n nat_subnets -i keyname STACK
echo
echo  STACK - \(Existing\) HEAT stack name of the vCGNAT deployment
echo  Mandatory OPTIONs: 
echo  "  -n ip1/x,ip2/y,ip3/z   List of all BIG-IP nat subnets (one per AFM VE) with decimal number mask"
echo  "  -i keyname   		Openstack inserted F5 VE tenant key, for SSH configuration"
exit 1
}

if [[ $# -ne 5 ]]; then
        usage
fi


# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "n:i:" opt; do
  case "${opt}" in
	n)
#	  echo " -n was triggered. Argument $OPTARG, and other arg $2"
	  subn=${OPTARG}
	  ;;
        i)
	  f5key=${OPTARG}
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


echo s1  $1
echo nat_subnets $subn
echo f5key $f5key

# Create arrays from the input plus the openstack vCGNAT stack outputs
nat_subnets=(${subn//,/ })


ltm_mgmt_ips=(`heat output-show $1 ltm_mgmt_ips`) 
afm_mgmt_ips=(`heat output-show $1 afm_mgmt_ips`)

## ltm_afm_pool_members is good as a string, instead of array, since it is the same for all LTMs

ltm_afm_pool_members=`heat output-show $1 ltm_afm_pool_members`

# Verify array lengths restrictions

if [ ${#afm_mgmt_ips[@]} -ne ${#nat_subnets[@]} ]; then
	echo "OS ERROR: Number of subnets in -n argument (now  ${#nat_subnets[@]}) must be equal to number of AFMVEs: ${#afm_mgmt_ips[@]} " 
	exit 1
fi

if [ ${#afm_mgmt_ips[@]} -lt 1 ]; then
	echo "OS ERROR: At least one AFM in deployment"
	exit 1
fi

if [ ${#ltm_mgmt_ips[@]} -lt 1 ]; then
        echo "OS ERROR: At least one LTM in deployment"
        exit 1
fi


for (( i=0; i<${#ltm_mgmt_ips[@]}; i++ ))
do
	heat stack-create -f LTM_for_ITC.yaml -P "ve_instance=${ltm_mgmt_ips[$i]};pm__pool_AFM=$ltm_afm_pool_members" "$1_LTM_${ltm_mgmt_ips[$i]}"
done

for (( i=0; i<${#afm_mgmt_ips[@]}; i++ ))
do
	heat stack-create -f AFM_for_ITC.yaml -P "ve_instance=${afm_mgmt_ips[$i]};nat_subnet=${nat_subnets[$i]}" "$1_AFM_${afm_mgmt_ips[$i]}"
done




