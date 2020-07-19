onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib mymultadd_opt

do {wave.do}

view wave
view structure
view signals

do {mymultadd.udo}

run -all

quit -force
