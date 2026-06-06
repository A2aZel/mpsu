// Контроллер прерываний (ЛР6).
// Формирует запрос на прерывание irq_o (если прерывания разрешены и нет
// активной обработки), а также сигнал возврата irq_ret_o по инструкции mret.
module interrupt_controller(
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        exception_i,
  input  logic        irq_req_i,
  input  logic        mie_i,
  input  logic        mret_i,
  output logic        irq_ret_o,
  output logic [31:0] irq_cause_o,
  output logic        irq_o
);

  // exc_h — признак того, что процессор находится в обработчике исключения/прерывания.
  logic exc_h, irq_h;

  always_ff @(posedge clk_i) begin
    if (rst_i) exc_h <= 1'b0;
    else       exc_h <= mret_i ? 1'b0 : (exception_i | exc_h);
  end

  // Возврат из обработчика: mret вне исключения и вне активной обработки.
  assign irq_ret_o = mret_i & ~exception_i & ~exc_h;

  // irq_h — признак того, что текущее прерывание уже обрабатывается.
  always_ff @(posedge clk_i) begin
    if (rst_i) irq_h <= 1'b0;
    else       irq_h <= irq_ret_o ? 1'b0 : (irq_o | irq_h);
  end

  // Машинное внешнее прерывание.
  assign irq_cause_o = 32'h8000_0010;

  // Прерывание выставляется при запросе, разрешённых прерываниях и отсутствии
  // активной обработки исключения/прерывания.
  assign irq_o = irq_req_i & mie_i & ~exception_i & ~exc_h & ~irq_h;

endmodule
