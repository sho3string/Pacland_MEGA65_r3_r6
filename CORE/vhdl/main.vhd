----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
-- Pac-Land (Jotego JTFRAME) - MEGA65 wrapper
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;
use work.globals.all;
library xpm;
use xpm.vcomponents.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(3 downto 0);
      video_green_o           : out std_logic_vector(3 downto 0);
      video_blue_o            : out std_logic_vector(3 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0);

      -- ROM download bus from QNICE
      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(24 downto 0);
      dn_data_i               : in  std_logic_vector(7 downto 0);
      dn_wr_i                 : in  std_logic;

      debug_led_o             : out std_logic;

      osm_control_i           : in  std_logic_vector(255 downto 0)
   );
end entity main;

architecture synthesis of main is

   -- Packed QNICE ROM image boundaries (byte addresses)
   constant ROM_MAIN_START     : natural := 16#00000#;
   constant ROM_MCUSUB_START   : natural := 16#20000#;
   constant ROM_SCR0_START     : natural := 16#22000#;
   constant ROM_SCR1_START     : natural := 16#24000#;
   constant ROM_OBJ_START      : natural := 16#26000#;
   constant ROM_MCU_START      : natural := 16#36000#;
   constant ROM_RGPAL_START    : natural := 16#37000#;
   constant ROM_BPAL_START     : natural := 16#37400#;
   constant ROM_SCR0PAL_START  : natural := 16#37800#;
   constant ROM_SCR1PAL_START  : natural := 16#37C00#;
   constant ROM_OBJPAL_START   : natural := 16#38000#;
   constant ROM_END            : natural := 16#38400#;
   
   -- Keyboard inputs are used for movement only in Keyboard mode
   constant m65_1          : integer := 56; --Player 1 Start
   constant m65_2          : integer := 59; --Player 2 Start
   constant m65_5          : integer := 16; --Insert coin 1
   constant m65_6          : integer := 19; --Insert coin 2
   constant m65_9          : integer := 32; --Service button
    
   constant m65_up_crsr    : integer := 73; --Player up
   constant m65_vert_crsr  : integer := 7;  --Player down
   constant m65_left_crsr  : integer := 74; --Player left
   constant m65_horz_crsr  : integer := 2;  --Player right
   constant m65_z          : integer := 12; --Fire 1
   constant m65_x          : integer := 23; --Left
   constant m65_c          : integer := 20; --Right
   constant m65_v          : integer := 31; --Fire 1
   constant m65_capslock   : integer := 72; --Pause
   constant AUDIO_GAIN_SH  : natural := 5;   -- 4 = never clips, 5 = louder; try both


   signal keyboard_n            : std_logic_vector(79 downto 0);
   signal reset_async           : std_logic;
   signal reset_48              : std_logic;
   signal pxl_cen               : std_logic := '0';
   signal pxl2_cen              : std_logic := '0';
   signal cen_c30               : std_logic := '0';
   signal pxl_div               : unsigned(2 downto 0) := (others => '0');
   signal c30_acc               : integer range 0 to 124 := 0;
   signal pl_cab                : std_logic_vector(3 downto 0);
   signal pl_coin               : std_logic_vector(3 downto 0);
   signal p1_buttons            : std_logic_vector(2 downto 0);
   signal p1_mapped             : std_logic_vector(2 downto 0);
   signal p1_left_n             : std_logic;
   signal p1_right_n            : std_logic;
   signal p1_jump_n             : std_logic;
   signal pl_joy1               : std_logic_vector(6 downto 0);
   signal pl_joy2               : std_logic_vector(6 downto 0);
   signal pl_dipsw_a            : std_logic_vector(7 downto 0);
   signal pl_dipsw_b            : std_logic_vector(7 downto 0);
   signal pl_dipsw              : std_logic_vector(31 downto 0);
   signal pl_cus_l              : std_logic_vector(15 downto 0);
   signal pl_cus_r              : std_logic_vector(15 downto 0);
   signal pl_cpu_dout           : std_logic_vector(7 downto 0);
   signal pl_bg_we              : std_logic_vector(1 downto 0);
   signal pl_fg_we              : std_logic_vector(1 downto 0);
   signal pl_olut_we            : std_logic_vector(1 downto 0);
   signal pl_vram0_addr         : std_logic_vector(11 downto 0);
   signal pl_vram1_addr         : std_logic_vector(11 downto 0);
   signal pl_oram_addr          : std_logic_vector(12 downto 0);
   signal pl_vram0_dout         : std_logic_vector(15 downto 0);
   signal pl_vram1_dout         : std_logic_vector(15 downto 0);
   signal pl_fg_dout            : std_logic_vector(15 downto 0);
   signal pl_bg_dout            : std_logic_vector(15 downto 0);
   signal pl_oram_dout          : std_logic_vector(15 downto 0);
   signal pl_olut_dout          : std_logic_vector(15 downto 0);
   signal pl_sndram_addr        : std_logic_vector(11 downto 0);
   signal pl_sndram_din         : std_logic_vector(7 downto 0);
   signal pl_sndram_dout        : std_logic_vector(7 downto 0);
   signal pl_sndram_we          : std_logic;
   signal pl_rgb_addr           : std_logic_vector(9 downto 0);
   signal pl_scr0pal_addr       : std_logic_vector(9 downto 0);
   signal pl_scr1pal_addr       : std_logic_vector(9 downto 0);
   signal pl_objpal_addr        : std_logic_vector(9 downto 0);
   signal pl_mcu_addr           : std_logic_vector(11 downto 0);
   signal pl_rgpal_data         : std_logic_vector(7 downto 0);
   signal pl_bpal_data          : std_logic_vector(7 downto 0);
   signal pl_scr0pal_data       : std_logic_vector(7 downto 0);
   signal pl_scr1pal_data       : std_logic_vector(7 downto 0);
   signal pl_objpal_data        : std_logic_vector(7 downto 0);
   signal pl_mcu_data           : std_logic_vector(7 downto 0);
   signal pl_main_cs            : std_logic;
   signal pl_mcusub_cs          : std_logic;
   signal pl_scr0_cs            : std_logic;
   signal pl_scr1_cs            : std_logic;
   signal pl_obj_cs             : std_logic;
   signal pl_main_addr          : std_logic_vector(16 downto 0);
   signal pl_mcusub_addr        : std_logic_vector(12 downto 0);
   signal pl_scr0_addr          : std_logic_vector(12 downto 0);
   signal pl_scr1_addr          : std_logic_vector(12 downto 0);
   signal pl_obj_addr           : std_logic_vector(15 downto 0);
   signal pl_main_data          : std_logic_vector(7 downto 0);
   signal pl_mcusub_data        : std_logic_vector(7 downto 0);
   signal pl_scr0_data          : std_logic_vector(15 downto 0);
   signal pl_scr1_data          : std_logic_vector(15 downto 0);
   signal pl_obj_data           : std_logic_vector(31 downto 0);
   signal pl_main_ok            : std_logic := '0';
   signal pl_mcusub_ok          : std_logic := '0';
   signal pl_scr0_ok            : std_logic := '0';
   signal pl_scr1_ok            : std_logic := '0';
   signal pl_obj_ok             : std_logic := '0';
   signal pl_main_addr_d        : std_logic_vector(16 downto 0);
   signal pl_mcusub_addr_d      : std_logic_vector(12 downto 0);
   signal pl_scr0_addr_d        : std_logic_vector(12 downto 0);
   signal pl_scr1_addr_d        : std_logic_vector(12 downto 0);
   signal pl_obj_addr_d         : std_logic_vector(15 downto 0);

   signal dn_we_main_0          : std_logic;
   signal dn_we_mcusub_0        : std_logic;
   signal dn_we_scr0_0          : std_logic;
   signal dn_we_scr0_1          : std_logic;
   signal dn_we_scr1_0          : std_logic;
   signal dn_we_scr1_1          : std_logic;
   signal dn_we_obj_0           : std_logic;
   signal dn_we_obj_1           : std_logic;
   signal dn_we_obj_2           : std_logic;
   signal dn_we_obj_3           : std_logic;
   signal dn_we_mcu_0           : std_logic;
   signal dn_we_rgpal_0         : std_logic;
   signal dn_we_bpal_0          : std_logic;
   signal dn_we_scr0pal_0       : std_logic;
   signal dn_we_scr1pal_0       : std_logic;
   signal dn_we_objpal_0        : std_logic;
   
   signal dn_obj_addr           : std_logic_vector(15 downto 0);
   

    -- Byte-addressed ROM layout; each ROM lane is an 8-bit dual-clock RAM.
    -- MCU: $36000-$36FFF, palette PROMs: five successive 1KB regions.
   -- Dual-clock ROM/PROM storage (runtime read, QNICE write)
   component dualport_2clk_ram
      generic (
         FALLING_A  : boolean := false;
         FALLING_B  : boolean := false;
         ADDR_WIDTH : integer := 8
      );
      port (
         clock_a   : in  std_logic;
         clen_a    : in  std_logic := '1';
         address_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
         q_a       : out std_logic_vector(7 downto 0);
         clock_b   : in  std_logic;
         clen_b    : in  std_logic := '1';
         address_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
         data_b    : in  std_logic_vector(7 downto 0);
         wren_b    : in  std_logic
      );
   end component;

   -- Video read / CPU read-write, with independent byte enables
   component paclan_dualram16
      generic (
         AW : positive := 12
      );
      port (
         clk    : in  std_logic;
         addr_a : in  std_logic_vector(AW-1 downto 0);
         dout_a : out std_logic_vector(15 downto 0);
         addr_b : in  std_logic_vector(AW-1 downto 0);
         din_b  : in  std_logic_vector(7 downto 0);
         we_b   : in  std_logic_vector(1 downto 0);
         dout_b : out std_logic_vector(15 downto 0)
      );
   end component;

      begin
      

   ---------------------------------------------------------------------------
   -- Reset and clock enables
   ---------------------------------------------------------------------------
   reset_async <= reset_hard_i or reset_soft_i;
    i_reset_48 : xpm_cdc_async_rst
   generic map (
      RST_ACTIVE_HIGH   => 1,
      DEST_SYNC_FF      => 6
   )
   port map (
      src_arst          => reset_async,
      dest_clk          => clk_main_i,
      dest_arst         => reset_48
   );

    -- Pixel 6.144 MHz, overlay 24.576 MHz, CUS30 3.072 MHz.
    -- Master clock: 49.152 MHz.
    process(clk_main_i)
    begin
        if rising_edge(clk_main_i) then
            pxl_div  <= pxl_div + 1;
            pxl_cen  <= '0';
            pxl2_cen <= '0';
            cen_c30  <= '0';
    
            if pxl_div = 7 then
                pxl_cen <= '1';
            end if;
    
            if pxl_div(1 downto 0) = "11" then
                pxl2_cen <= '1';
            end if;
    
            -- 49.152 MHz / 16 = 3.072 MHz
            if c30_acc >= 15 then
                c30_acc <= 0;
                cen_c30 <= '1';
            else
                c30_acc <= c30_acc + 1;
            end if;
                    end if;
    end process;


   ---------------------------------------------------------------------------
   -- Video and audio outputs
   ---------------------------------------------------------------------------
    video_ce_o <= pxl_cen;
    -- CUS30: sign-extend 13-bit PCM to 16 bits, then scale
    process(clk_main_i)
       variable l, r : signed(19 downto 0);
    begin
       if rising_edge(clk_main_i) then
          l := shift_left(resize(signed(pl_cus_l(12 downto 0)), 20), AUDIO_GAIN_SH);
          r := shift_left(resize(signed(pl_cus_r(12 downto 0)), 20), AUDIO_GAIN_SH);
          if    l >  32767 then audio_left_o  <= to_signed( 32767, 16);
          elsif l < -32768 then audio_left_o  <= to_signed(-32768, 16);
          else                  audio_left_o  <= l(15 downto 0); end if;
          if    r >  32767 then audio_right_o <= to_signed( 32767, 16);
          elsif r < -32768 then audio_right_o <= to_signed(-32768, 16);
          else                  audio_right_o <= r(15 downto 0); end if;
       end if;
    end process;
    
    

   ---------------------------------------------------------------------------
   -- DIP switches and cabinet controls
   ---------------------------------------------------------------------------
    pl_dipsw_a <= not (osm_control_i(C_MENU_SW1_0) & 
                       osm_control_i(C_MENU_SW1_1) &
                       osm_control_i(C_MENU_SW1_2) & 
                       osm_control_i(C_MENU_SW1_3) &
                       osm_control_i(C_MENU_SW1_4) & 
                       osm_control_i(C_MENU_SW1_5) &
                       osm_control_i(C_MENU_SW1_6) & 
                       osm_control_i(C_MENU_SW1_7));
                       
    pl_dipsw_b <= not (osm_control_i(C_MENU_SW2_0) &
                       osm_control_i(C_MENU_SW2_1) &
                       osm_control_i(C_MENU_SW2_2) & 
                       osm_control_i(C_MENU_SW2_3) &
                       osm_control_i(C_MENU_SW2_4) & 
                       osm_control_i(C_MENU_SW2_5) &
                       osm_control_i(C_MENU_SW2_6) & 
                       osm_control_i(C_MENU_SW2_7));
                       
    pl_dipsw <= x"0000" & pl_dipsw_b & pl_dipsw_a;
    -- Cabinet inputs are active low, matching jtpaclan_cab.v.
   
    
    -- Pac-Land original controls: physical Fire/POTX/POTY, with six
    -- permutations for the shared upright controls. Active-low throughout.
    p1_buttons(1) <= joy_1_fire_n_i;
    p1_buttons(0) <= '0' when (pot1_x_i(7) = '0' and osm_control_i(C_MENU_P1POL_0) = '1') or
                              (pot1_x_i(7) = '1' and osm_control_i(C_MENU_P1POL_1) = '1') else '1';
    p1_buttons(2) <= '0' when (pot1_y_i(7) = '0' and osm_control_i(C_MENU_P1POL_0) = '1') or
                              (pot1_y_i(7) = '1' and osm_control_i(C_MENU_P1POL_1) = '1') else '1';


    -- Layout strings denote the physical sequence POTX, Fire, POTY.
    -- Each output is ordered as (Left, Jump, Right).
    process(all)
    begin
       p1_mapped <= p1_buttons;
       if osm_control_i(C_MENU_P1LAY_0) = '1' then
          p1_mapped <= p1_buttons(0) & p1_buttons(1) & p1_buttons(2);
       elsif osm_control_i(C_MENU_P1LAY_1) = '1' then
          p1_mapped <= p1_buttons(0) & p1_buttons(2) & p1_buttons(1);
       elsif osm_control_i(C_MENU_P1LAY_2) = '1' then
          p1_mapped <= p1_buttons(1) & p1_buttons(0) & p1_buttons(2);
       elsif osm_control_i(C_MENU_P1LAY_3) = '1' then
          p1_mapped <= p1_buttons(2) & p1_buttons(0) & p1_buttons(1);
       elsif osm_control_i(C_MENU_P1LAY_4) = '1' then
          p1_mapped <= p1_buttons(1) & p1_buttons(2) & p1_buttons(0);
       elsif osm_control_i(C_MENU_P1LAY_5) = '1' then
          p1_mapped <= p1_buttons(2) & p1_buttons(1) & p1_buttons(0);
       end if;
    end process;


    -- Modes are exclusive: 3-button and joystick ignore keyboard movement;
    -- keyboard mode ignores all physical joystick and POT inputs.
    process(all)
    begin
       pl_joy1 <= (others => '1');

       if osm_control_i(C_MENU_MODE_2) = '1' then
          -- Keyboard: cursor keys or X/C for movement; Z/V to jump.
          pl_joy1(0) <= keyboard_n(m65_horz_crsr) and keyboard_n(m65_c);
          pl_joy1(1) <= keyboard_n(m65_left_crsr) and keyboard_n(m65_x);
          pl_joy1(2) <= keyboard_n(m65_vert_crsr);
          pl_joy1(3) <= keyboard_n(m65_up_crsr);
          pl_joy1(4) <= keyboard_n(m65_z) and keyboard_n(m65_v);
       elsif osm_control_i(C_MENU_MODE_1) = '1' then
          -- Joystick: left/right movement, Fire to jump.
          pl_joy1(0) <= joy_1_right_n_i;
          pl_joy1(1) <= joy_1_left_n_i;
          pl_joy1(2) <= joy_1_down_n_i;
          pl_joy1(3) <= joy_1_up_n_i;
          pl_joy1(4) <= joy_1_fire_n_i;
       else
          -- 3-button: POTX/Fire/POTY mapped to Left/Jump/Right.
          pl_joy1(0) <= p1_mapped(0);
          pl_joy1(1) <= p1_mapped(2);
          pl_joy1(2) <= joy_1_down_n_i;
          pl_joy1(3) <= joy_1_up_n_i;
          pl_joy1(4) <= p1_mapped(1);
       end if;
    end process;

    -- Upright cabinet: both players share the selected control scheme.
    pl_joy2 <= pl_joy1;

    pl_cab  <= "11" & keyboard_n(m65_2) & keyboard_n(m65_1);
    pl_coin <= "11" & keyboard_n(m65_5) & keyboard_n(m65_6);
   ---------------------------------------------------------------------------
   -- Keyboard interface
   ---------------------------------------------------------------------------
   i_keyboard : entity work.keyboard
   port map (
      clk_main_i        => clk_main_i,
      key_num_i         => kb_key_num_i,
      key_pressed_n_i   => kb_key_pressed_n_i,
      example_n_o       => keyboard_n
   );

   ---------------------------------------------------------------------------
   -- Pac-Land game core
   ---------------------------------------------------------------------------
   i_pacland : entity work.jtpaclan_game
   port map (
      rst               => reset_48,
      clk               => clk_main_i,
      pxl_cen           => pxl_cen,
      pxl2_cen          => pxl2_cen,
      cen_c30           => cen_c30,
      red               => video_red_o,
      green             => video_green_o,
      blue              => video_blue_o,
      LHBL              => video_hblank_o,
      LVBL              => video_vblank_o,
      HS                => video_hs_o,
      VS                => video_vs_o,
      cab_1p            => pl_cab,
      coin              => pl_coin,
      joystick1         => pl_joy1,
      joystick2         => pl_joy2,
      service           => keyboard_n(m65_9),
      dip_pause         => keyboard_n(m65_capslock),
      dip_flip          => open,
      dipsw             => pl_dipsw,
      gfx_en            => "1111",
      debug_bus         => (others => '0'),
      debug_view        => open,
      ioctl_addr        => (others => '0'),
      ioctl_din         => open,
      main_cs           => pl_main_cs,
      main_addr         => pl_main_addr,
      main_data         => pl_main_data,
      main_ok           => pl_main_ok,
      mcusub_cs         => pl_mcusub_cs,
      mcusub_addr       => pl_mcusub_addr,
      mcusub_data       => pl_mcusub_data,
      mcusub_ok         => pl_mcusub_ok,
      scr0_cs           => pl_scr0_cs,
      scr0_addr         => pl_scr0_addr,
      scr0_data         => pl_scr0_data,
      scr0_ok           => pl_scr0_ok,
      scr1_cs           => pl_scr1_cs,
      scr1_addr         => pl_scr1_addr,
      scr1_data         => pl_scr1_data,
      scr1_ok           => pl_scr1_ok,
      obj_cs            => pl_obj_cs,
      obj_addr          => pl_obj_addr,
      obj_data          => pl_obj_data,
      obj_ok            => pl_obj_ok,
      mcu_addr          => pl_mcu_addr,
      mcu_data          => pl_mcu_data,
      rgb_addr          => pl_rgb_addr,
      rgpal_data        => pl_rgpal_data,
      bpal_data         => pl_bpal_data,
      scr0pal_addr      => pl_scr0pal_addr,
      scr0pal_data      => pl_scr0pal_data,
      scr1pal_addr      => pl_scr1pal_addr,
      scr1pal_data      => pl_scr1pal_data,
      objpal_addr       => pl_objpal_addr,
      objpal_data       => pl_objpal_data,
      cpu_dout          => pl_cpu_dout,
      vram0_addr        => pl_vram0_addr,
      vram0_dout        => pl_vram0_dout,
      bg_we             => pl_bg_we,
      fg_dout           => pl_fg_dout,
      vram1_addr        => pl_vram1_addr,
      vram1_dout        => pl_vram1_dout,
      fg_we             => pl_fg_we,
      bg_dout           => pl_bg_dout,
      oram_addr         => pl_oram_addr,
      oram_dout         => pl_oram_dout,
      olut_we           => pl_olut_we,
      olut_dout         => pl_olut_dout,
      sndram_addr       => pl_sndram_addr,
      sndram_din        => pl_sndram_din,
      sndram_dout       => pl_sndram_dout,
      sndram_we         => pl_sndram_we,
      cus30_l           => pl_cus_l,
      cus30_r           => pl_cus_r
   );
   
   
    
    ---------------------------------------------------------------------------
   -- ROM address stability handshakes
   ---------------------------------------------------------------------------
   process(clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         pl_main_addr_d   <= pl_main_addr;
         pl_mcusub_addr_d <= pl_mcusub_addr;
         pl_scr0_addr_d   <= pl_scr0_addr;
         pl_scr1_addr_d   <= pl_scr1_addr;
         pl_obj_addr_d    <= pl_obj_addr;

      end if;
   end process;

   pl_main_ok   <= '1' when pl_main_addr   = pl_main_addr_d   else '0';
   pl_mcusub_ok <= '1' when pl_mcusub_addr = pl_mcusub_addr_d else '0';
   pl_scr0_ok   <= '1' when pl_scr0_addr   = pl_scr0_addr_d   else '0';
   pl_scr1_ok   <= '1' when pl_scr1_addr   = pl_scr1_addr_d   else '0';
   pl_obj_ok    <= '1' when pl_obj_addr    = pl_obj_addr_d    else '0';
  
   ---------------------------------------------------------------------------
   -- Writable video and object RAM
   ---------------------------------------------------------------------------
   i_vram0 : paclan_dualram16
   generic map (
      AW                => 12
   )
   port map (
      clk               => clk_main_i,
      addr_a            => pl_vram0_addr,
      dout_a            => pl_vram0_dout,
      addr_b            => '0' & pl_main_addr(11 downto 1),
      din_b             => pl_cpu_dout,
      we_b              => pl_bg_we,
      dout_b            => pl_fg_dout
   );
   i_vram1 : paclan_dualram16
   generic map (
      AW                => 12
   )
   port map (
      clk               => clk_main_i,
      addr_a            => pl_vram1_addr,
      dout_a            => pl_vram1_dout,
      addr_b            => '0' & pl_main_addr(11 downto 1),
      din_b             => pl_cpu_dout,
      we_b              => pl_fg_we,
      dout_b            => pl_bg_dout
   );
   i_oram : paclan_dualram16
   generic map (
      AW                => 13
   )
   port map (
      clk               => clk_main_i,
      addr_a            => pl_oram_addr,
      dout_a            => pl_oram_dout,
      addr_b            => '0' & pl_main_addr(12 downto 1),
      din_b             => pl_cpu_dout,
      we_b              => pl_olut_we,
      dout_b            => pl_olut_dout
   );
   -- CUS30 sound RAM
   process(clk_main_i)
      type ram_t is array (0 to 4095) of std_logic_vector(7 downto 0);
      variable snd : ram_t;
   begin
      if rising_edge(clk_main_i) then
         if pl_sndram_we = '1' then
            snd(to_integer(unsigned(pl_sndram_addr))) := pl_sndram_din;
         end if;
         pl_sndram_dout <= snd(to_integer(unsigned(pl_sndram_addr)));
      end if;
   end process;

   ---------------------------------------------------------------------------
   -- QNICE ROM download chip selects
   ---------------------------------------------------------------------------
   dn_we_main_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_MAIN_START and
      unsigned(dn_addr_i) <  ROM_MCUSUB_START
      else '0';

   dn_we_mcusub_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_MCUSUB_START and
      unsigned(dn_addr_i) <  ROM_SCR0_START
      else '0';

   dn_we_scr0_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_SCR0_START and
      unsigned(dn_addr_i) <  ROM_SCR1_START and
      dn_addr_i(0) = '0'
      else '0';

   dn_we_scr0_1 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_SCR0_START and
      unsigned(dn_addr_i) <  ROM_SCR1_START and
      dn_addr_i(0) = '1'
      else '0';

   dn_we_scr1_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_SCR1_START and
      unsigned(dn_addr_i) <  ROM_OBJ_START and
      dn_addr_i(0) = '0'
      else '0';

   dn_we_scr1_1 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_SCR1_START and
      unsigned(dn_addr_i) <  ROM_OBJ_START and
      dn_addr_i(0) = '1'
      else '0';

   dn_we_obj_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_OBJ_START and
      unsigned(dn_addr_i) <  ROM_MCU_START and
      dn_addr_i(1 downto 0) = "00"
      else '0';

   dn_we_obj_1 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_OBJ_START and
      unsigned(dn_addr_i) <  ROM_MCU_START and
      dn_addr_i(1 downto 0) = "01"
      else '0';

   dn_we_obj_2 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_OBJ_START and
      unsigned(dn_addr_i) <  ROM_MCU_START and
      dn_addr_i(1 downto 0) = "10"
      else '0';

   dn_we_obj_3 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_OBJ_START and
      unsigned(dn_addr_i) <  ROM_MCU_START and
      dn_addr_i(1 downto 0) = "11"
      else '0';

   dn_we_mcu_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_MCU_START and
      unsigned(dn_addr_i) <  ROM_RGPAL_START
      else '0';

   dn_we_rgpal_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_RGPAL_START and
      unsigned(dn_addr_i) <  ROM_BPAL_START
      else '0';

   dn_we_bpal_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_BPAL_START and
      unsigned(dn_addr_i) <  ROM_SCR0PAL_START
      else '0';

   dn_we_scr0pal_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_SCR0PAL_START and
      unsigned(dn_addr_i) <  ROM_SCR1PAL_START
      else '0';

   dn_we_scr1pal_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_SCR1PAL_START and
      unsigned(dn_addr_i) <  ROM_OBJPAL_START
      else '0';

   dn_we_objpal_0 <= dn_wr_i when
      unsigned(dn_addr_i) >= ROM_OBJPAL_START and
      unsigned(dn_addr_i) <  ROM_END
      else '0';

   ---------------------------------------------------------------------------
   -- Main CPU ROM
   ---------------------------------------------------------------------------
   i_rom_main_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 17
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_main_addr,
      q_a               => pl_main_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(16 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_main_0
   );

   ---------------------------------------------------------------------------
   -- Sub-MCU ROM
   ---------------------------------------------------------------------------
   i_rom_mcusub_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 13
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_mcusub_addr,
      q_a               => pl_mcusub_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(12 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_mcusub_0
   );

   ---------------------------------------------------------------------------
   -- Foreground graphics ROM
   ---------------------------------------------------------------------------
   i_rom_scr0_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 12
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_scr0_addr(11 downto 0),
      q_a               => pl_scr0_data(7 downto 0),
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(12 downto 1),
      data_b            => dn_data_i,
      wren_b            => dn_we_scr0_0
   );

   i_rom_scr0_1 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 12
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_scr0_addr(11 downto 0),
      q_a               => pl_scr0_data(15 downto 8),
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(12 downto 1),
      data_b            => dn_data_i,
      wren_b            => dn_we_scr0_1
   );

   ---------------------------------------------------------------------------
   -- Background graphics ROM
   ---------------------------------------------------------------------------
   i_rom_scr1_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 12
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_scr1_addr(11 downto 0),
      q_a               => pl_scr1_data(7 downto 0),
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(12 downto 1),
      data_b            => dn_data_i,
      wren_b            => dn_we_scr1_0
   );

   i_rom_scr1_1 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 12
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_scr1_addr(11 downto 0),
      q_a               => pl_scr1_data(15 downto 8),
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(12 downto 1),
      data_b            => dn_data_i,
      wren_b            => dn_we_scr1_1
   );
   
   -- Convert absolute download address to object-ROM-relative byte address.
   dn_obj_addr <= std_logic_vector(unsigned(dn_addr_i(15 downto 0)) -
                                    to_unsigned(ROM_OBJ_START mod 65536, 16));

   ---------------------------------------------------------------------------
   -- Sprite graphics ROM
   ---------------------------------------------------------------------------
   i_rom_obj_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 14
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_obj_addr(13 downto 0),
      q_a               => pl_obj_data(7 downto 0),
      clock_b           => dn_clk_i,
      address_b         => dn_obj_addr(15 downto 2),
      data_b            => dn_data_i,
      wren_b            => dn_we_obj_0
   );

   i_rom_obj_1 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 14
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_obj_addr(13 downto 0),
      q_a               => pl_obj_data(15 downto 8),
      clock_b           => dn_clk_i,
      address_b         => dn_obj_addr(15 downto 2),
      data_b            => dn_data_i,
      wren_b            => dn_we_obj_1
   );

   i_rom_obj_2 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 14
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_obj_addr(13 downto 0),
      q_a               => pl_obj_data(23 downto 16),
      clock_b           => dn_clk_i,
      address_b         => dn_obj_addr(15 downto 2),
      data_b            => dn_data_i,
      wren_b            => dn_we_obj_2
   );

   i_rom_obj_3 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 14
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_obj_addr(13 downto 0),
      q_a               => pl_obj_data(31 downto 24),
      clock_b           => dn_clk_i,
      address_b         => dn_obj_addr(15 downto 2),
      data_b            => dn_data_i,
      wren_b            => dn_we_obj_3
   );

   ---------------------------------------------------------------------------
   -- MCU program ROM
   ---------------------------------------------------------------------------
   i_rom_mcu_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 12
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_mcu_addr,
      q_a               => pl_mcu_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(11 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_mcu_0
   );

   ---------------------------------------------------------------------------
   -- Palette PROMs
   ---------------------------------------------------------------------------
   i_rom_rgpal_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 10
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_rgb_addr,
      q_a               => pl_rgpal_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(9 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_rgpal_0
   );

   i_rom_bpal_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 10
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_rgb_addr,
      q_a               => pl_bpal_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(9 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_bpal_0
   );

   i_rom_scr0pal_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 10
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_scr0pal_addr,
      q_a               => pl_scr0pal_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(9 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_scr0pal_0
   );

   i_rom_scr1pal_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 10
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_scr1pal_addr,
      q_a               => pl_scr1pal_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(9 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_scr1pal_0
   );

   i_rom_objpal_0 : dualport_2clk_ram
   generic map (
      FALLING_B         => true,
      ADDR_WIDTH        => 10
   )
   port map (
      clock_a           => clk_main_i,
      address_a         => pl_objpal_addr,
      q_a               => pl_objpal_data,
      clock_b           => dn_clk_i,
      address_b         => dn_addr_i(9 downto 0),
      data_b            => dn_data_i,
      wren_b            => dn_we_objpal_0
   );
end architecture synthesis;
