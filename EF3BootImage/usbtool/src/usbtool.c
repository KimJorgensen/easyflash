
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
        else if (strcmp(p_str_cmd, "d64") == 0)
        {
            write_disk_d64();
        }
        else
        {
            ef3usb_send_str("etyp");
        }
    }

    return 0;
}
