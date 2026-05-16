BUILDDIR   := $(CURDIR)/build
MOVCC      := $(BUILDDIR)/movcc
LCC_COMMIT := 3b3f01b4103cd7b519ae84bd1122c9b03233e687
AES_COMMIT := 7e42e693288bdf22d8e677da94248115168211b9

GCCLN := $(shell gcc --print-search-dirs | grep install | head -1 | cut -d ' ' -f 2-)

PATCHES := movfuscator/bind.patch movfuscator/makefile.patch movfuscator/enode.patch \
           movfuscator/gen.patch movfuscator/expr.patch movfuscator/lcc.patch \
           movfuscator/constexpr.patch movfuscator/gram.patch

.PHONY: all check install clean distclean

all: $(BUILDDIR)/crt0.o $(BUILDDIR)/crtf.o $(BUILDDIR)/crtd.o \
     $(BUILDDIR)/crt0_cf.o $(BUILDDIR)/crtf_cf.o $(BUILDDIR)/crtd_cf.o \
     movfuscator/lib/softfloat32.o movfuscator/lib/softfloat64.o movfuscator/lib/softfloatfull.o \
     movfuscator/lib/softfloat32_cf.o movfuscator/lib/softfloat64_cf.o movfuscator/lib/softfloatfull_cf.o

# --- lcc clone and patch ---

lcc/.git:
	git clone https://github.com/drh/lcc lcc

lcc/.patched: lcc/.git $(PATCHES)
	cd lcc && git reset --hard $(LCC_COMMIT)
	patch -N -r - lcc/src/bind.c movfuscator/bind.patch
	patch -N -r - lcc/makefile movfuscator/makefile.patch
	patch -N -r - lcc/src/enode.c movfuscator/enode.patch
	patch -N -r - lcc/src/gen.c movfuscator/gen.patch
	patch -N -r - lcc/src/expr.c movfuscator/expr.patch
	patch -N -r - lcc/etc/lcc.c movfuscator/lcc.patch
	patch -N -r - -p1 -d lcc < movfuscator/constexpr.patch
	patch -N -r - -p1 -d lcc < movfuscator/gram.patch
	touch $@

# --- build directory setup ---

$(BUILDDIR):
	mkdir -p $(BUILDDIR)

$(BUILDDIR)/include: lcc/.patched | $(BUILDDIR)
	mkdir -p $(BUILDDIR)/include
	cp -p -R lcc/include/x86/linux/* $(BUILDDIR)/include/

$(BUILDDIR)/gcc: | $(BUILDDIR)
	ln -sfn "$(GCCLN)" $(BUILDDIR)/gcc

# --- compiler build ---

lcc/.built: lcc/.patched $(BUILDDIR)/include $(BUILDDIR)/gcc
	$(MAKE) -C lcc BUILDDIR=$(BUILDDIR) HOSTFILE=../movfuscator/host.c \
	    'CFLAGS=-g -DLCCDIR=\"$(BUILDDIR)/\"' lcc
	$(MAKE) -C lcc BUILDDIR=$(BUILDDIR) all
	touch $@

$(MOVCC): lcc/.built | $(BUILDDIR)
	ln -sfn $(BUILDDIR)/lcc $(MOVCC)

# --- CRT libraries ---

$(BUILDDIR)/crt0.o: movfuscator/crt0.c $(MOVCC)
	$(MOVCC) $< -o $@ -c -Wf--crt0 -Wf--q

$(BUILDDIR)/crtf.o: movfuscator/crtf.c $(MOVCC)
	$(MOVCC) $< -o $@ -c -Wf--crtf -Wf--q

$(BUILDDIR)/crtd.o: movfuscator/crtd.c $(MOVCC)
	$(MOVCC) $< -o $@ -c -Wf--crtd -Wf--q

$(BUILDDIR)/crt0_cf.o: movfuscator/crt0.c $(MOVCC)
	$(MOVCC) $< -o $@ -c -Wf--crt0 -Wf--q -Wf--no-mov-flow

$(BUILDDIR)/crtf_cf.o: movfuscator/crtf.c $(MOVCC)
	$(MOVCC) $< -o $@ -c -Wf--crtf -Wf--q -Wf--no-mov-flow

$(BUILDDIR)/crtd_cf.o: movfuscator/crtd.c $(MOVCC)
	$(MOVCC) $< -o $@ -c -Wf--crtd -Wf--q -Wf--no-mov-flow

# --- softfloat (normal, then cf — sequential to share the source tree) ---

movfuscator/lib:
	mkdir -p movfuscator/lib

softfloat/.built_normal: $(MOVCC) | movfuscator/lib
	$(MAKE) -C softfloat clean
	$(MAKE) -C softfloat CC="$(MOVCC)"
	cp softfloat/softfloat32.o movfuscator/lib/softfloat32.o
	cp softfloat/softfloat64.o movfuscator/lib/softfloat64.o
	cp softfloat/softfloatfull.o movfuscator/lib/softfloatfull.o
	touch $@

movfuscator/lib/softfloat32.o movfuscator/lib/softfloat64.o movfuscator/lib/softfloatfull.o \
    : softfloat/.built_normal

softfloat/.built_cf: softfloat/.built_normal
	$(MAKE) -C softfloat clean
	$(MAKE) -C softfloat CC="$(MOVCC) -Wf--no-mov-flow"
	cp softfloat/softfloat32.o movfuscator/lib/softfloat32_cf.o
	cp softfloat/softfloat64.o movfuscator/lib/softfloat64_cf.o
	cp softfloat/softfloatfull.o movfuscator/lib/softfloatfull_cf.o
	$(MAKE) -C softfloat clean
	touch $@

movfuscator/lib/softfloat32_cf.o movfuscator/lib/softfloat64_cf.o movfuscator/lib/softfloatfull_cf.o \
    : softfloat/.built_cf

# --- check ---

validation/aes/.git:
	git clone https://github.com/kokke/tiny-AES128-C validation/aes

validation/aes/aes: validation/aes/.git $(MOVCC)
	cd validation/aes && git reset --hard $(AES_COMMIT)
	$(MOVCC) validation/aes/aes.c validation/aes/test.c -o validation/aes/aes -s

check: validation/aes/aes
	objdump -d -Mintel --insn-width=15 validation/aes/aes
	-./validation/aes/aes

# --- install ---

install: $(MOVCC)
	ln -sfn $(MOVCC) /usr/local/bin/movcc

# --- clean ---

clean:
	rm -rf $(BUILDDIR)
	rm -rf movfuscator/lib
	rm -f softfloat/.built_normal softfloat/.built_cf
	$(MAKE) -C softfloat clean

distclean: clean
	rm -rf lcc
	rm -rf validation/aes
