// Учебный процессор CYBERcobra 3000 Pro 2.1 (ЛР4).
// Объединяет память инструкций, регистровый файл, АЛУ и 32-битный сумматор.
module CYBERcobra (
  input  logic         clk_i,
  input  logic         rst_i,
  input  logic [15:0]  sw_i,
  output logic [31:0]  out_o
);

  import alu_opcodes_pkg::*;

  // Счётчик команд.
  logic [31:0] pc;
  logic [31:0] instr;

  // Поля инструкции.
  logic        J;
  logic        B;
  logic [1:0]  WS;
  logic [4:0]  alu_op;
  logic [4:0]  RA1;
  logic [4:0]  RA2;
  logic [7:0]  offset;
  logic [4:0]  WA;
  logic [31:0] const_se;   // знакорасширенная 23-битная константа

  assign J        = instr[31];
  assign B        = instr[30];
  assign WS       = instr[29:28];
  assign alu_op   = instr[27:23];
  assign RA1      = instr[22:18];
  assign RA2      = instr[17:13];
  assign offset   = instr[12:5];
  assign WA       = instr[4:0];
  assign const_se = {{9{instr[27]}}, instr[27:5]};

  // Память инструкций.
  instr_mem imem (
    .read_addr_i (pc),
    .read_data_o (instr)
  );

  // Регистровый файл и АЛУ.
  logic [31:0] rd1, rd2;
  logic [31:0] alu_result;
  logic        alu_flag;
  logic [31:0] write_data;
  logic        we;

  register_file rf (
    .clk_i          (clk_i),
    .write_enable_i (we),
    .write_addr_i   (WA),
    .read_addr1_i   (RA1),
    .read_addr2_i   (RA2),
    .write_data_i   (write_data),
    .read_data1_o   (rd1),
    .read_data2_o   (rd2)
  );

  alu alu (
    .a_i      (rd1),
    .b_i      (rd2),
    .alu_op_i (alu_op),
    .flag_o   (alu_flag),
    .result_o (alu_result)
  );

  // Мультиплексор источника записи в регистровый файл.
  always_comb begin
    case (WS)
      2'd0:    write_data = const_se;            // константа из инструкции
      2'd1:    write_data = alu_result;          // результат АЛУ
      2'd2:    write_data = {16'b0, sw_i};       // данные с внешнего устройства
      default: write_data = 32'b0;
    endcase
  end

  // Запись запрещена при переходах (условном и безусловном).
  assign we = ~(J | B);

  // Логика выбора слагаемого для PC: переход выполняется при J,
  // либо при условном переходе с истинным флагом АЛУ.
  logic        pc_sel;
  logic [31:0] pc_add_op;
  logic [31:0] pc_next;

  assign pc_sel = J | (B & alu_flag);

  // Смещение перехода: знакорасширенный offset, умноженный на 4.
  assign pc_add_op = pc_sel ? {{22{offset[7]}}, offset, 2'b00} : 32'd4;

  // Сумматор счётчика команд (из ЛР1).
  fulladder32 pc_adder (
    .a_i     (pc),
    .b_i     (pc_add_op),
    .carry_i (1'b0),
    .sum_o   (pc_next),
    .carry_o ()
  );

  always_ff @(posedge clk_i) begin
    if (rst_i) pc <= 32'b0;
    else       pc <= pc_next;
  end

  // Выход: содержимое регистра по адресу RA1.
  assign out_o = rd1;

endmodule
