/*
 * EasyProg - easyprog.c - The main module
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

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <conio.h>
#include <stdlib.h>
#include <cbm.h>

#include "easyprog.h"
#include "cart.h"
#include "screen.h"
#include "flashcode.h"
#include "flash.h"
#include "texts.h"
#include "filedlg.h"
#include "buffer.h"
#include "hex.h"
#include "progress.h"

/******************************************************************************/

// Low/High flash chip manufacturer/device ID
uint16_t anFlashId[2];

/******************************************************************************/
/* Static variables */

// String describes the current action
static char strStatus[41];

// Index to the currently chosen menu entry
static uint8_t nMenuSelection;

/******************************************************************************/

ScreenMenuEntry aMainMenuEntries[] =
{
        { EASYPROG_MENU_ENTRY_WRITE_CRT,  "Write CRT to flash" },
        { EASYPROG_MENU_ENTRY_VERIFY_CRT, "Verify CRT" },
        { EASYPROG_MENU_ENTRY_CHECK_TYPE, "Check flash type" },
        { EASYPROG_MENU_ENTRY_ERASE_ALL,  "Erase all" },
        { EASYPROG_MENU_ENTRY_HEX_VIEWER, "Hex viewer" },
        { EASYPROG_MENU_ENTRY_QUIT,       "Quit" },
        { 0, NULL }
};


ScreenMenuEntry aHelpMenuEntries[] =
{
        { EASYPROG_MENU_ENTRY_ABOUT,      "About" },
        { 0, NULL }
};

/******************************************************************************/
/**
 * Show a box with the current Flash type.
 */
static void showFlashTypeBox(uint8_t y, uint8_t nChip)
{
    uint16_t id;

    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(16, y, 23, 3);
    textcolor(COLOR_FOREGROUND);

    id = anFlashId[nChip];

    gotoxy (2, ++y);
    cprintf("%4s Flash ID:", apStrLowHigh[nChip]);

    gotoxy (17, y);
    cprintf("%04X (%s)", id,
        id == FLASH_TYPE_AMD_AM29F040 ? "Am29F040" : "unknown");
}


/******************************************************************************/
/**
 * Show or update a box with the current action.
 */
static void refreshStatusLine(void)
{
    gotoxy (1, 23);
    cputs(strStatus);
    cclear(39 - wherex());
}


/******************************************************************************/
/**
 * Show the Screen which reports the Flash IDs.
 */
static void refreshMainScreen(void)
{
    screenPrintFrame();

	// menu entries
    gotoxy (1, 1);
    textcolor(COLOR_EXTRA);
    cputc('M');
    textcolor(COLOR_FOREGROUND);
    cputs("enu  ");

    textcolor(COLOR_EXTRA);
    cputc('H');
    textcolor(COLOR_FOREGROUND);
    cputs("elp");

    showFlashTypeBox(10, 0);
    showFlashTypeBox(13, 1);
    progressShow();

    refreshStatusLine();
}


/******************************************************************************/
/**
 * Read Flash manufacturer and device IDs, print then on the screen.
 * If they are not okay, print an error message and return 0.
 * If everything is okay, return 1.
 */
static uint8_t checkFlashType(void)
{
#ifdef EASYFLASH_FAKE
    anFlashId[0] = FLASH_TYPE_AMD_AM29F040;
    anFlashId[1] = FLASH_TYPE_AMD_AM29F040;
#else
    anFlashId[0] = flashCodeReadIds(ROM0_BASE);
    anFlashId[1] = flashCodeReadIds(ROM1_BASE_ULTIMAX);
#endif

    if ((anFlashId[0] != FLASH_TYPE_AMD_AM29F040) ||
            (anFlashId[1] != FLASH_TYPE_AMD_AM29F040))
    {
        screenPrintSimpleDialog(apStrWrongFlash);
        refreshMainScreen();
        return 0;
    }

    refreshMainScreen();
    return 1;
}

/******************************************************************************/
/**
 * Check if the RAM at $DF00 is okay.
 * If it is not okay, print an error message.
 */
static void checkRAM(void)
{
    if (!flashCodeCheckRAM())
    {
        screenPrintSimpleDialog(apStrBadRAM);
        refreshMainScreen();
    }
}

/******************************************************************************/
/**
 * Set the status text and update the display.
 */
void __fastcall__ setStatus(const char* pStrStatus)
{
    strncpy(strStatus, pStrStatus, sizeof(strStatus - 1));
    strStatus[sizeof(strStatus) - 1] = '\0';
    refreshStatusLine();
}


/******************************************************************************/
/**
 * Write a crt image from the given file to flash. Before doing this, the
 * flash will be erased.
 *
 * If bWrite is 0, verify only.
 *
 * return CART_RV_OK or CART_RV_ERR
 */
