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
#include "memcfg.h"
#include "efmenu.h"
#include "usb.h"


// from gfx.s
extern const uint8_t* bitmap;
extern const uint8_t* colmap;
extern const uint8_t* attrib;
extern uint8_t background;

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
        { 0, 0, 0, 0, "", "" }
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
        { 0, 0, 0, 0, "", "" }
};

static efmenu_entry_t special_menu[] =
{
        { 'r',    0, 0,  MODE_AR,           "R", "Action Replay" },
        { 's',    0, 0,  MODE_SS5,          "S", "Super Snapshot 5" },
        { 'p',    0, 9,  MODE_EF_NO_RESET,  "P", "EasyProg" },
        { 'k',    0, 0,  MODE_KILL,         "K", "Kill Cartridge" },
        { 0, 0, 0, 0, "", "" }
};

static efmenu_t all_menus[] =
{
        {  2 * 8,  2 * 8, 10, kernal_menu },
        { 22 * 8, 13 * 8, 10, ef_menu },
        {  2 * 8, 14 * 8,  8, special_menu },
        {  0, 0, NULL }
};


static void show_menu(void)
{
    uint8_t y;
    const efmenu_t* menu;
    const efmenu_entry_t* entry;

    menu = all_menus;
    while (menu->pp_entries)
    {
        y = menu->y_pos + 8;

        entry = menu->pp_entries;
        while (entry->key)
        {
            text_plot_puts(menu->x_pos + 8,  y, entry->label);
            text_plot_puts(menu->x_pos + 20, y, entry->name);
            y += 8;
            ++entry;
        }
        ++menu;
    }
}


static void start_menu_entry(const efmenu_entry_t* entry)
{
	VIC.bordercolor = COLOR_WHITE;
    // Wait until the key is released
    wait_for_no_key();

    set_slot(entry->slot);

    if (entry->mode == MODE_EF_NO_RESET)
    {
        // PONR
        start_program(entry->bank);
    }
    else
    {
        // PONR
        set_bank_change_mode(entry->bank, entry->mode);
    }
}


static void wait_for_key(void)
{
    uint8_t key;
    const efmenu_t* menu;
    const efmenu_entry_t* entry;

    do
    {
        if (kbhit())
        {
            key = cgetc();
            VIC.bordercolor = key;

            menu = all_menus;
            while (menu->pp_entries)
            {
                entry = menu->pp_entries;
                while (entry->key)
                {
                    if (entry->key == key)
                        start_menu_entry(entry);

                    ++entry;
                }
                ++menu;
            }
        }
        usbCheck();
    }
    while (1);
}

static void prepare_background(void)
{
    uint8_t  n;
	uint16_t offset;

    const efmenu_t* menu;

    menu = all_menus;
    while (menu->pp_entries)
    {
        offset = menu->y_pos * 40 + menu->x_pos;

        for (n = menu->n_max_entries; n > 0; --n)
        {
            //memset(P_GFX_COLOR + offset / 8, COLOR_WHITE << 4 | COLOR_BLACK, 16);
            memset(P_GFX_COLOR + offset / 8, COLOR_BLACK << 4 | COLOR_GRAY3, 16);
            memset(P_GFX_BITMAP + offset, 0, 16 * 8);
            offset += 320;
        }
        ++menu;
    }
}


static void fill_directory(void)
{
    const efmenu_dir_t* p_dir = (efmenu_dir_t*)0x8000;
    int i;
    efmenu_entry_t* p_entry;
    char*           p_name;

    set_slot(EF_DIR_SLOT);
    set_bank(EF_DIR_BANK);
    // we show slot 1 to 7 only
    p_name  = p_dir->slots[1];
    p_entry = ef_menu;
    for (i = 0; i < 7; ++i)
    {
        memcpy(p_entry->name, p_name, sizeof(p_dir->slots[0]));
        ++p_entry;
        p_name += sizeof(p_dir->slots[0]);
        p_entry->name[sizeof(ef_menu[0].name) - 1] = '\0';
    }

    // and KERNAL 1 to 8
    p_name  = p_dir->kernals[0];
    p_entry = kernal_menu;
    for (i = 0; i < 8; ++i)
    {
        memcpy(p_entry->name, p_name, sizeof(p_dir->kernals[0]));
        ++p_entry;
        p_name += sizeof(p_dir->slots[0]);
        p_entry->name[sizeof(kernal_menu[0].name) - 1] = '\0';
    }
}

void initNMI(void);

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

    fill_directory();
    show_menu();


#if 0
    set_bank(0x0f);
    memcpy((void*)0x8000, (void*)0x8000, 0x2000);
    // copy KERNAL to RAM
    memcpy((void*)0xe000, (void*)0xe000, 0x2000);
    initNMI();
#endif

    wait_for_key();

    return 0;
}
