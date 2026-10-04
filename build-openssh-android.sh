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
cd $WORK/openssh-$SSH_VER


# 1. explicit_bzero: bzero di bionic adalah macro, pakai memset
sed -i 's|static void (\* volatile ssh_bzero)(void \*, size_t) = bzero;|static void ssh_bzero_fn(void *p, size_t n) { memset(p, 0, n); }\nstatic void (* volatile ssh_bzero)(void *, size_t) = ssh_bzero_fn;|' \
  openbsd-compat/explicit_bzero.c

# 2. getrrsetbyname: bionic tidak punya, ganti stub yang selalu gagal
cat > openbsd-compat/getrrsetbyname.c <<'EOF'
#include "includes.h"
#include "getrrsetbyname.h"
int getrrsetbyname(const char *hostname, unsigned int rdclass,
    unsigned int rdtype, unsigned int flags, struct rrsetinfo **res)
{
	return 1; /* ERRSET_FAIL */
}
void freerrset(struct rrsetinfo *rrset) {}
EOF

# 3. reallocarray: buat versi compat weak, agar tidak bentrok dengan libc.a
sed -i 's|^reallocarray(|__attribute__((weak)) reallocarray(|' openbsd-compat/reallocarray.c

# 4. pwcopy: bionic bisa mengembalikan field passwd = NULL
sed -i 's|xstrdup(pw->pw_gecos)|xstrdup(pw->pw_gecos == NULL ? "" : pw->pw_gecos)|' misc.c
sed -i 's|xstrdup(pw->pw_dir)|xstrdup(pw->pw_dir == NULL ? "/" : pw->pw_dir)|' misc.c
sed -i 's|xstrdup(pw->pw_shell)|xstrdup(pw->pw_shell == NULL ? "/system/bin/sh" : pw->pw_shell)|' misc.c
sed -i 's|xstrdup(pw->pw_class)|xstrdup(pw->pw_class == NULL ? "" : pw->pw_class)|' misc.c
grep -n "pw->pw_" misc.c | grep xstrdup

ac_cv_func_bzero=yes \
ac_cv_func_reallocarray=no \
ac_cv_have_decl_reallocarray=no \
ac_cv_func_recallocarray=no \
ac_cv_have_decl_recallocarray=no \
ac_cv_func_close_range=no \
ac_cv_have_decl_close_range=no \
ac_cv_func_getentropy=no \
ac_cv_have_decl_getentropy=no \
ac_cv_func_freezero=no \
./configure \
  --host=$TARGET \
  --prefix=/data/local/tmp/ssh \
  --with-zlib=$PREFIX \
  --with-ssl-dir=$PREFIX \
  --without-pam \
  --disable-strip \
  --with-ldflags="-L$PREFIX/lib" \
  --with-cppflags="-I$PREFIX/include"

# Patch config.h
sed -i 's|/\* #undef HAVE_ATTRIBUTE__SENTINEL__ \*/|#define HAVE_ATTRIBUTE__SENTINEL__ 1|' config.h
sed -i 's|^#define HAVE_CLOSE_RANGE 1|/* #undef HAVE_CLOSE_RANGE */|' config.h

make -j$(nproc) ssh scp
#$STRIP ssh scp

ls -a

mkdir -p $WORK/out && cp ssh scp $WORK/out/
file $WORK/out/ssh
echo "Selesai: $WORK/out/{ssh,scp}"
