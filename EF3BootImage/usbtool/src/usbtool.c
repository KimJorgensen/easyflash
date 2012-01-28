
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include <ef3usb.h>

#include "usbtool.h"


static void start_prg()
{
    void* p_start_addr;
    puts("Loading");
    usbtool_prg_load_and_run();
}



int main(void)
{
    const char* p_str_cmd;

    puts("USB tool started");

    for (;;)
    {
        puts("Waiting for command from USB...");
        do
        {
            p_str_cmd = ef3usb_check_cmd();
        }
        while (p_str_cmd == NULL);
        printf("Command: %s\n", p_str_cmd);

        if (strcmp(p_str_cmd, "prg") == 0)
        {
            ef3usb_send_str("load");
            start_prg();
        }
    }

    for (;;)
        ++*(unsigned char*)0xd020;
    return 0;
}
