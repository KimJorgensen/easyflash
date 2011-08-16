
#ifndef SLOTS_H
#define SLOTS_H

#include <stdint.h>

uint8_t __fastcall__ selectSlotDialog(uint8_t nSlots);
void __fastcall__ checkAskForSlot(uint8_t bWarn);
void selectSlot0(void);

extern uint8_t g_nSelectedSlot;
extern uint8_t g_nSlots;

#endif
