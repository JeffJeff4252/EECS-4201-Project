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


/*
 *   Decodes the instruction opcode/funct fields to produce control
 *   signals for the processor datapath.  Determines:
 *     - which ALU operation to perform
 *     - whether to read/write memory
 *     - how writeback and immediates are selected
 *
 *   This is purely combinational logic driven by the decoded instruction.
 */

`include "constants.svh"

module control #(
    parameter int DWIDTH = 32
)(
    // Instruction fields from decode stage
    input  logic [DWIDTH-1:0] insn_i,
    input  logic [6:0] opcode_i,
    input  logic [6:0] funct7_i,
    input  logic [2:0] funct3_i,

    // Control outputs to datapath
    output logic pcsel_o,      // select PC source (0=+4, 1=branch/jump)
    output logic immsel_o,     // select immediate operand for ALU
    output logic regwren_o,    // enable register file writeback
    output logic rs1sel_o,     // select rs1 source (not used)
    output logic rs2sel_o,     // select rs2 source (reg/imm)
    output logic memren_o,     // memory read enable
    output logic memwren_o,    // memory write enable
    output logic [1:0] wbsel_o,// writeback multiplexer select
    output logic [3:0] alusel_o// ALU operation select
);

    // ===============================================================
    // Combinational logic: decode by opcode
    // ===============================================================
    always_comb begin : Control
        case (opcode_i)

            // -------------------------------------------------------
            // R-type: register-register operations (ADD, SUB, AND, OR)
            // -------------------------------------------------------
            RTYPE: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b0;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;

                // Determine ALU operation
                case (funct3_i)
                    3'h0: alusel_o = (funct7_i == 7'h20) ? SUB : ADD;
                    3'h1: alusel_o = SLL;
                    3'h4: alusel_o = XOR;
                    3'h6: alusel_o = OR;
                    3'h7: alusel_o = AND;
                    3'h5: alusel_o = (funct7_i == 7'h20) ? SRA : SRL;
                    3'h2: alusel_o = SLT;
                    3'h3: alusel_o = SLTU;
                    default: alusel_o = ADD;
                endcase
            end

            // -------------------------------------------------------
            // I-type ALU ops (ADDI, ORI, ANDI, etc.)
            // -------------------------------------------------------
            ITYPE: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b1;
                memren_o  = 1'b0;
                memwren_o = 1'b0;

                case (funct3_i)
                    3'h0: alusel_o = ADD;   // ADDI
                    3'h4: alusel_o = XOR;   // XORI
                    3'h6: alusel_o = OR;    // ORI
                    3'h7: alusel_o = AND;   // ANDI
                    3'h1: alusel_o = SLL;   // SLLI
                    3'h5: alusel_o = (insn_i[31:25] == 7'h20) ? SRA : SRL; // SRLI/SRAI
                    3'h2: alusel_o = SLT;
                    3'h3: alusel_o = SLTU;
                    default: alusel_o = ADD;
                endcase
            end

            // -------------------------------------------------------
            // LOAD: memory read (LW/LH/LB)
            // -------------------------------------------------------
            LOAD: begin
                wbsel_o   = wbMEM;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b1;
                memren_o  = 1'b1;
                memwren_o = 1'b0;
                alusel_o  = ADD; // compute address = rs1 + imm
            end

            // -------------------------------------------------------
            // STORE: memory write (SW/SH/SB)
            // -------------------------------------------------------
            STORE: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b0;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b1;
                alusel_o  = ADD;
            end

            // -------------------------------------------------------
            // BRANCH: conditional branch
            // -------------------------------------------------------
            BRANCH: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b1; // use PC + imm
                immsel_o  = 1'b1;
                regwren_o = 1'b0;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = PCADD;
            end

            // -------------------------------------------------------
            // JAL: Jump and Link (PC-relative)
            // -------------------------------------------------------
            JAL: begin
                wbsel_o   = wbPC;
                pcsel_o   = 1'b1;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = PCADD;
            end

            // -------------------------------------------------------
            // JALR: Jump and Link Register
            // -------------------------------------------------------
            JALR: begin
                wbsel_o   = wbPC;
                pcsel_o   = 1'b1;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;
            end

            // -------------------------------------------------------
            // LUI: Load Upper Immediate
            // -------------------------------------------------------
            LUI: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;
            end

            // -------------------------------------------------------
            // AUIPC: Add Upper Immediate to PC
            // -------------------------------------------------------
            AUIPC: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b1;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;
            end

            // -------------------------------------------------------
            // Default: undefined instruction → safe defaults
            // -------------------------------------------------------
            default: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b0;
                regwren_o = 1'b0;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;
            end
        endcase
    end

endmodule : control
