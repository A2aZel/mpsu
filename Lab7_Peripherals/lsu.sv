// Блок загрузки и сохранения (Load-Store Unit) (ЛР6).
// Преобразует запросы ядра (байт/полуслово/слово) в обращения к памяти данных,
// формирует byte enable, выравнивает и расширяет считанные данные,
// а также вырабатывает сигнал stall на время обращения в память.
module lsu(
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        core_req_i,
  input  logic        core_we_i,
  input  logic [ 2:0] core_size_i,
  input  logic [31:0] core_addr_i,
  input  logic [31:0] core_wd_i,
  output logic [31:0] core_rd_o,
  output logic        core_stall_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [ 3:0] mem_be_o,
  output logic [31:0] mem_addr_o,
  output logic [31:0] mem_wd_o,
  input  logic [31:0] mem_rd_i,
  input  logic        mem_ready_i
);

  import decoder_pkg::*;

  // Один такт на обращение к блочной памяти: stall активен ровно один такт.
  logic enable;
  assign core_stall_o = core_req_i & ~enable & mem_ready_i;

  always_ff @(posedge clk_i) begin
    if (rst_i) enable <= 1'b0;
    else       enable <= core_stall_o;
  end

  logic [1:0] byte_off;
  logic       half_off;
  assign byte_off = core_addr_i[1:0];
  assign half_off = core_addr_i[1];

  // Прозрачная передача запроса в память.
  assign mem_req_o  = core_req_i;
  assign mem_we_o   = core_we_i;
  assign mem_addr_o = core_addr_i;

  // Формирование byte enable в зависимости от размера и смещения.
  always_comb begin
    case (core_size_i)
      LDST_B, LDST_BU: mem_be_o = 4'b0001 << byte_off;
      LDST_H, LDST_HU: mem_be_o = half_off ? 4'b1100 : 4'b0011;
      default:         mem_be_o = 4'b1111;  // LDST_W
    endcase
  end

  // Данные для записи дублируются по всем подходящим байтовым линиям.
  always_comb begin
    case (core_size_i)
      LDST_B, LDST_BU: mem_wd_o = {4{core_wd_i[ 7:0]}};
      LDST_H, LDST_HU: mem_wd_o = {2{core_wd_i[15:0]}};
      default:         mem_wd_o = core_wd_i;  // LDST_W
    endcase
  end

  // Выбор нужного байта/полуслова из считанного слова.
  logic [ 7:0] byte_data;
  logic [15:0] half_data;

  always_comb begin
    case (byte_off)
      2'd0:    byte_data = mem_rd_i[ 7: 0];
      2'd1:    byte_data = mem_rd_i[15: 8];
      2'd2:    byte_data = mem_rd_i[23:16];
      default: byte_data = mem_rd_i[31:24];
    endcase
  end

  assign half_data = half_off ? mem_rd_i[31:16] : mem_rd_i[15:0];

  // Расширение считанных данных (знаковое/беззнаковое).
  always_comb begin
    case (core_size_i)
      LDST_B:  core_rd_o = {{24{byte_data[7]}},  byte_data};
      LDST_BU: core_rd_o = {24'b0,               byte_data};
      LDST_H:  core_rd_o = {{16{half_data[15]}}, half_data};
      LDST_HU: core_rd_o = {16'b0,               half_data};
      default: core_rd_o = mem_rd_i;  // LDST_W
    endcase
  end

endmodule
