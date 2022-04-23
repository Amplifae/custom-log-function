<#
    Title:   Custom Logs Ingestion
    Language:PowerShell
    Version: 1.0
    Author:  Rogier Dijkman
    Last Modified:  04/22/2022

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

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $((Get-Date).ToUniversalTime())"

# Interact with query parameters or the body of the request.
$variables = @{
    workspaceName   = $Request.Query.workspace
    tableName       = $Request.Query.tableName
    format          = $Request.Query.format
    dataInput       = $Request.RawBody
}

$parameters = @{
    workspaceId   = ''
    workspaceKey  = ''
    tableName     = $variables.tableName
    format        = $variables.format
    dataInput     = $variables.dataInput
}

if ([string]::IsNullOrEmpty($variables.tableName)) {
    Write-Host 'No table name has been specified, exit function'
    $response = 'No table name specified'
    break
}

$workspace = Get-Workspace -workspaceName $variables.workspaceName

if ($null -ne $workspace.workspaceKey) {
    Write-Output 'Upload data to workspace'
    $parameters.workspaceId  = $workspace.workspaceId
    $parameters.workspaceKey = $workspace.workspaceKey
} else {
    Write-Host 'Fallback connecting to default workspace'
    $parameters.workspaceId    = $env:workspaceId
    $parameters.workspaceKey   = $env:workspaceKey | ConvertTo-SecureString -AsPlainText -Force
}

$response = Process-Payload @parameters

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding `
    -Name Response `
    -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = $response
        })