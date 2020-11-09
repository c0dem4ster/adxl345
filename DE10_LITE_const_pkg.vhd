------------------------------------------------------------------------------------
-- Project : adxl345
-- Author  : Theodor Fragner (theodor[at]fragner.org)
-- Date    : 09.11.2020
-- File    : DE10_Lite_const_pkg.vhd
-- Design  : Terasic DE10 Board
------------------------------------------------------------------------------------
-- Description: Type- and Constant Definitions for Terasic DE10 Board
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
--==================================================================================
package DE10_Lite_const_pkg is
  ----------------------------------------------------------------------------------
  -- DE10 50MHz Clock
  constant de10_clk_freq_c   : real := 50.0E6;
  -- DE10 Cycle Time
  constant de10_cycle_time_c : time := 1.0 sec / de10_clk_freq_c;
  ----------------------------------------------------------------------------------
  -- number of leds
  constant leds_c     : natural := 10;
  -- number of 7-Segment displays
  constant digits_c   : natural :=  6;
  -- number of switches
  constant switches_c : natural := 10;
  -- number of buttons
  constant keys_c     : natural :=  2;
  ----------------------------------------------------------------------------------
  -- display interface
  subtype disp_type is std_logic_vector(6 downto 0);
  type disp_array_type is array (0 to 15) of disp_type;
  constant disp_array_c : disp_array_type := (("0111111"),  -- 0
                                              ("0000110"),  -- 1
                                              ("1011011"),  -- 2
                                              ("1001111"),  -- 3
                                              ("1100110"),  -- 4
                                              ("1101101"),  -- 5
                                              ("1111101"),  -- 6
                                              ("0000111"),  -- 7
                                              ("1111111"),  -- 8
                                              ("1101111"),  -- 9
                                              ("1110111"),  -- A
                                              ("1111100"),  -- b
                                              ("0111001"),  -- C
                                              ("1011110"),  -- d
                                              ("1111001"),  -- E
                                              ("1110001")); -- F
  ----------------------------------------------------------------------------------
  -- RGB_DAC Resolution
  constant rgb_dac_c       : natural := 4;
  constant vga_color_depth : natural := 3 * rgb_dac_c;
  ----------------------------------------------------------------------------------
end DE10_Lite_const_pkg;
--==================================================================================
