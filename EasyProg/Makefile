
ifeq "$(release)" "yes"
	version := 1.5.0
else
	version := $(shell date +%y%m%d-%H%M)
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
obj += obj/easyprog.o
obj += obj/flash.o
obj += obj/cart.o
obj += obj/screen.o
obj += obj/progress.o
obj += obj/timerasm.o
obj += obj/dir.o
obj += obj/filedlg.o
obj += obj/hex.o
obj += obj/buffer.o
obj += obj/torturetest.o
obj += obj/write.o
obj += obj/util.o

bin_acme :=
bin_acme += obj/startup.bin
bin_acme += obj/sprites.bin

eapi := eapi-am29f040-03
eapi += eapi-m29w160t-03

eapi_dir := ../EasySDK/eapi
eapi_src := $(addprefix $(eapi_dir)/,$(eapi))
eapi_obj := $(addprefix obj/,$(eapi))

inc      := include
inc      += eload/src

INCLUDE  := $(addprefix -I,$(inc))

DEFINE   := -DEFVERSION=\"${version}\"

eload    := eload/eload.lib

.PHONY: all
ifeq "$(release)" "yes"
all: easyprog-$(version).zip
else
all: easyprog.prg
endif

###############################################################################
# Poor men's dependencies: Let all files depend from all header files
#
headers := $(wildcard $(inc)/*.h)

obj/%.s: src/%.c obj $(headers)
	cc65 -t c64 -T -O --static-locals $(INCLUDE) $(DEFINE) -o $@ $<

###############################################################################
obj/%.o: obj/%.s obj
	ca65 -t c64 -o $@ $<

###############################################################################
# the binaries created with acme are included in ca65 source code
# therefore we need a dependency here, and we need the built-in eapi
#
obj/%.o: src/%.s obj $(bin_acme) $(eapi_obj)
	ca65 -t c64 -o $@ $<

###############################################################################
# Always build eapi and copy it here
#
.PHONY: always
always:

$(eapi_obj): always
	make -C $(eapi_dir)
	cp $(eapi_src) obj

###############################################################################
obj/%.bin: src/%.s obj
	acme -o $@ $<

###############################################################################
obj:
	mkdir -p $@

easyprog: $(obj) src/ld.cfg $(eload)
	ld65 -o $@ -m $@.map -C src/ld.cfg $(obj) -L /usr/local/lib/cc65/lib \
		--lib c64.lib --lib $(eload)
	cat easyprog.map | grep -e "^Name\|^CODE\|^DATA\|^BSS\|^RODATA"

easyprog.prg: easyprog
	exomizer sfx 0x080d -o $@ -q $^

easyprog-$(version).zip: easyprog.prg CHANGES
	rm -rf easyprog-$(version)
	rm -f $@
	mkdir easyprog-$(version)
	cp easyprog.prg easyprog-$(version)/easyprog-$(version).prg
	cp CHANGES easyprog-$(version)
	cp IMPORTANT.txt easyprog-$(version)
	zip -v -r $@ easyprog-$(version)

$(eload): force
	$(MAKE) -C $(dir $@)

.PHONY: force
force:

.PHONY: clean
clean:
	rm -f easyprog easyprog.map easyprog.prg
	rm -rf obj
	$(MAKE) -C $(dir $(eload)) clean
