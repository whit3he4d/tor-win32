#
# This Makefile heavily abuses the stamp idiom :-)
#

OPENSSL_VERSION ?= 1.0.2n #1.1.1l
OPENSSL_URL = https://www.openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz

LIBEVENT_VERSION ?= 2.1.8-stable #2.1.12-stable
LIBEVENT_URL = https://github.com/libevent/libevent/releases/download/release-$(LIBEVENT_VERSION)/libevent-$(LIBEVENT_VERSION).tar.gz

ZLIB_VERSION ?= 1.2.11
ZLIB_URL = https://github.com/madler/zlib/archive/refs/tags/v$(ZLIB_VERSION).tar.gz

TOR_GIT_URL ?= https://git.torproject.org/tor.git

MINGW  ?= mingw
HOST   ?= i686-w64-mingw32

#MINGW  ?= mingw64
#HOST   ?= x86_64-w64-mingw32

CC     ?= $(HOST)-gcc
CXX    ?= $(HOST)-g++
CPP    ?= $(HOST)-cpp
LD     ?= $(HOST)-ld
AR     ?= $(HOST)-ar
RANLIB ?= $(HOST)-ranlib

PREFIX ?= $(PWD)/prefix

all: prepare tor

.PHONY: clean prepare

prepare:
	mkdir -p src dist prefix || true

# OpenSSL.
src/openssl-fetch-stamp:
	wget $(OPENSSL_URL) -P dist/
	touch $@

src/openssl-unpack-stamp: src/openssl-fetch-stamp
	tar zxfv dist/openssl-$(OPENSSL_VERSION).tar.gz -C src/
	touch $@

src/openssl-build-stamp: src/openssl-unpack-stamp
	cd src/openssl-$(OPENSSL_VERSION) && \
		./Configure $(MINGW) no-shared no-dso   \
		--cross-compile-prefix=$(HOST)-  \
		--prefix=$(PREFIX) &&            \
		make &&                          \
		make install
	touch $@

# Libevent.
src/libevent-fetch-stamp:
	wget $(LIBEVENT_URL) -P dist/
	touch $@

src/libevent-unpack-stamp: src/libevent-fetch-stamp
	tar zxfv dist/libevent-$(LIBEVENT_VERSION).tar.gz -C src/
	touch $@

src/libevent-build-stamp: src/libevent-unpack-stamp
	cd src/libevent-$(LIBEVENT_VERSION) && \
		./configure --host=$(HOST)         \
		--disable-shared 				   \
        --enable-static 				   \
		--with-pic                         \
		--prefix=$(PREFIX)                 \
		--disable-openssl &&               \
		make &&                            \
		make install
	touch $@

# zlib.
src/zlib-fetch-stamp:
	wget $(ZLIB_URL) -P dist/
	touch $@

src/zlib-unpack-stamp: src/zlib-fetch-stamp
	tar zxfv dist/v$(ZLIB_VERSION).tar.gz -C src/
	touch $@

src/zlib-build-stamp: src/zlib-unpack-stamp
	cd src/zlib-$(ZLIB_VERSION) && \
	CC=$(HOST)-gcc AR="$(HOST)-ar" RANLIB=$(HOST)-ranlib ./configure --prefix=$(PREFIX) --static && \
	make install
	touch $@

# Tor.
src/tor-fetch-stamp: src/zlib-build-stamp
	git clone $(TOR_GIT_URL) src/tor
	touch $@

src/tor-configure-stamp: src/tor-fetch-stamp
	cd src/tor && ./autogen.sh
	touch $@

tor: src/tor-configure-stamp src/openssl-build-stamp src/libevent-build-stamp src/zlib-build-stamp
	cd src/tor &&                          \
		./configure --host=$(HOST)         \
		--disable-asciidoc                 \
		--disable-zstd                     \
		--disable-lzma                     \
		--enable-static-tor				   \
		--with-zlib-dir=$(PREFIX)		   \
		--with-libevent-dir=$(PREFIX)      \
		--with-openssl-dir=$(PREFIX)       \
		--disable-tool-name-check          \
		--prefix=$(PREFIX) &&              \
		make &&                            \
		make install

clean:
	rm -rf src/* dist/* prefix/* || true
