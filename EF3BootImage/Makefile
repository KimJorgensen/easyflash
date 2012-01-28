# BANK ROML             |  ROMH
# ==========================================
# 00   KERNAL0          |  Trampoline
# 01   KERNAL1          |
# 02   KERNAL2          |
# 03   KERNAL3          |
# 04   KERNAL4          |
# 05   KERNAL5          |
# 06   KERNAL6          |
# 07   KERNAL7          |
# ==========================================
# 08   <----------- Boot menu ------------->
# 09 \ <----------- EasyProg
# 0a /                       -------------->
# 0b   <----------- USB tool -------------->
# .                     .
# 0f <--------------- Sound --------------->
# ==========================================
# 10                    |   Action Replay
# .     Directory       |      Slot 0
# .     (64k reserved)  |      (64 k)
# 17                    |
# ==========================================
# 18                    |   Action Replay
# .     Reserved        |      Slot 1
# .                     |      (64 k)
# 1f                    |
# ==========================================
# 20
# .              Super Snapsot
# .             (128 k reserved)
# 27
# ==========================================
# 28
# .            Final Cartridge III
# .                    (?)
# 2f
# ==========================================


# uncompressed version of EasyProg
easyprog    := ../EasyProg/easyprog

ifneq "$(release)" "yes"
	version := $(shell date +%y%m%d-%H%M)
else
	version := 1.0.4
endif

dirname := ef3-menu-init-$(version)

###############################################################################
#
.PHONY: all
ifeq "$(release)" "yes"
all: ef3-menu-init-$(version).zip
else
all: ef3-init.crt ef3-menu.crt
endif

$(dirname).zip: ef3-init.crt ef3-menu.crt CHANGES
	rm -rf $(dirname)
	rm -f $@
	mkdir $(dirname)
	cp ef3-init.crt $(dirname)/ef3-init-$(version).crt
	cp ef3-menu.crt $(dirname)/ef3-menu-$(version).crt
	cp CHANGES $(dirname)
	zip -v -r $@ $(dirname)

###############################################################################
# These files are in "menu" image and "initial" image

menu_image  := trampoline.bin       0x00 0x1F00 H
menu_image  += efmenu/efmenu.bin    0x08 0x0000 LH
menu_image  += $(easyprog)          0x09 0x0000 LH
menu_image  += usbtool/usbtool.bin  0x0b 0x0000 LH
#menu_image += waterdrop.raw        0x0f 0x0000
#menu_image += bing.raw        0x0f 0x0000

menu_deps   := trampoline.bin
menu_deps   += efmenu/efmenu.bin
menu_deps   += $(easyprog)
menu_deps   += usbtool/usbtool.bin

###############################################################################
# These files are in and "initial" image only

init_image  := images/exos.bin              0x00 0x0000 L
init_image  += images/beast.bin             0x01 0x0000 L
init_image  += images/ttn2crom.bin          0x02 0x0000 L

init_image  += directory.bin                0x10 0x0000 L

init_image  += images/rr38ppal.bin          0x10 0x0000 H
#init_image  += images/apower.bin            0x18 0x0000 H
init_image  += images/ar.bin                0x18 0x0000 H

#init_image  += images/ss522-2-pal.bin       0x20 0x0000 LH

###############################################################################
# The menu image: Contains menu and tools
#
ef3-menu.bin: $(menu_deps) mkimages
	./mkimages \
		$(menu_image) \
		ef3-menu.bin

###############################################################################
# The initial image: Contains menu, tools, some KERNALS and a directory
#
ef3-init.bin: $(menu_deps) mkimages \
              directory.bin
	./mkimages \
		$(menu_image) \
		$(init_image) \
		ef3-init.bin


###############################################################################
#
mkimages: mkimages.c
	$(CC) -o $@ $<

###############################################################################
#
efmenu/efmenu.bin: always
	$(MAKE) -C efmenu version=$(version)

.PHONY: always
always:

###############################################################################
#
usbtool/usbtool.bin: always
	$(MAKE) -C usbtool version=$(version)

###############################################################################
#
$(easyprog): always
	$(MAKE) -C $(dir $@) release=$(release)

###############################################################################
#
.PHONY: clean
clean:
	-rm -f mkimages
	-rm -f ef3-init.crt
	-rm -f ef3-init.bin
	-rm -f ef3-menu.crt
	-rm -f ef3-menu.bin
	-rm -f mkimages
	-rm -f directory.bin
	-make -C efmenu clean
	-make -C usbtool clean

###############################################################################
# create a .crt image from a .bin image
#
%.crt: %.bin
	cartconv -t easy -i $< -o $@

###############################################################################
# create a plain .bin image from a .s file
#
%.bin: %.s
	acme -f plain -o $@ $<
