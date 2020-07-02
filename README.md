# ScalableMoodle
Deployed the required resources in Azure Cloud to operate a scalable Moodle cluster.

# Prerequisites
1. A resource group exist.
1. You have the authorizations required to create resources in the resource group to use.
1. A TLS Certificate for the Application Gateway must exist in a Key Vault.
1. A User Managed Identity must exist.
1. Proper access privileges to the Application Gateway TLS Certificate must be granted to the User Managed Identity.

# Usage

## Step 1 - Create the infrastructure (Part 1/2)

1) Create a new file named *armTemplates/azureDeploy-part1.paramters.json* based on the *armTemplates/azureDeploy-part1.parameters.example.json* file.
1) Edit the new _azureDeploy-part1.paramters.json_ file to your liking.
1) Adapt and run the following commands:\
`deploymentName="MyDeploymentPart1"`\
`resourceGroupName="[Your resource Group name]"`\
`templateFile="armTemplate/azureDeploy-part1.json"`\
`paramterFile="armTemplates/azureDeploy-part1.parameters.json"`\
`az deployment group create --name $deploymentName --resource-group $resourceGroupName --template-file $templateFile --parameter @$parameterFile --verbose`

## Step 2 - Create a virtual machine image from the latest version of Moodle 3.8

1) Adapt and run the following commands:\
`scripts/create_vm_image.sh -applicationFqdn "[Use the application FQDN registered in DNS or the Application Gateway Public IP FQDN as output from part 1]" -applicationNetworkSecurityGroupName "[The application network security name]" -applicationSubnetName "[Use the corresponding value returned as output from part 1]" -databaseAdminPassword="[Use the corresponding value used as input for part 1]" -databaseAdminUsername "[Use the corresponding value used as input for part 1]" -databaseApplicationDatabaseName "[Use the corresponding value output from part 1]" -databaseMoodlePassword "[A secret password]" -databaseMoodleUsername "[A username]" -databaseFqdn "[Use the corresponding value returned as output from part 1]" -databaseName "[Use the corresponding value returned as output from part 1]" -fileRepositoryUri "[Use the corresponding value used  as input from part 1]" -moodleAdminEmail "[An email address]" -moodleAdminPassword "[A secret password]" -moodleAdminUsername "[A username]" -moodleShareName "[Use the corresponding value returned as output from part 1]" -moodleStorageAccountFilePrimaryEndPoint "[Use the corresponding value returned as output from part 1]" -moodleStorageAccountKey "[Use the corresponding value returned as output from part 1]" -moodleStorageAccountName "[Use the corresponding value returned as output from part 1]" -moodleUpgradeKey "[A secret Moodle upgrade key] -redisHostName "[Use the corresponding value returned as output from part 1]" -redisName "[Use the corresponding value returned as output from part 1]" redisPrimaryKey "[Use the corresponding value returned as output from part 1]" -resourceGroupName "The same resource group name used in part 1" -virtualNetworkName "[Use the corresponding value returned as output from part 1]" -vmImageName "[something]-$(date +'%Y%m%dT%H%M%S%Z')-VM-Image" -vmName "[something]-$(date +'%Y%m%dT%H%M%S%Z')-VM" -webServerAdminPassword "[A password]" -webServerAdminUsername "[A username]"`

## Step 3 - Create the infrastructure (Part 2/2)

1) Create a new file named _armTemplates/azureDeploy-part2.paramters.json_ based on the _armTemplates/azureDeploy-part2.parameters.example.json_ file.
1) Edit the new _azureDeploy-part2.paramters.json_ file to your liking.
1) Adapt and Run the following commands:\
`deploymentName="MyDeploymentPart2"`\
`resourceGroupName="[Your resource Group name]"`\
`templateFile="armTemplate/azureDeploy-part2.json"`\
`paramterFile="armTemplates/azureDeploy-part2.parameters.json"`\
`az deployment group create --name MyDeployment-part2 --resource-group $myResourceGroup --template-file armTemplate/azuredeploy-part2.json --parameter armTemplate/azuredeploy-part2.paramters.json --verbose`
