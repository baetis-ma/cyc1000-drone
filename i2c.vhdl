library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_UNSIGNED.ALL; 
use ieee.numeric_std.ALL;

entity i2c is
  generic (
    input_clk    : integer := (50_000_000);
    i2c_clk_rate : integer := 50_000);   --i2c scl freq
	 --i2c_clk_rate : integer := 5_000);   --i2c scl freq
    --works at 1.5MHz with additional 3K pu, 1.2M ok, 2M not ok
  port (
    clk          : in     std_logic;                  
    rst_n        : in     std_logic;
    sda_in       : in     std_logic;     
    sda_out      : buffer std_logic;                 
    scl          : buffer std_logic;
    nack         : buffer std_logic;
    magx         : buffer std_logic_vector(15 downto 0) := x"0000";
    magy         : buffer std_logic_vector(15 downto 0) := x"0000";
    magz         : buffer std_logic_vector(15 downto 0) := x"0000";
    heading      : buffer std_logic_vector(15 downto 0);
    altitude     : buffer std_logic_vector(15 downto 0);
    nack_cnt     : buffer std_logic_vector(15 downto 0) := x"0000";
    ack_cnt      : buffer std_logic_vector(15 downto 0) := x"0000";   
    calibrate    : in     std_logic;
    i2c_testout  : buffer std_logic_vector(7 downto 0)
  );                  
end i2c;

architecture logic of i2c is
--define internal signals
constant divider          : integer := (input_clk/i2c_clk_rate/16);
signal   clock_count      : integer := 0;
signal   i2cstartcnt      : integer := 50_000_000;
constant i2cstartmax      : integer := (50_000_000/20);  -- run i2c sequence every 50msec
signal   i2c_start        : std_logic;
type     i2cmachine         is(stop, start, ack, shift, pause, pre_start, reset);
signal   i2c_state        : i2cmachine;
type     state0             is(seq_rdy, seq_run, seq_cal);
signal   i2c_seqer        : state0 := seq_rdy;
type     state1             is(command_rdy, regset, readword3, readword, writebyte, detect);
signal   commands_state   : state1;
signal   magx_off         : std_logic_vector(15 downto 0);
signal   magy_off         : std_logic_vector(15 downto 0);
signal   word_cnt         : std_logic_vector(3 downto 0);
signal   done_cnt         : std_logic_vector(7 downto 0);
signal   seq_cnt          : std_logic_vector(7 downto 0);
signal   slave_addr       : std_logic_vector(7 downto 0);
signal   slave_address    : std_logic_vector(7 downto 0);
signal   reg_addr         : std_logic_vector(7 downto 0);
signal   reg_data         : std_logic_vector(7 downto 0);
signal   i2c_ena          : std_logic;
signal   i2c_rw           : std_logic;   -- write = 0 read = 1
signal   i2c_ack_error    : std_logic;   
signal   rdata            : std_logic_vector(7 downto 0);
signal   rword            : std_logic_vector(15 downto 0);
signal   wdata            : std_logic_vector(7 downto 0);
signal   i2c_cnt          : std_logic_vector(7 downto 0);
signal   i2c_transmitting : std_logic;
signal   nack_once        : std_logic := '0';
signal   eoc              : std_logic;
signal   present          : std_logic;
signal   ack_strobe       : std_logic;
signal   stop_strobe      : std_logic;
signal   calibratex       : std_logic := '1';
signal   bmp280           : std_logic_vector(19 downto 0); 
signal   bmp280_off       : std_logic_vector(19 downto 0); 


component direction is
  port(
    clk     : in     std_logic;
    magx    : in     std_logic_VECTOR(15 downto 0);
    magy    : in     std_logic_VECTOR(15 downto 0);
    heading : out    std_logic_VECTOR(15 downto 0)
  );
end component direction;

begin

altitude <= bmp280(15 downto 0);
direction0 : component direction
   port map (
      clk     => clk,
      magx    => magx,
      magy    => magy,
      heading => heading
    );

i2c_testout(7 downto 4) <= done_cnt(3 downto 0);
i2c_testout(3) <= '1' when i2c_state = shift else '0';
i2c_testout(2) <= '1' when i2c_state = start else '0';
i2c_testout(0) <= '1' when i2c_state = pause else '0';

