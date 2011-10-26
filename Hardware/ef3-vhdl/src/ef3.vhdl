----------------------------------------------------------------------------------
--
-- (c) 2011 Thomas 'skoe' Giesel
--
-- This software is provided 'as-is', without any express or implied
-- warranty.  In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not be
--    misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source distribution.
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cartridge_modes.all;

entity ef3 is
    port ( addr:        inout std_logic_vector (15 downto 0);
           data:        inout std_logic_vector (7 downto 0);
           n_dma:       inout std_logic;
           ba:          in std_logic;
           n_roml:      in std_logic;
           n_romh:      in std_logic;
           n_io1:       in std_logic;
           n_io2:       in std_logic;
           n_wr:        in std_logic;
           n_irq:       in std_logic;
           n_nmi:       inout std_logic;
           n_reset_io:  inout std_logic;
           clk:         in std_logic;
           phi2:        in std_logic;
           n_exrom:     inout std_logic;
           n_game:      inout std_logic;
           button_a:    in  std_logic;
           button_b:    in  std_logic;
           button_c:    in  std_logic;
           n_led:       out std_logic;
           mem_addr:    out std_logic_vector (22 downto 0);
           mem_data:    inout std_logic_vector (7 downto 0);
           n_mem_wr:    out std_logic;
           n_mem_oe:    out std_logic;
           n_flash_cs:  out std_logic;
           n_ram_cs:    out std_logic;
           usb_txe:     in std_logic;
           usb_rxf:     in std_logic;
           usb_wr:      out std_logic;
           usb_rd:      out std_logic
         );
end ef3;

