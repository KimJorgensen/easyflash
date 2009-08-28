/*
 * EasyProg - screen.c - Functions for the screen
 *
 * (c) 2009 Thomas Giesel
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Thomas Giesel skoe@directbox.com
 */

#include <stdint.h>
#include <conio.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#include "screen.h"
#include "texts.h"
#include "sprites.h"

static const char* pStrHexDigits = "0123456789ABCDEF";

/******************************************************************************/
/**
 * Initialize the screen. Set up colors and clear it.
 */
void screenInit(void)
{
	bgcolor(COLOR_BACKGROUND);
    bordercolor(COLOR_BACKGROUND);
    textcolor(COLOR_FOREGROUND);
    clrscr();
}

/******************************************************************************/
/**
 */
void __fastcall__ screenPrintHex2(uint8_t n)
{
    uint8_t tmp;

    tmp = n >> 4;
    cputc(pStrHexDigits[tmp]);
    cputc(pStrHexDigits[n & 0xf]);
}

/******************************************************************************/
/**
 */
void __fastcall__ screenPrintHex4(uint16_t n)
{
    uint8_t tmp;

    tmp = n >> 8;
    screenPrintHex2(tmp);
    screenPrintHex2((uint8_t) n);
}

/******************************************************************************/
/**
 */
void __fastcall__ screenPrintAddr(uint8_t nBank, uint8_t nChip, uint16_t nOffset)
{
    screenPrintHex2(nBank);
    cputc(':');
    if (nChip)
        cputc('1');
    else
        cputc('0');
    cputc(':');
    screenPrintHex4(nOffset);
}


/******************************************************************************/
/**
 * Print the Top line of a frame at y between xStart and xEnd (incl).
 *
 * ++++++++ <= This one
 * +      +
 * ++++++++
 * +      +
 * ++++++++
 */
void screenPrintTopLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    --xEnd;

    cputcxy(xStart, y, 0xb0);
    chline(xEnd - xStart);
    cputc(0xae);
}


/******************************************************************************/
/**
 * Print a separation line at y between xStart and xEnd (incl).
 *
 * ++++++++
 * +      +
 * ++++++++ <= This one
 * +      +
 * ++++++++
 */
void screenPrintSepLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    --xEnd;

    cputcxy(xStart, y, 0xab);
    chline(xEnd - xStart);
    cputc(0xb3);
}


/******************************************************************************/
/**
 * Print the bottom line of a frame at y between xStart and xEnd (incl).
 *
 * ++++++++
 * +      +
 * ++++++++
 * +      +
 * ++++++++ <= This one
 */
void screenPrintBottomLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    --xEnd;

    cputcxy(xStart, y, 0xad);
    chline(xEnd - xStart);
    cputc(0xbd);
}


/******************************************************************************/
/**
 * Print a free line at y between xStart and xEnd (incl).
 *
 * ++++++++
 * +      + <= This one
 * ++++++++
 * +      +
 * ++++++++
 */
void screenPrintFreeLine(uint8_t xStart, uint8_t xEnd, uint8_t y)
{
    cputcxy(xStart, y, 0x7d);
    cclear(xEnd - xStart - 1);
    cputc(0x7d);
}


/******************************************************************************/
/**
 * Draw the big screen and the screen divisions.
 */
void screenPrintFrame(void)
{
    uint8_t y;

    // Top line
    screenPrintTopLine(0, 39, 0);
    // 1 text line
    screenPrintFreeLine(0, 39, 1);
    // separation line with "step"
    screenPrintSepLine(0, 28, 2);
    screenPrintFreeLine(28, 39, 2);
    screenPrintFreeLine(0, 28, 3);
    screenPrintSepLine(28, 39, 3);
    cputcxy(28, 2, 0xae);
    cputcxy(28, 3, 0xad);

    // some free lines
    for (y = 4; y < 22; ++y)
        screenPrintFreeLine(0, 39, y);
    // separation line
    screenPrintSepLine(0, 39, 22);
    // 1 text line
    screenPrintFreeLine(0, 39, 23);
    // Bottom line
    screenPrintBottomLine(0, 39, 24);
}


/******************************************************************************/
/**
 * Draw a box.
 *
 * The size is incl. border
 */
void screenPrintBox(uint8_t x, uint8_t y, uint8_t w, uint8_t h)
{
    uint8_t i;

    --w;

    // Top line
    screenPrintTopLine(x, x + w, y);

    for (i = h - 2; i; --i)
    {
        // text line
        screenPrintFreeLine(x, x + w, ++y);
    }

    // Bottom line
    screenPrintBottomLine(x, x + w, ++y);
}


