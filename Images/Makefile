
# 40
# 41
# 42
# 43
# 44
# 45
# 46
# 57
# 58
# .
# .
# .
# 70 \
# 71  \ Final Cartridge III
# 72  /
# 73 /
# 74 -- Exos?
# 75
# 76
# 77
# 78
# 79
# 7a
# 7b -- Boot menu
# 7c \
# 7d  \ Unused, currently not supported, because the
# 7e  / boot block of the M29W160ET makes it difficult
# 7f /


ef2-multi.crt: mkimages fc3-1988.bin exos.bin efmenu/efmenu.bin
	./mkimages \
		fc3-1988.bin 0x70 \
		exos.bin 0x74 \
		efmenu/efmenu.bin 0x7b \
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
