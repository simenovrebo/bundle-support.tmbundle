#!/bin/sh
# Build lib/osx/plist.bundle, the osx-plist Ruby extension (https://github.com/kballard/osx-plist, MIT license,
# see LICENSE), as a universal (arm64 + x86_64) binary for the ruby 1.8.7 used by bin/ruby18.
#
# Requirements: Xcode command line tools.
# Usage: build.sh
set -e

here=$(cd "$(dirname "$0")" && pwd)
support=$(cd "$here/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The headers of the ruby that bin/ruby18 runs (lib/ruby/1.8/‹arch›-darwin)
tar -xJf "$support/private/ruby18/ruby_1.8.7-p374.txz" -C "$work"
headers="$work/1.8.7-p374/lib/ruby/1.8"

build () { # arch ruby-arch-dir min-os
	clang -arch "$1" -mmacosx-version-min="$3" -O2 -fno-common -Wno-deprecated-declarations \
		-I"$headers/$2" -bundle -undefined dynamic_lookup -framework CoreFoundation \
		-o "$work/plist-$1.bundle" "$here/plist.c"
}

build arm64  aarch64-darwin 11.0
build x86_64 x86_64-darwin  10.15

lipo -create "$work/plist-arm64.bundle" "$work/plist-x86_64.bundle" -output "$support/lib/osx/plist.bundle"
strip -x "$support/lib/osx/plist.bundle"
echo "Created $support/lib/osx/plist.bundle"
