/*
 * Module: control
 *
 * Description: This module sets the control bits (control path) based on the decoded
 * instruction. Note that this is part of the decode stage but housed in a separate
 * module for better readability, debug and design purposes.
 *
 * Inputs:
 * 1) DWIDTH instruction ins_i
 * 2) 7-bit opcode opcode_i
 * 3) 7-bit funct7 funct7_i
 * 4) 3-bit funct3 funct3_i
 *
 * Outputs:
 * 1) 1-bit PC select pcsel_o
 * 2) 1-bit Immediate select immsel_o
 * 3) 1-bit register write en regwren_o
 * 4) 1-bit rs1 select rs1sel_o
 * 5) 1-bit rs2 select rs2sel_o
 * 6) k-bit ALU select alusel_o
 * 7) 1-bit memory read en memren_o
 * 8) 1-bit memory write en memwren_o
 * 9) 2-bit writeback sel wbsel_o
 */

`include "constants.svh"

module control #(
    parameter int DWIDTH = 32
)(
    // Instruction fields from decode stage
    input  logic [DWIDTH-1:0] insn_i,
    input  logic [6:0]        opcode_i,
    input  logic [6:0]        funct7_i,
    input  logic [2:0]        funct3_i,

    // Control outputs to datapath
    output logic       pcsel_o,      // 0 = PC+4, 1 = branch/jump target
    output logic       immsel_o,     // 1 = instruction uses immediate
    output logic       regwren_o,    // register file write enable
    output logic       rs1sel_o,     // 0 = rs1, 1 = PC/zero (depends on datapath)
    output logic       rs2sel_o,     // 0 = rs2, 1 = immediate
    output logic       memren_o,     // data memory read enable
    output logic       memwren_o,    // data memory write enable
    output logic [1:0] wbsel_o,      // writeback mux select
    output logic [3:0] alusel_o      // ALU operation select
);

    // ------------------------------------------------------------
    // Default values (safe NOP-like behavior)
    // ------------------------------------------------------------
    always_comb begin : Control
        // Safe defaults: no memory, no writeback, PC+4
        pcsel_o   = 1'b0;
        immsel_o  = 1'b0;
        regwren_o = 1'b0;
        rs1sel_o  = 1'b0;
        rs2sel_o  = 1'b0;
        memren_o  = 1'b0;
        memwren_o = 1'b0;
        wbsel_o   = wbOFF;
        alusel_o  = ADD;

        unique case (opcode_i)

            // R-type: register-register ALU ops
            //   rd = rs1 (op) rs2
            RTYPE: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;   // PC+4
                immsel_o  = 1'b0;   // no immediate
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;   // src1 = rs1
                rs2sel_o  = 1'b0;   // src2 = rs2
                memren_o  = 1'b0;
                memwren_o = 1'b0;

                unique case (funct3_i)
                    3'h0: alusel_o = (funct7_i == 7'h20) ? SUB : ADD; // SUB vs ADD
                    3'h1: alusel_o = SLL;
                    3'h4: alusel_o = XOR;
                    3'h6: alusel_o = OR;
                    3'h7: alusel_o = AND;
                    3'h5: alusel_o = (funct7_i == 7'h20) ? SRA : SRL; // SRA vs SRL
                    3'h2: alusel_o = SLT;
                    3'h3: alusel_o = SLTU;
                    default: alusel_o = ADD;
                endcase
            end

            // I-type ALU ops (ADDI, ORI, ANDI, SLLI, SRLI, SRAI,
            // SLTI, SLTIU)
            //   rd = rs1 (op) imm
            ITYPE: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;   // uses immediate
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;   // src1 = rs1
                rs2sel_o  = 1'b1;   // src2 = imm
                memren_o  = 1'b0;
                memwren_o = 1'b0;

                unique case (funct3_i)
                    3'h0: alusel_o = ADD;   // ADDI
                    3'h4: alusel_o = XOR;   // XORI
                    3'h6: alusel_o = OR;    // ORI
                    3'h7: alusel_o = AND;   // ANDI
                    3'h1: alusel_o = SLL;   // SLLI
                    3'h5: alusel_o = (insn_i[31:25] == 7'h20) ? SRA : SRL; // SRAI/SRLI
                    3'h2: alusel_o = SLT;   // SLTI
                    3'h3: alusel_o = SLTU;  // SLTIU
                    default: alusel_o = ADD;
                endcase
            end

            // LOAD: LW/LH/LB...
            //   addr = rs1 + imm
            //   rd   = mem[addr]
            LOAD: begin
                wbsel_o   = wbMEM;  // write back memory data
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;   // src1 = rs1
                rs2sel_o  = 1'b1;   // src2 = imm
                memren_o  = 1'b1;   // read memory
                memwren_o = 1'b0;
                alusel_o  = ADD;    // addr = rs1 + imm
            end

            // STORE: SW/SH/SB...
            //   addr      = rs1 + imm
            //   mem[addr] = rs2
            STORE: begin
                wbsel_o   = wbOFF;  // no writeback
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b0;   // no rd
                rs1sel_o  = 1'b0;   // src1 = rs1
                rs2sel_o  = 1'b1;   // src2 = imm  (FIXED)
                memren_o  = 1'b0;
                memwren_o = 1'b1;   // write memory
                alusel_o  = ADD;    // addr = rs1 + imm
            end

            // BRANCH: BEQ/BNE/BLT/BGE/BLTU/BGEU
            //   target = PC + imm (computed when branch_taken)
            //   regwren_o = 0
            //   pcsel_o indicates "this is a control-flow instruction"
            BRANCH: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b1;   // use branch/jump target (when taken)
                immsel_o  = 1'b1;   // uses branch imm
                regwren_o = 1'b0;
                // For PCADD, many datapaths treat src1 as PC, src2 as imm.
                // rs1sel_o and rs2sel_o may be ignored for compare path.
                rs1sel_o  = 1'b1;   // assume 1 = PC for PCADD
                rs2sel_o  = 1'b1;   // src2 = imm
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = PCADD;  // compute PC + imm
            end

            // JAL: Jump and Link
            //   PC_next = PC + imm
            //   rd      = PC + 4
            JAL: begin
                wbsel_o   = wbPC;   // write PC+4 to rd
                pcsel_o   = 1'b1;   // jump to target
                immsel_o  = 1'b1;   // uses J-type imm
                regwren_o = 1'b1;
                rs1sel_o  = 1'b1;   // src1 = PC (for PCADD)
                rs2sel_o  = 1'b1;   // src2 = imm
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = PCADD;  // target = PC + imm
            end

            // JALR: Jump and Link Register
            //   PC_next = (rs1 + imm) & ~1
            //   rd      = PC + 4
            JALR: begin
                wbsel_o   = wbPC;   // write PC+4 to rd
                pcsel_o   = 1'b1;   // jump to computed target
                immsel_o  = 1'b1;   // uses I-type imm
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;   // src1 = rs1
                rs2sel_o  = 1'b1;   // src2 = imm (FIXED)
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;    // target = rs1 + imm (mask LSB outside)
            end

            // LUI: Load Upper Immediate
            //   rd = imm (U-type, already shifted by decode)
            LUI: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;   // no jump
                immsel_o  = 1'b1;   // uses U-type imm
                regwren_o = 1'b1;
                rs1sel_o  = 1'b1;   // assume 1 = ZERO or special path
                rs2sel_o  = 1'b1;   // src2 = imm
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;    // result = 0 + imm
            end

            // AUIPC: Add Upper Immediate to PC
            //   rd = PC + imm
            //   PC itself just goes to PC+4 (no jump)
            AUIPC: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;   // uses U-type imm
                regwren_o = 1'b1;
                rs1sel_o  = 1'b1;   // src1 = PC
                rs2sel_o  = 1'b1;   // src2 = imm
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;    // rd = PC + imm
            end

            // Default: illegal / unimplemented instruction
            // stays at safe NOP-like defaults set above
            default: begin
                // already set by defaults at top
            end

        endcase
    end

endmodule : control

