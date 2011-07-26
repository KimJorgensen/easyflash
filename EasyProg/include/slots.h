
#ifndef SLOTS_H
#define SLOTS_H


typedef struct SlotEntry_s {
    char          name[17];     /* Label in PETSCII, 0-terminated */
} SlotEntry;

uint8_t __fastcall__ selectSlot(uint8_t nSlots);

#endif
