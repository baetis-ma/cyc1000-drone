## QuadCoptor
###  F450 Frame with FPGA flightcontroller
## Abstract
##### A Quadcoptor is implemented with H2 Airframe kit, LiPo-3 batteries, Max1000 fpag module and printed circuit board. A functional flight controller is implemented in VHDL. The firmware includes SPI interfaces for RF communications chip and another for MPU6050 MEMS motion tracking chip. DPS operations are implemented to calculate attitude parameters theta, phi and heading which are then used as inputs to PID filters to continuously change rate of motors. 
##### Other features are implemented to enable communication to R/C transmitter, measure system voltage.
###1. Theory of Operation
##### For the situation where this system were simply to be holding a position it is clear that there can be no net forces present on the system as a whole. Each of the motors would be generating about a quarter of the thrust necessary to counteract the weight of the quadcoptor, and there would be no net torque from the motors to rotate the system. Spinning opposite motors in the same direction and adjacent motors in the other direction eliminate much of the net torque from the motors. If the electronic speed controllers and the motors were all equal (and weight evenly distributed, etc…) the throttle control could be advanced or lowered to make the drone rise and fall, or a throttle setting found where the quadcoptor will hover. This does work to a certain extent, but in reality situation more like trying to balance a pencil on a tabletop.
##### To keep this situation stable it is necessary to determine three error signals indication how far the quadcoptor is from 1)the direction we want to be going, 2)the forward angle of tilt and 3)the side to side angle of tilt. These three angles are then used to provide forces necessary to reduce error to keep quadcoptor level and pointed in the correct direction by controlling the speeds of the motors.
##### If the drone were tilting down to one side the motors on that side would be speed up and the others turned down a bit. If the drone were not pointing in the right direction motors spinning in the same direction would be slowed up and the other motors sped up.
##### One of the main challenges of this system lies in the collection, filtering and fusion of the accelerometer and gyroscope data. The x,y,z gyro and x,y,z accel data all come from the same chip, using nanotechnology structures to make its’ measurements, the accelerometers are noisy and the gyroscopes tend to drift. The measurements, after calibration, are combined with a fusion filter to provide theta (back-forward tilt) and phi (side-to-side tilt) measurements that minimizes noise and drift. The gyro data is emphasized in the <1second range with the accel data becoming more important after that. The PID filters calculate speed change commands for theta, roll and heading, each motor has different ways to add or subtract these offsets.
##### Once these measurements are accurately obtained they must be turned into motor speed changes to result in rapid feedback closure. A PID controller with carefully selected gains has been found to be essential here. Gain tuning is critical to damp oscillations and to keep system stable and responsive.
##### A craft that can hover can be made to follow R/C commands by modifying the measured theta (pitch), phi (roll) and heading (yaw) measurements.


