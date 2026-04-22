## CLOCK — 100MHz on-board oscillator
## ================================================================
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

## ================================================================
## RESET — Center button BTNC (active high)
## Press to reset, release to run
## ================================================================
set_property PACKAGE_PIN N17 [get_ports reset_btn]
set_property IOSTANDARD LVCMOS33 [get_ports reset_btn]

## ================================================================
## UART — USB-UART bridge on Nexys A7
## These connect to the on-board FTDI chip
## Use these pins — do NOT use Pmod UART
## ================================================================
set_property PACKAGE_PIN C4 [get_ports rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports rx_pin]

set_property PACKAGE_PIN D4 [get_ports tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports tx_pin]

## ================================================================
## SEVEN SEGMENT DISPLAY — Cathodes (segments)
## Common anode display — segments active LOW
## seg[0]=CA, seg[1]=CB, seg[2]=CC, seg[3]=CD,
## seg[4]=CE, seg[5]=CF, seg[6]=CG
## ================================================================
set_property PACKAGE_PIN T10 [get_ports {seg[0]}]
set_property PACKAGE_PIN R10 [get_ports {seg[1]}]
set_property PACKAGE_PIN K16 [get_ports {seg[2]}]
set_property PACKAGE_PIN K13 [get_ports {seg[3]}]
set_property PACKAGE_PIN P15 [get_ports {seg[4]}]
set_property PACKAGE_PIN T11 [get_ports {seg[5]}]
set_property PACKAGE_PIN L18 [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]

## ================================================================
## SEVEN SEGMENT DISPLAY — Anodes
## Nexys A7 has 8 digits — we enable only AN0 (rightmost)
## an = 8'b11111110 in RTL drives AN0 active
## ================================================================
set_property PACKAGE_PIN J17 [get_ports {an[0]}]
set_property PACKAGE_PIN J18 [get_ports {an[1]}]
set_property PACKAGE_PIN T9  [get_ports {an[2]}]
set_property PACKAGE_PIN J14 [get_ports {an[3]}]
set_property PACKAGE_PIN P14 [get_ports {an[4]}]
set_property PACKAGE_PIN T14 [get_ports {an[5]}]
set_property PACKAGE_PIN K2  [get_ports {an[6]}]
set_property PACKAGE_PIN U13 [get_ports {an[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[*]}]

## ================================================================
## LEDs — LD0 to LD15
## Diagnostic outputs:
##   led[15] = exception (illegal instruction)
##   led[14] = is_mul
##   led[13] = is_div
##   led[12] = mac_done
##   led[11] = uart_tx_busy
##   led[10] = rx_done
##   led[9:0] = PC word index
## ================================================================
set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property PACKAGE_PIN J13 [get_ports {led[2]}]
set_property PACKAGE_PIN N14 [get_ports {led[3]}]
set_property PACKAGE_PIN R18 [get_ports {led[4]}]
set_property PACKAGE_PIN V17 [get_ports {led[5]}]
set_property PACKAGE_PIN U17 [get_ports {led[6]}]
set_property PACKAGE_PIN U16 [get_ports {led[7]}]
set_property PACKAGE_PIN V16 [get_ports {led[8]}]
set_property PACKAGE_PIN T15 [get_ports {led[9]}]
set_property PACKAGE_PIN U14 [get_ports {led[10]}]
set_property PACKAGE_PIN T16 [get_ports {led[11]}]
set_property PACKAGE_PIN V15 [get_ports {led[12]}]
set_property PACKAGE_PIN V14 [get_ports {led[13]}]
set_property PACKAGE_PIN V12 [get_ports {led[14]}]
set_property PACKAGE_PIN V11 [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## ================================================================
## CONFIGURATION — Required for Nexys A7
## ================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN [current_design]

## ================================================================
## TIMING CONSTRAINTS
## ================================================================

## Input delay for UART RX (async signal from USB chip)
set_input_delay -clock sys_clk_pin -max 2.0 [get_ports rx_pin]
set_input_delay -clock sys_clk_pin -min 0.0 [get_ports rx_pin]

## Input delay for reset button
set_input_delay -clock sys_clk_pin -max 2.0 [get_ports reset_btn]
set_input_delay -clock sys_clk_pin -min 0.0 [get_ports reset_btn]

## Output delay for UART TX
set_output_delay -clock sys_clk_pin -max 2.0 [get_ports tx_pin]
set_output_delay -clock sys_clk_pin -min 0.0 [get_ports tx_pin]

## Output delay for LEDs (slow outputs — relaxed timing)
set_output_delay -clock sys_clk_pin -max 4.0 [get_ports {led[*]}]
set_output_delay -clock sys_clk_pin -min 0.0 [get_ports {led[*]}]

## Output delay for seven segment
set_output_delay -clock sys_clk_pin -max 4.0 [get_ports {seg[*]}]
set_output_delay -clock sys_clk_pin -min 0.0 [get_ports {seg[*]}]
set_output_delay -clock sys_clk_pin -max 4.0 [get_ports {an[*]}]
set_output_delay -clock sys_clk_pin -min 0.0 [get_ports {an[*]}]

## False path on reset button — async button input
set_false_path -from [get_ports reset_btn]
