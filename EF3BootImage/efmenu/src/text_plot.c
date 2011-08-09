/*
 * EasyProg - text_plot.c - Text Plotter
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
#include <string.h>
#include <c64.h>
#include "memcfg.h"
#include "text_plot.h"

uint16_t text_plot_x;
uint8_t  text_plot_y;


/******************************************************************************/
/**
 * Plot the given 0-terminated string into the bitmap at x_pos/y_pos.
 *
 * No clipping is performed.
 * x_pos/y_pos are the upper left-hand corner of the first character.
 */
void __fastcall__ text_plot_puts(
        uint16_t x_pos, uint8_t y_pos, const char* str)
{
    text_plot_x = x_pos;
    text_plot_y = y_pos;

    while (*str != 0)
    {
        text_plot_char(*str);
        
        // space between chars
        ++text_plot_x;
        ++str;
    }
}
