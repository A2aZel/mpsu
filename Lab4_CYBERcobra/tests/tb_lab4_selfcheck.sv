`timescale 1ns/1ps

module tb_lab4_selfcheck;
  import alu_opcodes_pkg::*;
  logic clk = 1'b0;
  logic rst = 1'b0;
  logic [15:0] sw = 16'b0;
  wire [31:0] out;
  integer checks = 0;
  integer program_cases = 0;
  integer low16 = 0;
  integer exhaustive = 0;
  logic test_pass = 1'b0;
  integer value;
  reg [31:0] program_image [0:127];

  CYBERcobra DUT(.clk_i(clk), .rst_i(rst), .sw_i(sw), .out_o(out));

  function automatic [31:0] li(input integer imm, input [4:0] dest);
    li = {4'b0000, imm[22:0], dest};
  endfunction

  function automatic [31:0] op(input [4:0] code, input [4:0] src1,
                             input [4:0] src2, input [4:0] dest);
    op = {4'b0001, code, src1, src2, 8'b0, dest};
  endfunction

  function automatic [31:0] branch(input bit jump, input bit cond,
                                  input [4:0] code, input [4:0] src1,
                                  input [4:0] src2, input [7:0] displacement,
                                  input [4:0] dest);
    branch = {jump, cond, 2'b00, code, src1, src2, displacement, dest};
  endfunction

  function automatic [31:0] packed_even(input [15:0] switches, input bit only16);
    reg [31:0] operand;
    integer k;
    begin
      operand = {{16{switches[15]}}, switches};
      packed_even = 32'b0;
      for (k = 0; k < 16; k = k + 1)
        if (!only16 || k < 8) packed_even[k] = operand[2*k];
    end
  endfunction

  task automatic expect32(input [31:0] actual, input [31:0] expected,
                          input string label_text);
    begin
      checks = checks + 1;
      if (actual !== expected)
        $fatal(1, "%s: got %08h, expected %08h; PC=%08h instr=%08h",
               label_text, actual, expected, DUT.pc, DUT.instr);
    end
  endtask

  task automatic tick;
    begin
      #1; clk = 1'b1;
      #1; clk = 1'b0;
      #1;
    end
  endtask

  task automatic reset_cpu;
    begin
      rst = 1'b1;
      tick();
      rst = 1'b0;
      #1;
    end
  endtask

  task automatic directed_core;
    integer i;
    begin
      for (i = 0; i < 128; i = i + 1) DUT.imem.ROM[i] = 32'h80000000;
      DUT.imem.ROM[0] = li(-1, 1);
      DUT.imem.ROM[1] = li(-4194304, 2);
      DUT.imem.ROM[2] = {4'b0010, 23'b0, 5'd3};
      DUT.imem.ROM[3] = {4'b0011, 5'b0, 5'd1, 5'd0, 8'b0, 5'd4};
      DUT.imem.ROM[4] = op(ALU_ADD, 1, 2, 5);
      DUT.imem.ROM[5] = op(ALU_ADD, 1, 2, 0);
      DUT.imem.ROM[6] = branch(0, 1, ALU_EQ, 1, 1, 8'd2, 1);
      DUT.imem.ROM[7] = li(123, 1);
      DUT.imem.ROM[8] = branch(0, 1, ALU_NE, 1, 1, 8'd2, 1);
      DUT.imem.ROM[9] = branch(1, 0, ALU_ADD, 1, 2, 8'd2, 2);
      DUT.imem.ROM[10] = li(555, 2);
      DUT.imem.ROM[11] = op(ALU_SUB, 1, 2, 6);
      DUT.imem.ROM[12] = branch(1, 0, ALU_ADD, 1, 2, 8'hff, 2);
      sw = 16'h8000;
      reset_cpu();
      expect32(DUT.pc, 0, "reset PC");
      tick(); expect32(DUT.pc, 4, "sequential PC + 4");
      expect32(DUT.rf.rf_mem[1], 32'hffffffff, "LI -1 sign extension23");
      tick(); expect32(DUT.rf.rf_mem[2], 32'hffc00000, "LI minimum23");
      tick(); expect32(DUT.rf.rf_mem[3], 32'hffff8000, "IN sign extension16");
      expect32(out, 32'hffffffff, "out is asynchronous RA1");
      tick(); expect32(DUT.rf.rf_mem[4], 0, "WS11 default zero");
      tick(); expect32(DUT.rf.rf_mem[5], 32'hffbfffff, "WS01 ALU ADD");
      tick(); expect32(DUT.rf.read_data2_o, 32'hffffffff, "branch reads register1 after attempted x0 write");
      expect32({31'b0, DUT.we}, 0, "B inhibits write when taken");
      tick(); expect32(DUT.pc, 32, "taken branch relative to current PC");
      expect32(DUT.rf.rf_mem[1], 32'hffffffff, "taken B preserves destination");
      expect32({31'b0, DUT.we}, 0, "B inhibits write when not taken");
      tick(); expect32(DUT.pc, 36, "untaken B falls through");
      expect32(DUT.rf.rf_mem[1], 32'hffffffff, "untaken B preserves destination");
      expect32({31'b0, DUT.we}, 0, "J inhibits write");
      tick(); expect32(DUT.pc, 44, "positive J displacement multiplied by4");
      expect32(DUT.rf.rf_mem[2], 32'hffc00000, "J preserves destination");
      tick(); expect32(DUT.rf.rf_mem[6], 32'h003fffff, "ALU SUB result");
      tick(); expect32(DUT.pc, 44, "negative J sign extension8");
      rst = 1'b1;
      #1;
      expect32(DUT.pc, 44, "reset is synchronous before edge");
      tick(); expect32(DUT.pc, 0, "reset acts at positive edge");
      rst = 1'b0;

      // Read x0 explicitly after the attempted write to address0.
      DUT.imem.ROM[0] = op(ALU_ADD, 0, 0, 7);
      #1; expect32(out, 0, "x0 always reads zero");
      tick(); expect32(DUT.rf.rf_mem[7], 0, "x0 ignores prior write");
      $display("PASS directed core: %0d assertions", checks);
    end
  endtask

  task automatic run_program(input [15:0] switches);
    integer cycles;
    reg [31:0] terminal_pc;
    reg [31:0] expected;
    begin
      sw = switches;
      reset_cpu();
      terminal_pc = low16 ? 32'd52 : 32'd44;
      cycles = 0;
      while ((DUT.pc !== terminal_pc) && cycles < 120) begin
        tick();
        cycles = cycles + 1;
      end
      if (DUT.pc !== terminal_pc)
        $fatal(1, "Program timeout: sw=%04h PC=%08h cycles=%0d", switches, DUT.pc, cycles);
      expected = packed_even(switches, low16 != 0);
      expect32(out, expected, $sformatf("variant12 sw=%04h low16=%0d", switches, low16));
      tick();
      expect32(DUT.pc, terminal_pc, "terminal J0 stays in place");
      expect32(out, expected, "terminal J0 preserves result");
      program_cases = program_cases + 1;
    end
  endtask

  initial begin
    if ($value$plusargs("LOW16=%d", low16)) begin end
    if ($value$plusargs("EXHAUSTIVE=%d", exhaustive)) begin end
    #1;
    for (value = 0; value < 128; value = value + 1) program_image[value] = DUT.imem.ROM[value];
    directed_core();
    for (value = 0; value < 128; value = value + 1) DUT.imem.ROM[value] = program_image[value];
    run_program(16'h0000);
    run_program(16'h0001);
    run_program(16'h0002);
    run_program(16'h03b8);
    run_program(16'h5555);
    run_program(16'haaaa);
    run_program(16'h7fff);
    run_program(16'h8000);
    run_program(16'hffff);
    if (exhaustive != 0) begin
      for (value = 0; value < 65536; value = value + 1) begin
        run_program(value[15:0]);
        if ((value & 8191) == 8191) $display("Progress: %0d / 65536 low16=%0d", value+1, low16);
      end
    end
    $display("PASS lab4 selfcheck: program_cases=%0d assertions=%0d LOW16=%0d EXHAUSTIVE=%0d",
             program_cases, checks, low16, exhaustive);
    test_pass = 1'b1;
    $finish;
  end

  initial begin
    #100000000;
    $fatal(1, "Global watchdog expired");
  end
endmodule
