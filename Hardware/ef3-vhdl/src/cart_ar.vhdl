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


entity cart_ar is
    port (
        clk:                in  std_logic;
        n_sys_reset:        in  std_logic;
        n_reset:            in  std_logic;
        enable:             in  std_logic;
        phi2:               in  std_logic;
        n_io1:              in  std_logic;
        n_io2:              in  std_logic;
        n_roml:             in  std_logic;
        n_romh:             in  std_logic;
        n_wr:               in  std_logic;
        bus_ready:          in  std_logic;
        cycle_start:        in  std_logic;
        addr:               in  std_logic_vector(15 downto 0);
        data:               in  std_logic_vector(7 downto 0);
        button_crt_reset:   in  std_logic;
        button_special_fn:  in  std_logic;
        freezer_ready:      in  std_logic;
        flash_addr:         out std_logic_vector(22 downto 0);
        ram_addr:           out std_logic_vector(14 downto 0);
        n_game:             out std_logic;
        n_exrom:            out std_logic;
        start_reset:        out std_logic;
        start_freezer:      out std_logic;
        reset_freezer:      out std_logic;
        ram_read:           out std_logic;
        ram_write:          out std_logic;
        flash_read:         out std_logic;
        data_out:           out std_logic_vector(7 downto 0);
        data_out_valid:     out std_logic
    );
end cart_ar;

-- Memory mapping of AR binary in Flash and AR RAM:
-- Address Bit                21098765432109876543210
--                            2221111111111  .
-- Bits needed for RAM/Flash:           .    .
--   RAM (32 ki * 8)                  *************** (14..0)
--   Flash (8 Mi * 8)         *********************** (22..0)
-- Used in AR mode:
--   mem_addr(22 downto 15)   000b1000                (22..15)
--   mem_addr(14 downto 13)           BB              (14..13)
--   mem_addr(12 downto 0)              AAAAAAAAAAAAA (12..0)
--
-- A    = Address from C64 bus to address 8k per bank
-- b    = AR bank(0)
-- B    = AR bank(2 downto 1) for flash
--        AR bank(1 downto 0) or "00" for RAM
-- "1000" corresponds to EF Bank 0x20

architecture behav of cart_ar is

    signal data_out_valid_i:    std_logic;
    signal start_freezer_i:     std_logic;
    signal ctrl_game:           std_logic;
    signal ctrl_exrom:          std_logic;
    signal ctrl_ram:            std_logic;
    signal ctrl_kill:           std_logic;
    signal ctrl_unfreeze:       std_logic;
    signal ctrl_reumap:         std_logic;
    signal ctrl_de01_written:   std_logic;
    signal bank:                std_logic_vector(2 downto 0);

    signal addr_00_01:          boolean;
