/*
 * Module: fetch
 *
 * Description: Fetch stage
 *
 * Inputs:
 * 1) clk
 * 2) rst signal
 *
 * Outputs:
 * 1) AWIDTH wide program counter pc_o
 * 2) DWIDTH wide instruction output insn_o
 */

// taken from eclass and has not been modified

module fetch #(
    parameter int DWIDTH   = 32,
    parameter int AWIDTH   = 32,
    parameter logic [31:0] BASEADDR = 32'h0100_0000
)(
    // inputs
    input  logic              clk,
    input  logic              rst,
    input  logic              pc_write_i,   // 1 = update PC, 0 = stall
    input  logic [AWIDTH-1:0] pc_next_i,    // next PC value

    // outputs
    output logic [AWIDTH-1:0] pc_o,
    output logic [DWIDTH-1:0] insn_o
);
/* * Process definitions to be filled by * student below... */
    logic [AWIDTH-1:0] pc_q;

    // PC register with reset + enable
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_q <= BASEADDR;
        end else if (pc_write_i) begin
            pc_q <= pc_next_i;
        end
        // else: hold pc_q (stall)
    end

    assign pc_o   = pc_q;
    assign insn_o = '0;

endmodule : fetch

