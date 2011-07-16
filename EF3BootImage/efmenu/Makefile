
# do not remove intermediate targets
.SECONDARY:

name := efmenu

ifneq "$(release)" "yes"
	version := $(shell date +%y%m%d-%H%M)
else
	version := 1.0.0
endif

ld_config := src/ld.cfg

obj :=
obj += obj/crt0.o
obj += obj/efmenu.o
obj += obj/efmenu_asm.o
obj += obj/gfx.o
obj += obj/charset.o
obj += obj/text_plot.o
obj += obj/text_plot_asm.o

INCLUDE  := src

DEFINE   := -DEFVERSION=\"${version}\"

.PHONY: all
all: $(name).crt

###############################################################################
# Poor men's dependencies: Let all files depend from all header files
#
headers := $(wildcard $(INCLUDE)/*.h)

obj/%.s: src/%.c obj $(headers)
	cc65 -t c64 -T -Or --static-locals -I $(INCLUDE) $(DEFINE) -o $@ $<

###############################################################################
obj/%.o: obj/%.s obj
	ca65 -t c64 -o $@ $<

###############################################################################
# the binaries created with acme are included in ca65 source code
# therefore we need a dependency here
#
obj/%.o: src/%.s obj $(bin_acme)
	ca65 -t c64 -I src -o $@ $<

###############################################################################
# prepare the charset
#
obj/charset.s: src/charset.sed obj
	sed -e "s/\#/1/g; s/\-/0/g; s/^[01][01]/.byte %&/" \
		$< > $@

###############################################################################
# create a crt image from a binary image
#
%.crt: %.bin
	../../EasySDK/tools/bin2efcrt linear $< $@

###############################################################################
obj:
	mkdir -p $@

$(name).bin: $(obj) $(ld_config)
	ld65 -o $@ -m $@.map -Ln $@.labels -C $(ld_config) $(obj) \
		-L /usr/local/lib/cc65/lib --lib c64.lib
ifeq "$(release)" "yes"
	cp $@ $@-$(version).prg
endif

.PHONY: clean
clean:
	rm -f $(name) $(name).bin $(name).bin.map $(name).bin.labels
	rm -f $(name).crt
	rm -rf obj
