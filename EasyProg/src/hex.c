/*
 * hex.c
 *
 *  Created on: 04.06.2009
 *      Author: skoe
 */

#include <conio.h>
#include <stdint.h>
#include <string.h>

#include "flash.h"
#include "eapiglue.h"
#include "util.h"
#include "screen.h"
#include "slots.h"

/******************************************************************************/
/* Static variables */

static uint8_t nBank;
static uint8_t nChip;
static uint16_t nOffset;

/******************************************************************************/
/**
 * Show 128 bytes of hexdump.
 */
static void hexShowBlock(void)
{
    uint8_t  x;
    uint8_t  y;
    uint8_t  nVal;
    uint8_t* p;
    uint16_t n;

    if (nChip)
        p = ROM1_BASE;
    else
        p = ROM0_BASE;

    p += nOffset;
    eapiSetSlot(g_nSelectedSlot);
    eapiSetBank(nBank);

    gotoxy(1, 23);
    screenPrintAddr(nBank, nChip, nOffset);
    if (g_nSlots > 1)
    {
        strcpy(utilStr, ", slot ");
        utilAppendDecimal(g_nSelectedSlot);
        cputs(utilStr);
    }

    n = nOffset;
    for (y = 0; y < 16; ++y)
    {
        gotoxy(1, 3 + y);
        screenPrintHex4(n);
        cputc(' ');

        for (x = 0; x < 8; ++x)
        {
            screenPrintHex2(efPeekCartROM(p++));
            cputc(' ');
        }

        p -= 8;
        for (x = 0; x < 8; ++x)
        {
            nVal = efPeekCartROM(p++);
            if (nVal < ' ')
                cputc('.');
            else
                cputc(nVal);
        }

        n += 8;
    }
}


/******************************************************************************/
/**
 * Advance to the next bank, if possible.
 */
static void hexNextBank(void)
{
    if (!nChip)
    {
        nOffset = 0;
        nChip = 1;
    }
    else if (nBank < FLASH_NUM_BANKS)
    {
        ++nBank;
        nChip = 0;
        nOffset = 0;
    }
}


/******************************************************************************/
/**
 * Go to the given offset of the previous bank, if possible.
 */
static void hexPrevBank(uint16_t nToOffset)
{
    if (nChip)
    {
        nOffset = nToOffset;
        nChip = 0;
    }
    else if (nBank > 0)
    {
        --nBank;
        nChip = 1;
        nOffset = nToOffset;
    }
}


/******************************************************************************/
/**
 * The hexdump viewer
 */
void hexViewer(void)
{
    char key;
    uint8_t  prevKeyRepeat;

    // we can discard the values => just use "key"
    if (!eapiInit(&key, &key))
        return;

    screenPrintFrame();
    screenPrintSepLine(0, 39, 20);

    prevKeyRepeat = screenSetKeyRepeat(KEY_REPEAT_ALL);
    cputsxy(1, 1, "Hex Viewer");
    strcpy(utilStr, "<Up>/<Down>/<+>/<->");
    if (g_nSlots > 1)
    {
        utilAppendStr("/<0>..<");
        utilAppendDecimal(g_nSlots - 1);
        utilAppendChar('>');
    }
    utilAppendStr("/<Stop>");
    cputsxy(1, 21, utilStr);

    g_nSelectedSlot = nBank = nChip = nOffset = 0;

    do
    {
        hexShowBlock();

        key = cgetc();
        switch (key)
        {
        case CH_CURS_DOWN:
            if (nOffset < 0x2000 - 0x80)
                nOffset += 0x80;
            else
                hexNextBank();
            break;

        case CH_CURS_UP:
            if (nOffset > 0)
                nOffset -= 0x80;
            else
                hexPrevBank(0x2000 - 0x80);
            break;

        case '+':
            hexNextBank();
            break;

        case '-':
            hexPrevBank(0);
            break;

        default:
            if (key >= '0' && key < g_nSlots + '0')
            {
                g_nSelectedSlot = key - '0';
                hexShowBlock();
            }
        }
    }
    while (key != CH_STOP);

    screenSetKeyRepeat(prevKeyRepeat);
}
