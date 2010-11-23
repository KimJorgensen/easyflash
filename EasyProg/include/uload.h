/*
 * uload.h
 *
 *  Created on: 28.10.2010
 *      Author: skoe
 */

#ifndef ULOAD_H_
#define ULOAD_H_

#include <stdint.h>

uint8_t uloadInit(void);
uint8_t uloadOpenDir(void);
uint8_t __fastcall__ uloadOpenFile(uint16_t ts);
int uloadReadByte(void);
void uloadExit(void);

int __fastcall__ uloadRead(void* buffer, unsigned int size);

#endif /* ULOAD_H_ */
