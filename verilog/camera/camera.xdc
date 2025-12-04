
## Clock signal
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }]; #IO_L12P_T1_MRCC_35 Sch=clk100mhz
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk_100mhz}];

#set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { CPU_RESETN }]; #IO_L3P_T0_DQS_AD1P_15 Sch=cpu_resetn
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { resetn }]; #IO_L3P_T0_DQS_AD1P_15 Sch=cpu_resetn


set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]; #IO_L7P_T1_AD6P_35 Sch=uart_txd_in

##Pmod Header JA

set_property -dict { PACKAGE_PIN C17   IOSTANDARD LVCMOS33 } [get_ports { cam_data[0] }]; #IO_L20N_T3_A19_15 Sch=ja[1]
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { cam_data[1] }]; #IO_L21N_T3_DQS_A18_15 Sch=ja[2]
set_property -dict { PACKAGE_PIN E18   IOSTANDARD LVCMOS33 } [get_ports { cam_data[2] }]; #IO_L21P_T3_DQS_15 Sch=ja[3]
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { cam_data[3] }]; #IO_L18N_T2_A23_15 Sch=ja[4]
set_property -dict { PACKAGE_PIN D17   IOSTANDARD LVCMOS33 } [get_ports { cam_data[4] }]; #IO_L16N_T2_A27_15 Sch=ja[7]
set_property -dict { PACKAGE_PIN E17   IOSTANDARD LVCMOS33 } [get_ports { cam_data[5] }]; #IO_L16P_T2_A28_15 Sch=ja[8]
set_property -dict { PACKAGE_PIN F18   IOSTANDARD LVCMOS33 } [get_ports { cam_data[6] }]; #IO_L22N_T3_A16_15 Sch=ja[9]
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { cam_data[7]}]; #IO_L22P_T3_A17_15 Sch=ja[10]


##Pmod Header JB
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports { cam_pclk }];
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cam_pclk_IBUF]

#set_property -dict { PACKAGE_PIN C10 IOSTANDARD LVCMOS33 } [get_ports { cam_pclk }];
#set_property -dict { PACKAGE_PIN D14   IOSTANDARD LVCMOS33 } [get_ports { cam_pclk }]; #IO_L1P_T0_AD0P_15 Sch=jb[1]
set_property -dict { PACKAGE_PIN F16   IOSTANDARD LVCMOS33 } [get_ports { cam_href }]; #IO_L14N_T2_SRCC_15 Sch=jb[2]
set_property -dict { PACKAGE_PIN G16   IOSTANDARD LVCMOS33 } [get_ports { cam_vsync }]; #IO_L13N_T2_MRCC_15 Sch=jb[3]
set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { cam_xclk }]; #IO_L15P_T2_DQS_15 Sch=jb[4]
set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports { cam_scl }]; #IO_L11N_T1_SRCC_15 Sch=jb[7]
set_property -dict { PACKAGE_PIN F13   IOSTANDARD LVCMOS33 } [get_ports { cam_sda }]; #IO_L5P_T0_AD9P_15 Sch=jb[8]
##set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { JB[9] }]; #IO_0_15 Sch=jb[9]
##set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { JB[10] }]; #IO_L13P_T2_MRCC_15 Sch=jb[10]

## Clock 100 MHz (example pin; verify in Digilent XDC!)
#set_property PACKAGE_PIN E3 [get_ports {clk_100mhz}]
#set_property IOSTANDARD LVCMOS33 [get_ports {clk_100mhz}]
#create_clock -name clk_100mhz -period 10.0 [get_ports {clk_100mhz}]
#set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { UART_TXD_IN }]; #IO_L7P_T1_AD6P_35 Sch=uart_txd_in
#set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { UART_RXD_OUT }]; #IO_L11N_T1_SRCC_35 Sch=uart_rxd_out
#set_property -dict { PACKAGE_PIN D3    IOSTANDARD LVCMOS33 } [get_ports { UART_CTS }]; #IO_L12N_T1_MRCC_35 Sch=uart_cts
#set_property -dict { PACKAGE_PIN E5    IOSTANDARD LVCMOS33 } [get_ports { UART_RTS }]; #IO_L5N_T0_AD13N_35 Sch=uart_rts

#set_property -dict { PACKAGE_PIN N17   IOSTANDARD LVCMOS33 } [get_ports { BTNC }]; #IO_L9P_T1_DQS_14 Sch=btnc

## UART TX (to USB-UART bridge)
#set_property PACKAGE_PIN D4 [get_ports {uart_tx}]  ;# check board XDC
#set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx}]
## PMOD JA: D0..D7 from camera
## Replace <PIN_JA0> etc. with the actual package pins for ja[0]..ja[7] from master XDC
#set_property PACKAGE_PIN <PIN_JA0> [get_ports {cam_data[0]}]
#set_property PACKAGE_PIN <PIN_JA1> [get_ports {cam_data[1]}]
#set_property PACKAGE_PIN <PIN_JA2> [get_ports {cam_data[2]}]
#set_property PACKAGE_PIN <PIN_JA3> [get_ports {cam_data[3]}]
#set_property PACKAGE_PIN <PIN_JA4> [get_ports {cam_data[4]}]
#set_property PACKAGE_PIN <PIN_JA5> [get_ports {cam_data[5]}]
#set_property PACKAGE_PIN <PIN_JA6> [get_ports {cam_data[6]}]
#set_property PACKAGE_PIN <PIN_JA7> [get_ports {cam_data[7]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {cam_data[*]}]

## PMOD JB: control + SCCB (example mapping)
#set_property PACKAGE_PIN <PIN_JB0> [get_ports {cam_pclk}]
#set_property PACKAGE_PIN <PIN_JB1> [get_ports {cam_href}]
#set_property PACKAGE_PIN <PIN_JB2> [get_ports {cam_vsync}]
#set_property PACKAGE_PIN <PIN_JB3> [get_ports {cam_xclk}]
#set_property PACKAGE_PIN <PIN_JB4> [get_ports {cam_scl}]
#set_property PACKAGE_PIN <PIN_JB5> [get_ports {cam_sda}]
#set_property IOSTANDARD LVCMOS33 [get_ports {cam_pclk cam_href cam_vsync cam_xclk cam_scl cam_sda}]
