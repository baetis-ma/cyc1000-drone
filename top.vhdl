library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_signed.all; 
use IEEE.std_logic_ARITH.ALL;  
use ieee.numeric_std.ALL;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity top is port(
           clk_12mhz       : in     std_logic; 
           rst_n           : in     std_logic;
           tx_text         : buffer std_logic;
           rx_text         : in     std_logic; 

           mcp_spi_miso    : in     std_logic;
           mcp_spi_clk     : buffer std_logic;
           mcp_spi_sel     : buffer std_logic_vector( 1 downto 0);
           mcp_spi_mosi    : buffer std_logic;

           nrf_spi_miso    : in     std_logic;
           nrf_spi_clk     : buffer std_logic;
           nrf_spi_sel     : buffer std_logic;
           nrf_spi_mosi    : buffer std_logic;
           nrf_spi_ce      : buffer std_logic;

           sda             : inout  std_logic;           
           sck             : buffer std_logic;

           esc1            : buffer std_logic;
           esc2            : buffer std_logic;
           esc3            : buffer std_logic;
           esc4            : buffer std_logic;
    
           gps_rx          : in     std_logic;
           gps_tx          : buffer std_logic;
           
           batt_dc         : inout  std_logic;
           sw              : in     std_logic;
           led             : buffer std_logic_vector(7 downto 0);
           rate_1ms        : buffer std_logic; 
           clk_out         : buffer std_logic     
    );
end entity top;

architecture Behavioral of top is

--define internal signals
signal clk_50mhz           : std_logic;
signal clk_cntr            : std_logic_vector(15 downto 0) := x"0000";
signal clk_timer           : std_logic_vector(31 downto 0) := x"00000000";
signal testout             : std_logic_vector(7 downto 0);
signal regaddr             : std_logic_vector(7 downto 0);
signal regdataout          : std_logic_vector(15 downto 0);
signal regdatain           : std_logic_vector(15 downto 0);
signal regstrobe           : std_logic;
signal regdata00           : std_logic_vector(15 downto 0) := x"0002";
signal regdata01           : std_logic_vector(15 downto 0) := x"8001";
signal pwm_rate            : std_logic_vector(15 downto 0) := x"3c50";
signal pwm_counter         : std_logic_vector(15 downto 0) := x"0000";
signal pwm_cycle           : std_logic_vector(15 downto 0) := x"0100";
signal pwm                 : std_logic;
signal counter_1msec       : std_logic_vector(15 downto 0);
signal strobe_1msec        : std_logic;
signal counter_1usec       : std_logic_vector(7 downto 0);
signal strobe_1usec        : std_logic;
signal timer               : std_logic_vector(31 downto 0) := x"00000000";
signal gyrox               : std_logic_vector(15 downto 0);
signal gyroy               : std_logic_vector(15 downto 0);
signal gyroz               : std_logic_vector(15 downto 0);
signal gyroxhp             : std_logic_vector(15 downto 0);
signal gyroxhpp            : std_logic_vector(15 downto 0);
signal gyroyhp             : std_logic_vector(15 downto 0);
signal gyroyhpp            : std_logic_vector(15 downto 0);
signal gyrozhp             : std_logic_vector(15 downto 0);
signal temper              : std_logic_vector(15 downto 0);
signal accelx              : std_logic_vector(15 downto 0);
signal accely              : std_logic_vector(15 downto 0);
signal accelz              : std_logic_vector(15 downto 0);
signal accelxlp            : std_logic_vector(15 downto 0);
signal accelylp            : std_logic_vector(15 downto 0);
signal theta               : std_logic_vector(15 downto 0);
signal phi                 : std_logic_vector(15 downto 0);
signal magx                : std_logic_vector(15 downto 0);
signal magy                : std_logic_vector(15 downto 0);
signal magz                : std_logic_vector(15 downto 0);
signal spiregops           : std_logic_vector(15 downto 0) := x"0002";
signal spiregread          : std_logic_vector(15 downto 0);
signal spiregwrite         : std_logic_vector(15 downto 0);
signal spi_testout         : std_logic_vector(7 downto 0);
signal i2c_testout         : std_logic_vector(7 downto 0);
signal nrf_testout         : std_logic_vector(7 downto 0);
signal nack                : std_logic;
signal nack_cnt            : std_logic_vector(15 downto 0);
signal ack_cnt             : std_logic_vector(15 downto 0);
signal control             : std_logic_vector(15 downto 0);
signal altitude_prog       : std_logic_vector(15 downto 0);
signal heading_prog        : std_logic_vector(15 downto 0);
signal sda_in              : std_logic;
signal sda_out             : std_logic;
signal batt_dc_in          : std_logic;
signal batt_dc_out         : std_logic;
signal calibrate           : std_logic;
signal lastmagy            : std_logic_vector(7 downto 0);

signal githeta             : std_logic_vector(15 downto 0);
signal gptheta             : std_logic_vector(15 downto 0);
signal gdtheta             : std_logic_vector(15 downto 0);
signal giyaw               : std_logic_vector(15 downto 0);
signal gpyaw               : std_logic_vector(15 downto 0);
signal gdyaw               : std_logic_vector(15 downto 0);
signal intmax              : std_logic_vector(15 downto 0);
signal galtitude           : std_logic_vector(15 downto 0);
signal gheading            : std_logic_vector(15 downto 0);

signal rc_timer            : std_logic_vector(15 downto 0);
signal throttle            : std_logic_vector(15 downto 0) := x"03e8";
signal yaw                 : std_logic_vector(15 downto 0) := x"05dc";
signal pitch               : std_logic_vector(15 downto 0) := x"05dd";
signal roll                : std_logic_vector(15 downto 0) := x"05de";
signal rx_mode             : std_logic_vector(15 downto 0) := x"0000";

signal drone_timer         : std_logic_vector(15 downto 0);
signal height              : std_logic_vector(15 downto 0);
signal heading             : std_logic_vector(15 downto 0);
signal altitude            : std_logic_vector(15 downto 0);
signal displacement        : std_logic_vector(15 downto 0);
signal motor1              : std_logic_vector(15 downto 0);
signal motor2              : std_logic_vector(15 downto 0);
signal motor3              : std_logic_vector(15 downto 0);
signal motor4              : std_logic_vector(15 downto 0);
signal voltage             : std_logic_vector(15 downto 0);
signal rcout11             : std_logic_vector(15 downto 0);
signal rcout12             : std_logic_vector(15 downto 0);
signal rcout13             : std_logic_vector(15 downto 0);
signal rcout14             : std_logic_vector(15 downto 0);
signal rcout15             : std_logic_vector(15 downto 0); 
signal esc_period_cnt      : std_logic_vector(19 downto 0); 

--install components
component i2c is
    port(
          clk           : in     std_logic;
          rst_n         : in     std_logic;
          sda_in        : in     std_logic;
          sda_out       : buffer std_logic;
          scl           : buffer std_logic;
          magx          : buffer std_logic_vector(15 downto 0);
          magy          : buffer std_logic_vector(15 downto 0);
          magz          : buffer std_logic_vector(15 downto 0);
          heading       : buffer std_logic_vector(15 downto 0);
          altitude      : buffer std_logic_vector(15 downto 0);
          nack          : buffer std_logic;
          nack_cnt      : out    std_logic_vector(15 downto 0);
          ack_cnt       : out    std_logic_vector(15 downto 0);
          calibrate     : in     std_logic;
          i2c_testout   : buffer std_logic_vector(7 downto 0)
      );
end component i2c;

component mcp_spi is
   port (
          clk           : in     std_logic;
          sw            : in     std_logic;
          spi_miso      : in     std_logic;
          spi_clk       : buffer std_logic;
          spi_sel       : buffer std_logic_vector( 1 downto 0);
          spi_mosi      : buffer std_logic;
          accelx        : buffer std_logic_vector(15 downto 0);
          accely        : buffer std_logic_vector(15 downto 0);
          accelz        : buffer std_logic_vector(15 downto 0);
          temper        : buffer std_logic_vector(15 downto 0);
          gyrox         : buffer std_logic_vector(15 downto 0);
          gyroy         : buffer std_logic_vector(15 downto 0);
          gyroz         : buffer std_logic_vector(15 downto 0);
          gyroxhp       : buffer std_logic_vector(15 downto 0);
          gyroxhpp      : buffer std_logic_vector(15 downto 0);
          gyroyhp       : buffer std_logic_vector(15 downto 0);
          gyroyhpp      : buffer std_logic_vector(15 downto 0);
          gyrozhp       : buffer std_logic_vector(15 downto 0);
          accelxlp      : buffer std_logic_vector(15 downto 0);
          accelylp      : buffer std_logic_vector(15 downto 0);
          theta         : buffer std_logic_vector(15 downto 0);
          phi           : buffer std_logic_vector(15 downto 0);
          spiregops     : in     std_logic_vector(15 downto 0);
          spiregread    : buffer std_logic_vector(15 downto 0);
          spiregwrite   : in     std_logic_vector(15 downto 0);
          spi_testout   : buffer std_logic_vector(7 downto 0)
    );
end component mcp_spi;

component nrf_spi is
   port (
          clk           : in     std_logic; 
          strobe_1usec  : in     std_logic;
          sw            : in     std_logic;
          --spi external signals
          nrf_miso      : in     std_logic := '0';
          nrf_clk       : buffer std_logic := '0';
          nrf_sel       : buffer std_logic := '0';
          nrf_mosi      : buffer std_logic := '0';
          nrf_ce        : buffer std_logic := '0';

          rc_timer      : buffer std_logic_vector(15 downto 0);
          throttle      : buffer std_logic_vector(15 downto 0);
          yaw           : buffer std_logic_vector(15 downto 0);
          pitch         : buffer std_logic_vector(15 downto 0);
          roll          : buffer std_logic_vector(15 downto 0);
          rx_mode       : buffer std_logic_vector(15 downto 0);

          drone_timer   : in     std_logic_vector(15 downto 0);
          height        : in     std_logic_vector(15 downto 0);
          heading       : in     std_logic_vector(15 downto 0);
          displacement  : in     std_logic_vector(15 downto 0);
          theta         : in     std_logic_vector(15 downto 0);
          phi           : in     std_logic_vector(15 downto 0);
          motor1        : in     std_logic_vector(15 downto 0);
          motor2        : in     std_logic_vector(15 downto 0);
          motor3        : in     std_logic_vector(15 downto 0);
          motor4        : in     std_logic_vector(15 downto 0);
          voltage       : in     std_logic_vector(15 downto 0);
          rcout11       : in     std_logic_vector(15 downto 0);
          rcout12       : in     std_logic_vector(15 downto 0);
          rcout13       : in     std_logic_vector(15 downto 0);
          rcout14       : in     std_logic_vector(15 downto 0);
          rcout15       : in     std_logic_vector(15 downto 0); 
          testout       : buffer std_logic_vector(7 downto 0) 
    );
end component nrf_spi;

component textinterface is
    port (
          clk            : in     std_logic;
          tx             : buffer std_logic;
          rx             : in     std_logic; 
          regaddr        : buffer std_logic_vector(7 downto 0);
          regdataout     : in     std_logic_vector(15 downto 0);
          regdatain      : buffer std_logic_vector(15 downto 0);
          regstrobe      : buffer std_logic := '0';
          testout        : buffer std_logic_vector(7 downto 0)
    );
end component textinterface;

component voltmeter is
    port (
          clk           : in     std_logic;
          strobe_1usec  : in     std_logic;
          batt_dc_in    : in     std_logic;
          batt_dc_out   : buffer std_logic;
          voltage       : buffer std_logic_vector(15 downto 0)
);
end component voltmeter;

component pll is
    port (
          clk_clk        : in  std_logic := 'X'; -- clk
          reset_reset_n  : in  std_logic := 'X'; -- reset_n
          pll_clk        : out std_logic         -- clk
    );
end component pll;

begin
--connect components
i2c0: component i2c 
     port map (
          clk            => clk_50mhz,
          rst_n          => '0',
          sda_out        => sda_out,
          sda_in         => sda_in,
          scl            => sck,
          magx           => magx,
          magy           => magy,
          magz           => magz,
          heading        => heading,
          altitude       => altitude,
          nack           => nack,
          nack_cnt       => nack_cnt, 
          ack_cnt        => ack_cnt,
          calibrate      => calibrate,
          i2c_testout    => i2c_testout
     );

spi0 : component mcp_spi
    port map (
           clk           => clk_50mhz,
           sw            => sw,
           spi_miso      => mcp_spi_miso,
           spi_clk       => mcp_spi_clk,
           spi_sel       => mcp_spi_sel,
           spi_mosi      => mcp_spi_mosi,
           accelx        => accelx,
           accely        => accely,
           accelz        => accelz,
           temper        => temper,
           gyrox         => gyrox,
           gyroy         => gyroy,
           gyroz         => gyroz,
           gyroxhp       => gyroxhp,
           gyroxhpp      => gyroxhpp,
           gyroyhp       => gyroyhp,
           gyroyhpp      => gyroyhpp,
           gyrozhp       => gyrozhp,
           accelxlp      => accelxlp,
           accelylp      => accelylp,
           theta         => theta,
           phi           => phi,
           spiregops     => spiregops,
           spiregread    => spiregread,
           spiregwrite   => spiregwrite,
           spi_testout   => spi_testout
    );
    
spi1 : component nrf_spi
    port map (
          clk            => clk_50mhz,
          strobe_1usec   => strobe_1usec,
          sw             => sw,
          --spi external signals
          nrf_miso       => nrf_spi_miso,
          nrf_clk        => nrf_spi_clk,
          nrf_sel        => nrf_spi_sel,
          nrf_mosi       => nrf_spi_mosi,
          nrf_ce         => nrf_spi_ce,

          rc_timer       => rc_timer,
          throttle       => throttle,
          yaw            => yaw,
          pitch          => pitch,
          roll           => roll,
          rx_mode        => rx_mode,

          drone_timer    => drone_timer,
          height         => height,
          heading        => heading,
          displacement   => displacement,
          theta          => theta,
          phi            => phi, 
          motor1         => motor1,
          motor2         => motor2,
          motor3         => motor3,
          motor4         => motor4,
          voltage        => voltage,
          rcout11        => rcout11,
          rcout12        => rcout12,
          rcout13        => rcout13,
          rcout14        => rcout14,
          rcout15        => rcout15,
          testout        => nrf_testout 
    );

textinterface0: component textinterface 
    port map (
           clk           => clk_50mhz,
           tx            => tx_text,
           rx            => rx_text,
           regaddr       => regaddr,
           regdataout    => regdataout,
           regdatain     => regdatain,
           regstrobe     => regstrobe,
           testout       => testout
    );
    
voltmeter0: component voltmeter
    port map (
          clk            => clk_50mhz,
          strobe_1usec   => strobe_1usec,
          batt_dc_in     => batt_dc_in,
          batt_dc_out    => batt_dc_out,
          voltage        => voltage
    );

pll0 : component pll
    port map (
          clk_clk        => clk_12mhz,
          reset_reset_n  => '1', 
          pll_clk        => clk_50mhz
    );

--connect inout wires 
sda <= 'Z' when sda_out = '1' else '0';
sda_in <= sda;
batt_dc <= 'Z' when batt_dc_out = '1' else '0';
batt_dc_in <= batt_dc;

clk_out <= clk_50mhz;
led <= x"00" when pwm = '0' else yaw(9 downto 2);
--led <= x"00" when pwm = '0' else nrf_testout;
--led <= x"00" when pwm = '0' else esc_period_cnt(16 downto 9);


--run some processes
rate_1ms <= '1' when clk_cntr = x"0000" else '0';
process(clk_50mhz)
   begin
       if clk_50mhz'event and clk_50mhz='1' then
          clk_cntr <= clk_cntr + '1';
            if clk_cntr >= x"c350" then   
               clk_cntr <= x"0000";
               clk_timer <= clk_timer + x"00000001";
            end if;
       end if;
end process;

--chip register files
regdataout <= regdata00             when regaddr = x"00" else
              regdata01             when regaddr = x"01" else
              control               when regaddr = x"10" else
              spiregops             when regaddr = x"20" else
              spiregread            when regaddr = x"21" else
              spiregwrite           when regaddr = x"22" else
              gyrox                 when regaddr = x"30" else
              gyroy                 when regaddr = x"31" else
              gyroz                 when regaddr = x"32" else
              gyroxhp               when regaddr = x"38" else
              gyroxhpp              when regaddr = x"39" else
              gyroyhp               when regaddr = x"3a" else              
              gyroyhpp              when regaddr = x"3b" else              
              gyrozhp               when regaddr = x"3c" else              
              accelx                when regaddr = x"40" else
              accely                when regaddr = x"41" else
              accelz                when regaddr = x"42" else
              accelxlp              when regaddr = x"48" else
              accelylp              when regaddr = x"49" else                
              theta                 when regaddr = x"50" else
              phi                   when regaddr = x"51" else
              magx                  when regaddr = x"60" else
              magy                  when regaddr = x"61" else
              magz                  when regaddr = x"62" else
              heading               when regaddr = x"63" else
              heading_prog          when regaddr = x"64" else
              altitude              when regaddr = x"65" else
              altitude_prog         when regaddr = x"66" else
              githeta               when regaddr = x"70" else
              gptheta               when regaddr = x"71" else
              gdtheta               when regaddr = x"72" else
              giyaw                 when regaddr = x"73" else
              gpyaw                 when regaddr = x"74" else
              gdyaw                 when regaddr = x"75" else
              galtitude             when regaddr = x"76" else
              gheading              when regaddr = x"77" else
              intmax                when regaddr = x"78" else
              pwm_rate              when regaddr = x"90" else
              pwm_cycle             when regaddr = x"91" else
              nack_cnt              when regaddr = x"99" else
              ack_cnt               when regaddr = x"9a" else 

              rc_timer              when regaddr = x"a0" else
              throttle              when regaddr = x"a1" else
              yaw                   when regaddr = x"a2" else
              pitch                 when regaddr = x"a3" else
              roll                  when regaddr = x"a4" else
              rx_mode               when regaddr = x"a5" else

              drone_timer           when regaddr = x"b0" else
              height                when regaddr = x"b1" else
              heading               when regaddr = x"b2" else
              displacement          when regaddr = x"b3" else
              theta                 when regaddr = x"b4" else
              phi                   when regaddr = x"b5" else
              motor1                when regaddr = x"b6" else
              motor2                when regaddr = x"b7" else
              motor3                when regaddr = x"b8" else
              motor4                when regaddr = x"b9" else
              voltage               when regaddr = x"ba" else
              rcout11               when regaddr = x"bb" else
              rcout12               when regaddr = x"bc" else
              rcout13               when regaddr = x"bd" else
              rcout14               when regaddr = x"be" else
              rcout15               when regaddr = x"bf" else

              timer(31 downto 16)   when regaddr = x"e0" else
              timer(15 downto 0)    when regaddr = x"e1" else              
              x"dead";
              


