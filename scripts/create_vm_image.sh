#!/bin/bash

# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with exit code $?."' EXIT

################################################################################
echo 'Initialize expected parameters array...'
declare -A parameters=( [applicationFqdn]= \
                        [applicationNetworkSecurityGroupName]= \
                        [applicationSubnetName]= \
                        [databaseAdminPassword]= \
                        [databaseAdminUsername]= \
                        [databaseApplicationDatabaseName]= \
                        [databaseMoodlePassword]= \
                        [databaseMoodleUsername]= \
                        [databaseFqdn]= \
                        [databaseName]= \
                        [fileRepositoryUri]= \
                        [moodleAdminEmail]= \
                        [moodleAdminPassword]= \
                        [moodleAdminUsername]= \
                        [moodleShareName]= \
                        [moodleStorageAccountFilePrimaryEndPoint]= \
                        [moodleStorageAccountKey]= \
                        [moodleStorageAccountName]= \
                        [moodleUpgradeKey]= \
                        [redisHostName]= \
                        [redisName]= \
                        [redisPrimaryKey]= \
                        [resourceGroupName]= \
                        [smtpRelayFqdn]= \
                        [smtpRelayPrivateIp]= \
                        [virtualMachineTags]= \
                        [virtualNetworkName]= \
                        [vmImageName]= \
                        [vmName]= \
                        [webServerAdminPassword]= \
                        [webServerAdminUsername]= )

sortedParameterList=$(echo ${!parameters[@]} | tr " " "\n" | sort | tr "\n" " ");

