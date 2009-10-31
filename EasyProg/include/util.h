
#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>

#define UTIL_GLOBAL_READ_LFN 2

void utilResetStartCartridge(void);
void utilResetKillCartridge(void);
void __fastcall__ utilAppendHex1(uint8_t n);
void __fastcall__ utilAppendHex2(uint8_t n);
void __fastcall__ utilAppendChar(char c);

void __fastcall__ utilAppendFlashAddr(uint8_t nBank,
                                      uint8_t nChip, uint16_t nOffset);
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

#endif
