
#ifndef TORTURETEST_H_
#define TORTURETEST_H_

#include <stdint.h>

void __fastcall__ tortureTestFillBuffer(const uint8_t* pBuffer,
                                        const EasyFlashAddr* pAddr);
uint16_t __fastcall__ tortureTestBanking(void);
uint16_t __fastcall__ tortureTestCompare(const uint8_t* pBuffer,
                                         const EasyFlashAddr* pAddr);

void tortureTest(void);

#endif /* TORTURETEST_H_ */
