// Контроллер переключателей (ЛР7 / ЛР13).
// Возвращает значение sw_i по запросу чтения адреса 0x00 и генерирует
// прерывание при изменении положения переключателей.
module sw_sb_ctrl(
  // Системная шина
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        req_i,
  input  logic        write_enable_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,  // не используется
  output logic [31:0] read_data_o,
  // Подсистема прерываний
  output logic        interrupt_request_o,
  input  logic        interrupt_return_i,
  // Периферия
  input  logic [15:0] sw_i
);

  // Синхронное чтение: по запросу чтения адреса 0x00 выдаём sw_i (доп. нулями).
  always_ff @(posedge clk_i) begin
    if (rst_i)
      read_data_o <= 32'd0;
    else if (req_i & ~write_enable_i & (addr_i == 32'h0))
      read_data_o <= {16'd0, sw_i};
  end

  // Предыдущее значение переключателей для детектирования изменения.
  logic [15:0] sw_prev;
  always_ff @(posedge clk_i) begin
    if (rst_i) sw_prev <= 16'd0;
    else       sw_prev <= sw_i;
  end

  // Запрос прерывания удерживается до завершения его обработки.
  logic irq_reg;
  always_ff @(posedge clk_i) begin
    if (rst_i)                   irq_reg <= 1'b0;
    else if (sw_i != sw_prev)    irq_reg <= 1'b1;
    else if (interrupt_return_i) irq_reg <= 1'b0;
  end

  assign interrupt_request_o = irq_reg;

endmodule
