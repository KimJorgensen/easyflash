#!/bin/sh


c1541 $1 -write ulm3.prg "uload m3 test" > /dev/null || exit 1
c1541 $1 \
	-write bitmap0.exo "0" \
	-write bitmap1.exo "1" \
	-write bitmap2.exo "2" \
	-write bitmap3.exo "3" \
	-write bitmap4.exo "4" \
	-write bitmap5.exo "5" \
	-write bitmap6.exo "6" \
	-write bitmap7.exo "7" \
	-write bitmap8.exo "8" \
	-write bitmap9.exo "9" \
	> /dev/null || exit 1
