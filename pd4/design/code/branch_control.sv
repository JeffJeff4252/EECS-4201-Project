/*
 * Module: branch_control
 *
 * Description:
 * -------------
 * This module implements simple branch comparison logic for the RISC-V
 * BRANCH instruction group. It detects:
 *   1) Whether rs1 == rs2 (for BEQ/BNE)
 *   2) Whether rs1 < rs2 (for BLT/BGE and BLTU/BGEU)
 *
 * It uses funct3_i to choose between signed and unsigned comparison types,
 * and enables its outputs only when the opcode corresponds to a BRANCH.
 *
 * Inputs:
 * -------
 * 1) opcode_i   : 7-bit opcode field of instruction
 * 2) funct3_i   : 3-bit function field (determines branch subtype)
 * 3) rs1_i, rs2_i : 32-bit register operands
 *
 * Outputs:
 * --------
 * 1) breq_o : 1 if operands are equal (BEQ-type)
 * 2) brlt_o : 1 if rs1 < rs2 (BLT/BLTU-type)
 */

module branch_control #(
    parameter int DWIDTH=32
)(
    // Inputs from decode stage
    input  logic [6:0] opcode_i,
    input  logic [2:0] funct3_i,
    input  logic [DWIDTH-1:0] rs1_i,
    input  logic [DWIDTH-1:0] rs2_i,

    // Outputs to execute/control path
    output logic breq_o,
    output logic brlt_o
);

    // ------------------------------------------------------------------
    // Internal signals (retain names for waveform/debug compatibility)
    // ------------------------------------------------------------------
    logic breq, brlt, brlt_signed, brlt_unsigned, enableBrOutput;

    // ------------------------------------------------------------------
    // Basic equality check
    // Used by BEQ / BNE instructions
    // ------------------------------------------------------------------
    assign breq = (rs1_i == rs2_i);

    // ------------------------------------------------------------------
    // Unsigned comparison
    // Used for BLTU / BGEU instructions
    // ------------------------------------------------------------------
    assign brlt_unsigned = unsigned'(rs1_i) < unsigned'(rs2_i);

    // ------------------------------------------------------------------
    // Signed comparison
    // Used for BLT / BGE instructions
    // ------------------------------------------------------------------
    assign brlt_signed = signed'(rs1_i) < signed'(rs2_i);

    // ------------------------------------------------------------------
    // Select signed vs. unsigned comparison depending on funct3 field
    // funct3 = 110 / 111 ⇒ unsigned
    // funct3 = 100 / 101 ⇒ signed
    // ------------------------------------------------------------------
    assign brlt = (funct3_i == 3'h6 || funct3_i == 3'h7)
                    ? brlt_unsigned
                    : brlt_signed;

    // ------------------------------------------------------------------
    // Output enable only for BRANCH opcode (7'b1100011)
    // Prevents accidental comparisons for non-branch instructions
    // ------------------------------------------------------------------
    assign enableBrOutput = (opcode_i == 7'b1100011);

    // ------------------------------------------------------------------
    // Final outputs gated by enable signal
    // ------------------------------------------------------------------
    assign breq_o = (enableBrOutput) ? breq : 1'b0;
    assign brlt_o = (enableBrOutput) ? brlt : 1'b0;

endmodule : branch_control

