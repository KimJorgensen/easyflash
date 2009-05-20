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
#include <stdio.h>

/******************************************************************************/
/**
 * Initialize the screen. Set up colors and clear it.
 */
void screenInit(void)
{
	bgcolor(COLOR_GRAY3);
    bordercolor(COLOR_GRAY3);
    textcolor(COLOR_BLACK);
    clrscr();
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
    uint8_t x;

    --xEnd;

    cputcxy(xStart, y, 0xb0);
    for (x = xStart; x != xEnd; ++x)
        cputc(0x60);
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
    uint8_t x;

    --xEnd;

    cputcxy(xStart, y, 0xab);
    for (x = xStart; x != xEnd; ++x)
        cputc(0x60);
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
    uint8_t x;

    --xEnd;

    cputcxy(xStart, y, 0xad);
    for (x = xStart; x != xEnd; ++x)
        cputc(0x60);
    cputc(0xbd);
}


/******************************************************************************/
/**
 * Print a separation line at y between xStart and xEnd (incl).
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
    cputcxy(xEnd, y, 0x7d);
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
    // separation line
    screenPrintSepLine(0, 39, 2);
    // some free lines
    for (y = 3; y < 24; ++y)
        screenPrintFreeLine(0, 39, y);
    // Bottom line
    screenPrintBottomLine(0, 39, 24);

    cputsxy(1, 1, "EasyProg");
}


/******************************************************************************/
/**
 * Print a Button with a label. x/y is the upper left corner. The first
 * character of the label is printed inverse
 */
void screenPrintButton(uint8_t x, uint8_t y, const char* pStrLabel)
{
    unsigned char oldColor;
    uint8_t len;
    uint8_t xEnd;

    oldColor = textcolor(COLOR_BLUE);
    len = strlen(pStrLabel);
    xEnd = x + len + 1;

    screenPrintTopLine(x, xEnd, y++);

    cputcxy(x, y++, 0x7d);
    textcolor(COLOR_BLACK);
    revers(1);
    cputc(pStrLabel[0]);
    revers(0);
    cputs(pStrLabel + 1);
    textcolor(COLOR_BLUE);
    cputc(0x7d);

    screenPrintBottomLine(x, xEnd, y);

    textcolor(oldColor);
}


/******************************************************************************/
/**
 * Print a dialog with some text lines.
 * The array of lines apStrLines must be terminated with a NULL pointer.
 */
void screenPrintDialog(const char* apStrLines[])
{
    uint8_t y, t;
    uint8_t nLines;
    uint8_t nLongestLength = 1;
    uint8_t xStart, xEnd;
    uint8_t yStart, yEnd;

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
    for (y = 0; y < nLines; ++y)
    {
        t = strlen(apStrLines[y]);
        if (t > 38)
            continue;

        cputsxy(20 - t / 2, yStart++, apStrLines[y]);
    }

    screenPrintButton(xEnd - 4, yEnd - 3, "OK");
}


/******************************************************************************/
/**
 * Print a dialog with some text lines.
 * The array of lines apStrLines must be terminated with a NULL pointer.
 */
void screenWaitOKKey(void)
{
    char key;
    do
    {
        key = cgetc();
    }
    while ((key != '\n') && (key != 'o'));
}
