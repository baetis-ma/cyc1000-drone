library IEEE;
use IEEE.std_logic_1164.ALL;
use ieee.std_logic_unsigned.all; 

entity textinterface is
   port (
           clk           : in     std_logic ; 
           rst_n         : in     std_logic;
           tx            : buffer std_logic;
           rx            : in     std_logic; 
           regaddr       : buffer std_logic_vector(7 downto 0);
           regdataout    : in     std_logic_vector(15 downto 0);
           regdatain     : buffer std_logic_vector(15 downto 0);
           regstrobe     : buffer std_logic := '0';
           testout       : buffer std_logic_vector(7 downto 0) 
    );
end entity textinterface;

architecture Behavioral of textinterface is   

--define internal signals
constant streammax         : integer := (50_000_000/1);  -- uart lines at 10Hz
signal   streamcount       : integer := (50_000_000);
constant stream_cnt        : integer := 11;
type   mem_type              is array (0 to stream_cnt-1) of std_logic_vector(7 downto 0);
--magnetometer map
--signal stream_addr         : mem_type := (x"e0", x"e1", x"50", x"51", x"65", x"60", x"61", x"62", x"63", x"9a");
--attitude map
--signal stream_addr         : mem_type := (x"ba", x"e1", x"38", x"39", x"3a", x"3b", x"3c", x"63", x"65", x"50", x"51");
--rc controller map
signal stream_addr         : mem_type := (x"e0", x"e1", x"50", x"51", x"a0", x"a1", x"a2", x"a3", x"a4", x"a5", x"ba");
signal stream_ptr          : integer range 0 to stream_cnt;
type   rx_machine            is (rst, busy, addr0, addr1, data0, data1, data2, data3, cr);
type   tx_machine            is (pause, tx0, tx1, tx2, tx3, tx4, tx5, tx6, tx7, tx8, tx9, tx10, tx11, tx12); 
signal tx_state            : tx_machine;
signal rx_state            : rx_machine;
signal regwrite            : std_logic := '0';
signal stream              : std_logic := '1';
signal rx_busy             : std_logic;
signal rx_error            : std_logic;
signal rx_data             : std_logic_vector(7 downto 0);
signal tx_ena              : std_logic := '0';
signal tx_data             : std_logic_vector(7 downto 0);
signal tx_busy             : std_logic;
signal statetx             : std_logic_vector(7 downto 0) := x"00";
signal staterx             : std_logic_vector(7 downto 0) := x"00";
signal ascii               : std_logic_vector(7 downto 0);
signal ascii2hex           : std_logic_vector(3 downto 0);
signal asciibad            : std_logic;
signal txdelay             : std_logic_vector(7 downto 0);
signal rxbusy              : std_logic := '0';
signal txrw                : std_logic := '0';
signal regaddr_std         : std_logic_vector(7 downto 0);
signal lastrx_busy         : std_logic;
signal stream_strobe       : std_logic;

--install components
component uart is
    port (
        clk       :   IN      std_logic;                     --system clock
        reset_n   :   IN      std_logic;                     --ascynchronous reset
        rx        :   IN      std_logic;                     --receive pin
        rx_busy   :   buffer  std_logic;                     --data reception in progress
        rx_error  :   buffer  std_logic;                     --start, parity, or stop bit error detected
        rx_data   :   buffer  std_logic_vector(7 DOWNTO 0);  --data received

        tx_ena    :   IN      std_logic;                     --initiate transmission
        tx_data   :   IN      std_logic_vector(7 DOWNTO 0);  --data to transmit
        tx_busy   :   buffer  std_logic;                     --transmission in progress
        tx        :   buffer  std_logic
    );
end component uart;

begin

--connect components
uart0: component uart 
    port map (
          clk       => clk,
          reset_n   => '1',
          rx        => rx,
          rx_busy   => rx_busy,
          rx_error  => rx_error,
          rx_data   => rx_data,

          tx_ena    => tx_ena,
          tx_data   => tx_data,
          tx_busy   => tx_busy,
          tx        => tx
    );
