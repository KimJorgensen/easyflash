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
        button_crt_reset:   in std_logic;
        button_special_fn:  in std_logic;
        flash_addr:         out std_logic_vector(22 downto 0);
        ram_addr:           out std_logic_vector(14 downto 0);
        n_game:             out std_logic;
        n_exrom:            out std_logic;
        start_reset:        out std_logic;
        ram_read:           out std_logic;
        ram_write:          out std_logic;
        flash_read:         out std_logic
    );
end cart_ar;

-- Memory mapping:
-- Bit                        21098765432109876543210
--                            2221111111111  .
-- Bits needed for RAM/Flash:           .    .
--   RAM (32 ki * 8)                  *************** (14..0)
--   Flash (8 Mi * 8)         *********************** (22..0)
-- Used in AR mode:
--   mem_addr(22 downto 15)   000b0111                (22..15)
--   mem_addr(14 downto 13)           0B              (14..13)
--   mem_addr(12 downto 0)              AAAAAAAAAAAAA (12..0)
-- 
-- A    = Address from C64 bus to address 8k per bank
-- b    = AR bank(0)
-- B    = AR bank(1)
-- "01110" = EF Bank 0x1c

architecture behav of cart_ar is

    signal ctrl_game:       std_logic;
    signal ctrl_exrom:      std_logic;
    signal ctrl_ram:        std_logic;
    signal bank:            std_logic_vector(1 downto 0);

begin

    ---------------------------------------------------------------------------
    -- Combinatorically create the next memory address.
    ---------------------------------------------------------------------------
    create_mem_addr: process(bank, addr)
    begin
        flash_addr <= "000" & bank(0) & "01110" & bank(1) & addr(12 downto 0);
        ram_addr   <= "00" & addr(12 downto 0);
    end process;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    rw_control_regs: process(clk, n_reset, n_sys_reset, enable)
    begin
        if n_reset = '0' then
            ctrl_exrom <= '0';
            ctrl_game  <= '0';
            ctrl_ram   <= '0';
            bank       <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                if bus_ready = '1' and n_io1 = '0' then
                    if n_wr = '0' then
                        -- write control register
                        ctrl_ram    <= data(5); 
                        bank        <= data(4 downto 3);
                        ctrl_exrom  <= data(1);
                        ctrl_game   <= data(0);
                    end if;
                end if; -- bus_ready...
            else
                ctrl_exrom <= '1';
                ctrl_game  <= '0';
            end if; -- enable
       end if; -- clk
    end process;

    n_exrom <= ctrl_exrom;
    n_game  <= not ctrl_game;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    rw_mem: process(enable, addr, n_io2, n_roml, n_romh, n_wr, phi2, 
                    bus_ready, ctrl_ram)
    begin
        flash_read <= '0';
        ram_write <= '0';
        ram_read <= '0';
        if enable = '1' then
            if bus_ready = '1' then
                if ctrl_ram = '1' then
                    -- RAM in ROML enabled
                    if n_wr = '1' then
                        -- read RAM only on IO2/ROML to avoid bus contention
                        if n_io2 = '0' or n_roml = '0' then
                            ram_read <= '1';
                        end if;
                    else
                        -- write through to cart RAM like original AR
                        if n_io2 = '0' or addr(15 downto 13) = "100" then
                            ram_write <= '1';
                        end if;
                    end if;
                else
                    if (n_io2 = '0' or n_roml = '0') and n_wr = '1' then
                        flash_read <= '1';
                    end if;
                end if;
                if n_romh = '0' and n_wr = '1' then
                    flash_read <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture behav;