begin

    -- used to check if $00/$01 is addressed in I/O space (for $de00/$de01)
    addr_00_01 <= true when addr(7 downto 1) = "0000000" else false;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    do_freezer: process(enable, button_special_fn)
    begin
        start_freezer_i <= '0';
        if enable = '1' and button_special_fn = '1' then
            start_freezer_i <= '1';
        end if; 
    end process;
    start_freezer <= start_freezer_i;

    ---------------------------------------------------------------------------
    -- Combinatorically create the data value for a register read access.
    ---------------------------------------------------------------------------
    create_data_out: process(data_out_valid_i, bank, ctrl_reumap)
    begin
        data_out <= (others => '0');
        if data_out_valid_i = '1' then
            data_out <= bank(2) & ctrl_reumap & '0' & bank(1 downto 0) & "000";
        end if;
    end process;

    ---------------------------------------------------------------------------
    --
    --  $de00 write:
    --      This register is reset to $00 on reset.
    --      Bit 7: Bank address 15 for ROM
    --      Bit 6: Write 1 to exit freeze mode
    --      Bit 5: Switches between ROM and RAM: 0 = ROM, 1 = RAM
    --      Bit 4: Bank address 14 for ROM/RAM
    --      Bit 3: Bank address 13 for ROM/RAM
    --      Bit 2: 1 = Kill cartridge, registers and memory inactive
    --      Bit 1: EXROM line, 0 = assert
    --      Bit 0: GAME line, 1 = assert
    --
    --  $de01 write:
    --      This register is reset to $00 on a hard reset.
    --      Bit 7: Bank address 15 for ROM      (mirror of $de00)
    --      Bit 6: Memory map: 0 = standard, 1 = REU compatible memory map
    --      Bit 5: (Bank address 16, ignored)
    --      Bit 4: Bank address 14 for ROM/RAM  (mirror of $de00)
    --      Bit 3: Bank address 13 for ROM/RAM  (mirror of $de00)
    --      Bit 2: (NoFreeze, ignored)
    --      Bit 1: (AllowBank, ignored)
    --      Bit 0: (Enable accessory connector, ignored)
    --
    --  $de00/$de01 read:
    --      Bit 7: Bank address 15 for ROM
    --      Bit 6: Memory map: 0 = standard, 1 = REU compatible memory map
    --      Bit 5: 0 (Bank address 16)
    --      Bit 4: Bank address 14 for ROM/RAM
    --      Bit 3: Bank address 13 for ROM/RAM
    --      Bit 2: Freeze button (1 = pressed)
    --      Bit 1: 0 (AllowBank)
    --      Bit 0: 0 (Flashmode active)
    --
    ---------------------------------------------------------------------------
    rw_control_regs: process(clk, n_reset, n_sys_reset, enable)
    begin
        if n_reset = '0' then
            ctrl_exrom      <= '0';
            ctrl_game       <= '0';
            ctrl_ram        <= '0';
            ctrl_kill       <= '0';
            ctrl_unfreeze   <= '0';
            ctrl_reumap     <= '0';
            ctrl_de01_written <= '0';
            bank            <= (others => '0');
            data_out_valid_i <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                if start_freezer_i = '1' then
                    bank            <= (others => '0');
                    ctrl_unfreeze   <= '0';
                    ctrl_ram        <= '0';
                    ctrl_kill       <= '0';
                    ctrl_exrom      <= '0';
                    ctrl_game       <= '0';
                elsif ctrl_kill = '0' then
                    if bus_ready = '1' and n_io1 = '0' then
                        if n_wr = '0' then
                            case addr(7 downto 0) is
                                when x"00" =>
                                    -- write control register $de00
                                    bank            <= data(7) & data(4 downto 3);
                                    ctrl_unfreeze   <= data(6);
                                    ctrl_ram        <= data(5);
                                    ctrl_kill       <= data(2);
                                    ctrl_exrom      <= data(1);
                                    ctrl_game       <= data(0);

                                when x"01" =>
                                    -- write control register $de01
                                        bank        <= data(7) & data(4 downto 3);
                                        ctrl_ram    <= data(5);
                                    if ctrl_de01_written = '0' then
                                        ctrl_reumap <= data(6);
                                        -- todo: no freeze
                                        -- todo: allow bank
                                        ctrl_de01_written <= '1';
                                    end if;

                                when others => null;
                            end case;
                        else
                            if addr_00_01 then
                                -- read $de00/$de01
                                data_out_valid_i <= '1';
                            end if;
                        end if;
                    end if; -- bus_ready...
                    if cycle_start = '1' then
                        data_out_valid_i <= '0';
                    end if;
                end if;
            else
                ctrl_exrom <= '1';
                ctrl_game  <= '0';
                data_out_valid_i <= '0';
            end if; -- enable
       end if; -- clk
    end process;

    data_out_valid <= data_out_valid_i;
    reset_freezer  <= ctrl_unfreeze;

    ---------------------------------------------------------------------------
    -- Leave GAME and EXROM in VIC-II cycles to avoid flickering when software
    -- uses the Ultimax mode. This seems to be the case with the RR loader.
    ---------------------------------------------------------------------------
    set_game_exrom: process(enable, ctrl_exrom, ctrl_game, phi2)
    begin
        if freezer_ready = '1' then
            n_exrom <= '1';
            n_game <= '0';
        elsif phi2 = '1' and enable = '1' then
            n_exrom <= ctrl_exrom;
            n_game  <= not ctrl_game;
        else
            n_exrom <= '1';
            n_game  <= '1';
        end if;
    end process;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    rw_mem: process(enable, addr, n_io1, n_io2, n_roml, n_romh, n_wr, phi2,
                    bus_ready, ctrl_ram, ctrl_kill, ctrl_reumap, addr_00_01)
    begin
        flash_read <= '0';
        ram_read   <= '0';
        ram_write  <= '0';

        if enable = '1' and ctrl_kill = '0' and bus_ready = '1' then
            -- RAM or Flash at I/O1 in REU map or
            --              at I/O2 in normal map or
            --              at ROML
            if (n_io1 = '0' and ctrl_reumap = '1' and not addr_00_01) or
               (n_io2 = '0' and ctrl_reumap = '0') or
               (n_roml = '0')
            then
                if n_wr = '1' then
                    if ctrl_ram = '1' then
                        ram_read <= '1';
                    else
                        flash_read <= '1';
                    end if;
                else
                    if ctrl_ram = '1' then
                        ram_write <= '1';
                    end if;
                end if;
            end if;

            if ctrl_ram = '1' and addr(15 downto 13) = "100" and n_wr = '0' then
                -- write through to cart RAM at ROML space like original AR
                ram_write <= '1';
            end if;

            -- ROMH is always flash
            if n_romh = '0' and n_wr = '1' then
                flash_read <= '1';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Combinatorically create the next memory address.
    ---------------------------------------------------------------------------
    create_mem_addr: process(bank, addr, n_io1, n_io2)
    begin
        flash_addr <= "000" & bank(0) & "1010" & bank(2 downto 1) & addr(12 downto 0);
        if n_io1 = '0' or n_io2 = '0' then
            -- no RAM banking in I/O space
            ram_addr   <= "00" & addr(12 downto 0);
        else
            -- but in ROML space
            ram_addr   <= bank(1 downto 0) & addr(12 downto 0);
        end if;
    end process;

end architecture behav;
