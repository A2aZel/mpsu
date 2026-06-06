// Полный 32-битный сумматор (ЛР1).
// Цепочка из восьми 4-битных сумматоров, перенос передаётся по вектору c.
module fulladder32(
  input  logic [31:0] a_i,
  input  logic [31:0] b_i,
  input  logic        carry_i,
  output logic [31:0] sum_o,
  output logic        carry_o
);

  // c[0]   — вход переноса младшего разряда,
  // c[8]   — выход переноса старшего разряда.
  logic [8:0] c;

  assign c[0]    = carry_i;
  assign carry_o = c[8];

  fulladder4 fa4[7:0] (
    .a_i     (a_i),
    .b_i     (b_i),
    .carry_i (c[7:0]),
    .sum_o   (sum_o),
    .carry_o (c[8:1])
  );

endmodule
