
#define EASYFLASH_DEBUG
//#define EASYFLASH_EXTENDED_DEBUG
//#define EASYFLASH_PRINTER_LEN 128
//#define EASYFLASH_RAM
//#define EASYFLASH_LED_USE
//#define EASYFLASH_LED_POSITION 0
//#define EASYFLASH_LED_OFF_COLOR 5
//#define EASYFLASH_LED_ON_COLOR 2

#include "vice.h"

#include <stdio.h>
#include <string.h>

#include "c64cart.h"
#include "c64cartmem.h"
#include "easyflash.h"
#include "vicii-phi1.h"

#include "c64mem.h"
#include "c64io.h"

#include "log.h"


// the jumper
BYTE easyflash_jumper;

// backup of the regsiters
BYTE easyflash_register_00, easyflash_register_02;

// decoding table of the modes
static const BYTE easyflash_memconfig[] = {
    // bit3 = jumper, bit2 = mode, bit1 = exrom, bit0 = game
    // jumper off, mode 0, trough 00,01,10,11 in game/exrom bits
    4+3, // exrom high, game = jumper = low
    8+3, // Reserved, don't use this
    4+1, // exrom high, game = jumper = high
    8+1, // Reserved, don't use this
    // jumper off, mode 1, trough 00,01,10,11 in game/exrom bits
    0+2, 0+3, 0+0, 0+1,
    // jumper on, mode 0, trough 00,01,10,11 in game/exrom bits
    4+2, // exrom high, game = jumper = low
    8+3, // Reserved, don't use this
    4+0, // exrom low, game = jumper = low
    8+1, // Reserved, don't use this
    // jumper on, mode 1, trough 00,01,10,11 in game/exrom bits
    0+2, 0+3, 0+0, 0+1,
};

/*
    info:
        game=0, exrom=0 -> 16k
        game=1, exrom=0 -> 8k
        game=0, exrom=1 -> ultimax
        game=1, exrom=1 -> off
*/

#ifdef EASYFLASH_RAM
    // geheimwaffe
    BYTE easyflash_ram[256];
#endif

/*
** debugging stuff
*/

#ifdef EASYFLASH_DEBUG
    // already in vice (compat) mode
    static const char *easyflash_memconfig_txt[] = {
        // the programmed config
        "8k", "16k", "off", "ult",
        // configured by jumper
        "8k(J)", "16k(J)", "off(J)", "ult(J)",
        // reserved lines
        NULL, "Reserved:16k", NULL, "Reserved:ult",
    };
    BYTE easyflash_debug = 1;
    
    #ifdef EASYFLASH_EXTENDED_DEBUG
        BYTE easyflash_mark;
        char easyflash_printer[EASYFLASH_PRINTER_LEN];
        int easyflash_printer_len;
    #endif
#endif


BYTE REGPARM1 easyflash_io1_read(WORD addr){
    #if defined(EASYFLASH_DEBUG) && defined(EASYFLASH_EXTENDED_DEBUG)
        io_source = IO_SOURCE_FINAL3; // don't know why, but this way it works
        switch(addr){
        case 0xdefc:
            return 'E';
        case 0xdefd:
            return 'F';
        case 0xdefe:
            return 'd';
        case 0xdeff:
            return easyflash_mark;
        }
        io_source = IO_SOURCE_NONE;
    #endif
    return vicii_read_phi1();
}