architecture ef3_arc of ef3 is

    -- Current cartridge mode
    signal cart_mode:           cartridge_mode_type := MODE_MENU;
    signal enable_menu:         std_logic;
    signal enable_ef:           std_logic;
    signal enable_kernal:       std_logic;

    signal buttons_enabled:     std_logic := '0';

    -- This is Button A filtered with buttons_enabled
    -- Enter menu mode
    signal button_menu:         std_logic;

    -- This is Button B filtered with buttons_enabled
    -- Reset current cartridge
    signal button_crt_reset:    std_logic;

    -- This is Button C filtered with buttons_enabled
    -- Special function of a cartridge (e.g. boot disabled or freezer)
    signal button_special_fn:   std_logic;

    signal n_mem_oe_i:  std_logic;

    signal addr_ready:  std_logic;
    signal bus_ready:   std_logic;
    signal dma_ready:   std_logic;
    signal hiram_detect_ready: std_logic;
    signal cycle_end:   std_logic;
    
    signal data_out:    std_logic_vector(7 downto 0);
    signal data_out_valid: std_logic; 

    signal n_exrom_out: std_logic;
    signal n_game_out:  std_logic;
    --signal n_dma_out:   std_logic;

    signal phi2_cycle_start: std_logic;

    -- When this it '1' at the rising edge of clk the reset generator
    -- is started
    signal start_reset_generator: std_logic;

    -- Reset the machine to enter the menu mode
    signal start_reset_to_menu:    std_logic;

    -- This is '1' when software starts the reset generator
    signal sw_start_reset:      std_logic;

    signal n_reset:             std_logic;
    signal n_sys_reset:         std_logic;
    signal n_generated_reset:   std_logic;

    signal hiram:       std_logic;

    -- Number of the current slot, where one slot is 1 MByte
    signal slot:        std_logic_vector(2 downto 0);
    signal latch_slot:  std_logic;
    signal new_slot:    std_logic_vector(2 downto 0);
    signal ma19:        std_logic;
    signal new_ma19:    std_logic;
    signal latch_ma19:  std_logic;
    signal bank:        std_logic_vector(5 downto 0);
    signal latch_bank:  std_logic;
    signal new_bank:    std_logic_vector(5 downto 0);

    signal ram_read:    std_logic;
    signal ram_write:   std_logic;
    signal flash_read:  std_logic;
    signal flash_write: std_logic;
    signal latch_mem_addr: std_logic;
    signal new_mem_addr: std_logic_vector (12 downto 0);

    signal ef_mem_addr:     std_logic_vector(12 downto 0);
    signal ef_latch_mem_addr: std_logic;
    signal ef_ma19:         std_logic;
    signal ef_latch_ma19:   std_logic;
    signal ef_n_game:       std_logic;
    signal ef_n_exrom:      std_logic;
    signal ef_start_reset:  std_logic;
    signal ef_ram_read:     std_logic;
    signal ef_ram_write:    std_logic;
    signal ef_flash_read:   std_logic;
    signal ef_flash_write:  std_logic;
    signal ef_data_out:     std_logic_vector(7 downto 0);
    signal ef_data_out_valid: std_logic;

    signal kernal_mem_addr:     std_logic_vector(12 downto 0);
    signal kernal_latch_mem_addr: std_logic;
    signal kernal_ma19:         std_logic;
    signal kernal_latch_ma19:   std_logic;
    signal kernal_n_dma:        std_logic;
    signal kernal_a14:          std_logic;
    signal kernal_n_game:       std_logic;
    signal kernal_n_exrom:      std_logic;
    signal kernal_flash_read:   std_logic;

    component exp_bus_ctrl is
        port (
            clk:        in  std_logic;
            phi2:       in  std_logic;
            n_wr:       in  std_logic;
            ba:         in  std_logic;
            phi2_cycle_start: out std_logic;
            addr_ready: out std_logic;
            bus_ready:  out std_logic;
            dma_ready:  out std_logic;
            hiram_detect_ready: out std_logic;
            cycle_end:  out std_logic
        );
    end component;

    component reset_generator is
        port
        (
            clk:                    in std_logic;
            phi2_cycle_start:       in std_logic;
            start_reset_generator:  in std_logic;
            n_reset_in:             in  std_logic;
            n_reset:                out std_logic;
            n_generated_reset:      out std_logic;
            n_sys_reset:            out std_logic
        );
    end component;

    component cart_easyflash is
        port (
            clk:            in  std_logic;
            n_sys_reset:    in  std_logic;
            set_boot_flag:  in  std_logic;
            n_reset:        in  std_logic;
            enable:         in  std_logic;
            phi2:           in  std_logic;
            n_io1:          in  std_logic;
            n_io2:          in  std_logic;
            n_roml:         in  std_logic;
            n_romh:         in  std_logic;
            n_wr:           in  std_logic;
            bus_ready:      in  std_logic;
            cycle_end:      in  std_logic;
            addr:           in  std_logic_vector(15 downto 0);
            data:           in  std_logic_vector(7 downto 0);
            button_crt_reset:  in std_logic;
            button_special_fn: in std_logic;
            slot:           in std_logic_vector(2 downto 0);
            new_slot:       out std_logic_vector(2 downto 0);
            latch_slot:     out std_logic;
            mem_addr:       out std_logic_vector(12 downto 0);
            latch_mem_addr: out std_logic;
            bank:           out std_logic_vector(5 downto 0);
            latch_bank:     out std_logic;
            ma19:           out std_logic;
            latch_ma19:     out std_logic;
            n_game:         out std_logic;
            n_exrom:        out std_logic;
            start_reset:    out std_logic;
            ram_read:       out std_logic;
            ram_write:      out std_logic;
            flash_read:     out std_logic;
            flash_write:    out std_logic;
            data_out:       out std_logic_vector(7 downto 0);
            data_out_valid: out std_logic
        );
    end component;

    component cart_kernal is
        port (
            clk:            in  std_logic;
            n_reset:        in  std_logic;
            enable:         in  std_logic;
            phi2:           in  std_logic;
            ba:             in  std_logic;
            n_romh:         in  std_logic;
            n_wr:           in  std_logic;
            addr_ready:     in  std_logic;
            dma_ready:      in  std_logic;
            hiram_detect_ready: in std_logic;
            cycle_end:      in  std_logic;
            addr:           in  std_logic_vector(15 downto 0);
            mem_addr:       out std_logic_vector(12 downto 0);
            latch_mem_addr: out std_logic;
            ma19:           out std_logic;
            latch_ma19:     out std_logic;
            n_dma:          out std_logic;
            a14:            out std_logic;
            n_game:         out std_logic;
            n_exrom:        out std_logic;
            flash_read:     out std_logic;
            hiram:          out std_logic
        );
    end component;

