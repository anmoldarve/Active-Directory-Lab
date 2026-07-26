<#
.SYNOPSIS
    Health check for the lab domain controller.
.DESCRIPTION
    Validates the services a domain depends on, in the order they actually fail:
    AD DS running, DNS resolving, the DC pointing at itself for DNS, SYSVOL and
    NETLOGON shared, DHCP scope active, and time in sync.

    Written the way a service desk health check should be -- each test prints
    PASS or FAIL with the reason, and nothing stops the run.
.EXAMPLE
    .\Test-LabHealth.ps1
#>
[CmdletBinding()]
param(
    [string] $DomainName    = 'lab.local',
    [string] $ExpectedDcIp  = '192.168.10.10'
)

$results = @()

function Add-Result {
    param($Name, $Passed, $Detail)
    $script:results += [pscustomobject]@{
        Test   = $Name
        Result = if ($Passed) { 'PASS' } else { 'FAIL' }
        Detail = $Detail
    }
}

Write-Host "`n=== Lab health check: $DomainName ===`n" -ForegroundColor Cyan

# 1. AD DS service
try {
    $ntds = Get-Service -Name NTDS -ErrorAction Stop
    Add-Result 'AD DS service (NTDS)' ($ntds.Status -eq 'Running') "Status: $($ntds.Status)"
} catch {
    Add-Result 'AD DS service (NTDS)' $false 'Service not found -- is this the DC?'
}

# 2. DNS Server service
try {
    $dns = Get-Service -Name DNS -ErrorAction Stop
    Add-Result 'DNS Server service' ($dns.Status -eq 'Running') "Status: $($dns.Status)"
} catch {
    Add-Result 'DNS Server service' $false 'Service not found'
}

# 3. Static IP -- a DC on DHCP causes intermittent auth failures
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -eq $ExpectedDcIp }).PrefixOrigin
Add-Result 'DC has static IP' ($ip -eq 'Manual') "PrefixOrigin: $ip (expected Manual)"

# 4. DC points at itself for DNS -- the single most common lab break
$dnsServers = (Get-DnsClientServerAddress -AddressFamily IPv4 |
               Where-Object { $_.ServerAddresses }).ServerAddresses
Add-Result 'DC uses itself for DNS' ($dnsServers -contains $ExpectedDcIp) `
           "Configured: $($dnsServers -join ', ')"

# 5. Forward lookup zone exists
try {
    $zone = Get-DnsServerZone -Name $DomainName -ErrorAction Stop
    Add-Result 'Forward lookup zone' $true "Zone type: $($zone.ZoneType)"
} catch {
    Add-Result 'Forward lookup zone' $false "No zone named $DomainName"
}

# 6. Domain resolves
try {
    $null = Resolve-DnsName -Name $DomainName -ErrorAction Stop
    Add-Result 'Domain name resolves' $true "$DomainName resolved"
} catch {
    Add-Result 'Domain name resolves' $false 'Resolution failed'
}

# 7. SYSVOL and NETLOGON shared -- without these, GPO never applies
$shares = (Get-SmbShare -ErrorAction SilentlyContinue).Name
Add-Result 'SYSVOL shared'   ($shares -contains 'SYSVOL')   "Shares: $($shares -join ', ')"
Add-Result 'NETLOGON shared' ($shares -contains 'NETLOGON') ''

# 8. DHCP scope active
try {
    $scopes = Get-DhcpServerv4Scope -ErrorAction Stop
    $active = $scopes | Where-Object { $_.State -eq 'Active' }
    Add-Result 'DHCP scope active' ([bool]$active) `
               "$($scopes.Count) scope(s), $($active.Count) active"
} catch {
    Add-Result 'DHCP scope active' $false 'DHCP role not installed or no scope'
}

# 9. Time source -- Kerberos fails past a 5 minute skew
$timeSource = (w32tm /query /source) 2>&1
Add-Result 'Time source configured' ($LASTEXITCODE -eq 0) "Source: $timeSource"

# --- output -------------------------------------------------------------
$results | Format-Table -AutoSize

$failed = ($results | Where-Object Result -eq 'FAIL').Count
if ($failed -eq 0) {
    Write-Host "All $($results.Count) checks passed.`n" -ForegroundColor Green
} else {
    Write-Host "$failed of $($results.Count) checks FAILED.`n" -ForegroundColor Red
}
