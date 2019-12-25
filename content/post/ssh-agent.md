---
date: "2019-01-14"
title: "what is the value-add of ssh-agent?"
tags: [
    "software-security",
]
---

## `ssh-agent` overview

`ssh-agent` [is an authentication agent](https://linux.die.net/man/1/ssh-agent). It is a long-running process that (among other things) does private key operations on behalf of your SSH client.

One reason why `ssh-agent` exists is to protect private keys on-disk. It's likely that your SSH private keys are encrypted with a key derived from a password you have set. That is why you may occasionally have to enter a password prior to establishing a SSH connection with some server.

The reason why you have to only enter this password occasionally instead of approximately every SSH connection (or every time your SSH client wants to do a private key operation like signing) is because `ssh-agent` caches your plaintext private key in-memory for some period of time.

## the ux value-add of ssh-agent

Caching the private key is a user experience improvement of using `ssh-agent`. With a long-running agent process you can keep sensitive data (e.g. cleartext private keys) off the filesystem and still avoid having to type your password every time you want to establish a SSH connection.

This improvement, however, assumes that encrypting your private keys on the filesystem is useful. Individually encrypted files are probably useful if you *don't* already have full-disk encryption (FDE) like FileVault enabled but you should have FDE enabled on your machine! If you don't, go ahead and take the time now-ish to set it up.

What if you do have FDE enabled? What would encrypting your private keys get you from a security perspective? Given that the primary UX win of `ssh-agent` is dependent on caching cleartext private keys we could just skip the password entry step all together if it didn't meaningfully improve security.

## malware

One potential security control you may want from `ssh-agent` is protecting you from malicious processes running on your machine. This is reasonable, but whether `ssh-agent` helps you here is complex. Why? Reasons include:

* The location of your `ssh-agent` socket is often specified by an environment variable. It may be trivial for a malicious process to overwrite this environment variable and point to a socket that steals your `ssh-agent` password or your private keys when they are loaded into the agent.

* ["The default OpenSSH key encryption is worse than plaintext"](https://latacora.micro.blog/2018/08/03/the-default-openssh.html). Do you have a stellar password protecting your private keys?

* Side channels are plentiful!

One could imagine attacks or vulnerabilities where the attacker either doesn't have persistent access or only has e.g. file read capabilities. `ssh-agent` does provide some level of security control from weaker local attacks like these.

## remote backups

Off-site backups are a strong reason in-favor of keeping cleartext private keys off-disk (Another point for `ssh-agent`!). That is, if you write your private keys in plaintext to disk, it's possible that these files may end up on Google Drive or something. While it's reasonable to place some amount of trust in Google not sniffing around for your private keys, I imagine this isn't an ideal outcome either.

Should you use an encrypted backup service like [tarsnap](https://www.tarsnap.com/)? Yeah. Probably!

## possible improvements

It is an arguable improvement if you use a Yubikey as an `ssh-agent`. That is, if your SSH private keys are stored in hardware and never touch your disk, the evil processes running on your laptop have to work harder to SSH into your blog.

Additionally, keys that require physical interaction (e.g. TouchID authZ, Yubikey taps) may further limit exposure.

In both of these cases, however, you need at least a halfway decent backup plan in case you lose/break/swallow your security key.

It is still worthwhile to use `ssh-agent` unless you have a strong reason not to.
