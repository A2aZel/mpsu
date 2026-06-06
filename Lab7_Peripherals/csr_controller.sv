// Регистры контроля и статуса (CSR controller) (ЛР6).
// Хранит mie, mtvec, mscratch, mepc, mcause; выполняет CSR-операции Zicsr,
// а при трапе (trap_i) сохраняет адрес возврата в mepc и причину в mcause.
module csr_controller (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        trap_i,
  input  logic [ 2:0] opcode_i,
  input  logic [11:0] addr_i,
  input  logic [31:0] pc_i,
  input  logic [31:0] mcause_i,
  input  logic [31:0] rs1_data_i,
  input  logic [31:0] imm_data_i,
  input  logic        write_enable_i,
  output logic [31:0] read_data_o,
  output logic [31:0] mie_o,
  output logic [31:0] mepc_o,
  output logic [31:0] mtvec_o
);

  import csr_pkg::*;

  logic [31:0] mie, mtvec, mscratch, mepc, mcause;

  assign mie_o   = mie;
  assign mtvec_o = mtvec;
  assign mepc_o  = mepc;

  // Текущее значение выбранного CSR.
  always_comb begin
    case (addr_i)
      MIE_ADDR:      read_data_o = mie;
      MTVEC_ADDR:    read_data_o = mtvec;
      MSCRATCH_ADDR: read_data_o = mscratch;
      MEPC_ADDR:     read_data_o = mepc;
      MCAUSE_ADDR:   read_data_o = mcause;
      default:       read_data_o = 32'd0;
    endcase
  end

  // Значение для записи в зависимости от операции CSR.
  logic [31:0] write_value;
  always_comb begin
    case (opcode_i)
      CSR_RW:  write_value =  rs1_data_i;
      CSR_RS:  write_value =  rs1_data_i | read_data_o;
      CSR_RC:  write_value = ~rs1_data_i & read_data_o;
      CSR_RWI: write_value =  imm_data_i;
      CSR_RSI: write_value =  imm_data_i | read_data_o;
      CSR_RCI: write_value = ~imm_data_i & read_data_o;
      default: write_value = 32'd0;
    endcase
  end

  logic we_mie, we_mtvec, we_mscratch, we_mepc, we_mcause;
  assign we_mie      = write_enable_i & (addr_i == MIE_ADDR);
  assign we_mtvec    = write_enable_i & (addr_i == MTVEC_ADDR);
  assign we_mscratch = write_enable_i & (addr_i == MSCRATCH_ADDR);
  assign we_mepc     = write_enable_i & (addr_i == MEPC_ADDR);
  assign we_mcause   = write_enable_i & (addr_i == MCAUSE_ADDR);

  always_ff @(posedge clk_i) begin
    if (rst_i)       mie <= 32'd0;
    else if (we_mie) mie <= write_value;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i)         mtvec <= 32'd0;
    else if (we_mtvec) mtvec <= write_value;
  end

  always_ff @(posedge clk_i) begin
    if (rst_i)            mscratch <= 32'd0;
    else if (we_mscratch) mscratch <= write_value;
  end

  // При трапе в mepc сохраняется адрес инструкции, прерванной исключением/прерыванием.
  always_ff @(posedge clk_i) begin
    if (rst_i)                 mepc <= 32'd0;
    else if (we_mepc | trap_i) mepc <= trap_i ? pc_i : write_value;
  end

  // При трапе в mcause сохраняется причина.
  always_ff @(posedge clk_i) begin
    if (rst_i)                   mcause <= 32'd0;
    else if (we_mcause | trap_i) mcause <= trap_i ? mcause_i : write_value;
  end

endmodule
