----------------------------------------------------------------------------------
-- 
-- (c) 2010 Thomas 'skoe' Giesel
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

--
-- Registers used:
-- 
-- 13 mem_addr
--  1 n_mem_wr
--  1 n_mem_oe
--  1 n_ram_cs
--  1 n_flash_cs
--  1 n_reset tristate enable
--  1 n_led
--  1 n_exrom
--  1 n_game
-- ==
-- 21
-- 
-- 11 ram_bank
--  7 flash_bank
--  1 buttons_enabled
--  1 cart_mode
--  1 easyflash_boot
-- ==
-- 21
-- 
-- component exp_bus_ctrl (u0):
--  6
-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.ef2_types.all;


entity ef2 is
    port ( addr:        inout std_logic_vector (15 downto 0);
           data:        inout std_logic_vector (7 downto 0);
           n_dma:       out std_logic;
           ba:          in std_logic;
           n_roml:      in std_logic;
           n_romh:      in std_logic;
           n_io1:       in std_logic;
           n_io2:       in std_logic;
           n_wr:        in std_logic;
           n_irq:       in std_logic;
           n_nmi:       inout std_logic;
           n_reset:     inout std_logic;
           n_dotclk:    in std_logic;
           phi2:        in std_logic;
           n_exrom:     out std_logic;
           n_game:      out std_logic;
           button_a:    in  std_logic;
           button_b:    in  std_logic;
           button_c:    in  std_logic;
           button_d:    in  std_logic;
           n_led:       out std_logic;
           mem_addr:    out std_logic_vector (20 downto 0);
           mem_data:    inout std_logic_vector (7 downto 0);
           n_mem_wr:    out std_logic;
           n_mem_oe:    out std_logic;
           n_flash_cs:  out std_logic;
           n_ram_cs:    out std_logic;
           n_mem_reset: out std_logic;
           pad2:        out std_logic;
           pad3:        out std_logic;
           clk_out:     out std_logic;
           clk_in:      in  std_logic
         );
end ef2;

architecture ef2_arc of ef2 is

    -- This clock is about 16 MHz, double frequency of dotclock
    signal clk:                     std_logic;
    
    -- next state of the bus, detected combinatorically
    signal bus_next_state:          bus_state_type;

    -- current state of the bus
    signal bus_current_state:       bus_state_type;

    -- current state of the hiram detection
    signal hrdet_current_state:     hiram_det_state_type;

    -- next state of the hiram detection
    signal hrdet_next_state:        hiram_det_state_type;

    -- output enable for expansion port data bus
    signal bus_out_enable:          std_logic;

    -- This is '0' when our memory chips have output enabled
    signal n_mem_oe_i:              std_logic;

    -- This is '1' when the CPU addresses kernal space
    signal kernal_space_addressed:  std_logic;

    -- This is '1' when the CPU writes to the kernal address space
    signal kernal_space_cpu_write:  std_logic;
    
    -- Memory bank for RAM. In GeoRAM and EasyFlash mode 256 bytes of RAM
    -- are visible at once. So this bank will go to memory bits 18 downto 8
    -- for 512 KiB.
    signal ram_bank:            std_logic_vector(10 downto 0);

    -- Memory bank for Flash ROM. Usually 8 KiB of ROM can be visible at
    -- LOROM and 8 KiB of ROM can be seen at HIROM. So this bank will go to 
    -- memory bits 19 downto 13 for 1 MiB (bit 20 is for HIROM/LOROM).
    signal flash_bank:          std_logic_vector(6 downto 0);

    signal buttons_enabled:     std_logic := '0';

    -- at least one of the lines n_io1, n_io2, n_roml, n_romh is active
    signal cart_addressed: std_logic;

    -- Current cartridge mode
    type cartridge_mode is (MODE_GEORAM, MODE_EASYFLASH, MODE_KERNAL, MODE_FC3);
    signal cart_mode: cartridge_mode := MODE_GEORAM;

    -- When we are in easyflash mode: boot enabled?
    signal easyflash_boot: std_logic := '1';

    -- I/O 0xdfff is addressed 
    signal io_dfff_addressed: std_logic;

    -- Internal state of NMI line
    signal n_nmi_i: std_logic;

    -- When the freezer button is pressed and BA is low, this is '1'
    signal freezer: std_logic;
    
    component exp_bus_ctrl is
        port 
        (  
            n_roml:     in std_logic;
            n_romh:     in std_logic;
            n_io1:      in std_logic;
            n_io2:      in std_logic;
            n_wr:       in std_logic;
            n_reset:    inout std_logic;
            clk:        in std_logic;
            phi2:       in std_logic;
            ba:         in std_logic;            
            addr:       in std_logic_vector(15 downto 12);
            bus_next_state:     out bus_state_type;
            bus_current_state:  out bus_state_type;
            bus_out_enable:     out std_logic;
            hrdet_next_state:   out hiram_det_state_type;
            hrdet_current_state: out hiram_det_state_type
        );
    end component;

begin
    ---------------------------------------------------------------------------
    -- Component: Expansion Port Bus Control
    ---------------------------------------------------------------------------
    u0: exp_bus_ctrl port map 
    (
        n_roml, n_romh, n_io1, n_io2, n_wr, n_reset, clk, phi2,
        ba, addr(15 downto 12),
        bus_next_state, bus_current_state, bus_out_enable,
        hrdet_next_state, hrdet_current_state
    );

    ---------------------------------------------------------------------------
    -- Double clock frequency
    ---------------------------------------------------------------------------
    clk_out <= not n_dotclk;
    clk <= n_dotclk xor clk_in;

    ---------------------------------------------------------------------------
    -- The stuff we don't use currently
    ---------------------------------------------------------------------------
    n_dma <= 'Z';
    n_reset <= 'Z';
    n_mem_reset <= '1'; 
    pad2 <= '1';
    pad3 <= '1';
    addr <= (others => 'Z');

    ---------------------------------------------------------------------------
    -- Combinatorical logic used here and there
    ---------------------------------------------------------------------------
    kernal_space_addressed <= '1' when addr(15 downto 13) = "111" else '0';

    -- Note: Do not check BA here, since the CPU can also write in the first
    -- cycles of BA = '0'
    kernal_space_cpu_write <= '1' when kernal_space_addressed = '1' and 
        n_wr = '0' else '0';

    io_dfff_addressed <= '1' when 
        n_io2 = '0' and addr(7 downto 0) = x"ff" else '0';

    cart_addressed <= not (n_io1 and n_io2 and n_roml and n_romh);

    ---------------------------------------------------------------------------
    -- The buttons will be enabled after all buttons have been released one
    -- time. This is done to prevent detection of button presses while the
    -- circuit is powered up.
    ---------------------------------------------------------------------------
    enable_buttons: process(clk)
    begin
        if rising_edge(clk) then
            if button_a = '0' and button_b = '0' and 
               button_c = '0' and button_d = '0' then
                buttons_enabled <= '1';
            end if;
        end if;
    end process enable_buttons;

    ---------------------------------------------------------------------------
    -- Check the cartridge buttons. If one is pressed, reset the C64 and 
    -- activate the cartridge mode according to the buttons
    ---------------------------------------------------------------------------
    switch_cartmode: process(clk)
    begin
        if rising_edge(clk) then
            n_reset <= 'Z';
            freezer <= '0';
            
            if buttons_enabled = '1' then
                if button_a = '1' then
                    cart_mode <= MODE_GEORAM;
                    n_reset <= '0';

                elsif button_b = '1' then
                    cart_mode <= MODE_EASYFLASH;
                    easyflash_boot <= '1';
                    n_reset <= '0';

                elsif button_c = '1' then
                    cart_mode <= MODE_KERNAL;
                    -- cart_mode <= MODE_FC3;
                    n_reset <= '0';

                elsif button_d = '1' then
                    -- This button has a special function depending from mode
                    case cart_mode is
                        when MODE_EASYFLASH =>
                            easyflash_boot <= '0';
                            n_reset <= '0';

                        when MODE_FC3 =>
                            if ba = '1' then
                                freezer <= '1'; -- todo: Counter?
                            end if;
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process switch_cartmode;

    ---------------------------------------------------------------------------
    -- Set the state of the LED.
    ---------------------------------------------------------------------------
--    set_led: process(clk)
  --  begin
    --    if rising_edge(clk) then
      --      n_led <= '1';
        --    if cart_mode = MODE_GEORAM then
          --      n_led <= '0';
