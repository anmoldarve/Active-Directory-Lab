# Active Directory Home Lab

A two-part lab: a working Windows Server domain (AD DS, DNS, DHCP, GPO) with domain-joined
Windows 11 clients, and a segmented Cisco network design that the addressing plan maps onto.

> Built to teach myself the fundamentals behind Level 1/2 IT support work: identity,
> name resolution, address assignment, group policy, and VLAN segmentation.

---

## Topology

| Host | Role | VLAN | IP |
|---|---|---|---|
| DC01 | Windows Server 2022 — AD DS, DNS, DHCP | 10 (Servers) | 192.168.10.10 /24 |
| PC01 | Windows 11 client, domain-joined | 20 (Clients) | DHCP from 192.168.20.100-200 |
| R01 | Router-on-a-stick, inter-VLAN routing | — | .10.1 / .20.1 |
| SW01 | Access switch, 802.1Q trunk to R01 | — | — |

Domain: `lab.local`

---

## What's in this repo

| Path | What it is |
|---|---|
| `docs/01-lab-design.md` | Addressing plan, VLAN design, and the reasoning behind each choice |
| `docs/02-build-log.md` | Step-by-step record of what I built, in order |
| `docs/03-troubleshooting-log.md` | Things that broke and how I diagnosed them |
| `docs/04-what-i-learned.md` | Concepts I understand now that I didn't before |
| `scripts/` | PowerShell to provision OUs, users and groups, plus a health check |
| `network/` | Switch and router configurations as plain text |
| `screenshots/` | Evidence the lab actually runs |

---

## Quick start

On DC01, after the domain is promoted:

```powershell
.\scripts\New-LabOUStructure.ps1
.\scripts\New-LabUsers.ps1 -CsvPath .\scripts\users.csv
.\scripts\Test-LabHealth.ps1
```

On SW01 and R01, paste the contents of `network/switch-sw01.txt` and
`network/router-r01.txt` into the CLI in that order.

---

## Verification

The lab is working when all of these pass:

- [ ] `nslookup lab.local` from PC01 returns 192.168.10.10
- [ ] PC01 receives a DHCP lease in the 192.168.20.100-200 range
- [ ] PC01 is joined to `lab.local` and a domain user can sign in
- [ ] `gpresult /r` on PC01 shows the Control Panel restriction GPO applied
- [ ] PC01 can ping DC01 across the VLAN boundary
- [ ] `Test-LabHealth.ps1` returns all PASS

---

## Notes

Built on VirtualBox with a host-only network. Windows Server 2022 and Windows 11
evaluation ISOs. Cisco Packet Tracer for the switching and routing design.
