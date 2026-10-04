#!/bin/bash
set -e

SSH_VER=9.9p1
WORK=$HOME/android-ssh-build
NDK=$WORK/android-ndk-r27c
export TARGET=aarch64-linux-android
export API=26
export PATH=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
export CC=$TARGET$API-clang
export AR=llvm-ar
export RANLIB=llvm-ranlib
export STRIP=llvm-strip
export PREFIX=$WORK/deps

# ---------- Ekstrak ulang source yang bersih ----------
cd $WORK
rm -rf openssh-$SSH_VER
tar xf openssh-$SSH_VER.tar.gz
cd openssh-$SSH_VER

# ---------- Patch source (sebelum configure/make) ----------

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

# ---------- Configure ----------
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
  --without-retpoline \
  --disable-strip \
  --with-ldflags="-static -L$PREFIX/lib" \
  --with-cppflags="-I$PREFIX/include"

# ---------- Patch config.h (setelah configure) ----------
sed -i 's|/\* #undef HAVE_ATTRIBUTE__SENTINEL__ \*/|#define HAVE_ATTRIBUTE__SENTINEL__ 1|' config.h
sed -i 's|^#define HAVE_CLOSE_RANGE 1|/* #undef HAVE_CLOSE_RANGE */|' config.h
grep -q "HAVE_ATTRIBUTE__SENTINEL__ 1" config.h || echo '#define HAVE_ATTRIBUTE__SENTINEL__ 1' >> config.h

# ---------- Build ----------
make -j$(nproc) ssh scp
$STRIP ssh scp

mkdir -p $WORK/out
cp ssh scp $WORK/out/
file $WORK/out/ssh
echo "Selesai: $WORK/out/{ssh,scp}"
