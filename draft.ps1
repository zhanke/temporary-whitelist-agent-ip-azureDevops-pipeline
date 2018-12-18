param (
  [string] $ResGrpName,
  [string] $AppName,
  [string] $SlotName,
  [bool] $IsAdd
)

Function GetResourceTypeAndName($SiteName, $Slot)
{
    $ResourceType = "Microsoft.Web/sites"
    $ResourceName = $SiteName
    if (![string]::IsNullOrEmpty($Slot)) {
        $ResourceType = "$($ResourceType)/slots"
        $ResourceName = "$($ResourceName)/$($Slot)"
    }
    $ResourceType,$ResourceName
}

# Function for adding the IP Address to to the WebApp Properties.
Function AddIpToProperties($properties, $address, $subnetmask) {
    $restrictions = $properties.ipSecurityRestrictions
    
    foreach ($restiction in $restrictions) {
        if($address -eq $restiction.ipAddress)  
        {
            Write-Host "Ip was already added"
            return;
        }
    }

    $restriction = @{}
    $restriction.Add("ipAddress",$address)
    $restriction.Add("subnetMask",$subnetmask) 

    $properties.ipSecurityRestrictions+= $restriction
}

# Function for adding the IP Address to to the WebApp Properties.
Function RemoveIpFromProperties($properties, $address) {
    $restrictions = $properties.ipSecurityRestrictions
    $newRestrictions = @()
    Write-Host("address to remove $($address)")
    foreach ($restiction in $restrictions) {
    Write-Host("source $($restiction.ipAddress)")

        if($address -ne $restiction.ipAddress)  
        {
            $newRestrictions += $restiction
        }
    }

    $properties.ipSecurityRestrictions = $newRestrictions
}

$buildAgentIP = Invoke-RestMethod https://api.ipify.org/?format=json | Select -exp ip
    
Write-Host("Build Agent IP Address: $($buildAgentIP)")

# Get resource type and resource name
$ResourceType,$ResourceName = GetResourceTypeAndName $AppName $SlotName

$r = Get-AzureRmResource -ResourceGroupName $ResGrpName -ResourceType $ResourceType/config -Name $ResourceName/web -ApiVersion 2016-08-01

# Get resource properties for IP restrictions
$properties = $r.Properties
if($properties.ipSecurityRestrictions -eq $null){
    $properties.ipSecurityRestrictions = @()
}

if($IsAdd){
    Write-Host("Adding Build Agent IP Address $($buildAgentIP)")
    AddIpToProperties $properties $buildAgentIP ""
}else{
    Write-Host("Remove Build Agent IP Address $($buildAgentIP)")
    RemoveIpFromProperties $properties $buildAgentIP
}

Set-AzureRmResource -Force -ResourceGroupName  $ResGrpName -ResourceType $ResourceType/config -Name $ResourceName/web -PropertyObject $properties -ApiVersion 2016-08-01

Start-Sleep -s 10
