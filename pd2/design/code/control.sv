/*
 * Module: control
 *
 * Description: Control unit sets control signals based on opcode and funct fields
 */

`include "constants.svh"

module control #(
    parameter int DWIDTH = 32
)(
    // inputs
    input  logic [DWIDTH-1:0] insn_i,
    input  logic [6:0] opcode_i,
    input  logic [6:0] funct7_i,
    input  logic [2:0] funct3_i,

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

    always_comb begin
        // Default all control signals
        pcsel_o   = 0;
        immsel_o  = 0;
        regwren_o = 0;
        rs1sel_o  = 0;
        rs2sel_o  = 0;
        memren_o  = 0;
        memwren_o = 0;
        wbsel_o   = 2'b00;
        alusel_o  = 4'b0000;

        unique case (opcode_i)
            7'b0110011: begin // R-type
                regwren_o = 1;
                alusel_o  = 4'b0001;
            end

            7'b0010011: begin // I-type arithmetic
                regwren_o = 1;
                immsel_o  = 1;
                rs2sel_o  = 1;
                alusel_o  = 4'b0010;
            end

            7'b0000011: begin // Load
                regwren_o = 1;
                memren_o  = 1;
                immsel_o  = 1;
                rs2sel_o  = 1;
                wbsel_o   = 2'b01;
            end

            7'b0100011: begin // Store
                memwren_o = 1;
                immsel_o  = 1;
                rs2sel_o  = 1;
            end

            7'b1100011: begin // Branch
                pcsel_o  = 1;
                alusel_o = 4'b0011;
            end

            7'b1101111, // JAL
            7'b1100111: begin // JALR
                regwren_o = 1;
                wbsel_o   = 2'b10;
                pcsel_o   = 1;
            end

            7'b0110111, // LUI
            7'b0010111: begin // AUIPC
                regwren_o = 1;
                immsel_o  = 1;
            end

            default: ;
        endcase
    end

endmodule : control