### 2. System Overview
#### 2.1 Airframe and Avionics
##### The kit has a F450 airframe with 5x 30Amp ESCs and 5x A2212 1000KV motors, all propellers and mounting hardware. A small compass, spirit level and battery switch were added. The assembled quadcoptor weighs 2.2 pounds (~1kg). 
##### Although not strictly necessary, some thrust vs electrical power measurements were taken of the ESC/A2212 motor system.
##### The first graph was taken with the motor attached to small scale with prop placed to push air upward, at zero rmp the scale was zeroed. The pulse width to the ESC was varied from 1000 to 2000 microseconds with 20millisecond repetition rate with data recorded every 50usec increment. The thrust in grams was record as well as the current and voltage (LiPo 3S) applied to the ESC. With no prop the ESC used less than an amp (and over a ¼ amp when it wasn’t even running). With the prop attached the curves were extended to 1500 usec and the current was seen to increase to 4 Amp and the thrust 0.4Kg. The second graph has this data rearranged a bit, the no prop current is substacted from and prop data and current converted to power and plotted against the thrust, the curve was fit to a curve showing that power increases to the 0.65 power – doubling thrust means three times more electrical power. The data also shows that this drone will need at least 16 Amps from a 3S battery, well within the rating of the available modest batteries (2200mah – 25C). This quadcoptor in standby will be using about 15Watts and hovering will be close to 100Watts. Looks like about 15 minutes of hover or and hour and a half of standby per battery charge.
### 2.2 Support Electronics
##### A printed circuit board houses the support electronics for the drone. The board is two layers and 100mm by 100mm. A schematic is available at end of this paper. The board conrains the following components: CYC1000 fpga module, NRF24L0+ 2.4GHz transceiver, MPU6050 3 axis gyroscope/accelerometer module,  QMC5883 3 axis magnetometer, 4 channel level shifter and buffer for the ESC motor controllers, serial output, BMP280 pressure sensor, VL53L0x ToF module, room for GPS module and a12-5 volt power supply.
## 2. R/C Transmitter
##### The R/C transmitter was built with an ESP32 module controlling OLED Display, NRF240L+ RF module and a 4 channel Analog to Digital converter attached to two Joysticks. In enabled mode it transmits a packet every 50msec containing values for throttle, yaw, pitch, roll and status. Status states include enable, unlock motors, motors off, etc. After transmission a response packet should soon be received containing data from the drone including theta, phi, motor speeds, voltage, pid outputs a well as other parameters, which can be logged over serial connection. The little oled display can show most of the drone blackbox data. The switchs along with the display can are used to enable the drone and initiate drone calibration.
##### The software is written in C with the espressif RTOS design enviroment. (more in section 8.2). 
## 3. Firmware
### 3.1 Top Level Functionality
##### `top.vhdl` provides interconnectivity for the system component pieces, `i2c.vhdl`, `mcp_spi.vhdl`, `nrf_spi.vhdl`, `testinterface.vhdl`, `voltmeter.vhdl` and `pll.vhdl`. It provides a system level memory map of user accessible registers, a memory map listed in appendix. Various system timers are setup such strobes are setup. Motor control PWMs are also setup at this level, generating 4 esc outputs of 1-2msec high logic outputs every 50msec. 
### 3.2 Serial Interface 
##### `textinterface.vhdl` provides serial tx and rx port ttl to usb cable, baud rate is 115,200 baud. In its default mode the fpga outputs a text line of selected memory mapped registers once per second, the variable array stream_addr contains list of register addresses. An attached monitor can keep a list of internal registers to monitor chip operation or to be able to easily graph register values over time, several examples of which are present in this report. To setup monitor register dump: determine tty port plugged into board, in linux stty -F /dev/ttyUSB1 115200 and then cat /dev/ttyUSB1.
##### Another way to use this interface is to run picocom -r -b 115200 -c. To start the output will be the same monitor register dump as above. When you hit the character ‘s’ the dump will stop and monitor will be ready to accept commands to read and write the fpga’s internal mapped registers. There are only three commands: 1) ‘r’ followed by two hex digits – example ‘r 00’ will read register 0 and write it to monitor, 2)’w’ followed by two hex digits of address and then four digits of data – example ‘w 00 1234’ will write new register value to fpga and 3)’s’ returns to monitor register dump.
### 3.3 RF Comms – SPI NRF24L0+
##### This module shares data with the R/C Transmitter. On start up the nrf24 is configured and enter receive mode. As the oscilliscope trace shows the module is repeatedly queried for receive buffer status, it will try until timeout when the device is reconfigured. Eventually the receive buffer status indicates data available and a read is made – the throttle, yaw, pitch, roll and status from the R/C Transmitter. The process moves onto resetting the device and transmitting blackbox data.
### 3.4 6 Axis Gyro/Accel – Attitude Calculation – MPU6050
##### `mcp_spi.vhdl` is an spi interface to a mpu6050 module. This module has a chip containing three MEMS gyroscopes and there accelerometers. The spi interface has a clock rate of 2.5MHz and the six channels of data are collected at an 8KHz rate. A calibration signal external to the module can reset and calibrate the device. The gyroscope measurements are hp pass filtered and the accelerometer measurements low pass filtered, the measurements are ‘fused’ to generate theta and phi outputs.
##### The DSP filtering is worth a short walk through, which is pretty accurate and easy. Each time a new measurement (gyrox) is taken the following two VHDL commands are applied to it, the result is the contents of gyroxint contain the high pass filter output of gyrox. The time constant of the filter depends on the value of tau, tau of zero is time constant of 1 sec – tau = 2 time constant 0.25 sec and  tau  -1 time constant 2 sec. 
##### The same loop is applied to the other gyro and accel measurements. Interestingly the accelorometer measurements lead to low pass filter being represented in accelXint. The gyro outputs are the derivative of the angle while the accelerometer outputs a measurement of actual angle (at least for small angles).
##### In the case of this project, where the mpu6050 is mounted so that accelz=-g, the fusion filtered theta and phi are calculated as follows -


