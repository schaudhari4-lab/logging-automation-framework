# Enforce strict error handling
Set-StrictMode -Version Latest

# Variables
$subscriptionId = "391c8a4e-5460-4de0-947c-c60eb3dd48ef"
$resourceGroupName = "RG-CSOC-LOGGING"
$policyDefinitionId = "/subscriptions/391c8a4e-5460-4de0-947c-c60eb3dd48ef/providers/Microsoft.Authorization/policyDefinitions/54d3a201-a3ae-4e5d-9062-2c78922dbb62"
$diagSettingName = "CS-sqldiag"

# Disable Az context autosave to avoid session issues
Disable-AzContextAutosave -Scope Process

# Authenticate via Managed Identity
Write-Output "Authenticating using Managed Identity..."
$context = (Connect-AzAccount -Identity).Context
Set-AzContext -SubscriptionId $subscriptionId -DefaultProfile $context

# Get Storage Account in CSOC logging RG
Write-Output "Fetching storage account from ${resourceGroupName}..."
$storage = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | Select-Object -First 1
if (-not $storage) {
    throw "No storage account found in ${resourceGroupName}."
}
$storageId = $storage.Id
Write-Output "Found storage account: $($storage.StorageAccountName)"

# Get non-compliant SQL databases from policy state
Write-Output "Querying non-compliant SQL databases for policy definition..."
$policyStates = Get-AzPolicyState | Where-Object {
    $_.PolicyDefinitionId -eq $policyDefinitionId -and
    $_.ComplianceState -eq "NonCompliant" -and
    $_.ResourceType -eq "Microsoft.Sql/servers/databases"
}

if (-not $policyStates) {
    Write-Output "No non-compliant SQL databases found."
    return
}

# Process each non-compliant database
foreach ($state in $policyStates) {
    $dbId = $state.ResourceId
    $dbName = ($dbId -split "/")[-1]
    if ($dbName -eq "master") {
        Write-Output "Skipping master database."
        continue
    }

    Write-Output "Processing database: ${dbName}"

    # Check if diagnostic setting already exists
    $existing = Get-AzDiagnosticSetting -ResourceId $dbId -ErrorAction SilentlyContinue
    if ($existing -and $existing.Name -eq $diagSettingName) {
        Write-Output "Diagnostic setting '${diagSettingName}' already exists for ${dbName}, skipping."
        continue
    }

    # Create diagnostic log configuration
    $log1 = New-AzDiagnosticSettingLogSettingsObject -Category "SQLSecurityAuditEvents" -Enabled $true
    $log2 = New-AzDiagnosticSettingLogSettingsObject -Category "Errors" -Enabled $true

    try {
        New-AzDiagnosticSetting -Name $diagSettingName `
            -ResourceId $dbId `
            -StorageAccountId $storageId `
            -Log $log1, $log2

        Write-Output "Enabled diagnostic setting '${diagSettingName}' for ${dbName}"
    }
    catch {
        Write-Warning "Failed to configure diagnostics for ${dbName}: $($_.Exception.Message)"
    }
}
