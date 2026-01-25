`include "constants.svh"

module pd4_tb;

    // Parameters
    localparam int AWIDTH = 32;
    localparam int DWIDTH = 32;
    localparam logic [31:0] BASEADDR = 32'h01000000;
    localparam int SIM_CYCLES = 50;

    // Clock and reset
    logic clk;
    logic reset;

    // Instantiate DUT
    pd4 #(
        .AWIDTH(AWIDTH),
        .DWIDTH(DWIDTH),
        .BASEADDR(BASEADDR)
    ) dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Reset logic
    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    // Simple IMEM preload
    initial begin
        $display("TB: Preloading IMEM with test instructions...");
        // Example instructions; adapt as needed
        dut.insn_mem.main_memory[0] = 8'h13;   // LSB
        dut.insn_mem.main_memory[1] = 8'h01;
        dut.insn_mem.main_memory[2] = 8'h01;
        dut.insn_mem.main_memory[3] = 8'hfd;   // MSB

        dut.insn_mem.main_memory[4] = 8'h23;
        dut.insn_mem.main_memory[5] = 8'h26;
        dut.insn_mem.main_memory[6] = 8'h11;
        dut.insn_mem.main_memory[7] = 8'h02;

        // DMEM preload (copy IMEM for alignment)
        for (int i = 0; i < 8; i++) begin
            dut.data_mem.main_memory[i] = dut.insn_mem.main_memory[i];
        end
    end

    // Cycle counter and debug print
    integer cycle_cnt;
    initial cycle_cnt = 0;

    always_ff @(posedge clk) begin
        if (!reset) begin
            cycle_cnt <= cycle_cnt + 1;

            // Print pipeline stages
            $display("TB-CYC=%0d FETCH_PC=0x%08h FETCH_INSN=0x%08h DECODE_RD=%0d ALU_RES=0x%08h WB_DATA=0x%08h",
                     cycle_cnt,
                     dut.FETCH_PC_O,
                     dut.FETCH_INSN_O,
                     dut.DECODE_RD_O,
                     dut.ALU_RES_O,
                     dut.WB_DATA_O
            );

            // Stop condition: termination instruction
            if (dut.DMEM_DATA_O == 32'h00000073 || cycle_cnt >= SIM_CYCLES) begin
                $display("TB: Terminating simulation at cycle %0d", cycle_cnt);
                $finish;
            end
        end
    end

    // Optional waveform dump for ModelSim / VCS
    initial begin
        $dumpfile("pd4_tb.vcd");
        $dumpvars(0, pd4_tb);
    end

endmodule

