

.PHONY: all
all: out/ef3kernal.bin

src := ef3kernal.s

deps :=
deps += kernal.bin

###############################################################################

out/ef3kernal.bin: $(src) $(deps) out
	acme -l $@.labels -o $@ $<

###############################################################################
out:
	mkdir -p $@


.PHONY: clean
clean:
	rm -rf out
