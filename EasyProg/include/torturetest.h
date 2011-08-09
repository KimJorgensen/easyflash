
#ifndef TORTURETEST_H_
#define TORTURETEST_H_

#include <stdint.h>

void __fastcall__ tortureTestFillBuffer(const uint8_t* pBuffer,
                                        const EasyFlashAddr* pAddr);
uint16_t __fastcall__ tortureTestBanking(void);
uint16_t __fastcall__ tortureTestCompare(const uint8_t* pBuffer,
                                         const EasyFlashAddr* pAddr);
uint8_t __fastcall__ tortureTestCheckRAM(void);
uint8_t* __fastcall__ tortureTestVerifyFlash(uint8_t* pFlash, uint8_t* pRAM);

void tortureTestComplete(void);
void tortureTestRead(void);
void tortureTestRAM(void);

#endif /* TORTURETEST_H_ */
