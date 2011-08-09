/*
 * (c) 2010 Thomas Giesel
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
#include <stddef.h>
#include <string.h>
#include <conio.h>
#include <c64.h>

#include "text_plot.h"
#include "image_detect.h"
#include "memcfg.h"
#include "efmenu.h"


// from gfx.s
extern const uint8_t* bitmap;
extern const uint8_t* colmap;
extern const uint8_t* attrib;
extern uint8_t background;


#define MODE_EF     0
#define MODE_FC3    1
#define MODE_GEORAM 2
#define MODE_KERNAL 3


static efmenu_entry_t kernal_menu[] =
{
        { '1',    0, 	0x00,   MODE_KERNAL,    "1", "Empty" },
        { '2',    0, 	0x01,   MODE_KERNAL,    "2", "Empty" },
        { '3',    0, 	0x02,   MODE_KERNAL,    "3", "Empty" },
        { '4',    0, 	0x03,   MODE_KERNAL,    "4", "Empty" },
        { '5',    0, 	0x04,   MODE_KERNAL,    "5", "Empty" },
        { '6',    0, 	0x05,   MODE_KERNAL,    "6", "Empty" },
        { '7',    0, 	0x06,   MODE_KERNAL,    "7", "Empty" },
        { '8',    0, 	0x07,   MODE_KERNAL,    "8", "Empty" },
        { 0, 0, 0, 0, "", NULL }
};

static efmenu_entry_t ef_menu[] =
{
        { 'a',    0x01,	0, 	MODE_EF,    "A", "EF Slot 1" },
        { 'b',    0x02, 0, 	MODE_EF,    "B", "EF Slot 2" },
        { 'c',    0x03, 0, 	MODE_EF,    "C", "EF Slot 3" },
        { 'd',    0x04, 0, 	MODE_EF,    "D", "EF Slot 4" },
        { 'e',    0x05, 0, 	MODE_EF,    "E", "EF Slot 5" },
        { 'f',    0x06, 0, 	MODE_EF,    "F", "EF Slot 6" },
        { 'g',    0x07, 0, 	MODE_EF,    "G", "EF Slot 7" },
        { 0, 0, 0, 0, "", NULL }
};


void showMenu(void)
{
    uint8_t y;
    const efmenu_entry_t* entry;

    y = 2 * 8 + 4;

    entry = kernal_menu;
    while (entry->key)
    {
        text_plot_puts(2 * 8 + 4, y, entry->label);
        text_plot_puts(4 * 8 + 4, y, entry->name);
        y += 9;
        ++entry;
    }

    y = 13 * 8 + 4;
    entry = ef_menu;
    while (entry->key)
    {
        text_plot_puts(22 * 8 + 4, y, entry->label);
        text_plot_puts(24 * 8 + 4, y, entry->name);
        y += 9;
        ++entry;
    }
}


static void startMenuEntry(const efmenu_entry_t* entry)
{
	VIC.bordercolor = COLOR_WHITE;
    // Wait until the key is released
    waitForNoKey();
    // PONR
    *(uint8_t*)0xde01 = entry->slot; // <= todo: make it nice
    setBankChangeMode(entry->bank, entry->mode);
}


static void waitForKey(void)
{
    uint8_t key;
    const efmenu_entry_t* entry;

    do
    {
        if (kbhit())
        {
            key = cgetc();
            VIC.bordercolor = key;

            entry = kernal_menu;
            while (entry->key)
            {
                if (entry->key == key)
                	startMenuEntry(entry);
                ++entry;
            }
            entry = ef_menu;

            while (entry->key)
            {
                if (entry->key == key)
                	startMenuEntry(entry);
                ++entry;
            }

            if (key == 'p')
            {
            	startProgram(9); // EasyProg
            }
        }
    }
    while (1);
}

static void prepare_background(void)
{
	uint8_t y, yy;

	for (y = 0; y < 10; ++y)
	{
		yy = y + 2;
		memset(P_GFX_COLOR + 40 * yy + 2,
			   COLOR_WHITE << 4 | COLOR_BLACK, 16);
		memset(P_GFX_BITMAP + 320 * yy + 2 * 8, 0, 16 * 8);

		yy = y + 13;
		memset(P_GFX_COLOR + 40 * yy + 22,
				COLOR_WHITE << 4 | COLOR_BLACK, 16);
		memset(P_GFX_BITMAP + 320 * yy + 22 * 8, 0, 16 * 8);
	}
}


int main(void)
{
    // copy bitmap at $A000 from ROM to RAM => VIC can see it
    memcpy(P_GFX_BITMAP, bitmap, 8000);

    // copy colors to $8400
    memcpy(P_GFX_COLOR, colmap, 1000);

    VIC.bordercolor = COLOR_BLACK;
    //VIC.bgcolor0 = background;

    /* set VIC base address to $4000 */
    CIA2.pra = 0x14 + 2;

    /* DDR => Output */
    CIA2.ddra = 0x3f;

    /* video offset $2000, bitmap offset = $0000 */
    VIC.addr = 0x80;

    /* Bitmap mode */
    VIC.ctrl1 = 0xbb;

    prepare_background();

    detect_images(kernal_menu);
    showMenu();
    waitForKey();

    return 0;
}
