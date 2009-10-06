
#ifndef DIR_H
#define DIR_H

#include <cbm.h>

typedef struct DirEntry_s {
    char          name[17];     /* File name in PETSCII, limited to 16 chars */
    char          type[4];
    unsigned int  size;         /* Size in 254 byte blocks */
} DirEntry;

unsigned char __fastcall__ dirOpen(unsigned char lfn, unsigned char device);
unsigned char __fastcall__ dirReadEntry (unsigned char lfn, DirEntry* l_dirent);

#endif
