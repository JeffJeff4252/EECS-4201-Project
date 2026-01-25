`include "constants.svh"

module writeback #(
    parameter int DWIDTH=32,
    parameter int AWIDTH=32
)(
    input  logic        clk,   // kept for compatibility
    input  logic [AWIDTH-1:0] pc_i,
    input  logic [DWIDTH-1:0] alu_res_i,
    input  logic [DWIDTH-1:0] memory_data_i,
    input  logic [1:0]   wbsel_i,
    input  logic         brtaken_i,
    input  logic         regwren_i,
    output logic [DWIDTH-1:0] writeback_data_o,
    output logic [AWIDTH-1:0] next_pc_o
);

    // next PC = PC + 4 (simple)
    assign next_pc_o = pc_i + 32'd4;

    always_comb begin
        // default: ALU result visible
        writeback_data_o = alu_res_i;

        case (wbsel_i)
            wbALU: writeback_data_o = alu_res_i;
            wbMEM: writeback_data_o = memory_data_i;
            wbPC : writeback_data_o = pc_i + 32'd4;
            default: writeback_data_o = alu_res_i;
        endcase

        // harness expects ALU result visible even when reg writes disabled
        if (!regwren_i) begin
            writeback_data_o = alu_res_i;
        end
    end

endmodule : writeback

