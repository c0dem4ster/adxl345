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

  type adxl_state_type is (s_startup_cmd, s_startup_dat, s_sampling_cmd, s_sampling_dat, s_pause);
  type spi_state_type is (s_write, s_read, s_idle);

  -- write register power_ctl (0x2d)
  constant spi_cmd_write: std_logic_vector(7 downto 0) := "00101101";
  constant spi_dat_write: std_logic_vector(7 downto 0) := "00001000";
  -- read register datax0 (0x32)
  constant spi_cmd_read: std_logic_vector(7 downto 0) := "10110011";
  constant spi_clk_div: natural := 500;

  signal spi_state: spi_state_type;
  signal spi_counter: natural range 0 to spi_clk_div;
  signal spi_pulse: std_logic := '0';
  signal spi_sclk: std_logic := '0';
  signal spi_sclk_dis: std_logic := '1';
  signal spi_cmd: std_logic_vector(7 downto 0);
  signal spi_fin: std_logic := '0';
  signal current_bit: natural range 0 to 7;

  signal adxl_state: adxl_state_type;
  signal idle_counter: natural range 0 to 10000;

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

  GSENSOR_SCLK <= spi_sclk or spi_sclk_dis;

  -- divide 50MHz to 1 MHz
  CLK_DIV: process(CLK, nRST)
  begin
    if(nRST = '0') then
      spi_counter <= 0;
      spi_pulse <= '0';
      spi_sclk <= '1';
    elsif(rising_edge(CLK)) then
      if(spi_counter = spi_clk_div) then
        spi_counter <= 0;
        spi_sclk <= not spi_sclk;
        spi_pulse <= spi_sclk;
      else
        spi_counter <= spi_counter + 1;
        spi_pulse <= '0';
      end if;
    end if;
  end process CLK_DIV;

  READ_ADXL: process(CLK, nRST)
  begin
    if(nRST = '0') then
      spi_state <= s_idle;
      spi_sclk_dis <= '1';
      adxl_state <= s_startup_cmd;
      idle_counter <= 0;
      GSENSOR_CS_N <= '1';
    elsif(rising_edge(CLK)) then
      case adxl_state is

        when s_startup_cmd =>
          if(spi_fin = '0') then
            GSENSOR_CS_N <= '0';
            spi_sclk_dis <= '0';
            if(spi_pulse = '1') then
              spi_state <= s_write;
              spi_cmd <= spi_cmd_write;
            end if;
          else
            adxl_state <= s_startup_dat;
          end if;

        when s_startup_dat =>
          if(current_bit = 0 and spi_counter = 0) then
            spi_sclk_dis <= '1';
          end if;
          if(spi_fin = '0') then
            spi_state <= s_write;
            spi_cmd <= spi_dat_write;
          else
            adxl_state <= s_pause;
            GSENSOR_CS_N <= '1';
          end if;

        when s_sampling_cmd =>
          if(spi_fin = '0') then
            GSENSOR_CS_N <= '0';
            spi_sclk_dis <= '0';
            if(spi_pulse = '1') then
              spi_state <= s_write;
              spi_cmd <= spi_cmd_read;
            end if;
          else
            adxl_state <= s_sampling_dat;
          end if;

        when s_sampling_dat =>
          if(current_bit = 0 and spi_counter = 0) then
            spi_sclk_dis <= '1';
          end if;
          if(spi_fin = '0') then
            spi_state <= s_read;
          else
            adxl_state <= s_pause;
            GSENSOR_CS_N <= '1';
          end if;

        when s_pause =>
          spi_state <= s_idle;
          if(idle_counter /= 10000) then
            idle_counter <= idle_counter + 1;
          else
            idle_counter <= 0;
            adxl_state <= s_sampling_cmd;
          end if;
      end case;
    end if;
  end process;


  -- coordinate r/w access to the bus
  CTRL_SPI: process(CLK, nRST)
  begin
    if(nRST = '0') then
      spi_fin <= '0';
      current_bit <= 7;
    elsif(rising_edge(CLK)) then
      case spi_state is
        when s_write | s_read =>
          spi_fin <= '0';
          if(spi_pulse = '1') then
            if(current_bit /= 0) then
              current_bit <= current_bit - 1;
            else
              current_bit <= 7;
              spi_fin <= '1';
            end if;
          end if;
        when s_idle =>
          null;
      end case;
    end if;
  end process CTRL_SPI;

  WRITE_SPI: process(CLK, nRST)
  begin
    if(rising_edge(CLK) and spi_state = s_write) then
      GSENSOR_SDI <= spi_cmd(current_bit);
    end if;
  end process WRITE_SPI;

  READ_SPI: process(CLK, nRST)
  begin
    if(rising_edge(CLK) and spi_state = s_read) then
      LEDR(current_bit) <= GSENSOR_SDO;
    end if;
  end process READ_SPI;
  --=====================================================================================================
end rtl;
