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

entity ef3 is
    port ( addr:                inout std_logic_vector (15 downto 0);
           data:                inout std_logic_vector (7 downto 0);
           n_dma:               out std_logic;
           ba:                  in std_logic;
           n_roml:              in std_logic;
           n_romh:              in std_logic;
           n_io1:               in std_logic;
           n_io2:               in std_logic;
           n_wr:                in std_logic;
           n_irq:               inout std_logic;
           n_nmi:               inout std_logic;
           n_reset_io:          inout std_logic;
           clk:                 in std_logic;
           phi2:                in std_logic;
           n_exrom:             inout std_logic;
           n_game:              inout std_logic;
           button_a:            in  std_logic;
           button_b:            in  std_logic;
           button_c:            in  std_logic;
           n_led:               out std_logic;
           mem_addr:            out std_logic_vector (22 downto 0);
           mem_data:            inout std_logic_vector (7 downto 0);
           n_mem_wr:            out std_logic;
           n_mem_oe:            out std_logic;
           n_flash_cs:          out std_logic;
           n_ram_cs:            out std_logic;
           n_usb_txe:           in std_logic;
           n_usb_rxf:           in std_logic;
           usb_wr:              out std_logic;
           n_usb_rd:            out std_logic
         );
end ef3;

architecture ef3_arc of ef3 is

    -- Current 1 MByte slot, taken from cart_easyflash     (addr 22 downto 20)
    signal slot:                std_logic_vector(2 downto 0);

    -- Current bank (high bits), taken from cart_easyflash (addr 19 downto 17)
    signal bank_hi:             std_logic_vector(2 downto 0);

    -- Current cartridge mode
    signal enable_menu:         std_logic;
    signal enable_ef:           std_logic;
    signal enable_kernal:       std_logic;
    signal enable_ar:           std_logic;
    signal enable_ss5:          std_logic;

    -- This is enabled for several modes
    signal enable_usb:          std_logic;
    signal enable_io2ram:       std_logic;

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

    signal n_ram_cs_i:          std_logic;
    signal n_mem_oe_i:          std_logic;
    signal n_usb_rd_i:          std_logic;
    signal n_usb_wr:            std_logic;

    signal rd:                  std_logic;
    signal wr:                  std_logic;
    signal bus_ready:           std_logic;
    signal phase_pos:           std_logic_vector(10 downto 0);
    signal cycle_start:         std_logic;

    signal data_out:            std_logic_vector(7 downto 0);
    signal data_out_valid:      std_logic;

    signal n_exrom_out:         std_logic;
    signal n_game_out:          std_logic;

    signal phi2_cycle_start:    std_logic;

    -- When this it '1' at the rising edge of clk the reset generator
    -- is started
    signal start_reset:         std_logic;

    -- Reset the machine to enter the menu mode
    signal start_reset_to_menu: std_logic;

    -- This is '1' when software starts the reset generator
    signal sw_start_reset:      std_logic;

    signal n_reset:             std_logic;
    signal n_sys_reset:         std_logic;
    signal n_generated_reset:   std_logic;
    signal start_freezer:       std_logic;
    signal reset_freezer:       std_logic;
    signal freezer_irq:         std_logic;
    signal freezer_ready:       std_logic;

    signal hiram:               std_logic;

    signal ram_read:            std_logic;
    signal ram_write:           std_logic;
    signal flash_read:          std_logic;
    signal flash_write:         std_logic;

    signal ef_flash_addr:       std_logic_vector(16 downto 0);
    signal io2ram_ram_addr:     std_logic_vector(14 downto 0);
    signal ef_n_game:           std_logic;
    signal ef_n_exrom:          std_logic;
    signal ef_start_reset:      std_logic;
    signal io2_ram_read:        std_logic;
    signal io2_ram_write:       std_logic;
    signal ef_flash_read:       std_logic;
    signal ef_flash_write:      std_logic;
    signal ef_data_out:         std_logic_vector(7 downto 0);
    signal ef_data_out_valid:   std_logic;
    signal ef_led:              std_logic;

    signal kernal_flash_addr:   std_logic_vector(16 downto 0);
    signal kernal_n_dma:        std_logic;
    signal kernal_addr_test:    std_logic;
    signal kernal_n_game:       std_logic;
    signal kernal_n_exrom:      std_logic;
    signal kernal_flash_read:   std_logic;
    signal kernal_ram_read:     std_logic;
    signal kernal_ram_write:    std_logic;
    signal kernal_set_bank:     std_logic;
    signal kernal_start_reset:  std_logic;

    signal ar_flash_addr:       std_logic_vector(16 downto 0);
    signal ar_ram_addr:         std_logic_vector(14 downto 0);
    signal ar_n_game:           std_logic;
    signal ar_n_exrom:          std_logic;
    signal ar_start_reset:      std_logic;
    signal ar_start_freezer:    std_logic;
    signal ar_reset_freezer:    std_logic;
    signal ar_ram_read:         std_logic;
    signal ar_ram_write:        std_logic;
    signal ar_flash_read:       std_logic;
    signal ar_data_out:         std_logic_vector(7 downto 0);
    signal ar_data_out_valid:   std_logic;
    signal ar_led:              std_logic;

    signal ss5_flash_addr:      std_logic_vector(16 downto 0);
    signal ss5_ram_addr:        std_logic_vector(14 downto 0);
    signal ss5_n_game:          std_logic;
    signal ss5_n_exrom:         std_logic;
    signal ss5_start_reset:     std_logic;
    signal ss5_start_freezer:   std_logic;
    signal ss5_reset_freezer:   std_logic;
    signal ss5_ram_read:        std_logic;
    signal ss5_ram_write:       std_logic;
    signal ss5_flash_read:      std_logic;
    signal ss5_led:             std_logic;

    signal usb_read:            std_logic;
    signal usb_write:           std_logic;
    signal usb_data_out:        std_logic_vector(7 downto 0);
    signal usb_data_out_valid:  std_logic;

    signal io1_addr_0x:         std_logic;

    attribute KEEP : string; -- keep buffer from being optimized out
    attribute KEEP of io1_addr_0x: signal is "TRUE";
    attribute KEEP of cycle_start: signal is "TRUE";
    --attribute KEEP of rd:          signal is "TRUE";
    --attribute KEEP of wr:          signal is "TRUE";

    component exp_bus_ctrl is
        port (
            clk:                in  std_logic;
            phi2:               in  std_logic;
            n_wr:               in  std_logic;
            rd:                 out std_logic;
            wr:                 out std_logic;
            phase_pos:          out std_logic_vector(10 downto 0);
            cycle_start:        out std_logic;
            phi2_cycle_start:   out std_logic
        );
    end component;

    component reset_generator is
        port (
            clk:                in std_logic;
            phi2_cycle_start:   in std_logic;
            start_reset:        in std_logic;
            n_reset_in:         in  std_logic;
            n_reset:            out std_logic;
            n_generated_reset:  out std_logic;
            n_sys_reset:        out std_logic
        );
    end component;

    component freezer is
        port (
            clk:                in  std_logic;
            n_reset:            in  std_logic;
            phi2:               in  std_logic;
            bus_ready:          in  std_logic;
            ba:                 in  std_logic;
            n_wr:               in  std_logic;
            start_freezer:      in  std_logic;
            reset_freezer:      in  std_logic;
            freezer_irq:        out std_logic;
            freezer_ready:      out std_logic
        );
    end component;

    component cart_easyflash is
        port (
            clk:                in  std_logic;
            n_sys_reset:        in  std_logic;
            reset_to_menu:      in  std_logic;
            n_reset:            in  std_logic;
            enable:             in  std_logic;
            phi2:               in  std_logic;
            n_roml:             in  std_logic;
            n_romh:             in  std_logic;
            rd:                 in  std_logic;
            wr:                 in  std_logic;
            cycle_start:        in  std_logic;
            addr:               in  std_logic_vector(15 downto 0);
            data:               in  std_logic_vector(7 downto 0);
            io1_addr_0x:        in  std_logic;
            button_crt_reset:   in  std_logic;
            button_special_fn:  in  std_logic;
            slot:               out std_logic_vector(2 downto 0);
            bank_hi:            out std_logic_vector(2 downto 0);
            flash_addr:         out std_logic_vector(16 downto 0);
            n_game:             out std_logic;
            n_exrom:            out std_logic;
            start_reset:        out std_logic;
            flash_read:         out std_logic;
            flash_write:        out std_logic;
            data_out:           out std_logic_vector(7 downto 0);
            data_out_valid:     out std_logic;
            led:                out std_logic
        );
    end component;

    component cart_io2ram is
        port (
            enable:         in  std_logic;
            n_io2:          in  std_logic;
            rd:             in  std_logic;
            wr:             in  std_logic;
            addr:           in  std_logic_vector(15 downto 0);
            ram_addr:       out std_logic_vector(14 downto 0);
            ram_read:       out std_logic;
            ram_write:      out std_logic
        );
    end component;

    component cart_kernal is
        port (
            clk:                in  std_logic;
            n_reset:            in  std_logic;
            enable:             in  std_logic;
            phi2:               in  std_logic;
            ba:                 in  std_logic;
            n_romh:             in  std_logic;
            n_wr:               in  std_logic;
            phase_pos:          in  std_logic_vector(10 downto 0);
            cycle_start:        in  std_logic;
            set_bank:           in  std_logic;
            addr:               in  std_logic_vector(15 downto 0);
            data:               in  std_logic_vector(7 downto 0);
            button_crt_reset:   in  std_logic;
            flash_addr:         out std_logic_vector(16 downto 0);
            n_dma:              out std_logic;
            addr_test:          out std_logic;
            n_game:             out std_logic;
            n_exrom:            out std_logic;
            start_reset:        out std_logic;
            flash_read:         out std_logic;
            ram_read:           out std_logic;
            ram_write:          out std_logic;
            hiram:              out std_logic
        );
    end component;

    component cart_ar is
        port (
            clk:                in  std_logic;
            n_reset:            in  std_logic;
            enable:             in  std_logic;
            phi2:               in  std_logic;
            n_io1:              in  std_logic;
            n_io2:              in  std_logic;
            n_roml:             in  std_logic;
            n_romh:             in  std_logic;
            rd:                 in  std_logic;
            wr:                 in  std_logic;
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
    end component;

    component cart_ss5 is
        port (
            clk:                in  std_logic;
            n_reset:            in  std_logic;
            enable:             in  std_logic;
            n_io1:              in  std_logic;
            n_roml:             in  std_logic;
            n_romh:             in  std_logic;
            rd:                 in  std_logic;
            wr:                 in  std_logic;
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
            led:                out std_logic
        );
    end component;

    component cart_usb is
        port (
            clk:                in  std_logic;
            n_reset:            in  std_logic;
            enable:             in  std_logic;
            n_io1:              in  std_logic;
            rd:                 in  std_logic;
            wr:                 in  std_logic;
            cycle_start:        in  std_logic;
            addr:               in  std_logic_vector(15 downto 0);
            io1_addr_0x:        in  std_logic;
            n_usb_rxf:          in  std_logic;
            n_usb_txe:          in  std_logic;
            usb_read:           out std_logic;
            usb_write:          out std_logic;
            data_out:           out std_logic_vector(7 downto 0);
            data_out_valid:     out std_logic
        );
    end component;

begin
    ---------------------------------------------------------------------------
    -- Components
    ---------------------------------------------------------------------------
    u_exp_bus_ctrl: exp_bus_ctrl port map
    (
        clk                     => clk,
        phi2                    => phi2,
        n_wr                    => n_wr,
        rd                      => rd,
        wr                      => wr,
        phase_pos               => phase_pos,
        cycle_start             => cycle_start,
        phi2_cycle_start        => phi2_cycle_start
    );

    u_reset_generator: reset_generator port map
    (
        clk                     => clk,
        phi2_cycle_start        => phi2_cycle_start,
        start_reset             => start_reset,
        n_reset_in              => n_reset_io,
        n_reset                 => n_reset,
        n_generated_reset       => n_generated_reset,
        n_sys_reset             => n_sys_reset
    );

    u_freezer: freezer port map
    (
        clk                     => clk,
        n_reset                 => n_reset,
        phi2                    => phi2,
        bus_ready               => bus_ready,
        ba                      => ba,
        n_wr                    => n_wr,
        start_freezer           => start_freezer,
        reset_freezer           => reset_freezer,
        freezer_irq             => freezer_irq,
        freezer_ready           => freezer_ready
    );

    u_cart_easyflash: cart_easyflash port map
    (
        clk                     => clk,
        n_sys_reset             => n_sys_reset,
        reset_to_menu           => start_reset_to_menu,
        n_reset                 => n_reset,
        enable                  => enable_ef,
        phi2                    => phi2,
        n_roml                  => n_roml,
        n_romh                  => n_romh,
        rd                      => rd,
        wr                      => wr,
        cycle_start             => cycle_start,
        addr                    => addr,
        data                    => data,
        io1_addr_0x             => io1_addr_0x,
        button_crt_reset        => button_crt_reset,
        button_special_fn       => button_special_fn,
        slot                    => slot,
        bank_hi                 => bank_hi,
        flash_addr              => ef_flash_addr,
        n_game                  => ef_n_game,
        n_exrom                 => ef_n_exrom,
        start_reset             => ef_start_reset,
        flash_read              => ef_flash_read,
        flash_write             => ef_flash_write,
        data_out                => ef_data_out,
        data_out_valid          => ef_data_out_valid,
        led                     => ef_led
    );

    u_cart_io2ram: cart_io2ram port map
    (
        enable                  => enable_io2ram,
        n_io2                   => n_io2,
        rd                      => rd,
        wr                      => wr,
        addr                    => addr,
        ram_addr                => io2ram_ram_addr,
        ram_write               => io2_ram_write,
        ram_read                => io2_ram_read
    );

    u_cart_kernal: cart_kernal port map
    (
        clk                     => clk,
        n_reset                 => n_reset,
        enable                  => enable_kernal,
        phi2                    => phi2,
        ba                      => ba,
        n_romh                  => n_romh,
        n_wr                    => n_wr,
        phase_pos               => phase_pos,
        cycle_start             => cycle_start,
        set_bank                => kernal_set_bank,
        addr                    => addr,
        data                    => data,
        button_crt_reset        => button_crt_reset,
        flash_addr              => kernal_flash_addr,
        n_dma                   => kernal_n_dma,
        addr_test               => kernal_addr_test,
        n_game                  => kernal_n_game,
        n_exrom                 => kernal_n_exrom,
        start_reset             => kernal_start_reset,
        flash_read              => kernal_flash_read,
        ram_read                => kernal_ram_read,
        ram_write               => kernal_ram_write,
        hiram                   => hiram
    );

    u_cart_ar: cart_ar port map
    (
        clk                     => clk,
        n_reset                 => n_reset,
        enable                  => enable_ar,
        phi2                    => phi2,
        n_io1                   => n_io1,
        n_io2                   => n_io2,
        n_roml                  => n_roml,
        n_romh                  => n_romh,
        rd                      => rd,
        wr                      => wr,
        cycle_start             => cycle_start,
        addr                    => addr,
        data                    => data,
        button_crt_reset        => button_crt_reset,
        button_special_fn       => button_special_fn,
        freezer_ready           => freezer_ready,
        flash_addr              => ar_flash_addr,
        ram_addr                => ar_ram_addr,
        n_game                  => ar_n_game,
        n_exrom                 => ar_n_exrom,
        start_reset             => ar_start_reset,
        start_freezer           => ar_start_freezer,
        reset_freezer           => ar_reset_freezer,
        ram_read                => ar_ram_read,
        ram_write               => ar_ram_write,
        flash_read              => ar_flash_read,
        data_out                => ar_data_out,
        data_out_valid          => ar_data_out_valid,
        led                     => ar_led
    );

    u_cart_ss5: cart_ss5 port map
    (
        clk                     => clk,
        n_reset                 => n_reset,
        enable                  => enable_ss5,
        n_io1                   => n_io1,
        n_roml                  => n_roml,
        n_romh                  => n_romh,
        rd                      => rd,
        wr                      => wr,
        addr                    => addr,
        data                    => data,
        button_crt_reset        => button_crt_reset,
        button_special_fn       => button_special_fn,
        freezer_ready           => freezer_ready,
        flash_addr              => ss5_flash_addr,
        ram_addr                => ss5_ram_addr,
        n_game                  => ss5_n_game,
        n_exrom                 => ss5_n_exrom,
        start_reset             => ss5_start_reset,
        start_freezer           => ss5_start_freezer,
        reset_freezer           => ss5_reset_freezer,
        ram_read                => ss5_ram_read,
        ram_write               => ss5_ram_write,
        flash_read              => ss5_flash_read,
        led                     => ss5_led
    );

    u_cart_usb: cart_usb
    port map(
        clk                     => clk,
        n_reset                 => n_reset,
        enable                  => enable_usb,
        n_io1                   => n_io1,
        rd                      => rd,
        wr                      => wr,
        cycle_start             => cycle_start,
        addr                    => addr,
        io1_addr_0x             => io1_addr_0x,
        n_usb_rxf               => n_usb_rxf,
        n_usb_txe               => n_usb_txe,
        usb_read                => usb_read,
        usb_write               => usb_write,
        data_out                => usb_data_out,
        data_out_valid          => usb_data_out_valid
    );


    bus_ready <= phase_pos(5);

    enable_usb      <= enable_ef; -- or enable_kernal;
    enable_io2ram   <= enable_ef; -- or enable_kernal;

    button_menu       <= buttons_enabled and button_a;
    button_crt_reset  <= buttons_enabled and button_b;
    button_special_fn <= buttons_enabled and button_c;

    -- unused signals and defaults
    addr <= (others => 'Z');

    n_reset_io  <= 'Z' when n_generated_reset = '1' else '0';
    n_nmi       <= 'Z' when freezer_irq = '0'       else '0';
    n_irq       <= 'Z' when freezer_irq = '0'       else '0';

    -- for readable optimizations: '1' for n_io1 $de00..$de0f
    io1_addr_0x <= '1' when
            n_io1 = '0' and addr(7 downto 4) = x"0"
        else '0';

    -- KERNAL bank at $de0e in menu mode
    kernal_set_bank <= '1' when wr = '1' and io1_addr_0x = '1' and
            addr(3 downto 0) = x"e" and enable_menu = '1'
        else '0';

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
            enable_ef       <= '1';
            enable_menu     <= '1';
            enable_ar       <= '0';
            enable_ss5      <= '0';
            enable_kernal   <= '0';
            sw_start_reset  <= '0';
        elsif rising_edge(clk) then
            sw_start_reset  <= '0';
            if start_reset_to_menu = '1' then
                enable_ef       <= '1';
                enable_menu     <= '1';
                enable_ar       <= '0';
                enable_ss5      <= '0';
                enable_kernal   <= '0';
            elsif wr = '1' and io1_addr_0x = '1' and enable_menu = '1' then
                case addr(3 downto 0) is
                    when x"f" =>
                        enable_ef       <= '0';
                        enable_menu     <= '0';
                        enable_ar       <= '0';
                        enable_ss5      <= '0';
                        enable_kernal   <= '0';
                        -- $de0f = cartridge mode
                        case data(3 downto 0) is
                            when x"0" =>
                                enable_ef <= '1';
                                sw_start_reset <= '1';

                            when x"1" =>
                                enable_ef <= '1';
                                -- without reset, hide this register only

                            when x"2" =>
                                enable_kernal <= '1';
                                sw_start_reset <= '1';

                            when x"3" =>
                                -- FC not implemented
                                sw_start_reset <= '1';

                            when x"4" =>
                                --enable_ar <= '1';
                                sw_start_reset <= '1';

                            when x"5" =>
                                enable_ss5 <= '1';
                                sw_start_reset <= '1';

                            when x"7" =>
                                -- everything disabled
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
    ram_read        <= io2_ram_read or kernal_ram_read or ar_ram_read or ss5_ram_read;
    ram_write       <= io2_ram_write or kernal_ram_write or ar_ram_write or ss5_ram_write;
    flash_read      <= ef_flash_read or kernal_flash_read or ar_flash_read or ss5_flash_read;
    flash_write     <= ef_flash_write;
    n_exrom_out     <= ef_n_exrom and kernal_n_exrom and ar_n_exrom and ss5_n_exrom;
    n_game_out      <= ef_n_game and kernal_n_game and ar_n_game and ss5_n_game;

    data_out        <= ef_data_out or usb_data_out or ar_data_out;
    data_out_valid  <= ef_data_out_valid or usb_data_out_valid or ar_data_out_valid;

    start_reset     <= ef_start_reset or kernal_start_reset or ar_start_reset or
                       ss5_start_reset or
                       start_reset_to_menu or sw_start_reset;

    start_freezer   <= ar_start_freezer or ss5_start_freezer;
    reset_freezer   <= ar_reset_freezer or ss5_reset_freezer;

    n_led <= not (ef_led or ar_led or ss5_led);

    n_dma <= '0' when kernal_n_dma = '0' else 'Z';

    n_exrom <= n_exrom_out; -- when ((n_exrom and n_exrom_out) = '0') else 'Z';

    n_game <= n_game_out; -- when ((n_game and n_game_out) = '0') else 'Z';

    addr(15 downto 12) <= "1011" when kernal_addr_test = '1' else "ZZZZ";

    ---------------------------------------------------------------------------
    --
    ---------------------------------------------------------------------------
    set_mem_addr: process(enable_ef, ef_flash_addr,
                          enable_io2ram, io2ram_ram_addr,
                          enable_kernal, kernal_flash_addr,
                          enable_ar, ar_flash_addr, ar_ram_addr,
                          enable_ss5, ss5_flash_addr, ss5_ram_addr,
                          slot, bank_hi, n_ram_cs_i)
    begin
        mem_addr <= (others => '0');

        -- The upper bits are the slot address and the high bits of bank
        mem_addr(22 downto 17) <= slot & bank_hi;

        -- Take lower address bits from C64 directly
        mem_addr(12 downto 0) <= addr(12 downto 0);

        if n_ram_cs_i = '0' then
            if enable_io2ram = '1' then
                mem_addr(14 downto 13) <= io2ram_ram_addr(14 downto 13);
            elsif enable_ar = '1' then
                mem_addr(14 downto 13) <= ar_ram_addr(14 downto 13);
            elsif enable_ss5 = '1' then
                mem_addr(14 downto 13) <= ss5_ram_addr(14 downto 13);
            end if;
        else
            if enable_kernal = '1' then
                mem_addr(16 downto 13) <= kernal_flash_addr(16 downto 13);
            elsif enable_ef = '1' then
                mem_addr(16 downto 13) <= ef_flash_addr(16 downto 13);
            elsif enable_ar = '1' then
                mem_addr(16 downto 13) <= ar_flash_addr(16 downto 13);
            elsif enable_ss5 = '1' then
                mem_addr(16 downto 13) <= ss5_flash_addr(16 downto 13);
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- The variable write_scheduled is used to delay a n_mem_wr by one
    -- cycle to allow data and address bus to settle.
    ---------------------------------------------------------------------------
    mem_ctrl: process(clk, n_reset)
        variable write_scheduled : integer range 0 to 3;
    begin
        if n_reset = '0' then
            n_ram_cs_i  <= '1';
            n_flash_cs  <= '1';
            n_mem_oe_i  <= '1';
            n_mem_wr    <= '1';
            n_usb_rd_i  <= '1';
            n_usb_wr    <= '1';
            write_scheduled := 0;
        elsif rising_edge(clk) then
            if write_scheduled = 3 then
                n_mem_wr <= '0';
                write_scheduled := write_scheduled - 1;
            elsif write_scheduled = 0 then
                n_mem_wr <= '1';
                n_usb_wr <= '1';

                if ram_read = '1' then
                    -- start ram read, leave active until next cycle_start
                    n_ram_cs_i  <= '0';
                    n_flash_cs  <= '1';
                    n_mem_oe_i  <= '0';
                    n_usb_rd_i  <= '1';
                end if;
                if ram_write = '1' then
                    -- ram write tbd in next cycle
                    n_ram_cs_i  <= '0';
                    n_flash_cs  <= '1';
                    n_mem_oe_i  <= '1';
                    n_usb_rd_i  <= '1';
                    -- 3 means activate n_mem_wr in the next cycle
                    write_scheduled := 3;
                end if;
                if flash_read = '1' then
                    -- start flash read, leave active until next cycle_start
                    n_ram_cs_i  <= '1';
                    n_flash_cs  <= '0';
                    n_mem_oe_i  <= '0';
                    n_usb_rd_i  <= '1';
                end if;
                if flash_write = '1' then
                    -- flash write tbd in next cycle
                    n_ram_cs_i  <= '1';
                    n_flash_cs  <= '0';
                    n_mem_oe_i  <= '1';
                    n_usb_rd_i  <= '1';
                    -- 3 means activate n_mem_wr in the next cycle
                    write_scheduled := 3;
                end if;
                if usb_read = '1' then
                    -- start usb read, leave until cycle_start
                    n_ram_cs_i  <= '1';
                    n_flash_cs  <= '1';
                    n_mem_oe_i  <= '1';
                    n_usb_rd_i  <= '0';
                end if;
                if usb_write = '1' then
                    -- usb write can start now
                    n_ram_cs_i  <= '1';
                    n_flash_cs  <= '1';
                    n_mem_oe_i  <= '1';
                    n_usb_rd_i  <= '1';
                    n_usb_wr    <= '0';
                    -- set it to 2 but not to 3 to avoid n_mem_wr to be set
                    write_scheduled := 2;
                end if;
                if cycle_start = '1' then
                    -- return to idle
                    n_ram_cs_i  <= '1';
                    n_flash_cs  <= '1';
                    n_mem_oe_i  <= '1';
                    n_usb_rd_i  <= '1';
                    n_usb_wr    <= '1';
                    write_scheduled := 0;
                end if;

            else
                write_scheduled := write_scheduled - 1;
            end if;
        end if;
    end process mem_ctrl;
    n_ram_cs <= n_ram_cs_i;
    n_mem_oe <= n_mem_oe_i;
    n_usb_rd <= n_usb_rd_i;
    usb_wr   <= not n_usb_wr;

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
                             mem_data, data_out, data_out_valid,
                             n_mem_oe_i, n_usb_rd_i, data)
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
        elsif n_mem_oe_i = '1' and n_usb_rd_i = '1' then
            mem_data <= data;
        end if;
    end process data_out_enable;

end ef3_arc;
