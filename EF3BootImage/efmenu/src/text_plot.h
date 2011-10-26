 
#ifndef _TEXT_PLOT_H_
#define _TEXT_PLOT_H_

#include <stdint.h>
#include <c64.h>

void __fastcall__ text_plot_char(char ch);
void __fastcall__ text_plot_puts(uint16_t x_pos, uint8_t y_pos, const char* str);


#endif
