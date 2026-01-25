/* Description:
 *   The Writeback stage is the final stage of the PD4 RISC-V pipeline.
 *   Its primary job is to decide *which value* will be written back to the
 *   register file based on the control signal `wbsel_i`.
 *
 *   This stage receives potential data sources from:
 *     • The ALU (arithmetic / logical result)
 *     • The data memory (for LOAD instructions)
 *     • The program counter (for JAL / JALR — PC + 4)
 *
 *   The control logic (from control.sv) determines which of these data sources
 *   should be written to the destination register by setting `wbsel_i`.
 *
 *   If `regwren_i` is deasserted, the writeback output is forced to ZERO to
 *   prevent unintended writes.
*/


`include "constants.svh"

module writeback #(
    parameter int DWIDTH = 32,
    parameter int AWIDTH = 32
)(
    input  logic              clk,
    input  logic [AWIDTH-1:0] pc_i,
    input  logic [DWIDTH-1:0] alu_res_i,
    input  logic [DWIDTH-1:0] memory_data_i,
    input  logic [1:0]         wbsel_i,
    input  logic               brtaken_i,
    input  logic               regwren_i,
    output logic [DWIDTH-1:0]  writeback_data_o,
    output logic [AWIDTH-1:0]  next_pc_o
);

    assign next_pc_o = pc_i + 32'd4;

    always_comb begin
        case (wbsel_i)
            wbALU: writeback_data_o = alu_res_i;
            wbMEM: writeback_data_o = memory_data_i;
            wbPC : writeback_data_o = pc_i + 32'd4;
            default: writeback_data_o = alu_res_i;
        endcase

        // ensure stable value even when regwren disabled
        if (!regwren_i)
            writeback_data_o = alu_res_i;
    end

endmodule : writeback

