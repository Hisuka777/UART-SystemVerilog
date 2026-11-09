transcript on

# Run this script from the repository root directory.
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vlog -sv rtl/baud_generator.sv
vlog -sv rtl/uart_tx.sv
vlog -sv rtl/rx_synchronizer.sv
vlog -sv rtl/uart_rx.sv
vlog -sv rtl/UART.sv
vlog -sv tb/test_UART.sv

vsim -t 1ps work.tb_uart
run -all
