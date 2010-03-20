
ef2-multi.crt: mkimages #efmenu.bin
	./mkimages fc3-1988.bin 0x40 exos.bin 0x44 ef2-multi.crt

mkimages: mkimages.c cart.h
	$(CC) -o $@ $<

.PHONY: clean
clean:
	-rm mkimages

%.bin: %.s
	acme -o $@ $<
