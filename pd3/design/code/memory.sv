/*
 * -------- REPLACE THIS FILE WITH THE MEMORY MODULE DEVELOPED IN PD1 -----------
 * Module: memory
 *
 * Description: Byte-addressable memory implementation. Supports both read and write.
 *
 * Inputs:
 * 1) clk
 * 2) rst signal
 * 3) AWIDTH address addr_i
 * 4) DWIDTH data to write data_i
 * 5) read enable signal read_en_i
 * 6) write enable signal write_en_i
 *
 * Outputs:
 * 1) DWIDTH data output data_o
 * 2) data out valid signal data_vld_o
 */

module memory #(
  parameter int AWIDTH = 32,
  parameter int DWIDTH = 32,
  parameter logic [31:0] BASE_ADDR = 32'h01000000
) (
  // inputs
  input logic clk,
  input logic rst,
  input logic [AWIDTH-1:0] addr_i,
  input logic [DWIDTH-1:0] data_i,
  input logic read_en_i,
  input logic write_en_i,
  // outputs
  output logic [DWIDTH-1:0] data_o,
  output logic data_vld_o
);

  // Local constant for byte size
  localparam integer BYTE_SIZE = 8;

  // Temporary memory used for initialization (word-based)
  logic [DWIDTH-1:0] temp_memory [0:`MEM_DEPTH];

  // Main byte-addressable memory
  logic [7:0] main_memory [0:`MEM_DEPTH];

  // Address offset based on BASE_ADDR
  logic [AWIDTH-1:0] address;
  assign address = (addr_i < BASE_ADDR) ? 'h0 : (addr_i - BASE_ADDR);

  // Memory Initialization (Simulation Only)
  // ---------------------------------------
  // The initial block reads memory contents from a hex file (defined by `MEM_PATH`).
  // Each 32-bit word is split into four bytes for the byte-addressable memory.
`ifndef TESTBENCH
  initial begin
    $readmemh(`MEM_PATH, temp_memory);  // Load memory file into temp_memory
    for (int i = 0; i < `LINE_COUNT; i++) begin
      main_memory[4*i]     = temp_memory[i][7:0];      // Byte 0 (LSB)
      main_memory[4*i + 1] = temp_memory[i][15:8];     // Byte 1
      main_memory[4*i + 2] = temp_memory[i][23:16];    // Byte 2
      main_memory[4*i + 3] = temp_memory[i][31:24];    // Byte 3 (MSB)
    end
    $display("MEMORY: Loaded %0d 32-bit words from %s", `LINE_COUNT, `MEM_PATH);
  end
`endif

  // Synchronous Write Logic
  // ------------------------
  // On the rising edge of the clock, if write_en_i is asserted,
  // data_i is written byte-by-byte to consecutive memory addresses.
  always_ff @(posedge clk) begin : Write_Mem
    if (write_en_i) begin
      // Only write if the address is within valid range
      if (address < `MEM_DEPTH - 3) begin
        // Write 4 bytes (one word) sequentially
        for (int i = 0; i < 4; i++) begin
          main_memory[address + i] <= data_i[i*BYTE_SIZE +: BYTE_SIZE];
        end
      end
    end
  end

  // Combinational Read Logic
  // -------------------------
  // If reset is asserted, outputs are cleared.
  // When read_en_i is high, data_o is constructed from up to 4 consecutive bytes.
  // Handles edge cases where reads occur near the end of memory.
  always_comb begin
    if (rst) begin
      data_o = 'd0;
      data_vld_o = 1'b0;
    end else if (read_en_i) begin
      data_vld_o = 1'b1;

      // Read handling depending on available bytes at address
      case (address)
        // Default: Normal 4-byte word read
        default: begin
          data_o = { main_memory[address + 3],
                     main_memory[address + 2],
                     main_memory[address + 1],
                     main_memory[address] };
        end

        // Near-End Cases:
        // When the address is within the last few bytes of memory,
        // fill upper bytes with zeros as required.

        (`MEM_DEPTH - 3): begin
          data_o = { 8'b0,
                     main_memory[address + 2],
                     main_memory[address + 1],
                     main_memory[address] };
        end

        (`MEM_DEPTH - 2): begin
          data_o = { 16'b0,
                     main_memory[address + 1],
                     main_memory[address] };
        end

        (`MEM_DEPTH - 1): begin
          data_o = { 24'b0,
                     main_memory[address] };
        end
      endcase
    end else begin
      // Default (no read): drive zeros and clear valid signal
      data_o = '0;
      data_vld_o = 1'b0;
    end
  end

endmodule : memory
