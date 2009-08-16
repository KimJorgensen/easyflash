

# do not remove intermediate targets
.SECONDARY:

OBJ :=
OBJ += obj/crt0.o
OBJ += obj/flashcode.o
OBJ += obj/flash.o
OBJ += obj/cart.o
OBJ += obj/screen.o
OBJ += obj/easyprog.o
OBJ += obj/texts.o
OBJ += obj/hex.o
OBJ += obj/progress.o
OBJ += obj/write.o
OBJ += obj/torturetest.o
OBJ += obj/torturetestasm.o
OBJ += obj/startupbin.o
OBJ += obj/filedlg.o

BIN_ACME += obj/startup.bin

INCLUDE := include
#DEFINE  := -D EASYFLASH_FAKE

.PHONY: all
all: easyprog


obj/%.s: src/%.c obj
	cc65 -t c64 -O -I $(INCLUDE) $(DEFINE) -o $@ $<


obj/%.o: obj/%.s obj
	ca65 -t c64 -o $@ $<


# the binaries created with acme are included in ca65 source code
# therefore we need a dependency here
obj/%.o: src/%.s obj $(BIN_ACME)
	ca65 -t c64 -o $@ $<


obj/%.bin: src/%.s obj
	acme -o $@ $<

obj:
	mkdir -p $@

easyprog.prg: $(OBJ) src/ld.cfg
	ld65 -o $@ -m $@.map -C src/ld.cfg $(OBJ) --lib c64.lib

easyprog: easyprog.prg
	exomizer sfx 0x080d -o $@ -q $^

.PHONY: clean
clean:
	rm -f easyprog easyprog.map easyprog.prg
	rm -rf obj
