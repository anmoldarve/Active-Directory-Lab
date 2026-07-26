# Screenshots

Evidence the lab runs. Capture these and drop them in this folder:

| Filename | What to capture |
|---|---|
| `01-aduc-ou-structure.png` | ADUC showing the LAB OU tree with users in place |
| `02-dns-forward-zone.png` | DNS Manager showing the `lab.local` zone and `_msdcs` |
| `03-dhcp-active-leases.png` | DHCP console showing PC01's active lease |
| `04-domain-join.png` | PC01 System page showing it joined to `lab.local` |
| `05-gpresult.png` | `gpresult /r` output with the GPO applied |
| `06-control-panel-blocked.png` | The GPO actually working on the client |
| `07-packet-tracer-topology.png` | The full Packet Tracer topology |
| `08-show-interfaces-trunk.png` | Trunk carrying VLANs 10 and 20 |
| `09-health-check.png` | `Test-LabHealth.ps1` returning all PASS |

Crop tightly and blur nothing that isn't a real credential -- lab passwords are fine
to show, but get in the habit of checking before you push.
