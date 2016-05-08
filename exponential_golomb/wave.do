add wave -noupdate            -expand -group "TB top" "*"
add wave -noupdate            -expand -group "DUT"    "dut/*"
#
# Some signals are better viewed on different radix
add wave -noupdate -radix bin -expand -group "DUT"    "dut/encoded_data"
add wave -noupdate -radix uns -expand -group "DUT"    "dut/output_bit_cnt"
add wave -noupdate -radix uns -expand -group "DUT"    "dut/encoded_dwidth"
configure wave -namecolwidth 200
configure wave -valuecolwidth 120
update
