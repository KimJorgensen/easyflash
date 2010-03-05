
ef2-multi.crt: mkimages efmenu.bin
	./mkimages

mkimages: mkimages.c cart.h
	$(CC) -o $@ $<

.PHONY: clean
clean:
	-rm mkimages

%.bin: %.s
	acme -o $@ $<
