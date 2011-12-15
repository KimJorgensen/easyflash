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


entity cart_ss5 is
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
        flash_addr:         out std_logic_vector(19 downto 0);
        ram_addr:           out std_logic_vector(14 downto 0);
        n_game:             out std_logic;
        n_exrom:            out std_logic;
        start_reset:        out std_logic;
        start_freezer:      out std_logic;
        reset_freezer:      out std_logic;
        ram_read:           out std_logic;
        ram_write:          out std_logic;
        flash_read:         out std_logic
    );
end cart_ss5;

architecture behav of cart_ss5 is

    signal start_freezer_i:     std_logic;
    signal ctrl_game:           std_logic;
    signal ctrl_exrom:          std_logic;
    signal ctrl_kill:           std_logic;
    signal bank:                std_logic_vector(1 downto 0);

begin

    start_reset <= enable and button_crt_reset;

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
    --
    -- 32K ROM, 4 * 8K Banks
    -- 32K RAM, 4 * 8K Banks
    --
    -- IO1 read:
    --     Cartridge ROM from current ROML bank
    --
    -- ROML read:
    --     Cartridge RAM or ROM from current ROML bank

    -- ROMH read:
    --     Cartridge ROM from current ROMH bank
    --
    -- $dexx write:
    --
    -- Bit 4: Bank address 14 for ROM/RAM
    -- Bit 3: 1 = Kill cartridge, registers and memory inactive
    -- Bit 2: Bank address 13 for ROM/RAM
    -- Bit 1: EXROM line, 1 = assert, 1 additionally selects RAM for ROML
    -- Bit 0: GAME line, 0 = assert, 1 additionally exits freeze mode
    --
    ---------------------------------------------------------------------------
    rw_control_regs: process(clk, n_reset, enable)
    begin
        if n_reset = '0' then
            bank            <= (others => '0');
            ctrl_kill       <= '0';
            ctrl_exrom      <= '0';
            ctrl_game       <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                if freezer_ready = '1' then
                    bank            <= (others => '0');
                    ctrl_kill       <= '0';
                    ctrl_exrom      <= '0';
                    ctrl_game       <= '0';
                end if;

                if ctrl_kill = '0' and bus_ready = '1' and
                        n_io1 = '0' and n_wr = '0' then
                    -- write control register $de00
                    bank            <= data(4) & data(2);
                    ctrl_kill       <= data(3);
                    ctrl_exrom      <= data(1);
                    ctrl_game       <= data(0);
                end if;
            end if; -- enable
       end if; -- clk
    end process;

    ---------------------------------------------------------------------------
    -- reset_freezer needs a flip flop here, can this be optimized?
    ---------------------------------------------------------------------------
    check_reset_freezer: process(clk, n_reset)
    begin
        if n_reset = '0' then
            reset_freezer <= '0';
        elsif rising_edge(clk) then
            if enable = '1' and freezer_ready = '1' and ctrl_game = '1' then
                reset_freezer <= '1';
            else
                reset_freezer <= '0';
            end if;
        end if; -- clk
    end process;


    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    set_game_exrom: process(enable, ctrl_exrom, ctrl_game, phi2,
                            freezer_ready)
    begin
        if enable = '1' then
            if freezer_ready = '1' then
                n_exrom <= '1';
                n_game <= '0';
            else
                n_exrom <= not ctrl_exrom;
                n_game  <= ctrl_game;
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
                    bus_ready, ctrl_kill, ctrl_exrom)
    begin
        flash_read <= '0';
        ram_read   <= '0';
        ram_write  <= '0';

        if enable = '1' and ctrl_kill = '0' and bus_ready = '1' then
            if n_roml = '0' then
                if n_wr = '1' then
                    if ctrl_exrom = '0' then
                        ram_read <= '1';
                    else
                        flash_read <= '1';
                    end if;
                else
                    if ctrl_exrom = '0' then
                        ram_write <= '1';
                    end if;
                end if;
            end if;

            if n_romh = '0' or n_io1 = '0' then
                if n_wr = '1' then
                    flash_read <= '1';
                end if;
            end if; -- n_romh

        end if; -- enable...
    end process;

    ---------------------------------------------------------------------------
    -- Combinatorically create the next memory address.
    --
    -- Memory mapping of SS5 binary in Flash and SS5 RAM:
    -- Address Bit                98765432109876543210
    --                            1111111111  .
    -- Bits needed for RAM/Flash:        .    .
    --   RAM (32 ki * 8)               *************** (14..0)
    --   Flash (8 Mi * 8)         ******************** (19..0)
    -- Used in AR mode:
    --   mem_addr(19 downto 15)   L1010                (19..15)
    --   mem_addr(14 downto 13)        BB              (14..13)
    --   mem_addr(12 downto 0)           AAAAAAAAAAAAA (12..0)
    --
    -- A    = Address from C64 bus to address 8k per bank
    -- B    = SS5 bank(1 downto 0)
    -- L    = ROML/ROMH, we use A13 just as the real cartridge
    -- "000L1000" corresponds to EF Bank 20
    --
    ---------------------------------------------------------------------------
    create_mem_addr: process(bank, addr, n_io1, n_io2, n_roml)
    begin
        flash_addr <= addr(13) & "1000" & bank & addr(12 downto 0);
        ram_addr   <= bank & addr(12 downto 0);
    end process;

end architecture behav;
