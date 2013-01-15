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
#include <stdlib.h>
#include <c64.h>

#include <ef3usb.h>

#include "text_plot.h"
#include "memcfg.h"
#include "efmenu.h"

static void erase_text_areas(void);
static void fill_directory(void);

// from gfx.s
extern const uint8_t* bitmap;
extern const uint8_t* colmap;
extern const uint8_t* attrib;
extern uint8_t background;


static const char* m_pEFSignature = "EF-Directory V1:";

typedef enum screen_state_e
{
    SCREEN_STATE_MENU,
    SCREEN_STATE_SHIFT_MENU,
    SCREEN_STATE_VERSION
} screen_state_t;

static screen_state_t screen_state;

static efmenu_entry_t kernal_menu[] =
{
        { '1',  0,  0,  0,  MODE_KERNAL,    "1", "Empty", "" },
        { '2',  0,  1,  0,  MODE_KERNAL,    "2", "Empty", "" },
        { '3',  0,  2,  0,  MODE_KERNAL,    "3", "Empty", "" },
        { '4',  0,  3,  0,  MODE_KERNAL,    "4", "Empty", "" },
        { '5',  0,  4,  0,  MODE_KERNAL,    "5", "Empty", "" },
        { '6',  0,  5,  0,  MODE_KERNAL,    "6", "Empty", "" },
        { '7',  0,  6,  0,  MODE_KERNAL,    "7", "Empty", "" },
        { '8',  0,  7,  0,  MODE_KERNAL,    "8", "Empty", "" },
        { 0, 0, 0, 0, 0, "", "", "" }
};

static efmenu_entry_t ef_menu[] =
{
        { 'a',  1,  0,  1,  MODE_EF,    "A", "EF Slot 1", "" },
        { 'b',  2,  0,  1,  MODE_EF,    "B", "EF Slot 2", "" },
        { 'c',  3,  0,  1,  MODE_EF,    "C", "EF Slot 3", "" },
        { 'd',  4,  0,  1,  MODE_EF,    "D", "EF Slot 4", "" },
        { 'e',  5,  0,  1,  MODE_EF,    "E", "EF Slot 5", "" },
        { 'f',  6,  0,  1,  MODE_EF,    "F", "EF Slot 6", "" },
        { 'g',  7,  0,  1,  MODE_EF,    "G", "EF Slot 7", "" },
        { 0, 0, 0, 0, 0, "", "", "" }
};

static efmenu_entry_t special_menu[] =
{
        { 'r',  0,  0x10,   1,  MODE_AR,           "R", "Replay Slot 1",    "" },
        { 'y',  0,  0x18,   1,  MODE_AR,           "Y", "Replay Slot 2",    "" },
        { 's',  0,  0x20,   1,  MODE_SS5,          "S", "Super Snapshot 5", "" },
        { 'p',  0,  9,      1,  MODE_EF_NO_RESET,  "P", "EasyProg",         "crt" },
        { '?',  0,  0,      0,  MODE_EF,           "",  "",                 "" },
        { '?',  0,  0,      0,  MODE_EF,           "",  "<SHIFT> for more",   "" },
        { 0, 0, 0, 0, 0, "", "", "" }
};

static efmenu_entry_t dummy_menu[] =
{
        // { '9',  0,  0x18,   1,  MODE_KERNAL,       "9", "EF3 KERNAL",       "key" },
        // { '9',  0,  0x18,   1,  MODE_KERNAL,       "9", "EF3 KERNAL",       "prg" },
        { '?',  0,  0x0b,   1,  MODE_EF,           "?", "USB Tool",         "d64" },
        { '?',  0,  0x0b,   1,  MODE_EF,           "?", "USB Tool",         "prg" },
        { 0, 0, 0, 0, 0, "", "", "" }
};

static efmenu_entry_t special_shift_menu[] =
{
        { 128 + 'v', 0, 0,  0,  MODE_SHOW_VERSION, "V", "Show Versions",    "" },
        { 128 + 'k', 0, 0,  1,  MODE_KILL,         "K", "Kill Cartridge",   "" },
        { 128 + 'z', 0, 0,  1,  MODE_GO128,        "Z", "To C128 Mode",     "" },
        { 0, 0, 0, 0, 0, "", "", "" }
};

