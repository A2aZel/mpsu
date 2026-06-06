// Декодер инструкций однотактного процессора RISC-V (RV32I + Zicsr + mret) (ЛР5).
// Чисто комбинационная схема: один always_comb с вложенными case по opcode/func3/func7.
module decoder (
  input  logic [31:0]  fetched_instr_i,
  output logic [1:0]   a_sel_o,
  output logic [2:0]   b_sel_o,
  output logic [4:0]   alu_op_o,
  output logic [2:0]   csr_op_o,
  output logic         csr_we_o,
  output logic         mem_req_o,
  output logic         mem_we_o,
  output logic [2:0]   mem_size_o,
  output logic         gpr_we_o,
  output logic [1:0]   wb_sel_o,
  output logic         illegal_instr_o,
  output logic         branch_o,
  output logic         jal_o,
  output logic         jalr_o,
  output logic         mret_o
);
  import decoder_pkg::*;

  logic [4:0] opcode;
  logic [2:0] func3;
  logic [6:0] func7;

  assign opcode = fetched_instr_i[6:2];
  assign func3  = fetched_instr_i[14:12];
  assign func7  = fetched_instr_i[31:25];

  always_comb begin
    // Значения по умолчанию = пропуск нелегальной инструкции:
    // ничего не пишется, переходов нет.
    a_sel_o         = OP_A_RS1;
    b_sel_o         = OP_B_RS2;
    alu_op_o        = ALU_ADD;
    csr_op_o        = 3'b000;
    csr_we_o        = 1'b0;
    mem_req_o       = 1'b0;
    mem_we_o        = 1'b0;
    mem_size_o      = 3'b011;
    gpr_we_o        = 1'b0;
    wb_sel_o        = WB_EX_RESULT;
    illegal_instr_o = 1'b1;
    branch_o        = 1'b0;
    jal_o           = 1'b0;
    jalr_o          = 1'b0;
    mret_o          = 1'b0;

    // Два младших бита 7-битного opcode всегда должны быть 11.
    if (fetched_instr_i[1:0] == 2'b11) begin
      case (opcode)
        // ----- Регистровые операции (R-тип) -----
        OP_OPCODE: begin
          a_sel_o  = OP_A_RS1;
          b_sel_o  = OP_B_RS2;
          gpr_we_o = 1'b1;
          wb_sel_o = WB_EX_RESULT;
          illegal_instr_o = 1'b0;
          case (func3)
            3'h0: case (func7)
                    7'h00:   alu_op_o = ALU_ADD;
                    7'h20:   alu_op_o = ALU_SUB;
                    default: begin alu_op_o = ALU_ADD; illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
                  endcase
            3'h1: if (func7 == 7'h00) alu_op_o = ALU_SLL;
                  else begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
            3'h2: if (func7 == 7'h00) alu_op_o = ALU_SLTS;
                  else begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
            3'h3: if (func7 == 7'h00) alu_op_o = ALU_SLTU;
                  else begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
            3'h4: if (func7 == 7'h00) alu_op_o = ALU_XOR;
                  else begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
            3'h5: case (func7)
                    7'h00:   alu_op_o = ALU_SRL;
                    7'h20:   alu_op_o = ALU_SRA;
                    default: begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
                  endcase
            3'h6: if (func7 == 7'h00) alu_op_o = ALU_OR;
                  else begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
            3'h7: if (func7 == 7'h00) alu_op_o = ALU_AND;
                  else begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
          endcase
        end

        // ----- Операции с непосредственным операндом (I-тип) -----
        OP_IMM_OPCODE: begin
          a_sel_o  = OP_A_RS1;
          b_sel_o  = OP_B_IMM_I;
          gpr_we_o = 1'b1;
          wb_sel_o = WB_EX_RESULT;
          illegal_instr_o = 1'b0;
          case (func3)
            3'h0: alu_op_o = ALU_ADD;   // ADDI
            3'h2: alu_op_o = ALU_SLTS;  // SLTI
            3'h3: alu_op_o = ALU_SLTU;  // SLTIU
            3'h4: alu_op_o = ALU_XOR;   // XORI
            3'h6: alu_op_o = ALU_OR;    // ORI
            3'h7: alu_op_o = ALU_AND;   // ANDI
            3'h1: if (func7 == 7'h00) alu_op_o = ALU_SLL;  // SLLI
                  else begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
            3'h5: case (func7)                              // SRLI / SRAI
                    7'h00:   alu_op_o = ALU_SRL;
                    7'h20:   alu_op_o = ALU_SRA;
                    default: begin illegal_instr_o = 1'b1; gpr_we_o = 1'b0; end
                  endcase
          endcase
        end

        // ----- Загрузка из памяти (I-тип) -----
        LOAD_OPCODE: begin
          a_sel_o    = OP_A_RS1;
          b_sel_o    = OP_B_IMM_I;
          alu_op_o   = ALU_ADD;
          mem_req_o  = 1'b1;
          mem_size_o = func3;
          gpr_we_o   = 1'b1;
          wb_sel_o   = WB_LSU_DATA;
          case (func3)
            LDST_B, LDST_H, LDST_W, LDST_BU, LDST_HU: illegal_instr_o = 1'b0;
            default: begin illegal_instr_o = 1'b1; mem_req_o = 1'b0; gpr_we_o = 1'b0; end
          endcase
        end

        // ----- Запись в память (S-тип) -----
        STORE_OPCODE: begin
          a_sel_o    = OP_A_RS1;
          b_sel_o    = OP_B_IMM_S;
          alu_op_o   = ALU_ADD;
          mem_req_o  = 1'b1;
          mem_we_o   = 1'b1;
          mem_size_o = func3;
          wb_sel_o   = WB_EX_RESULT;
          case (func3)
            LDST_B, LDST_H, LDST_W: illegal_instr_o = 1'b0;
            default: begin illegal_instr_o = 1'b1; mem_req_o = 1'b0; mem_we_o = 1'b0; end
          endcase
        end

        // ----- Условные переходы (B-тип) -----
        BRANCH_OPCODE: begin
          a_sel_o  = OP_A_RS1;
          b_sel_o  = OP_B_RS2;
          branch_o = 1'b1;
          illegal_instr_o = 1'b0;
          case (func3)
            3'h0: alu_op_o = ALU_EQ;
            3'h1: alu_op_o = ALU_NE;
            3'h4: alu_op_o = ALU_LTS;
            3'h5: alu_op_o = ALU_GES;
            3'h6: alu_op_o = ALU_LTU;
            3'h7: alu_op_o = ALU_GEU;
            default: begin illegal_instr_o = 1'b1; branch_o = 1'b0; end
          endcase
        end

        // ----- Безусловный переход JAL (J-тип) -----
        JAL_OPCODE: begin
          a_sel_o  = OP_A_CURR_PC;
          b_sel_o  = OP_B_INCR;
          alu_op_o = ALU_ADD;
          gpr_we_o = 1'b1;
          wb_sel_o = WB_EX_RESULT;
          jal_o    = 1'b1;
          illegal_instr_o = 1'b0;
        end

        // ----- Безусловный переход JALR (I-тип) -----
        JALR_OPCODE: begin
          if (func3 == 3'h0) begin
            a_sel_o  = OP_A_CURR_PC;
            b_sel_o  = OP_B_INCR;
            alu_op_o = ALU_ADD;
            gpr_we_o = 1'b1;
            wb_sel_o = WB_EX_RESULT;
            jalr_o   = 1'b1;
            illegal_instr_o = 1'b0;
          end
        end

        // ----- Загрузка верхнего непосредственного (U-тип) -----
        LUI_OPCODE: begin
          a_sel_o  = OP_A_ZERO;
          b_sel_o  = OP_B_IMM_U;
          alu_op_o = ALU_ADD;
          gpr_we_o = 1'b1;
          wb_sel_o = WB_EX_RESULT;
          illegal_instr_o = 1'b0;
        end

        // ----- PC + непосредственный (U-тип) -----
        AUIPC_OPCODE: begin
          a_sel_o  = OP_A_CURR_PC;
          b_sel_o  = OP_B_IMM_U;
          alu_op_o = ALU_ADD;
          gpr_we_o = 1'b1;
          wb_sel_o = WB_EX_RESULT;
          illegal_instr_o = 1'b0;
        end

        // ----- MISC-MEM (FENCE = NOP) -----
        MISC_MEM_OPCODE: begin
          if (func3 == 3'h0) illegal_instr_o = 1'b0;  // FENCE -> ничего не делает
        end

        // ----- Системные инструкции (Zicsr / mret) -----
        SYSTEM_OPCODE: begin
          case (func3)
            3'h0: begin
              // ecall / ebreak вызывают исключение (illegal), mret — возврат.
              if (fetched_instr_i == 32'h30200073) begin
                mret_o          = 1'b1;
                illegal_instr_o = 1'b0;
              end
            end
            3'h4: ; // зарезервировано — нелегальная
            default: begin
              csr_op_o = func3;
              csr_we_o = 1'b1;
              gpr_we_o = 1'b1;
              wb_sel_o = WB_CSR_DATA;
              illegal_instr_o = 1'b0;
            end
          endcase
        end

        default: ; // нелегальный opcode — значения по умолчанию
      endcase
    end
  end

endmodule
