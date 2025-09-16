# Enforce strict error handling
Set-StrictMode -Version Latest

# Variables
$subscriptionId = "391c8a4e-5460-4de0-947c-c60eb3dd48ef"
$resourceGroupName = "RG-CSOC-LOGGING"
$policyDefinitionId = "/subscriptions/391c8a4e-5460-4de0-947c-c60eb3dd48ef/providers/Microsoft.Authorization/policyDefinitions/aefee340-2977-4677-80e9-d20660ef4720"
$diagSettingName = "CS-pgdiag"
$requiredCategories = @("PostgreSQLLogs", "PostgreSQLFlexSessions")

# Disable autosave for Az context
Disable-AzContextAutosave -Scope Process

# Authenticate with Managed Identity
Write-Output "Authenticating using Managed Identity..."
$context = (Connect-AzAccount -Identity).Context
Set-AzContext -SubscriptionId $subscriptionId -DefaultProfile $context

# Locate the destination storage account in CSOC logging RG
Write-Output "Fetching storage account from ${resourceGroupName}..."
$storage = Get-AzStorageAccount -ResourceGroupName $resourceGroupName | Select-Object -First 1
if (-not $storage) {
    throw "No storage account found in ${resourceGroupName}."
}
$storageId = $storage.Id
Write-Output "Using destination storage account: $($storage.StorageAccountName)"

# Retrieve non-compliant PostgreSQL flexible servers from policy states
Write-Output "Querying policy state for non-compliant PostgreSQL servers..."
$policyStates = Get-AzPolicyState | Where-Object {
    $_.PolicyDefinitionId -eq $policyDefinitionId -and
    $_.ComplianceState -eq "NonCompliant" -and
    $_.ResourceType -eq "Microsoft.DBforPostgreSQL/flexibleServers"
}

if (-not $policyStates) {
    Write-Output "No non-compliant PostgreSQL servers found."
    return
}

# Enable diagnostics for each PostgreSQL server
foreach ($state in $policyStates) {
    $serverId = $state.ResourceId
    $serverName = ($serverId -split "/")[-1]

    Write-Output "Processing PostgreSQL server: ${serverName}"

    # Check existing diagnostic settings
    $existing = Get-AzDiagnosticSetting -ResourceId $serverId -ErrorAction SilentlyContinue
    if ($existing -and $existing.Name -eq $diagSettingName) {
        Write-Output "Diagnostic setting '${diagSettingName}' already exists for ${serverName}, skipping."
        continue
    }

    # Create log settings objects
    $logSettings = @()
    foreach ($category in $requiredCategories) {
        $logSettings += New-AzDiagnosticSettingLogSettingsObject -Category $category -Enabled $true
    }

    # Proceed with creation — do not delete or modify existing configurations
    Write-Output "Creating diagnostic setting '${diagSettingName}' for ${serverName}..."

    try {
        New-AzDiagnosticSetting -Name $diagSettingName `
            -ResourceId $serverId `
            -StorageAccountId $storageId `
            -Log $logSettings

        Write-Output "Enabled diagnostic setting '${diagSettingName}' for ${serverName}"
    }
    catch {
        Write-Warning "Failed to configure diagnostics for ${serverName}: $($_.Exception.Message)"
    }
}
