# Troubleshooting log

> **This is the most valuable file in the repo.** Anyone can follow a tutorial.
> A log of what broke and how you narrowed it down is what shows you can actually
> work a ticket. Write an entry every single time something fails -- including
> the embarrassing ones.

Use this format:

---

## Symptom

What you observed, in the words a user would use.

## What I checked

The order you checked things, and what each result ruled out.

## Root cause

The actual cause.

## Fix

What resolved it.

## What I learned

Why it happened, so you can explain it in an interview.

---

# Entries

## 1. TODO -- example: domain join fails with "an Active Directory domain controller could not be contacted"

**Symptom:** PC01 rejected the domain join.

**What I checked:**
1. Pinged 192.168.10.10 -- succeeded, so it was not a Layer 3 problem
2. Ran `nslookup lab.local` -- failed, which pointed at name resolution
3. Ran `ipconfig /all` -- DNS server was set to the router, not the DC

**Root cause:** TODO

**Fix:** TODO

**What I learned:** Domain join depends on SRV records that live only in the
AD-integrated DNS zone. A client can have full internet access and still be
unable to find a domain controller.

---

## 2. TODO

---

## 3. TODO
