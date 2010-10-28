TARGET=c64
CC=cl65
AS=ca65
LD=ld65
C1541=c1541
CFLAGS=-Oirs -t $(TARGET)
AFLAGS=-g # -D DEBUG
LDFLAGS=


%.o: %.c
	$(CC) -c $(CFLAGS) $<

%.o: %.s
	$(AS) $(AFLAGS) $<


LOADER = ../loader/uloadm3.lib


all: ulm3.d64 ulm3.d81


ulm3.d64: ulm3.prg bitmap9.exo
	rm -f temp.d64
	c1541 -format "uload m3,mv" d64 temp.d64
	./writefiles.sh temp.d64
	mv temp.d64 $@

ulm3.d81: ulm3.prg bitmap9.exo
	rm -f temp.d81
	c1541 -format "ulload m3,mv" d81 temp.d81
	./writefiles.sh temp.d81
	mv temp.d81 $@


ulm3.prg: test.prg
	exomizer sfx sys -q -o $@ $^

test.prg: test.o exodecrunch.o music.o $(LOADER)
	$(LD) -C ulm3.cfg -m test.map --dbgfile test.dbg -o $@ $^


bitmap9.exo: bitmap9.prg
	./crunchfiles.sh


clean:
	rm -f *.o *.map *.dbg *.lab
	rm -f bitmap*.exo
	rm -f test.prg ulm3.prg
	rm -f temp.d64 ulm3.d64 temp.d81 ulm3.d81


distclean: clean
	rm -f *~