static efmenu_t all_menus[] =
{
        {  2,  2, 10, kernal_menu },
        { 22, 13,  9, ef_menu },
        {  2, 15,  8, special_menu },
        {  0,  0,  0, dummy_menu },
        {  0,  0,  0, NULL }
};

static efmenu_t all_shift_menus[] =
{
        {  2, 15,  8, special_shift_menu },
        {  0,  0,  0, NULL }
};


/******************************************************************************/
static void show_version(void);



/******************************************************************************/
/**
 * Return 1 if the entry is valid. This is the case if it contains a mode
 * which always works or if at least one of the last 4 bytes in the ROM
 * location is not empty and does not contain the torture test pattern.
 *
 * Empty pattern:         ff ff ff ff
 * Torture test pattern:  03 02 01 00
 */
uint8_t menu_entry_is_valid(const efmenu_entry_t* entry)
{
    uint8_t* p;
    uint8_t  i;

    if (entry->mode == MODE_EF_NO_RESET ||
        entry->mode == MODE_KILL ||
        entry->mode == MODE_SHOW_VERSION)
        return 1;

    if (is_c128())
    {
        if (entry->mode == MODE_KERNAL)
            return 0;
    }
    else
    {
        if (entry->mode == MODE_GO128)
            return 0;
    }

    set_slot(entry->slot);
    set_bank(entry->bank);

    if (entry->chip == 0)
        p = (uint8_t*) (0x8000 + 0x2000 - 4);
    else
        p = (uint8_t*) (0xa000 + 0x2000 - 4);

    for (i = 0; i != 4; ++i)
    {
        if ((p[i] != 0xff) &&
            (p[i] != 3 - i))
        {
            return 1;
        }
    }
    return 0;
}


/******************************************************************************/
/**
 */
static void show_menu(uint8_t shift)
{
    uint8_t y, color;
    const efmenu_t* menu;
    const efmenu_entry_t* entry;

    erase_text_areas();
    fill_directory();

    if (shift)
    {
        menu = all_shift_menus;
        screen_state = SCREEN_STATE_SHIFT_MENU;
    }
    else
    {
        menu = all_menus;
        screen_state = SCREEN_STATE_MENU;
    }

    while (menu->pp_entries)
    {
        if (menu->n_max_entries) /* hidden otherwise */
        {
            y = menu->y_pos + 1;

            entry = menu->pp_entries;
            while (entry->key)
            {
                text_plot_puts(menu->x_pos,     4, y, entry->label);
                text_plot_puts(menu->x_pos + 2, 0, y, entry->name);

                if (menu_entry_is_valid(entry))
                    color = COLOR_BLACK << 4 | COLOR_GRAY3;
                else
                    color = COLOR_GRAY2 << 4 | COLOR_GRAY3;
                text_set_line_color(menu->x_pos, y, color);

                ++y;
                ++entry;
            }
        }
        ++menu;
    }
}


/******************************************************************************/
/**
 */
static void __fastcall__ start_menu_entry(const efmenu_entry_t* entry)
{
    // Wait until the key is released
    wait_for_no_key();

    set_slot(entry->slot);

    if (entry->mode == MODE_EF_NO_RESET)
    {
        // PONR
        start_program(entry->bank);
    }
    else if (entry->mode == MODE_SHOW_VERSION)
    {
        show_version();
    }
    else
    {
        // PONR
        set_bank_change_mode(entry->bank, entry->mode);
    }
}


/******************************************************************************/
/**
 */
static void __fastcall__ start_menu_entry_ex(uint8_t key, const char* type)
{
    const efmenu_t* menu_list[] = {all_menus, all_shift_menus, NULL};
    const efmenu_t* menu;
    const efmenu_entry_t* entry;
    uint8_t i;

    for (i = 0; menu_list[i]; ++i)
    {
        menu = menu_list[i];

        while (menu->pp_entries)
        {
            entry = menu->pp_entries;
            while (entry->key)
            {
                if (menu_entry_is_valid(entry))
                {
                    if (key  && entry->key == key)
                        start_menu_entry(entry);
                    if (type && strcmp(entry->type, type) == 0)
                    {
                        ef3usb_send_str("wait");
                        start_menu_entry(entry);
                    }
                }
                ++entry;
            }
            ++menu;
        }
    }
}


