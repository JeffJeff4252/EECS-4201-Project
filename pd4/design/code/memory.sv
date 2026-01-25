/*
 * Module: memory
 *
 * Byte-addressable memory (read/write). Loads from `MEM_PATH` if provided.
 */

/*   Simple single-ported byte-addressable memory.
 *   Provides synchronous write and combinational read.
 *   Preloads contents from a hex file at reset.
 */

module memory #(
  parameter int AWIDTH = 32,
  parameter int DWIDTH = 32,
  parameter logic [31:0] BASE_ADDR = 32'h01000000
) (
  input logic clk,
  input logic rst,
  input logic [AWIDTH-1:0] addr_i,
  input logic [DWIDTH-1:0] data_i,
  input logic read_en_i,
  input logic write_en_i,
  output logic [DWIDTH-1:0] data_o,
  output logic data_vld_o
);

  localparam integer BYTE_SIZE = 8;

  // Temporary word-based buffer (only used if MEM_PATH defined)
  logic [DWIDTH-1:0] temp_mem [0:`MEM_DEPTH];

  // Main byte-addressable memory
  logic [7:0] main_memory [0:`MEM_DEPTH];

  // Address offset (BASE_ADDR -> 0)
  logic [AWIDTH-1:0] address;
  assign address = (addr_i < BASE_ADDR) ? 'h0 : (addr_i - BASE_ADDR);

  // Internal address register for auto-increment
  logic [AWIDTH-1:0] mem_addr_reg;

  // Address increment logic
  always_ff @(posedge clk) begin
    if (rst) begin
      mem_addr_reg <= BASE_ADDR;
    end else begin
      mem_addr_reg <= mem_addr_reg + 4; // Increment by 4 for word-aligned addresses
    end
  end

`ifdef MEM_PATH
  `ifdef LINE_COUNT
    initial begin
      $display("MEMORY: Loading %0d words from %s", `LINE_COUNT, `MEM_PATH);
      $readmemh(`MEM_PATH, temp_mem);
      for (int i = 0; i < `LINE_COUNT; i++) begin
        main_memory[4*i]     = temp_mem[i][7:0];
        main_memory[4*i + 1] = temp_mem[i][15:8];
        main_memory[4*i + 2] = temp_mem[i][23:16];
        main_memory[4*i + 3] = temp_mem[i][31:24];
      end
    end
  `else
    initial begin
      $display("MEMORY: LINE_COUNT not defined; zero-initializing");
      for (int i = 0; i <= `MEM_DEPTH; i++) main_memory[i] = 8'd0;
    end
  `endif
`else
  initial begin
    $display("MEMORY: MEM_PATH not defined; zero-initializing");
    for (int i = 0; i <= `MEM_DEPTH; i++) main_memory[i] = 8'd0;
  end
`endif




  // Synchronous write (word) - little-endian
  always_ff @(posedge clk) begin
    if (write_en_i) begin
      if (address < `MEM_DEPTH - 3) begin
        for (int i = 0; i < 4; i++)
          main_memory[address + i] <= data_i[i*BYTE_SIZE +: BYTE_SIZE];
      end
    end
  end

  // Combinational read
  always_comb begin
    if (rst) begin
      data_o = '0;
      data_vld_o = 1'b0;
    end else if (read_en_i) begin
      data_vld_o = 1'b1;
      // safe-bounds little-endian read
      data_o = { main_memory[address + 3],
                 main_memory[address + 2],
                 main_memory[address + 1],
                 main_memory[address] };
    end else begin
      data_o = '0;
      data_vld_o = 1'b0;
    end
  end

endmodule : memory

