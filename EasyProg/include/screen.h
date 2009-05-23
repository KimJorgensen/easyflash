
#ifndef SCREEN_H_
#define SCREEN_H_

#include <c64.h>

#define COLOR_BACKGROUND COLOR_LIGHTBLUE
#define COLOR_LIGHTFRAME COLOR_GRAY1
#define COLOR_FOREGROUND COLOR_BLACK


void screenInit(void);
void screenPrintFrame(void);
void screenPrintBox(uint8_t x, uint8_t y, uint8_t w, uint8_t h);
void screenPrintDialog(const char* apStrLines[]);
void screenWaitOKKey(void);
const char* screenReadInput(const char* pStrTitle, const char* pStrPrompt);

#endif /* SCREEN_H_ */
