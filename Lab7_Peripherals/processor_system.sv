// Процессорная система с периферией (ЛР7 / ЛР13).
// Вариант периферии: Переключатели (0x01) + Светодиоды (0x02).
// Содержит делитель частоты, системную шину с one-hot дешифратором адреса,
// ядро, память инструкций, LSU, память данных и контроллеры периферии.
module processor_system(
  input  logic        clk_i,
  input  logic        resetn_i,

  // Периферия
  input  logic [15:0] sw_i,       // Переключатели
  output logic [15:0] led_o,      // Светодиоды

  input  logic        kclk_i,     // Клавиатура (не используется в этом варианте)
  input  logic        kdata_i,

  output logic [ 6:0] hex_led_o,  // Семисегментные индикаторы (не используются)
  output logic [ 7:0] hex_sel_o,

  input  logic        rx_i,       // UART (не используется)
  output logic        tx_o,

  output logic [ 3:0] vga_r_o,    // VGA (не используется)
  output logic [ 3:0] vga_g_o,
  output logic [ 3:0] vga_b_o,
  output logic        vga_hs_o,
  output logic        vga_vs_o
);

  import peripheral_pkg::*;

  // ----- Делитель частоты и генератор сброса (10 МГц, активный уровень rst = 1) -----
  logic sysclk, rst;
  sys_clk_rst_gen divider (
    .ex_clk_i      (clk_i),
    .ex_areset_n_i (resetn_i),
    .div_i         (5),
    .sys_clk_o     (sysclk),
    .sys_reset_o   (rst)
  );

  // ----- Связи ядра -----
  logic [31:0] instr_addr, instr;
  logic [31:0] core_mem_addr, core_mem_wd, core_mem_rd;
  logic [ 2:0] core_mem_size;
  logic        core_mem_req, core_mem_we, core_stall;

  logic        irq_req, irq_ret;

  processor_core core (
    .clk_i        (sysclk),
    .rst_i        (rst),
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

  // ----- LSU и системная шина -----
  logic        bus_req, bus_we;
  logic [ 3:0] bus_be;
  logic [31:0] bus_addr, bus_wd, bus_rd;

  lsu lsu (
    .clk_i        (sysclk),
    .rst_i        (rst),
    .core_req_i   (core_mem_req),
    .core_we_i    (core_mem_we),
    .core_size_i  (core_mem_size),
    .core_addr_i  (core_mem_addr),
    .core_wd_i    (core_mem_wd),
    .core_rd_o    (core_mem_rd),
    .core_stall_o (core_stall),
    .mem_req_o    (bus_req),
    .mem_we_o     (bus_we),
    .mem_be_o     (bus_be),
    .mem_addr_o   (bus_addr),
    .mem_wd_o     (bus_wd),
    .mem_rd_i     (bus_rd),
    .mem_ready_i  (1'b1)
  );

  // One-hot дешифратор по старшим 8 битам адреса.
  logic [255:0] dev_sel;
  assign dev_sel = 256'd1 << bus_addr[31:24];

  // Адрес с обнулённой старшей частью передаётся периферии.
  logic [31:0] periph_addr;
  assign periph_addr = {8'd0, bus_addr[23:0]};

  // Сигналы запроса к устройствам.
  logic dmem_req, sw_req, led_req;
  assign dmem_req = bus_req & dev_sel[DMEM_ADDR_HIGH];
  assign sw_req   = bus_req & dev_sel[SW_ADDR_HIGH];
  assign led_req  = bus_req & dev_sel[LED_ADDR_HIGH];

  // ----- Память данных (0x00) -----
  logic [31:0] dmem_rd;
  data_mem data_mem (
    .clk_i          (sysclk),
    .mem_req_i      (dmem_req),
    .write_enable_i (bus_we),
    .byte_enable_i  (bus_be),
    .addr_i         (bus_addr),
    .write_data_i   (bus_wd),
    .read_data_o    (dmem_rd),
    .ready_o        ()
  );

  // ----- Контроллер переключателей (0x01) -----
  logic [31:0] sw_rd;
  sw_sb_ctrl sw_ctrl (
    .clk_i               (sysclk),
    .rst_i               (rst),
    .req_i               (sw_req),
    .write_enable_i      (bus_we),
    .addr_i              (periph_addr),
    .write_data_i        (bus_wd),
    .read_data_o         (sw_rd),
    .interrupt_request_o (irq_req),
    .interrupt_return_i  (irq_ret),
    .sw_i                (sw_i)
  );

  // ----- Контроллер светодиодов (0x02) -----
  logic [31:0] led_rd;
  led_sb_ctrl led_ctrl (
    .clk_i          (sysclk),
    .rst_i          (rst),
    .req_i          (led_req),
    .write_enable_i (bus_we),
    .addr_i         (periph_addr),
    .write_data_i   (bus_wd),
    .read_data_o    (led_rd),
    .led_o          (led_o)
  );

  // Мультиплексор данных чтения обратно в LSU (по старшей части адреса).
  always_comb begin
    case (bus_addr[31:24])
      SW_ADDR_HIGH:  bus_rd = sw_rd;
      LED_ADDR_HIGH: bus_rd = led_rd;
      default:       bus_rd = dmem_rd;  // DMEM_ADDR_HIGH
    endcase
  end

  // Неиспользуемые в данном варианте выходы периферии.
  assign hex_led_o = 7'd0;
  assign hex_sel_o = 8'd0;
  assign tx_o      = 1'b1;
  assign vga_r_o   = 4'd0;
  assign vga_g_o   = 4'd0;
  assign vga_b_o   = 4'd0;
  assign vga_hs_o  = 1'b0;
  assign vga_vs_o  = 1'b0;

endmodule
