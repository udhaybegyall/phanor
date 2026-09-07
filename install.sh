#!/bin/sh
# Phanor installer — macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/udhaybegyall/phanor/main/install.sh | sh
#
# ---- what this does, in order ----------------------------------------------
#
#   1. Works out which binary this machine needs.
#   2. Downloads it and checks the SHA-256 it came with.
#   3. Puts it somewhere on PATH, or tells you exactly how to add it.
#   4. Says what to run next.
#
# ---- and what it deliberately does not do ----------------------------------
#
# It does not touch your newsroom. Every file Phanor keeps — the database, the
# soul, the authors, the pictures — lives under one home directory that the
# binary creates for itself on first run, and reinstalling never goes near it.
# Upgrading is replacing one file.
#
# It does not use sudo on its own. If the install directory needs root, this
# says so and stops, rather than silently asking a pipe-to-shell script for
# your password.
#
# POSIX sh on purpose: this runs on whatever is already on the machine, which
# on a fresh VPS may be dash and not bash.

set -eu

# ---- where things come from and go to ---------------------------------------
#
# Overridable so a fork, a mirror, or a test can point this somewhere else
# without editing the script.
REPO="${PHANOR_REPO:-udhaybegyall/phanor}"
VERSION="${PHANOR_VERSION:-latest}"
INSTALL_DIR="${PHANOR_INSTALL_DIR:-}"

say() { printf '%s\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "this needs \`$1\`, which is not installed."
}

# ---- 1. which binary --------------------------------------------------------
detect_target() {
  os=$(uname -s)
  arch=$(uname -m)
  case "$os" in
    Linux)  os_part=linux ;;
    Darwin) os_part=macos ;;
    *) die "Phanor has no build for $os yet. Linux and macOS are supported here; on Windows use the PowerShell installer." ;;
  esac
  case "$arch" in
    x86_64|amd64)  arch_part=x86_64 ;;
    aarch64|arm64) arch_part=aarch64 ;;
    *) die "Phanor has no build for $arch yet (found on a $os_part machine)." ;;
  esac
  printf 'phanor-%s-%s' "$os_part" "$arch_part"
}

# ---- where a binary can go without root -------------------------------------
#
# Preferring a writable directory already on PATH over one we would have to ask
# the user to add: an installer whose last instruction is "now edit your shell
# profile" has not finished installing anything.
choose_install_dir() {
  if [ -n "$INSTALL_DIR" ]; then
    printf '%s' "$INSTALL_DIR"
    return
  fi
  for candidate in "$HOME/.local/bin" "$HOME/bin"; do
    case ":$PATH:" in
      *":$candidate:"*) if [ -w "$candidate" ] 2>/dev/null || mkdir -p "$candidate" 2>/dev/null; then
                          printf '%s' "$candidate"; return
                        fi ;;
    esac
  done
  # Not on PATH yet, but the conventional home for it, and we say so below.
  printf '%s' "$HOME/.local/bin"
}

need uname
need mkdir
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO "$2" "$1"; }
else
  die "this needs either \`curl\` or \`wget\`."
fi

target=$(detect_target)
archive="$target.tar.gz"
if [ "$VERSION" = "latest" ]; then
  base="https://github.com/$REPO/releases/latest/download"
else
  base="https://github.com/$REPO/releases/download/v${VERSION#v}"
fi

bold "Installing Phanor"
say "  build     $target"
say "  from      $base"

tmp=$(mktemp -d 2>/dev/null || mktemp -d -t phanor)
# Cleaned up whichever way this ends, including a failure partway through a
# download — a half-written archive left in /tmp is the kind of thing somebody
# later tries to install.
trap 'rm -rf "$tmp"' EXIT INT TERM

say "  fetching  $archive"
fetch "$base/$archive" "$tmp/$archive" \
  || die "could not download $base/$archive
       If this is a brand-new install, check that a release has been published for your platform."

# ---- 2. verify --------------------------------------------------------------
#
# Not optional-if-convenient. This script is run by piping a URL into a shell,
# which is already asking for trust; checking that the bytes match the digest
# published beside them is the least it can do in return.
if fetch "$base/$archive.sha256" "$tmp/$archive.sha256" 2>/dev/null; then
  expected=$(awk '{print $1}' < "$tmp/$archive.sha256")
  if command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$tmp/$archive" | awk '{print $1}')
  else
    actual=""
    say "  checksum  skipped (no shasum or sha256sum on this machine)"
  fi
  if [ -n "$actual" ]; then
    [ "$actual" = "$expected" ] || die "checksum mismatch — the download does not match its published digest.
       expected $expected
       got      $actual
       Not installing. Try again; if it persists, do not use this download."
    say "  checksum  ok"
  fi
else
  say "  checksum  no digest published for this build; skipping"
fi

# ---- 3. install -------------------------------------------------------------
need tar
tar -xzf "$tmp/$archive" -C "$tmp" || die "could not unpack $archive"
[ -f "$tmp/phanor" ] || die "the archive did not contain a \`phanor\` binary"
chmod +x "$tmp/phanor"

dir=$(choose_install_dir)
mkdir -p "$dir" 2>/dev/null || die "cannot create $dir"
if [ ! -w "$dir" ]; then
  die "cannot write to $dir.
       Either pick somewhere you own:   PHANOR_INSTALL_DIR=\$HOME/.local/bin sh install.sh
       or install it yourself:          sudo install -m755 <downloaded phanor> $dir/phanor"
fi

# Replaced by rename rather than written in place, so an upgrade cannot leave a
# half-copied binary where a working one used to be — and so upgrading while
# the daemon is running is safe on Unix: the running process keeps the old
# inode until it restarts.
mv "$tmp/phanor" "$dir/phanor.new" && mv "$dir/phanor.new" "$dir/phanor"
say "  installed $dir/phanor"

installed_version=$("$dir/phanor" --version 2>/dev/null | awk '{print $2}') || installed_version=""
[ -n "$installed_version" ] && say "  version   $installed_version"

# ---- 4. what to do next -----------------------------------------------------
say ""
case ":$PATH:" in
  *":$dir:"*)
    bold "Done. Start your newsroom:"
    say ""
    say "    phanor serve"
    say ""
    say "That opens the dashboard and runs the newsroom. Everything Phanor keeps"
    say "lives in one folder — run \`phanor where\` to see exactly where."
    ;;
  *)
    bold "Done — but $dir is not on your PATH yet."
    say ""
    say "Add this line to your shell profile (~/.profile, ~/.zshrc, ~/.bashrc):"
    say ""
    say "    export PATH=\"$dir:\$PATH\""
    say ""
    say "Then open a new terminal and run:"
    say ""
    say "    phanor serve"
    ;;
esac
