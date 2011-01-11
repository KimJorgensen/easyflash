

AS := ca65
AR := ar65
CC := cl65
AFLAGS := -g -Isrc
CFLAGS := -g -O -Isrc


obj/%.o: src/%.s
	$(AS) $(AFLAGS) -o $@ $<

INC :=
INC += src/drivetype.i
INC += src/kernal.i
INC += src/macro.i
INC += src/xfer_drive_1mhz_2bit.s
INC += src/xfer_drive_2mhz_2bit.s

SRC := 
SRC += src/drive_1541.s
SRC += src/drive_1571.s
SRC += src/drive_1581.s
SRC += src/drive_sd2iec.s
SRC += src/drive_common.s
SRC += src/loader_init.s
SRC += src/drive_detect.s
SRC += src/eload.s
SRC += src/eload_read.s
SRC += src/eload_read_byte.s
SRC += src/eload_close.s

OBJ := $(patsubst src/%.s,obj/%.o,$(SRC))

all: eload.lib eload_test.prg

$(SRC): $(INC)


eload.lib: obj $(OBJ)
	$(AR) a $@ $(OBJ)

eload_test.prg: src/eload_test.c eload.lib
	$(CC) $(CFLAGS) -m $@.map -o $@ $^

obj:
	mkdir -p obj

clean:
	rm -rf obj
	rm -f eload.lib
	rm -f eload_test.prg
	rm -f eload_test.prg.map

distclean: clean
	rm -f *~
