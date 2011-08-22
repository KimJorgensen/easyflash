
#ifndef SLOTS_H
#define SLOTS_H

#include <stdint.h>

uint8_t __fastcall__ selectSlotDialog(uint8_t nSlots);
uint8_t selectKERNALSlotDialog(void);
void __fastcall__ checkAskForSlot(uint8_t bWarn);
void __fastcall__ slotSelect(uint8_t slot);

extern uint8_t g_nSelectedSlot;
extern uint8_t g_nSlots;

#endif
