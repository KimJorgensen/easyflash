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
#include "timer.h"
#include "write.h"
#include "torturetest.h"
#include "filedlg.h"
#include "sprites.h"
#include "util.h"

/******************************************************************************/
static void showAbout(void);
static void toggleFastLoader(void);
static void checkEraseAll(void);
static uint8_t returnTrue(void);
static uint8_t ifHaveValidFlash(void);
static void updateFastLoaderText();

/******************************************************************************/


// Low/High flash chip manufacturer/device ID
uint8_t nManufacturerId;
uint8_t nDeviceId;
const char* pStrFlashDriver = "";


uint8_t g_bFastLoaderEnabled;


/******************************************************************************/
/* Static variables */

// String describes the current action
static char strStatus[41];

static char strFastLoader[30];

/******************************************************************************/

// forward declarations
extern ScreenMenu menuMain;
extern ScreenMenu menuOptions;
extern ScreenMenu menuExpert;
extern ScreenMenu menuHelp;


ScreenMenu menuMain =
{
    1, 2,
    0,
    &menuHelp,
    &menuOptions,
    {
        {
            "&Write CRT to flash",
            checkWriteCRTImage,
            ifHaveValidFlash,
            0
        },
        {
            "&Check flash type",
            (void (*)(void)) checkFlashType,
            returnTrue,
            0
        },
        {
            "&Erase all",
            checkEraseAll,
            returnTrue, //ifHaveValidFlash,
            0
        },
        {
            "&Start cartridge",
            utilResetStartCartridge,
            returnTrue,
            0
        },
        {
            "&Reset, cartridge off",
            utilResetKillCartridge,
            returnTrue,
            0
        },
        { NULL, NULL, 0, 0 }
    }
};


ScreenMenu menuOptions =
{
    7, 2,
    0,
    &menuMain,
    &menuExpert,
    {
        {
            strFastLoader,
            toggleFastLoader,
            returnTrue,
            SCREEN_MENU_ENTRY_FLAG_KEEP
        },
        { NULL, NULL, 0 }
    }
};


ScreenMenu menuExpert =
{
    16, 2,
    0,
    &menuOptions,
    &menuHelp,
    {
        {
            "Write BIN to &LOROM",
            checkWriteLOROMImage,
            returnTrue, //ifHaveValidFlash,
            0
        },
        {
            "Write BIN to &HIROM",
            checkWriteHIROMImage,
            returnTrue, //ifHaveValidFlash,
            0
        },
        {
            "&Torture test",
            tortureTestComplete,
            returnTrue, //ifHaveValidFlash,
            0
        },
        {
            "&Read torture test",
            tortureTestRead,
            returnTrue, //ifHaveValidFlash,
            0
        },
        {
            "R&AM test",
            tortureTestRAM,
            returnTrue,
            0
        },
        {
            "He&x viewer",
            hexViewer,
            returnTrue, //ifHaveValidFlash,
            0
        },
        { NULL, NULL, 0, 0 }
    }
};

ScreenMenu menuHelp =
{
    24, 2,
    0,
    &menuExpert,
    &menuMain,
    {
        {
            "&About",
            showAbout,
            returnTrue,
            0
        },
        { NULL, NULL, 0, 0 }
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
    cputc('O');
    textcolor(COLOR_FOREGROUND);
    cputs("ptions  ");

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

    gotoxy(3, 11);
    cputs("Flash Driver:");
    gotox(17);
    cputs(pStrFlashDriver);

    textcolor(COLOR_LIGHTFRAME);
    screenPrintBox(16, 13, 23, 3);
    textcolor(COLOR_FOREGROUND);

    gotoxy(3, 14);
    cputs("Time elapsed:");

    refreshElapsedTime();
    progressShow();
    refreshStatusLine();
}


/******************************************************************************/
/**
 */
static void leadingZero(uint16_t v)
{
    utilStr[0] = '\0';
    if (v < 10)
    {
        utilStr[0] = '0';
        utilStr[1] = '\0';
    }
}


/******************************************************************************/
/**
 * Refresh the elapsed time value.
 */
void refreshElapsedTime(void)
{
    uint16_t t;

    t = timerGet();
    gotoxy(17, 14);
    leadingZero(t >> 8);
    utilAppendDecimal(t >> 8);
    cputs(utilStr);
    cputc(':');
    leadingZero(t & 0xff);
    utilAppendDecimal(t & 0xff);
    cputs(utilStr);
}


/******************************************************************************/
/**
 * Read Flash manufacturer and device IDs, print then on the screen.
 * If they are not okay, print an error message and return 0.
 * If everything is okay, return 1.
 */
uint8_t checkFlashType(void)
{
    uint8_t* pDriver;
    uint8_t  bDriverFound = 0;

    pDriver = aEAPIDrivers[0];
    while (*pDriver)
    {
        memcpy(EAPI_LOAD_TO, pDriver, EAPI_SIZE);

        if (eapiInit(&nManufacturerId, &nDeviceId) > 0)
        {
            bDriverFound = 1;
            break;
        }

        /* if we are here, there is an error */
        switch (nDeviceId)
        {
        case EAPI_ERR_RAM:
            screenPrintSimpleDialog(apStrBadRAM);
            goto failed;

        case EAPI_ERR_ROML_PROTECTED:
            screenPrintSimpleDialog(apStrROMLProtected);
            goto failed;

        case EAPI_ERR_ROMH_PROTECTED:
            screenPrintSimpleDialog(apStrROMHProtected);
            goto failed;
        }
        pDriver += EAPI_SIZE;
    }

    if (bDriverFound)
    {
        pStrFlashDriver = EAPI_DRIVER_NAME;
        refreshMainScreen();
        return 1;
    }
    else
    {
        screenPrintSimpleDialog(apStrWrongFlash);
    }

failed:
    pStrFlashDriver = "(failed)";
    refreshMainScreen();
    nManufacturerId = nDeviceId = 0;
    return 0;
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
 * Toggle the fast loader setting.
 */
static void toggleFastLoader(void)
{
    g_bFastLoaderEnabled = !g_bFastLoaderEnabled;
    updateFastLoaderText();
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
 * Update the "Fast loader enabled:    " text.
 */
static void updateFastLoaderText()
{
    char* pStr;

    strcpy(strFastLoader, "&Fastloader enabled: ");
    pStr = g_bFastLoaderEnabled ? "Yes" : "No";
    strcat(strFastLoader, pStr);
}


/******************************************************************************/
/**
 *
 */
int main(void)
{
    char key;

    timerInitTOD();
    screenInit();
    progressInit();

    g_strFileName[0] = '\0';
    g_nDrive = *(uint8_t*)0xba;
    if (g_nDrive < 8)
        g_nDrive = 8;

    internalCartType = INTERNAL_CART_TYPE_NONE;

    g_bFastLoaderEnabled = 1;
    updateFastLoaderText();

    refreshMainScreen();
    showAbout();
    refreshMainScreen();
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

        case 'o':
            execMenu(&menuOptions);
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
