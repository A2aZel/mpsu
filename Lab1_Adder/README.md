# ЛР1. Сумматор

Реализация полного сумматора на SystemVerilog: 1-битный, 4-битный и 32-битный.

## Мои файлы (решение)
- `fulladder.sv` — полный 1-битный сумматор.
- `fulladder4.sv` — 4-битный сумматор (цепочка из 4× `fulladder`).
- `fulladder32.sv` — 32-битный сумматор (цепочка из 8× `fulladder4`).

## Вспомогательные файлы (из репозитория курса)
- `lab_01.tb_fulladder.sv`, `lab_01.tb_fulladder4.sv`, `lab_01.tb_fulladder32.sv` — тестбенчи.
- `board files/` — проверка в ПЛИС (Nexys A7): `nexys_adder.sv` + `nexys_a7_100t.xdc`.

## Как загрузить в Vivado
1. Создать пустой RTL-проект.
2. В `Design Sources` добавить: `fulladder.sv`, `fulladder4.sv`, `fulladder32.sv`.
3. В `Simulation Sources` добавить нужный тестбенч.
4. Перед запуском симуляции выставить верхним модулем нужный `lab_01_tb_fulladder*`
   (имя модуля внутри тестбенча: `lab_01_tb_fulladder`, `lab_01_tb_fulladder4`, `lab_01_tb_fulladder32`).
5. Для проверки на плате: добавить `board files/nexys_adder.sv` и `nexys_a7_100t.xdc`,
   верхним модулем синтеза выставить `nexys_adder`.

Тестбенч 32-битного сумматора сам сравнивает результат и печатает число ошибок
(должно быть `0`). Тестбенчи 1- и 4-битного — проверяются по временной диаграмме.
