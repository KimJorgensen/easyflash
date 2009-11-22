
# Where to install on "make install"?
inst_prefix   := /usr/local
bin_inst_dir  := $(inst_prefix)/bin
res_inst_dir  := $(inst_prefix)/share/easysplit
desktop_inst_dir := $(inst_prefix)/share/applications

cxx           := c++
cc            := gcc

ifeq ($(DEBUG), YES)
ccflags       := -g
cxxflags      := -g `wx-config --cxxflags`
ldflags       := -g
else
ccflags       := -O2
cxxflags      := -O2 `wx-config --cxxflags`
ldflags       :=
endif

srcdir        := src

include make/common/filelist.mk

###############################################################################
# Main targets
#
.PHONY: all
all: $(outdir)/easysplit $(outres)

.PHONY: install
install: all
	mkdir -p $(bin_inst_dir)
	cp $(outdir)/easysplit $(bin_inst_dir)
	mkdir -p $(res_inst_dir)
	cp -r  $(outdir)/res $(res_inst_dir)
	mkdir -p $(desktop_inst_dir)
	cp $(srcdir)/../res/easysplit.desktop $(desktop_inst_dir)

###############################################################################
# This rule can link <here>/out/obj/*.o to <here>/out/easysplit/easysplit
# 
$(outdir)/easysplit: $(obj) | $(outdir) check-environment
	$(cxx) $(ldflags) $(obj) -o $@ \
		`wx-config --libs`

include make/common/rules.mk

.PHONY: check-environment
check-environment:
