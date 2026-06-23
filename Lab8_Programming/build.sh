#!/usr/bin/env bash
# Сборка программы ЛР8 (вариант 12, переключатели + светодиоды) под RISC-V (RV32I + Zicsr).
# Требуется кросс-компилятор riscv-none-elf-* (xpack-riscv-none-elf-gcc 13.2.0 и т.п.).
# Укажите путь к bin тулчейна в переменной CC_DIR (или добавьте его в PATH).
#
# Запуск (git bash):  ./build.sh
set -euo pipefail

# Путь к каталогу bin кросс-компилятора. Поменяйте при необходимости.
CC_DIR="${CC_DIR:-/c/riscv_cc/bin}"
GPP="${CC_DIR}/riscv-none-elf-g++"
GCC="${CC_DIR}/riscv-none-elf-gcc"
OBJCOPY="${CC_DIR}/riscv-none-elf-objcopy"
OBJDUMP="${CC_DIR}/riscv-none-elf-objdump"

ARCH="-march=rv32i_zicsr -mabi=ilp32"

# 1. Компиляция объектных файлов.
"${GCC}" -c ${ARCH} startup.S -o startup.o
"${GPP}" -c ${ARCH} -Os -ffreestanding -fno-exceptions -fno-rtti main.cpp -o main.o

# 2. Компоновка в исполняемый ELF.
"${GPP}" ${ARCH} -Wl,--gc-sections -nostartfiles -T linker_script.ld \
    startup.o main.o -o result.elf

# 3. Экспорт секций для инициализации памятей (32-битные ячейки).
"${OBJCOPY}" -O verilog --verilog-data-width=4 -j .text result.elf init_instr.mem
"${OBJCOPY}" -O verilog --verilog-data-width=4 -j .data -j .sdata -j .bss result.elf init_data.mem || true

# 4. Удаляем строку адреса (вида @00000000 / @20000000), не нужную $readmemh.
sed -i '/^@/d' init_instr.mem
[ -f init_data.mem ] && sed -i '/^@/d' init_data.mem || true

# 5. Дизассемблирование для отладки.
"${OBJDUMP}" -D result.elf > disasm.S

echo "Готово: init_instr.mem (память инструкций), init_data.mem (память данных), disasm.S"
