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


entity cart_usb is
    port (
        clk:            in  std_logic;
        n_reset:        in  std_logic;
        enable:         in  std_logic;
        n_io1:          in  std_logic;
        n_wr:           in  std_logic;
        bus_ready:      in  std_logic;
        cycle_start:    in  std_logic;
        addr:           in  std_logic_vector(15 downto 0);
        io1_addr_0x_rdy: in  std_logic;
        n_usb_rxf:      in  std_logic;
        n_usb_txe:      in  std_logic;
        usb_read:       out std_logic;
        usb_write:      out std_logic;
        data_out:       out std_logic_vector(7 downto 0);
        data_out_valid: out std_logic
    );
end cart_usb;


architecture behav of cart_usb is

    signal data_out_valid_i:    std_logic;

begin

    ---------------------------------------------------------------------------
    -- This process decides combinatorically which data has to be put to
    -- data out.
    --
    -- ID register:      0xa1
    -- Check this register several times for 0xa1 to make sure USB is actually
    -- there. Not bullet-proof but better than nothing.
    --
    -- Control register: 7   6   5   4   3   2   1   0
    --                   RXR TXR 0   0   0   0   0   0
    --
    -- RXF  (RX Ready)   If this bit is set, received data can be read
    -- TXF  (TX Ready)   If this bit is set, data can be transmitted
    ---------------------------------------------------------------------------
    create_data_out: process(data_out_valid_i, n_usb_rxf, n_usb_txe, addr, n_io1)
        variable a : integer range 0 to 31;
    begin
        data_out <= (others => '0');
        if data_out_valid_i = '1' then
            if n_io1 = '0' then
                case addr(7 downto 0) is
                    when x"08" =>
                        -- $de08 - read ID register
                        data_out <= x"a1";

                    when x"09" =>
                        -- $de09 - read control register
                        data_out <= not n_usb_rxf & not n_usb_txe & "000000";
                    when others => null;
                end case;
            elsif false then
                a := to_integer(unsigned(addr(4 downto 0)));
                case a is
	                when  0 => data_out <= x"80";
	                when  1 => data_out <= x"09"; -- start vector => $8009
	                -- 2, 3 - don't care
	                when  4 => data_out <= x"c3";
	                when  5 => data_out <= x"c2";
	                when  6 => data_out <= x"cd";
	                when  7 => data_out <= x"38";
	                when  8 => data_out <= x"30"; -- CBM80
	                when  9 => data_out <= x"2c";
	                when 10 => data_out <= x"09";
	                when 11 => data_out <= x"de"; -- bit $de09
	                when 12 => data_out <= x"10";
	                when 13 => data_out <= x"fb"; -- bpl ...
	                when 14 => data_out <= x"ad";
	                when 15 => data_out <= x"0a";
	                when 16 => data_out <= x"de"; -- lda $de0a
	                when 17 => data_out <= x"48"; -- pha
	                when 18 => data_out <= x"ca"; -- dex
	                when 19 => data_out <= x"d0";
	                when 20 => data_out <= x"f4"; -- bne ...
	                when 21 => data_out <= x"60"; -- rts

	                when others => null;
	            end case;
	        end if;
	    end if;
    end process;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    rw_regs: process(clk, n_reset)
    begin
        if n_reset = '0' then
            data_out_valid_i <= '0';
        elsif rising_edge(clk) then
            usb_read  <= '0';
            usb_write <= '0';
            if enable = '1' then
                if io1_addr_0x_rdy = '1' then
                    if n_wr = '0' then
                        case addr(3 downto 0) is
                            when x"a" =>
                                -- $de0a - write data
                                usb_write <= '1';

                            when others => null;
                        end case;
                    else
                        case addr(3 downto 0) is
                            when x"8" =>
                                -- $de08 - read ID register
                                data_out_valid_i <= '1';

                            when x"9" =>
                                -- $de09 - read control register
                                data_out_valid_i <= '1';

                            when x"a" =>
                                -- $de0a - read data
                                usb_read <= '1';

                            when others => null;
                        end case;
                    end if;
                end if; -- bus_ready...
                if cycle_start = '1' then
                    data_out_valid_i <= '0';
                end if;
            else
                data_out_valid_i <= '0';
            end if; -- enable
       end if; -- clk
    end process;

    data_out_valid <= data_out_valid_i;
end architecture behav;
