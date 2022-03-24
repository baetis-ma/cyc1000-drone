library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity direction is
port (
  clk      : in  std_logic;
  magx     : in  signed(15 downto 0);
  magy     : in  signed(15 downto 0);
  heading  : buffer signed(15 downto 0)
);
end entity direction;

architecture rtl of direction is
signal  xoff    : signed(15 downto 0) := x"0001";
signal  yoff    : signed(15 downto 0) := x"0002";
signal  amagx   : signed(15 downto 0);
signal  amagy   : signed(15 downto 0);
signal  degrees : signed(15 downto 0);
signal  degi_ix : signed(15 downto 0);

begin


process (clk)
begin
   if clk'event and clk='1' then
	   --get absolute values
      if magx < x"0000" then amagx <= x"0000" - magx; else amagx <= magx; end if;
      if magy < x"0000" then amagy <= x"0000" - magy; else amagy <= magy; end if;	
      --degrees quadrant I lookup
		if       amagx                   > amagy & "000"            then degrees <= x"0004"; --  4 degrees 
         elsif amagx                   > amagy & "00"             then degrees <= x"000b"; -- 11 degrees
         elsif amagx                   > amagy & "0"              then degrees <= x"0014"; -- 20 degrees
         elsif amagx & "0"             > amagy & "00" - amagy     then degrees <= x"001e"; -- 30 degrees
         elsif amagx                   > amagy                    then degrees <= x"0028"; -- 40 degrees
         elsif amagx & "00" - amagx    > amagy & "0"              then degrees <= x"0032"; -- 50 degrees
         elsif amagx & "0"             > amagy                    then degrees <= x"003c"; -- 60 degrees
         elsif amagx & "00"            > amagy                    then degrees <= x"0046"; -- 70 degrees
         elsif amagx & "000"           > amagy                    then degrees <= x"004f"; -- 79 degrees
         else                                                          degrees <= x"0056"; -- 86 degrees
      end if;
		--rest of quadrants
      if       magx >= x"0000" and magy >= x"0000" then degi_ix <=           degrees;
		   elsif magx <  x"0000" and magy >= x"0000" then degi_ix <= x"00b4" - degrees;  --180-
         elsif magx <  x"0000" and magy <  x"0000" then degi_ix <= x"00b4" + degrees;  --180+
         elsif magx >= x"0000" and magy <  x"0000" then degi_ix <= x"0168" - degrees;  --360-
      end if;
		
		heading <= x"0168" - degi_ix;

   end if;
end process;

end architecture rtl;
