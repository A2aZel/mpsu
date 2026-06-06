// Арифметико-логическое устройство процессора RISC-V (ЛР2).
// 16 операций RV32I. Старший бит alu_op_i делит операции на вычислительные
// (формируют result_o) и операции сравнения (формируют flag_o).
// Сложение реализовано через 32-битный сумматор из ЛР1.
module alu (
  input  logic [31:0]  a_i,
  input  logic [31:0]  b_i,
  input  logic [4:0]   alu_op_i,
  output logic         flag_o,
  output logic [31:0]  result_o
);

  import alu_opcodes_pkg::*;

  // Сумматор из ЛР1 (используется для операции ADD).
  logic [31:0] add_result;
  fulladder32 adder (
    .a_i     (a_i),
    .b_i     (b_i),
    .carry_i (1'b0),
    .sum_o   (add_result),
    .carry_o ()
  );

  // Мультиплексор вычислительных операций (result_o).
  always_comb begin
    case (alu_op_i)
      ALU_ADD : result_o = add_result;
      ALU_SUB : result_o = a_i - b_i;
      ALU_SLL : result_o = a_i << b_i[4:0];
      ALU_SLTS: result_o = {31'b0, ($signed(a_i) < $signed(b_i))};
      ALU_SLTU: result_o = {31'b0, (a_i < b_i)};
      ALU_XOR : result_o = a_i ^ b_i;
      ALU_SRL : result_o = a_i >> b_i[4:0];
      ALU_SRA : result_o = $signed(a_i) >>> b_i[4:0];
      ALU_OR  : result_o = a_i | b_i;
      ALU_AND : result_o = a_i & b_i;
      default : result_o = 32'b0;
    endcase
  end

  // Мультиплексор операций сравнения (flag_o).
  always_comb begin
    case (alu_op_i)
      ALU_EQ  : flag_o = (a_i == b_i);
      ALU_NE  : flag_o = (a_i != b_i);
      ALU_LTS : flag_o = ($signed(a_i) <  $signed(b_i));
      ALU_GES : flag_o = ($signed(a_i) >= $signed(b_i));
      ALU_LTU : flag_o = (a_i <  b_i);
      ALU_GEU : flag_o = (a_i >= b_i);
      default : flag_o = 1'b0;
    endcase
  end

endmodule