/******************************************************************************/
/**
 */
static void show_version(void)
{
    uint16_t x;
    uint8_t  y;
    static char str_version[6];
    uint8_t vcode = EF3_CPLD_VERSION;

    erase_text_areas();
    x = all_menus[0].x_pos + 1;
    y = all_menus[0].y_pos + 1;

    text_plot_puts(x, 0, y, "CPLD Core Version:");
    y += 3;
    text_plot_puts(x, 0, y, "Menu Version:");
    y += 4;
    text_plot_puts(x, 0, y, "Press <Run/Stop>");

    if (vcode != EF3_OLD_VERSION)
    {
        str_version[0] = '0' + ((vcode >> 6) & 3);
        str_version[1] = '.';
        str_version[2] = '0' + ((vcode >> 3) & 7);
        str_version[3] = '.';
        str_version[4] = '0' + (vcode & 7);
    }
    else
        strcpy(str_version, "0.x.x");
    y = all_menus[0].y_pos + 2;
    x += 6;
    text_plot_puts(x, 0, y, str_version);
    y += 3;
    text_plot_puts(x, 0, y, EFVERSION);

    screen_state = SCREEN_STATE_VERSION;
}


/******************************************************************************/
/**
 */
static void main_loop(void)
{
    const char* pType;
    uint8_t key;

    do
    {
        if (kbhit())
        {
            key = cgetc();
            if (screen_state == SCREEN_STATE_VERSION && key == CH_STOP)
                show_menu(shift_pressed());
            else
                start_menu_entry_ex(key, NULL);
        }
        if (shift_pressed() && screen_state == SCREEN_STATE_MENU)
            show_menu(1);
        else if (!shift_pressed() && screen_state == SCREEN_STATE_SHIFT_MENU)
            show_menu(0);

        pType = ef3usb_check_cmd();
        if (pType)
        {
            start_menu_entry_ex(0, pType);
        }
    }
    while (1);
}


/******************************************************************************/
/**
 */
static void erase_text_areas(void)
{
    uint8_t  n;
	uint16_t offset;

    const efmenu_t* menu;

    menu = all_menus;
    while (menu->pp_entries)
    {
        offset = menu->y_pos * 320 + menu->x_pos * 8;

        for (n = 0; n != menu->n_max_entries; ++n)
        {
            memset(P_GFX_BITMAP + offset, 0, 16 * 8);
            offset += 320;
            text_set_line_color(menu->x_pos, menu->y_pos + n,
                                COLOR_BLACK << 4 | COLOR_GRAY3);
        }
        ++menu;
    }
}


/******************************************************************************/
/**
 * Read the directory from the cartridge to our menu structures.
 * Return immediately if the signature cannot be found.
 */
static void fill_directory(void)
{
    const efmenu_dir_t* p_dir = (efmenu_dir_t*)0x8000;
    int i;
    efmenu_entry_t* p_entry;
    char*           p_name;

    set_slot(EF_DIR_SLOT);
    set_bank(EF_DIR_BANK);

    if (memcmp(p_dir->signature, m_pEFSignature, sizeof(p_dir->signature)))
        return;

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


/******************************************************************************/
/**
 */
static void init_screen(void)
{
    VIC.bordercolor = COLOR_BLUE;

    /* set VIC base address to $4000 */
    CIA2.pra = 0x14 + 2;
    CIA2.ddra = 0x3f;

    /* video offset $1c00, bitmap offset = $2000 */
    VIC.addr = 0x78;

    /* Bitmap mode */
    VIC.ctrl1 = 0xbb;

    // copy bitmap at $A000 from ROM to RAM => VIC can see it
    // copy colors to $8400
    memcpy(P_GFX_BITMAP, bitmap, 8000);
    memcpy(P_GFX_COLOR, colmap, 1000);
}

void initNMI(void);

/******************************************************************************/
/**
 */
int main(void)
{
    init_screen();
    show_menu(shift_pressed());

#if 0
    set_bank(0x0f);
    memcpy((void*)0x8000, (void*)0x8000, 0x2000);
    // copy KERNAL to RAM
    memcpy((void*)0xe000, (void*)0xe000, 0x2000);
    initNMI();
#endif

    main_loop();

    return 0;
}
