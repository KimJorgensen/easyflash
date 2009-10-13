

VERSION := 1.3.3

# do not remove intermediate targets
.SECONDARY:

obj :=
obj += obj/crt0.o
obj += obj/buffer.o
obj += obj/eapiglueasm.o
obj += obj/flash.o
obj += obj/cart.o
obj += obj/screen.opt.o
obj += obj/easyprog.o
obj += obj/texts.o
obj += obj/hex.o
obj += obj/progress.o
obj += obj/write.o
obj += obj/torturetest.o
obj += obj/torturetestasm.o
obj += obj/startupbin.o
obj += obj/filedlg.o
obj += obj/spritesasm.o
obj += obj/util.o
obj += obj/dir.o

bin_acme :=
bin_acme += obj/startup.bin
bin_acme += obj/sprites.bin

INCLUDE := include

DEFINE  := -DEFVERSION=\"${VERSION}\"

.PHONY: all
all: easyprog.prg

###############################################################################
# Poor men's dependencies: Let all files depend from all header files
#
headers := $(wildcard $(INCLUDE)/*.h)

###############################################################################
obj/%.s: src/%.c obj $(headers)
	cc65 -t c64 -O -I $(INCLUDE) $(DEFINE) -o $@ $<

###############################################################################
obj/%.o: obj/%.s obj
	ca65 -t c64 -o $@ $<

###############################################################################
obj/%.opt.s: obj/%.s obj
	#glopt65 -o $@ $<
	cp $< $@
	#echo bla

###############################################################################
# the binaries created with acme are included in ca65 source code
# therefore we need a dependency here
#
obj/%.o: src/%.s obj $(bin_acme)
	ca65 -t c64 -o $@ $<

###############################################################################
obj/%.bin: src/%.s obj
	acme -o $@ $<

###############################################################################
obj:
	mkdir -p $@

easyprog: $(obj) src/ld.cfg
	ld65 -o $@ -m $@.map -C src/ld.cfg $(obj) -L /usr/local/lib/cc65/lib --lib c64.lib

easyprog.prg: easyprog
	exomizer sfx 0x080d -o $@ -q $^
	cp $@ easyprog-$(VERSION).prg

.PHONY: clean
clean:
	rm -f easyprog easyprog.map easyprog.prg
	rm -rf obj
