#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Creates the OU structure for the lab.local domain.
.DESCRIPTION
    Builds a top-level LAB OU with child OUs for Users, Computers, Groups and
    Service Accounts. Separating objects into OUs is what makes targeted Group
    Policy possible -- you cannot link a GPO to the default CN=Users container.
.EXAMPLE
    .\New-LabOUStructure.ps1
.EXAMPLE
    .\New-LabOUStructure.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $RootOuName = 'LAB'
)

$ErrorActionPreference = 'Stop'
$domainDN = (Get-ADDomain).DistinguishedName
Write-Verbose "Domain DN: $domainDN"

$rootPath = "OU=$RootOuName,$domainDN"

$structure = @(
    @{ Name = $RootOuName       ; Path = $domainDN }
    @{ Name = 'Users'           ; Path = $rootPath }
    @{ Name = 'Computers'       ; Path = $rootPath }
    @{ Name = 'Groups'          ; Path = $rootPath }
    @{ Name = 'ServiceAccounts' ; Path = $rootPath }
)

foreach ($ou in $structure) {
    $dn = "OU=$($ou.Name),$($ou.Path)"

    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Host "[SKIP] Already exists: $dn" -ForegroundColor DarkGray
        continue
    }

    if ($PSCmdlet.ShouldProcess($dn, 'Create OU')) {
        # ProtectedFromAccidentalDeletion defaults to $true -- left on deliberately.
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path
        Write-Host "[ OK ] Created: $dn" -ForegroundColor Green
    }
}

Write-Host "`nOU structure complete." -ForegroundColor Cyan
