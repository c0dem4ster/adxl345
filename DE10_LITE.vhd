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
        GSENSOR_CS_N  : buffer std_logic;
        GSENSOR_INT   :  in std_logic_vector(2 downto 1);
        GSENSOR_SCLK  : buffer std_logic;
        GSENSOR_SDI   : buffer std_logic;
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
  type spi_state_type is (s_cmd, s_dat, s_idle);

  -- write register power_ctl (0x2d) <= 0x08 (reverse bit order)
  constant spi_cmd_write: std_logic_vector(7 downto 0) := "10110100";
  constant spi_dat_write: std_logic_vector(7 downto 0) := "00010000";

  -- read register datax0 (0x32) (reverse bit order)
  constant spi_cmd_read:    std_logic_vector(7 downto 0) := "01001111";
  constant spi_clk_div_n:   natural := 50;
  constant idle_count_max:  natural := 1000;

  signal spi_state:     spi_state_type;
  signal spi_no_bits:   natural range 0 to 15;
  signal current_bit:   natural range 0 to 15;
  signal spi_counter:   natural range 0 to spi_clk_div_n;
  signal spi_start:     std_logic;
  signal spi_fin:       std_logic;
  signal spi_pulse_hi:  std_logic;
  signal spi_pulse_lo:  std_logic;
  signal spi_1st_pulse: std_logic;
  signal spi_sclk:      std_logic;
  signal spi_sclk_dis:  std_logic;
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

  GPIO(0) <= GSENSOR_CS_N;
  GPIO(1) <= GSENSOR_SCLK;
  GPIO(2) <= GSENSOR_SDI;
  GPIO(3) <= GSENSOR_SDO;
  GPIO(4) <= GSENSOR_SCLK;

  GSENSOR_SCLK <= spi_sclk or spi_sclk_dis;

  -- divide 50MHz to 1 MHz
  SPI_CLK_DIV: process(CLK, nRST)
  begin
    if(nRST = '0') then
      spi_counter <= 0;
      spi_pulse_lo <= '0';
      spi_pulse_hi <= '0';
      spi_sclk <= '1';
    elsif(rising_edge(CLK)) then
      if(spi_counter = spi_clk_div_n) then
        spi_counter <= 0;
        spi_sclk <= not spi_sclk;
        spi_pulse_lo <= spi_sclk;
        spi_pulse_hi <= not spi_sclk;
      else
        spi_counter <= spi_counter + 1;
        spi_pulse_lo <= '0';
        spi_pulse_hi <= '0';
      end if;
    end if;
  end process SPI_CLK_DIV;

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
          spi_no_bits <= 7;
          spi_cmd <= spi_cmd_write;
          spi_dat <= spi_dat_write;

          if(spi_fin = '1') then
            adxl_state <= s_pause;
          end if;

        when s_sampling =>
          spi_start <= '0';
          spi_no_bits <= 7;
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


  -- coordinate r/w access to the bus
  SPI_CTRL: process(CLK, nRST)
  begin
    if(nRST = '0') then
      spi_state <= s_idle;
      spi_fin <= '0';
      current_bit <= 0;
      spi_sclk_dis <= '1';
      GSENSOR_CS_N <= '1';
    elsif(rising_edge(CLK)) then
      case spi_state is

        when s_cmd =>
          GSENSOR_CS_N <= '0';
          spi_sclk_dis <= '0';
          if(spi_pulse_lo = '1') then
            if(spi_1st_pulse = '1') then
              spi_1st_pulse <= '0';
            elsif(current_bit /= spi_no_bits) then
              current_bit <= current_bit + 1;
            else
              current_bit <= 0;
              spi_state <= s_dat;
            end if;
          end if;

        when s_dat =>
          if(spi_pulse_lo = '1') then
            if(current_bit /= spi_no_bits) then
              current_bit <= current_bit + 1;
            else
              current_bit <= 0;
              spi_state <= s_idle;
              spi_fin <= '1';
              GSENSOR_CS_N <= '1';
              spi_sclk_dis <= '1';
            end if;
          end if;

        when s_idle =>
          spi_fin <= '0';
          if(spi_start = '1') then
            spi_state <= s_cmd;
            spi_1st_pulse <= '1';
          end if;

      end case;
    end if;
  end process SPI_CTRL;

  SPI_WRITE: process(CLK, nRST)
  begin
    if(rising_edge(CLK)) then
      if(spi_state = s_cmd) then
        GSENSOR_SDI <= spi_cmd(current_bit);
      elsif(spi_cmd(0) = '0' and spi_state /= s_idle) then
        GSENSOR_SDI <= spi_dat(current_bit);
      end if;
    end if;
  end process SPI_WRITE;

  SPI_READ: process(CLK, nRST)
  begin
    if(rising_edge(CLK) and spi_pulse_hi = '1') then
      if(spi_cmd(0) = '1' and spi_state = s_dat) then
        LEDR(current_bit) <= GSENSOR_SDO;
      end if;
    end if;
  end process SPI_READ;
  --=====================================================================================================
end rtl;
