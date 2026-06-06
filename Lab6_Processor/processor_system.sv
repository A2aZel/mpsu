// Процессорная система (ЛР6): ядро + память инструкций + LSU + память данных.
module processor_system(
  input  logic clk_i,
  input  logic rst_i
);

  // Связь ядра с памятью инструкций.
  logic [31:0] instr_addr;
  logic [31:0] instr;

  // Связь ядра с LSU.
  logic [31:0] core_mem_addr;
  logic [ 2:0] core_mem_size;
  logic        core_mem_req;
  logic        core_mem_we;
  logic [31:0] core_mem_wd;
  logic [31:0] core_mem_rd;
  logic        core_stall;

  // Связь LSU с памятью данных.
  logic        dmem_req;
  logic        dmem_we;
  logic [ 3:0] dmem_be;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wd;
  logic [31:0] dmem_rd;
  logic        dmem_ready;

  // Линии прерывания (подключаются к периферии в ЛР7).
  logic        irq_req;
  logic        irq_ret;

  processor_core core (
    .clk_i        (clk_i),
    .rst_i        (rst_i),
    .stall_i      (core_stall),
    .instr_i      (instr),
    .mem_rd_i     (core_mem_rd),
    .irq_req_i    (irq_req),
    .instr_addr_o (instr_addr),
    .mem_addr_o   (core_mem_addr),
    .mem_size_o   (core_mem_size),
    .mem_req_o    (core_mem_req),
    .mem_we_o     (core_mem_we),
    .mem_wd_o     (core_mem_wd),
    .irq_ret_o    (irq_ret)
  );

  instr_mem imem (
    .read_addr_i (instr_addr),
    .read_data_o (instr)
  );

  lsu lsu (
    .clk_i        (clk_i),
    .rst_i        (rst_i),
    .core_req_i   (core_mem_req),
    .core_we_i    (core_mem_we),
    .core_size_i  (core_mem_size),
    .core_addr_i  (core_mem_addr),
    .core_wd_i    (core_mem_wd),
    .core_rd_o    (core_mem_rd),
    .core_stall_o (core_stall),
    .mem_req_o    (dmem_req),
    .mem_we_o     (dmem_we),
    .mem_be_o     (dmem_be),
    .mem_addr_o   (dmem_addr),
    .mem_wd_o     (dmem_wd),
    .mem_rd_i     (dmem_rd),
    .mem_ready_i  (dmem_ready)
  );

  data_mem data_mem (
    .clk_i          (clk_i),
    .mem_req_i      (dmem_req),
    .write_enable_i (dmem_we),
    .byte_enable_i  (dmem_be),
    .addr_i         (dmem_addr),
    .write_data_i   (dmem_wd),
    .read_data_o    (dmem_rd),
    .ready_o        (dmem_ready)
  );

endmodule
