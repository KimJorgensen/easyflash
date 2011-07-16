# BANK ROML 	ROMH
# 00   KERNAL0
# 01   KERNAL1
# 02   KERNAL2
# 03   KERNAL3
# 04   KERNAL4
# 05   KERNAL5
# 06   KERNAL6
# 07   KERNAL7
# 08   -- Boot menu
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


ef2-multi.crt: mkimages fc3-1988.bin exos.bin efmenu/efmenu.bin
	./mkimages \
		efmenu/efmenu.bin 0x00 \
		fc3-1988.bin 0x10 \
		exos.bin 0x14 \
		ef2-multi.crt

mkimages: mkimages.c cart.h
	$(CC) -o $@ $<

efmenu/efmenu.bin: always
	$(MAKE) -C efmenu

.PHONY: clean
clean:
	-rm mkimages
	-rm ef2-multi.crt
	-make -C efmenu clean

%.bin: %.s
	acme -o $@ $<

.PHONY: always
always:
