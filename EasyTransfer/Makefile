#
# Makefile
#
# (c) 2003-2011 Thomas Giesel
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
#
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
#
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#
# Thomas Giesel skoe@directbox.com
#

here := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: world
world: all

ifeq ($(win32), yes)
    app_name      := easytransfer
    cxx           := i586-mingw32msvc-c++
    cc            := i586-mingw32msvc-gcc
    outbase       := out_win32
    include make/win32-cross-mingw/cross-wx.mk
	cxxflags      := $(shell $(wx-prefix)/bin/wx-config --static=yes --cxxflags)
	libs          := $(shell $(wx-prefix)/bin/wx-config --libs)
else
    app_name      := easytransfer
    cxx           := c++
    cc            := gcc
    outbase       := out
    cxxflags      := $(shell wx-config --cxxflags)
    libs          := $(shell wx-config --libs) -lftdi -lpthread
endif

# Where to install on "make install"?
inst_prefix   := /usr/local

ifeq ($(debug), yes)
    outbase       := $(outbase)_debug
    ccflags       += -g
    cxxflags      += -g
    ldflags       += -g
else
    ccflags       += -O2
    cxxflags      += -O2
    ldflags       +=
endif

ifneq "$(release)" "yes"
	version        := $(shell date +%y%m%d-%H%M)
	version_suffix :=
else
	version        := 1.0.0
	version_suffix := -$(version)
endif

###############################################################################
# This is the list of source files to be compiled
#
src := 
src += EasyTransferApp.cpp
src += EasyTransferMainFrame.cpp
src += WorkerThread.cpp
src += easytransfer.png

###############################################################################
# This is a list of resource files to be built/copied
#
res := easytransfer.png

###############################################################################
# This is a list of documents to be copied
#
doc := CHANGES COPYING README


include make/common/transform.mk
include make/common/rules.mk
include make/common/install.mk

.PHONY: check-environment
check-environment:
