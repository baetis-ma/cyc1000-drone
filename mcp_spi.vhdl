library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_signed.all; 
use ieee.numeric_std.all;

entity mcp_spi is
   port (
           clk           : in     std_logic; 
           sw            : in     std_logic;
           --spi external signals
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
           spiregops     : in     std_logic_vector(15 downto 0) := x"0002";
           spiregwrite   : in     std_logic_vector(15 downto 0);
           spiregread    : buffer std_logic_vector(15 downto 0);
           spi_testout   : buffer std_logic_vector(7 downto 0) 
    );
end entity mcp_spi;


architecture behavioral of mcp_spi is
--define internal signals
type   state_machine         is (ready, reset0, reset1, setup, spireadb, spiwriteb, readdump);
signal seq_state           : state_machine := ready;
signal samplerate          : integer := 13; -- logbase2 of samplerate 1KHz ~= 10 min rate
                                            -- samplerate = 10->1khz,  15->32khx,  13->8khx
signal tau                 : integer := -1; -- logbase2 filter timeconstant 1sec ~= 0
signal taupp               : integer := -4; -- tau (filter time constant) 0=>1sec, -2=.25sec, -4=> 1/16hz
signal tauyaw              : integer :=  1;

signal spi_rate            : std_logic_vector(31 downto 0) := x"0000c350"; -- for 1KHz spi_strobe
signal zeros               : std_logic_vector(31 downto 0) := x"00000000";
signal lastsw              : std_logic;
signal calcnt              : std_logic_vector(15 downto 0) := x"0000";
signal busy_cnt            : std_logic_vector(7 downto 0);
signal spi_strobe          : std_logic := '0'; 
signal spi_delay0          : std_logic := '0'; 
signal spi_delay1          : std_logic := '0'; 
signal done                : std_logic;
signal spi_strobe_cnt      : std_logic_vector(31 downto 0);
signal tx_data             : std_logic_vector(7 downto 0);
signal busy                : std_logic;
signal busy_last           : std_logic;
signal rx_data             : std_logic_vector(7 downto 0);
signal continuous          : std_logic;
signal spi_mode            : std_logic_vector(3 downto 0);
signal accelx_off          : std_logic_vector(15 downto 0);
signal accely_off          : std_logic_vector(15 downto 0);
signal accelz_off          : std_logic_vector(15 downto 0);
signal gyrox_off           : std_logic_vector(15 downto 0);
signal gyroy_off           : std_logic_vector(15 downto 0);
signal gyroz_off           : std_logic_vector(15 downto 0);
signal gyroxint            : std_logic_vector(31 downto 0);
signal gyroxintp           : std_logic_vector(31 downto 0);
signal gyroyint            : std_logic_vector(31 downto 0);
signal gyroyintp           : std_logic_vector(31 downto 0);
signal gyrozint            : std_logic_vector(31 downto 0);
signal accelxint           : std_logic_vector(31 downto 0);
signal accelyint           : std_logic_vector(31 downto 0);
signal product             : std_logic_vector(31 downto 0);
 
--install components
component spi_master is
  generic(
    slaves  : integer := 2;  --number of spi slaves
    d_width : integer := 8); --data bus width
  port(
    clock   : in     std_logic;                            
    reset_n : in     std_logic;                            
    enable  : in     std_logic;                            
    cpol    : in     std_logic;                            
    cpha    : in     std_logic;                            
    cont    : in     std_logic;                            
    clk_div : in     integer;                              
    addr    : in     integer;                              
    tx_data : in     std_logic_VECTOR(d_width-1 downto 0); 
    miso    : in     std_logic;                            
    sclk    : buffer std_logic;                            
    ss_n    : buffer std_logic_VECTOR(slaves-1  downto 0); 
    mosi    : out    std_logic;                            
    busy    : out    std_logic;                            
    rx_data : out    std_logic_VECTOR(d_width-1 downto 0)   
  ); 
end component spi_master;

