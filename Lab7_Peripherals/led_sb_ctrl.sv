// Контроллер светодиодов (ЛР7 / ЛР13).
// Регистр led_val (0x00) выводится на led_o. Регистр led_mode (0x04) включает
// режим "моргания" (1 секунда горит, 1 секунда — нет) при тактовой частоте 10 МГц.
// Адрес 0x24 — сброс регистров.
module led_sb_ctrl(
  // Системная шина
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        req_i,
  input  logic        write_enable_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  output logic [31:0] read_data_o,
  // Периферия
  output logic [15:0] led_o
);

  // Полупериод "моргания": при 10 МГц это 10^7 тактов (1 секунда).
  localparam int unsigned HALF_PERIOD = 10_000_000;
  localparam int unsigned FULL_PERIOD = 2 * HALF_PERIOD;

  logic [15:0] led_val;
  logic        led_mode;
  logic [31:0] blink_cnt;

  // Запрос на запись/чтение.
  logic wr, rd;
  assign wr = req_i &  write_enable_i;
  assign rd = req_i & ~write_enable_i;

  // Сигнал сброса контроллера: внешний сброс или запись 1 по адресу 0x24.
  logic local_rst;
  assign local_rst = rst_i | (wr & (addr_i == 32'h24) & (write_data_i == 32'd1));

  // Регистр выводимого значения (0x00).
  always_ff @(posedge clk_i) begin
    if (local_rst)                          led_val <= 16'd0;
    else if (wr & (addr_i == 32'h00))       led_val <= write_data_i[15:0];
  end

  // Регистр режима "моргания" (0x04).
  always_ff @(posedge clk_i) begin
    if (local_rst)                          led_mode <= 1'b0;
    else if (wr & (addr_i == 32'h04))       led_mode <= write_data_i[0];
  end

  // Счётчик "моргания": активен только при led_mode == 1.
  always_ff @(posedge clk_i) begin
    if (local_rst | ~led_mode)              blink_cnt <= 32'd0;
    else if (blink_cnt == FULL_PERIOD - 1)  blink_cnt <= 32'd0;
    else                                    blink_cnt <= blink_cnt + 32'd1;
  end

  // В первой половине периода светодиоды горят, во второй — гаснут.
  assign led_o = (blink_cnt < HALF_PERIOD) ? led_val : 16'd0;

  // Синхронное чтение регистров.
  always_ff @(posedge clk_i) begin
    if (rst_i)
      read_data_o <= 32'd0;
    else if (rd) begin
      case (addr_i)
        32'h00:  read_data_o <= {16'd0, led_val};
        32'h04:  read_data_o <= {31'd0, led_mode};
        default: read_data_o <= read_data_o;
      endcase
    end
  end

endmodule
