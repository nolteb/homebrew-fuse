# homebrew-fuse

A small Homebrew tap with FUSE drivers for macOS that homebrew-core has
retired (they are now Linux-only because macFUSE owns the macOS libfuse
userspace).

## Formulae

| Formula | What it does |
|---|---|
| `ext4fuse-mac` | Read-only ext4 FUSE driver, built against macFUSE's libfuse 2.x in /usr/local. Mount with: `sudo ext4fuse /dev/diskN /mnt/point -o allow_other` |

## Prerequisites

Install macFUSE first, then approve the macFUSE system extension in
System Settings, Privacy and Security:

    brew install --cask macfuse

## Usage

    brew tap nolteb/fuse
    brew install nolteb/fuse/ext4fuse-mac

## Why this exists

- `ext2fuse` (homebrew-core): disabled 2026-03-06, Linux-only, 2008 codebase, no ext4 support.
- `ext4fuse` (homebrew-core): deprecated, scheduled disable 2027-06-21, Linux-only.
- Both upstream projects are unmaintained; the brew formulae were locked to
  `depends_on :linux` because macFUSE (closed-source) provides the only
  working FUSE userspace on macOS.

These formulae compile the same upstream sources against macFUSE's
/usr/local libfuse instead of brew's Linux-only `libfuse@2`.
