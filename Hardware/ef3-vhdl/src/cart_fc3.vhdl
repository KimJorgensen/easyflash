----------------------------------------------------------------------------------
--
-- EasyFlash 3 CPLD Firmware version 1.2.0, May 2018, are
-- Copyright (c) 2018 Kim Jorgensen, are derived from EasyFlash 3 CPLD Firmware 1.1.1,
-- and are distributed according to the same disclaimer and license as
-- EasyFlash 3 CPLD Firmware 1.1.1
--
-- EasyFlash 3 CPLD Firmware versions 0.9.0, December 2011, through 1.1.1, August 2012, are
-- Copyright (c) 2011-2012 Thomas 'skoe' Giesel
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

entity cart_fc3 is
    port (
        clk:                in  std_logic;
        n_reset:            in  std_logic;
        enable:             in  std_logic;
        n_io1:              in  std_logic;
        n_io2:              in  std_logic;
        n_roml:             in  std_logic;
        n_romh:             in  std_logic;
        rd:                 in  std_logic;
        wp:                 in  std_logic;
        addr:               in  std_logic_vector(15 downto 0);
        data:               in  std_logic_vector(7 downto 0);
        bank_lo:            in  std_logic_vector(2 downto 0);
        button_crt_reset:   in  std_logic;
        button_special_fn:  in  std_logic;
        freezer_ready:      in  std_logic;
        set_bank_lo:        out std_logic;
        new_bank_lo:        out std_logic_vector(2 downto 0);
        n_game:             out std_logic;
        n_exrom:            out std_logic;
        start_reset:        out std_logic;
        start_freezer:      out std_logic;
        flash_read:         out std_logic;
        led:                out std_logic
    );
end cart_fc3;

architecture behav of cart_fc3 is
    signal ctrl_hide:           std_logic;
    signal ctrl_nmi:            std_logic;
    signal ctrl_game:           std_logic;
    signal ctrl_exrom:          std_logic;

    signal write_enable:        std_logic;
    signal cart_dfff_write:     std_logic;

    attribute KEEP : string; -- keep buffer from being optimized out
    attribute KEEP of cart_dfff_write: signal is "TRUE";
begin

    write_enable <= '1' when ctrl_hide = '0' or button_special_fn = '1'
        else '0';

    -- Write to register $dfff
    cart_dfff_write <= '1' when write_enable = '1' and wp = '1' and n_io2 = '0'
        and addr(7 downto 0) = x"ff" else '0';

    ctrl_nmi    <= bank_lo(2);
    start_reset <= enable and button_crt_reset;
    led         <= enable and write_enable;

    ---------------------------------------------------------------------------
    -- Combinatorial process to prepare output signals set_bank_lo and
    -- new_bank_lo.
    ---------------------------------------------------------------------------
    update_bank_lo: process(enable, data, freezer_ready, addr,
                            button_crt_reset, cart_dfff_write)
    begin
        set_bank_lo <= '0';
        new_bank_lo <= (others => '0');

        if enable = '1' then
            -- optimization: use unused bit in bank_lo to store ctrl_nmi
            new_bank_lo(2) <= data(6);

            -- todo: support FC3+ (data bit 2+3)
            new_bank_lo(1 downto 0) <= data(1 downto 0);

            if cart_dfff_write = '1' then
                set_bank_lo <= '1';
            end if;
            if button_crt_reset = '1' or freezer_ready = '1' then
                set_bank_lo <= '1';
                new_bank_lo <= (others => '0');
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    do_freezer: process(enable, button_special_fn, ctrl_nmi)
    begin
        start_freezer <= '0';

        if enable = '1' and (button_special_fn = '1' or ctrl_nmi = '0') then
            start_freezer <= '1';
        end if;
    end process;

    ---------------------------------------------------------------------------
    --
    --  $dfff write:
    --      This register is reset to $00 on reset.
    --      Bit 7: Hide register, 1 = disable write to register
    --      Bit 6: NMI line, 0 = assert
    --      Bit 5: GAME line, 0 = assert
    --      Bit 4: EXROM line, 0 = assert
    --      Bit 3: Bank address 17 for ROM (only FC3+)
    --      Bit 2: Bank address 16 for ROM (only FC3+)
    --      Bit 1: Bank address 15 for ROM
    --      Bit 0: Bank address 14 for ROM
    --
    ---------------------------------------------------------------------------
    w_control_reg: process(clk, n_reset, enable, cart_dfff_write)
    begin
        if n_reset = '0' then
            ctrl_hide   <= '0';
            ctrl_game   <= '0';
            ctrl_exrom  <= '0';
        elsif rising_edge(clk) then
            if enable = '1' then
                if freezer_ready = '1' then
                    ctrl_hide   <= '0';
                    ctrl_game   <= '0';
                    ctrl_exrom  <= '0';
                end if;

                if cart_dfff_write = '1' then
                    -- write control register $dfff
                    -- for bank & nmi refer to combinatorial logic new_bank_lo
                    ctrl_hide   <= data(7);
                    ctrl_game   <= data(5);
                    ctrl_exrom  <= data(4);
                end if;
            end if; -- enable
       end if; -- clk
    end process;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    set_game_exrom: process(enable, ctrl_exrom, ctrl_game, freezer_ready)
    begin
        if enable = '1' then
            if freezer_ready = '1' then
                n_exrom <= '0';
                n_game  <= '0';
            else
                n_exrom <= ctrl_exrom;
                n_game  <= ctrl_game;
            end if;
        else
            n_exrom <= '1';
            n_game  <= '1';
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Combinatorial process to prepare flash read access.
    ---------------------------------------------------------------------------
    r_flash: process(enable, n_io1, n_io2, n_roml, n_romh, rd)
    begin
        flash_read <= '0';

        if enable = '1' and rd = '1' then
            if n_io1 = '0' or n_io2 = '0' or n_roml = '0' or n_romh = '0' then
                flash_read <= '1';
            end if;
        end if;
    end process;

end architecture behav;
