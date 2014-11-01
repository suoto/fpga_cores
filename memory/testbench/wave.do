onerror {resume}
quietly WaveActivateNextPane {} 0
#add wave -noupdate -radix hex {*}
add wave -noupdate -radix hex -expand -group {dut} {dut/*}
#add wave -noupdate -radix hex -expand -group {pulse sync} {dut/wr_error_s/*}
#add wave -noupdate -radix hex -expand -group {pulse sync edge det} {dut/wr_error_s/dst_pulse_t/*}

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 0
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {999050 ns} {1000050 ns}
