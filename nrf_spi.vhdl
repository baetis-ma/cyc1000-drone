library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_signed.all; 
use ieee.numeric_std.all;

entity nrf_spi is
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
end entity nrf_spi;


architecture behavioral of nrf_spi is
--define internal signals
type   state_machine         is (ready, test, calib, transmit, rx_setup, rx_wait, rx_poll, rx_read );
signal seq_state           : state_machine := calib;

signal count_1usec         : std_logic_vector(15 downto 0);
signal count_wait          : std_logic_vector(15 downto 0);
signal busy_cnt            : std_logic_vector(7 downto 0);
signal spi_transact        : std_logic;
signal transact            : std_logic;
signal continuous          : std_logic;
signal busy                : std_logic;
signal busy_last           : std_logic;
signal rx_data             : std_logic_vector(7 downto 0);
signal rx_data_strobe      : std_logic_vector(7 downto 0);
signal tx_data             : std_logic_vector(7 downto 0);
signal nrf_sel_cnt         : std_logic_vector(11 downto 0);
signal spi_testout         : std_logic_vector(7 downto 0);

--install components
component spi_master is
  generic(
    slaves  : integer := 1;  --number of spi slaves
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
    ss_n    : buffer std_logic; 
    mosi    : out    std_logic;                            
    busy    : out    std_logic;                            
    rx_data : out    std_logic_VECTOR(d_width-1 downto 0)   
  ); 
end component spi_master;

begin
--connect components
spi1: component spi_master
   port map (
    clock    =>  clk,          --system clock
    reset_n  =>  '1',          --asynchronous reset
    enable   =>  transact,     --initiate transaction
    cpol     =>  '0',          --spi clock polarity
    cpha     =>  '0',          --spi clock phase
    cont     =>  continuous,   --continuous mode command
    clk_div  =>  625,          -- 50KHz
    --clk_div  =>  1250,          -- 50KHz
    addr     =>  0,            --address of slave
    tx_data  =>  tx_data,      --data to transmit
  
    miso     =>  nrf_miso,     --master in, slave out
    sclk     =>  nrf_clk,      --spi clock
    ss_n     =>  open,     --nrf_sel,      --slave select
    mosi     =>  nrf_mosi,     --master out, slave in
    busy     =>  busy,         --busy / data ready signal
    rx_data  =>  rx_data       --data received
   );

testout(0) <= '1' when seq_state = calib else '0';
testout(1) <= '1' when seq_state = rx_setup else '0';
testout(2) <= '1' when seq_state = rx_poll else '0';
testout(3) <= '1' when seq_state = rx_read else '0';
testout(7 downto 4) <= busy_cnt (3 downto 0);
transact <= '1' when spi_transact = '1' and nrf_sel = '0' else '0';
continuous <= '0';                        