echo "Mapping input parameter values and checking for extra parameters..."
while [[ ${#@} -gt 0 ]];
do
    key=$1
    value=$2

    ## Test if the parameter key start with "-" and if the parameter key (without the first dash) is in the expected parameter list.
    if [[ ${key} =~ ^-.*$ && ${parameters[${key:1}]+_} ]]; then
        parameters[${key:1}]="$value"
    else
        echo "ERROR: Unexpected parameter: $key"
        extraParameterFlag=true;
    fi

    # Move to the next key/value pair or up to the end of the parameter list.
    shift $(( 2 < ${#@} ? 2 : ${#@} ))
done

echo "Checking for missing parameters..."
for p in $sortedParameterList; do
    if [[ -z ${parameters[$p]} ]]; then
        echo "ERROR: Missing parameter: $p."
        missingParameterFlag=true;
    fi
done

if [[ -z $extraParameterFlag && -z $missingParameterFlag ]]; then
    echo "INFO: No missing or extra parameters."
else
    echo "ERROR: Execution aborted due to missing or extra parameters."
    usage="USAGE: $(basename $0)"
    for p in $sortedParameterList; do
        usage="${usage} -${p} \$${p}"
    done
    echo "${usage}";
    exit 1;
fi

echo 'Echo parameter values for debug purpose...'
for p in $sortedParameterList; do
    echo "DEBUG: $p = \"${parameters[$p]}\""
done

################################################################################
echo "Creating VM ${vmName}..."
az vm create \
    --name "${parameters[vmName]}" \
    --resource-group "${parameters[resourceGroupName]}" \
    --size "Standard_D2s_v3" \
    --storage-sku "Premium_LRS" \
    --image "Canonical:UbuntuServer:18.04-LTS:latest" \
    --computer-name "webserver" \
    --admin-username "${parameters[webServerAdminUsername]}" \
    --admin-password "${parameters[webServerAdminPassword]}" \
    --subnet "${parameters[applicationSubnetName]}" \
    --vnet-name "${parameters[virtualNetworkName]}" \
    --nsg "${parameters[applicationNetworkSecurityGroupName]}" \
    --public-ip-address "" \
    --tags "${parameters[virtualMachineTags]}"

################################################################################
echo "Running VM extension to install moodle..."
az vm extension set \
    --resource-group "${parameters[resourceGroupName]}" \
    --vm-name "${parameters[vmName]}" \
    --name "CustomScript" \
    --publisher "Microsoft.Azure.Extensions" \
    --version "2.1" \
    --settings \
        "{ \
            \"fileUris\": [ \
                \"${parameters[fileRepositoryUri]}/scripts/install_moodle.sh\", \
                \"${parameters[fileRepositoryUri]}/scripts/update_muc.php\" \
            ] \
        }" \
    --protected-settings \
        "{ \
            \"commandToExecute\": \"sudo ./install_moodle.sh \
                -dbServerAdminPassword ${parameters[databaseAdminPassword]} \
                -dbServerAdminUsername ${parameters[databaseAdminUsername]} \
                -dbServerFqdn ${parameters[databaseFqdn]} \
                -dbServerName ${parameters[databaseName]} \
                -fileShareName ${parameters[moodleShareName]} \
                -moodleAdminEmail ${parameters[moodleAdminEmail]} \
                -moodleAdminPassword ${parameters[moodleAdminPassword]} \
                -moodleAdminUsername ${parameters[moodleAdminUsername]} \
                -moodleDbName ${parameters[databaseApplicationDatabaseName]} \
                -moodleDbPassword ${parameters[databaseMoodlePassword]} \
                -moodleDbUsername ${parameters[databaseMoodleUsername]} \
                -moodleFqdn ${parameters[applicationFqdn]} \
                -moodleUpgradeKey ${parameters[moodleUpgradeKey]} \
                -redisHostName ${parameters[redisHostName]} \
                -redisName ${parameters[redisName]} \
                -redisPrimaryKey ${parameters[redisPrimaryKey]} \
                -smtpRelayFqdn ${parameters[smtpRelayFqdn]} \
                -smtpRelayPrivateIp ${parameters[smtpRelayPrivateIp]} \
                -storageAccountEndPoint ${parameters[moodleStorageAccountFilePrimaryEndPoint]} \
                -storageAccountKey ${parameters[moodleStorageAccountKey]} \
                -storageAccountName ${parameters[moodleStorageAccountName]} > /var/log/install_moodle.log 2>&1\" \
         }"

################################################################################
echo "Scheduling VM deprovisioning process..."
az vm run-command invoke \
    --resource-group "${parameters[resourceGroupName]}" \
    --name "${parameters[vmName]}" \
    --command-id RunShellScript \
    --scripts 'echo "waagent -deprovision+user -force" | at now + 1 minutes'

################################################################################
echo "Waiting for the deprovisioning process to finish..."
sleep 90

################################################################################
echo "Deallocating VM ${parameters[vmName]}..."
az vm deallocate \
    --resource-group "${parameters[resourceGroupName]}" \
    --name "${parameters[vmName]}"

################################################################################
echo "Generalizing VM ${parameters[vmName]}..."
az vm generalize \
    --resource-group "${parameters[resourceGroupName]}" \
    --name "${parameters[vmName]}"

################################################################################
echo "Creating VM image ${parameters[vmImageName]}..."
az image create \
    --resource-group "${parameters[resourceGroupName]}" \
    --name "${parameters[vmImageName]}" \
    --source "${parameters[vmName]}"

################################################################################
echo "Deleting VM ${parameters[vmName]}..."
az vm delete \
    --resource-group "${parameters[resourceGroupName]}" \
    --name "${parameters[vmName]}" \
    --yes

################################################################################
echo "Deleting VM Network Interface Card..."
az network nic delete \
    --resource-group "${parameters[resourceGroupName]}" \
    --name $(az network nic list --resource-group "${parameters[resourceGroupName]}" --query "[?contains(name, '${parameters[vmName]}')].name | [0]" -o tsv) \

################################################################################
echo "Deleting VM disk..."
# Based on our observations, VM Disk Names generated by Azure are created using
# the format "[VM Name]-[Disk ID]" and cannot exceed 80 characters in lenght.
# Since the [Disk ID] part is 39 character long, this leaves only 40 characters
# for the [VM Name] part. If the [VM Name] is longer then extra characters are
# truncated so that the Disk Name does not exceed 80 characters. Hence, when
# searching for the VM disk name, we only use the first 40 characters of the VM
# Name.
# Ref: https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftcompute
az disk delete \
    --resource-group "${parameters[resourceGroupName]}" \
    --name  $(az disk list --resource-group "${parameters[resourceGroupName]}" --query "[?contains(name, '${parameters[vmName]:0:40}')].name | [0]" -o tsv) \
    --yes

################################################################################
echo "Done"
################################################################################
trap - EXIT