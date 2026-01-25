/*
 * Module: igen
 *
 * Description: Immediate value generator
 *
 * Inputs:
 * 1) opcode opcode_i
 * 2) input instruction insn_i
 * Outputs:
 * 2) 32-bit immediate value imm_o
 */

module igen #(
    parameter int DWIDTH=32
    )(
    input logic [6:0] opcode_i,
    input logic [DWIDTH-1:0] insn_i,
    output logic [31:0] imm_o
);

    // Internal temporary signals
    logic [DWIDTH-1:0] instruction;        // Local copy of instruction
    logic [DWIDTH-1:0] imm_reg;            // Internal immediate register
    logic [2:0] funct3;                    // Extracted funct3 field

    // Assignments
    assign instruction = insn_i;
    assign imm_o       = imm_reg;
    assign funct3      = insn_i[14:12];

    // Immediate generation logic (combinational)
    always_comb begin : immgen
        case (opcode_i)

            // -----------------------------
            // R-Type Instructions (no immediate)
            // -----------------------------
            7'b011_0011: begin
                imm_reg = 'd0; // R-type has no immediate operand
            end

            // -----------------------------
            // I-Type Instructions (arithmetic/logical immediate)
            // -----------------------------
            7'b001_0011: begin
                case (funct3)
                    
                    // ADDI, XORI, ORI, ANDI
                    3'h0, 3'h4, 3'h6, 3'h7: begin
                        // Sign-extend 12-bit immediate (bits 31:20)
                        imm_reg = {{DWIDTH-12{instruction[31]}}, instruction[31:20]};
                    end

                    // SLLI (Shift Left Logical Immediate)
                    3'h1: begin
                        if (instruction[31:25] == 'h0) begin
                            imm_reg = {{DWIDTH-12{1'b0}}, instruction[31:20]};
                        end
                        else imm_reg = 'd0; // Invalid shift encoding
                    end

                    // SRLI/SRAI (Shift Right Logical/Arithmetic Immediate)
                    3'h5: begin
                        if (instruction[31:25] == 'h0 || instruction[31:25] == 'h20) begin
                            imm_reg = {{DWIDTH-12{1'b0}}, instruction[31:20]};
                        end
                        else imm_reg = 'd0;
                    end

                    // SLTI / SLTIU
                    3'h2, 3'h3: imm_reg = {{DWIDTH-12{instruction[31]}}, instruction[31:20]};

                    default: begin
                        imm_reg = 'd0; // Default case for undefined funct3
                    end
                endcase
            end

            // -----------------------------
            // LOAD Instructions (I-Type format)
            // -----------------------------
            7'b000_0011: begin
                imm_reg = {{DWIDTH-12{instruction[31]}}, instruction[31:20]};
            end

            // -----------------------------
            // STORE Instructions (S-Type format)
            // imm[11:5] = [31:25], imm[4:0] = [11:7]
            // -----------------------------
            7'b010_0011: begin
                imm_reg = {{DWIDTH-12{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end

            // -----------------------------
            // BRANCH Instructions (B-Type format)
            // imm[12|10:5|4:1|11] = [31|30:25|11:8|7]
            // -----------------------------
            7'b110_0011: begin
                imm_reg = {{DWIDTH-13{instruction[31]}}, instruction[31],
                           instruction[7], instruction[30:25],
                           instruction[11:8], 1'b0};
            end

            // -----------------------------
            // JAL (J-Type format)
            // imm[20|10:1|11|19:12] = [31|30:21|20|19:12]
            // -----------------------------
            7'b110_1111: begin
                imm_reg = {{DWIDTH-21{instruction[31]}}, instruction[31],
                           instruction[19:12], instruction[20],
                           instruction[30:21], 1'b0};
            end

            // -----------------------------
            // JALR (I-Type format)
            // -----------------------------
            7'b110_0111: begin
                imm_reg = {{DWIDTH-12{instruction[31]}}, instruction[31:20]};
            end

            // -----------------------------
            // LUI (U-Type format)
            // imm[31:12] = [31:12], lower 12 bits = 0
            // -----------------------------
            7'b011_0111: begin
                imm_reg = {instruction[31:12], 12'b0};
            end

            // -----------------------------
            // AUIPC (U-Type format)
            // Similar to LUI, but adds to PC later
            // -----------------------------
            7'b001_0111: begin
                imm_reg = {instruction[31:12], 12'b0};
            end

            // -----------------------------
            // Default case (undefined opcode)
            // -----------------------------
            default: begin
                imm_reg = 'd0; // Default immediate value (no-op)
            end
        endcase
    end

endmodule : igen

