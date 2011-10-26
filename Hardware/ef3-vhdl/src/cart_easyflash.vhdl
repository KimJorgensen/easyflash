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


entity cart_easyflash is
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
end cart_easyflash;

-- Memory mapping:
-- Bit                        21098765432109876543210
--                            2221111111111  .
-- Bits needed for RAM/Flash:           .    .
--   RAM (32 ki * 8)                  *************** (14..0)
--   Flash (8 Mi * 8)         *********************** (22..0)
-- Used in EF mode:
--   mem_addr(22 downto 15)   SSSLBBBB                (22..15) latch_addr_high
--   mem_addr(14 downto 13)           MM              (14..13) latch_addr_mid
--   mem_addr(12 downto 0)              AAAAAAAAAAAAA (12..0)  latch_addr_low
--
-- A    = Address from C64 bus to address 8k per bank
-- B/M  = Bank number as set with $de00
-- M    = Shared between RAM and Flash, 00 for RAM, flash_bank(1 downto 0) for Flash
-- L    = ROML/ROMH, 0 for ROML banks
-- S    = new_slot number as set with $de01
--
-- Only flash_bank(1 downto 0) is saved in this entity. This is needed because
-- these bits are used by RAM and ROM.
-- The other banking and new_slot bits are written to and read from mem_addr_out
-- and mem_addr_in directly.

architecture behav of cart_easyflash is

    -- boot enabled?
    signal easyflash_boot:      std_logic := '1';
begin

    reset_boot_or_no_boot: process(n_sys_reset, set_boot_flag, clk)
    begin
        if n_sys_reset = '0' or set_boot_flag = '1' then
            easyflash_boot <= '1';
        elsif rising_edge(clk) then
            if enable = '1' then
                if button_special_fn = '1' then
                    easyflash_boot <= '0';
                    start_reset <= '1';
                elsif button_crt_reset = '1' then
                    easyflash_boot <= '1';
                    start_reset <= '1';
                else
                    start_reset <= '0';
                end if;
            end if;
        end if;
    end process;

    create_mem_addr: process(enable, n_roml, n_romh,
                             addr, bus_ready, data)
    begin
        mem_addr <= (others => '0');
        new_slot <= (others => '0');
        bank <= (others => '0');
        ma19 <= '0';

        latch_mem_addr <= '0';
        latch_ma19 <= '0';

        if enable = '1' then
            if n_roml = '0' or n_romh = '0' then
                mem_addr <= addr(12 downto 0);
            else
                -- RAM
                mem_addr <= "00000" & addr(7 downto 0);
            end if;
            new_slot <= data(2 downto 0);
            bank <= data(5 downto 0);
            ma19 <= n_roml;

            latch_mem_addr <= bus_ready;
            latch_ma19     <= bus_ready;
        end if;
    end process;

    create_data_out: process(enable, slot)
    begin
        data_out <= (others => '0');
        if enable = '1' then
            data_out <= "00000" & slot;
        end if;
    end process;

    rw_control_regs: process(clk, n_reset, enable, easyflash_boot)
    begin
        if n_reset = '0' then
            n_exrom <= '1';
            if enable = '1' then
                n_game  <= not easyflash_boot;
            else
                n_game <= '1';
            end if;
            latch_slot <= '0';
            latch_bank <= '0';
            data_out_valid <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                latch_slot <= '0';
                latch_bank <= '0';
                if bus_ready = '1' and n_io1 = '0' then
                    if n_wr = '0' then
                        -- write control register
                        case addr(7 downto 0) is
                            when x"00" =>
                                -- $de00
                                latch_bank <= '1';

                            when x"01" =>
                                -- $de01
                                latch_slot <= '1';

                            when x"02" =>
                                -- $de02
                                n_exrom <= not data(1);
                                if data(2) = '0' then
                                    n_game <= not easyflash_boot;
                                else
                                    n_game <= not data(0);
                                end if;

                            when others => null;
                        end case;
                    else
                        -- read control register
                        if addr(7 downto 0) = x"01" then
                            -- $de01
                            data_out_valid <= '1';
                        end if;
                    end if;
                end if; -- bus_ready...
                if cycle_end = '1' then
                    data_out_valid <= '0';
                end if;
            else
                n_exrom <= '1';
                n_game <= '1';
                latch_slot <= '0';
                latch_bank <= '0';
                data_out_valid <= '0';
            end if; -- enable
       end if; -- clk
    end process;

    -- We need a special case with phi2 = '0' for C128 which doesn't set R/W
    -- correctly for Phi1 cycles.
    rw_flash: process(enable, n_roml, n_romh, n_wr, bus_ready)
    begin
        flash_write <= '0';
        flash_read <= '0';
        if enable = '1' then
            if bus_ready = '1' and (n_roml = '0' or n_romh = '0') then
                if phi2 = '0' then
                    -- VIC-II
                    flash_read <= '1';
                else
                    -- CPU
                    if n_wr = '1' then
                        flash_read <= '1';
                    else
                        flash_write <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    rw_ram: process(enable, n_io2, n_wr, bus_ready)
    begin
        ram_write <= '0';
        ram_read <= '0';
        if enable = '1' then
            if bus_ready = '1' and n_io2 = '0' then
                if n_wr = '1' then
                    ram_read <= '1';
                else
                    ram_write <= '1';
                end if;
            end if;
        end if;
    end process;


end architecture behav;
