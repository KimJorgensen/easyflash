

AS := ca65
AR := ar65
AFLAGS := -g -Isrc


obj/%.o: src/%.s
	$(AS) $(AFLAGS) -o $@ $<

INC :=
INC += src/drivetype.i
INC += src/kernal.i
INC += src/macro.i
INC += src/xfer_drive_1mhz_2bit.s
INC += src/xfer_drive_2mhz_2bit.s
INC += src/drivecode.s

SRC := 
SRC += src/drive_1541.s
SRC += src/drive_1581.s
SRC += src/drive_sd2iec.s
SRC += src/loader_init.s
SRC += src/loader_detect.s
SRC += src/eload.s
SRC += src/eload_read.s
SRC += src/eload_read_byte.s
SRC += src/eload_close.s

OBJ := $(patsubst src/%.s,obj/%.o,$(SRC))

all: eload.lib

$(SRC): $(INC)


eload.lib: obj $(OBJ)
	$(AR) a $@ $(OBJ)

obj:
	mkdir -p obj

clean:
	rm -rf obj
	rm -f eload.lib

distclean: clean
	rm -f *~
