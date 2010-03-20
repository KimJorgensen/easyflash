
# Where to install on "make install"?
inst_prefix   := /usr/local
bin_inst_dir  := $(inst_prefix)/bin
res_inst_dir  := $(inst_prefix)/share/easysplit
doc_inst_dir  := $(inst_prefix)/share/doc/easysplit
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
all: $(outbase)/EasySplit$(version_suffix).tar.bz2

$(outbase)/EasySplit$(version_suffix).tar.bz2: \
		$(outdir)/easysplit $(outres) $(outdoc)
	rm -f $@
	cd $(dir $@) && tar cjf $(notdir $@) EasySplit

.PHONY: install
install: all
	mkdir -p $(bin_inst_dir)
	cp $(outdir)/easysplit $(bin_inst_dir)
	mkdir -p $(res_inst_dir)
	cp -r  $(outdir)/res $(res_inst_dir)
	mkdir -p $(doc_inst_dir)
	cp -r  $(outdir)/res $(doc_inst_dir)
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
