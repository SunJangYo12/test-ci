#!/bin/bash
set -e

# ---------- Versi (sesuaikan jika ada yang lebih baru) ----------
NDK_VER=r27c
ZLIB_VER=1.3.1
SSL_VER=3.3.2
SSH_VER=9.9p1

WORK=$HOME/android-ssh-build
mkdir -p $WORK && cd $WORK

# ---------- Download source ----------
wget -c https://dl.google.com/android/repository/android-ndk-$NDK_VER-linux.zip
wget -c https://zlib.net/fossils/zlib-$ZLIB_VER.tar.gz
wget -c https://github.com/openssl/openssl/releases/download/openssl-$SSL_VER/openssl-$SSL_VER.tar.gz
wget -c https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-$SSH_VER.tar.gz

unzip -q -o android-ndk-$NDK_VER-linux.zip
tar xf zlib-$ZLIB_VER.tar.gz
tar xf openssl-$SSL_VER.tar.gz
tar xf openssh-$SSH_VER.tar.gz

# ---------- Environment toolchain ----------
export NDK=$WORK/android-ndk-$NDK_VER
export TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
export TARGET=aarch64-linux-android
export API=26
export PATH=$TOOLCHAIN/bin:$PATH
export ANDROID_NDK_ROOT=$NDK
export CC=$TARGET$API-clang
export AR=llvm-ar
export RANLIB=llvm-ranlib
export STRIP=llvm-strip
export PREFIX=$WORK/deps
mkdir -p $PREFIX

# ---------- zlib ----------
cd $WORK/zlib-$ZLIB_VER
./configure --prefix=$PREFIX --static
make -j$(nproc) && make install

# ---------- OpenSSL ----------
cd $WORK/openssl-$SSL_VER
./Configure android-arm64 -D__ANDROID_API__=$API \
  no-shared no-tests no-docs --prefix=$PREFIX --libdir=lib
make -j$(nproc) && make install_sw

# ---------- OpenSSH ----------
cd $WORK/openssh-$SSH_VER/openbsd-compat
sed -i '0,/#include "includes.h"/s//#include "includes.h"\n#include <strings.h>/' explicit_bzero.c
grep -n "strings.h" explicit_bzero.c   # harus muncul 1 baris
cd ..

cd $WORK/openssh-$SSH_VER

ac_cv_func_bzero=yes \
ac_cv_func_recallocarray=no \
ac_cv_have_decl_recallocarray=no \
ac_cv_func_close_range=no \
ac_cv_have_decl_close_range=no \
./configure \
  --host=$TARGET \
  --prefix=/data/local/tmp/ssh \
  --with-zlib=$PREFIX \
  --with-ssl-dir=$PREFIX \
  --without-pam \
  --disable-strip \
  --with-ldflags="-static -L$PREFIX/lib" \
  --with-cppflags="-I$PREFIX/include"

# Patch config.h
sed -i 's|/\* #undef HAVE_ATTRIBUTE__SENTINEL__ \*/|#define HAVE_ATTRIBUTE__SENTINEL__ 1|' config.h
sed -i 's|^#define HAVE_CLOSE_RANGE 1|/* #undef HAVE_CLOSE_RANGE */|' config.h

make -j$(nproc) ssh scp
$STRIP ssh scp

mkdir -p $WORK/out && cp ssh scp $WORK/out/
file $WORK/out/ssh
echo "Selesai: $WORK/out/{ssh,scp}"
