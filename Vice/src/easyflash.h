#ifndef _EASYFLASH_H
#define _EASYFLASH_H

#include <stdio.h>

#include "types.h"

extern int easyflash_crt_attach(FILE *fd, BYTE *rawcart, BYTE *header);

extern void easyflash_config_init(void);
extern void easyflash_config_setup(BYTE *rawcart);

extern BYTE REGPARM1 easyflash_io1_read(WORD addr);
extern void REGPARM2 easyflash_io1_store(WORD addr, BYTE value);

extern BYTE REGPARM1 easyflash_io2_read(WORD addr);
extern void REGPARM2 easyflash_io2_store(WORD addr, BYTE value);

#endif