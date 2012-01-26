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
top_dir := $(here)

# don't delete intermediate files
.SECONDARY:

.PHONY: world
world: all

prj_name      := easytransfer

cxxflags      := 
cflags        := 
clibs         :=
cxxlibs       :=
ldflags       :=

ifeq ($(win32), yes)
    app_name      := EasyTransfer.exe
    ef3xfer_name  := ef3xfer.exe
    host          := i686-w64-mingw32
    cxx           := $(host)-c++
    cc            := $(host)-gcc
    outbase       := $(top_dir)/out_win32
    archive_fmt   := zip
else
    app_name      := easytransfer
    ef3xfer_name  := ef3xfer
    cxx           := c++
    cc            := gcc
    outbase       := $(top_dir)/out
    cxxflags      += $(shell wx-config --cxxflags)
    cxxlibs       += $(shell wx-config --libs) -lftdi -lpthread
    clibs         += -lftdi 
    archive_fmt   := tar.bz2
endif

archive_dir   := $(top_dir)/archive

ifeq ($(debug), yes)
    outbase       := $(outbase)_debug
    cflags        += -g
    cxxflags      += -g
    ldflags       += -g
else
    cflags        += -O2
    cxxflags      += -O2
    ldflags       += -Wl,--strip-all
endif

ifneq "$(release)" "yes"
	version        := $(shell date +%y%m%d-%H%M)
	version_suffix :=
else
	version        := 1.0.0
	version_suffix := -$(version)
endif

outdir        := $(outbase)/$(prj_name)
objdir        := $(outbase)/obj
srcdir        := src

# Where to install intermediate libs
tmp_install   := $(outbase)/tmp-install

# Where to install on "make install"?
inst_prefix   := /usr/local

bin_inst_dir  := $(inst_prefix)/bin
res_inst_dir  := $(inst_prefix)/share
doc_inst_dir  := $(inst_prefix)/share/doc
desktop_inst_dir := $(inst_prefix)/share/applications

cflags    += -DVERSION=\"$(version)\"
cflags    += -I$(objdir)
cxxflags  += -DVERSION=\"$(version)\"
cxxflags  += -I$(objdir)

ifeq ($(win32), yes)
    include make/win32-cross-mingw/cross-wx.mk
    include make/win32-cross-mingw/cross-ftdi.mk
endif

###############################################################################
###############################################################################
# Input and output files
###############################################################################
###############################################################################

# list of source files to be compiled
src := 
src += EasyTransferApp.cpp
src += EasyTransferMainFrame.cpp
src += WorkerThread.cpp
src += ef3xfer.c
src += easytransfer.png

# resource files to be built/copied
res := easytransfer.png

# documents to be copied
doc := CHANGES COPYING README

# DLLs to be copied
dll :=
ifeq "$(win32)" "yes"
#dll += mingwm10.dll
dll += libftdi.dll
dll += libusb-1.0.dll
endif

###############################################################################
###############################################################################
# Variable transformations
###############################################################################
###############################################################################

###############################################################################
# Transform all names from $(src)/*.cpp|c|png to out/obj/foo.o or
# out/obj/foo.xpm
#
src_cpp := $(filter %.cpp,$(src))
obj     := $(addprefix $(objdir)/, $(src_cpp:.cpp=.o))
src_c   := $(filter %.c,$(src))
obj     += $(addprefix $(objdir)/, $(src_c:.c=.o))
src_png := $(filter %.png,$(src))
xpm     := $(addprefix $(objdir)/, $(src_png:.png=.xpm))

outdll  := $(addprefix $(outdir)/, $(dll))

outres  := $(addprefix $(outdir)/res/, $(res))

ifeq "$(win32)" "yes"
outdoc  := $(addsuffix .txt, $(addprefix $(outdir)/, $(doc)))
else
outdoc  := $(addprefix $(outdir)/, $(doc))
endif

# Poor men's dependencies: Let all files depend from all header files
headers := $(wildcard $(srcdir)/*.h) $(xpm)

###############################################################################
###############################################################################
# Rules
###############################################################################
###############################################################################

.PHONY: all
all: $(outbase)/$(prj_name)$(version_suffix).$(archive_fmt)

ifeq "$(win32)" "yes"
pre_deps := libftdi
endif

$(outbase)/$(prj_name)$(version_suffix).tar.bz2: \
		$(outdir)/$(app_name) $(outdir)/$(ef3xfer_name) \
		$(outres) $(outdoc) $(outdll)
	rm -f $@
	cd $(dir $@) && tar cjf $(notdir $@) $(prj_name)

$(outbase)/$(prj_name)$(version_suffix).zip: \
		$(outdir)/$(app_name) $(outdir)/$(ef3xfer_name) \
		$(outres) $(outdoc) $(outdll)
	rm -f $@
	cd $(dir $@) && zip -r $(notdir $@) $(prj_name)

$(outdir)/$(app_name): $(obj) | $(outdir) check-environment
	$(cxx) $(ldflags) $(obj) -o $@ $(cxxlibs)

# quick and dirty: command line tool
.PHONY: ef3xfer
ef3xfer: $(outdir)/$(ef3xfer_name)
$(outdir)/$(ef3xfer_name): src/ef3xfer_main.c src/ef3xfer.c src/ef3xfer.h \
						 | $(outdir) check-environment
	$(cc) $(ldflags) $(cflags) -o $@ src/ef3xfer_main.c src/ef3xfer.c $(clibs)


$(outdir) $(objdir):
	mkdir -p $@

$(objdir)/%.o: $(srcdir)/%.cpp $(headers) | $(objdir) check-environment
	$(cxx) -c $(cxxflags) -o $@ $<

$(objdir)/%.o: $(srcdir)/%.c $(headers) | $(objdir) check-environment
	$(cc) -c $(cflags) -o $@ $<

$(objdir)/%.xpm: $(srcdir)/../res/%.png | $(objdir) check-environment
	convert $< $@.tmp.xpm
	cat $@.tmp.xpm | sed "\
			s/static char/static const char/;\
			s/[\._]tmp//;\
			s/\.xpm/_xpm/" > $@

$(outdir)/%: $(srcdir)/../%
	mkdir -p $(dir $@)
	cp $< $@

$(outdir)/%.txt: $(srcdir)/../%
	cat $< | unix2dos > $@

$(outbase)/$(prj_name)/mingwm10.dll: /usr/share/doc/mingw32-runtime/mingwm10.dll.gz
	gunzip -c $^ > $@

$(outbase)/$(prj_name)/libftdi.dll: $(tmp_install)/bin/libftdi.dll
	cp $^ $@

$(outbase)/$(prj_name)/libusb-1.0.dll: $(tmp_install)/bin/libusb-1.0.dll
	cp $^ $@

###############################################################################
# make clean the simple way
#
.PHONY: clean
clean:
	rm -rf $(outbase)


.PHONY: check-environment
check-environment: $(pre_deps)
