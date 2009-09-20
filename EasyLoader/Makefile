
# KickAss must be version 2.25 !!

# definitions in your file, read tools/example.EasyLoader.rc
# or use "make VARIABLE=VALUE"

DEPDIR = .deps
df = $(DEPDIR)/$(*F)
RCFILES = 

ifneq ($(strip $(wildcard ~/.EasyLoader.rc)),) 
include ~/.EasyLoader.rc
RCFILES += ~/.EasyLoader.rc
endif

PHP5 ?= php
JAVA ?= java
KICKASS ?= KickAss.jar
VICE ?= x64

RCFILES += $(PACKAGE)

SRCS = easyloader_nrm.asm easyloader_ocm.asm

N = "\\033[0m"
B = "\\033[1m"

build: n

clean:
	rm build/* .deps/*

svn:
	svn ci
	svn up

build/%.prg: %.asm
	@echo "$(B)Assembling $<$(N)"
	$(PHP5) tools/mkdep.php $< > $(df).P
	$(JAVA) -jar $(KICKASS) -showmem -vicesymbols -o $@ $<
	@mv $(<:.asm=.vs) $(@:.prg=.vs)

%.crt: %.prg tools/mk_easyflash_module.php $(RCFILES)
	@echo "$(B)Packing a module $<$(N)"
	$(PHP5) tools/mk_easyflash_module.php > $@ < $< $< $(PACKAGE)

# prereq

build/main.prg: graphics/petscii_lower_minimal.png build/screen.bin

build/screen.asm: build/screen.bin

build/screen.bin: screen/screen.php graphics/sprites.png
	@echo "$(B)Generating $<$(N)"
	$(PHP5) screen/screen.php > $@


# debug version!

n: build/easyloader_nrm.crt
	@echo "$(B)Launching vice$(N)"
	echo 'load_labels "build/easyloader_nrm.vs"' > build/easyloader_nrm.mc
	$(VICE) -cartcrt build/easyloader_nrm.crt -moncommands build/easyloader_nrm.mc

o: build/easyloader_ocm.crt
	@echo "$(B)Launching vice$(N)"
	echo 'load_labels "build/easyloader_ocm.vs"' > build/easyloader_ocm.mc
	$(VICE) -cartcrt build/easyloader_ocm.crt -moncommands build/easyloader_ocm.mc

# autodep

-include $(SRCS:%.asm=$(DEPDIR)/%.P)

