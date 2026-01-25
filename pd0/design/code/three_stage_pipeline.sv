/*
 * Module: three_stage_pipeline
 *
 * A 3-stage pipeline (TSP) where the first stage performs an addition of two
 * operands (op1_i, op2_i) and registers the output, and the second stage computes
 * the difference between the output from the first stage and op1_i and registers the
 * output. This means that the output (res_o) must be available two cycles after the
 * corresponding inputs have been observed on the rising clock edge
 *
 * Visually, the circuit should look like this:
 *               <---         Stage 1           --->
 *                                                        <---         Stage 2           --->
 *                                                                                               <--    Stage 3    -->
 *                                    |------------------>|                    |
 * -- op1_i -->|                    | --> |         |     |                    |-->|         |   |                    |
 *             | pipeline registers |     | ALU add | --> | pipeline registers |   | ALU sub |-->| pipeline register  | -- res_o -->
 * -- op2_i -->|                    | --> |         |     |                    |-->|         |   |                    |
 *
 * Inputs:
 * 1) 1-bit clock signal
 * 2) 1-bit wide synchronous reset
 * 3) DWIDTH-wide input op1_i
 * 4) DWIDTH-wide input op2_i
 *
 * Outputs:
 * 1) DWIDTH-wide result res_o
 */

import constants_pkg::*;

module three_stage_pipeline #(
    parameter int DWIDTH = 8)(
        input  logic clk,
        input  logic rst,
        input  logic [DWIDTH-1:0] op1_i,
        input  logic [DWIDTH-1:0] op2_i,
        output logic [DWIDTH-1:0] res_o
    );

    // Stage 1: add
    logic [DWIDTH-1:0] add_res, add_reg_out;
    alu #(.DWIDTH(DWIDTH)) alu_add (
        .sel_i(ADD),  //fixed to ADD
        .op1_i(op1_i),
        .op2_i(op2_i),
        .res_o(add_res),
        .zero_o(),
        .neg_o()
    );
    reg_rst #(.DWIDTH(DWIDTH)) reg_add (
        .clk(clk), .rst(rst),
        .in_i(add_res),
        .out_o(add_reg_out)
    );

    // Stage 2: subtract (add_reg_out - op1_i)
    logic [DWIDTH-1:0] sub_res, sub_reg_out;
    alu #(.DWIDTH(DWIDTH)) alu_sub (
        .sel_i(SUB),  //fixed to SUB
        .op1_i(add_reg_out),
        .op2_i(op1_i),
        .res_o(sub_res),
        .zero_o(),
        .neg_o()
    );
    reg_rst #(.DWIDTH(DWIDTH)) reg_sub (
        .clk(clk), .rst(rst),
        .in_i(sub_res),
        .out_o(sub_reg_out)
    );

    // Stage 3: register the result
    reg_rst #(.DWIDTH(DWIDTH)) reg_out (
        .clk(clk), .rst(rst),
        .in_i(sub_reg_out),
        .out_o(res_o)
    );

endmodule: three_stage_pipeline

