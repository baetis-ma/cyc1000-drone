library ieee;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_signed.all; 
use IEEE.std_logic_ARITH.ALL;  
use ieee.numeric_std.ALL;


entity voltmeter is
    port (
          clk           : in     std_logic;
          strobe_1usec  : in     std_logic;
          batt_dc_in    : in     std_logic;
          batt_dc_out   : buffer std_logic;
          voltage       : buffer std_logic_vector(15 downto 0)
);
end entity voltmeter;

architecture rtl of voltmeter is
signal  high_cnt      : std_logic_vector(15 downto 0) := x"0000";
signal  measure_cnt   : std_logic_vector(15 downto 0) := x"0000";

begin
batt_dc_out <= '0' when measure_cnt < x"03ef" else '1';

process (clk)
begin
   if clk'event and clk='1' and strobe_1usec = '1' then
      if measure_cnt < x"2710" then measure_cnt <= measure_cnt + '1'; 
      elsif measure_cnt = x"2710" then measure_cnt <= x"0000"; high_cnt <= x"0000"; voltage <= high_cnt; end if;
      if measure_cnt > x"03e8" and batt_dc_in = '1' then high_cnt <= high_cnt + '1'; end if; 
   end if;
end process;

end architecture rtl;
