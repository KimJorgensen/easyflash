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
# .
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

MKIMAGE := ./mkimages

MKIMAGE += trampoline.bin	0x00 	0x3F00

MKIMAGE += images/exos.bin	0x00	0x0000
MKIMAGE += images/beast.bin	0x01	0x0000
MKIMAGE += images/ttn2crom.bin	0x02	0x0000
MKIMAGE += images/jiffy.bin	0x03	0x0000

MKIMAGE += efmenu/efmenu.bin	0x08	0x0000

#MKIMAGE += fc3-1988.bin	0x10	0x0000

MKIMAGE += ef3-multi.bin

ef3-multi.crt: ef3-multi.bin
	cartconv -t easy -i $< -o $@

trampoline.bin: trampoline.s
	acme -f plain -o $@ $<

ef3-multi.bin: trampoline.bin mkimages fc3-1988.bin \
		efmenu/efmenu.bin
	$(MKIMAGE)

mkimages: mkimages.c
	$(CC) -o $@ $<

efmenu/efmenu.bin: always
	$(MAKE) -C efmenu

.PHONY: clean
clean:
	-rm mkimages
	-rm ef3-multi.crt
	-make -C efmenu clean

%.bin: %.s
	acme -o $@ $<

.PHONY: always
always:
