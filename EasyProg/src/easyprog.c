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
#include "eapiglue.h"
#include "flash.h"
#include "texts.h"
#include "buffer.h"
#include "hex.h"
#include "progress.h"
#include "write.h"
#include "torturetest.h"
#include "filedlg.h"
#include "sprites.h"
#include "util.h"

/******************************************************************************/
static void showAbout(void);
static void checkEraseAll(void);
static uint8_t returnTrue(void);
static uint8_t ifHaveValidFlash(void);

/******************************************************************************/


// Low/High flash chip manufacturer/device ID
uint8_t nManufacturerId;
uint8_t nDeviceId;

// Driver name
char strDriverName[18 + 1] = "Internal Fallback";

// EAPI signature
static const unsigned char pStrEAPISignature[] =
{
        0x65, 0x61, 0x70, 0x69 /* "EAPI" */
};

/******************************************************************************/
/* Static variables */

// String describes the current action
static char strStatus[41];

/******************************************************************************/

// forward declarations
extern ScreenMenu menuMain;
extern ScreenMenu menuExpert;
extern ScreenMenu menuHelp;


ScreenMenu menuMain =
{
    1, 2,
    0,
    &menuHelp,
    &menuExpert,
    {
        {
            "&Write CRT to flash",
            checkWriteCRTImage,
            ifHaveValidFlash
        },
        {
            "&Check flash type",
            (void (*)(void)) checkFlashType,
            returnTrue
        },
        {
            "&Erase all",
            checkEraseAll,
            ifHaveValidFlash
        },
        {
            "&Start cartridge",
            utilResetStartCartridge,
            returnTrue
        },
        {
            "&Reset, cartridge off",
            utilResetKillCartridge,
            returnTrue
        },
        { NULL, NULL, 0 }
    }
};

ScreenMenu menuExpert =
{
    7, 2,
    0,
    &menuMain,
    &menuHelp,
    {
        {
            "Write BIN to &LOROM",
            checkWriteLOROMImage,
            ifHaveValidFlash
        },
        {
            "Write BIN to &HIROM",
            checkWriteHIROMImage,
            ifHaveValidFlash
        },
        {
            "&Torture test",
            tortureTestComplete,
            ifHaveValidFlash
        },
        {
            "&Read torture test",
            tortureTestRead,
            ifHaveValidFlash
        },
        {
            "R&AM test",
            tortureTestRAM,
            returnTrue
        },
        {
            "&Hex viewer",
            hexViewer,
            ifHaveValidFlash
        },
        { NULL, NULL, 0 }
    }
};

ScreenMenu menuHelp =
{
    15, 2,
    0,
    &menuExpert,
    &menuMain,
    {
        {
            "&About",
            showAbout,
            returnTrue
        },
        { NULL, NULL, 0 }
    }
};


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
 * Show or refresh the Screen which reports the Flash IDs.
 */
void refreshMainScreen(void)
{
    const char* str;

    screenPrintFrame();

    // menu entries
    gotoxy (1, 1);
    textcolor(COLOR_EXTRA);
    cputc('M');
    textcolor(COLOR_FOREGROUND);
    cputs("enu  ");

    textcolor(COLOR_EXTRA);
    cputc('E');
    textcolor(COLOR_FOREGROUND);
    cputs("xpert  ");

    textcolor(COLOR_EXTRA);
    cputc('H');
    textcolor(COLOR_FOREGROUND);
    cputs("elp");

    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(16, 4, 23, 3);
    screenPrintBox(16, 7, 23, 3);
    textcolor(COLOR_FOREGROUND);

    gotoxy(6, 5);
    cputs("File name:");
    gotox(17);
    cputs(g_strFileName);

    gotoxy(7, 8);
    cputs("CRT Type:");
    gotox(17);
    cputs(aStrInternalCartTypeName[internalCartType]);

    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(16, 10, 23, 3);
    textcolor(COLOR_FOREGROUND);

    gotoxy(7, 11);
    cputs("Flash ID:");
    gotox(17);

    utilStr[0] = '\0';
    utilAppendHex2(nManufacturerId);
    utilAppendHex2(nDeviceId);
    cputs(utilStr);

    switch ((nManufacturerId << 8) | nDeviceId)
    {
    case FLASH_TYPE_AMD_AM29F040:
        str = " (Am29F040)";
        break;

    case FLASH_TYPE_AMD_M29W160ET:
        str = " (M29W160ET)";
        break;

    default:
        str = " (unknown)";
    }
    cputs(str);

    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(16, 13, 23, 3);
    textcolor(COLOR_FOREGROUND);

    gotoxy(3, 14);
    cputs("Flash Driver:");
    gotox(17);
    cputs(strDriverName);

    progressShow();

    refreshStatusLine();
}


/******************************************************************************/
/**
 * Read Flash manufacturer and device IDs, print then on the screen.
 * If they are not okay, print an error message and return 0.
 * If everything is okay, return 1.
 */
uint8_t checkFlashType(void)
{
    if (eapiInit(&nManufacturerId, &nDeviceId) == 0)
    {
        screenPrintSimpleDialog(apStrWrongFlash);
        refreshMainScreen();
        nManufacturerId = nDeviceId = 0;
        return 0;
    }

    refreshMainScreen();
    return 1;
}


/******************************************************************************/
/**
 * Always return 1.
 */
static uint8_t returnTrue(void)
{
   return 1;
}


/******************************************************************************/
/**
 * Return non-0 if the flash is okay and we have a driver which supports it.
 */
static uint8_t ifHaveValidFlash(void)
{
    return nManufacturerId | nDeviceId;
}

/******************************************************************************/
/**
 * Check if the RAM at $DF00 is okay.
 * If it is not okay, print an error message.
 */
static void checkRAM(void)
{
    if (!tortureTestCheckRAM())
    {
        screenPrintSimpleDialog(apStrBadRAM);
        refreshMainScreen();
    }
}


/******************************************************************************/
/**
 * Show the about dialog.
 */
static void showAbout(void)
{
    spritesShow();
    screenPrintSimpleDialog(apStrAbout);
    spritesOn(0);
}


/******************************************************************************/
/**
 * Ask the user if it is okay to erase all and do so if yes.
 */
static void checkEraseAll(void)
{
    if (screenAskEraseDialog() == BUTTON_ENTER)
    {
        checkFlashType();
        eraseAll();

        // remove the name, it's not valid anymore
        g_strFileName[0] = '\0';
        internalCartType = INTERNAL_CART_TYPE_NONE;
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
 * Execute an action according to the given menu ID.
 */
static void __fastcall__ execMenu(ScreenMenu* pMenu)
{
    screenDoMenu(pMenu);
    refreshMainScreen();
}


/******************************************************************************/
/**
 * Load EAPI driver.
 */
static void loadEAPI(void)
{
    memcpy(EAPI_LOAD_TO, pFallbackDriverStart,
           pFallbackDriverEnd - pFallbackDriverStart);
    EAPI_ZP_REAL_CODE_BASE = EAPI_LOAD_TO;
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

    g_strFileName[0] = '\0';
    g_nDrive = *(uint8_t*)0xba;
    if (g_nDrive < 8)
        g_nDrive = 8;

    internalCartType = INTERNAL_CART_TYPE_NONE;

    refreshMainScreen();
    showAbout();
    loadEAPI();
    screenBing();

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
            execMenu(&menuMain);
            break;

        case 'e':
            execMenu(&menuExpert);
            break;

        case 'h':
            execMenu(&menuHelp);
            break;
        }
    }
    return 0;
}
