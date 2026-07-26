# Addressing plan

## Subnets

| VLAN | Name | Subnet | Gateway | Purpose |
|---|---|---|---|---|
| 10 | SERVERS | 192.168.10.0/24 | 192.168.10.1 | Domain controller, infrastructure |
| 20 | CLIENTS | 192.168.20.0/24 | 192.168.20.1 | End-user workstations |

## Static assignments

| Host | Address | Notes |
|---|---|---|
| R01 (VLAN 10 gateway) | 192.168.10.1 | Subinterface Gi0/0.10 |
| SW01 management | 192.168.10.2 | SVI on VLAN 10 |
| DC01 | 192.168.10.10 | Static. A DC on DHCP causes intermittent auth failures |
| R01 (VLAN 20 gateway) | 192.168.20.1 | Subinterface Gi0/0.20 |

## DHCP

| Setting | Value |
|---|---|
| Scope | 192.168.20.100 - 192.168.20.200 |
| Subnet mask | 255.255.255.0 |
| Option 003 (Router) | 192.168.20.1 |
| Option 006 (DNS) | 192.168.10.10 |
| Option 015 (Domain) | lab.local |

## Design decisions

**Why servers and clients are separated.** Putting them in one flat subnet works
but teaches nothing. Segmenting them mirrors how real networks are built and forces
the inter-VLAN routing and DHCP relay problems to actually appear.

**Why DNS option 006 points at the DC and never at 8.8.8.8.** Domain join and
Kerberos both rely on SRV records that only exist in the AD-integrated zone. A client
using a public resolver can reach the internet and still fail to find the domain --
which is the single most common reason a domain join fails.

**Why `ip helper-address` is needed.** A DHCP DISCOVER is a broadcast, and routers do
not forward broadcasts. With the DHCP server in VLAN 10 and clients in VLAN 20, the
router must be told to relay those requests, or clients sit on APIPA addresses.

**Why DHCP runs on the server, not the router.** Windows DHCP integrates with DNS to
register client records automatically. Router-based DHCP would leave stale DNS entries.
