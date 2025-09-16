# Enforce strict error handling
Set-StrictMode -Version Latest

# Variables
$subscriptionId = "391c8a4e-5460-4de0-947c-c60eb3dd48ef"
$resourceGroupName = "RG-CSOC-LOGGING"
$policyDefinitionId = "/subscriptions/391c8a4e-5460-4de0-947c-c60eb3dd48ef/providers/Microsoft.Authorization/policyDefinitions/7ced553c-4726-43d9-8a29-709be6cecb17"

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

# Retrieve non-compliant Blob service resources from policy states
Write-Output "Querying policy state for non-compliant Blob services..."
$policyStates = Get-AzPolicyState | Where-Object {
    $_.PolicyDefinitionId -eq $policyDefinitionId -and
    $_.ComplianceState -eq "NonCompliant" -and
    $_.ResourceType -eq "Microsoft.Storage/storageAccounts/blobServices"
}

if (-not $policyStates) {
    Write-Output "No non-compliant Blob services found."
    return
}

# Enable diagnostics for each Blob service
foreach ($state in $policyStates) {
    $blobServiceId = $state.ResourceId
    $storageAccountName = ($blobServiceId -split "/")[8]
    $diagSettingName = "CS-blobdiag"

    Write-Output "Processing Blob service on: ${storageAccountName}"

    # Check existing diagnostic settings
    $existing = Get-AzDiagnosticSetting -ResourceId $blobServiceId -ErrorAction SilentlyContinue
    if ($existing -and $existing.Name -eq $diagSettingName) {
        Write-Output "Diagnostic setting 'CS-blobdiag' already exists for ${storageAccountName}, skipping."
        continue
    }

    # Proceed with creation — do not delete or modify existing configurations
    Write-Output "Creating diagnostic setting 'CS-blobdiag' for ${storageAccountName}..."

    $log1 = New-AzDiagnosticSettingLogSettingsObject -Category "StorageRead" -Enabled $true
    $log2 = New-AzDiagnosticSettingLogSettingsObject -Category "StorageWrite" -Enabled $true
    $log3 = New-AzDiagnosticSettingLogSettingsObject -Category "StorageDelete" -Enabled $true

    try {
        New-AzDiagnosticSetting -Name $diagSettingName `
            -ResourceId $blobServiceId `
            -StorageAccountId $storageId `
            -Log $log1, $log2, $log3

        Write-Output "Enabled diagnostic setting 'CS-blobdiag' for ${storageAccountName}"
    }
    catch {
        Write-Warning "Failed to configure diagnostics for ${storageAccountName}: $($_.Exception.Message)"
    }
}
