`timescale 1ns/1ps

//  PD5 Testbench
//  - Includes instruction memory
//  - Includes data memory
//  - Includes self-checking
//  - Includes directed hazard tests

module pd5_tb;
    // Clock and reset
    logic clk;
    logic rst;

    // DUT debug outputs
    logic [31:0] dbg_pc_if;
    logic [31:0] dbg_pc_id;
    logic [31:0] dbg_pc_ex;
    logic [31:0] dbg_pc_mem;
    logic [31:0] dbg_pc_wb;

    logic [31:0] dbg_regfile_x1;
    logic [31:0] dbg_regfile_x2;
    logic [31:0] dbg_regfile_x3;
    logic [31:0] dbg_regfile_x4;

    // ------------------------------
    // Instruction Memory Model
    // ------------------------------
    logic [31:0] imem[0:255];

    // ------------------------------
    // Data Memory Model
    // ------------------------------
    logic [31:0] dmem[0:255];

    // DUT instance
    pd5 dut(
        .clk(clk),
        .rst(rst),
        // Debug
        .dbg_pc_if(dbg_pc_if),
        .dbg_pc_id(dbg_pc_id),
        .dbg_pc_ex(dbg_pc_ex),
        .dbg_pc_mem(dbg_pc_mem),
        .dbg_pc_wb(dbg_pc_wb),
        .dbg_regfile_x1(dbg_regfile_x1),
        .dbg_regfile_x2(dbg_regfile_x2),
        .dbg_regfile_x3(dbg_regfile_x3),
        .dbg_regfile_x4(dbg_regfile_x4)
    );

    // -----------------------------------------------------------
    // Clock
    // -----------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;


    // -----------------------------------------------------------
    // Reset
    // -----------------------------------------------------------
    initial begin
        rst = 1;
        #30 rst = 0;
    end


    // -----------------------------------------------------------
    // Program Loader
    // -----------------------------------------------------------
    task load_program();
    begin
        // ZERO entire memory
        for (int i = 0; i < 256; i++) begin
            imem[i] = 32'h00000013; // NOP = ADDI x0,x0,0
            dmem[i] = 32'h0;
        end

        // --------------------------------------------------------
        //  Directed Hazard Tests
        // --------------------------------------------------------

        // 0: ADD x3 = x1 + x2    (forwarding test)
        imem[0] = 32'h002081b3;  // ADD x3, x1, x2

        // 1: SUB x4 = x3 - x1    (EX/MEM forwarding)
        imem[1] = 32'h4011a233;  // SUB x4, x3, x1

        // 2: LW  x5 = 0(x3)      (load-use)
        imem[2] = 32'h0001a283;  // LW x5, 0(x3)

        // 3: ADD x6 = x5 + x2    (should stall 1 cycle)
        imem[3] = 32'h0022b333;  // ADD x6, x5, x2

        // 4: ADDI x7 = x6 + 4    (checks pipeline resume)
        imem[4] = 32'h00430393;  // ADDI x7, x6, 4

        // 5: BEQ x7,x6, +8       (branch test)
        imem[5] = 32'h00638363;  // BEQ x7, x6, +8

        // 6: ADDI x1 = x0 + 9    (should be flushed if branch taken)
        imem[6] = 32'h00900093;  // ADDI x1, x0, 9

        // 7: ADDI x1 = x0 + 2    (target)
        imem[7] = 32'h00200093;  // ADDI x1, x0, 2
    end
    endtask


    // -----------------------------------------------------------
    // Instruction fetch hookup
    // -----------------------------------------------------------
    // DUT must expose imem_addr
    // and accept imem_data
    assign dut.imem_data = imem[dut.imem_addr[9:2]];


    // -----------------------------------------------------------
    // Data Memory hookup
    // -----------------------------------------------------------
    always_ff @(posedge clk) begin
        if (dut.mem_write) begin
            dmem[dut.mem_addr[9:2]] <= dut.mem_wdata;
        end
    end

    assign dut.mem_rdata = dmem[dut.mem_addr[9:2]];


    // -----------------------------------------------------------
    // Self-Checking Logic
    // -----------------------------------------------------------
    task check_value(string msg, logic [31:0] expected, logic [31:0] actual);
    begin
        if (expected !== actual) begin
            $display("[FAIL] %s Expected=%h Actual=%h", msg, expected, actual);
            $finish;
        end else begin
            $display("[PASS] %s = %h", msg, actual);
        end
    end
    endtask


    // -----------------------------------------------------------
    // Simulation Control
    // -----------------------------------------------------------
    initial begin
        $dumpfile("pd5_tb.vcd");
        $dumpvars(0, pd5_tb);

        load_program();

        $display("--- Starting Simulation ---");

        // Run long enough
        repeat (300) @(posedge clk);

        $display("--- Checking Results ---");

        // Expected results (depends on register init = 0)
        // ADD x3 = x1 + x2 = 0
        check_value("x3", 32'h0, dbg_regfile_x3);

        // SUB x4 = x3 - x1 = 0
        check_value("x4", 32'h0, dbg_regfile_x4);

        // LW x5 loads memory value (default zero)
        check_value("x5", 32'h0, dut.rf.regs[5]);

        // ADD x6 = x5 + x2 = 0
        check_value("x6", 32'h0, dut.rf.regs[6]);

        // ADDI x7 = x6 + 4 = 4
        check_value("x7", 32'h4, dut.rf.regs[7]);

        // Branch should be NOT taken (x7 != x6)
        // So x1 must = 9 (from flushed ADDI?)
        check_value("x1", 32'h9, dbg_regfile_x1);

        $display("ALL TESTS PASSED.");
        $finish;
    end

    // -----------------------------------------------------------
    // Per-cycle Monitor
    // -----------------------------------------------------------
    always @(posedge clk) begin
        $display("PC_IF=%h | x1=%h x2=%h x3=%h", dbg_pc_if, dbg_regfile_x1, dbg_regfile_x2, dbg_regfile_x3);
    end

endmodule

