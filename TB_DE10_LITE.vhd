------------------------------------------------------------------------------------
-- Project : adxl345
-- Author  : Theodor Fragner (theodor[at]fragner.org)
-- Date    : 09.11.2020
-- File    : TB_DE10_LITE.vhd
-- Design  : TB Terasic DE10 Board
------------------------------------------------------------------------------------
-- Description: test communicate with accelerometer on de10-lite board
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use work.DE10_Lite_const_pkg.ALL;

--=======================================================================================================
entity TB_DE10_Lite is
end TB_DE10_Lite;
--=======================================================================================================

architecture rtl of TB_DE10_Lite is
  --=====================================================================================================
  signal CLK: std_logic := '0';
  signal nRST: std_logic_vector(1 downto 0) := "00";
  --=====================================================================================================
begin
  --=====================================================================================================
  CLK <= not CLK after de10_cycle_time_c / 2;
  nRST <= not nRST after 1 ms;
  --=====================================================================================================
  I_DE10_Lite:  entity work.DE10_Lite(rtl) port map (
    MAX10_CLK1_50 => CLK,
    KEY => nRST,
    SW => (others => '0'),
    GSENSOR_INT  => (others => '0'),
    GSENSOR_SDO  => '0'
  );
end rtl;
