vunit_load
add  wave  -noupdate  -expand  -group  "TB top" "*"
add  wave  -noupdate -group  "DUT"    "dut/*"

configure wave -namecolwidth 200
configure wave -valuecolwidth 120
update
vunit_run
