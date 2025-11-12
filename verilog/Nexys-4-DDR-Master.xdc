## This is for Nexys 4 DDR board
## Nexys-4-DDR-Master.xdc

## Clock signal (100MHz)
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}];

## Reset button (BTNC - center button)
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports { rst }];

## Configuration
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

##############################################################################
## OPTION 1: Pmod Header JA
## Pins: 1=C17, 2=D18, 3=E18, 4=G17, 5=GND, 6=VCC
##       7=D17, 8=E17, 9=F18, 10=G18, 11=GND, 12=VCC
##############################################################################
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports { scl }]; # JA1
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports { sda }]; # JA2

##############################################################################
## OPTION 2: Pmod Header JB
## Pins: 1=D14, 2=F16, 3=G16, 4=H14, 5=GND, 6=VCC
##       7=E16, 8=F13, 9=G13, 10=H16, 11=GND, 12=VCC
##############################################################################
#set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { scl }]; # JB1
#set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports { sda }]; # JB2

##############################################################################
## OPTION 3: Pmod Header JC
## Pins: 1=K1, 2=F6, 3=J2, 4=G6, 5=GND, 6=VCC
##       7=E7, 8=J3, 9=J4, 10=E6, 11=GND, 12=VCC
##############################################################################
#set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 } [get_ports { scl }]; # JC1
#set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 } [get_ports { sda }]; # JC2

##############################################################################
## OPTION 4: Pmod Header JD
## Pins: 1=H4, 2=H1, 3=G1, 4=G3, 5=GND, 6=VCC
##       7=H2, 8=G4, 9=G2, 10=F3, 11=GND, 12=VCC
##############################################################################
#set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports { scl }]; # JD1
#set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 } [get_ports { sda }]; # JD2

##############################################################################
## Configuration options
##############################################################################
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
