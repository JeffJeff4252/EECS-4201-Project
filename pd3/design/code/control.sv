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
	parameter int DWIDTH=32
)(
	// inputs
    input logic [DWIDTH-1:0] insn_i,
    input logic [6:0] opcode_i,
    input logic [6:0] funct7_i,
    input logic [2:0] funct3_i,

    // outputs
    output logic pcsel_o,
    output logic immsel_o,
    output logic regwren_o,
    output logic rs1sel_o,
    output logic rs2sel_o,
    output logic memren_o,
    output logic memwren_o,
    output logic [1:0] wbsel_o,
    output logic [3:0] alusel_o
);
    // ===============================================================
    // Combinational logic block — defines all control signals
    // based on instruction opcode and funct fields.
    // ===============================================================
    always_comb begin : Control
        case (opcode_i)

            // -------------------------------------------------------
            // R-type Instructions (e.g., ADD, SUB, XOR, AND, OR, etc.)
            // Operate on two registers, write result to rd
            // -------------------------------------------------------
            RTYPE: begin
                wbsel_o   = wbALU;    // Write ALU result to rd
                pcsel_o   = 1'b0;     // Next PC = PC + 4
                immsel_o  = 1'b0;     // Immediate not used
                regwren_o = 1'b1;     // Enable register write
                rs1sel_o  = 1'b0;     // Use register file for rs1
                rs2sel_o  = 1'b0;     // Use register file for rs2
                memren_o  = 1'b0;     // No memory read
                memwren_o = 1'b0;     // No memory write

                // Determine ALU operation from funct3 and funct7
                case (funct3_i)
                    3'h0: begin
                        case (funct7_i)
                            7'h0: alusel_o = ADD;  // ADD
                            7'h2: alusel_o = SUB;  // SUB
                            default: alusel_o = ADD;
                        endcase
                    end
                    3'h1: alusel_o = SLL;
                    3'h4: alusel_o = XOR;
                    3'h6: alusel_o = OR;
                    3'h7: alusel_o = AND;
                    3'h5: begin
                        case (funct7_i)
                            7'h0: alusel_o = SRL;  // Shift Right Logical
                            7'h2: alusel_o = SRA;  // Shift Right Arithmetic
                            default: alusel_o = ADD;
                        endcase
                    end
                    3'h2: alusel_o = SLT;   // Set Less Than
                    3'h3: alusel_o = SLTU;  // Set Less Than Unsigned
                endcase
            end

            // -------------------------------------------------------
            // I-type ALU Instructions (e.g., ADDI, XORI, ORI, ANDI)
            // -------------------------------------------------------
            ITYPE: begin
                wbsel_o   = wbALU;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;  // Use immediate operand
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b1;  // Second operand = immediate
                memren_o  = 1'b0;
                memwren_o = 1'b0;

                // Select ALU operation based on funct3
                case (funct3_i)
                    3'h0: alusel_o = ADD;   // ADDI
                    3'h4: alusel_o = XOR;   // XORI
                    3'h6: alusel_o = OR;    // ORI
                    3'h7: alusel_o = AND;   // ANDI
                    3'h1: begin              // SLLI
                        case (insn_i[31:25])
                            7'h0: alusel_o = SLL;
                            default: alusel_o = ADD;
                        endcase
                    end
                    3'h5: begin              // SRLI or SRAI
                        case (insn_i[31:25])
                            7'h0: alusel_o = SRL;
                            7'h2: alusel_o = SRA;
                            default: alusel_o = ADD;
                        endcase
                    end
                    3'h2: alusel_o = SLT;   // SLTI
                    3'h3: alusel_o = SLTU;  // SLTIU
                endcase
            end

            // -------------------------------------------------------
            // Load Instructions (LW, LH, LB)
            // -------------------------------------------------------
            LOAD: begin
                wbsel_o   = wbMEM;   // Write-back from memory
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b1;
                memren_o  = 1'b1;    // Enable memory read
                memwren_o = 1'b0;
                alusel_o  = ADD;     // Effective address = rs1 + imm
            end

            // -------------------------------------------------------
            // Store Instructions (SW, SH, SB)
            // -------------------------------------------------------
            STORE: begin
                wbsel_o   = wbOFF;   // No write-back
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b0;    // No register write
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b1;    // Enable memory write
                alusel_o  = ADD;
            end

            // -------------------------------------------------------
            // Branch Instructions (BEQ, BNE, BLT, etc.)
            // -------------------------------------------------------
            BRANCH: begin
                wbsel_o   = wbOFF;   // No register write
                pcsel_o   = 1'b1;    // PC = branch target
                immsel_o  = 1'b1;
                regwren_o = 1'b0;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = PCADD;   // ALU computes branch target
            end

            // -------------------------------------------------------
            // JAL - Jump and Link
            // -------------------------------------------------------
            JAL: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b1;   // Jump to PC + imm
                immsel_o  = 1'b1;
                regwren_o = 1'b1;   // Write return address
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = PCADD;
            end

            // -------------------------------------------------------
            // JALR - Jump and Link Register
            // -------------------------------------------------------
            JALR: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b1;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;    // ALU computes rs1 + imm
            end

            // -------------------------------------------------------
            // LUI - Load Upper Immediate
            // -------------------------------------------------------
            LUI: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b0;
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;    // Upper immediate load
            end

            // -------------------------------------------------------
            // AUIPC - Add Upper Immediate to PC
            // -------------------------------------------------------
            AUIPC: begin
                wbsel_o   = wbOFF;
                pcsel_o   = 1'b1;   // Update PC = PC + imm
                immsel_o  = 1'b1;
                regwren_o = 1'b1;
                rs1sel_o  = 1'b0;
                rs2sel_o  = 1'b0;
                memren_o  = 1'b0;
                memwren_o = 1'b0;
                alusel_o  = ADD;
            end

            // -------------------------------------------------------
            // Default - undefined instruction
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
                alusel_o  = ADD;    // Default ALU operation
            end
        endcase
    end

endmodule : control
