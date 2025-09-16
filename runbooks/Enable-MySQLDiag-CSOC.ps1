# Enforce strict error handling
Set-StrictMode -Version Latest

# Variables
$subscriptionId = "391c8a4e-5460-4de0-947c-c60eb3dd48ef"
$resourceGroupName = "RG-CSOC-LOGGING"
$policyDefinitionId = "/subscriptions/391c8a4e-5460-4de0-947c-c60eb3dd48ef/providers/Microsoft.Authorization/policyDefinitions/95914b83-dd45-4cfc-b761-8db7fc57ff26"
$diagSettingName = "CS-mysqldiag"

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

# Get non-compliant MySQL Servers (Flexible and Single) from policy state
Write-Output "Querying non-compliant MySQL Servers for policy definition..."
$policyStates = Get-AzPolicyState | Where-Object {
    $_.PolicyDefinitionId -eq $policyDefinitionId -and
    $_.ComplianceState -eq "NonCompliant" -and
    ($_.ResourceType -eq "Microsoft.DBforMySQL/flexibleServers" -or $_.ResourceType -eq "Microsoft.DBforMySQL/servers")
}

if (-not $policyStates) {
    Write-Output "No non-compliant MySQL Servers found."
    return
}

# Process each non-compliant MySQL server
foreach ($state in $policyStates) {
    $serverId = $state.ResourceId
    $serverName = ($serverId -split "/")[-1]

    Write-Output "Processing MySQL Server: ${serverName}"

    # Check if diagnostic setting already exists
    $existing = Get-AzDiagnosticSetting -ResourceId $serverId -ErrorAction SilentlyContinue
    if ($existing -and $existing.Name -eq $diagSettingName) {
        Write-Output "Diagnostic setting '${diagSettingName}' already exists for ${serverName}, skipping."
        continue
    }

    # Create diagnostic log settings
    $logAudit = New-AzDiagnosticSettingLogSettingsObject -Category "MySqlAuditLogs" -Enabled $true `
        -RetentionPolicyEnabled $false

    $logSlow = New-AzDiagnosticSettingLogSettingsObject -Category "MySqlSlowLogs" -Enabled $false `
        -RetentionPolicyEnabled $false

    # Create diagnostic metric settings
    $metricAll = New-AzDiagnosticSettingMetricSettingsObject -Category "AllMetrics" -Enabled $false `
        -RetentionPolicyEnabled $false

    try {
        New-AzDiagnosticSetting -Name $diagSettingName `
            -ResourceId $serverId `
            -StorageAccountId $storageId `
            -Log $logAudit, $logSlow `
            -Metric $metricAll

        Write-Output "Enabled diagnostic setting '${diagSettingName}' for ${serverName}"

        # Verify setting was applied
        $verify = Get-AzDiagnosticSetting -ResourceId $serverId
        if ($verify.Name -eq $diagSettingName) {
            Write-Output "Verified: Diagnostic setting successfully applied to ${serverName}"
        } else {
            Write-Warning "Diagnostic setting not found after creation for ${serverName}"
        }
    }
    catch {
        Write-Warning "Failed to configure diagnostics for ${serverName}: $($_.Exception.Message)"
    }
}
