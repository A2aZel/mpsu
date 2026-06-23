# ЛР4. Простейшее программируемое устройство (CYBERcobra)

Учебный процессор `CYBERcobra 3000 Pro 2.1`, собранный из модулей ЛР1–ЛР3.
В память инструкций загружена программа-счетчик до значения на входе `sw_i`.

## Мои файлы (решение)
- `CYBERcobra.sv` — процессор (PC, сумматор PC из ЛР1, `imem`, `rf`, `alu`,
  мультиплексоры источника записи и слагаемого PC, логика `we`/перехода).
- `program_var12.txt` — программа счетчика в формате конвертера (с комментариями
  и псевдокодом).
- `program.mem` — та же программа в hex (этим файлом инициализируется память инструкций).
- `cyberconvert.py` — скрипт-конвертер `program_var12.txt` → `program.mem`
  (запуск: `python cyberconvert.py program_var12.txt program.mem`).

### Программа счетчика
Псевдокод:
```text
reg_file[1] <- -1
reg_file[2] <- sw_i
reg_file[3] <- 1

loop:
  reg_file[1] <- reg_file[1] + reg_file[3]
  if (reg_file[1] < reg_file[2])
    PC <- PC + (-1)

stop:
  out_o = reg_file[1], PC <- PC + 0
```

Сначала `r1` получает `-1`, `r2` — значение переключателей `sw_i`, `r3` — шаг
`1`. Затем `r1` увеличивается на единицу, пока не станет равным `r2`. Последняя
инструкция выводит `r1` на `out_o` и зацикливается сама на себя.

## Вспомогательные файлы (зависимости из ЛР1–ЛР3)
- `fulladder.sv`, `fulladder4.sv`, `fulladder32.sv`, `alu.sv`, `alu_opcodes_pkg.sv`,
  `instr_mem.sv`, `register_file.sv`, `memory_pkg.sv`.
- `lab_04.tb_cybercobra.sv` — тестбенч.
- `board files/` — проверка в ПЛИС: `nexys_cybercobra.sv` + `nexys_a7_100t.xdc`.

## Как загрузить в Vivado
1. Создать пустой RTL-проект.
2. В `Design Sources` добавить все `.sv` (пакеты + модули + `CYBERcobra.sv`)
   и файл `program.mem`.
3. В `Simulation Sources` добавить `lab_04.tb_cybercobra.sv`
   (верхний модуль симуляции — `lab_04_tb_CYBERcobra`).
4. Запустить симуляцию и вынести на временную диаграмму `pc`, `instr`, `out_o`
   и регистры `DUT.rf.rf_mem[1]`, `DUT.rf.rf_mem[2]`, `DUT.rf.rf_mem[3]`.
   В тестбенче сейчас `sw_i = 16'b100001000` (= 264 = `0x108`).
5. Для платы: `board files/nexys_cybercobra.sv` + `nexys_a7_100t.xdc`,
   верхний модуль синтеза — `nexys_cybercobra`.

> Проверка результата: на временной диаграмме `DUT.rf.rf_mem[1]` должен идти
> `0, 1, 2, ...`, `DUT.rf.rf_mem[2]` должен быть равен `sw_i`, а после достижения
> `264` сигнал `out_o` остается `32'h00000108`. Счетчик `pc` в конце зацикливается
> на последней инструкции (`pc = 20`, hex `0x14`).
