
#ifndef TORTURETEST_H_
#define TORTURETEST_H_

#include <stdint.h>

void __fastcall__ tortureTestFillBuffer(const uint8_t* pBuffer,
                                        const EasyFlashAddr* pAddr);

void kernalRamTest(void);
void kernalRamRead(void);
void kernalRamWriteCompare(void);

#endif /* TORTURETEST_H_ */