begin
--connect components
spi0: component spi_master
   port map (
    clock    =>  clk,          --system clock
    reset_n  =>  '1',          --asynchronous reset
    enable   =>  spi_delay1,   --initiate transaction
    cpol     =>  '1',          --spi clock polarity
    cpha     =>  '1',          --spi clock phase
    cont     =>  continuous,   --continuous mode command
    clk_div  =>  10,           -- 2.5MHz
    addr     =>  0,            --address of slave
    tx_data  =>  tx_data,      --data to transmit
  
    miso     =>  spi_miso,     --master in, slave out
    sclk     =>  spi_clk,      --spi clock
    ss_n     =>  spi_sel,      --slave select
    mosi     =>  spi_mosi,     --master out, slave in
    busy     =>  busy,         --busy / data ready signal
    rx_data  =>  rx_data       --data received
   );

spi_testout(7 downto 4) <= busy_cnt (3 downto 0);
spi_testout(3) <= spiregread(4);   
spi_testout(2) <= spiregread(3);   
spi_testout(1) <= spiregread(1);   
spi_testout(0) <= spiregread(0);   

gyroxhp   <= gyroxint(31 downto 16);
gyroxhpp  <= gyroxintp(31 downto 16);
gyroyhp   <= gyroyint(31 downto 16);
gyroyhpp  <= gyroyintp(31 downto 16);
gyrozhp   <= gyrozint(31 downto 16);
accelxlp  <= accelxint(31 downto 16) + accelx_off;
accelylp  <= accelyint(31 downto 16) + accely_off;
theta     <= accelylp + gyroxhp;
phi       <= accelxlp - gyroyhp;

