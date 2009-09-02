DEPDIR = .deps
df = $(DEPDIR)/$(*F)
PHP = /usr/local/php5/bin/php
# KickAss must be version 2.25 !!
KICKASS = java -jar ~/Develop/6502-asm/fibr/tools_all/KickAssembler/KickAss.jar
VICE = ~/Applications/x64.app/Contents/MacOS/x64

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
	$(PHP) tools/mkdep.php $< > $(df).P
	$(KICKASS) -showmem -vicesymbols -o $@ $<
	@mv $(<:.asm=.vs) $(@:.prg=.vs)

%.crt: %.prg tools/mk_easyflash_module.php
	@echo "$(B)Packing a module $<$(N)"
	$(PHP) tools/mk_easyflash_module.php > $@ < $< $<

# prereq

build/main.prg: graphics/petscii_lower_minimal.png build/screen.bin

build/screen.asm: build/screen.bin

build/screen.bin: screen/screen.php graphics/sprites.png
	@echo "$(B)Generating $<$(N)"
	$(PHP) screen/screen.php > $@


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

