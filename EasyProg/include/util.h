
#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>

void utilResetStartCartridge(void);
void utilResetKillCartridge(void);
int __fastcall__ utilRead(void* buffer, unsigned int size);
void __fastcall__ utilAppendHex1(uint8_t n);
void __fastcall__ utilAppendHex2(uint8_t n);
void __fastcall__ utilAppendChar(char c);

void __fastcall__ utilAppendFlashAddr(uint8_t nBank,
                                      uint8_t nChip, uint16_t nOffset);
void __fastcall__ utilAppendDecimal(uint16_t n);

extern const uint8_t* pFallbackDriverStart;
extern const uint8_t* pFallbackDriverEnd;

extern char utilStr[];

#endif