void REGPARM2 easyflash_io1_store(WORD addr, BYTE value){

#if defined(EASYFLASH_DEBUG) && defined(EASYFLASH_EXTENDED_DEBUG)
    if(addr >= 0xdefc && addr <= 0xdeff){
        switch(addr){
        case 0xdefc:
            easyflash_debug = 1;
            log_message(LOG_DEFAULT, "EasyFlash: enabled debugging");
            break;
        case 0xdefd:
            easyflash_debug = 0;
            log_message(LOG_DEFAULT, "EasyFlash: disabled debugging");
            break;
        case 0xdefe:
            if(easyflash_printer_len < EASYFLASH_PRINTER_LEN){
                easyflash_printer[easyflash_printer_len++] = value;
            }
            break;
        case 0xdeff:
            if(value < 128){
                if(value == 0){
                    log_message(LOG_DEFAULT, "EasyFlash: Mark");
                }else if(value >= 0x20 && value <= 0x7e){
                    log_message(LOG_DEFAULT, "EasyFlash: Mark '%c'", value);
                }else{
                    log_message(LOG_DEFAULT, "EasyFlash: Mark %d", value);
                }
                easyflash_mark = value;
            }else{
                switch(value){
                case 0x80:
                    easyflash_printer_len = 0;
                    break;
                case 0x81:
                    if(!easyflash_debug){
                        break;
                    }
                case 0xc1:
                    {
                        char buf[4*EASYFLASH_PRINTER_LEN+1 + 30];
                        int j=0, i;
                        unsigned long val = 0;
                        for(i=easyflash_printer_len-1; i>=0; i--){
                            sprintf(buf+j, "$%02x ", 0xff & easyflash_printer[i]);
                            j+=4;
                            val = (val << 8) | (0xff & easyflash_printer[i]);
                        }
                        sprintf(buf+j-1, " = %u", val);
                        
                        log_message(LOG_DEFAULT, "EasyFlash: %s", buf);
                        easyflash_printer_len = 0;
                    }
                    break;
                case 0x82:
                    if(!easyflash_debug){
                        break;
                    }
                case 0xc2:
                    {
                        char buf[4*EASYFLASH_PRINTER_LEN+1];
                        int j=0, i;
                        for(i=0; i<easyflash_printer_len; i++){
                            if(easyflash_printer[i] >= 0x20 && easyflash_printer[i] != 0x60 && easyflash_printer[i] <= 0x7a){
                                buf[j++] = easyflash_printer[i];
                            }else{
                                sprintf(buf+j, "{%02x}", 0xff & easyflash_printer[i]);
                                j+=4;
                            }
                        }
                        buf[j] = 0;
                        
                        log_message(LOG_DEFAULT, "EasyFlash: \"%s\"", buf);
                        easyflash_printer_len = 0;
                    }
                    break;
                }
            }
            break;
        }
    }else{
#endif
        if((addr & 2) == 0){
            // $de00 (+ $de01)
            easyflash_register_00 = value & 0x3f; // we only remember 6 bit
            #ifdef EASYFLASH_DEBUG
                if(easyflash_debug){
                    log_message(LOG_DEFAULT, "EasyFlash: mode: %s, bank: %d (addr $%04x, value $%02x)", easyflash_memconfig_txt[easyflash_memconfig[(easyflash_jumper << 3) | (easyflash_register_02 & 0x07)]], easyflash_register_00, addr, value);
                }
            #endif
        }else{
            // $de02 (+ $de03)
            #ifdef EASYFLASH_DEBUG
                BYTE last02 = easyflash_register_02;
            #endif
            easyflash_register_02 = value & 0x87; // we only remember led, mode, exrom, game
            BYTE mem_mode = easyflash_memconfig[(easyflash_jumper << 3) | (easyflash_register_02 & 0x07)];
            cartridge_config_changed(mem_mode, mem_mode, CMODE_READ);
            #ifdef EASYFLASH_DEBUG
                if(easyflash_debug && ((last02 & 0x0f) != (easyflash_register_02 & 0x0f))){
                    // ignore changes in LED only!
                    log_message(LOG_DEFAULT, "EasyFlash: mode: %s, bank: %d (addr $%04x, value $%02x)", easyflash_memconfig_txt[easyflash_memconfig[(easyflash_jumper << 3) | (easyflash_register_02 & 0x07)]], easyflash_register_00, addr, value);
                }
            #endif
            #ifdef EASYFLASH_LED_USE
                colorram_store(0xd800 + EASYFLASH_LED_POSITION, (value & 0x80) ? EASYFLASH_LED_ON_COLOR : EASYFLASH_LED_OFF_COLOR);
            #endif
        }
        cartridge_romhbank_set(easyflash_register_00);
        cartridge_romlbank_set(easyflash_register_00);
        mem_pla_config_changed();
#if defined(EASYFLASH_DEBUG) && defined(EASYFLASH_EXTENDED_DEBUG)
    }
#endif
}

BYTE REGPARM1 easyflash_io2_read(WORD addr){
    #ifdef EASYFLASH_RAM
        io_source = IO_SOURCE_FINAL3;
        return easyflash_ram[addr & 0xff];
    #else
        return vicii_read_phi1();
    #endif
}

void REGPARM2 easyflash_io2_store(WORD addr, BYTE value){
    #ifdef EASYFLASH_RAM
        easyflash_ram[addr & 0xff] = value;
    #endif
}

void easyflash_config_init(void){
    #ifdef EASYFLASH_DEBUG
        BYTE debug = easyflash_debug;
        easyflash_debug = 0;
    #endif
    cartridge_store_io1((WORD)0xde00, 0);
    cartridge_store_io1((WORD)0xde02, 0);
    #ifdef EASYFLASH_DEBUG
        log_message(LOG_DEFAULT, "EasyFlash: mode: %s, bank: %d (reset)", easyflash_memconfig_txt[easyflash_memconfig[(easyflash_jumper << 3) | (easyflash_register_02 & 0x07)]], easyflash_register_00);
        easyflash_debug = debug;
        #ifdef EASYFLASH_EXTENDED_DEBUG
            easyflash_printer_len = 0;
            easyflash_mark = 0;
        #endif
    #endif
}

void easyflash_config_setup(BYTE *rawcart){
    memcpy(roml_banks, rawcart, 0x2000 * 64);
    memcpy(romh_banks, &rawcart[0x2000 * 64], 0x2000 * 64);
}

int easyflash_crt_attach(FILE *fd, BYTE *rawcart, BYTE *header){
    BYTE chipheader[0x10];
    
    if(header[0x18] && (!header[0x19])){
        // .crt is a ultimax (EXROM=1 and GAME=0)
        easyflash_jumper = 0;
    }else{
        // .crt is no ultimax, say the jumper is in "off" mode
        easyflash_jumper = 1;
    }
        
    while (1) {
        if (fread(chipheader, 0x10, 1, fd) < 1) {
            break;
        }
        if (chipheader[0xb] >= 64 || (chipheader[0xc] != 0x80 && chipheader[0xc] != 0xa0)) {
            return -1;
        }
        if (fread(&rawcart[(chipheader[0xb] << 13) | (chipheader[0xc] == 0x80 ? 0 : 1<<19)], 0x2000, 1, fd) < 1) {
            return -1;
        }
    }
    return 0;
}
