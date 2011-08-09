# BANK ROML             ROMH
# 00   KERNAL0          Trampoline
# 01   KERNAL1
# 02   KERNAL2
# 03   KERNAL3
# 04   KERNAL4
# 05   KERNAL5
# 06   KERNAL6
# 07   KERNAL7
# 08   <-------- Boot menu -------->
# 09   <--------- EasyProg -------->
# .
# .
# 10 \
# 11  \ Final Cartridge III
# 12  /
# 13 /
# 14 -- Exos?
# 15
# 16
# 17
# 18
# 19
# 1a
# 1b
# 1c
# 1d
# 1e
# 1f

easyprog    := ../EasyProg/easyprog.prg

mkimage_cmd := ./mkimages

mkimage_cmd += trampoline.bin       0x00 0x3F00

mkimage_cmd += images/exos.bin      0x00 0x0000
mkimage_cmd += images/beast.bin     0x01 0x0000
mkimage_cmd += images/ttn2crom.bin  0x02 0x0000
mkimage_cmd += images/jiffy.bin     0x03 0x0000

mkimage_cmd += efmenu/efmenu.bin    0x08 0x0000
mkimage_cmd += $(easyprog)          0x09 0x0000

#mkimage_cmd += fc3-1988.bin         0x10 0x0000

mkimage_cmd += ef3-multi.bin

ef3-multi.crt: ef3-multi.bin
	cartconv -t easy -i $< -o $@

trampoline.bin: trampoline.s
	acme -f plain -o $@ $<

ef3-multi.bin: trampoline.bin mkimages fc3-1988.bin \
		efmenu/efmenu.bin $(easyprog)
	$(mkimage_cmd)

mkimages: mkimages.c
	$(CC) -o $@ $<

efmenu/efmenu.bin: always
	$(MAKE) -C efmenu

$(easyprog): always
	$(MAKE) -C $(dir $@)

.PHONY: clean
clean:
	-rm mkimages
	-rm ef3-multi.crt
	-make -C efmenu clean

%.bin: %.s
	acme -o $@ $<

.PHONY: always
always:
