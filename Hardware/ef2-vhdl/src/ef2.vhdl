----------------------------------------------------------------------------------
-- 
----------------------------------------------------------------------------------
--
-- Registers used:
-- 
-- 19 mem_addr (will be 21 when flash memory is being used)
--  8 mem_data
--  1 mem_data output enable
--  1 n_mem_wr
--  1 n_mem_oe
--  1 n_ram_cs
--  1 n_led
-- ==
-- 32
-- 
-- 11 ram_bank
-- ==
-- 11
-- 
-- component exp_bus_ctrl (u0):
--  2 FDCPE_u0/bus_current_state_i
--  1 FTCPE_u0/bus_out_enable
--  3 FTCPE_u0/dotclk_cnt
--  1 FDCPE_u0/prev_phi2
-- ==
--  7

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.ef2_types.all;


entity ef2 is
    port ( addr:        in std_logic_vector (15 downto 0);
           data:        inout std_logic_vector (7 downto 0);
           n_dma:       out std_logic;
           ba:          in std_logic;
           n_roml:      in std_logic;
           n_romh:      in std_logic;
           n_io1:       in std_logic;
           n_io2:       in std_logic;
           n_wr:        in std_logic;
           n_irq:       out std_logic;
           n_nmi:       out std_logic;
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
           pad4:        out std_logic;
           pad5:        out std_logic
         );
end ef2;

architecture ef2_arc of ef2 is

    -- next state of the bus, detected combinatorically
    signal bus_next_state:  bus_state_type;

    -- current state of the bus
    signal bus_current_state: bus_state_type;

    -- output enable for expansion port data bus
    signal bus_out_enable:  std_logic;

    -- Memory bank for RAM. In GeoRAM and EasyFlash mode 256 bytes of RAM
    -- are visible at once. So this bank will go to memory bits 18 downto 8
    -- for 512 KiB.
    signal ram_bank: std_logic_vector(10 downto 0);

    signal buttons_enabled: std_logic := '0';

    -- Current cartridge mode
    type cartridge_mode is (MODE_GEORAM, MODE_WARPSPEED64, MODE_WARPSPEED128);

    signal cart_mode: cartridge_mode := MODE_GEORAM;

    component exp_bus_ctrl is
        port 
        (  
            n_roml:     in std_logic;
            n_romh:     in std_logic;
            n_io1:      in std_logic;
            n_io2:      in std_logic;
            n_wr:       in std_logic;
            n_reset:    inout std_logic;
            n_dotclk:   in std_logic;
            phi2:       in std_logic;
            bus_next_state:     out bus_state_type;
            bus_current_state:  out bus_state_type;
            bus_out_enable:     out std_logic            
        );
    end component;

begin
    ---------------------------------------------------------------------------
    -- Component: Expansion Port Bus Control
    ---------------------------------------------------------------------------
    u0: exp_bus_ctrl port map 
    (
        n_roml, n_romh, n_io1, n_io2, n_wr, n_reset, n_dotclk, phi2,
        bus_next_state, bus_current_state, bus_out_enable
    );

    ---------------------------------------------------------------------------
    -- The stuff we don't use currently
    ---------------------------------------------------------------------------
    n_dma <= 'Z';
    n_irq <= 'Z';
    n_nmi <= 'Z';
    n_reset <= 'Z';
    n_exrom <= 'Z';
    n_game <= 'Z';
    pad2 <= '1';
    pad3 <= '1';
    pad4 <= '1';
    pad5 <= '1';

    ---------------------------------------------------------------------------
    -- The buttons will be enabled after all buttons have been released one
    -- time. This is done to prevent detection of button presses while the
    -- circuit is powered up.
    ---------------------------------------------------------------------------
    enable_buttons: process(n_dotclk)
    begin
        if rising_edge(n_dotclk) then
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
    switch_cartmode: process(n_dotclk)
    begin
        if rising_edge(n_dotclk) then -- remove me
            n_reset <= 'Z';
            if buttons_enabled = '1' then
                if button_a = '1' then
                    cart_mode <= MODE_GEORAM;
                    n_reset <= '0';
                elsif button_b = '1' then
                    cart_mode <= MODE_WARPSPEED64;
                    n_reset <= '0';
                elsif button_c = '1' then
                    cart_mode <= MODE_WARPSPEED128;
                    n_reset <= '0';
                end if;
            end if;
    --    end if;
    end process switch_cartmode;

    ---------------------------------------------------------------------------
    -- Set the state of the LED.
    ---------------------------------------------------------------------------
    set_led: process(n_dotclk, button_a, button_b, button_c, button_d)
    begin
        if rising_edge(n_dotclk) then
            n_led <= '1';
            if cart_mode = MODE_GEORAM then
                n_led <= '0';
            end if;
        end if;
    end process set_led;

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
    -- Put the addresses onto the memory address bus
    ---------------------------------------------------------------------------
    prepare_mem_address: process(n_dotclk)
    begin
        if rising_edge(n_dotclk) then
            if bus_next_state = BUS_READ_VALID or 
               bus_next_state = BUS_WRITE_VALID then
                -- GeoRAM: Show current RAM bank at $dexx
                if n_io1 = '0' then
                    mem_addr(20 downto 8) <= "00" & ram_bank;
                end if;
                mem_addr(7 downto 0) <= addr(7 downto 0);
            end if;
        end if;
    end process prepare_mem_address;

    ---------------------------------------------------------------------------
    -- Put the addresses onto the memory address bus
    ---------------------------------------------------------------------------
    prepare_mem_data: process(n_dotclk)
    begin
        if rising_edge(n_dotclk) then
            mem_data <= (others => 'Z');
            if bus_next_state = BUS_WRITE_VALID or
               bus_next_state = BUS_WRITE_ENABLE then
                -- GeoRAM: Show current RAM bank at $dexx
                if n_io1 = '0' then
                    mem_data <= data;
                end if;
            end if;
        end if;
    end process prepare_mem_data;

    ---------------------------------------------------------------------------
    -- Control lines for read/write from RAM or Flash
    ---------------------------------------------------------------------------
    mem_control: process(n_dotclk, n_reset)
    begin
        n_mem_reset <= n_reset;

        -- used for all of the 'else' branches
        -- todo: put these in variables?

        if rising_edge(n_dotclk) then

            case bus_next_state is

                when BUS_IDLE =>
                    n_flash_cs  <= '1';
                    n_ram_cs    <= '1';
                    n_mem_wr    <= '1';
                    n_mem_oe    <= '1';

                when BUS_READ_VALID =>
                    -- GeoRAM: Read RAM at $de00
                    if n_io1 = '0' then
                        n_ram_cs   <= '0';
                        n_mem_oe   <= '0';
                    end if;

                when BUS_WRITE_ENABLE =>
                    -- GeoRAM: Write RAM at $de00
                    if n_io1 = '0' then
                        n_ram_cs   <= '0';
                        n_mem_wr   <= '0';
                    end if;

                when others => null;
            end case;
        end if;
    end process mem_control;

    ---------------------------------------------------------------------------
    -- Set the RAM bank.
    -- In GeoRAM mode:
    --     $dffe select 256 bytes of 16 KiB block (i.e. bits 13 downto 8) 
    --     $dfff select 16 KiB block (i.e. bits 18 downto 14 @ 512 KiB)
    --     we check the lowest bit of the address only
    --     todo: how many bits did the original GeoRAM check?
    -- In EasyFlash mode:
    --     RAM bank always 0
    --     todo: Would it be useful to use the last page of RAM?
    ---------------------------------------------------------------------------
    set_ram_bank: process(n_dotclk, n_reset)
    begin
        if n_reset = '0' then
            ram_bank <= (others => '0');
        elsif rising_edge(n_dotclk) then
            -- GeoRAM
            if bus_next_state = BUS_WRITE_ENABLE and n_io2 = '0' then
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
        end if;
    end process set_ram_bank;

end ef2_arc;
