
ifneq "$(release)" "yes"
	version := $(shell date +%y%m%d-%H%M)
else
	version := 1.0.0
endif

# do not remove intermediate targets
.SECONDARY:

obj :=
obj += obj/texts.o
obj += obj/torturetestasm.o

optobj :=
optobj += obj/eftest.o
optobj += obj/screen.o
optobj += obj/torturetest.o

bin_acme :=

INCLUDE := include

DEFINE  := -DEFVERSION=\"${version}\"


# GLOPT65 := $(shell which glopt65)
# GCAT65  := $(shell which gcat65)

ifeq "$(GLOPT65)" ""
	obj += $(optobj)
	optobj :=
	optasm :=
else
	obj += obj/eftest.opt.o
	optasm := $(optobj:.o=.s)
endif

.PHONY: all
all: eftest.prg

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
obj/eftest.all.s: $(optasm)
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

eftest: $(obj)
	cl65 -o $@ -m $@.map $(obj) -L /usr/local/lib/cc65/lib --lib c64.lib

eftest.prg: eftest
	exomizer sfx 0x080d -o $@ -q $^
ifeq "$(release)" "yes"
	cp $@ eftest-$(version).prg
endif

.PHONY: clean
clean:
	rm -f eftest eftest.map eftest.prg
	rm -rf obj
