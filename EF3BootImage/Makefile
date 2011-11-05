# BANK ROML         .	ROMH
# 00   KERNAL0      .	Trampoline
# 01   KERNAL1      .
# 02   KERNAL2      .
# 03   KERNAL3      .
# 04   KERNAL4      .
# 05   KERNAL5      .
# 06   KERNAL6      .
# 07   KERNAL7      .
# 08   <-------- Boot menu -------->
# 09 \ <--------- EasyProg
# 0a /                     -------->
# .                 .
# 0f <----------- sound ----------->    
# 10 \              .
# .   \ Directory   .
# .   / (64k        .
# 17 /   reserved)  .
# 18 \
# 19  \ Final Cartridge III
# 1a  /
# 1b /
# 1c \
# 1d  \ Action Replay
# 1e  /
# 1f /

# uncompressed version of EasyProg
easyprog    := ../EasyProg/easyprog

###############################################################################
#
PHONY: all
all: ef3-init.crt ef3-menu.crt

###############################################################################
# These files are in "menu" image and "initial" image

menu_image  := trampoline.bin       0x00 0x3F00
menu_image  += efmenu/efmenu.bin    0x08 0x0000
menu_image  += $(easyprog)          0x09 0x0000
#menu_image += waterdrop.raw        0x0f 0x0000
#menu_image += bing.raw        0x0f 0x0000

menu_deps   := trampoline.bin
menu_deps   += efmenu/efmenu.bin
menu_deps   += $(easyprog)

###############################################################################
# These files are in and "initial" image only

init_image 	:= images/exos.bin      0x00 0x0000
init_image 	+= images/beast.bin     0x01 0x0000
init_image 	+= images/ttn2crom.bin  0x02 0x0000

init_image 	+= directory.bin        0x10 0x0000

init_image 	+= images/ar.bin  		0x1c 0x0000

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
	$(MAKE) -C efmenu

.PHONY: always
always:

###############################################################################
#
$(easyprog): always
	$(MAKE) -C $(dir $@)

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
