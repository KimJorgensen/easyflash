.PHONY: all
all: loader test

.PHONY: loader
loader:
	make -C loader all

.PHONY: test
test:
	make -C test all


.PHONY: clean
clean: loader-clean test-clean

.PHONY: loader-cleam
loader-clean:
	make -C loader clean

.PHONY: test-clean
test-clean:
	make -C test clean


.PHONY: distclean
distclean: loader-distclean test-distclean

.PHONY: loader-cleam
loader-distclean:
	make -C loader distclean

.PHONY: test-distclean
test-distclean:
	make -C test distclean
