/*
 * flashcode.h
 *
 *  Created on: 19.05.2009
 *      Author: skoe
 */

#ifndef FLASHCODE_H_
#define FLASHCODE_H_

unsigned __fastcall__ flashCodeReadIds(void* base);
void __fastcall__ flashCodeSectorErase(void* base);

#endif /* FLASHCODE_H_ */
