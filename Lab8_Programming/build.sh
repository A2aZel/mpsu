#!/usr/bin/env bash
# Сборка программы ЛР8 (вариант 12, переключатели + светодиоды) под RISC-V (RV32I + Zicsr).
# Требуется кросс-компилятор riscv-none-elf-* (xpack-riscv-none-elf-gcc 13.2.0 и т.п.).
# Укажите путь к bin тулчейна в переменной CC_DIR (или добавьте его в PATH).
#
# Запуск (git bash):  ./build.sh
set -euo pipefail

# Префикс тулчейна (поменяйте под свой):
#   riscv-none-elf-          (xpack)
#   riscv64-unknown-elf-     (типичный на Linux-серверах, работает с -march=rv32i)
#   riscv32-unknown-elf-     (если установлен 32-битный вариант)
CROSS="${CROSS:-riscv-none-elf-}"

# Каталог bin тулчейна. Если он уже в PATH — оставьте CC_DIR пустым.
CC_DIR="${CC_DIR:-}"
if [ -n "${CC_DIR}" ]; then PFX="${CC_DIR}/${CROSS}"; else PFX="${CROSS}"; fi

GPP="${PFX}g++"
GCC="${PFX}gcc"
OBJCOPY="${PFX}objcopy"
OBJDUMP="${PFX}objdump"

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
