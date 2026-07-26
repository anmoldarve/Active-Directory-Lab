# Build log

> One entry per stage. Keep it short. The point is to prove you did the work
> and can retrace it, not to write a manual.

---

## Stage 1 -- Domain controller

**Date:** TODO

- Installed Windows Server 2022 (Desktop Experience) on DC01
- Set static IP 192.168.10.10/24, DNS pointing to itself
- Renamed to DC01 and rebooted
- Added AD DS and DNS Server roles
- Promoted to domain controller, new forest `lab.local`

**Verified:** ADUC opens, DNS Manager shows the `lab.local` forward lookup zone
and the `_msdcs` records.

---

## Stage 2 -- DHCP

**Date:** TODO

- Added the DHCP Server role, completed post-install configuration
- Created scope 192.168.20.100-200
- Set options 003, 006 and 015 (see addressing plan)
- Activated the scope

**Verified:** TODO

---

## Stage 3 -- Client and domain join

**Date:** TODO

- Built PC01 on the same virtual network
- Confirmed it received a DHCP lease with the correct DNS server
- Joined `lab.local`

**Verified:** `nslookup lab.local` returns 192.168.10.10; domain user signs in.

---

## Stage 4 -- OUs, users and groups

**Date:** TODO

- Ran `scripts/New-LabOUStructure.ps1` to create the OU tree
- Ran `scripts/New-LabUsers.ps1 -CsvPath .\users.csv` to bulk-create five users

**Verified:** TODO -- how many objects, where they landed.

---

## Stage 5 -- Group Policy

**Date:** TODO

- Created a GPO linked to the LAB\Users OU
- Enabled: User Configuration > Administrative Templates > Control Panel >
  "Prohibit access to Control Panel and PC settings"

**Verified:** Signed in as `jdoe`, ran `gpupdate /force`, confirmed Control Panel
is blocked. `gpresult /r` shows the GPO applied.

---

## Stage 6 -- Packet Tracer network

**Date:** TODO

- Built the topology: 2911 router, 2960 switch, two VLANs
- Applied `network/switch-sw01.txt` then `network/router-r01.txt`

**Verified:** TODO -- which pings succeeded, `show interfaces trunk` output.
