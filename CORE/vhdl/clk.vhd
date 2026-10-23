
-------------------------------------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Clock Generator using the Xilinx specific MMCME2_ADV
--
-- Pac-Land / JTFRAME:
--   Input:  100.000000 MHz
--   VCO:    725.000000 MHz
--   Main:    49.152542 MHz
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
-------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

entity clk is
   port (
      sys_clk_i       : in  std_logic;   -- expects 100 MHz

      main_clk_o      : out std_logic;   -- 49.152542 MHz main clock
      main_rst_o      : out std_logic    -- synchronized reset
   );
end entity clk;

architecture rtl of clk is

signal clkfb_mmcm        : std_logic;
signal clkfb             : std_logic;
signal main_clk_mmcm     : std_logic;
signal main_locked       : std_logic;

begin

   -------------------------------------------------------------------------------------
   -- Generate 49.152542 MHz JTFRAME master clock
   -------------------------------------------------------------------------------------

   i_clk_main : MMCME2_ADV
   generic map (
      BANDWIDTH            => "OPTIMIZED",
      CLKOUT4_CASCADE      => FALSE,
      COMPENSATION         => "ZHOLD",
      STARTUP_WAIT         => FALSE,
      CLKIN1_PERIOD        => 10.0,
      REF_JITTER1          => 0.010,

      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT_F      => 7.250,      -- VCO = 725 MHz
      CLKFBOUT_PHASE       => 0.000,
      CLKFBOUT_USE_FINE_PS => FALSE,

      -- Pac-Land / JTFRAME master clock
      CLKOUT0_DIVIDE_F     => 14.750,     -- 725 / 14.75 = 49.152542 MHz
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT0_USE_FINE_PS  => FALSE
   )
   port map (
      -- Output clocks
      CLKFBOUT            => clkfb_mmcm,
      CLKOUT0             => main_clk_mmcm,

      -- Input clock control
      CLKFBIN             => clkfb,
      CLKIN1              => sys_clk_i,
      CLKIN2              => '0',
      CLKINSEL            => '1',

      -- Dynamic reconfiguration
      DADDR               => (others => '0'),
      DCLK                => '0',
      DEN                 => '0',
      DI                  => (others => '0'),
      DO                  => open,
      DRDY                => open,
      DWE                 => '0',

      -- Dynamic phase shift
      PSCLK               => '0',
      PSEN                => '0',
      PSINCDEC            => '0',
      PSDONE              => open,

      -- Status/control
      LOCKED              => main_locked,
      CLKINSTOPPED        => open,
      CLKFBSTOPPED        => open,
      PWRDWN              => '0',
      RST                 => '0'
   );

   -------------------------------------------------------------------------------------
   -- Output buffering
   -------------------------------------------------------------------------------------

   clkfb_bufg : BUFG
   port map (
      I => clkfb_mmcm,
      O => clkfb
   );

   -- 49.152542 MHz JTFRAME master clock
   main_clk_bufg : BUFG
   port map (
      I => main_clk_mmcm,
      O => main_clk_o
   );

   -------------------------------------------------------------------------------------
   -- Reset generation
   -------------------------------------------------------------------------------------

   -- 49.152542 MHz domain
   i_xpm_cdc_async_rst_main : xpm_cdc_async_rst
   generic map (
      RST_ACTIVE_HIGH => 1,
      DEST_SYNC_FF    => 6
   )
   port map (
      src_arst  => not main_locked,
      dest_clk  => main_clk_o,
      dest_arst => main_rst_o
   );

end architecture rtl;