--            end if;
  --      end if;
    --end process set_led;

    ---------------------------------------------------------------------------
    -- Control the data bus of the expansion port. But it in high impedance
    -- whenever there is no read access active from the expansion port.
    -- Otherwise route the right data to the port.
    --
    -- It is possible that we put nonsense onto the bus, e.g. when the CPU
    -- reads undefined addresses from our address space.
    ---------------------------------------------------------------------------
    data_to_port : process(bus_out_enable, mem_data)
    begin
        if bus_out_enable = '1' then
            data <= mem_data;
        else
            data <= (others => 'Z');
        end if;
    end process data_to_port;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    set_game_exrom_dma: process(clk, n_reset, cart_mode)
    begin
        if n_reset = '0' then
            n_exrom  <= '1';
            n_game   <= '1';
            n_dma    <= '1';

            case cart_mode is
                when MODE_EASYFLASH =>
                    n_game  <= not easyflash_boot;

                when MODE_FC3 =>
                    n_exrom <= '0';
                    n_game <= '0';
                    
                when others => null;
            end case;

        elsif rising_edge(clk) then

            case cart_mode is
                    
                when MODE_EASYFLASH =>
                    if bus_next_state = BUS_WRITE_VALID and 
                          n_io1 = '0' and addr(1) = '1' then
                        -- $de02 (only addr(1) is checked in the original EF)
                        n_exrom <= not data(1);
                        if data(2) = '0' then
                            n_game <= not easyflash_boot;
                        else
                            n_game <= not data(0);
                        end if;
                    end if;

                when MODE_KERNAL =>
                    -- HIRAM detection needed to distinguish RAM and ROM read
                    -- refer to hrdet state machine comments
                    case hrdet_next_state is
                        when HRDET_STATE_IDLE =>
                            n_dma <= '1';
                            n_exrom <= '1';
                            n_game <= '1';

                        when HRDET_STATE_DMA =>
                            n_dma <= '0';
                            n_game <= '0';
                            n_exrom <= '0';

                        when HRDET_STATE_READ =>
                            -- Ultimax mode
                            n_dma <= '1';
                            n_exrom <= '1';

                        when others => null;
                    end case;

                when MODE_FC3 =>
                    if bus_next_state = BUS_WRITE_VALID and io_dfff_addressed = '1' then
                        -- $dfff
                        n_exrom <= data(4);
                        n_game  <= data(5);
                    elsif freezer = '1' then
                        n_game <= '0';
                    end if;

                when others => null;
            end case;
        end if;
    end process set_game_exrom_dma;

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    set_nmi: process(clk, n_reset, cart_mode)
    begin
        if n_reset = '0' then
            if cart_mode = MODE_FC3 then
                n_nmi_i <= '0';
            else
                n_nmi_i <= '1';
            end if;
        elsif rising_edge(clk) then
            if cart_mode = MODE_FC3 then
                if bus_next_state = BUS_WRITE_VALID and 
                   io_dfff_addressed = '1' then
                    -- $dfff
                    if data(6) = '0' then
                        n_nmi_i <= '0';
                    else
                        n_nmi_i <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process set_nmi;

    n_nmi <= 'Z' when n_nmi_i = '1' and freezer = '0' else '0';

    ---------------------------------------------------------------------------
    -- Pull down A14 for Kernal mode (HIRAM detection)
    ---------------------------------------------------------------------------
    pull_down_a14: process(clk)
    begin
        if rising_edge(clk) then
            -- we put the CPU in DMA-mode, put 0xBxxx on address bus
            if cart_mode = MODE_KERNAL and 
               hrdet_next_state = HRDET_STATE_DETECT then
                addr(14) <= '0';
            else
                addr(14) <= 'Z';
            end if;
        end if;
    end process pull_down_a14;

    ---------------------------------------------------------------------------
    -- Put the addresses onto the memory address bus
    ---------------------------------------------------------------------------
    prepare_mem_address: process(clk)
    begin
        if rising_edge(clk) then
            
            if cart_mode = MODE_KERNAL then
                if hrdet_next_state = HRDET_STATE_DMA then
                    -- Prepare read address, no matter if it will be 
                    -- ROM or RAM: High address lines will work for both
                    mem_addr(20 downto 8) <= x"44" & addr(12 downto 8);

                elsif bus_next_state = BUS_WRITE_VALID then
                    -- Write accesses always go to RAM, same address as above
                    mem_addr(20 downto 8) <= x"44" & addr(12 downto 8);
                end if;

            elsif bus_next_state = BUS_READ_VALID or 
                  bus_next_state = BUS_WRITE_VALID then

                case cart_mode is
                    when MODE_GEORAM =>
                        -- Show current RAM bank at $dexx
                        if n_io1 = '0' then
                            mem_addr(20 downto 8) <= "00" & ram_bank;
                        end if;

                    when MODE_EASYFLASH =>
                        if n_io2 = '0' then
                            -- Show RAM bank 0 at $dfxx                            
                            mem_addr(20 downto 8) <= (others => '0');
                        elsif n_roml = '0' then
                            -- Show current Flash bank at ROML or ROMH
                            mem_addr(20 downto 8) <= 
                                "0" & flash_bank & addr(12 downto 8);
                        elsif n_romh = '0' then
                            mem_addr(20 downto 8) <= 
                                "1" & flash_bank & addr(12 downto 8);
                        end if;
    
                    when MODE_FC3 =>
                        if n_roml = '0' then
                            -- Show current Flash bank at ROML or ROMH
                            mem_addr(20 downto 8) <= 
                                x"4" & "00" & flash_bank(1 downto 0) & addr(12 downto 8);
                        elsif n_romh = '0' then
                            mem_addr(20 downto 8) <= 
                                x"c" & "00" & flash_bank(1 downto 0) & addr(12 downto 8);
                        elsif n_io1 = '0' or n_io2 = '0' then
                            mem_addr(20 downto 8) <= 
                                x"4" & "00" & flash_bank(1 downto 0) & addr(12 downto 8);
                        end if;

                    when others => null;
                end case;
            end if;
        end if;
    end process prepare_mem_address;

    mem_addr(7 downto 0) <= addr(7 downto 0);

    ---------------------------------------------------------------------------
    -- Copy expansion bus data to memory bus data
    ---------------------------------------------------------------------------
    prepare_mem_data: process(n_mem_oe_i, data)
    begin
        if n_mem_oe_i = '0' then
            mem_data <= (others => 'Z');
        else
            mem_data <= data;
        end if;
    end process prepare_mem_data;

    ---------------------------------------------------------------------------
    -- Control lines for read/write from RAM or Flash
    ---------------------------------------------------------------------------
    mem_control: process(clk, n_reset)
    begin
        if n_reset = '0' then
            n_flash_cs  <= '1';
            n_ram_cs    <= '1';
            n_mem_oe_i  <= '1';
            n_mem_wr    <= '1';
            n_led       <= '1';
        
        elsif rising_edge(clk) then

            case cart_mode is

                when MODE_GEORAM =>
                    case bus_next_state is
                        when BUS_IDLE =>
                            n_flash_cs  <= '1';
                            n_ram_cs    <= '1';
                            n_mem_oe_i  <= '1';
                            n_mem_wr    <= '1';
                            
                        when BUS_READ_VALID =>
                            if n_io1 = '0' then
                                -- Read RAM at $de00
                                n_ram_cs   <= '0';
                                n_mem_oe_i <= '0';
                            end if;
            
                        when BUS_WRITE_VALID =>
                            if n_io1 = '0' then
                                -- Write RAM at $de00
                                n_ram_cs <= '0';
                            end if;

                        when BUS_WRITE_ENABLE =>
                            if n_io1 = '0' then
                                -- Write RAM at $de00
                                n_mem_wr <= '0';
                            end if;

                        when others => null;
                    end case;

                when MODE_EASYFLASH =>
                    case bus_next_state is
                        when BUS_IDLE =>
                            n_flash_cs  <= '1';
                            n_ram_cs    <= '1';
                            n_mem_oe_i  <= '1';
                            n_mem_wr    <= '1';
                            
                        when BUS_READ_VALID =>
                            if n_io2 = '0' then
                                -- Read RAM at $df00
                                n_ram_cs   <= '0';
                                n_mem_oe_i <= '0';
                            elsif n_roml = '0' or n_romh = '0' then
                                -- Read FLASH at ROML/ROMH
                                n_flash_cs <= '0';
                                n_mem_oe_i <= '0';
                            end if;

                        when BUS_WRITE_VALID =>
                            if n_io2 = '0' then
                                -- Write RAM at $df00
                                n_ram_cs <= '0';
                            elsif n_roml = '0' or n_romh = '0' then
                                -- Write FLASH at ROML/ROMH
                                n_flash_cs <= '0';
                            end if;
            
                        when BUS_WRITE_ENABLE =>
                            if n_io2 = '0' or n_roml = '0' or n_romh = '0' then
                                -- Write RAM at $df00 or FLASH at ROML/ROMH
                                n_mem_wr <= '0';
                            end if;

                        when others => null;
                    end case;

                when MODE_FC3 =>
                    case bus_next_state is
                        when BUS_IDLE =>
                            n_flash_cs  <= '1';
                            n_ram_cs    <= '1';
                            n_mem_oe_i  <= '1';
                            n_mem_wr    <= '1';

                        when BUS_READ_VALID =>
                            if cart_addressed = '1' then
                                -- Read FLASH at ROML/ROMH/IO1/IO2
                                n_flash_cs <= '0';
                                n_mem_oe_i <= '0';
                            end if;

                        when others => null;
                    end case;

                when MODE_KERNAL =>
                    -- read kernal at 0xe000..0xffff
                    if hrdet_current_state = HRDET_STATE_DETECT then
                        -- we did some preparations to detect HIRAM
                        if n_romh = '0' then
                            -- read rom
                            n_flash_cs <= '0';
                            n_led <= '1';
                        else
                            -- read ram below rom
                            n_ram_cs <= '0';
                            n_led <= '0';
                        end if;
                        n_mem_oe_i <= '0';
                    else
                        case bus_next_state is
                            when BUS_IDLE =>
                                n_flash_cs  <= '1';
                                n_ram_cs    <= '1';
                                n_mem_oe_i  <= '1';
                                n_mem_wr    <= '1';
            
                            when BUS_WRITE_VALID =>
                                if kernal_space_cpu_write = '1' then
                                    n_ram_cs <= '0';
                                end if;
    
                            when BUS_WRITE_ENABLE =>
                                if kernal_space_cpu_write = '1' then
                                    n_mem_wr <= '0';
                                end if;

                            when others => null;
                        end case;
                    end if;

                when others => null;
            end case;
        end if;
    end process mem_control;

    n_mem_oe <= n_mem_oe_i;

    ---------------------------------------------------------------------------
    -- Set the RAM bank.
    -- In GeoRAM mode:
    --     $dffe select 256 bytes of 16 KiB block (i.e. bits 13 downto 8) 
    --     $dfff select 16 KiB block (i.e. bits 18 downto 14 @ 512 KiB)
    --     we check the lowest bit of the address only
    --     todo: how many bits did the original GeoRAM check?
    -- In EasyFlash mode:
    --     RAM bank not used, always 0
    ---------------------------------------------------------------------------
    set_ram_bank: process(clk, n_reset)
    begin
        if n_reset = '0' then
            ram_bank <= (others => '0');
        elsif rising_edge(clk) then
            if bus_next_state = BUS_WRITE_VALID then
                case cart_mode is
                    when MODE_GEORAM =>
                        if n_io2 = '0' then
                            -- todo: Wie sieht das Register-Mirroring bei der 
                            --       Original-GeoRAM aus?
                            -- $dffe
                            if addr(0) = '0' then
                                ram_bank(5 downto 0)  <= data(5 downto 0);
                            -- $dfff
                            else
                                ram_bank(10 downto 6) <= data(4 downto 0);
                            end if;
                        end if;
                
                    when others => null;
                end case;
            end if;
        end if;
    end process set_ram_bank;

    ---------------------------------------------------------------------------
    -- Set the Flash ROM bank.
    -- In EasyFlash mode:
    --     $de00 select flash bank 8 KiB block (i.e. bits 19 downto 13)
    ---------------------------------------------------------------------------
    set_flash_bank: process(clk, n_reset)
    begin
        if n_reset = '0' then
            flash_bank <= (others => '0');
        elsif rising_edge(clk) then
            if bus_next_state = BUS_WRITE_VALID then
                case cart_mode is
                    when MODE_EASYFLASH =>
                        -- $de00 (only addr(1) is checked in the original EF)
                        if n_io1 = '0' and addr(1) = '0' then
                            flash_bank(6 downto 0) <= data(6 downto 0);
                        end if;

                    when MODE_FC3 =>
                        if io_dfff_addressed = '1' then
                            flash_bank(1 downto 0) <= data(1 downto 0);
                        end if;

                    when others => null;
                end case;
            end if;
        end if;
    end process set_flash_bank;

end ef2_arc;