process (clk)
begin
   if clk'event and clk='1' then
      --count done falling edge
      busy_last <= busy;
      if busy = '0' and busy_last = '1' then busy_cnt <= busy_cnt + '1'; end if;
      
      if (seq_state = test or seq_state = calib or seq_state = rx_setup or seq_state = rx_poll or 
          seq_state = rx_read or seq_state = transmit) and strobe_1usec = '1' then
         if count_1usec = x"00f9" then nrf_sel_cnt <= nrf_sel_cnt + '1'; end if; --1us prior to spi_transact
         if count_1usec < x"00fa" then count_1usec <= count_1usec + '1';      
         else count_1usec <= x"0000"; spi_transact <= '1'; end if;
      else spi_transact <= '0';
      end if;

      case seq_state is
         when ready =>
            nrf_ce <= '1';
            nrf_sel <= '1';
            if strobe_1usec = '1' then count_wait <= count_wait + '1'; end if;
            if count_wait > x"01e7" then 
               nrf_ce <= '0'; 
               count_wait <= x"0000"; 
               nrf_sel_cnt <= x"000"; 
               --seq_state <= test; 
               seq_state <= calib; 
            end if;
         when test =>  
            case nrf_sel_cnt is
               when x"000" => nrf_sel <= '0';
                             tx_data <= x"20" + x"07";
               when x"001" => tx_data <= x"00";
               when x"002" => nrf_sel <= '1';

               when x"003" => nrf_sel <= '0';
                             tx_data <= x"20" + x"04";
               when x"004" => tx_data <= x"70";
               when x"005" => nrf_sel <= '1';

               when x"006" => nrf_sel <= '0';
                             tx_data <= x"00" + x"04";
               when x"007" => tx_data <= x"00";
               when x"008" => nrf_sel <= '1';

               when x"009" => nrf_sel <= '0';
                             tx_data <= x"20" + x"04";
               when x"00a" => tx_data <= x"55";
               when x"00b" => nrf_sel <= '1';

               when x"00c" => nrf_sel <= '0';
                             tx_data <= x"00" + x"04";
               when x"00d" => tx_data <= x"00";
               when x"00e" => seq_state <= ready;
                             count_wait <= x"0000";
               nrf_sel_cnt <= x"000"; 
                             nrf_sel <= '1';
               when others => seq_state <= ready;
                             count_wait <= x"0000";
            end case;
         when calib =>  
            case nrf_sel_cnt is
               when x"000" => nrf_sel <= '0';  -- write 0 to 1 (chip off, rx mode)
                             tx_data <= x"20" + x"00";
               when x"001" => tx_data <= x"01";
               when x"002" => nrf_sel <= '1';

               when x"003" => nrf_sel <= '0'; -- write 1 to 0 (no auto ack)
                             tx_data <= x"20" + x"01";
               when x"004" => tx_data <= x"00";
               when x"005" => nrf_sel <= '1';

               when x"006" => nrf_sel <= '0'; -- write 2 to 1 (pipe 1)
                             tx_data <= x"20" + x"02";
               when x"007" => tx_data <= x"01";
               when x"008" => nrf_sel <= '1';

               when x"009" => nrf_sel <= '0'; -- write 3 to 3 (address field)
                             tx_data <= x"20" + x"03";
               when x"00a" => tx_data <= x"03";
               when x"00b" => nrf_sel <= '1';

               when x"00c" => nrf_sel <= '0'; -- write 4 to 0 (no retransmit)
                             tx_data <= x"20" + x"04";
               when x"00d" => tx_data <= x"00";
               when x"00e" => nrf_sel <= '1';

               when x"00f" => nrf_sel <= '0'; -- write 5 to 5 (channel 5)
                             tx_data <= x"20" + x"05";
               when x"010" => tx_data <= x"05";
               when x"011" => nrf_sel <= '1';

               when x"012" => nrf_sel <= '0'; -- write 6 to 6 (1mb/s 0dbm)
                             tx_data <= x"20" + x"06";
               when x"013" => tx_data <= x"06";
               when x"014" => nrf_sel <= '1';

               when x"015" => nrf_sel <= '0'; -- write 11 to 20 (32 byte payload -max)
                             tx_data <= x"20" + x"11";
               when x"016" => tx_data <= x"20";
               when x"017" => nrf_sel <= '1';
               when x"018" => seq_state <= rx_setup;
                             nrf_sel_cnt <= x"000";
                             count_wait <= x"0000";
               when others => seq_state <= ready;
                             count_wait <= x"0000";
            end case;
         when rx_setup =>  
            case nrf_sel_cnt is
               when x"000" => nrf_sel <= '0'; -- tx mode off
                             tx_data <= x"20" + x"00"; 
               when x"001" => tx_data <= x"01";
               when x"002" => nrf_sel <= '1';
                             
               when x"003" => nrf_sel <= '0'; -- tx mode on
                             tx_data <= x"20" + x"00";
               when x"004" => tx_data <= x"03";
               when x"005" => nrf_sel <= '1';
                             
               when x"006" => nrf_sel <= '0'; -- purge rx fifo
                             tx_data <= x"00" + x"e2"; 
               when x"007" => tx_data <= x"00";
               when x"008" => nrf_sel <= '1';
                             
               when x"009" => nrf_sel <= '0'; -- clear status register
                             tx_data <= x"20" + x"07";
               when x"00a" => tx_data <= x"70";
               when x"00b" => nrf_sel <= '1';
                             seq_state <= rx_wait; 
                             nrf_sel_cnt <= x"000";
                             count_wait <= x"0000";
               when others => seq_state <= ready;
                             count_wait <= x"0000";
            end case;
         when rx_wait =>
            nrf_ce <= '1';
            if strobe_1usec = '1' then count_wait <= count_wait + '1'; end if;
            if count_wait = x"0080" then count_wait <= x"0000"; nrf_sel_cnt <= x"000"; seq_state <= rx_poll; end if;
         when rx_poll =>  
            if rx_data(6) = '1' and nrf_sel_cnt(2 downto 0) = "101" then nrf_sel_cnt <= x"000"; seq_state <= rx_read; end if;
            if nrf_sel_cnt > x"0f0" then 
               nrf_ce <= '0';
               seq_state <= rx_setup; 
               nrf_sel_cnt <= x"000";
            end if;
            case nrf_sel_cnt(2 downto 0) is
               when "000" => 
               when "001" => 
               when "010" => 
               when "011" => 
               when "100" => tx_data <= x"07"; 
                             nrf_sel <= '0';
               when "101" => nrf_sel <= '1';
               when "110" => 
               when "111" => 
               when others => 
            end case;
         when rx_read =>  
            case nrf_sel_cnt is
               when x"000" => nrf_ce <= '0';
               when x"001" => nrf_sel <= '0'; 
                             tx_data <= x"61"; -- read 32 bytes rx buffer
               when x"002" => tx_data<= x"00";
                              if count_1usec = x"00f9" then rc_timer(15 downto 8) <= rx_data; end if;
               when x"003" => if count_1usec = x"00f9" then rc_timer( 7 downto 0) <= rx_data; end if;    
               when x"004" => if count_1usec = x"00f9" then throttle(15 downto 8) <= rx_data; end if;    
               when x"005" => if count_1usec = x"00f9" then throttle( 7 downto 0) <= rx_data; end if;    
               when x"006" => if count_1usec = x"00f9" then yaw(15 downto 8) <= rx_data; end if;    
               when x"007" => if count_1usec = x"00f9" then yaw( 7 downto 0) <= rx_data; end if;    
               when x"008" => if count_1usec = x"00f9" then pitch(15 downto 8) <= rx_data; end if;    
               when x"009" => if count_1usec = x"00f9" then pitch( 7 downto 0) <= rx_data; end if;    
               when x"00a" => if count_1usec = x"00f9" then roll(15 downto 8) <= rx_data; end if;    
               when x"00b" => if count_1usec = x"00f9" then roll( 7 downto 0) <= rx_data; end if;    
               when x"00c" => if count_1usec = x"00f9" then rx_mode(15 downto 8) <= rx_data; end if;    
               when x"00d" => if count_1usec = x"00f9" then rx_mode( 7 downto 0) <= rx_data; end if;    
               when x"00e" => seq_state <= transmit; 
                             --nrf_ce <= '0';
                             nrf_sel <= '1';
                             nrf_sel_cnt <= x"000";
               when others => seq_state <= ready;
            end case;
         when transmit =>  
            case nrf_sel_cnt is
               when x"000" => nrf_sel <= '0'; --tx mode off
                             tx_data <= x"20" + x"00";
               when x"001" => tx_data <= x"00";
               when x"002" => nrf_sel <= '1';
                             
               when x"003" => nrf_sel <= '0'; --tx mode on
                             tx_data <= x"20" + x"00";
               when x"004" => tx_data <= x"02";
               when x"005" => nrf_sel <= '1';
                             
               when x"006" => nrf_sel <= '0'; -- flush tx buffer
                             tx_data <= x"00" + x"e2"; 
               when x"007" => tx_data <= x"00";
               when x"008" => nrf_sel <= '1';
                             
               when x"009" => nrf_sel <= '0';
                             tx_data <= x"20" + x"07";
               when x"00a" => tx_data <= x"70";
               when x"00b" => nrf_sel <= '1';

               when x"00c" => nrf_sel <= '0'; 
                             tx_data <= x"a0"; -- tx buffer address (32 byte max)
               when x"00d" => tx_data <= drone_timer(15 downto 8);
               when x"00e" => tx_data <= drone_timer(7 downto 0);
               when x"00f" => tx_data <= height(15 downto 8);
               when x"010" => tx_data <= height(7 downto 0);
               when x"011" => tx_data <= heading(15 downto 8);
               when x"012" => tx_data <= heading(7 downto 0);
               when x"013" => tx_data <= displacement(15 downto 8);
               when x"014" => tx_data <= displacement(7 downto 0);
               when x"015" => tx_data <= theta(15 downto 8);
               when x"016" => tx_data <= theta(7 downto 0);
               when x"017" => tx_data <= phi(15 downto 8);
               when x"018" => tx_data <= phi(7 downto 0);
               when x"019" => tx_data <= motor1(15 downto 8);
               when x"01a" => tx_data <= motor1(7 downto 0);
               when x"01b" => tx_data <= motor2(15 downto 8);
               when x"01c" => tx_data <= motor2(7 downto 0);
               when x"01d" => tx_data <= motor3(15 downto 8);
               when x"01e" => tx_data <= motor3(7 downto 0);
               when x"01f" => tx_data <= motor4(15 downto 8);
               when x"020" => tx_data <= motor4(7 downto 0);
               when x"021" => tx_data <= voltage(15 downto 8);
               when x"022" => tx_data <= voltage(7 downto 0);
               when x"023" => nrf_ce <= '1';
                             nrf_sel <= '1';
               when x"024" => 
               when x"025" => nrf_sel_cnt <= x"000"; --wait 500usec
                             nrf_ce <= '0';
                             seq_state <= ready;
               nrf_sel_cnt <= x"000"; 
               when others => seq_state <= ready;
            end case;
         when others => seq_state <= ready;
      end case;
   end if;
end process;

end behavioral;
