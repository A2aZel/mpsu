# Авто-сборка проекта симуляции для Nexys A7-100T (xc7a100tcsg324-1).
# Запуск из Tcl Console Vivado:  source <путь>/Lab2_ALU/build_sim.tcl
catch {close_sim}
catch {close_project}
set script_dir [file dirname [file normalize [info script]]]
set proj_name  "sim_proj"
set part       "xc7a100tcsg324-1"
set sim_top    "lab_02_tb_alu"

set proj_dir [file join $script_dir $proj_name]
file delete -force $proj_dir
create_project $proj_name $proj_dir -part $part -force

set design {}
foreach f [glob -nocomplain -directory $script_dir *.sv] {
  if {[string match "*tb_*" [file tail $f]]} continue
  lappend design $f
}
if {[llength $design]} { add_files $design }

set mems [glob -nocomplain -directory $script_dir *.mem]
if {[llength $mems]} { add_files $mems }

set tbs [glob -nocomplain -directory $script_dir *tb_*.sv]
if {[llength $tbs]} { add_files -fileset sim_1 $tbs }
if {[llength $mems]} { add_files -fileset sim_1 $mems }

set_property top $sim_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
run all
puts "=== Симуляция $sim_top запущена. Смотри Tcl Console и окно Waveform. ==="
