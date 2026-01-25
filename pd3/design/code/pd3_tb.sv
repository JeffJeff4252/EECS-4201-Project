`timescale 1ns/1ps
`include "constants.svh"

// ===============================================================
// Testbench for PD3 processor top-level
// Verifies pipeline execution, instruction flow, and data integrity
// ===============================================================
module pd3_tb;

  // ---------------------------------------------
  // Parameters
  // ---------------------------------------------
  localparam int AWIDTH = 32;
  localparam int DWIDTH = 32;
  localparam int CLK_PERIOD = 10; // 100 MHz clock

  // ---------------------------------------------
  // DUT Inputs/Outputs
  // ---------------------------------------------
  logic clk;
  logic reset;

  // ---------------------------------------------
  // Instantiate DUT (pd3 top-level)
  // ---------------------------------------------
  pd3 #(
    .AWIDTH(AWIDTH),
    .DWIDTH(DWIDTH)
  ) dut (
    .clk(clk),
    .reset(reset)
  );

  // ---------------------------------------------
  // Clock generation
  // ---------------------------------------------
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // ---------------------------------------------
  // Reset sequence
  // ---------------------------------------------
  initial begin
    reset = 1;
    repeat (5) @(posedge clk);
    reset = 0;
    $display("[TB] Reset released at time %0t", $time);
  end

  // ---------------------------------------------
  // Instruction memory preload (optional)
  // ---------------------------------------------
  initial begin
    // Load simple program if your memory module supports MEM_PATH
    // Otherwise, preloaded from file defined in constants.svh
    if ($test$plusargs("LOAD_HEX")) begin
      $readmemh("program.hex", dut.core.memory_inst.temp_memory);
      $display("[TB] Loaded program.hex into instruction memory.");
    end
  end

  // ---------------------------------------------
  // Simulation control
  // ---------------------------------------------
  initial begin
    $dumpfile("pd3_tb.vcd");
    $dumpvars(0, pd3_tb);

    // Run simulation for 2000 cycles max
    repeat (2000) @(posedge clk);

    // After running, check key register results
    check_results();

    $display("==================================================");
    $display("[TB] End of Simulation at time %0t", $time);
    $display("==================================================");
    $finish;
  end

  // ---------------------------------------------
  // Optional pipeline stage monitor
  // ---------------------------------------------
  always @(posedge clk) begin
    if (!reset) begin
      $display("[Cycle %0t] PC=0x%08h  ALU_RES=0x%08h  BR_TAKEN=%0d  MEM_DATA=0x%08h",
               $time,
               dut.core.fetch_inst.pc_reg,
               dut.core.execute_inst.alu_result,
               dut.core.branch_control_inst.branch_taken,
               dut.core.memory_inst.data_o);
    end
  end

  // ---------------------------------------------
  // Task: Dump registers
  // ---------------------------------------------
  task automatic dump_registers();
    $display("\n==== REGISTER FILE DUMP ====");
    for (int i = 0; i < 32; i++) begin
      $display("x%-2d = 0x%08h", i, dut.core.register_file_inst.regs[i]);
    end
  endtask

  // ---------------------------------------------
  // Task: Dump first 16 memory words
  // ---------------------------------------------
  task automatic dump_memory();
    $display("\n==== MEMORY DUMP (first 16 words) ====");
    for (int i = 0; i < 16; i++) begin
      $display("MEM[%0d] = 0x%08h", i, dut.core.memory_inst.temp_memory[i]);
    end
  endtask

  // ---------------------------------------------
  // Self-checking results
  // ---------------------------------------------
  task automatic check_results();
    dump_registers();
    dump_memory();

    // Example checks (adjust based on your test program)
    int errors = 0;

    // Example: register x5 should hold 0x0000000A (if program adds 5+5)
    if (dut.core.register_file_inst.regs[5] !== 32'h0000000A) begin
      $error("[TB] Register x5 mismatch. Expected 0x0000000A, got 0x%08h",
             dut.core.register_file_inst.regs[5]);
      errors++;
    end

    // Example: memory[0] should contain 0x12345678
    if (dut.core.memory_inst.temp_memory[0] !== 32'h12345678) begin
      $error("[TB] Memory[0] mismatch. Expected 0x12345678, got 0x%08h",
             dut.core.memory_inst.temp_memory[0]);
      errors++;
    end

    if (errors == 0) begin
      $display("\n✅ TEST PASSED: All checks successful!");
    end else begin
      $display("\n❌ TEST FAILED: %0d mismatches detected.", errors);
    end
  endtask

endmodule : pd3_tb

