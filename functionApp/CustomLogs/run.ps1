<#
    Title:   Custom Logs Ingestion
    Language:PowerShell
    Version: 1.0
    Author:  Rogier Dijkman
    Last Modified:  04/08/2022

    DESCRIPTION
    This Function App is used to upload custom data to a log analytics workspace.
    The input can be either JSON or CSV formatted. This function will build the signature and authorization header needed to
    post the data to the Log Analytics workspace via the HTTP Data Connector API.

    The Function App will post each log type to their individual tables in Log Analytics, for example,
    SecureHats_CL
#>

using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

# Interact with query parameters or the body of the request.
$workspaceName = $Request.Query.workspace
$tableName = $Request.Query.tableName
$format = $Request.Query.format
$dataInput = $Request.RawBody

Write-Host "Processing File input"
if ($format -eq 'csv') {
    try {
        Write-Output "Converting file from CSV to Object"
        $dataObject = $dataInput | ConvertFrom-CSV
    }
    catch {
        Write-Output "Unable to process CSV file"
        break
    }
}
else {
    try {
        Write-Output "Converting file from JSON to Object"
        $dataObject = $dataInput | ConvertFrom-JSON
    }
    catch {
        Write-Output "Unable to process JSON file"
        break
    }
}

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
#$rfc1123date = [DateTime]::UtcNow.ToString("r")

try {
    Write-Output "Connecting to workspace [$($WorkspaceName)]"
    $workspace = Get-AzResource `
        -Name "$WorkspaceName" `
        -ResourceType 'Microsoft.OperationalInsights/workspaces'

    $ResourceGroupName = $workspace.ResourceGroupName
    $workspaceName = $workspace.Name
    $workspaceId = (Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $workspaceName).CustomerId.Guid

    Write-Host "Workspace Name: $($workspaceName)"
    Write-Host "Workspace Id: $($workspaceId)"
}
catch {
    Write-Warning -Message "Log Analytics workspace [$($WorkspaceName)] not found in the current context"
    break
}

$workspaceKey = (Get-AzOperationalInsightsWorkspaceSharedKeys `
        -ResourceGroupName $ResourceGroupName `
        -Name $WorkspaceName).PrimarySharedKey `
| ConvertTo-SecureString -AsPlainText -Force

Write-Output 'Upload data to workspace'
$postObject = @{
    "workspaceId"  = $workspaceId
    "workspaceKey" = $workspaceKey
    "tableName"    = $tableName
}
Process-Payload -customData $dataObject -tablename $tableName

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $response
    })