##### These measurements much better control signals than the using acceleromter only.
##### `attitude.vhdl` inputs the R/C commands, the theta and phi calculations above, all the preset PID gain values and outputs four motor control signal (which all have value from 1000 to 2000).
### 3.5 Magnetometer – Heading Calculation
##### A QMC5883 module is used to collect heading information. The unit is connected to the fpga with an I2C bus working at 10Hz. This device returns three axis measurements of magnetic field, depending on placement of module, most of which is the earths field. Many things can alter magnetic field and calibration must be done in as close as possible to use conditions. In order to avoid messy three dimensional calculations, assume that the device will always be used in pretty much the same plane – ie level plus of minus 10 degrees. In this case we only need to use the x axis and y axis field magnitudes. The attached figure shows data gathered through about two and a half revolutions. The plot is of the x axis data plotted against the y axis, ideally the shape of the data would be circular and centered on (0, 0).
##### For calibration the circle is centered with calibration offset parameters entered into the VHDL code, the magnitude adjustment is ignored and not thought to cause unacceptable errors. Field measurements are turned into a direction value by breaking the problem into quadrants and using a comparison tree with simple base two magnitude adjustments, resulting in 10 angles per quadrant and 40 discrete direction results (ranging from 4 – 10 degrees separation).
### 3.6 Attitude Filtering and Control
##### Attitude and headings
##### Each of the motors uses
### 3.7 Battery Voltage Measurement
##### Implements voltage measurement with one fpga I/O pin, two resistors and a capacitor.
##### FPGA input volt is connected to the LIPO-3 battery input through a resistor divider and capacitor to ground (R1, R4 and C20). A measurement is performed every 10 milliseconds. The first 1 millisecond of the cycle an output low signal is applied to node. The fpga output transitions to high impedance, at which time the battery begins to charge the node. An internal counter increments every 1 microsecond until the input voltage reaches the logic high input level. As can be seen from calibration table the input voltage can be inferred from counter value at end of cycle. (voltage.vhdl)
##### On the calibration curve to the right notice that the data fits the expected curve very well.  It appears my 1uF capacitor may be closer to 0.92uF (rated +/- 20%). The time constant is calculated as RC = (R1||R2)C. Vin is the calculated input voltage and Vt is the input threshold voltage transition logic zero to logic one.
## 4. Flight
## 5. Conclusion
## 6. Setting up Software
### 6.1 Altera Quartus
##### Search and download Intel Quartus Prime Lite Edition Design Software, my machine is running ubuntu and using version 21.1. Extract software and install.sh. Give your self permissions for a serial port if necessary.
##### From a terminal go to directory where you want cyc1000-drone project installed and install git. To download project directory enter the following command. 
##### `git clone -r https://github.com/baetis-ma/cyc1000-drone.git`
##### As a short cut to get the quartus gui running -
##### `~/intelFPGA_lite/21.1/quartus/bin/quartus --64bit top.qpf` 
##### Starting a project and getting things going with the gui has its uses, but it is also possible to edit files and program the device directly with your own IDE with a few simple commands.
```
 ~/intelFPGA_lite/21.1/nios2eds/nios2_command_shell.sh                                           (set environment)
quartus_sh --flow compile top                                                                                     (compiles project)
quartus_pgm -m jtag -o "p;/home/mark/Desktop/cyc1000-drone/output_files/top.sof"      (program fpga sram)
```
##### The file command in the base directory has several other useful commands.
### 6.2 ESP32
##### The R/C Tramitter software can be downloaded with the following command.
```
git clone -r https://github.com/baetis/xxx.git
```
##### Setup ESP IDE software from home directory as follows:
```
git clone –recursive https://github.com/espressif/ESP8266_RTOS_SDK.git      
export IDF_Path =~/esp8266/ESP8266_RTOS_SDK
export PATH == $PATH:~/esp8266/extwnsa_’x106-elf/bin
```
##### Information on how to use this enviroment can be found here -
##### https://docs.espressif.com/projects/esp8266-rtos-sdk/en/latest/get-started/
### 6.3 Using the Serial Outputs
##### Both the Drone and R/C Transmitter Systems have serial ports that output text files with columns of hexadecimal numbers. By piping the serial outputs into a program and then piping the programs output into gnuplot realtime updated graphs of system parameters can be displayed.
## 8. Appendix

Schematic
