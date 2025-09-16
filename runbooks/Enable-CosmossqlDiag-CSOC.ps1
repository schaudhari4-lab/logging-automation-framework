# Enforce strict error handling
Set-StrictMode -Version Latest

# Parameters (customize as needed)
$subscriptionId = "391c8a4e-5460-4de0-947c-c60eb3dd48ef"
$resourceGroupName = "RG-CSOC-LOGGING"
$policyDefinitionId = "/subscriptions/391c8a4e-5460-4de0-947c-c60eb3dd48ef/providers/Microsoft.Authorization/policyDefinitions/e7306834-0ff4-4fe4-8074-c25859e41afa"
$diagSettingName = "CS-cosmosqldiag"

# Disable Az context autosave to avoid session issues
Disable-AzContextAutosave -Scope Process

# Authenticate using Managed Identity
Write-Output "Authenticating using Managed Identity..."
$context = (Connect-AzAccount -Identity).Context
Set-AzContext -SubscriptionId $subscriptionId -DefaultProfile $context

# Get Storage Account for diagnostics
Write-Output "Fetching storage account from $resourceGroupName..."
$storage = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | Select-Object -First 1
if (-not $storage) {
    throw "No storage account found in $resourceGroupName."
}
$storageId = $storage.Id
Write-Output "Using storage account: $($storage.StorageAccountName)"

# Get non-compliant Cosmos DB accounts from policy state
Write-Output "Querying non-compliant Cosmos DB accounts for policy definition..."
$policyStates = Get-AzPolicyState -SubscriptionId $subscriptionId | Where-Object {
    $_.PolicyDefinitionId -eq $policyDefinitionId -and
    $_.ComplianceState -eq "NonCompliant" -and
    $_.ResourceType -eq "Microsoft.DocumentDB/databaseAccounts"
}

if (-not $policyStates) {
    Write-Output "No non-compliant Cosmos DB accounts found."
    return
}

# Process each non-compliant Cosmos DB account
foreach ($state in $policyStates) {
    $dbId = $state.ResourceId
    $dbName = ($dbId -split "/")[-1]

    Write-Output "Processing Cosmos DB account: $dbName"

    # Check if diagnostic setting already exists
    $existing = Get-AzDiagnosticSetting -ResourceId $dbId -ErrorAction SilentlyContinue
    if ($existing -and $existing.Name -eq $diagSettingName) {
        Write-Output "Diagnostic setting '$diagSettingName' already exists for $dbName, skipping."
        continue
    }

    # Create diagnostic log configuration
    $logCategories = @("DataPlaneRequests", "TableApiRequests", "ControlPlaneRequests", "MongoRequests")
    $logSettings = @()
    foreach ($category in $logCategories) {
        $logSettings += New-AzDiagnosticSettingLogSettingsObject -Category $category -Enabled $true
    }

    try {
        New-AzDiagnosticSetting -Name $diagSettingName `
            -ResourceId $dbId `
            -StorageAccountId $storageId `
            -Log $logSettings

        Write-Output "Enabled diagnostic setting '$diagSettingName' for $dbName"
    }
    catch {
        Write-Warning "Failed to configure diagnostics for ${dbName}: $($_.Exception.Message)"
    }
}
