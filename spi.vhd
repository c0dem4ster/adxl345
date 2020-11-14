------------------------------------------------------------------------------------
-- Project : adxl345
-- Author  : Theodor Fragner (theodor[at]fragner.org)
-- Date    : 09.11.2020
-- File    : spi.vhd
-- Design  : SPI master
------------------------------------------------------------------------------------
-- Description: implementation of the adxl345 spi protocol
------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

--=======================================================================================================
entity SPI is
  port (
        CLK           :  in std_logic;
        nRST          :  in std_logic;
        ----------------------------------------------------
        CS_N          : out std_logic;
        SCLK          : out std_logic;
        MOSI          : out std_logic;
        MISO          :  in std_logic;
        ----------------------------------------------------
        spi_start     :  in std_logic;
        spi_fin       : out std_logic;
        spi_cmd       :  in std_logic_vector(7 downto 0);
        spi_dat_in    :  in std_logic_vector(7 downto 0);
        spi_dat_out   : out std_logic_vector(15 downto 0)
       );
end SPI;
--=======================================================================================================

architecture rtl of SPI is
  --=====================================================================================================
  type spi_state_type is (s_cmd, s_dat, s_idle);

  constant spi_no_bits:   natural := 7;
  constant spi_clk_div_n: natural := 50;

  signal spi_state:     spi_state_type;
  signal current_bit:   natural range 0 to 15;
  signal spi_counter:   natural range 0 to spi_clk_div_n;
  signal spi_pulse_hi:  std_logic;
  signal spi_pulse_lo:  std_logic;
  signal spi_1st_pulse: std_logic;
  signal spi_sclk:      std_logic;
  signal spi_sclk_dis:  std_logic;

  --=====================================================================================================
begin
  --=====================================================================================================

  SCLK <= spi_sclk or spi_sclk_dis;

  -- divide system clock to bus clock
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

  -- coordinate r/w access to the bus
  SPI_CTRL: process(CLK, nRST)
  begin
    if(nRST = '0') then
      spi_state <= s_idle;
      spi_fin <= '0';
      current_bit <= 0;
      spi_sclk_dis <= '1';
      CS_N <= '1';
    elsif(rising_edge(CLK)) then
      case spi_state is

        when s_cmd =>
          CS_N <= '0';
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
            if((current_bit /= 7 and spi_cmd(1) = '0') or (current_bit /= 15 and spi_cmd(1) = '1')) then
              current_bit <= current_bit + 1;
            else
              current_bit <= 0;
              spi_state <= s_idle;
              spi_fin <= '1';
              CS_N <= '1';
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
        MOSI <= spi_cmd(current_bit);
      elsif(spi_cmd(0) = '0' and spi_state /= s_idle) then
        MOSI <= spi_dat_in(current_bit);
      end if;
    end if;
  end process SPI_WRITE;

  SPI_READ: process(CLK, nRST)
  begin
    if(rising_edge(CLK) and spi_pulse_hi = '1') then
      if(spi_cmd(0) = '1' and spi_state = s_dat) then
        spi_dat_out(current_bit) <= MISO;
      end if;
    end if;
  end process SPI_READ;
  --=====================================================================================================
end rtl;
