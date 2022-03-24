--> /home/mark/intelFPGA_lite/21.1/quartus/bin/quartus --64bit
--> /home/mark/intelFPGA_lite/21.1/quartus/bin/quartus --64bit top.qpf
--> /home/mark/intelFPGA_lite/20.1/quartus/bin/quartus --64bit ~/Desktop/anew-dec5/top.qpf
--> ssh -Y localhost /home/mark/intelFPGA_lite/20.1/quartus/bin/quartus --64bit ~/Desktop/anew-dec5/top.qpf

to run programmer from command line
--> ~/intelFPGA_lite/21.1/nios2eds/nios2_command_shell.sh
--> quartus_pgm --auto
--> quartus_pgm -m jtag -o "p;/home/mark/Desktop/amax-dec5/output_files/top.sof"
--> quartus_pgm -m jtag -o "p;/home/mark/Desktop/amax-dec5/output_files/top.pof"

to compile (from project directory) (is nios2 env set dont need path)
--> cd ~/Desktop/fpgadrone
--> ~/intelFPGA_lite/21.1/quartus/bin/quartus_sh --flow compile top
--> ~/intelFPGA_lite/21.1/nios2eds/nios2_command_shell.sh
--> quartus_sh --flow compile top 
--> quartus_pgm -m jtag -o "p;/home/mark/Desktop/amax-dec5/output_files/top.sof"   
cyc1000 has no internal prom, to program via indirect configuration file (.jic)
1) make .cof file, <from main gui file> convert programming file (fill in and save) 
2) execution of .cof makes .jic -- which is file to program on board eprom epcq16a
--> quartus_cpf -c output_files/top.cof
3) start ptoram device from main gui
4) from programmer gui add .jic file, in file tab save project
5) use .cdf to indirectly program module prom
--> quartus_pgm output_files/top.cdf

--> vim top.qsf 
has all depenancies inc fpga device type,pin and type assignments,vhdl files

get assigned pinlist, files, types      
grep ' PIN_' top.qsf | sed 's/^.*PIN_//g'
grep VHDL top.qsf | sed 's/^.*VHDL_FILE//g' 
grep IO_STANDARD top.qsf | sed 's/^.*IO_STANDARD//g' 


  quartus_sh --flow compile top
  quartus_cpf -c output_files/top.cof
  quartus_pgm output_files/top.cdf

