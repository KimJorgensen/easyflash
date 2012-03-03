

.PHONY: all
all: out/ef3kernal_b0.bin out/ef3kernal_b1.bin

src := src/ef3kernal.s

deps :=
deps += src/kernal.bin

###############################################################################
# KERNAL bank 0
# We do this with acme since it makes it very easy to overwrite portions of 
# the original KERNAL image
out/ef3kernal_b0.bin: $(src) $(deps) out
	acme -l $@.labels -o $@ $<

###############################################################################
# KERNAL bank 1

obj_b1 := obj/kernal_b1.o

out/ef3kernal_b1.bin: $(obj_b1) src/ld.kernal.cfg
	ld65 -o $@ -m $@.map -C src/ld.kernal.cfg $(obj_b1)
	cat $@.map | grep -e "^Name\|^CODE\|^DATA\|^BSS\|^RODATA"

###############################################################################
obj/%.o: src/%.s obj
	ca65 -t c64 $(INCLUDE) -o $@ $<

obj:
	mkdir -p $@

out:
	mkdir -p $@


.PHONY: clean
clean:
	rm -rf out
