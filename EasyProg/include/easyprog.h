/*
 * easyprog.h
 *
 *  Created on: 20.05.2009
 *      Author: skoe
 */

#ifndef EASYPROG_H_
#define EASYPROG_H_

/// These are the menu entry IDs, they are also index into apStrMenuEntries
typedef enum EasyFlashMenuId_e
{
    // 0 is invalid
    EASYPROG_MENU_ENTRY_WRITE_CRT = 1,
    EASYPROG_MENU_ENTRY_VERIFY_CRT,
    EASYPROG_MENU_ENTRY_CHECK_TYPE,
    EASYPROG_MENU_ENTRY_ERASE_ALL,
    EASYPROG_MENU_ENTRY_HEX_VIEWER,
    EASYPROG_MENU_ENTRY_QUIT,
    EASYPROG_MENU_ENTRY_ABOUT
}
EasyFlashMenuId;

void __fastcall__ setStatus(const char* pStrStatus);
void __fastcall__ addBytesFlashed(uint16_t nAdd);

#endif /* EASYPROG_H_ */
