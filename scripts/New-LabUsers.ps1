#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
    Bulk-creates domain users from a CSV and adds them to security groups.
.DESCRIPTION
    Reads a CSV of new starters, creates each user in the LAB\Users OU, and adds
    them to the security group named in the CSV, creating the group if missing.

    This is the lab equivalent of a real onboarding process: one source of truth
    in, consistent accounts out, no manual clicking through ADUC.
.PARAMETER CsvPath
    Path to the CSV. Required columns:
    FirstName, LastName, SamAccountName, JobTitle, Department, Group
.EXAMPLE
    .\New-LabUsers.ps1 -CsvPath .\users.csv
.EXAMPLE
    .\New-LabUsers.ps1 -CsvPath .\users.csv -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string] $CsvPath,

    [string] $RootOuName = 'LAB',

    [securestring] $InitialPassword = (ConvertTo-SecureString 'LabP@ssw0rd!23' -AsPlainText -Force)
)

$ErrorActionPreference = 'Stop'
$domainDN = (Get-ADDomain).DistinguishedName
$dnsRoot  = (Get-ADDomain).DNSRoot
$usersOU  = "OU=Users,OU=$RootOuName,$domainDN"
$groupsOU = "OU=Groups,OU=$RootOuName,$domainDN"

$rows = Import-Csv -Path $CsvPath
Write-Host "Loaded $($rows.Count) rows from $CsvPath`n" -ForegroundColor Cyan

foreach ($row in $rows) {

    $sam = $row.SamAccountName

    # --- create the user -------------------------------------------------
    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Host "[SKIP] User already exists: $sam" -ForegroundColor DarkGray
    }
    elseif ($PSCmdlet.ShouldProcess($sam, 'Create AD user')) {
        New-ADUser `
            -Name                  "$($row.FirstName) $($row.LastName)" `
            -GivenName             $row.FirstName `
            -Surname               $row.LastName `
            -SamAccountName        $sam `
            -UserPrincipalName     "$sam@$dnsRoot" `
            -DisplayName           "$($row.FirstName) $($row.LastName)" `
            -Title                 $row.JobTitle `
            -Department            $row.Department `
            -Path                  $usersOU `
            -AccountPassword       $InitialPassword `
            -ChangePasswordAtLogon $true `
            -Enabled               $true

        Write-Host "[ OK ] Created user: $sam" -ForegroundColor Green
    }

    # --- ensure the security group exists --------------------------------
    $groupName = $row.Group
    if (-not (Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($groupName, 'Create security group')) {
            New-ADGroup -Name $groupName -GroupScope Global -GroupCategory Security -Path $groupsOU
            Write-Host "[ OK ] Created group: $groupName" -ForegroundColor Green
        }
    }

    # --- add the membership ----------------------------------------------
    if ($PSCmdlet.ShouldProcess("$sam -> $groupName", 'Add group member')) {
        Add-ADGroupMember -Identity $groupName -Members $sam -ErrorAction SilentlyContinue
        Write-Host "[ OK ] $sam added to $groupName" -ForegroundColor Green
    }
}

Write-Host "`nUser provisioning complete." -ForegroundColor Cyan
