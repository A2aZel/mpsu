// Ядро однотактного процессора RISC-V (RV32I + Zicsr + прерывания) (ЛР6).
// Объединённый результат ЛР07 (тракт данных) + ЛР09 (LSU) + ЛР11 (прерывания).
module processor_core (
  input  logic        clk_i,
  input  logic        rst_i,

  input  logic        stall_i,
  input  logic [31:0] instr_i,
  input  logic [31:0] mem_rd_i,
  input  logic        irq_req_i,

  output logic [31:0] instr_addr_o,
  output logic [31:0] mem_addr_o,
  output logic [ 2:0] mem_size_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [31:0] mem_wd_o,
  output logic        irq_ret_o
);

  import decoder_pkg::*;

  // Программный счётчик.
  logic [31:0] pc;
  assign instr_addr_o = pc;

  // ----- Декодер -----
  logic [1:0] a_sel;
  logic [2:0] b_sel;
  logic [4:0] alu_op;
  logic [2:0] csr_op;
  logic       csr_we;
  logic       mem_req_dec, mem_we_dec;
  logic [2:0] mem_size_dec;
  logic       gpr_we;
  logic [1:0] wb_sel;
  logic       illegal;
  logic       branch, jal, jalr, mret;

  decoder i_decoder (
    .fetched_instr_i (instr_i),
    .a_sel_o         (a_sel),
    .b_sel_o         (b_sel),
    .alu_op_o        (alu_op),
    .csr_op_o        (csr_op),
    .csr_we_o        (csr_we),
    .mem_req_o       (mem_req_dec),
    .mem_we_o        (mem_we_dec),
    .mem_size_o      (mem_size_dec),
    .gpr_we_o        (gpr_we),
    .wb_sel_o        (wb_sel),
    .illegal_instr_o (illegal),
    .branch_o        (branch),
    .jal_o           (jal),
    .jalr_o          (jalr),
    .mret_o          (mret)
  );

  // ----- Регистровый файл -----
  logic [31:0] rs1_data, rs2_data, rf_wd;
  logic        rf_we;

  register_file i_rf (
    .clk_i          (clk_i),
    .write_enable_i (rf_we),
    .write_addr_i   (instr_i[11:7]),
    .read_addr1_i   (instr_i[19:15]),
    .read_addr2_i   (instr_i[24:20]),
    .write_data_i   (rf_wd),
    .read_data1_o   (rs1_data),
    .read_data2_o   (rs2_data)
  );

  // ----- Константы (immediate) -----
  logic [31:0] imm_i, imm_u, imm_s, imm_b, imm_j, imm_z;
  assign imm_i = {{20{instr_i[31]}}, instr_i[31:20]};
  assign imm_u = {instr_i[31:12], 12'b0};
  assign imm_s = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
  assign imm_b = {{19{instr_i[31]}}, instr_i[31], instr_i[7], instr_i[30:25], instr_i[11:8], 1'b0};
  assign imm_j = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12], instr_i[20], instr_i[30:21], 1'b0};
  // imm_Z — единственная константа, расширяемая нулями.
  assign imm_z = {27'b0, instr_i[19:15]};

  // ----- АЛУ и мультиплексоры операндов -----
  logic [31:0] alu_a, alu_b, alu_result;
  logic        alu_flag;

  always_comb begin
    case (a_sel)
      OP_A_RS1:     alu_a = rs1_data;
      OP_A_CURR_PC: alu_a = pc;
      default:      alu_a = 32'd0;   // OP_A_ZERO
    endcase
  end

  always_comb begin
    case (b_sel)
      OP_B_RS2:   alu_b = rs2_data;
      OP_B_IMM_I: alu_b = imm_i;
      OP_B_IMM_U: alu_b = imm_u;
      OP_B_IMM_S: alu_b = imm_s;
      default:    alu_b = 32'd4;     // OP_B_INCR
    endcase
  end

  alu i_alu (
    .a_i      (alu_a),
    .b_i      (alu_b),
    .alu_op_i (alu_op),
    .flag_o   (alu_flag),
    .result_o (alu_result)
  );

  // ----- Подсистема прерываний и CSR -----
  logic [31:0] csr_rdata, mie, mepc, mtvec, irq_cause, mcause_in;
  logic        irq_pending, trap;

  interrupt_controller i_irq (
    .clk_i       (clk_i),
    .rst_i       (rst_i),
    .exception_i (illegal),
    .irq_req_i   (irq_req_i),
    .mie_i       (mie[16]),
    .mret_i      (mret),
    .irq_ret_o   (irq_ret_o),
    .irq_cause_o (irq_cause),
    .irq_o       (irq_pending)
  );

  assign trap      = irq_pending | illegal;
  assign mcause_in = illegal ? 32'h2 : irq_cause;

  csr_controller i_csr (
    .clk_i          (clk_i),
    .rst_i          (rst_i),
    .trap_i         (trap),
    .opcode_i       (csr_op),
    .addr_i         (instr_i[31:20]),
    .pc_i           (pc),
    .mcause_i       (mcause_in),
    .rs1_data_i     (rs1_data),
    .imm_data_i     (imm_z),
    .write_enable_i (csr_we),
    .read_data_o    (csr_rdata),
    .mie_o          (mie),
    .mepc_o         (mepc),
    .mtvec_o        (mtvec)
  );

  // ----- Интерфейс памяти данных -----
  assign mem_addr_o = alu_result;
  assign mem_wd_o   = rs2_data;
  assign mem_size_o = mem_size_dec;
  assign mem_req_o  = mem_req_dec & ~trap;
  assign mem_we_o   = mem_we_dec  & ~trap;

  // ----- Мультиплексор источника записи в регистровый файл -----
  always_comb begin
    case (wb_sel)
      WB_LSU_DATA: rf_wd = mem_rd_i;
      WB_CSR_DATA: rf_wd = csr_rdata;
      default:     rf_wd = alu_result;  // WB_EX_RESULT
    endcase
  end

  // Запись в РФ запрещена при ожидании памяти и при трапе.
  assign rf_we = gpr_we & ~(stall_i | trap);

  // ----- Логика программного счётчика -----
  logic [31:0] jalr_target, pc_offset, pc_seq, pc_next_normal, pc_next;

  assign jalr_target    = rs1_data + imm_i;
  // Слагаемое PC: для перехода — соответствующая константа, иначе +4.
  assign pc_offset      = ((alu_flag & branch) | jal) ? (branch ? imm_b : imm_j) : 32'd4;
  // jalr задаёт новый адрес rs1+imm с обнулением младшего бита.
  assign pc_seq         = jalr ? {jalr_target[31:1], 1'b0} : (pc + pc_offset);
  // При трапе переход на обработчик (mtvec), при mret — возврат (mepc).
  assign pc_next_normal = trap ? mtvec : pc_seq;
  assign pc_next        = mret ? mepc  : pc_next_normal;

  logic pc_enable;
  assign pc_enable = ~stall_i | trap;

  always_ff @(posedge clk_i or posedge rst_i) begin
    if      (rst_i)     pc <= 32'd0;
    else if (pc_enable) pc <= pc_next;
  end

endmodule
