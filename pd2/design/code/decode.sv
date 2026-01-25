/*
 * Module: decode
 *
 * Description: Decode stage
 */

`include "constants.svh"

module decode #(
    parameter int DWIDTH = 32,
    parameter int AWIDTH = 32
)(
    // inputs
    input  logic clk,
    input  logic rst,
    input  logic [DWIDTH-1:0] insn_i,
    input  logic [AWIDTH-1:0] pc_i,

    // outputs
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

    assign pc_o  = pc_i;
    assign insn_o = insn_i;

    igen u_igen (
        .opcode_i(opcode_o),
        .insn_i(insn_i),
        .imm_o(imm_o)
    );

    always_comb begin
        opcode_o = insn_i[6:0];
        funct3_o = insn_i[14:12];
        rs1_o    = insn_i[19:15];
        shamt_o  = insn_i[24:20];

        rd_o     = insn_i[11:7];
        rs2_o    = 5'd0;
        funct7_o = 7'd0;

        unique case (opcode_o)
            7'b0110011: begin
                rs2_o    = insn_i[24:20];
                funct7_o = insn_i[31:25];
            end

            7'b0100011: begin
                rd_o     = 5'd0;
                rs2_o    = insn_i[24:20];
                funct7_o = 7'd0;
            end

            7'b1100011: begin
                rd_o     = 5'd0;
                rs2_o    = insn_i[24:20];
                funct7_o = 7'd0;
            end

            default: begin
                rs2_o    = 5'd0;
                funct7_o = 7'd0;
            end
        endcase
    end

endmodule : decode

