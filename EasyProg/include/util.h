
#ifndef UTIL_H
#define UTIL_H

#include <stdint.h>

void utilResetStartCartridge(void);
void utilResetKillCartridge(void);
int __fastcall__ utilRead(void* buffer, unsigned int size);

extern const uint8_t* pFallbackDriverStart;
extern const uint8_t* pFallbackDriverEnd;

#endif
