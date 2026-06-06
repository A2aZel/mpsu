# ЛР2. Арифметико-логическое устройство (АЛУ)

АЛУ процессора RISC-V: 16 операций (10 вычислительных + 6 сравнений).
Операция ADD реализована через 32-битный сумматор из ЛР1.

## Мои файлы (решение)
- `alu.sv` — модуль АЛУ (два `case`: для `result_o` и `flag_o`).

## Вспомогательные файлы
- `alu_opcodes_pkg.sv` — пакет с кодами операций (`ALU_ADD`, `ALU_SUB`, ...).
- `fulladder.sv`, `fulladder4.sv`, `fulladder32.sv` — сумматор из ЛР1 (зависимость АЛУ).
- `lab_02.tb_alu.sv` — тестбенч (сравнивает с эталоном, печатает число ошибок).
- `board files/` — проверка в ПЛИС: `nexys_alu.sv` + `nexys_a7_100t.xdc`.

## Как загрузить в Vivado
1. Создать пустой RTL-проект.
2. В `Design Sources` добавить: `alu_opcodes_pkg.sv`, `alu.sv`,
   `fulladder.sv`, `fulladder4.sv`, `fulladder32.sv`.
3. В `Simulation Sources` добавить `lab_02.tb_alu.sv` (верхний модуль симуляции
   `lab_02_tb_alu`).
4. Для платы: добавить `board files/nexys_alu.sv` и `nexys_a7_100t.xdc`,
   верхним модулем синтеза — `nexys_alu`.

Тест должен закончиться сообщением `Number of errors: 0`.
