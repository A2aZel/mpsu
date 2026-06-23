# Авто-сборка проекта симуляции ЛР8 для Nexys A7-100T (xc7a100tcsg324-1).
# ЛР8 — это та же железка, что ЛР7, но с увеличенной памятью (memory_pkg 1024/2048)
# и прошивкой из твоей C++-программы. Поэтому RTL берётся из Lab7_Peripherals,
# а memory_pkg.sv — из этой папки (Lab8).
#
# ВАЖНО: в этой папке должен лежать program.mem — это твой init_instr.mem,
# собранный кросс-компилятором (riscv-none-elf) и переименованный в program.mem.
# Без него симуляция запустится, но процессор выполнит пустую/неверную программу.
#
# Запуск из Tcl Console Vivado:  source <путь>/Lab8_Programming/build_sim.tcl
catch {close_sim}
catch {close_project}
set script_dir [file dirname [file normalize [info script]]]
set lab7_dir   [file normalize [file join $script_dir .. Lab7_Peripherals]]
set proj_name  "sim_proj"
set part       "xc7a100tcsg324-1"
set sim_top    "lab_13_tb_processor_system"

set proj_dir [file join $script_dir $proj_name]
file delete -force $proj_dir
create_project $proj_name $proj_dir -part $part -force

# RTL из ЛР7, кроме тестбенча и его memory_pkg (берём увеличенный из ЛР8)
set design {}
foreach f [glob -nocomplain -directory $lab7_dir *.sv] {
  set n [file tail $f]
  if {[string match "*tb_*" $n]} continue
  if {$n eq "memory_pkg.sv"} continue
  lappend design $f
}
lappend design [file join $script_dir memory_pkg.sv]
add_files $design

# Прошивка (program.mem из собранного init_instr.mem)
set mems [glob -nocomplain -directory $script_dir *.mem]
if {[llength $mems]} {
  add_files $mems
  add_files -fileset sim_1 $mems
} else {
  puts "ВНИМАНИЕ: нет program.mem в Lab8_Programming!"
  puts "Сначала собери init_instr.mem кросс-компилятором (см. README) и положи как program.mem."
}

set tb [file join $lab7_dir lab_13.tb_processor_system.sv]
add_files -fileset sim_1 $tb

set_property top $sim_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
run all
puts "=== Симуляция ЛР8 ($sim_top) запущена. ==="
