# Phanor

An autonomous newsroom that runs on your own machine. It watches your feeds, decides
what is worth writing about, researches it, writes it in your voice, draws a cover, and
waits for you to approve it before anything goes near your website.

> **Early access.** Today there is a **Windows** build only. Linux and macOS builds are
> coming; the installer for them is already here and will start working the moment a
> release carries them. Nothing here is final and the version number says so.

## Install

**Windows** — in PowerShell:

```powershell
irm https://raw.githubusercontent.com/udhaybegyall/phanor/main/install.ps1 | iex
```

**Linux and macOS** — the script works, but there is no build for it to download yet:

```sh
curl -fsSL https://raw.githubusercontent.com/udhaybegyall/phanor/main/install.sh | sh
```

Both scripts download the binary from this repository's Releases, check it against the
SHA-256 published beside it, and put it on your PATH. Neither needs administrator or
root. Neither touches an existing newsroom.

If you would rather not pipe a script into a shell — a reasonable instinct — read it
first: [`install.ps1`](install.ps1), [`install.sh`](install.sh). Or download the archive
from [Releases](https://github.com/udhaybegyall/phanor/releases) and put `phanor.exe`
somewhere on your PATH yourself. That is all the installer does.

## Start

```
phanor serve
```

That runs the newsroom and opens the dashboard at <http://127.0.0.1:4517>. Everything is
driven from there.

## Where your newsroom lives

```
phanor where
```

One folder holds all of it — the database, your soul files, your authors, the pictures,
your sign-in. Copying that folder copies your whole newsroom, and `phanor where` will
tell you plainly if you have ever pointed a setting somewhere outside it.

On Windows that folder is under `%APPDATA%\Phanor`. Set `PHANOR_HOME` to put it wherever
you like — a second install, a throwaway one, a data disk.

## Keep it running

```
phanor service install
```

Registers the newsroom with whatever this machine uses to start things — a scheduled task
on Windows, a systemd user unit on Linux, a launch agent on macOS — so it survives closing
the terminal and comes back after a reboot. `phanor service uninstall` removes that
arrangement and nothing else: your newsroom is untouched and `phanor serve` still works by
hand.

## Upgrading

Run the installer again. It replaces one file. Your newsroom is not involved.

On Windows, stop it first — Windows will not let anything overwrite a running program, and
the installer checks for this and says so rather than failing halfway:

```powershell
Stop-Process -Name phanor
```

## Uninstalling

Delete the binary. To remove your newsroom as well, delete the folder `phanor where`
names — that is genuinely all of it, and nothing is written anywhere else.

## Getting your bearings

```
phanor doctor     # is everything wired up, and what is missing
phanor where      # every folder and file this newsroom keeps
phanor --help     # everything else
```

`phanor doctor` is the one to run when something looks wrong. It reports what is
configured, what is signed in, and what is switched off, and it names the setting behind
each answer.

## What is in this repository

The install scripts and the released binaries. **Phanor's source is not open** — see
the licence below.

## Licence

Copyright © 2026. All rights reserved. This software is proprietary; the binaries here are
published for use, not for redistribution or modification.
