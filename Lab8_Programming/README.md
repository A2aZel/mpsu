# ЛР8. Высокоуровневое программирование (C++, вариант 12)

Программа на C++ для процессора RISC-V (RV32I + Zicsr). Реализует индивидуальное
задание вариант 12 для пары периферии «переключатели + светодиоды»:
формирует число из чётных двоичных разрядов значения с переключателей
(`out[k] = sw[2*k]`) и выводит результат на светодиоды.

## Мои файлы (решение)
- `main.cpp` — программа: `main` (пустой бесконечный цикл) и
  `extern "C" int_handler` (по прерыванию читает переключатели `sw_ptr->value`,
  собирает число из чётных битов, пишет результат в `led_ptr->value`).
- `memory_pkg.sv` — обновлённый пакет: `INSTR_MEM_SIZE_BYTES = 1024`,
  `DATA_MEM_SIZE_BYTES = 2048` (этим файлом нужно заменить `memory_pkg.sv`
  в проекте из ЛР7).
- `build.sh` — скрипт сборки (компиляция, компоновка, экспорт `.mem`, дизасм).

## Вспомогательные файлы (из репозитория)
- `platform.h` — указатели на структуры регистров периферии (`sw_ptr`, `led_ptr` …).
- `linker_script.ld` — скрипт компоновки (instr_mem 1K, data_mem 2K).
- `startup.S` — стартовый код: инициализация sp/gp, .bss, mtvec/mscratch/mie,
  вызов `main`, низкоуровневый обработчик прерываний с вызовом `int_handler`.

## Алгоритм (вариант 12)
```
result = 0
i = 0
while value != 0:
    result |= (value & 1) << i   # младший (чётный) бит -> позиция i
    value >>= 2                  # к следующему чётному биту
    i++
# пример: value = 0b011_1011_1000 -> result = 0b01_0100 (= 20)
```

## Сборка (требуется кросс-компилятор RISC-V)
Нужен тулчейн `riscv-none-elf-*` (например xpack-riscv-none-elf-gcc 13.2.0).
В git bash, указав путь к нему в `CC_DIR`:
```bash
CC_DIR=/c/riscv_cc/bin ./build.sh
```
Либо вручную (см. ЛР14 README):
```bash
riscv-none-elf-gcc -c -march=rv32i_zicsr -mabi=ilp32 startup.S -o startup.o
riscv-none-elf-g++ -c -march=rv32i_zicsr -mabi=ilp32 -Os main.cpp -o main.o
riscv-none-elf-g++ -march=rv32i_zicsr -mabi=ilp32 -Wl,--gc-sections -nostartfiles \
    -T linker_script.ld startup.o main.o -o result.elf
riscv-none-elf-objcopy -O verilog --verilog-data-width=4 -j .text result.elf init_instr.mem
# Удалить из init_instr.mem первую строку вида @00000000
```

> [!IMPORTANT]
> На этой машине кросс-компилятор RISC-V **не установлен**, поэтому готовые
> `init_instr.mem` / `init_data.mem` не приложены — собрать их без тулчейна
> невозможно. После установки тулчейна выполните `build.sh`, и полученным
> `init_instr.mem` инициализируйте память инструкций (`program.mem`) в проекте.
> Если `init_data.mem` непустой — удалите из него строку `@20000000` и
> добавьте `$readmemh` в `data_mem`.

## Проверка
1. Взять проект из ЛР7 (Переключатели + Светодиоды), заменить `memory_pkg.sv`
   на приведённый здесь (1024/2048).
2. Содержимым `init_instr.mem` заменить `program.mem`.
3. Симулировать тестбенчем `lab_13_tb_processor_system`: при изменении `sw_i`
   приходит прерывание, процессор читает переключатели и выводит число,
   собранное из чётных битов, на `led_o`.
