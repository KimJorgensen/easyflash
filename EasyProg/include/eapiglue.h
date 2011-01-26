
#ifndef EAPIGLUE_H
#define EAPIGLUE_H

#include <stdint.h>

uint16_t __fastcall__ eapiInit(uint8_t* pManufacturerId, uint8_t* pDeviceId);
uint8_t __fastcall__ eapiGetBank(void);
void __fastcall__ eapiSetBank(uint8_t nBank);
uint8_t __fastcall__ eapiSectorErase(uint8_t* pBase);
uint8_t __fastcall__ eapiWriteFlash(uint8_t* pAddr, uint8_t nVal);
uint8_t __fastcall__ eapiGlueWriteBlock(uint8_t* pDst, uint8_t* pSrc);

#define EAPI_LOAD_TO ((uint8_t*)0xc000)
#define EAPI_DRIVER_NAME ((const char*)0xc000 + 4)
#define EAPI_SIZE 0x300

extern uint8_t aEAPIDrivers[][EAPI_SIZE];

#endif