regaddr <= regaddr_std when stream = '0' else stream_addr(stream_ptr);
--connect wires 
testout(0) <= stream;
testout(1) <= '1' when stream_cnt = 4 else '0';
--testout <= stream_addr(3);
--testout(0) <= '1' when rx_state = rst   else '0';
--testout(1) <= '1' when rx_state = busy  else '0';
testout(2) <= '1' when stream_ptr = 0 else '0';
testout(3) <= '1' when stream_ptr = 1 else '0';
testout(4) <= '1' when stream_ptr = 2 else '0';
testout(5) <= '1' when stream_ptr = 3 else '0';
testout(6) <= '1' when stream_ptr = 4 else '0';
testout(7) <= '1' when stream_ptr = 5 else '0';
--testout <= regaddr;
--tx_data <= rx_data;
--tx_ena <= rx_busy;
ascii <= rx_data;
ascii2hex <=  "1111" when ascii = x"66" or ascii = x"46" else
              "1110" when ascii = x"65" or ascii = x"45" else
              "1101" when ascii = x"64" or ascii = x"44" else
              "1100" when ascii = x"63" or ascii = x"43" else
              "1011" when ascii = x"62" or ascii = x"42" else
              "1010" when ascii = x"61" or ascii = x"41" else
              ascii(3 downto 0) when (ascii >= x"30" and ascii <= x"39") else  -- 0 to 9
              "0000";
asciibad   <= '0' when (ascii >= x"30" and ascii <= x"39") else            -- 0 to 9
              '0' when (ascii >= x"61" and ascii <= x"66") else            -- a to f
              '0' when (ascii >= x"41" and ascii <= x"46") else            -- A to F
              '1';

process(clk)
begin
   if clk'event and clk='1' then
      case rx_state is
         when rst =>
            regwrite <= '0'; regstrobe <= '0';
            if(rx_busy = '1') then rx_state <= busy; end if;
         when busy =>
            if(rx_busy = '0') then
               rxbusy <= '0';
               if(rx_data = x"72")    then txrw <= '0'; rx_state <= addr1; --'r'
               elsif(rx_data = x"77") then txrw <= '1'; rx_state <= addr1; --'w'
               elsif(rx_data = x"73") then   rx_state <= rst;
                  if stream = '1' then 
                     stream <= '0'; else stream <= '1'; end if;  
               else rx_state <= rst; end if;
            end if;
         --when read1 =>
         --   if(rx_busy = '1') then rx_state <= addr1; end if;
         when addr1 =>
            if(rx_busy = '1') then rxbusy <= '1'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '1') then 
               rxbusy <= '0'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '0') then
               rxbusy <= '0';
               regaddr_std(7 downto 4) <= ascii2hex;       
               rx_state <= addr0; end if;
         --when read0 =>
         --   if(rx_busy = '1') then rx_state <= addr0; end if;
         when addr0 =>
            if(rx_busy = '1') then rxbusy <= '1'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '1') then 
               rxbusy <= '0'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '0') then
               rxbusy <= '0';
               regaddr_std(3 downto 0) <= ascii2hex;       
               if txrw = '1' then rx_state <= data3; else rx_state <= cr; end if; 
            end if;  
         when data3 =>
            if(rx_busy = '1') then rxbusy <= '1'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '1') then 
               rxbusy <= '0'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '0') then
               rxbusy <= '0';
               regdatain(15 downto 12) <= ascii2hex;       
               rx_state <= data2;
            end if;  
         when data2 =>
            if(rx_busy = '1') then rxbusy <= '1'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '1') then 
               rxbusy <= '0'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '0') then
               rxbusy <= '0';
               regdatain(11 downto 8) <= ascii2hex;       
               rx_state <= data1; 
            end if;  
         when data1 =>
            if(rx_busy = '1') then rxbusy <= '1'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '1') then 
               rxbusy <= '0'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '0') then
               rxbusy <= '0';
               regdatain(7 downto 4) <= ascii2hex;       
               rx_state <= data0;  
            end if;  
         when data0 =>
            if(rx_busy = '1') then rxbusy <= '1'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '1') then 
               rxbusy <= '0'; end if;
            if(rxbusy = '1' and rx_busy = '0' and asciibad = '0') then
               rxbusy <= '0';
               regdatain(3 downto 0) <= ascii2hex;       
               rx_state <= cr;  
            end if;  
         when cr =>
             if rx_data = x"0d" and txrw = '0' then regwrite <= '1'; rx_state <= rst; end if;   
             if rx_data = x"0d" and txrw = '1' then regstrobe <= '1'; rx_state <= rst; end if;             
         when others =>
            rx_state <= rst;
      end case;
   end if;
