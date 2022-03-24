library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;


entity direction is
generic (
  esc_rate      : integer := 50;     --updates per second
  )
port (
  clk           : in     std_logic;
  clk_1usec     : in     std_logic;
  control       : in     std_logic_vector(15 downto 0);
  status        : in     std_logic_vector(15 downto 0);
  throttle      : in     std_logic_vector(15 downto 0);
  yaw           : in     std_logic_vector(15 downto 0);
  pitch         : in     std_logic_vector(15 downto 0);
  roll          : in     std_logic_vector(15 downto 0);

  theta         : in     std_logic_vector(15 downto 0);
  phi           : in     std_logic_vector(15 downto 0);

  --pid loop gains
  githeta       : in     signed(15 downto 0);
  gptheta       : in     signed(15 downto 0);
  gdtheta       : in     signed(15 downto 0);
  giphi         : in     signed(15 downto 0);
  gpphi         : in     signed(15 downto 0);
  gdphi         : in     signed(15 downto 0);
  intmax        : in     signed(15 downto 0);
  intclear      : in     std_logic;
  motormax      : in     std_logic_vector(15 downto 0);

  altitude_prog : in     signed(15 downto 0);
  heading_prog  : in     signed(15 downto 0);
  altitude      : in     signed(15 downto 0);
  heading       : in     signed(15 downto 0);

  motor1        : buffer std_logic_vector(15 downto 0);
  motor2        : buffer std_logic_vector(15 downto 0);
  motor3        : buffer std_logic_vector(15 downto 0);
  motor4        : buffer std_logic_vector(15 downto 0); 

  strobe_esc    : buffer std_logic 
);
end entity direction;

architecture rtl of direction is
variable count         : integer range 0 to 1_000_000/esc_rate := 0;
signal  pidouttheta    : std_logic_vector(15 downto 0);
signal  pidoutphi      : std_logic_vector(15 downto 0);

signal  inttheta       : std_logic_vector(15 downto 0);
signal  lasttheta      : std_logic_vector(15 downto 0);
signal  intphi         : std_logic_vector(15 downto 0);
signal  lastphi        : std_logic_vector(15 downto 0);

begin

process (clk)
begin
   if clk'event and clk='1' then if count < 1000*esc_rate-1 then count := count + 1; else count := 0; end if;
end process;

process (clk)
begin
   if clk'event and clk='1' then
      if count = 0 then
         lasttheta <= theta;
         inttheta <= inttheta + theta;
         lastphi <= phi;
         intphi <= inttphi+ phi;
      elsif count = 1 then
      elsif count = 2 then
      elsif count = 3 then
      elsif count = 4 then
      elsif count = 5 then
      elsif count = 6 then
      elsif count = 7 then
         esc_strobe <= '1';
         motor1 <= throttle + yawadj + pitchadj + rolladj;
         motor2 <= throttle - yawadj + pitchadj - rolladj;
         motor3 <= throttle + yawadj - pitchadj - rolladj;
         motor4 <= throttle - yawadj + pitchadj + rolladj;
      elsif count = 8 then
         esc_strobe <= '0';
      end if;
   end if;
end process;

end architecture rtl;