/******************************************************************************/
/**
 * Print a Button with a label. x/y is the upper left corner.
 */
void screenPrintButton(uint8_t x, uint8_t y, const char* pStrLabel)
{
    uint8_t len;
    uint8_t xEnd;

    len = strlen(pStrLabel);
    xEnd = x + len + 1;

    screenPrintTopLine(x, xEnd, y++);

    cputcxy(x, y++, 0x7d);
    cputs(pStrLabel);
    cputc(0x7d);

    screenPrintBottomLine(x, xEnd, y);
}


/******************************************************************************/
/**
 * Show or update the menu.
 *
 * If bPrintFrame is set, also draw the frame.
 */
void __fastcall__ screenPrintMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries,
                                  uint8_t nSelected, uint8_t bPrintFrame)
{
    uint8_t nEntry, nEntries;
    uint8_t tmp;
    uint8_t len;
    const char* pStr;

    // calculate length of longest entry
    len = 2;
    for (nEntry = 0; (pStr = pMenuEntries[nEntry].pStrLabel); ++nEntry)
    {
        tmp = strlen(pStr);
        if (tmp > len)
            len = tmp;
    }
    len += 2;
    nEntries = nEntry;

    if (bPrintFrame)
    {
        screenPrintBox(x, y, len + 2, nEntries + 2);
    }

    for (nEntry = 0; nEntry != nEntries; ++nEntry)
    {
        gotoxy(x + 1, ++y);

        pStr = pMenuEntries[nEntry].pStrLabel;

        if (nEntry == nSelected)
            revers(1);

        cputc(' ');
        textcolor(COLOR_EXTRA);
        cputc(*pStr);
        textcolor(COLOR_FOREGROUND);
        cputs(pStr + 1);
        cclear(len + x - wherex() + 1);

        revers(0);
    }
}


/******************************************************************************/
/**
 * Show and handle the menu and return the item Id selected or 0.
 */
uint8_t __fastcall__ screenDoMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries)
{
    uint8_t nEntry, nEntries;
    uint8_t nSelected;
    char key;

    screenPrintMenu(x, y, pMenuEntries, nSelected, 1);

    // count the entries
    nEntries = 0;
    for (nEntry = 0; pMenuEntries[nEntry].pStrLabel; ++nEntry)
        ++nEntries;

    nSelected = 0;

    do
    {
        screenPrintMenu(x, y, pMenuEntries, nSelected, 0);
        key = cgetc();
        switch (key)
        {
        case CH_CURS_UP:
            if (nSelected)
                --nSelected;
            else
                nSelected = nEntries - 1;
            break;

        case CH_CURS_DOWN:
            if (++nSelected == nEntries)
                nSelected = 0;
            break;

        case CH_ENTER:
            return pMenuEntries[nSelected].nId;
            break;

        default:
            for (nEntry = 0; nEntry != nEntries; ++nEntry)
                if (key == tolower(pMenuEntries[nEntry].pStrLabel[0]))
                {
                    screenPrintMenu(x, y, pMenuEntries, nEntry, 0);
                    return pMenuEntries[nEntry].nId;
                }
        }
    } while (key != CH_STOP);

    return 0;
}

/******************************************************************************/
/**
 * Print a dialog with some text lines and wait for a key.
 * The array of lines apStrLines must be terminated with a NULL pointer.
 *
 * flags            can contain BUTTON_ENTER and/or BUTTON_STOP.
 * return           the button which has been pressed
 */
uint8_t __fastcall__ screenPrintDialog(const char* apStrLines[], uint8_t flags)
{
    uint8_t y, t;
    uint8_t nLines;
    uint8_t nLongestLength = 1;
    uint8_t xStart, xEnd, yStart, yEnd;

    for (y = 0; apStrLines[y]; ++y)
    {
        t = strlen(apStrLines[y]);
        if (t > nLongestLength)
            nLongestLength = t;
    }
    nLines = y;

    if (nLongestLength > 38)
        nLongestLength = 38;

    nLongestLength += 2;
    xStart = 20 - nLongestLength / 2;
    xEnd = 20 + nLongestLength / 2;
    yStart = 8 - nLines / 2;
    yEnd = 8 + nLines / 2 + 9;

    // Top line
    y = yStart;
    screenPrintTopLine(xStart, xEnd, y);
    screenPrintFreeLine(xStart, xEnd, ++y);
    cputsxy(xStart + 1, y, "EasyProg");
    screenPrintSepLine(xStart, xEnd, ++y);

    // some lines
    for (++y; y < yEnd; ++y)
        screenPrintFreeLine(xStart, xEnd, y);
    // Bottom line
    screenPrintBottomLine(xStart, xEnd, y);

    // Write the text lines
    yStart += 4;
    ++xStart;
    for (y = 0; y < nLines; ++y)
    {
        t = strlen(apStrLines[y]);
        if (t > 38)
            continue;

        cputsxy(xStart, yStart++, apStrLines[y]);
    }

    y = yEnd - 3;
    if (flags & BUTTON_ENTER)
        screenPrintButton(xEnd - 7, yEnd - 3, "Enter");

    if (flags & BUTTON_STOP)
        screenPrintButton(xStart, yEnd - 3, "Stop");

    return screenWaitKey(flags);
}


