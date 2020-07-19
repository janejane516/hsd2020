onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib int_MAC_opt

do {wave.do}

view wave
view structure
view signals

do {int_MAC.udo}

run -all

quit -force
