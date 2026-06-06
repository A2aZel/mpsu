# ЛР3. Регистровый файл и память инструкций

Два элемента памяти будущего процессора RISC-V.

## Мои файлы (решение)
- `instr_mem.sv` — память инструкций (ПЗУ, 512×32 бит, асинхронное чтение,
  адрес побайтовый — берутся биты `[10:2]`).
- `register_file.sv` — регистровый файл (32×32 бит, 2 порта чтения async +
  1 порт записи sync, `x0` — аппаратный ноль, массив назван `rf_mem`).

## Вспомогательные файлы
- `memory_pkg.sv` — пакет с размерами памяти.
- `program.mem` — содержимое памяти инструкций (нужно для элаборации `instr_mem`).
- `lab_03.tb_register_file.sv` — тестбенч регистрового файла.
- `board files/` — проверка в ПЛИС: `nexys_rf_riscv.sv` + `nexys_a7_100t.xdc`.

## Как загрузить в Vivado
1. Создать пустой RTL-проект.
2. В `Design Sources` добавить: `memory_pkg.sv`, `instr_mem.sv`, `register_file.sv`.
3. Добавить `program.mem` (Add Sources → Add or create design sources, тип `.mem`).
4. В `Simulation Sources` добавить `lab_03.tb_register_file.sv`
   (верхний модуль симуляции — `lab_03_tb_register_file`).
5. Для платы: добавить `board files/nexys_rf_riscv.sv` и `nexys_a7_100t.xdc`,
   верхний модуль синтеза — `nexys_rf_riscv`.

Тест регистрового файла должен закончиться сообщением `Number of errors: 0`.