static uint8_t writeCrtImage(uint8_t lfn, uint8_t bWrite)
{
    uint8_t rv;
    uint8_t  nBank;
    uint16_t nAddress;
    uint16_t nSize;
    BankHeader bankHeader;

    setStatus("Reading header");
    if (!readCartHeader(lfn))
    {
        screenPrintSimpleDialog(apStrHeaderReadError);
        return CART_RV_ERR;
    }

    if (bWrite)
    {
        setStatus("Erasing flash memory");
        if (!eraseAll())
        {
            screenPrintSimpleDialog(apStrEraseFailed);
            return CART_RV_ERR;
        }
    }

    do
    {
        setStatus("Reading header from file");
        rv = readNextBankHeader(&bankHeader, lfn);

        if (rv == CART_RV_OK)
        {
            nBank = bankHeader.bank[1];
            nAddress = 256 * bankHeader.loadAddr[0] + bankHeader.loadAddr[1];
            nSize = 256 * bankHeader.romLen[0] + bankHeader.romLen[1];

            if ((nAddress == (uint16_t) ROM0_BASE) && (nSize <= 0x4000))
            {
                if (nSize > 0x2000)
                {
                    flashWriteBlockFromFile(nBank, 0, 0x2000, bWrite, lfn);
                    flashWriteBlockFromFile(nBank, 1, nSize - 0x2000, bWrite, lfn);
                }
                else
                {
                    flashWriteBlockFromFile(nBank, 0, nSize, bWrite, lfn);
                }
            }
            else if (((nAddress == (uint16_t) ROM1_BASE) || (nAddress
                    == (uint16_t) ROM1_BASE_ULTIMAX)) && (nSize <= 0x2000))
            {
                flashWriteBlockFromFile(nBank, 1, nSize, bWrite, lfn);
            }
            else
            {
                // todo: error message
                gotoxy(0, 0);
                cprintf("Illegal CHIP address or size (%p, %p)", nAddress, nSize);
                for (;;)
                    ;
            }
        }
        else if (rv == CART_RV_ERR)
        {
            screenPrintSimpleDialog(apStrChipReadError);
            return CART_RV_ERR;
        }
    } while (rv == CART_RV_OK);

    setStatus("OK");
    return CART_RV_OK;
}


/******************************************************************************/
/**
 * Write and/or verify an CRT image file to the flash.
 *
 * If bWrite is 0, verify only.
 */
void checkWriteImage(uint8_t bWrite)
{
    const char *pStrTitle;
    const char *pStrInput;
    char strFileName[FILENAME_MAX];
    uint8_t lfn, rv;

    if (bWrite)
        pStrTitle = "Write CRT to flash";
    else
        pStrTitle = "Verify flash content";
    pStrInput = screenReadInput(pStrTitle, "Enter file name");

    refreshMainScreen();

    if (!pStrInput)
        return;

    strcpy(strFileName, pStrInput);

    sprintf(strStatus, "Checking %s", strFileName);
    refreshStatusLine();

    lfn = 2;
    rv = cbm_open(lfn, 8, CBM_READ, strFileName);

    if (rv)
    {
        screenPrintSimpleDialog(apStrFileOpenError);
        return;
    }

    writeCrtImage(lfn, bWrite);
    cbm_close(lfn);

    //printCartInfo();
}


/******************************************************************************/
/**
 * Execute the currently selected menu entry.
 */
void execMenuEntry(void)
{
    switch (nMenuSelection)
    {
    case EASYPROG_MENU_ENTRY_CHECK_TYPE:
        checkFlashType();
        break;

    case EASYPROG_MENU_ENTRY_ERASE_ALL:
        if (checkFlashType())
        {
            eraseAll();
        }
        break;
    }
}


/******************************************************************************/
/**
 * Execute an action according to the given menu ID.
 */
static void __fastcall__ execMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries)
{
    switch (screenDoMenu(x, y, pMenuEntries))
    {
    case EASYPROG_MENU_ENTRY_WRITE_CRT:
        checkFlashType();
        checkWriteImage(1);
        break;

    case EASYPROG_MENU_ENTRY_VERIFY_CRT:
        checkWriteImage(0);
        break;

    case EASYPROG_MENU_ENTRY_CHECK_TYPE:
        checkFlashType();
        break;

    case EASYPROG_MENU_ENTRY_ERASE_ALL:
        checkFlashType();
        eraseAll();
        break;

    case EASYPROG_MENU_ENTRY_HEX_VIEWER:
        hexViewer();
        break;

    case EASYPROG_MENU_ENTRY_QUIT:
        clrscr();
        exit(0);
        break;

    case EASYPROG_MENU_ENTRY_ABOUT:
        screenPrintSimpleDialog(apStrAbout);
        break;

    default:
        break;
    }

    refreshMainScreen();
}


/******************************************************************************/
/**
 *
 */
int main(void)
{
    char key;

    screenInit();
    progressInit();
    refreshMainScreen();

    // this also makes visible 16kByte of flash memory
    checkFlashType();
    checkRAM();

    for (;;)
    {
        setStatus("Ready. Press <m> for Menu.");

        key = cgetc();
        switch (key)
        {
        case 'm':
            execMenu(3, 2, aMainMenuEntries);
            break;

        case 'h':
            execMenu(7, 2, aHelpMenuEntries);
            break;

		// for testing
		case 'f':
		  //  fileDlg();
			break;

        default:
            break;
        }
    }
}
