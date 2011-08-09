
#ifndef SCREEN_H_
#define SCREEN_H_

#include <c64.h>
#include <stdint.h>

#define COLOR_BACKGROUND COLOR_LIGHTBLUE
#define COLOR_LIGHTFRAME COLOR_GRAY1
#define COLOR_FOREGROUND COLOR_BLACK
#define COLOR_EXTRA      COLOR_BROWN

#define BUTTON_ENTER     0x01
#define BUTTON_STOP      0x02

/**
 * Define this to 1 if you want the screen to get restored when a dialog bis
 * has been closed. It costs about 2 kByte.
 */
#define SCREEN_RESTAURATION 1

/**
 * This type describes an entry in a menu.
 * The last Entry (terminator) has all fields set to zero.
 */
typedef struct ScreenMenuEntry_s
{
    const char* pStrLabel;
    void (*pFunction)(void);
    uint8_t (*pCheckFunction)(void);
}
ScreenMenuEntry;

void screenInit(void);
void screenBing(void);
void __fastcall__ screenPrintHex2(uint8_t n);
void __fastcall__ screenPrintHex4(uint16_t n);
void __fastcall__ screenPrintAddr(uint8_t nBank, uint8_t nChip, uint16_t nOffset);
void screenPrintFrame(void);
void screenPrintBox(uint8_t x, uint8_t y, uint8_t w, uint8_t h);
void screenPrintSepLine(uint8_t xStart, uint8_t xEnd, uint8_t y);
uint8_t __fastcall__ screenPrintDialog(const char* apStrLines[], uint8_t flags);
void __fastcall__ screenPrintSimpleDialog(const char* apStrLines[]);
uint8_t __fastcall__ screenPrintTwoLinesDialog(const char* p1, const char* p2);
uint8_t __fastcall__ screenAskEraseDialog(void);
void __fastcall__ screenPrintVerifyError(uint8_t nBank, uint8_t nChip,
                                         uint16_t nOffset,
                                         uint8_t nData,
                                         uint8_t nFlashVal);
uint8_t __fastcall__ screenWaitKey(uint8_t flags);
const char* __fastcall__ screenReadInput(const char* pStrTitle, const char* pStrPrompt);

void __fastcall__ screenPrintMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries,
                                  uint8_t nSelected, uint8_t bPrintFrame);

const ScreenMenuEntry* __fastcall__ screenDoMenu(uint8_t x, uint8_t y,
                               const ScreenMenuEntry* pMenuEntries);
void screenShowSprites(void);

#endif /* SCREEN_H_ */
