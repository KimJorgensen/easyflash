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
#include <6502.h>

#include "eftest.h"
#include "screen.h"
#include "texts.h"
#include "torturetest.h"

/******************************************************************************/
static void showAbout(void);
static uint8_t returnTrue(void);
static void busTest1(void);
static void busTest2(void);
static void kernalRamTest(void);

/******************************************************************************/

/******************************************************************************/
/* Static variables */

// String describes the current action
static char strStatus[41];

/******************************************************************************/

ScreenMenuEntry aMainMenuEntries[] =
{
        {
            "1 Bus Test DExx <= xx",
            busTest1,
            returnTrue
        },
        {
            "2 Bus Test DE55 = 55, DEAA = AA",
            busTest2,
            returnTrue
        },
        {
            "3 Kernal/RAM Test",
            kernalRamTest,
            returnTrue
        },
        {
            "4 Read RAM below kernal",
            kernalRamRead,
            returnTrue
        },
        {
            "5 Write & compare RAM below kernal",
            kernalRamWriteCompare,
            returnTrue
        },
        { NULL, NULL, 0 }
};


ScreenMenuEntry aHelpMenuEntries[] =
{
        {
            "About",
            showAbout,
            returnTrue
        },
        { NULL, NULL, 0 }
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
 * Copy the given string to the status line.
 */
void setStatusLine(const char* str)
{
    strcpy(strStatus, str);
    refreshStatusLine();
}

/******************************************************************************/
/**
 * Show or refresh the Screen which reports the Flash IDs.
 */
void refreshMainScreen(void)
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

    refreshStatusLine();
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
 * Show the about dialog.
 */
static void showAbout(void)
{
    screenPrintSimpleDialog(apStrAbout);
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
static void __fastcall__ execMenu(uint8_t x, uint8_t y,
                                  const ScreenMenuEntry* pMenuEntries)
{
    screenDoMenu(x, y, pMenuEntries);
    refreshMainScreen();
}


/******************************************************************************/
/**
 *
 */
static void busTest1(void)
{
    uint8_t v, offset;

    v = 0;
    offset = 0;

    for (;;)
    {
        do
        {
            *((uint8_t*) 0xde00 + offset) = v;
            if (*((uint8_t*) 0xde00 + offset) != v)
                ++*((uint8_t*)0xd020);

            ++offset;
        } while (offset);
        ++v;
        *((uint8_t*) 0x0400) = v;
    }
}

static void busTest2(void)
{
    SEI();
    for (;;)
    {
        *((uint8_t*) 0xde55) = 0x55;
        *((uint8_t*) 0xdeaa) = 0xaa;
    }
}

/******************************************************************************/
/**
 *
 */
int main(void)
{
    char key;

    screenInit();
    refreshMainScreen();

    screenBing();

    for (;;)
    {
        setStatus("Ready. Press <m> for Menu.");

        key = cgetc();
        switch (key)
        {
        case 'm':
            execMenu(1, 2, aMainMenuEntries);
            break;

        case 'h':
            execMenu(15, 2, aHelpMenuEntries);
            break;
        }
    }
    return 0;
}
