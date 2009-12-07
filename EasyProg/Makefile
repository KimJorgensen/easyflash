
ifneq "$(release)" "yes"
	version := $(shell date +%y%m%d-%H%M)
else
	version := 1.4.0
endif

# do not remove intermediate targets
.SECONDARY:

obj :=
obj += obj/crt0.o
obj += obj/eapiglueasm.o
obj += obj/texts.o
obj += obj/torturetestasm.o
obj += obj/startupbin.o
obj += obj/spritesasm.o
obj += obj/exostreamdecr1.o
obj += obj/utilasm.o

optobj :=
optobj += obj/easyprog.o
optobj += obj/flash.o
optobj += obj/cart.o
optobj += obj/screen.o
optobj += obj/progress.o
optobj += obj/dir.o
optobj += obj/filedlg.o
optobj += obj/hex.o
optobj += obj/buffer.o
optobj += obj/torturetest.o
optobj += obj/write.o
optobj += obj/util.o

bin_acme :=
bin_acme += obj/startup.bin
bin_acme += obj/sprites.bin

INCLUDE := include

DEFINE  := -DEFVERSION=\"${version}\"


# GLOPT65 := $(shell which glopt65)
# GCAT65  := $(shell which gcat65)

ifeq "$(GLOPT65)" ""
	obj += $(optobj)
	optobj :=
	optasm :=
else
	obj += obj/easyprog.opt.o
	optasm := $(optobj:.o=.s)
endif

.PHONY: all
all: easyprog.prg

###############################################################################
# Poor men's dependencies: Let all files depend from all header files
#
headers := $(wildcard $(INCLUDE)/*.h)

obj/%.s: src/%.c obj $(headers)
	cc65 -t c64 -T -O --static-locals -I $(INCLUDE) $(DEFINE) -o $@ $<

###############################################################################
obj/%.o: obj/%.s obj
	ca65 -t c64 -o $@ $<

###############################################################################
obj/easyprog.all.s: $(optasm)
	gcat65 --add-removed -v -o $@ $^

###############################################################################
obj/%.opt.s: obj/%.all.s obj
	glopt65 -o $@ $<

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
ifeq "$(release)" "yes"
	cp $@ easyprog-$(version).prg
endif

.PHONY: clean
clean:
	rm -f easyprog easyprog.map easyprog.prg
	rm -rf obj
