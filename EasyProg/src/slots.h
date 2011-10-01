
#ifndef SLOTS_H
#define SLOTS_H

#include <stdint.h>

#define EF_DIR_NUM_SLOTS    16
#define EF_DIR_NUM_KERNALS  8
#define EF_DIR_SLOT         0
#define EF_DIR_BANK         0x10

void slotsFillEFDir(void);
uint8_t __fastcall__ selectSlotDialog(uint8_t nSlots);
uint8_t selectKERNALSlotDialog(void);
uint8_t __fastcall__ checkAskForSlot(void);
void __fastcall__ slotSelect(uint8_t slot);
void __fastcall__ slotSaveName(const char* name, char isKERNAL);

extern uint8_t g_nSelectedSlot;
extern uint8_t g_nSlots;

void __fastcall__ setBankChangeMode(uint8_t bank, uint8_t mode);
void __fastcall__ startProgram(uint8_t bank);

void waitForNoKey(void);

typedef struct efmenu_dir_s
{
    char        signature[16];
    char        slots[EF_DIR_NUM_SLOTS][16];
    char        kernals[EF_DIR_NUM_KERNALS][16];
    uint16_t    checksum;
} efmenu_dir_t;

#endif