/******************************************************************************/
/**
 * Print a dialog with some text lines and wait for <Enter>.
 * The array of lines apStrLines must be terminated with a NULL pointer.
 */
void __fastcall__ screenPrintSimpleDialog(const char* apStrLines[])
{
    screenPrintDialog(apStrLines, BUTTON_ENTER);
}


/******************************************************************************/
/**
 * Print a dialog with two text lines and wait for <Stop> or <Enter>.
 *
 * return           the button which has been pressed
 */
uint8_t __fastcall__ screenPrintTwoLinesDialog(const char* p1, const char* p2)
{
    const char* apStrLines[3];
    apStrLines[0] = p1;
    apStrLines[1] = p2;
    apStrLines[2] = NULL;
    return screenPrintDialog(apStrLines, BUTTON_ENTER | BUTTON_STOP);
}


/******************************************************************************/
/**
 * Print a dialog to ask whether it is okay to erase the flash.
 * Wait for <Stop> or <Enter>.
 *
 * return           the button which has been pressed
 */
uint8_t __fastcall__ screenAskEraseDialog(void)
{
    return screenPrintDialog(apStrAskErase, BUTTON_ENTER | BUTTON_STOP);
}


/******************************************************************************/
/**
 * Print a dialog with a verify error and wait for <Stop> or <Enter>.
 */
void __fastcall__ screenPrintVerifyError(uint8_t nBank, uint8_t nChip,
                                         uint16_t nOffset,
                                         uint8_t nData,
                                         uint8_t nFlashVal)
{
    char strStatus[41];

    sprintf(strStatus, "%02X:%X:%04X: data %02X != flash %02X",
            nBank, nChip, nOffset,
            nData, nFlashVal);

    screenPrintTwoLinesDialog("Verify error at", strStatus);
}

/******************************************************************************/
/**
 * Wait until one of the keys has been pressed.
 *
 * flags        contains the keys allowed: BUTTON_ENTER and/or BUTTON_STOP
 * return       BUTTON_ENTER or BUTTON_STOP
 */
uint8_t __fastcall__ screenWaitKey(uint8_t flags)
{
    char key;

    for (;;)
    {
        key = cgetc();

        if ((flags & BUTTON_ENTER) && key == CH_ENTER)
            return BUTTON_ENTER;

        if ((flags & BUTTON_STOP) && key == CH_STOP)
            return BUTTON_STOP;
    }
}


#if 0 // unused
/******************************************************************************/
/**
 *
 * Return the string entered.
 * Return NULL if the user pressed <stop>.
 * Not reentrant ;-)
 */
const char* __fastcall__ screenReadInput(const char* pStrTitle, const char* pStrPrompt)
{
    uint8_t y, len;
    static char strInput[FILENAME_MAX];
    char c;

    // Top line
    y = 6;
    screenPrintTopLine(2, 37, y);
    screenPrintFreeLine(2, 37, ++y);
    cputsxy(3, y, pStrTitle);
    screenPrintSepLine(2, 37, ++y);

    // some lines
    for (++y; y < 19; ++y)
        screenPrintFreeLine(2, 37, y);
    // Bottom line
    screenPrintBottomLine(2, 37, y);

    // the prompt
    cputsxy(4, 9, pStrPrompt);

    // the input field
    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(4, 11, 32, 3);
    textcolor(COLOR_FOREGROUND);

    screenPrintButton(3, 16, "Stop");
    screenPrintButton(30, 16, "Enter");

    strInput[0] = '\0';
    len = 0;
    cursor(1);
    do
    {
        cputsxy(5, 12, strInput);
        cputc(' ');
        gotox(5 + len);

        c = cgetc();
        if ((c >= 32) && (c < 127) && (len < sizeof(strInput) - 1))
        {
            strInput[len++] = c;
        }
        else if (c == CH_DEL)
        {
            if (len)
                strInput[--len] = '\0';
        }
    } while((c != CH_ENTER) && (c != CH_STOP));

    cursor(0);

    if (c == CH_STOP)
        return NULL;
    else
        return strInput;
}
#endif
