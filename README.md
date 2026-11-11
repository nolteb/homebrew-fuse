# homebrew-fuse

A small Homebrew tap with FUSE drivers for macOS that homebrew-core has
retired (they are now Linux-only because macFUSE owns the macOS libfuse
userspace).

## Formulae

| Formula | What it does |
|---|---|
| `ext4fuse-mac` | Read-only ext4 FUSE driver, built against macFUSE's libfuse 2.x in /usr/local. Includes a patch fixing the upstream argument parser (options like `-o allow_other` were silently stripped). Mount as your user with `chown $(id -un) /dev/diskNs1` + `ext4fuse /dev/diskN /Volumes/Name`, or use the `ext4-mount` helper pattern. |

## Prerequisites

Install macFUSE first, then approve the macFUSE system extension in
System Settings, Privacy and Security:

    brew install --cask macfuse

## Usage

    brew tap nolteb/fuse
    brew install nolteb/fuse/ext4fuse-mac

## Troubleshooting

- `Error: Refusing to load formula nolteb/fuse/... from untrusted tap`
  (Homebrew requires explicit trust for third-party taps; usually a fresh
  `brew install nolteb/fuse/ext4fuse-mac` records it automatically, but it
  gets invalidated if the tap is re-tapped from a different remote):

      brew trust nolteb/fuse

## Why this exists

- `ext2fuse` (homebrew-core): disabled 2026-03-06, Linux-only, 2008 codebase, no ext4 support.
- `ext4fuse` (homebrew-core): deprecated, scheduled disable 2027-06-21, Linux-only.
- Both upstream projects are unmaintained; the brew formulae were locked to
  `depends_on :linux` because macFUSE (closed-source) provides the only
  working FUSE userspace on macOS.

These formulae compile the same upstream sources against macFUSE's
/usr/local libfuse instead of brew's Linux-only `libfuse@2`.
