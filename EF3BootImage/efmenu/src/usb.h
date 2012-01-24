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
void usbSendResponseLOAD(void);
void usbSendResponseBTYP(void);

#endif /* USB_H_ */
