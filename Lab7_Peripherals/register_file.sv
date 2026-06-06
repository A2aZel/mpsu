// Регистровый файл процессора RISC-V (ЛР3).
// Трёхпортовое ОЗУ: 2 асинхронных порта чтения и 1 синхронный порт записи.
// 32 регистра по 32 бита. Регистр x0 — аппаратный ноль.
module register_file(
  input  logic        clk_i,
  input  logic        write_enable_i,

  input  logic [ 4:0] write_addr_i,
  input  logic [ 4:0] read_addr1_i,
  input  logic [ 4:0] read_addr2_i,

  input  logic [31:0] write_data_i,
  output logic [31:0] read_data1_o,
  output logic [31:0] read_data2_o
);

  // Массив регистров (имя rf_mem требуется верификационным окружением).
  logic [31:0] rf_mem [0:31];

  // Синхронная запись; запись в x0 запрещена.
  always_ff @(posedge clk_i) begin
    if (write_enable_i && (write_addr_i != 5'd0))
      rf_mem[write_addr_i] <= write_data_i;
  end

  // Асинхронное чтение; по нулевому адресу всегда возвращается 0.
  assign read_data1_o = (read_addr1_i == 5'd0) ? 32'd0 : rf_mem[read_addr1_i];
  assign read_data2_o = (read_addr2_i == 5'd0) ? 32'd0 : rf_mem[read_addr2_i];

endmodule
