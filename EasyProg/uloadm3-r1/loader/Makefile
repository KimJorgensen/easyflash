TARGET=c64
CC=cl65
AS=ca65
LD=ld65
AR=ar65
C1541=c1541
CFLAGS=-Oirs -t $(TARGET)
AFLAGS=-g # -D UL3_SAVE -D UL3_SUPERCPUFIX -D UL3_DTV2FIX # -D LOADERTEST
LDFLAGS=


%.o: %.c
	$(CC) -c $(CFLAGS) $<

%.o: %.s
	$(AS) $(AFLAGS) $<


DRIVECODE = \
	drivecode.o \
	drive1541.o \
	drive1571.o \
	drive1581.o \
	drivecmdhd.o \
	drivecmdfd.o

LOADERINIT = \
	loader_init.o \
	loader_detect.o

LOADER = \
	loader.o


all: uloadm3.lib


uloadm3.lib: $(DRIVECODE) $(LOADERINIT) $(LOADER)
	$(AR) a $@ $^


clean:
	rm -f *.o *.map *.dbg *.lab
	rm -f uloadm3.lib


distclean: clean
	rm -f *~
