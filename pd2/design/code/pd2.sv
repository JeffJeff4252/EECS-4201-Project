/*
 * Module: pd2
 *
 * Description: Pipeline datapath integrating fetch, decode, control, memory, and immediate generation.
 *
 * Notes:
 *  - Must match design_wrapper.sv which instantiates `pd2` as the core and passes `clk` and `reset`.
 *  - Instantiates the provided memory module for instruction fetch (read_en tied high).
 */

`include "constants.svh"

module pd2 #(
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32
)(
    input  logic clk,
    input  logic reset    // <-- must match design_wrapper.sv
);

    // Internal reset alias used by modules expecting 'rst'
    logic rst;
    assign rst = reset;

    // -----------------------
    // FETCH outputs
    // -----------------------
    logic [AWIDTH-1:0] f_pc;
    logic [DWIDTH-1:0] f_insn;

    // -----------------------
    // DECODE outputs
    // -----------------------
    logic [AWIDTH-1:0] d_pc;
    logic [DWIDTH-1:0] d_insn;
    logic [6:0] d_opcode;
    logic [4:0] d_rd, d_rs1, d_rs2;
    logic [6:0] d_funct7;
    logic [2:0] d_funct3;
    logic [4:0] d_shamt;
    logic [DWIDTH-1:0] d_imm;

    // -----------------------
    // CONTROL outputs
    // -----------------------
    logic pcsel, immsel, regwren, rs1sel, rs2sel, memren, memwren;
    logic [1:0] wbsel;
    logic [3:0] alusel;

    // ------------------------------------------------------------
    // FETCH: generates f_pc and increments on each clock
    // ------------------------------------------------------------
    fetch #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) u_fetch (
        .clk(clk),
        .rst(rst),
        .pc_o(f_pc),
        .insn_o()   // fetch doesn't itself read memory; instruction will be provided by memory.data_o
    );

    // ------------------------------------------------------------
    // INSTRUCTION MEMORY: combinational read from address f_pc
    //   - Use provided memory module
    //   - read_en tied high to always present instruction data at f_insn
    //   - write_en tied low (instruction memory is read-only in this test)
    // ------------------------------------------------------------
    memory #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH)
        // BASE_ADDR left as default (01000000) to match test data mapping
    ) u_imem (
        .clk(clk),
        .rst(rst),
        .addr_i(f_pc),
        .data_i('0),
        .read_en_i(1'b1),
        .write_en_i(1'b0),
        .data_o(f_insn)
    );

    // ------------------------------------------------------------
    // DECODE: extracts fields & generates immediate via igen
    // ------------------------------------------------------------
    decode #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) u_decode (
        .clk(clk),
        .rst(rst),
        .insn_i(f_insn),
        .pc_i(f_pc),
        .pc_o(d_pc),
        .insn_o(d_insn),
        .opcode_o(d_opcode),
        .rd_o(d_rd),
        .rs1_o(d_rs1),
        .rs2_o(d_rs2),
        .funct7_o(d_funct7),
        .funct3_o(d_funct3),
        .shamt_o(d_shamt),
        .imm_o(d_imm)
    );

    // ------------------------------------------------------------
    // CONTROL: generate control signals for the rest of pipeline
    // ------------------------------------------------------------
    control #(
        .DWIDTH(DWIDTH)
    ) u_control (
        .insn_i(d_insn),
        .opcode_i(d_opcode),
        .funct7_i(d_funct7),
        .funct3_i(d_funct3),
        .pcsel_o(pcsel),
        .immsel_o(immsel),
        .regwren_o(regwren),
        .rs1sel_o(rs1sel),
        .rs2sel_o(rs2sel),
        .memren_o(memren),
        .memwren_o(memwren),
        .wbsel_o(wbsel),
        .alusel_o(alusel)
    );

    // -------------------------------------------------------------------------
    // NOTE on probes:
    // probes.svh is included by design_wrapper.sv (and testbench expects these
    // macro names to map to signals within this pd2 module instance). Do NOT
    // redefine the probe file here. The probes.svh you provided must define
    // macros that resolve to these internal signals via hierarchical names.
    // -------------------------------------------------------------------------

    // If you kept probes.svh as you showed earlier, it references these names:
    //  f_pc, f_insn, d_pc, d_opcode, d_rd, d_funct3, d_rs1, d_rs2, d_funct7, d_imm

    // End module
endmodule : pd2

