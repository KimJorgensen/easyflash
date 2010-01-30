
#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>

#define UTIL_GLOBAL_READ_LFN 2

// return values for utilOpenFile
#define OPEN_FILE_OK    0
#define OPEN_FILE_ERR   1
#define OPEN_FILE_WRONG 2

void __fastcall__ utilAppendHex1(uint8_t n);
void __fastcall__ utilAppendHex2(uint8_t n);
void __fastcall__ utilAppendChar(char c);
void __fastcall__ utilAppendDecimal(uint16_t n);


uint8_t __fastcall__ utilOpenFile(uint8_t nDrive, const char* pStrFileName);
void utilCloseFile(void);

void utilReadSelectNormalFile(void);
int __fastcall__ utilReadNormalFile(void* buffer, unsigned int size);


/* private */ void utilInitDecruncher(void);
/* private */ int __fastcall__ utilReadEasySplitFile(void* buffer, unsigned int size);


extern int __fastcall__ (*utilRead)(void* buffer, unsigned int size);
extern int32_t nUtilExoBytesRemaining;

extern const uint8_t* pFallbackDriverStart;
extern const uint8_t* pFallbackDriverEnd;

extern char utilStr[];
extern char strFileName[];

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

void utilReset(void);

#endif
