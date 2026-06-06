// Полный 4-битный сумматор (ЛР1).
// Цепочка из четырёх 1-битных сумматоров, перенос передаётся по вектору c.
module fulladder4(
  input  logic [3:0] a_i,
  input  logic [3:0] b_i,
  input  logic       carry_i,
  output logic [3:0] sum_o,
  output logic       carry_o
);

  // c[0]   — вход переноса нулевого разряда,
  // c[4]   — выход переноса старшего разряда.
  logic [4:0] c;

  assign c[0]   = carry_i;
  assign carry_o = c[4];

  fulladder fa[3:0] (
    .a_i     (a_i),
    .b_i     (b_i),
    .carry_i (c[3:0]),
    .sum_o   (sum_o),
    .carry_o (c[4:1])
  );

endmodule
