/*
 * Module: decode
 *
 * Description: Decode stage
 *
 * -------- REPLACE THIS FILE WITH THE DECODE MODULE DEVELOPED IN PD2 -----------
 */

/* Description:
 *   Extracts instruction fields (opcode, funct3, funct7, register indices)
 *   from the 32-bit instruction word fetched from instruction memory.
 *
 * Inputs:
 *   instruction_i : [31:0] Current instruction word from instruction memory
 *
 * Outputs:
 *   opcode_o  : [6:0] Primary opcode field
 *   funct3_o  : [2:0] Secondary function field
 *   funct7_o  : [6:0] Additional function field (for R-type)
 *   rs1_o     : [4:0] Source register 1 index
 *   rs2_o     : [4:0] Source register 2 index
 *   rd_o      : [4:0] Destination register index
 *
 *   These outputs are passed to the control and datapath modules.
 * -------------------------------------------------------------------------
 */

`include "constants.svh"

module decode #(
    parameter int DWIDTH=32,
    parameter int AWIDTH=32
)(
    input logic clk,
    input logic rst,
    input logic [DWIDTH - 1:0] insn_i,
    input logic [DWIDTH - 1:0] pc_i,
    output logic [AWIDTH-1:0] pc_o,
    output logic [DWIDTH-1:0] insn_o,
    output logic [6:0] opcode_o,
    output logic [4:0] rd_o,
    output logic [4:0] rs1_o,
    output logic [4:0] rs2_o,
    output logic [6:0] funct7_o,
    output logic [2:0] funct3_o,
    output logic [4:0] shamt_o,
    output logic [DWIDTH-1:0] imm_o
);

    logic [6:0] opcode, funct7;
    logic [4:0] rs1, rs2, rd, shiftamt;
    logic [2:0] funct3;
    logic [DWIDTH-1:0] instruction, imm_reg;
    logic [AWIDTH-1:0] programcounter;

    assign opcode = instruction[6:0];

    assign insn_o = instruction;
    assign pc_o = programcounter;
    assign opcode_o = opcode;
    assign funct3_o = funct3;
    assign funct7_o = funct7;
    assign rs1_o = rs1;
    assign rs2_o = rs2;
    assign rd_o = rd;
    assign shamt_o = shiftamt;
    assign imm_o = imm_reg;

    assign instruction = insn_i;
    assign programcounter = pc_i;

    always_comb begin
        rd = instruction[11:7];
        rs1 = instruction[19:15];
        rs2 = instruction[24:20];
        funct3 = instruction[14:12];
        funct7 = instruction[31:25];
        shiftamt = instruction[24:20];

        unique case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: // I-type
                imm_reg = {{DWIDTH-12{instruction[31]}}, instruction[31:20]};

            7'b0100011: // S-type
                imm_reg = {{DWIDTH-12{instruction[31]}}, instruction[31:25], instruction[11:7]};

            7'b1100011: // B-type
                imm_reg = {{DWIDTH-13{instruction[31]}}, instruction[31], instruction[7],
                           instruction[30:25], instruction[11:8], 1'b0};

            7'b0110111, 7'b0010111: // U-type
                imm_reg = {instruction[31:12], 12'b0};

            7'b1101111: // J-type
                imm_reg = {{DWIDTH-21{instruction[31]}}, instruction[31],
                           instruction[19:12], instruction[20], instruction[30:21], 1'b0};

            default:
                imm_reg = '0;
        endcase
    end

endmodule : decode

