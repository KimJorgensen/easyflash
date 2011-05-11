
#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>

#define UTIL_GLOBAL_READ_LFN 2

// return values for utilOpenFile
#define OPEN_FILE_OK        0
#define OPEN_FILE_ERR       1
#define OPEN_FILE_WRONG     2
#define OPEN_FILE_UNKNOWN   3
// used internally:
#define OPEN_FILE_TYPE_ESPLIT  8
#define OPEN_FILE_TYPE_CRT     9
#define OPEN_FILE_TYPE_PRG    10



void utilResetStartCartridge(void);
void utilResetKillCartridge(void);
void __fastcall__ utilAppendHex1(uint8_t n);
void __fastcall__ utilAppendHex2(uint8_t n);
void __fastcall__ utilAppendChar(char c);

void __fastcall__ utilAppendFlashAddr(uint8_t nBank,
                                      uint8_t nChip, uint16_t nOffset);
void __fastcall__ utilAppendDecimal(uint16_t n);


uint8_t utilOpenFile(uint8_t nPart);

void utilReadSelectNormalFile(void);
unsigned int __fastcall__ utilKernalRead(void* buffer,
                                         unsigned int size);


/* private */ void utilInitDecruncher(void);
/* private */ unsigned int __fastcall__ utilReadEasySplitFile(void* buffer, unsigned int size);


extern unsigned int __fastcall__ (*utilRead)(void* buffer,
                                             unsigned int size);
extern int32_t nUtilExoBytesRemaining;

extern const uint8_t* pFallbackDriverStart;
extern const uint8_t* pFallbackDriverEnd;

extern char utilStr[];

typedef struct EasySplitHeader_s
{
    char    magic[8];   /* PETSCII EASYSPLT (hex 65 61 73 79 73 70 6c 74) */
    uint8_t len[4];     /* uncompressed file size (little endian) */
    uint8_t id[2];      /* 16 bit file ID, must be constant in all parts
                         * which belong to one file. May be a random value,
                         * a checksum or whatever. */
    uint8_t part;       /* Number of this file (0 = 01, 1 = 02...) */
    uint8_t total;      /* Total number of files */
}
EasySplitHeader;

#endif
