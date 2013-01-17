
# do not remove intermediate targets
.SECONDARY:

name := usbtool

ifneq "$(release)" "yes"
	version := $(shell date +%y%m%d-%H%M)
else
	version := 1.0.0
endif
bin2efcrt = ../../EasySDK/tools/bin2efcrt

obj :=
obj += obj/usbtool.o
obj += obj/usbtool_prg.o
obj += obj/write_disk.o

inc      := src
inc      += ../../libs/libef3usb/src
inc      += ../../libs/eload/src

INCLUDE  := $(addprefix -I,$(inc))

DEFINE   := -DEFVERSION=\"${version}\"

libef3usb := ../../libs/libef3usb/libef3usb.lib
libeload  := ../../libs/eload/eload.lib

.PHONY: all
all: $(name).crt

###############################################################################
# Poor men's dependencies: Let all files depend from all header files
#
headers := $(wildcard $(INCLUDE)/*.h)

obj/%.s: src/%.c $(headers) | obj
	cc65 -t c64 -T -O --static-locals $(INCLUDE) $(DEFINE) -o $@ $<

###############################################################################
obj/%.o: obj/%.s | obj
	ca65 -t c64 $(INCLUDE) -o $@ $<

###############################################################################
obj/%.o: src/%.s | obj
	ca65 -t c64 $(INCLUDE) -o $@ $<

###############################################################################
# create a crt image from a binary image
#
%.crt: %.bin
	$(bin2efcrt) $< $@

###############################################################################
#
$(libef3usb): force
	$(MAKE) -C $(dir $@)

$(libeload): force
	$(MAKE) -C $(dir $@)

.PHONY: force
force:

###############################################################################
obj:
	mkdir -p $@

$(name).bin: obj/crt0.crt.o $(obj) src/ld.crt.cfg $(libef3usb) $(libeload)
	ld65 -o $@ -m $@.map -C src/ld.crt.cfg obj/crt0.crt.o $(obj) \
		--lib  $(libef3usb) $(libeload) \
		-L /usr/local/lib/cc65/lib --lib c64.lib
	cat $@.map | grep -e "^Name\|^CODE\|^DATA\|^BSS\|^RODATA\|^LOWCODE"

$(name).prg: obj/crt0.prg.o $(obj) src/ld.prg.cfg $(libef3usb) $(libeload)
	ld65 -o $@ -m $@.map -C src/ld.prg.cfg obj/crt0.prg.o $(obj) \
		--lib  $(libef3usb) $(libeload) \
		-L /usr/local/lib/cc65/lib --lib c64.lib
	cat $@.map | grep -e "^Name\|^CODE\|^DATA\|^BSS\|^RODATA\|^LOWCODE"

.PHONY: clean
clean:
	rm -f $(name) $(name).bin $(name).bin.map $(name).crt
	rm -f $(obj)
	rm -rf obj
	-$(MAKE) -C $(dir $(libef3usb)) clean
	-$(MAKE) -C $(dir $(libeload)) clean

