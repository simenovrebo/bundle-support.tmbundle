#!/bin/sh
# Build ruby_1.8.7-p374.txz: a universal (arm64 + x86_64) ruby 1.8.7 used by bin/ruby18.
#
# Requirements: Xcode command line tools, Rosetta (to build the x86_64 half) and
# automake (for up-to-date config.guess/config.sub), e.g. `brew install automake`.
#
# Usage: build.sh [output directory]  (defaults to the directory of this script)
set -e

VERSION=1.8.7-p374
SHA256=b4e34703137f7bfb8761c4ea474f7438d6ccf440b3d35f39cc5e4d4e239c07e3
PREFIX=/usr/local/textmate-ruby-1.8.7 # rewritten to the install location by ruby18_fix_loadpath.rb

out=$(cd "${1:-$(dirname "$0")}" && pwd)
automake_share=$(ls -d "$(brew --prefix 2>/dev/null || echo /usr/local)"/share/automake-* | tail -1)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

curl -fsSLO "https://cache.ruby-lang.org/pub/ruby/1.8/ruby-$VERSION.tar.bz2"
echo "$SHA256  ruby-$VERSION.tar.bz2" | shasum -a 256 -c -
tar -xjf "ruby-$VERSION.tar.bz2"

# Needed so that modern clang builds ruby 1.8 correctly: it relies on signed integer overflow
# wrapping (bignum.c), on gnu89 inline semantics (lex.c), and predates C99 prototypes.
CFLAGS="-O2 -fwrapv -fno-strict-aliasing -fgnu89-inline -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-function-pointer-types -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=return-type -Wno-deprecated-non-prototype"

build () { # arch triple min-os
	cp -Rp "ruby-$VERSION" "build-$1" # -p: keep timestamps so lex.c is not regenerated
	cd "build-$1"
	rm -rf ext/openssl ext/tk ext/readline ext/gdbm ext/Win32API ext/win32ole
	cp "$automake_share/config.guess" "$automake_share/config.sub" .
	cc="clang -arch $1 -mmacosx-version-min=$3"
	arch -$1 ./configure --prefix="$PREFIX" --build="$2" --host="$2" --disable-shared --enable-pthread=no \
		CC="$cc" CFLAGS="$CFLAGS" LDSHARED="$cc -dynamic -bundle -undefined dynamic_lookup" >/dev/null
	arch -$1 make -j"$(sysctl -n hw.ncpu)" >/dev/null
	arch -$1 make test
	arch -$1 make install DESTDIR="$work/install-$1" >/dev/null
	cd ..
}

build arm64  aarch64-apple-darwin 11.0
build x86_64 x86_64-apple-darwin  10.15

# The arch specific directories (aarch64-darwin, x86_64-darwin) live side by side, everything else is identical
dst="$work/pkg/$VERSION"
mkdir -p "$work/pkg"
cp -Rp "install-arm64$PREFIX" "$dst"
cp -Rp "install-x86_64$PREFIX/lib/ruby/1.8/x86_64-darwin" "$dst/lib/ruby/1.8/"
lipo -create "install-arm64$PREFIX/bin/ruby" "install-x86_64$PREFIX/bin/ruby" -output "$dst/bin/ruby"
rm -rf "$dst/lib/libruby-static.a" "$dst/share"
strip -S "$dst/bin/ruby"
find "$dst" -name '*.bundle' -exec strip -S {} \;

COPYFILE_DISABLE=1 tar --no-xattrs -cJf "$out/ruby_$VERSION.txz" -C "$work/pkg" "$VERSION"
echo "Created $out/ruby_$VERSION.txz"
