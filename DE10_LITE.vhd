------------------------------------------------------------------------------------
-- Project : adxl345
-- Author  : Theodor Fragner (theodor[at]fragner.org)
-- Date    : 09.11.2020
-- File    : DE10_Lite.vhd
-- Design  : Terasic DE10 Board
------------------------------------------------------------------------------------
-- Description: communicate with accelerometer on de10-lite board
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

use work.DE10_Lite_const_pkg.ALL;

--=======================================================================================================
entity DE10_Lite is
  port (
        MAX10_CLK1_50 :  in std_logic;
        ---------------------------------------------------------------
        KEY           :  in std_logic_vector(    keys_c - 1 downto 0);
        SW            :  in std_logic_vector(switches_c - 1 downto 0);
        LEDR          : out std_logic_vector(    leds_c - 1 downto 0);
        ---------------------------------------------------------------
        GSENSOR_CS_N  : out std_logic;
        GSENSOR_INT   :  in std_logic_vector(2 downto 1);
        GSENSOR_SCLK  : out std_logic;
        GSENSOR_SDI   : out std_logic;
        GSENSOR_SDO   :  in std_logic;
        GPIO          : out std_logic_vector(35 downto 0)
        ---------------------------------------------------------------
       );
end DE10_Lite;
--=======================================================================================================

architecture rtl of DE10_Lite is
  --=====================================================================================================
  alias CLK: std_logic is MAX10_CLK1_50;
  alias nRST: std_logic is KEY(0);

  type adxl_state_type is (s_startup, s_sampling, s_pause);

  -- write register power_ctl (0x2d) <= 0x08 (reverse bit order)
  constant spi_cmd_write: std_logic_vector(7 downto 0) := "10110100";
  constant spi_dat_write: std_logic_vector(7 downto 0) := "00010000";

  -- read register datax0 (0x32) (reverse bit order)
  constant spi_cmd_read:    std_logic_vector(7 downto 0) := "01001101";
  constant idle_count_max:  natural := 1000;

  signal spi_start:     std_logic;
  signal spi_fin:       std_logic;
  signal spi_cmd:       std_logic_vector(7 downto 0);
  signal spi_dat:       std_logic_vector(7 downto 0);

  signal adxl_state: adxl_state_type;
  signal idle_counter: natural range 0 to idle_count_max;

  --=====================================================================================================
begin
  --=====================================================================================================
  -- SCLK (p.15):
  --    max 5MHz (1.6MHz)
  --    normally '1'
  --    sampling at rising edge
  --    1st bit: 0=w / 1=r
  -- register map (p.22):
  --    0x31 data_format
  --    0x32 datax0
  --    0x33 datax1

  I_SPI:  entity work.spi(rtl) port map (
    CLK         => CLK,
    nRST        => nRST,
    CS_N        => GSENSOR_CS_N,
    SCLK        => GSENSOR_SCLK,
    MOSI        => GSENSOR_SDI,
    MISO        => GSENSOR_SDO,
    spi_start   => spi_start,
    spi_fin     => spi_fin,
    spi_cmd     => spi_cmd,
    spi_dat_in  => spi_dat,
    spi_dat_out => LEDR(7 downto 0)
  );

  READ_ADXL: process(CLK, nRST)
  begin
    if(nRST = '0') then
      spi_start <= '1';
      adxl_state <= s_startup;
      idle_counter <= 0;
    elsif(rising_edge(CLK)) then
      case adxl_state is

        when s_startup =>
          spi_start <= '0';
          spi_cmd <= spi_cmd_write;
          spi_dat <= spi_dat_write;

          if(spi_fin = '1') then
            adxl_state <= s_pause;
          end if;

        when s_sampling =>
          spi_start <= '0';
          spi_cmd <= spi_cmd_read;

          if(spi_fin = '1') then
            adxl_state <= s_pause;
          end if;

        when s_pause =>
          if(idle_counter /= idle_count_max) then
            idle_counter <= idle_counter + 1;
          else
            idle_counter <= 0;
            adxl_state <= s_sampling;
            spi_start <= '1';
          end if;
      end case;
    end if;
  end process;
  --=====================================================================================================
end rtl;
