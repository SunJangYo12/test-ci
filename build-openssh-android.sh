#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Build static OpenSSH client for Android ARM64
# Output:
#   out/ssh
#   out/scp
#   out/openssh-android-arm64.tar.gz
# ============================================================

WORK="${PWD}/build-openssh"
OUT="${PWD}/out"

NDK_VERSION="r25c"
API=24

OPENSSL_VERSION="3.5.4"
OPENSSH_VERSION="10.2p1"

NDK_DIR="${WORK}/android-ndk-${NDK_VERSION}"
TOOLCHAIN="${NDK_DIR}/toolchains/llvm/prebuilt/linux-x86_64"

OPENSSL_PREFIX="${WORK}/openssl-install"
OPENSSH_PREFIX="${WORK}/openssh-install"

mkdir -p "$WORK" "$OUT"

# ------------------------------------------------------------
# Download Android NDK
# ------------------------------------------------------------

if [ ! -d "$NDK_DIR" ]; then
    wget -q --show-progress \
        "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" \
        -O "${WORK}/ndk.zip"

    unzip -q "${WORK}/ndk.zip" -d "$WORK"
	ls $NDK_DIR
	ls $TOOLCHAIN
fi

CC="${TOOLCHAIN}/bin/aarch64-linux-android${API}-clang"
AR="${TOOLCHAIN}/bin/llvm-ar"
RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
STRIP="${TOOLCHAIN}/bin/llvm-strip"

export CC
export AR
export RANLIB
export STRIP

echo "CC=$CC"

"$CC" --version

# ------------------------------------------------------------
# OpenSSL
# ------------------------------------------------------------

cd "$WORK"

if [ ! -d "openssl-${OPENSSL_VERSION}" ]; then
    wget -q --show-progress \
        "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"

    tar xf "openssl-${OPENSSL_VERSION}.tar.gz"
fi

cd "openssl-${OPENSSL_VERSION}"

if [ ! -f "${OPENSSL_PREFIX}/lib/libcrypto.a" ]; then

    make clean >/dev/null 2>&1 || true

    ./Configure android-arm64 \
        --prefix="$OPENSSL_PREFIX" \
        no-shared \
        no-tests \
        no-apps

    make -j"$(nproc)"
    make install_sw
fi

# ------------------------------------------------------------
# OpenSSH
# ------------------------------------------------------------

cd "$WORK"

if [ ! -d "openssh-${OPENSSH_VERSION}" ]; then
    wget -q --show-progress \
        "https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VERSION}.tar.gz"

    tar xf "openssh-${OPENSSH_VERSION}.tar.gz"
fi

cd "openssh-${OPENSSH_VERSION}"

make distclean >/dev/null 2>&1 || true

export CFLAGS="-O2 -ffunction-sections -fdata-sections"
export CPPFLAGS="-I${OPENSSL_PREFIX}/include"
export LDFLAGS="-static -L${OPENSSL_PREFIX}/lib -Wl,--gc-sections"

./configure \
    --host="aarch64-linux-android" \
    --prefix="$OPENSSH_PREFIX" \
    --sysconfdir="$OPENSSH_PREFIX/etc" \
    --with-ssl-dir="$OPENSSL_PREFIX" \
    --without-pam \
    --without-kerberos5 \
    --without-ldns \
    --without-libedit \
    --without-xauth \
    --disable-strip \
    --disable-lastlog \
    --disable-utmp \
    --disable-wtmp \
    --disable-wtmpx \
    --disable-pututline \
    --disable-pututxline

make -j"$(nproc)"

# ------------------------------------------------------------
# Copy only ssh + scp
# ------------------------------------------------------------

rm -rf "$OUT"
mkdir -p "$OUT"

cp ssh "$OUT/ssh"
cp scp "$OUT/scp"

"$STRIP" "$OUT/ssh"
"$STRIP" "$OUT/scp"

chmod 755 "$OUT/ssh" "$OUT/scp"

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "===== file ====="

file "$OUT/ssh"
file "$OUT/scp"

echo
echo "===== dynamic dependencies ====="

readelf -d "$OUT/ssh" || true
readelf -d "$OUT/scp" || true

echo
echo "===== size ====="

ls -lh "$OUT/ssh" "$OUT/scp"

# ------------------------------------------------------------
# Package
# ------------------------------------------------------------

cd "$OUT"

tar czf openssh-android-arm64.tar.gz ssh scp

echo
echo "===== result ====="

ls -lh openssh-android-arm64.tar.gz
