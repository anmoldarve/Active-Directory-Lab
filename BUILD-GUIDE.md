# Complete build guide — Active Directory home lab

**Read this before running anything.** Every script in this repo is printed in full
below, so you can check each line before it touches your machine. Nothing here has
been executed or tested by anyone yet — you are the first to run it. Expect at least
one thing to break. That is the point; log it in `docs/03-troubleshooting-log.md`.

**Time:** roughly 6–10 hours spread over two or three sittings.

---

## Contents

- [0. Before you start](#0-before-you-start)
- [1. Create the DC01 virtual machine](#1-create-the-dc01-virtual-machine)
- [2. Install Windows Server](#2-install-windows-server)
- [3. Set the static IP](#3-set-the-static-ip)
- [4. Rename and reboot](#4-rename-and-reboot)
- [5. Install AD DS and DNS](#5-install-ad-ds-and-dns)
- [6. Promote to domain controller](#6-promote-to-domain-controller)
- [7. Verify AD and DNS](#7-verify-ad-and-dns)
- [8. Install DHCP](#8-install-dhcp)
- [9. Create the DHCP scope](#9-create-the-dhcp-scope)
- [10. Build the client VM](#10-build-the-client-vm)
- [11. Join the domain](#11-join-the-domain)
- [12. Create the OU structure (script)](#12-create-the-ou-structure-script)
- [13. Create users and groups (script)](#13-create-users-and-groups-script)
- [14. Create and test a GPO](#14-create-and-test-a-gpo)
- [15. Run the health check (script)](#15-run-the-health-check-script)
- [16. Build the Packet Tracer network](#16-build-the-packet-tracer-network)
- [17. Final verification checklist](#17-final-verification-checklist)
- [18. Troubleshooting reference](#18-troubleshooting-reference)

---

## 0. Before you start

### Downloads

| What | Where | Notes |
|---|---|---|
| VirtualBox | virtualbox.org | Free. VMware Workstation Player also fine |
| Windows Server 2022 ISO | Microsoft Evaluation Center | 180-day eval, no licence needed |
| Windows 11 ISO | Microsoft software download page | Use the Media Creation Tool or direct ISO |
| Cisco Packet Tracer | Cisco NetAcad (free account) | Needs a free Networking Academy signup |

### Host requirements

You are running two VMs at once. Minimum realistically usable:

- 16 GB RAM on the host (8 GB works but will be painful)
- 120 GB free disk
- Virtualisation enabled in BIOS/UEFI — check Task Manager > Performance > CPU,
  it should say "Virtualization: Enabled"

### Two decisions to make now

**Network mode.** Use **Host-only** (VirtualBox) or **Internal Network**. Both VMs
must be on the *same* one or nothing will work. NAT will not do — VMs on NAT cannot
see each other.

If you also want the VMs to reach the internet, add a *second* adapter set to NAT.
Keep the host-only adapter as the primary.

**Naming.** This guide uses `lab.local`. If you pick something else, you must change
it in the scripts and configs too. `.local` is technically discouraged in production
because of mDNS conflicts — worth knowing, and worth mentioning if asked. For a lab
it is fine.

---

## 1. Create the DC01 virtual machine

In VirtualBox: **New**

| Setting | Value |
|---|---|
| Name | `DC01` |
| Type | Microsoft Windows |
| Version | Windows 2022 (64-bit) |
| Memory | 4096 MB (8192 if you can spare it) |
| CPU | 2 cores |
| Disk | 60 GB, dynamically allocated |

Then **Settings > Network > Adapter 1**: set *Attached to* = **Host-only Adapter**.

**Settings > Storage**: click the empty optical drive, choose the Windows Server ISO.

---

## 2. Install Windows Server

Start the VM.

1. Language and keyboard: your preference. **Region: Australia**, keyboard: US or
   English (Australia).
2. **Install now**
3. Edition: **Windows Server 2022 Standard Evaluation (Desktop Experience)**

   Pick Desktop Experience, not Core. Core has no GUI and you want to see ADUC and
   DNS Manager for the screenshots.
4. Accept the licence terms
5. **Custom: Install Windows only (advanced)**
6. Select the 60 GB unallocated space, **Next**
7. Wait through the install and reboot
8. Set the Administrator password. Write it down. There is no reset here.

**Verify:** you can sign in and Server Manager opens automatically.

---

## 3. Set the static IP

A domain controller on DHCP causes intermittent, hard-to-diagnose authentication
failures. This is not optional.

1. Right-click the network icon > **Open Network & Internet settings**
2. **Change adapter options**
3. Right-click Ethernet > **Properties**
4. Select **Internet Protocol Version 4 (TCP/IPv4)** > **Properties**
5. Choose **Use the following IP address**:

   | Field | Value |
   |---|---|
   | IP address | `192.168.10.10` |
   | Subnet mask | `255.255.255.0` |
   | Default gateway | `192.168.10.1` (or blank if host-only with no router) |
   | Preferred DNS server | `192.168.10.10` |

**The DNS server points at itself.** This looks wrong the first time you see it. It
is correct — the DC is going to *be* the DNS server, so it must resolve against
itself. Every other machine in the domain will also point here.

**Verify:**

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Format-Table IPAddress, PrefixOrigin
```

`PrefixOrigin` must say `Manual`. If it says `Dhcp`, the setting did not stick.

---

## 4. Rename and reboot

1. Server Manager > **Local Server**
2. Click the computer name (something like `WIN-A1B2C3D4`)
3. **Change** > Computer name: `DC01` > OK
4. Reboot when prompted

Do this **before** promoting to a domain controller. Renaming a DC afterwards is
possible but messy, and it is exactly the kind of avoidable rework worth mentioning
in your build log.

**Verify:** `hostname` returns `DC01`.

---

## 5. Install AD DS and DNS

1. Server Manager > **Manage** > **Add Roles and Features**
2. Installation type: **Role-based or feature-based installation**
3. Server selection: `DC01` (the only option)
4. Server Roles — tick:
   - **Active Directory Domain Services** → a dialog appears, click **Add Features**
   - **DNS Server** → **Add Features**

   You may get a warning about static IP. If you did step 3 correctly you will not.
5. Features: leave defaults
6. **Install**

This takes a few minutes. Do not close the wizard.

**Verify:**

```powershell
Get-WindowsFeature AD-Domain-Services, DNS | Format-Table Name, InstallState
```

Both should read `Installed`.

---

## 6. Promote to domain controller

1. In Server Manager, click the **yellow warning flag** in the top bar
2. **Promote this server to a domain controller**
3. Deployment operation: **Add a new forest**
4. Root domain name: `lab.local`
5. **Next**
6. Forest and domain functional level: leave at default (Windows Server 2016)
7. Tick **Domain Name System (DNS) server** and **Global Catalog** — both should
   already be ticked
8. **Directory Services Restore Mode (DSRM) password** — set it and **write it down**.
   This is a separate password from the Administrator account. You need it to boot
   into recovery mode.
9. DNS Options: you will see a warning about a delegation for the parent zone not
   being created. **This is expected and safe to ignore** in a lab with no parent
   domain. Click Next.
10. NetBIOS name: `LAB` (auto-filled)
11. Paths: leave defaults
12. Review, then **Install**

The server reboots itself.

**After reboot**, sign in as `LAB\Administrator` — note the sign-in screen now shows
the domain prefix. That is your first confirmation it worked.

---

## 7. Verify AD and DNS

Open **Active Directory Users and Computers** (Server Manager > Tools > ADUC).

You should see `lab.local` with default containers: Builtin, Computers, Domain
Controllers, Users.

Open **DNS Manager** (Tools > DNS). Expand `DC01 > Forward Lookup Zones`. You should
see:

- `_msdcs.lab.local`
- `lab.local`

Inside `lab.local` there should be `_tcp`, `_udp`, `_sites`, `_msdcs` folders. Those
contain the **SRV records** that let clients find a domain controller. If they are
missing, domain join will fail later with a confusing error, so check now.

**Verify from PowerShell:**

```powershell
Get-ADDomain | Format-List Name, DNSRoot, DomainMode, DistinguishedName
Get-DnsServerZone
Resolve-DnsName lab.local
```

---

## 8. Install DHCP

1. Server Manager > **Add Roles and Features**
2. Server Roles: tick **DHCP Server** > Add Features
3. **Install**
4. When it completes, click the warning flag > **Complete DHCP configuration**
5. Authorisation: use current credentials (`LAB\Administrator`) > **Commit**

Authorisation matters — an unauthorised DHCP server in an AD domain refuses to hand
out leases. This trips people up constantly.

**Verify:**

```powershell
Get-Service DHCPServer | Format-Table Name, Status
```

---

## 9. Create the DHCP scope

1. Server Manager > Tools > **DHCP**
2. Expand `dc01.lab.local` > right-click **IPv4** > **New Scope**
3. Name: `CLIENTS-VLAN20`
4. IP range:

   | Field | Value |
   |---|---|
   | Start | `192.168.20.100` |
   | End | `192.168.20.200` |
   | Length | 24 |
   | Subnet mask | `255.255.255.0` |

5. Exclusions: none needed
6. Lease duration: 8 days (default) is fine
7. **Yes, I want to configure these options now**
8. Router (default gateway): `192.168.20.1`
9. Domain name and DNS servers:
   - Parent domain: `lab.local`
   - DNS server IP: `192.168.10.10` — **remove any other entry**
10. WINS: skip
11. **Yes, I want to activate this scope now**

**Option 006 must be the DC, never 8.8.8.8.** A client using a public resolver can
browse the internet perfectly and still be completely unable to join the domain,
because the SRV records only exist in your AD-integrated zone. This is the single
most common lab failure.

**Verify:**

```powershell
Get-DhcpServerv4Scope
Get-DhcpServerv4OptionValue -ScopeId 192.168.20.0
```

---

## 10. Build the client VM

Same process as DC01:

| Setting | Value |
|---|---|
| Name | `PC01` |
| Version | Windows 11 (64-bit) |
| Memory | 4096 MB |
| CPU | 2 cores |
| Disk | 60 GB |
| Network | **Same host-only adapter as DC01** |

Install Windows 11. Two things to watch:

**Windows 11 wants a Microsoft account.** At the network setup screen, press
`Shift + F10` to open a command prompt and run:

```
OOBE\BYPASSNRO
```

The machine reboots and you get an "I don't have internet" option, which lets you
create a local account.

**Windows 11 Home cannot join a domain.** You need **Pro** or Enterprise. If the
installer does not ask which edition, check afterwards with `winver`.

### Client network settings

For the first test, set a static IP so you are testing one thing at a time:

| Field | Value |
|---|---|
| IP address | `192.168.10.20` |
| Subnet mask | `255.255.255.0` |
| Default gateway | blank (or `192.168.10.1`) |
| Preferred DNS | `192.168.10.10` |

**Verify connectivity before attempting the domain join:**

```
ping 192.168.10.10
nslookup lab.local
nslookup -type=SRV _ldap._tcp.dc._msdcs.lab.local
```

All three must succeed. The third one is the real test — it is literally the query
Windows makes when finding a domain controller. If ping works but nslookup fails,
your DNS setting is wrong. Fix it here; do not proceed.

---

## 11. Join the domain

1. Settings > System > About > **Domain or workgroup**
2. **Change** > Member of: **Domain** > `lab.local`
3. Credentials: `LAB\Administrator` and the password
4. Welcome message > OK > **Restart now**
5. After reboot, at the sign-in screen choose **Other user** and sign in as
   `LAB\Administrator`

**Verify:** on DC01, open ADUC > `lab.local` > Computers. `PC01` should be listed.

Or from PowerShell on DC01:

```powershell
Get-ADComputer -Filter * | Format-Table Name, DNSHostName, Enabled
```

### Switch the client to DHCP

Now that the join works, prove DHCP works too. On PC01, set the adapter back to
**Obtain an IP address automatically** and **Obtain DNS server address
automatically**, then:

```
ipconfig /release
ipconfig /renew
ipconfig /all
```

Confirm the lease is in the `192.168.20.100–200` range and DNS shows `192.168.10.10`.

> Note: with both VMs on one flat host-only network, the `192.168.20.x` scope will
> only hand out leases if the DHCP server can see the request. In a single-subnet
> lab, either change the scope to `192.168.10.100–200`, or accept that the
> `192.168.20.x` design lives in Packet Tracer only. **Document whichever you chose
> and why** — this is a real design tension and explaining it well is worth more
> than hiding it.

---

## 12. Create the OU structure (script)

You cannot link a Group Policy Object to the default `CN=Users` container. That is
the whole reason this OU structure exists.

Save as `New-LabOUStructure.ps1` on DC01. Run PowerShell **as Administrator**.

**Dry run first:**

```powershell
.\New-LabOUStructure.ps1 -WhatIf
```

`-WhatIf` shows what would happen without changing anything. Get in the habit.

**Then for real:**

```powershell
.\New-LabOUStructure.ps1
```

### Full script

```powershell
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
```

**Verify:**

```powershell
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName
```

Or refresh ADUC — you should see the `LAB` OU with four children.

> **Note on deletion.** The OUs are created with accidental-deletion protection on
> (the default). If you want to remove one later you must clear that flag first,
> in ADUC under View > Advanced Features > Object tab.

---

## 13. Create users and groups (script)

Save as `New-LabUsers.ps1`, with `users.csv` alongside it.

**Dry run:**

```powershell
.\New-LabUsers.ps1 -CsvPath .\users.csv -WhatIf
```

**Real run:**

```powershell
.\New-LabUsers.ps1 -CsvPath .\users.csv
```

### users.csv

```csv
FirstName,LastName,SamAccountName,JobTitle,Department,Group
Jane,Doe,jdoe,Service Desk Analyst,IT,GG-IT-Staff
Ravi,Patel,rpatel,Systems Administrator,IT,GG-IT-Admins
Mei,Chen,mchen,Accounts Officer,Finance,GG-Finance
Tom,Baker,tbaker,Sales Representative,Sales,GG-Sales
Aisha,Khan,akhan,HR Coordinator,People,GG-People
```

### Full script

```powershell
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
```

**Two things to know before you run it.**

The default password `LabP@ssw0rd!23` is hardcoded as a parameter default. That is
acceptable for a throwaway lab and unacceptable anywhere else. If your domain
password policy rejects it, pass your own:

```powershell
$pw = Read-Host -AsSecureString "Initial password"
.\New-LabUsers.ps1 -CsvPath .\users.csv -InitialPassword $pw
```

`-ChangePasswordAtLogon $true` means each user must set a new password at first
sign-in. Realistic, but it means you cannot immediately test a GPO as `jdoe` without
going through that prompt first. Sign in once as `jdoe`, set a password, then test.

**Verify:**

```powershell
Get-ADUser -Filter * -SearchBase "OU=Users,OU=LAB,$((Get-ADDomain).DistinguishedName)" |
    Format-Table Name, SamAccountName, Enabled

Get-ADGroupMember -Identity GG-IT-Staff | Format-Table Name
```

---

## 14. Create and test a GPO

1. Server Manager > Tools > **Group Policy Management**
2. Expand Forest > Domains > `lab.local` > `LAB` > `Users`
3. Right-click the **Users** OU > **Create a GPO in this domain, and Link it here**
4. Name: `Restrict Control Panel - Standard Users`
5. Right-click the new GPO > **Edit**
6. Navigate: **User Configuration > Policies > Administrative Templates >
   Control Panel**
7. Double-click **Prohibit access to Control Panel and PC settings**
8. Set to **Enabled** > OK
9. Close the editor

### Test it

On PC01, sign in as `LAB\jdoe` (set the new password when prompted), then:

```
gpupdate /force
gpresult /r
```

`gpresult /r` should list `Restrict Control Panel - Standard Users` under **Applied
Group Policy Objects** in the USER SETTINGS section.

Then try to open Settings or Control Panel. It should be blocked.

**If the GPO does not apply**, check in this order:

1. Is `jdoe` actually *in* the Users OU? Policy applies by OU location, not by group
   membership.
2. Is it a **User** Configuration policy applied to a **user** object? A common
   mistake is putting a user policy on an OU that only contains computers.
3. Has replication happened? In a single-DC lab it is instant, but `gpupdate /force`
   and a sign-out/sign-in clears most confusion.
4. Is SYSVOL shared? Run `Get-SmbShare` on DC01 — if SYSVOL is missing, no GPO will
   ever apply.

---

## 15. Run the health check (script)

Save as `Test-LabHealth.ps1` on DC01, run as Administrator.

```powershell
.\Test-LabHealth.ps1
```

This checks nine things in the order a domain actually breaks. Run it after each
major stage, not just at the end.

### Full script

```powershell
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
    [string] $DomainName   = 'lab.local',
    [string] $ExpectedDcIp = '192.168.10.10'
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

# 4. DC points at itself for DNS -- the most common lab break
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
```

Screenshot the all-PASS output. That goes in the repo.

---

## 16. Build the Packet Tracer network

Packet Tracer cannot run Active Directory, so this half is the **network design**
that the AD lab conceptually sits on. Be honest about that in your README — claiming
the two are physically connected is the kind of thing that unravels in an interview.

### Topology

Drag onto the canvas:

| Device | Model |
|---|---|
| Router | 2911 |
| Switch | 2960 |
| PC (server) | PC-PT, label it `DC01` |
| PC (client) | PC-PT, label it `PC01` |

Cable with **Copper Straight-Through**:

- `R01 Gi0/0` → `SW01 Gi0/1`
- `SW01 Fa0/1` → `DC01 Fa0`
- `SW01 Fa0/2` → `PC01 Fa0`

### Switch configuration

Click SW01 > CLI tab > press Enter, then paste:

```
enable
configure terminal

hostname SW01
no ip domain-lookup

vlan 10
 name SERVERS
vlan 20
 name CLIENTS
exit

interface FastEthernet0/1
 description DC01 - domain controller
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
exit

interface FastEthernet0/2
 description PC01 - client workstation
 switchport mode access
 switchport access vlan 20
 spanning-tree portfast
exit

interface GigabitEthernet0/1
 description Trunk to R01 - carries VLAN 10 and 20
 switchport mode trunk
 switchport trunk allowed vlan 10,20
exit

interface vlan 10
 description Switch management address
 ip address 192.168.10.2 255.255.255.0
 no shutdown
exit
ip default-gateway 192.168.10.1

end
write memory
```

> The 2960 is dot1q-only, so `switchport trunk encapsulation dot1q` is not available
> and not needed. On a 3560 you would have to issue it *before* `switchport mode
> trunk` or the command is rejected. Worth knowing.

### Router configuration

Click R01 > CLI tab, then paste:

```
enable
configure terminal

hostname R01
no ip domain-lookup

interface GigabitEthernet0/0
 description Trunk to SW01
 no ip address
 no shutdown
exit

interface GigabitEthernet0/0.10
 description Servers - VLAN 10 gateway
 encapsulation dot1Q 10
 ip address 192.168.10.1 255.255.255.0
exit

interface GigabitEthernet0/0.20
 description Clients - VLAN 20 gateway
 encapsulation dot1Q 20
 ip address 192.168.20.1 255.255.255.0
 ip helper-address 192.168.10.10
exit

end
write memory
```

**Why `ip helper-address` is there.** A DHCP DISCOVER is a broadcast, and routers do
not forward broadcasts. With the DHCP server in VLAN 10 and clients in VLAN 20,
without this line the clients never get a lease and end up on 169.254.x.x APIPA
addresses. This single command is one of the best things in the whole lab to be able
to explain.

**Do not also configure `ip dhcp pool` on the router.** Pick one DHCP source. Running
both produces conflicting leases.

### End device addressing in Packet Tracer

Click DC01 > Desktop > IP Configuration:

| Field | Value |
|---|---|
| IP | `192.168.10.10` |
| Mask | `255.255.255.0` |
| Gateway | `192.168.10.1` |
| DNS | `192.168.10.10` |

Click PC01 > Desktop > IP Configuration > **Static** (Packet Tracer's built-in DHCP
client will not get a lease unless you also add a PT Server running DHCP):

| Field | Value |
|---|---|
| IP | `192.168.20.100` |
| Mask | `255.255.255.0` |
| Gateway | `192.168.20.1` |
| DNS | `192.168.10.10` |

### Verification

From PC01 > Desktop > Command Prompt:

```
ping 192.168.20.1
ping 192.168.10.1
ping 192.168.10.10
```

All three must succeed. The third proves inter-VLAN routing works.

On the switch and router:

```
show vlan brief
show interfaces trunk
show ip interface brief
show ip route
```

Screenshot `show interfaces trunk` showing VLANs 10 and 20 in the allowed list.

---

## 17. Final verification checklist

Tick these off before you call the project done:

- [ ] `Test-LabHealth.ps1` returns all nine PASS
- [ ] ADUC shows the LAB OU tree with five users in the correct OU
- [ ] `Get-ADGroupMember GG-IT-Staff` returns `jdoe`
- [ ] PC01 appears in ADUC under Computers
- [ ] A domain user can sign in on PC01
- [ ] `gpresult /r` on PC01 shows the Control Panel GPO applied
- [ ] Control Panel is actually blocked for `jdoe`
- [ ] PC01 gets a DHCP lease with DNS = 192.168.10.10
- [ ] Packet Tracer: PC01 can ping across the VLAN boundary to 192.168.10.10
- [ ] `show interfaces trunk` shows VLANs 10 and 20
- [ ] All nine screenshots captured
- [ ] `docs/03-troubleshooting-log.md` has at least three real entries

That last one is not padding. If nothing went wrong you either got very lucky or you
are not looking closely enough.

---

## 18. Troubleshooting reference

| Symptom | Most likely cause | Check |
|---|---|---|
| Domain join: "AD domain controller could not be contacted" | Client DNS not pointing at DC | `ipconfig /all`, then `nslookup -type=SRV _ldap._tcp.dc._msdcs.lab.local` |
| Client gets 169.254.x.x | No DHCP reachable, or missing `ip helper-address` across VLANs | `ipconfig /all`, check scope is Active and authorised |
| DHCP scope active but no leases | DHCP server not authorised in AD | DHCP console — the IPv4 node shows a red arrow if unauthorised |
| Sign-in fails with correct password | Time skew over 5 minutes breaks Kerberos | `w32tm /query /status` on both machines |
| GPO does not apply | Object is not in the linked OU, or wrong Configuration section | `gpresult /r`, confirm user's OU in ADUC |
| GPO never applies to anyone | SYSVOL or NETLOGON not shared | `Get-SmbShare` on DC01 |
| VMs cannot see each other | Different virtual networks, or one is on NAT | Hypervisor network settings — both must be the same host-only/internal net |
| Inter-VLAN ping fails in Packet Tracer | Trunk not formed, or subinterface encapsulation mismatch | `show interfaces trunk`, `show ip interface brief` |
| Cannot join domain from Windows 11 | Home edition | `winver` — you need Pro |
| AD DS install warns about IP | DC is on DHCP | Set the static IP and retry |

---

## What to do when it breaks

Work it like a ticket, in this order, and write down what each step ruled out:

1. **Layer 3** — can you ping the DC by IP? If no, it is a network problem, not AD.
2. **Name resolution** — does `nslookup lab.local` work? If no, it is DNS.
3. **Service** — is the relevant service running on the DC? `Test-LabHealth.ps1`.
4. **Permission** — are you using the right account, with the `LAB\` prefix?
5. **Time** — is the clock within five minutes on both machines?

Roughly nine out of ten lab failures are step 2. Check it first every time.
