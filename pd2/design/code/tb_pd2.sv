/*
 * ==============================================================
 * Testbench: tb_pd2
 * Purpose: Comprehensive verification for pd2 RISC-V pipeline
 * Modules Covered: fetch, decode, immediate generation, control
 * ==============================================================
 */

`include "probes.svh"

module tb_pd2;

    // -------------------------------------
    // Clock and Reset
    // -------------------------------------
    logic clk;
    logic reset;

    // Clock: 10ns period = 100MHz
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset: Assert for 20ns
    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    // -------------------------------------
    // Instantiate DUT
    // -------------------------------------
    pd2 dut (
        .clk(clk),
        .reset(reset)
    );

    // -------------------------------------
    // Simulation control
    // -------------------------------------
    integer cycle_count = 0;
    localparam int MAX_CYCLES = 200;

    // Waveform dump (for GTKWave / ModelSim)
    initial begin
        $dumpfile("pd2_tb.vcd");
        $dumpvars(0, tb_pd2);
    end

    // -------------------------------------
    // Display header
    // -------------------------------------
    initial begin
        $display("============================================================");
        $display("                PD2 PIPELINE FUNCTIONAL TEST");
        $display("============================================================");
        $display("Cycle |     F_PC     |   INSN   | D_PC | OPCODE | FUNCT3 | FUNCT7 | RS1 | RS2 | RD  | IMM(hex)  | SHAMT | CTRL Signals");
        $display("------------------------------------------------------------");
    end

    // -------------------------------------
    // Main simulation process
    // -------------------------------------
    initial begin
        @(negedge reset);
        $display("Reset deasserted. Starting simulation...\n");

        repeat (MAX_CYCLES) begin
            @(posedge clk);
            cycle_count++;

            // ---- FETCH STAGE ----
            logic [31:0] f_pc, f_insn;
            f_pc   = dut.`PROBE_F_PC;
            f_insn = dut.`PROBE_F_INSN;

            // ---- DECODE STAGE ----
            logic [31:0] d_pc, d_opcode, d_funct3, d_funct7, d_rs1, d_rs2, d_rd, d_imm;
            d_pc      = dut.`PROBE_D_PC;
            d_opcode  = dut.`PROBE_D_OPCODE;
            d_rd      = dut.`PROBE_D_RD;
            d_funct3  = dut.`PROBE_D_FUNCT3;
            d_rs1     = dut.`PROBE_D_RS1;
            d_rs2     = dut.`PROBE_D_RS2;
            d_funct7  = dut.`PROBE_D_FUNCT7;
            d_imm     = dut.`PROBE_D_IMM;

            logic [4:0] d_shamt = dut.`PROBE_D_SHAMT;

            // ---- CONTROL SIGNALS (inside decode/control) ----
            logic branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;
            branch      = dut.core.decode.branch;
            mem_read    = dut.core.decode.mem_read;
            mem_to_reg  = dut.core.decode.mem_to_reg;
            mem_write   = dut.core.decode.mem_write;
            alu_src     = dut.core.decode.alu_src;
            reg_write   = dut.core.decode.reg_write;

            // ---- DISPLAY STATUS ----
            $display("%3d | %h | %h | %h | %02h | %01h | %02h | %02h | %02h | %02h | %08h | %02h | Br:%b MR:%b MW:%b AS:%b RW:%b",
                     cycle_count, f_pc, f_insn, d_pc, d_opcode[6:0], d_funct3[2:0], d_funct7[6:0],
                     d_rs1[4:0], d_rs2[4:0], d_rd[4:0], d_imm, d_shamt,
                     branch, mem_read, mem_write, alu_src, reg_write);

            // ---- STOP CONDITIONS ----
            if (f_insn === 32'h00000073) begin // ECALL or end marker
                $display("\n[ECALL encountered — stopping simulation at cycle %0d]\n", cycle_count);
                break;
            end

            if (cycle_count >= MAX_CYCLES) begin
                $display("\n[Max cycles reached (%0d) — stopping simulation]\n", MAX_CYCLES);
                break;
            end
        end

        $display("============================================================");
        $display("Simulation complete after %0d cycles", cycle_count);
        $display("============================================================");
        $finish;
    end

endmodule

