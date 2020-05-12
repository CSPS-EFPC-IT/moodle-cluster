#!/bin/bash

################################################################################
echo 'Mapping input parameters...'
databaseAdminPassword="$1"
databaseAdminUsername="$2"
databaseMoodlePassword="$3"
databaseMoodleUsername="$4"
fileRepositoryUri="$5"
gateway_publicIp_fqdn="$6"
moodleAdminEmail="$7"
moodleAdminPassword="$8"
moodleAdminUsername="$9"
shift 9
moodle_share_name="$1"
moodle_storageAccount_key="$2"
moodle_storageAccount_name="$3"
paz_networkSecurityGroup_name="$4"
paz_subnet_name="$5"
postgresql_moodleDb_name="$6"
postgresql_name="$7"
redis_name="$8"
redis_primarykey="$9"
shift 9
resourceGroup="$1"
virtualNetwork_name="$2"
webServerAdminPassword="$3"
webServerAdminUsername="$4"
vmName="$5"
vmImageName="$6"
moodleUpgradeKey="$7"

################################################################################
echo 'Echo values for debug purposes...'
echo "databaseAdminPassword = $databaseAdminPassword"
echo "databaseAdminUsername = $databaseAdminUsername"
echo "databaseMoodlePassword = $databaseMoodlePassword"
echo "databaseMoodleUsername = $databaseMoodleUsername"
echo "fileRepositoryUri = $fileRepositoryUri"
echo "gateway_publicIp_fqdn = $gateway_publicIp_fqdn"
echo "moodleAdminEmail = $moodleAdminEmail"
echo "moodleAdminPassword=$moodleAdminPassword"
echo "moodleAdminUsername = $moodleAdminUsername"
echo "moodle_share_name = $moodle_share_name"
echo "moodle_storageAccount_key = $moodle_storageAccount_key"
echo "moodle_storageAccount_name = $moodle_storageAccount_name"
echo "paz_networkSecurityGroup_name = $paz_networkSecurityGroup_name"
echo "paz_subnet_name = $paz_subnet_name"
echo "postgresql_moodleDb_name = $postgresql_moodleDb_name"
echo "postgresql_name = $postgresql_name"
echo "redis_name = $redis_name"
echo "redis_primarykey = $redis_primarykey"
echo "resourceGroup = $resourceGroup"
echo "virtualNetwork_name = $virtualNetwork_name"
echo "webServerAdminPassword = $webServerAdminPassword"
echo "webServerAdminUsername = $webServerAdminUsername"
echo "vmName = $vmName"
echo "vmImageName =$vmImageName"
echo "moodleUpgradeKey = $moodleUpgradeKey"

################################################################################
echo "Creating VM ${vmName}..."
az vm create \
    --name $vmName \
    --resource-group $resourceGroup \
    --size "Standard_D2s_v3" \
    --storage-sku "Premium_LRS" \
    --image "Canonical:UbuntuServer:18.04-LTS:latest" \
    --computer-name "webserver" \
    --admin-username "$webServerAdminUsername" \
    --admin-password "$webServerAdminPassword" \
    --subnet "$paz_subnet_name" \
    --vnet-name "$virtualNetwork_name" \
    --nsg "$paz_networkSecurityGroup_name" \
    --public-ip-address ""

################################################################################
echo "Running VM extension to install moodle..."
az vm extension set \
    --resource-group $resourceGroup \
    --vm-name $vmName \
    --name "CustomScript" \
    --publisher "Microsoft.Azure.Extensions" \
    --version "2.1" \
    --settings \
        "{ \
            \"fileUris\": [ \
                \"$fileRepositoryUri/scripts/install_moodle.sh\", \
                \"$fileRepositoryUri/scripts/update_muc.php\" \
            ] \
        }" \
    --protected-settings \
        "{ \
            \"commandToExecute\": \"sudo ./install_moodle.sh \
                $moodle_storageAccount_name \
                $moodle_storageAccount_key \
                $moodle_share_name \
                $postgresql_name \
                $databaseAdminUsername \
                $databaseAdminPassword \
                $postgresql_moodleDb_name \
                $databaseMoodleUsername \
                $databaseMoodlePassword \
                $gateway_publicIp_fqdn \
                $moodleAdminUsername \
                $moodleAdminPassword \
                $moodleAdminEmail \
                $redis_name \
                $redis_primarykey \
                $moodleUpgradeKey > /var/log/install_moodle.log\" \
         }"

################################################################################
echo "Scheduling VM deprovisioning process..."
az vm run-command invoke \
    --resource-group $resourceGroup \
    --name $vmName \
    --command-id RunShellScript \
    --scripts 'echo "waagent -deprovision+user -force" | at now + 1 minutes'

################################################################################
echo "Waiting for the deprovisioning process to finish..."
sleep 90

################################################################################
echo "Deallocating VM ${vmName}..."
az vm deallocate \
    --resource-group $resourceGroup \
    --name $vmName

################################################################################
echo "Generalizing VM ${vmName}..."
az vm generalize \
    --resource-group $resourceGroup \
    --name $vmName

################################################################################
echo "Creating VM image ${vmImageName}..."
az image create \
    --resource-group $resourceGroup \
    --name "$vmImageName" \
    --source $vmName

################################################################################
echo "Deleting VM ${vmName}..."
az vm delete \
    --resource-group $resourceGroup \
    --name $vmName \
    --yes

################################################################################
echo "Deleting VM Network Interface Card..."
az network nic delete \
    --resource-group $resourceGroup \
    --name $(az network nic list --resource-group $resourceGroup --query "[?contains(name, '$vmName')].name | [0]" -o tsv) \

################################################################################
echo "Deleting VM disk..."
az disk delete \
    --resource-group $resourceGroup \
    --name  $(az disk list --resource-group $resourceGroup --query "[?contains(name, '$vmName')].name | [0]" -o tsv) \
    --yes

################################################################################
echo "Done"
################################################################################