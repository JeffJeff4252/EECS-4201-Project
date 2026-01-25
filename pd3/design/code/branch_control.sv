/*
 * Module: branch_control
 *
 * Description: Branch control logic. Only sets the branch control bits based on the
 * branch instruction
 *
 * Inputs:
 * 1) 7-bit instruction opcode opcode_i
 * 2) 3-bit funct3 funct3_i
 * 3) 32-bit rs1 data rs1_i
 * 4) 32-bit rs2 data rs2_i
 *
 * Outputs:
 * 1) 1-bit operands are equal signal breq_o
 * 2) 1-bit rs1 < rs2 signal brlt_o
 */

 module branch_control #(
    parameter int DWIDTH=32
)(
    // inputs
    input logic [6:0] opcode_i,
    input logic [2:0] funct3_i,
    input logic [DWIDTH-1:0] rs1_i,
    input logic [DWIDTH-1:0] rs2_i,
    // outputs
    output logic breq_o,
    output logic brlt_o
);
    // internal signals: keep original names so top-level probing works
    logic breq, brlt, brlt_signed, brlt_unsigned, enableBrOutput;

    // equality comparison is straightforward combinational logic
    assign breq = (rs1_i == rs2_i);

    // unsigned compare, used for BLTU/BGEU variants
    assign brlt_unsigned = unsigned'(rs1_i) < unsigned'(rs2_i);

    // signed compare, used for BLT/BGE variants
    assign brlt_signed = signed'(rs1_i) < signed'(rs2_i);

    // select signed or unsigned less-than depending on funct3 value
    assign brlt = (funct3_i == 3'h6 || funct3_i == 3'h7) ?
                            brlt_unsigned : brlt_signed;

    // only enable branch outputs when opcode indicates BRANCH instructions
    assign enableBrOutput = (opcode_i == 7'b1100011);

    // drive outputs; otherwise default to zero when not a branch opcode
    assign breq_o = (enableBrOutput) ? breq : 1'b0;
    assign brlt_o = (enableBrOutput) ? brlt : 1'b0;

endmodule : branch_control

