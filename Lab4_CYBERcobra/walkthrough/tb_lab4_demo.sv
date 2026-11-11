`timescale 1ns/1ps

// One-input teaching demonstration; the exhaustive self-check remains separate.
module tb_lab4_demo;
  logic clk = 1'b0;
  logic rst = 1'b1;
  // Change this HEX value, save, and Relaunch Simulation to try another input.
  logic [15:0] sw = 16'h03b8;
  wire [31:0] out;
  integer ordinary_step = 0;
  integer checks = 0;
  logic test_pass = 1'b0;
  logic [31:0] expected_result;
  logic [15:0] sampled_sw;
  logic [31:0] input_word;
  logic [31:0] remaining_word;
  integer iterations;
  integer terminal_step;
  integer completed_iterations;

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

  // Stop scheduling clock edges after success. Resuming the GUI after $finish
  // must neither fail the watchdog nor run forever on an unnecessary clock.
  initial begin
    while (!test_pass) begin
      #10;
      clk = ~clk;
    end
  end

  always @(posedge clk) begin
    if (rst) ordinary_step <= 0;
    else     ordinary_step <= ordinary_step + 1;
  end

  // Independent reference: select bits of the original operand directly.
  // It does not use DUT registers or repeat the program's shift/OR algorithm.
  function automatic [31:0] packed_even(input [31:0] operand,
                                      input integer count);
    integer k;
    begin
      packed_even = 32'b0;
      for (k = 0; k < count; k = k + 1)
        packed_even[k] = operand[2*k];
    end
  endfunction

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
    // Optional command-line override for automated checks; GUI users edit sw.
    if ($value$plusargs("SW=%h", sw)) begin end
    repeat (2) @(posedge clk);
    #1;
    expect32(pc, 32'd0, "synchronous reset PC");
    // Deassert away from the sampling edge; RF initialization belongs to the program.
    @(negedge clk);
    if ((^sw) === 1'bx) $fatal(1, "DEMO_FAIL sw contains unknown bits");
    sampled_sw = sw;
    input_word = {{16{sampled_sw[15]}}, sampled_sw};
    expected_result = packed_even(input_word, 16);
    remaining_word = input_word;
    iterations = 0;
    // The assembly loop runs once even when the input is zero.
    do begin
      iterations = iterations + 1;
      remaining_word = remaining_word >> 2;
    end while (remaining_word != 0);
    terminal_step = 5 + 6 * iterations;
    rst = 1'b0;

    repeat (terminal_step + 2) begin
      @(posedge clk);
      #1;
      case (ordinary_step)
        1: begin
          expect32(pc, 32'h04, "after IN");
          expect32(r2, input_word, "input loaded into r2");
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
        default: begin
          if (ordinary_step <= terminal_step && (ordinary_step - 5) % 6 == 0) begin
            completed_iterations = (ordinary_step - 5) / 6;
            checkpoint(completed_iterations == iterations ? 32'h2c : 32'h14,
                       packed_even(input_word, completed_iterations),
                       input_word >> (2 * completed_iterations),
                       completed_iterations,
                       input_word[2 * (completed_iterations - 1)]
                         ? (32'd1 << (completed_iterations - 1)) : 32'd0);
            if (ordinary_step == terminal_step) begin
              expect32(out, expected_result, "final output");
              expect32({31'b0, we}, 32'd0, "terminal J0 inhibits writes");
              expect32(pc_next, 32'h2c, "terminal J0 target");
            end
          end else if (ordinary_step > terminal_step) begin
            expect32(pc, 32'h2c, "J0 holds PC");
            expect32(out, expected_result, "J0 holds output");
          end
        end
      endcase
    end

    test_pass = 1'b1;
    $display("DEMO_PASS SW=%04h OUT=%08h PC=%08h after %0d ordinary steps; J0 stable for 2 extra steps; checks=%0d",
             sampled_sw, out, pc, terminal_step, checks);
    #79;
    $finish;
  end

  initial begin
    #3000;
    if (!test_pass) $fatal(1, "DEMO_FAIL watchdog expired");
  end
endmodule