process (clk)
begin
   if clk'event and clk='1' then
      --counts busy falling edges
      busy_last <= busy;
      spi_delay0 <= spi_strobe;
      spi_delay1 <= spi_delay0;

      --count done falling edge
      if busy ='0' and busy_last = '1' then 
         done <= '1';
      elsif done = '1' then
         done <= '0';
         busy_cnt <= busy_cnt + '1';   
      end if;
      
      --calibrate
      lastsw <= sw;
      if (sw = '1' and lastsw = '0') or calcnt /= x"0000" then
         if calcnt = x"0000" then calcnt <= x"0001"; end if; 
         if spi_strobe = '1' then calcnt <= calcnt + '1'; end if; 
         if       calcnt = x"0010" then spi_mode <= x"1";      --reset0 wait for 100msec
            elsif calcnt = x"0011" then spi_mode <= x"0";
            
            elsif calcnt = x"2010" then spi_mode <= x"3";      -- reset1 wait for 100msec 
            elsif calcnt = x"2011" then spi_mode <= x"0";
            
            elsif calcnt = x"4010" then spi_mode <= x"2";      -- setup
            elsif calcnt = x"4011" then spi_mode <= x"0"; 
            
            elsif calcnt = x"8010" then spi_mode <= x"4";      -- calibrate
            elsif calcnt = x"8011" then spi_mode <= x"0"; calcnt <=x"0000";
         end if;
      else
         spi_mode <= spiregops(3 downto 0);
      end if;

      case seq_state is
         when ready =>  
            busy_cnt <= x"00";
            continuous <= '1';                        
            if spi_strobe = '1' and calcnt = x"0000" then 
               case spi_mode is
                  when x"1" =>   seq_state <= reset0;
                  when x"2" =>   seq_state <= readdump;
                  when x"3" =>   seq_state <= setup;
                  when x"5" =>   seq_state <= reset1;
                  when x"6" =>   seq_state <= spireadb;
                  when x"7" =>   seq_state <= spiwriteb;
                  when others => seq_state <= ready;
               end case;     
            end if;
         when setup =>
            case busy_cnt is
               when x"00" => tx_data <= x"00" + x"1a";  --read=x80 write=x00 
               when x"01" => tx_data <= x"00";
               when x"02" => tx_data <= x"02";
               when x"03" => tx_data <= x"00";
               when x"04" => tx_data <= x"01";
                   continuous <= '0'; -- last in sequence
               when x"05"  => seq_state <= ready;
               when others => seq_state <= ready;      
            end case;
         when spireadb =>
            case busy_cnt is
               when x"00" => tx_data <= x"80" + spiregwrite(15 downto 8);  --read=x80 write=x00 
               when x"01" => 
                  tx_data <= x"00";
                  continuous <= '0'; -- last in sequence
                  if done = '1' then 
                     spiregread(15 downto 8) <= x"80" + spiregwrite(15 downto 8);
                     spiregread(7 downto 0)  <= rx_data; 
                  end if;
               when x"02"  => seq_state <= ready;
               when others => seq_state <= ready;      
            end case;
         when spiwriteb =>
            case busy_cnt is
               when x"00" => tx_data <= x"00" + spiregwrite(15 downto 8);  --read=x80 write=x00 
               when x"01" => 
                  tx_data <= x"00";
                  continuous <= '0'; -- last in sequence
                  if done = '1' then 
                     spiregread(15 downto 8) <= x"80" + spiregwrite(15 downto 8);
                     spiregread(7 downto 0)  <= spiregwrite(7 downto 0);
                  end if;
               when x"02"  => seq_state <= ready;
               when others => seq_state <= ready;      
            end case;
         when reset0 =>
            case busy_cnt is
               when x"00" => tx_data <= x"00" + x"6b";  --read=x80 write=x00 
               when x"01" => 
                  tx_data <= x"80";
                  continuous <= '0'; -- last in sequence
               when x"02"  => seq_state <= ready;
               when others => seq_state <= ready;      
            end case; 
         when reset1 =>
            case busy_cnt is
               when x"00" => tx_data <= x"00" + x"68";  --read=x80 write=x00 
               when x"01" => 
                  tx_data <= x"07";
                  continuous <= '0'; -- last in sequence
               when x"02"  => seq_state <= ready;
               when others => seq_state <= ready;      
            end case;             
         when readdump =>
            case busy_cnt is
               when x"00" => tx_data <= x"80" + x"3b";    --read=x80 write=x00           
               when x"01" => if done = '1' then accelx(15 downto 8) <= rx_data; end if;
               when x"02" => if done = '1' then accelx( 7 downto 0) <= rx_data; end if;
               when x"03" => if done = '1' then accely(15 downto 8) <= rx_data; end if;
               when x"04" => if done = '1' then accely( 7 downto 0) <= rx_data; end if;
               when x"05" => if done = '1' then accelz(15 downto 8) <= rx_data; end if;
               when x"06" => if done = '1' then accelz( 7 downto 0) <= rx_data; end if;
               when x"07" => if done = '1' then temper(15 downto 8) <= rx_data; end if;
               when x"08" => if done = '1' then temper( 7 downto 0) <= rx_data; end if;
               when x"09" => if done = '1' then gyrox (15 downto 8) <= rx_data; end if;
               when x"0a" => if done = '1' then gyrox ( 7 downto 0) <= rx_data; end if;
               when x"0b" => if done = '1' then gyroy (15 downto 8) <= rx_data; end if;
               when x"0c" => if done = '1' then gyroy ( 7 downto 0) <= rx_data; end if;
               when x"0d" => if done = '1' then gyroz (15 downto 8) <= rx_data; end if;    
               when x"0e" => if done = '1' then gyroz ( 7 downto 0) <= rx_data; end if;    
                             continuous <= '0';  -- last in sequence
               when x"0f" =>
                  busy_cnt <= x"10";  
                  -- add calibrate offset                  
                  gyrox  <= gyrox  + gyrox_off;
                  gyroy  <= gyroy  + gyroy_off;
                  gyroz  <= gyroz  + gyroz_off;
                  --accelx <= accelx + accelx_off;
                  --accely <= accely + accely_off;
                  --accelz <= accelz + accelz_off;
                when x"10" =>
                  busy_cnt  <= x"11";
                  -- gyro in shifted down by sample rate @ 1kHz should be down by 2^10, so 16 - 10 = 6
                  gyroxint  <= gyroxint  + (gyrox  & zeros(16-samplerate downto 0)); 
                  gyroxintp <= gyroxintp + (gyrox  & zeros(16-samplerate downto 0)); 
                  gyroyint  <= gyroyint  + (gyroy  & zeros(16-samplerate downto 0));                 
                  gyroyintp <= gyroyintp + (gyroy  & zeros(16-samplerate downto 0));                 
                  gyrozint  <= gyrozint  + (gyroz  & zeros(16-samplerate downto 0));                 
                  accelxint <= accelxint + (accelx & zeros(15-(samplerate + tau) downto 0));
                  accelyint <= accelyint + (accely & zeros(15-(samplerate + tau) downto 0));
                when x"11" =>
                  seq_state <= ready;
                  --1sec time contant would be same shift
                  gyroxint  <= gyroxint  - gyroxint(31 downto (samplerate + tau));   -- integrator times alpha 
                  gyroxintp <= gyroxintp - gyroxintp(31 downto (samplerate + taupp));   -- integrator times alpha 
                  gyroyint  <= gyroyint  - gyroyint(31 downto (samplerate + tau));                     
                  gyroyintp <= gyroyintp - gyroyintp(31 downto (samplerate + taupp));                     
                  gyrozint  <= gyrozint  - gyrozint(31 downto (samplerate + tauyaw));                     
                  accelxint <= accelxint - accelxint(31 downto (samplerate + tau));  -- subract out (1-alpha) of sum 
                  accelyint <= accelyint - accelyint(31 downto (samplerate + tau));                  
                when others =>
                  seq_state <= ready;
                -- gyroscope high pass filter
                      -- integration = alpha x integration + gyro reading x time between measurements
                      -- essentually integrating derivative of angle
                -- accelerometer low pass filter
                      -- sort of an average of last n samples; n=averaging time inteval/samples/sec
                      -- integrate add new accel to integrator shifted by tau (lp zero freq/num samples)
                      --    ex: 1Hz / 1KHz sample ~= 2^10 ; shift up by adding 16-10=6 zeros
            end case;
         when others =>
       end case;
       if spi_mode = x"4" then
          gyrox_off  <= x"0000" - gyrox;
          gyroy_off  <= x"0000" - gyroy;
          gyroz_off  <= x"0000" - gyroz;
          --may want to integrate raw data and use offset later to make cal possible
          accelx_off <= x"0000" - accelxint(31 downto 16);   -- -accelx;
          accely_off <= x"0000" - accelyint(31 downto 16);   -- -accely;
          --accelx_off <= x"0000" - accelx;
          --accely_off <= x"0000" - accely;          
          accelz_off <= x"0000" - accelz;
          gyroxint   <= x"00000000";
          gyroxintp  <= x"00000000";
          gyroyint   <= x"00000000";
          gyroyintp  <= x"00000000";
          gyrozint   <= x"00000000";
          --accelxint  <= x"00000000";
          --accelyint  <= x"00000000";
       end if;
    end if;
end process;

process (clk)
begin
   if clk'event and clk = '1' then
      --if spi_strobe_cnt < x"00000675" then  -- 32khz
      if spi_strobe_cnt < spi_rate(31 downto samplerate-10) then  -- 1khz   
      --if spi_strobe_cnt < x"00bebc20" then  -- 1/4 sec
      --if spi_strobe_cnt < x"02faf080" then  -- 1sec
      --if spi_strobe_cnt < x"3b9aca00" then    --20sec
         spi_strobe_cnt <= spi_strobe_cnt + '1';
         spi_strobe <= '0';
      else
         spi_strobe_cnt <= x"00000000";
         spi_strobe <= '1';
      end if;
   end if;
end process;

end behavioral;
