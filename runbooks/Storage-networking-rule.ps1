# Azure Automation Runbook to Enable Microsoft.Storage Service Endpoint
# and Add Subnets to Storage Firewall in RG-CSOC-LOGGING

# Disable AzContext autosave (important in runbooks)
Disable-AzContextAutosave -Scope Process

# Authenticate with Managed Identity
$AzureContext = (Connect-AzAccount -Identity -AccountId "03e56e91-9b44-44e9-8eb9-bbdef19f7f7a").context
Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

# Input values
$subscriptionId = "391c8a4e-5460-4de0-947c-c60eb3dd48ef"
$storageRG = "RG-CSOC-LOGGING"

# Get the single storage account in the resource group
$storageAccount = Get-AzStorageAccount -ResourceGroupName $storageRG | Select-Object -First 1

# Define list of European regions
$europeRegions = @(
    "northeurope", "westeurope", "swedencentral", "switzerlandnorth", "francecentral",
    "germanywestcentral", "norwayeast", "uksouth", "ukwest", "polandcentral"
)

# Iterate through all resource groups ending with 'cx'
$targetRGs = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*cx" }

foreach ($rg in $targetRGs) {
    $vnets = Get-AzVirtualNetwork -ResourceGroupName $rg.ResourceGroupName | Where-Object {
        $europeRegions -contains $_.Location.ToLower()
    }

    foreach ($vnet in $vnets) {
        $modified = $false

        foreach ($subnet in $vnet.Subnets) {
            if (-not ($subnet.ServiceEndpoints | Where-Object { $_.Service -eq "Microsoft.Storage" })) {
                $subnet.ServiceEndpoints += New-Object -TypeName Microsoft.Azure.Commands.Network.Models.PSServiceEndpoint `
                    -Property @{ Service = "Microsoft.Storage"; Locations = @($vnet.Location) }
                $modified = $true
            }

            # Add subnet to storage account firewall
            try {
                Add-AzStorageAccountNetworkRule -ResourceGroupName $storageRG -Name $storageAccount.StorageAccountName `
                    -VirtualNetworkResourceId $subnet.Id -ErrorAction Stop
            } catch {
                Write-Warning "Failed to add subnet [$($subnet.Name)] in VNet [$($vnet.Name)] to storage account firewall: $_"
            }
        }

        if ($modified) {
            $vnet | Set-AzVirtualNetwork
        }
    }
}

# Restrict public access to selected networks only
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $storageRG -Name $storageAccount.StorageAccountName `
    -DefaultAction Deny -Bypass AzureServices
