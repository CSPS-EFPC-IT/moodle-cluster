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
    
## Step 2 - Create a virtal machine image from the latest version of Moodle 3.8

1) Edit and run the following commands:\
`databaseAdminPassword="[Use the corresponding value used as input for part 1]"`\
`databaseAdminUsername="[Use the corresponding value used as input for part 1]"`\
`databaseMoodlePassword="[A secret password]"`\
`databaseMoodleUsername="[A username]"`\
`fileRepositoryUri="https://raw.githubusercontent.com/CSPS-EFPC-IT/moodle-cluster"`\
`gateway_publicIp_fqdn="[Use the corresponding value returned as output by part 1]"`\
`moodleAdminEmail="[An email address]"`\
`moodleAdminPassword="[A secret password]"`\
`moodleAdminUsername="[A username]"`\
`moodle_share_name="[Use the corresponding value returned as output from part 1]"`\
`moodle_storageAccount_key="[Use the corresponding value returned as output from part 1]"`\
`moodle_storageAccount_name="[Use the corresponding value returned as output from part 1]"`\
`paz_networkSecurityGroup_name="[Use the corresponding value returned as output from part 1]"`\
`paz_subnet_name="[Use the corresponding value returned as output from part 1]"`\
`postgresql_moodleDb_name="[Use the corresponding value returned as output from part 1]"`\
`postgresql_name="[Use the corresponding value returned as output from part 1]"`\
`redis_name="[Use the corresponding value returned as output from part 1]"`\
`redis_primarykey="[Use the corresponding value returned as output from part 1]"`\
`resourceGroup="[Use the corresponding value used as input to part 1]"`\
`virtualNetwork_name="[Use the corresponding value returned as output from part 1]"`\
`webServerAdminPassword="[A secret password]"`\
`webServerAdminUsername="[A username]"`\
`vmName="[A base name for the virtual machine image]"`\
`vmImageName="${vmName}-Image"`\
`scripts/create_vm_image.sh $databaseAdminPassword $databaseAdminUsername $databaseMoodlePassword $databaseMoodleUsername $fileRepositoryUri $gateway_publicIp_fqdn $moodleAdminEmail $moodleAdminPassword $moodleAdminUsername $moodle_share_name $moodle_storageAccount_key $moodle_storageAccount_name $paz_networkSecurityGroup_name $paz_subnet_name $postgresql_moodleDb_name $postgresql_name $redis_name $redis_primarykey $resourceGroup $virtualNetwork_name $webServerAdminPassword $webServerAdminUsername $vmName $vmImageName`

## Step 3 - Create the infrastructure (Part 2/2)

1) Create a new file named _armTemplates/azureDeploy-part2.paramters.json_ based on the _armTemplates/azureDeploy-part2.parameters.example.json_ file.
1) Edit the new _azureDeploy-part2.paramters.json_ file to your liking.
1) Adapt and Run the following commands:\
`deploymentName="MyDeploymentPart2"`\
`resourceGroupName="[Your resource Group name]"`\
`templateFile="armTemplate/azureDeploy-part2.json"`\
`paramterFile="armTemplates/azureDeploy-part2.parameters.json"`\
`az deployment group create --name MyDeployment-part2 --resource-group $myResourceGroup --template-file armTemplate/azuredeploy-part2.json --parameter armTemplate/azuredeploy-part2.paramters.json --verbose`
