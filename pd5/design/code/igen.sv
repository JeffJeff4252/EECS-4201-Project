/*
 * Module: igen
 *
 * Description: Immediate generator
 */


//This file basically just takes in the instruction and defines it to the type of instruction we have. We have also implemented parts of it in other files

module igen #(
    parameter int DWIDTH = 32
)(
    input  logic [6:0]  opcode_i,
    input  logic [DWIDTH-1:0] insn_i,
    output logic [DWIDTH-1:0] imm_o
);

    always_comb begin
        imm_o = 32'd0; // Default to zero (prevents X’s)

        case (opcode_i)
            7'b0010011, // I-type (ADDI, etc.)
            7'b0000011, // Load
            7'b1100111: // JALR
                imm_o = {{20{insn_i[31]}}, insn_i[31:20]};

            7'b0100011: // S-type (Store)
                imm_o = {{20{insn_i[31]}}, insn_i[31:25], insn_i[11:7]};

            7'b1100011: // B-type (Branch)
                imm_o = {{19{insn_i[31]}}, insn_i[31], insn_i[7], insn_i[30:25], insn_i[11:8], 1'b0};

            7'b0110111, // LUI
            7'b0010111: // AUIPC
                imm_o = {insn_i[31:12], 12'b0};

            7'b1101111: // J-type (JAL)
                imm_o = {{11{insn_i[31]}}, insn_i[31], insn_i[19:12], insn_i[20], insn_i[30:21], 1'b0};

            default:
                imm_o = 32'd0;
        endcase
    end

endmodule : igen

