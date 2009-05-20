

OBJ :=
OBJ += obj/crt0.o
OBJ += obj/flashcode.o
OBJ += obj/cart.o
OBJ += obj/screen.o
OBJ += obj/easyprog.o

INCLUDE := include
#DEFINE  := -D __C64__ -D __CBM__

.PHONY: all
all: easyprog


obj/%.s: src/%.c obj
	cc65 -t c64 -O -I $(INCLUDE) $(DEFINE) -o $@ $<


obj/%.o: obj/%.s obj
	ca65 -t c64 -o $@ $<


obj/%.o: src/%.s obj
	ca65 -t c64 -o $@ $<

obj:
	mkdir -p $@

easyprog: $(OBJ) src/ld.cfg
	ld65 -o $@ -m $@.map -C src/ld.cfg $(OBJ) --lib c64.lib

.PHONY: clean
clean:
	rm -f easyprog easyprog.map
	rm -rf obj