process (clk)
begin
   if clk'event and clk='1' then
      -- initialize 
      if rst_n = '1' or nack_once = '0' then 
         nack_once <= '1'; 
         i2c_state <= pause; 
         eoc <= '0';
      end if;
      
   -- i2c testing      
      --if i2c_cnt(3 downto 0) = x"8" then 
      --   if eoc = '1' then magx(12) <= '1'; else magx(12) <= '0'; end if;
      --   magx(8) <= scl;
      --   magx(4) <= sda_in;
      --   magx(0) <= sda_out;
      --end if;
      --magy(15 downto 8) <= i2c_cnt(7 downto 0);
      --case i2c_state is
      --   when pause     => magy(7 downto 0) <= x"01";
      --   when start     => magy(7 downto 0) <= x"02";
      --   when shift     => magy(7 downto 0) <= x"03";
      --   when ack       => magy(7 downto 0) <= x"04";
      --   when stop      => magy(7 downto 0) <= x"05";
      --   when reset     => magy(7 downto 0) <= x"07";
      --   when pre_start => magy(7 downto 0) <= x"0f";
      --   when others    => magy(7 downto 0) <= x"ff";
      --end case;
      --magz(15 downto 8) <= seq_cnt;      
      --magz(7 downto 0) <= done_cnt;
      --accelx = read word
      --accely(12) <= i2c_start;
      --case commands_state is
      --   when command_rdy => accely(7 downto 0) <= x"10";
      --   when readword    => accely(7 downto 0) <= x"01";
      --   when writebyte   => accely(7 downto 0) <= x"02";
      --   when detect      => accely(7 downto 0) <= x"03";
      --end case;            if i2c_start = '1' and calibratex = '1' then i2c_seqer <= seq_cal; end if;
      --accelz(7 downto 0) <= rdata;
      
      --ic2 state counter
      if clock_count < divider then clock_count <= clock_count + 1;
      else   i2c_cnt <= i2c_cnt + x"01"; clock_count <= 0; end if;

      --i2c state machine
      case i2c_state is
         when pause =>  
            scl <= '1';
            sda_out <= '1';
            commands_state <= command_rdy;
         when pre_start => 
            sda_out <= '1';
            scl <= '1';         
            if i2c_cnt(3 downto 0) = x"f" then
               i2c_cnt <= x"00";
               i2c_state <= start; 
            end if;
         when start => 
            if i2c_cnt(3 downto 0) = x"4" then sda_out <= '0'; end if;
            if i2c_cnt(3 downto 0) = x"c" then scl <= '0'; end if;
            if i2c_cnt(3 downto 0) = x"f" then i2c_state <= shift; i2c_cnt <= x"00"; end if;
         when stop =>
            if i2c_cnt(3 downto 0) = x"1" then scl <= '0'; end if;
            if i2c_cnt(3 downto 0) = x"1" then sda_out <= '0'; end if;
            if i2c_cnt(3 downto 0) = x"8" then scl <= '1'; end if;
            if i2c_cnt(3 downto 0) = x"c" then sda_out <= '1'; end if;
            --if i2c_cnt(3 downto 0) = x"f" and clock_count = 0 then 
            if i2c_cnt(3 downto 0) = x"f" then
               i2c_state <= pause; end if;
         when reset =>
            sda_out <= '1';
            if i2c_cnt(3 downto 0) = x"4" then scl <= '1'; end if;
            if i2c_cnt(3 downto 0) = x"c" then scl <= '0'; end if;  
            if sda_in = '1' and i2c_cnt(3 downto 0) = x"f" then
               i2c_cnt <= x"00";   
               i2c_state <= stop; 
               --i2c_seqer <= seq_rdy;
            end if;
         when shift =>
            if i2c_transmitting = '1' then  
               sda_out <= wdata(7-to_integer(unsigned(i2c_cnt(7 downto 4))));
            else sda_out <= '1';   
            end if;
            if i2c_cnt(3 downto 0) = x"5" then scl <= '1'; end if;            
            if i2c_cnt(3 downto 0) = x"d" then scl <= '0'; end if;
            if i2c_cnt(3 downto 0) = x"c" then 
               rdata(7-to_integer(unsigned(i2c_cnt(7 downto 4)))) <= sda_in; end if;
            if i2c_cnt(7 downto 0) = x"7f" then 
               i2c_state <= ack; i2c_cnt <= x"00"; end if;
         when ack =>
            sda_out <= i2c_transmitting;
            if i2c_cnt(3 downto 0) = x"4" then scl <= '1'; end if;
            if i2c_cnt(3 downto 0) = x"c" then scl <= '0'; end if; 
            if i2c_cnt(3 downto 0) = x"3" and clock_count = 0 then
               nack <= sda_in;      
               if sda_in = '1' then nack_cnt <= nack_cnt + '1'; end if;
               if sda_in = '0' then ack_cnt <= ack_cnt + '1'; end if;
               sda_out <= '0';         
            end if;         
            if i2c_cnt(3 downto 0) = x"f" then
               i2c_cnt <= x"00";
               if eoc = '1' then 
                     --eoc <= '0'; 
                     sda_out <= '0';
                     i2c_state <= stop;
                     --i2c_state <= reset;
                     --commands_state <= command_rdy;   
               else i2c_state <= shift; end if;   
            end if;            
            --if i2c_start = '1' and calibratex = '1' then i2c_seqer <= seq_cal; end if;
         when others =>
            --i2c_state <= pause;         
      end case;
      
      --command sequence engine
      if i2c_state = ack and i2c_cnt(3 downto 0) = x"f" and clock_count = 0 then 
         ack_strobe <= '1'; else ack_strobe <= '0'; end if;
      if i2c_state = stop and i2c_cnt(3 downto 0) = x"f" and clock_count = 0 then 
         stop_strobe <= '1'; else stop_strobe <= '0'; end if;

      case commands_state is     
         when command_rdy =>
            done_cnt <= x"00"; 
            eoc <= '0';

         when regset =>
            case done_cnt is
               when x"00" =>
                  if i2c_state = pause and clock_count = 0 then
                     done_cnt <= x"01";
                     i2c_state <= pre_start;                
                  end if;
               when x"01" =>   -- wait for start to finish
                  if i2c_cnt = x"f" then done_cnt <= x"02"; end if;
               when x"02" =>   -- send slaveaddr
                  i2c_transmitting <= '1';      
                  i2c_rw <= '0';                  
                  wdata <= slave_address;                     
                  if ack_strobe = '1' then done_cnt <= x"03"; end if;
               when x"03" =>   -- send regaddr
                  eoc <= '1';
                  wdata <= reg_addr;         
                  if stop_strobe = '1' then  
                     seq_cnt <= seq_cnt + '1'; 
                     done_cnt <= x"00";    
                     eoc <= '0';         
                  end if;
               when others =>
                  commands_state <= command_rdy; 
            end case;          

         when readword3 =>
            case done_cnt is
               when x"00" =>
                  if i2c_state = pause and clock_count = 0 then
                     done_cnt <= x"01";
                     i2c_state <= pre_start;                
                  end if;
               when x"01" =>   -- wait for start to finish
                  if i2c_cnt = x"f" then done_cnt <= x"02"; end if;
               when x"02" =>   
                  i2c_transmitting <= '1';      
                  i2c_rw <= '1';                  
                  wdata <= slave_address;                     
                  if ack_strobe = '1' then done_cnt <= x"03"; end if;
               when x"03" => 
                  i2c_transmitting <= '0';      
                  if ack_strobe = '1' then 
                     done_cnt <= x"04";  
                     rword(7 downto 0) <= rdata;
                  end if;
               when x"04" => 
                  if ack_strobe = '1' then 
                     done_cnt <= x"05";  
                     rword(15 downto 8) <= rdata;
                  end if;
               when x"05" =>  
                  if ack_strobe = '1' then 
                     done_cnt <= x"06";  
                     rword(7 downto 0) <= rdata;
                  end if;
               when x"06" =>   
                  if ack_strobe = '1' then 
                     done_cnt <= x"07";  
                     rword(15 downto 8) <= rdata;
                  end if;
               when x"07" =>   
                  if ack_strobe = '1' then 
                     done_cnt <= x"08";  
                     rword(7 downto 0) <= rdata;
                  end if;
               when x"08" => 
                  eoc <= '1';
                  if ack_strobe = '1' then rword(15 downto 8) <= rdata; end if;
                  if stop_strobe = '1' then   
                     seq_cnt <= seq_cnt + '1'; 
                     done_cnt <= x"00";    
                     eoc <= '0';         
                  end if;                 
               when others =>
                  commands_state <= command_rdy; 
            end case;  

         when readword =>
            case done_cnt is
               when x"00" =>
                  if i2c_state = pause and clock_count = 0 then
                     done_cnt <= x"01";
                     i2c_state <= pre_start;                
                  end if;
               when x"01" =>   -- wait for start to finish
                  if i2c_cnt = x"f" then done_cnt <= x"02"; end if;
               when x"02" =>   -- send slaveaddr
                  i2c_transmitting <= '1';      
                  i2c_rw <= '0';                  
                  wdata <= slave_address;                     
                  if ack_strobe = '1' then done_cnt <= x"03"; end if;
               when x"03" =>   -- send regaddr
                  wdata <= reg_addr;         
                  if ack_strobe = '1' then done_cnt <= x"04"; 
                    i2c_state <= pre_start; end if;  
               when x"04" =>   -- wait for start to finish
                  if i2c_cnt = x"f" then done_cnt <= x"05"; end if;
               when x"05" =>   -- send slaveaddr
                  i2c_rw <= '1';
                  wdata <= slave_address;         
                  if ack_strobe = '1' then done_cnt <= x"06"; end if;
               when x"06" =>   -- send recieve data 
                  i2c_transmitting <= '0';      
                  if ack_strobe = '1' then 
                     done_cnt <= x"07";  
                     rword(15 downto 8) <= rdata;
                  end if;
               when x"07" =>   -- send recieve data
                  eoc <= '1';
                  if ack_strobe = '1' then rword(7 downto 0) <= rdata; end if;
                  if stop_strobe = '1' then   
                     seq_cnt <= seq_cnt + '1'; 
                     done_cnt <= x"00";    
                     eoc <= '0';         
                  end if;                
               when others =>
                  commands_state <= command_rdy; 
            end case;         

         when detect =>
            case done_cnt is
               when x"00" =>
                  if i2c_state = pause and clock_count = 0 then
                     done_cnt <= x"01";
                     i2c_state <= pre_start;                
                  end if;
               when x"01" =>   -- wait for start to finish                  
                  if i2c_cnt = x"f" then done_cnt <= x"02"; end if;                  
               when x"02" =>                 
                  eoc <= '1';               -- only 1 byte transfer
                  i2c_transmitting <= '1'; 
                  i2c_rw <= '0';        
                  wdata <= slave_address;   -- address of slave
                  if stop_strobe = '1' then 
                     seq_cnt <= seq_cnt + '1';
                     done_cnt <= x"00";
                     eoc <= '0';                     
                  end if;
               when others =>
                  commands_state <= command_rdy; 
            end case;            

         when writebyte   =>
            case done_cnt is
               when x"00" =>
                  if i2c_state = pause and clock_count = 0 then
                     done_cnt <= x"01";
                     i2c_state <= pre_start;                
                  end if;
               when x"01" =>   -- wait for start to finish
                  if i2c_cnt = x"f" then done_cnt <= x"02"; end if;
               when x"02" =>
                  i2c_transmitting <= '1';
                  i2c_rw <= '0';                -- (write) only defined after start
                  wdata <= slave_address;       -- address of slave
                  if ack_strobe = '1' then done_cnt <= x"03"; end if;
               when x"03" =>
                  wdata <= reg_addr;            -- data to be written in i2c second byte
                  if ack_strobe = '1' then done_cnt <= x"04"; end if;
               when x"04" =>
                  eoc <= '1';
                  wdata <= reg_data;  
                  if stop_strobe = '1' then            
                     seq_cnt <= seq_cnt + '1';
                     done_cnt <= x"00";                  
                     eoc <= '0';                     
                  end if;
               when others =>
                  commands_state <= command_rdy; 
            end case;            

         when others =>
            commands_state <= command_rdy; 
      end case;
      
      slave_address(7 downto 1) <= slave_addr(6 downto 0);
      slave_address(0) <= i2c_rw;
      case i2c_seqer is
         when seq_rdy =>
            seq_cnt <= x"00";
            if i2c_start = '1' and calibratex = '1' then i2c_seqer <= seq_cal; end if;
            if i2c_start = '1' and calibratex = '0' then i2c_seqer <= seq_run; end if;
         when seq_cal => 
            calibratex <= '0';
            case seq_cnt is
               when x"00" => 
                  commands_state <= detect;
                  slave_addr <= x"0d";                  --slave address of i2c target
                  if done_cnt = x"02" and stop_strobe = '1' then 
                     present <= nack; 
                  end if;
               when x"01" =>
                  commands_state <= writebyte;
                  reg_addr   <= x"09";
                  reg_data   <= x"01";
               when x"02" =>
                  commands_state <= writebyte;
                  reg_addr   <= x"0a";
                  reg_data   <= x"00";                           
               when x"03" =>
                  commands_state <= writebyte;
                  reg_addr   <= x"0b";
                  reg_data   <= x"01";                        
               when x"04" =>
                  commands_state <= writebyte;
                  slave_addr <= x"76";                  --slave address of i2c target
                  reg_addr   <= x"f5";
                  reg_data   <= x"1c";
               when x"05" =>
                  commands_state <= writebyte;
                  slave_addr <= x"76";                  --slave address of i2c target
                  reg_addr   <= x"f4";
                  reg_data   <= x"1f";
               when x"06" =>
                  i2c_seqer <= seq_rdy;   -- last command 
                  commands_state <= command_rdy;
               when others =>
                  i2c_seqer <= seq_rdy;
                  commands_state <= command_rdy;
            end case;

         when seq_run =>
            case seq_cnt is
               when x"00" => 
                  commands_state <= regset;
                  slave_addr <= x"0d";                  --slave address of i2c target
                  reg_addr <= x"00";    -- reg address to set
                  if done_cnt = x"02" and stop_strobe = '1' then 
                     present <= nack; 
                  end if;
                when x"01" =>
                  commands_state <= readword3;
                  if done_cnt = x"04" and ack_strobe = '1' then 
                     magz <= rword;   
                  end if;                     
                  if done_cnt = x"06" and ack_strobe = '1' then 
                     magx <= rword - x"0000";
                  end if;                     
                  if done_cnt = x"08" and ack_strobe = '1' then 
                     magy <= rword - x"0000";   
                  end if;   
                when x"02" => 
                  commands_state <= detect;
                when x"03" => 
                  commands_state <= detect;                     
                when x"04" => 
                  commands_state <= detect;
                when x"05" => 
                  commands_state <= detect;            
                when x"06" =>
                  commands_state <= regset;
                  slave_addr <= x"76";
                  reg_addr <= x"f7";
                when x"07" =>
                  commands_state <= readword3;
                  if done_cnt = x"03" and ack_strobe = '1' then 
                     bmp280(19 downto 12) <= rdata;   
                  end if;                     
                  if done_cnt = x"04" and ack_strobe = '1' then 
                     bmp280(11 downto 4) <= rdata;   
                  end if;                     
                  if done_cnt = x"05" and ack_strobe = '1' then 
                     bmp280(3 downto 0) <= rdata(7 downto 4);   
                  end if;                     
                  if done_cnt = x"07" and ack_strobe = '1' then 
                     bmp280 <= bmp280 - bmp280_off;
                  end if;                     
                when x"09" =>
                  i2c_seqer <= seq_rdy;   -- last command 
                  commands_state <= command_rdy;     
                when others =>
                  i2c_seqer <= seq_rdy;
                  commands_state <= command_rdy;
            end case;
         when others =>
            i2c_seqer <= seq_rdy;
      end case;
      if calibrate = '1' then bmp280_off <= bmp280; end if;
   end if;
end process;

process (clk)
begin
   if clk'event and clk='1' then
      if i2cstartmax > i2cstartcnt then
         i2c_start <= '0';
         i2cstartcnt <= i2cstartcnt + 1;
      else
         i2c_start <= '1';
         i2cstartcnt <= 0;
      end if;
   end if;
end process;

end logic;
