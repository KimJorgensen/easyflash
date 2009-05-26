/*
 * flashcode.h
 *
 *  Created on: 19.05.2009
 *      Author: skoe
 */

#ifndef FLASHCODE_H_
#define FLASHCODE_H_

#include <stdint.h>

void __fastcall__ flashCodeSetBank(uint8_t nBank);
unsigned __fastcall__ flashCodeReadIds(uint8_t* pBase);
void __fastcall__ flashCodeSectorErase(uint8_t* pBase);
void __fastcall__ flashCodeWrite(uint8_t* pAddr, uint8_t nVal);

#endif /* FLASHCODE_H_ */