process(clk_50mhz)
begin
   if clk_50mhz'event and clk_50mhz='1' then
      if regstrobe = '1' then
         if regaddr = x"00" then regdata00   <= regdatain; end if;
         if regaddr = x"01" then regdata01   <= regdatain; end if;
         if regaddr = x"10" then control     <= regdatain; end if;
         if regaddr = x"20" then spiregops   <= regdatain; end if;
         if regaddr = x"22" then spiregwrite <= regdatain; end if;
         if regaddr = x"70" then githeta     <= regdatain; end if;
         if regaddr = x"71" then gptheta     <= regdatain; end if;
         if regaddr = x"72" then gdtheta     <= regdatain; end if;
         if regaddr = x"73" then giyaw       <= regdatain; end if;
         if regaddr = x"74" then gpyaw       <= regdatain; end if;
         if regaddr = x"75" then gdyaw       <= regdatain; end if;
         if regaddr = x"76" then galtitude   <= regdatain; end if;
         if regaddr = x"77" then gheading    <= regdatain; end if;
         if regaddr = x"79" then intmax      <= regdatain; end if;
         if regaddr = x"90" then pwm_rate    <= regdatain; end if;
         if regaddr = x"91" then pwm_cycle   <= regdatain; end if;
      end if;
      if regstrobe = '1' and regaddr = x"10" then calibrate <= '1'; 
      elsif sw = '0' then calibrate <= '1'; 
      else calibrate <= '0'; end if;
   end if;
end process;

process(clk_50mhz)
begin
   if clk_50mhz'event and clk_50mhz='1' then
      if counter_1usec = x"32" then 
         strobe_1usec <= '1';
         counter_1usec <= x"00";   
      else 
         strobe_1usec <= '0';      
         counter_1usec <= counter_1usec + '1';
      end if;
   end if;
end process;

process(clk_50mhz)
begin
   if clk_50mhz'event and clk_50mhz='1' then
      if counter_1msec = x"c350" then
         counter_1msec <= x"0000";   
         strobe_1msec <= '1'; 
      else 
         strobe_1msec <= '0'; 
         counter_1msec <= counter_1msec + '1'; 
      end if;
   end if;
end process;

process(clk_50mhz)
begin
   if clk_50mhz'event and clk_50mhz='1' then
      if strobe_1usec = '1' then
         if esc_period_cnt = x"0c350" then
            esc_period_cnt <= x"00000";   
         else 
            esc_period_cnt <= esc_period_cnt + '1'; 
         end if;
         if esc_period_cnt < (x"0" & throttle) then esc1 <= '1'; else esc1 <= '0'; end if;
         if esc_period_cnt < (x"0" & yaw     ) then esc2 <= '1'; else esc2 <= '0'; end if;
         if esc_period_cnt < (x"0" & pitch   ) then esc3 <= '1'; else esc3 <= '0'; end if;
         if esc_period_cnt < (x"0" & roll    ) then esc4 <= '1'; else esc4 <= '0'; end if;
      end if;
   end if;
end process;

pwm <= '1' when pwm_cycle > pwm_counter else '0';
process (strobe_1usec)
begin
   if strobe_1usec = '1' then
      pwm_counter <= pwm_counter + '1';
      if pwm_counter > pwm_rate then pwm_counter <= x"0000"; end if;
   end if;
end process;

process (clk_50mhz)
begin
   if clk_50mhz'event and clk_50mhz = '1' then   
      if strobe_1msec = '1' then timer <= timer + '1'; end if; 
   end if;
end process;

end Behavioral;