begin
    ---------------------------------------------------------------------------
    -- Component: Expansion Port Bus Control
    ---------------------------------------------------------------------------
    u_exp_bus_ctrl: exp_bus_ctrl port map
    (
        clk, phi2, n_wr, ba,
        phi2_cycle_start,
        addr_ready, bus_ready, dma_ready, hiram_detect_ready, cycle_end
    );

    u_reset_generator: reset_generator port map
    (
        clk, phi2_cycle_start,
        start_reset_generator,
        n_reset_io,
        n_reset, n_generated_reset, n_sys_reset
    );

    u_cart_easyflash: cart_easyflash port map
    (
        clk, n_sys_reset, start_reset_to_menu, n_reset, 
        enable_ef,
        phi2, n_io1, n_io2, n_roml, n_romh, n_wr, 
        bus_ready, cycle_end,
        addr, data, 
        button_crt_reset, button_special_fn,
        slot, new_slot, latch_slot,
        ef_mem_addr, ef_latch_mem_addr, 
        new_bank, latch_bank,
        ef_ma19, ef_latch_ma19,
        ef_n_game, ef_n_exrom,
        ef_start_reset,
        ef_ram_read, ef_ram_write,
        ef_flash_read, ef_flash_write,
        ef_data_out, ef_data_out_valid
    );

    u_cart_kernal: cart_kernal port map
    (
        clk, n_reset, enable_kernal,
        phi2, ba, n_romh, n_wr,
        addr_ready, dma_ready, hiram_detect_ready, cycle_end,
        addr,
        kernal_mem_addr, kernal_latch_mem_addr,
        kernal_ma19, kernal_latch_ma19,
        kernal_n_dma, kernal_a14,
        kernal_n_game, kernal_n_exrom,
        kernal_flash_read,
        hiram
    );

    button_menu       <= buttons_enabled and button_a;
    button_crt_reset  <= buttons_enabled and button_b;
    button_special_fn <= buttons_enabled and button_c;

    enable_menu     <= '1'
        when cart_mode = MODE_MENU
        else '0';

    enable_ef       <= '1'
        when cart_mode = MODE_EASYFLASH or cart_mode = MODE_MENU
        else '0';

    enable_kernal   <= '1'
        when cart_mode = MODE_KERNAL
        else '0';

    -- unused signals and defaults
    addr <= (others => 'Z');
    usb_rd <= '1';
    usb_wr <= '1';
    n_nmi <= 'Z';

    n_led <= '0' when (n_io1 and n_io2 and n_roml and n_romh) = '0' and n_wr = '1' and phi2 = '1' else '1';
    n_reset_io <= 'Z' when n_generated_reset = '1' else '0';


    ---------------------------------------------------------------------------
    -- The buttons will be enabled after all buttons have been released one
    -- time. This is done to prevent detection of button presses while the
    -- circuit is powered up.
    ---------------------------------------------------------------------------
    enable_buttons: process(clk)
    begin
        -- todo: Reset?
        if rising_edge(clk) then
            if button_a = '0' and button_b = '0' and
               button_c = '0' then
                buttons_enabled <= '1';
            end if;
        end if;
    end process enable_buttons;


    ---------------------------------------------------------------------------
    -- This button will always enter the menu mode.
    ---------------------------------------------------------------------------
    check_button_menu_mode: process(clk)
    begin
        if rising_edge(clk) then
            start_reset_to_menu <= button_menu;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Register $de03 selects the cartridge mode when enable_menu is set.
    ---------------------------------------------------------------------------
    check_cartridge_mode: process(clk, n_sys_reset)
    begin
        if n_sys_reset = '0' then
            cart_mode <= MODE_MENU;
            sw_start_reset <= '0';
        elsif rising_edge(clk) then
            sw_start_reset <= '0';
            if start_reset_to_menu = '1' then
                cart_mode <= MODE_MENU;
            elsif n_wr = '0' and bus_ready = '1' and
                n_io1 = '0' and enable_menu = '1' then
                case addr(7 downto 0) is
                    when x"03" =>
                        -- $de03 = cartridge mode
                        case data(2 downto 0) is
                            when "000" =>
                                cart_mode <= MODE_EASYFLASH;
                                sw_start_reset <= '1';

                            when "001" =>
                                cart_mode <= MODE_FC3;
                                sw_start_reset <= '1';

                            when "011" =>
                                cart_mode <= MODE_KERNAL;
                                sw_start_reset <= '1';

                            when others => null;
                        end case;
                    when others => null;
                end case;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Merge the output of all cartridges
    ---------------------------------------------------------------------------
    ram_read        <= ef_ram_read;
    ram_write       <= ef_ram_write;
    flash_read      <= ef_flash_read or kernal_flash_read;
    flash_write     <= ef_flash_write;
    n_exrom_out     <= ef_n_exrom and kernal_n_exrom;
    n_game_out      <= ef_n_game and kernal_n_game;
    new_mem_addr    <= ef_mem_addr or kernal_mem_addr;
    latch_mem_addr  <= ef_latch_mem_addr or kernal_latch_mem_addr;
    new_ma19        <= ef_ma19 or kernal_ma19;
    latch_ma19      <= ef_latch_ma19 or kernal_latch_ma19;
    data_out        <= ef_data_out;
    data_out_valid  <= ef_data_out_valid;

    start_reset_generator <=
        ef_start_reset or start_reset_to_menu or sw_start_reset;

    n_dma <= 'Z';

    n_exrom <= n_exrom_out; -- when ((n_exrom and n_exrom_out) = '0') else 'Z';

    n_game <= n_game_out; -- when ((n_game and n_game_out) = '0') else 'Z';

    addr(14) <= kernal_a14;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    set_mem_addr: process(clk, n_sys_reset, start_reset_to_menu)
    begin
        if n_sys_reset = '0' or start_reset_to_menu = '1' then
            slot <= (others => '0');
            bank <= (others => '0');
            mem_addr(12 downto 0) <= (others => '0');
            mem_addr(19) <= '0';
        elsif rising_edge(clk) then
            if latch_slot = '1' then
                slot <= new_slot;
            end if;
            if latch_bank = '1' then
                bank <= new_bank;
            end if;
            if latch_mem_addr = '1' then
                mem_addr(12 downto 0) <= new_mem_addr;
            end if;
            if latch_ma19 = '1' then
                mem_addr(19) <= new_ma19;
            end if;
            if flash_read = '1' or flash_write = '1' then
                mem_addr(14 downto 13) <= bank(1 downto 0);
            elsif ram_read = '1' or ram_write = '1' then
                mem_addr(14 downto 13) <= "00"; -- for now
            end if;             
        end if;
    end process;
    mem_addr(22 downto 20) <= slot;
    -- mem_addr(19) is taken from ROML/ROMH
    mem_addr(18 downto 15) <= bank(5 downto 2);
    -- mem_addr(14 downto 13) are different for flash and ram
    -- mem_addr(12 downto 0) come from the cartridge implementations

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    mem_ctrl: process(clk, n_reset)
        variable write_scheduled : boolean; -- todo: 2 Zyklen!
    begin
        if n_reset = '0' then
            n_ram_cs    <= '1';
            n_flash_cs  <= '1';
            n_mem_oe_i  <= '1';
            n_mem_wr    <= '1';
            write_scheduled := false;
        elsif rising_edge(clk) then
            -- n_mem_wr_i is only set for one write cycle
            -- after write_scheduled has been set
            n_mem_wr <= '1';
            if write_scheduled then
                n_mem_wr    <= '0'; -- will be active for one cycle only
                write_scheduled := false;
            elsif ram_read = '1' then
                -- start ram read, leave until cycle_end
                n_ram_cs    <= '0';
                n_flash_cs  <= '1';
                n_mem_oe_i  <= '0';
            elsif ram_write = '1' then
                n_ram_cs    <= '0';
                n_flash_cs  <= '1';
                n_mem_oe_i  <= '1';
                write_scheduled := true; -- tbd in next cycle
            elsif flash_read = '1' then
                -- start flash read, leave until cycle_end
                n_ram_cs    <= '1';
                n_flash_cs  <= '0';
                n_mem_oe_i  <= '0';
            elsif flash_write = '1' then
                n_ram_cs    <= '1';
                n_flash_cs  <= '0';
                n_mem_oe_i  <= '1';
                write_scheduled := true; -- tbd in next cycle
            elsif cycle_end = '1' then
                -- idle
                n_ram_cs    <= '1';
                n_flash_cs  <= '1';
                n_mem_oe_i  <= '1';
                write_scheduled := false;
            end if;

        end if;
    end process mem_ctrl;
    n_mem_oe <= n_mem_oe_i;

    ---------------------------------------------------------------------------
    -- Combinatorically decide:
    -- - If we put the memory bus onto the C64 data bus
    -- - If we put data out onto the C64 data bus
    -- - If we put the C64 data bus onto the memory bus
    --
    -- The C64 data bus is only driven if it is a read access with any
    -- of the four Expansion Port control lines asserted.
    --
    -- The memory bus is always driven by the CPLD when no memory chip has
    -- OE active.
    --
    -- We need a special case with phi2 = '0' for C128 which doesn't set R/W
    -- correctly for Phi1 cycles.
    -- 
    ---------------------------------------------------------------------------
    data_out_enable: process(n_io1, n_io2, n_roml, n_romh, phi2, n_wr,
                             mem_data, data_out,
                             n_mem_oe_i, data)
    begin
        mem_data <= (others => 'Z');
        data <= (others => 'Z');
        if (n_io1 and n_io2 and n_roml and n_romh) = '0' and 
           ((n_wr = '1' and phi2 = '1') or phi2 = '0') then
            if data_out_valid = '1' then
                data <= data_out;
            else
                data <= mem_data;
            end if;
        elsif n_mem_oe_i = '1' then
            mem_data <= data;
        end if;
    end process data_out_enable;

end ef3_arc;
