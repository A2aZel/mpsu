`timescale 1ns/1ps

// One-program teaching demonstration; the exhaustive self-check remains separate.
module tb_lab4_demo;
  logic clk = 1'b0;
  logic rst = 1'b1;
  logic [15:0] sw = 16'h03b8;
  wire [31:0] out;
  integer ordinary_step = 0;
  integer checks = 0;
  logic test_pass = 1'b0;

  CYBERcobra DUT(.clk_i(clk), .rst_i(rst), .sw_i(sw), .out_o(out));

  wire [31:0] pc         = DUT.pc;
  wire [31:0] instr      = DUT.instr;
  wire [4:0]  RA1        = DUT.RA1;
  wire [4:0]  RA2        = DUT.RA2;
  wire [4:0]  WA         = DUT.WA;
  wire [1:0]  WS         = DUT.WS;
  wire [31:0] rd1        = DUT.rd1;
  wire [31:0] rd2        = DUT.rd2;
  wire [4:0]  alu_op     = DUT.alu_op;
  wire [31:0] alu_result = DUT.alu_result;
  wire        alu_flag   = DUT.alu_flag;
  wire        we         = DUT.we;
  wire [31:0] write_data = DUT.write_data;
  wire [31:0] pc_next    = DUT.pc_next;
  wire [31:0] r1         = DUT.rf.rf_mem[1];
  wire [31:0] r2         = DUT.rf.rf_mem[2];
  wire [31:0] r4         = DUT.rf.rf_mem[4];
  wire [31:0] r6         = DUT.rf.rf_mem[6];

  always #10 clk = ~clk;

  always @(posedge clk) begin
    if (rst) ordinary_step <= 0;
    else     ordinary_step <= ordinary_step + 1;
  end

  task automatic expect32(input [31:0] actual, input [31:0] expected,
                          input string label_text);
    begin
      checks = checks + 1;
      if (actual !== expected)
        $fatal(1, "DEMO_FAIL step=%0d %s: got=%08h expected=%08h PC=%08h",
               ordinary_step, label_text, actual, expected, pc);
    end
  endtask

  task automatic checkpoint(input [31:0] expected_pc, input [31:0] expected_r1,
                            input [31:0] expected_r2, input [31:0] expected_r4,
                            input [31:0] expected_r6);
    begin
      expect32(pc, expected_pc, "PC");
      expect32(r1, expected_r1, "r1/result");
      expect32(r2, expected_r2, "r2/remaining input");
      expect32(r4, expected_r4, "r4/result position");
      expect32(r6, expected_r6, "r6/selected bit");
      $display("DEMO_CHECKPOINT step=%0d PC=%02h r1=%08h r2=%08h r4=%0d r6=%08h",
               ordinary_step, pc, r1, r2, r4, r6);
    end
  endtask

  initial begin
    repeat (2) @(posedge clk);
    #1;
    expect32(pc, 32'd0, "synchronous reset PC");
    // Deassert away from the sampling edge; RF initialization belongs to the program.
    @(negedge clk);
    rst = 1'b0;

    repeat (37) begin
      @(posedge clk);
      #1;
      case (ordinary_step)
        1: begin
          expect32(pc, 32'h04, "after IN");
          expect32(r2, 32'h03b8, "input loaded into r2");
        end
        2: begin
          expect32(pc, 32'h08, "after LI r1");
          expect32(r1, 32'h00, "result initialized");
        end
        3: begin
          expect32(pc, 32'h0c, "after LI r3");
          expect32(DUT.rf.rf_mem[3], 32'd1, "mask/increment initialized");
        end
        4: begin
          expect32(pc, 32'h10, "after LI r4");
          expect32(r4, 32'd0, "result position initialized");
        end
        5: begin
          expect32(pc, 32'h14, "after LI r5");
          expect32(DUT.rf.rf_mem[5], 32'd2, "input shift initialized");
        end
        11: checkpoint(32'h14, 32'h00, 32'h00ee, 32'd1, 32'h00);
        17: checkpoint(32'h14, 32'h00, 32'h003b, 32'd2, 32'h00);
        23: checkpoint(32'h14, 32'h04, 32'h000e, 32'd3, 32'h04);
        29: checkpoint(32'h14, 32'h04, 32'h0003, 32'd4, 32'h00);
        35: begin
          checkpoint(32'h2c, 32'h14, 32'h0000, 32'd5, 32'h10);
          expect32(out, 32'h14, "final output");
          expect32({31'b0, we}, 32'd0, "terminal J0 inhibits writes");
          expect32(pc_next, 32'h2c, "terminal J0 target");
        end
        36, 37: begin
          expect32(pc, 32'h2c, "J0 holds PC");
          expect32(out, 32'h14, "J0 holds output");
        end
        default: ;
      endcase
    end

    test_pass = 1'b1;
    $display("DEMO_PASS SW=03B8 OUT=00000014 PC=0000002C after 35 ordinary steps; J0 stable for 2 extra steps; checks=%0d", checks);
    #79;
    $finish;
  end

  initial begin
    #1000;
    $fatal(1, "DEMO_FAIL watchdog expired");
  end
endmodule
