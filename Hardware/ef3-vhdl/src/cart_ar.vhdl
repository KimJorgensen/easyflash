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
        flash_addr:         out std_logic_vector(16 downto 0);
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
        data_out_valid:     out std_logic;
        led:                out std_logic
    );
end cart_ar;

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

    -- special mode for Nordic/Atomic Power
    signal np_mode:             boolean;
begin

    -- used to check if $00/$01 is addressed in I/O space (for $de00/$de01)
    addr_00_01 <= true when addr(7 downto 1) = "0000000" else false;

    np_mode <= true when
        ctrl_exrom = '1' and ctrl_game = '0' and ctrl_ram = '1'
        else false;

    start_reset <= enable and button_crt_reset;
    led <= enable and not ctrl_kill;

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
    rw_control_regs: process(clk, n_reset, enable)
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
                if freezer_ready = '1' then
                    ctrl_exrom      <= '0';
                    ctrl_game       <= '0';
                    ctrl_ram        <= '0';
                    ctrl_kill       <= '0';
                    ctrl_unfreeze   <= '0';
                    bank            <= (others => '0');
                end if;
                if ctrl_kill = '0' then
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
                    end if;
                end if; -- enable
            else
                data_out_valid_i <= '0';
                ctrl_unfreeze    <= '0';
            end if; -- enable

            if cycle_start = '1' then
                data_out_valid_i <= '0';
            end if;
       end if; -- clk
    end process;

    data_out_valid <= data_out_valid_i;
    reset_freezer  <= ctrl_unfreeze;

    ---------------------------------------------------------------------------
    -- When ctrl_de01_written = '1' a RR firmware is running. In this case
    -- leave GAME and EXROM in VIC-II cycles to avoid flickering when software
    -- uses the Ultimax mode. This seems to be the case with the RR loader.
    --
    -- When there is AR firmware running (which does not write to $de01),
    -- we do not do this, e.g. the hidden part in Pain by Agony Design uses
    -- VIC access to cartridge RAM.
    ---------------------------------------------------------------------------
    set_game_exrom: process(enable, ctrl_exrom, ctrl_game, phi2,
                            ctrl_de01_written,
                            freezer_ready, np_mode)
    begin
        if enable = '1' and (phi2 = '1' or ctrl_de01_written = '0') then
            if freezer_ready = '1' then
                n_exrom <= '1';
                n_game <= '0';
            elsif np_mode then
                n_exrom <= '0';
                n_game  <= '0';
            else
                n_exrom <= ctrl_exrom;
                n_game  <= not ctrl_game;
            end if;
        else
            n_exrom <= '1';
            n_game  <= '1';
        end if;
    end process;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    rw_mem: process(enable, addr, n_io1, n_io2, n_roml, n_romh, n_wr, phi2,
                    bus_ready, ctrl_ram, ctrl_kill, ctrl_reumap, addr_00_01,
                    np_mode)
    begin
        flash_read <= '0';
        ram_read   <= '0';
        ram_write  <= '0';

        if enable = '1' and ctrl_kill = '0' and bus_ready = '1' then
            -- RAM or Flash at I/O1 in REU map or
            --              at I/O2 in normal map or
            --              at ROML
            if (n_io1 = '0' and ctrl_reumap = '1' and not addr_00_01) or
               (n_io2 = '0' and ctrl_reumap = '0')
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

            if n_roml = '0' then
                if n_wr = '1' then
                    if ctrl_ram = '1' and not np_mode then
                        ram_read <= '1';
                    else
                        flash_read <= '1';
                    end if;
                else
                    if ctrl_ram = '1' and not np_mode then
                        ram_write <= '1';
                    end if;
                end if;
            end if;

            if not np_mode and ctrl_ram = '1' and addr(15 downto 13) = "100" and n_wr = '0' then
                -- write through to cart RAM at $8000..$9fff like original AR
                ram_write <= '1';
            end if;

            if np_mode and addr(15 downto 13) = "101" and n_wr = '0' then
                -- write through to cart RAM at $a000..$bfff for Atomic/Nordic Power mode
                ram_write <= '1';
            end if;

            if n_romh = '0' then
                if n_wr = '1' then
                    if np_mode then
                        ram_read <= '1';
                    else
                        flash_read <= '1';
                    end if;
                else
                    if np_mode then
                        ram_write <= '1';
                    end if;
                end if;
            end if; -- n_romh

        end if; -- enable...
    end process;

    ---------------------------------------------------------------------------
    -- Combinatorically create the next memory address.
    --
    -- Memory mapping of AR binary in Flash and AR RAM:
    -- Address Bit                98765432109876543210
    --                            1111111111  .
    -- Bits needed for RAM/Flash:        .    .
    --   RAM (32 ki * 8)               *************** (14..0)
    --   Flash (8 Mi * 8)         ******************** (19..0)
    -- Used in AR mode:
    --   mem_addr(19 downto 15)   BBB1b                (19..15)
    --   mem_addr(14 downto 13)        BB              (14..13)
    --   mem_addr(12 downto 0)           AAAAAAAAAAAAA (12..0)
    --
    -- A    = Address from C64 bus to address 8k per bank
    -- H    = Bank number (high bits) as set by cart_easyflash
    -- b    = AR bank(2)
    -- B    = AR bank(1 downto 0) or "00" for RAM
    -- "1010" corresponds to EF Bank 10:1, this is the AR slot 0
    -- "1011" corresponds to EF Bank 18:1, this is the AR slot 1
    --
    ---------------------------------------------------------------------------
    create_mem_addr: process(bank, addr, n_io1, n_io2, n_romh,
                             np_mode)
    begin
        flash_addr <= '1' & bank & addr(12 downto 0);

       if n_io1 = '0' or n_io2 = '0' or np_mode then
           -- no RAM banking in IO-space and in NP mode
           ram_addr   <= "00" & addr(12 downto 0);
       else
           ram_addr   <= bank(1 downto 0) & addr(12 downto 0);
       end if;
    end process;

end architecture behav;
