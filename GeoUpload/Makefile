
ifneq "$(release)" "yes"
	version := $(shell date +%y%m%d-%H%M)
else
	version := 1.0.0
endif

# do not remove intermediate targets
.SECONDARY:

obj :=
obj += obj/texts.o
obj += obj/geoupload.o
obj += obj/screen.o
obj += obj/dir.o
obj += obj/filedlg.o
obj += obj/util.o
obj += obj/utilasm.o
obj += obj/exostreamdecr1.o

bin_acme :=

INCLUDE := include

DEFINE  := -DEFVERSION=\"${version}\"


.PHONY: all
all: geoupload.prg

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

geoupload: $(obj)
	cl65 -o $@ -m $@.map $(obj) -L /usr/local/lib/cc65/lib --lib c64.lib

geoupload.prg: geoupload
	exomizer sfx 0x080d -o $@ -q $^
ifeq "$(release)" "yes"
	cp $@ geoupload-$(version).prg
endif

.PHONY: clean
clean:
	rm -f geoupload geoupload.map geoupload.prg
	rm -rf obj
