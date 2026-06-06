// Память данных (ОЗУ) процессорной системы (ЛР6).
// Синхронное чтение (1 такт) и побайтовая синхронная запись.
module data_mem
import memory_pkg::DATA_MEM_SIZE_WORDS;
(
  input  logic        clk_i,
  input  logic        mem_req_i,
  input  logic        write_enable_i,
  input  logic [ 3:0] byte_enable_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  output logic [31:0] read_data_o,
  output logic        ready_o
);

  localparam ADDR_W = $clog2(DATA_MEM_SIZE_WORDS);

  logic [31:0]        ram [DATA_MEM_SIZE_WORDS];
  logic [ADDR_W-1:0]  word_addr;

  // Адрес слова: отбрасываем 2 младших (байтовых) бита.
  assign word_addr = addr_i[ADDR_W+1:2];

  // Блочная память ПЛИС отвечает за 1 такт — всегда готова.
  assign ready_o = 1'b1;

  // Синхронное чтение (значение удерживается при записи/без запроса).
  always_ff @(posedge clk_i) begin
    if (mem_req_i && !write_enable_i)
      read_data_o <= ram[word_addr];
  end

  // Синхронная побайтовая запись.
  always_ff @(posedge clk_i) begin
    if (mem_req_i && write_enable_i) begin
      if (byte_enable_i[0]) ram[word_addr][ 7: 0] <= write_data_i[ 7: 0];
      if (byte_enable_i[1]) ram[word_addr][15: 8] <= write_data_i[15: 8];
      if (byte_enable_i[2]) ram[word_addr][23:16] <= write_data_i[23:16];
      if (byte_enable_i[3]) ram[word_addr][31:24] <= write_data_i[31:24];
    end
  end

endmodule
