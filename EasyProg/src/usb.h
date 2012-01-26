/*
 * usb.h
 *
 *  Created on: 25.10.2011
 *      Author: skoe
 */

#ifndef USB_H_
#define USB_H_

void usbDiscardBuffer(void);
char* usbCheckForCommand(void);
void usbSendResponseWAIT(void);
void usbSendResponseSTOP(void);
void usbSendResponseLOAD(void);
void usbSendResponseBTYP(void);

/* these functions can be used after usbSendResponseLOAD(): */
unsigned int __fastcall__ usbReadFile(void* buffer, unsigned int size);
void usbCloseFile(void);

#endif /* USB_H_ */