end process;

--transmit state machine
process(clk)
begin
   if clk'event and clk='1' then
      case tx_state is
         when pause =>
            if(regwrite = '1') then tx_state <= tx0; end if;
            if(stream = '1' and stream_strobe = '1') then stream_ptr <= 0; tx_state <= tx4; end if;
            --local echo
            --lastrx_busy <= rx_busy;
            --if rx_busy = '0' and lastrx_busy = '1' then 
            --   tx_data <= rx_data;
            --   tx_ena <= '1';
            --else
            --   tx_ena <= '0';
            --end if;            
         when tx0 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00"; tx_data <= x"30"; tx_ena <= '1'; end if; --'0'
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx1; end if;
         when tx1 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00"; tx_data <= x"78"; tx_ena <= '1'; end if; --'x'
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx2; end if;
         when tx2 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00";  
               if regaddr(7 downto 4) <= x"9" then tx_data <= regaddr(7 downto 4) + x"30"; 
                                              else tx_data <= regaddr(7 downto 4) + x"57"; end if; 
               tx_ena <= '1'; 
            end if; --addr1
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx3; end if;
         when tx3 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00";  
               if regaddr(3 downto 0) <= x"9" then tx_data <= x"30" + regaddr(3 downto 0);
                                              else tx_data <= x"57" + regaddr(3 downto 0); end if;               
               tx_ena <= '1'; 
            end if; --addr0
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx4; end if;
         when tx4 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00"; tx_data <= x"20"; tx_ena <= '1'; end if; --space
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx5; end if;
         when tx5 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00"; tx_data <= x"30"; tx_ena <= '1'; end if; --'0'
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx6; end if;
         when tx6 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00"; tx_data <= x"78"; tx_ena <= '1'; end if; --'x'
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx7; end if;
         when tx7 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00";  
               if regdataout(15 downto 12) <= x"9" then tx_data <= x"30" + regdataout(15 downto 12);
                                                   else tx_data <= x"57" + regdataout(15 downto 12); end if;
               tx_ena <= '1'; 
            end if; --data3
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx8; end if;
         when tx8 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00";  
               if regdataout(11 downto 8) <= x"9" then tx_data <= x"30" + regdataout(11 downto 8); 
                                                  else tx_data <= x"57" + regdataout(11 downto 8); end if;
               tx_ena <= '1'; 
            end if; --data2
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx9; end if;
         when tx9 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00";  
               if regdataout(7 downto 4) <= x"9" then tx_data <= x"30" + regdataout(7 downto 4); 
                                                 else tx_data <= x"57" + regdataout(7 downto 4); end if;
               tx_ena <= '1'; 
            end if; --data1
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx10; end if;
         when tx10 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00";  
               if regdataout(3 downto 0) <=x"9" then tx_data <= x"30" + regdataout(3 downto 0); 
                                                else tx_data <= x"57" + regdataout(3 downto 0); end if;
               tx_ena <= '1'; 
            end if; 
            if(tx_ena = '1') then 
               tx_ena <= '0';
               if stream = '1' and stream_ptr < stream_cnt - 1 then 
                  stream_ptr <= stream_ptr + 1;   
                  tx_state <= tx4;
               else
                  tx_state <= tx11;
               end if;   
            end if;
         when tx11 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00"; tx_data <= x"0d"; tx_ena <= '1'; end if; --linefeed
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= tx12; end if;
         when tx12 =>
            if(tx_busy = '0') then txdelay <= txdelay + x"01"; end if;
            if(txdelay >= x"cc" and tx_ena = '0') then txdelay <= x"00"; tx_data <= x"0a"; tx_ena <= '1'; end if; --cr
            if(tx_ena = '1') then tx_ena <= '0'; tx_state <= pause; end if;
         when others =>
            tx_state <= pause;
      end case;
   end if;
end process;

process(clk)
begin
   if clk'event and clk='1' then   
      if streamcount < streammax then
         stream_strobe <= '0';
         streamcount <= streamcount + 1;
      else
         stream_strobe <= '1';
         streamcount <= 0;
      end if;
   end if;   
end process;

end Behavioral;
