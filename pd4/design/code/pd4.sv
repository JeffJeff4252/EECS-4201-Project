/*   Determines which data value is written back to the register file.
 *   Selection controlled by wbsel_i (see constants.svh).
 *
 * Inputs:
 *   pc_i      : current PC
 *   alu_i     : ALU result
 *   memdata_i : data read from memory
 *   wbsel_i   : writeback select code
 *   regwren_i : register write enable
 *
 * Output:
 *   wbdata_o  : data sent to register file for writeback
*/



`include "constants.svh"

module pd4 #(
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32,
    parameter logic [31:0] BASEADDR = 32'h01000000
)(
    input logic clk,
    input logic reset
);


    // -------------------------------------------------------------------------
    // Signals expected by the test harness / probes
    // -------------------------------------------------------------------------
    logic [AWIDTH-1:0] FETCH_PC_O;
    logic [DWIDTH-1:0] FETCH_INSN_O;

    logic [AWIDTH-1:0] DECODE_PC_O;
    logic [DWIDTH-1:0] DECODE_INSN_O;
    logic [6:0]        DECODE_OPCODE_O;
    logic [4:0]        DECODE_RD_O;
    logic [4:0]        DECODE_RS1_O;
    logic [4:0]        DECODE_RS2_O;
    logic [2:0]        DECODE_FUNCT3_O;
    logic [6:0]        DECODE_FUNCT7_O;
    logic [4:0]        DECODE_SHAMT_O;
    logic [DWIDTH-1:0] DECODE_IMM_O;

    logic [DWIDTH-1:0] RF_RS1DATA_O;
    logic [DWIDTH-1:0] RF_RS2DATA_O;

    logic [DWIDTH-1:0] ALU_RES_O;
    logic               ALU_BRTAKEN_O;

    logic CTRL_REGWREN_O;
    logic [1:0] CTRL_WBSEL_O;
    logic CTRL_MEMREN_O;
    logic CTRL_MEMWREN_O;
    logic [3:0] CTRL_ALUSEL_O;
    logic CTRL_IMMSEL_O;

    // EX->M latches to avoid Xs for store data only
    logic [DWIDTH-1:0] E_RS2_DATA;

    // Memory interface signals
    logic [AWIDTH-1:0] DMEM_ADDR_I;
    logic [DWIDTH-1:0] DMEM_DATA_I;
    logic               DMEM_READ_EN_I;
    logic               DMEM_WRITE_EN_I;
    logic [DWIDTH-1:0] DMEM_DATA_O;
    logic               DMEM_DATA_VLD_O;

    logic [AWIDTH-1:0] IMEM_ADDR_I;
    logic [DWIDTH-1:0] IMEM_DATA_O;
    logic               IMEM_DATA_VLD_O;

    logic [DWIDTH-1:0] WB_DATA_O;
    logic [AWIDTH-1:0] WB_NEXT_PC_O;

    // simple one-shot flag for debug print
    logic printed_debug;

    // small cycle counter for periodic debug
    integer cycle_cnt;

    // -------------------------------------------------------------------------
    // Control
    // -------------------------------------------------------------------------
    control #(.DWIDTH(DWIDTH)) u_control (
        .insn_i    (DECODE_INSN_O),
        .opcode_i  (DECODE_OPCODE_O),
        .funct7_i  (DECODE_FUNCT7_O),
        .funct3_i  (DECODE_FUNCT3_O),
        .pcsel_o   (),
        .immsel_o  (CTRL_IMMSEL_O),
        .regwren_o (CTRL_REGWREN_O),
        .rs1sel_o  (),
        .rs2sel_o  (),
        .memren_o  (CTRL_MEMREN_O),
        .memwren_o (CTRL_MEMWREN_O),
        .wbsel_o   (CTRL_WBSEL_O),
        .alusel_o  (CTRL_ALUSEL_O)
    );

    // -------------------------------------------------------------------------
    // IMEM (instruction memory instance)
    // -------------------------------------------------------------------------
    memory #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH)) insn_mem (
        .clk(clk),
        .rst(reset),
        .addr_i(IMEM_ADDR_I),
        .data_i(32'd0),
        .read_en_i(1'b1),
        .write_en_i(1'b0),
        .data_o(IMEM_DATA_O),
        .data_vld_o(IMEM_DATA_VLD_O)
    );

    assign IMEM_ADDR_I = FETCH_PC_O;
    assign FETCH_INSN_O = IMEM_DATA_O;

    // -------------------------------------------------------------------------
    // Fetch (PC generator)
    // -------------------------------------------------------------------------
    fetch u_fetch (
        .clk(clk),
        .rst(reset),
        .pc_o(FETCH_PC_O),
        .insn_o()   // instruction comes from IMEM -> FETCH_INSN_O
    );

    // -------------------------------------------------------------------------
    // Decode
    // -------------------------------------------------------------------------
    decode u_decode (
        .clk(clk),
        .rst(reset),
        .insn_i(FETCH_INSN_O),
        .pc_i(FETCH_PC_O),
        .pc_o(DECODE_PC_O),
        .insn_o(DECODE_INSN_O),
        .opcode_o(DECODE_OPCODE_O),
        .rd_o(DECODE_RD_O),
        .rs1_o(DECODE_RS1_O),
        .rs2_o(DECODE_RS2_O),
        .funct7_o(DECODE_FUNCT7_O),
        .funct3_o(DECODE_FUNCT3_O),
        .shamt_o(DECODE_SHAMT_O),
        .imm_o(DECODE_IMM_O)
    );

    // -------------------------------------------------------------------------
    // IGEN (not used at top-level; decode already provides imm)
    // -------------------------------------------------------------------------
    igen u_igen (
        .opcode_i(DECODE_OPCODE_O),
        .insn_i(DECODE_INSN_O),
        .imm_o()
    );

    // -------------------------------------------------------------------------
    // Register file
    // -------------------------------------------------------------------------
    register_file #(.DWIDTH(DWIDTH)) u_register_file (
        .clk(clk),
        .rst(reset),
        .rs1_i(DECODE_RS1_O),
        .rs2_i(DECODE_RS2_O),
        .rd_i(DECODE_RD_O),
        .datawb_i(WB_DATA_O),
        .regwren_i(CTRL_REGWREN_O),
        .rs1data_o(RF_RS1DATA_O),
        .rs2data_o(RF_RS2DATA_O)
    );

    // -------------------------------------------------------------------------
    // Branch control (kept simple here)
    // -------------------------------------------------------------------------
    branch_control u_branch_control (
        .opcode_i(DECODE_OPCODE_O),
        .funct3_i(DECODE_FUNCT3_O),
        .rs1_i(RF_RS1DATA_O),
        .rs2_i(RF_RS2DATA_O),
        .breq_o(),
        .brlt_o()
    );

    always_comb begin
        if (DECODE_OPCODE_O == BRANCH) begin
            case (DECODE_FUNCT3_O)
                3'h0: ALU_BRTAKEN_O = (RF_RS1DATA_O == RF_RS2DATA_O);
                3'h1: ALU_BRTAKEN_O = (RF_RS1DATA_O != RF_RS2DATA_O);
                3'h4, 3'h6: ALU_BRTAKEN_O = ($signed(RF_RS1DATA_O) < $signed(RF_RS2DATA_O));
                3'h5, 3'h7: ALU_BRTAKEN_O = !($signed(RF_RS1DATA_O) < $signed(RF_RS2DATA_O));
                default: ALU_BRTAKEN_O = 1'b0;
            endcase
        end else begin
            ALU_BRTAKEN_O = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // ALU
    // -------------------------------------------------------------------------
    alu #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH)) u_alu (
        .pc_i(DECODE_PC_O),
        .rs1_i(RF_RS1DATA_O),
        .rs2_i((CTRL_IMMSEL_O) ? DECODE_IMM_O : RF_RS2DATA_O),
        .funct3_i(DECODE_FUNCT3_O),
        .funct7_i(DECODE_FUNCT7_O),
        .alusel_i(CTRL_ALUSEL_O),
        .res_o(ALU_RES_O),
        .brtaken_o(ALU_BRTAKEN_O)
    );

    // latch EX->M store-data only (avoid Xs for store data)
    always_ff @(posedge clk) begin
        if (reset) begin
            E_RS2_DATA <= '0;
            printed_debug <= 1'b0;
            cycle_cnt <= 0;
        end else begin
            E_RS2_DATA <= RF_RS2DATA_O;
            cycle_cnt <= cycle_cnt + 1;

            // periodic debug prints for first few cycles
            if (cycle_cnt < 10) begin
                $display("PD4-CYC=%0d FETCH_PC=0x%08h FETCH_INSN=0x%08h IMEM_ADDR=0x%08h IMEM_DATA=0x%08h",
                         cycle_cnt, FETCH_PC_O, FETCH_INSN_O, IMEM_ADDR_I, IMEM_DATA_O);
            end

            // one-shot debug print when we hit BASEADDR and not printed yet
            if ((FETCH_PC_O == BASEADDR) && !printed_debug) begin
                $display("PD4-DBG: FETCH_PC=0x%08h IMEM_DATA=0x%08h FETCH_INSN=0x%08h", FETCH_PC_O, IMEM_DATA_O, FETCH_INSN_O);
                $display("PD4-DBG: DECODE_INSN=0x%08h OPCODE=0x%02h RD=%0d RS1=%0d RS2=%0d FUNCT3=0x%01h FUNCT7=0x%02h IMM=0x%08h",
                         DECODE_INSN_O, DECODE_OPCODE_O, DECODE_RD_O, DECODE_RS1_O, DECODE_RS2_O, DECODE_FUNCT3_O, DECODE_FUNCT7_O, DECODE_IMM_O);
                $display("PD4-DBG: RF_RS1DATA=0x%08h RF_RS2DATA=0x%08h", RF_RS1DATA_O, RF_RS2DATA_O);
                $display("PD4-DBG: ALU_RES=0x%08h DMEM_ADDR=0x%08h DMEM_DATA_O=0x%08h",
                         ALU_RES_O, ALU_RES_O, DMEM_DATA_O);
                printed_debug <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Memory interface wiring
    // - IMPORTANT: drive address from combinational ALU_RES_O so the harness sees
    //   the ALU result immediately in the M-stage snapshot.
    // - Keep DMEM data input latched (E_RS2_DATA) to avoid RF read/write races.
    // -------------------------------------------------------------------------
    assign DMEM_ADDR_I     = ALU_RES_O;      // <- change: use combinational ALU result
    assign DMEM_DATA_I     = E_RS2_DATA;
    assign DMEM_READ_EN_I  = CTRL_MEMREN_O;
    assign DMEM_WRITE_EN_I = CTRL_MEMWREN_O;

    // -------------------------------------------------------------------------
    // Data memory
    // -------------------------------------------------------------------------
    memory #(.AWIDTH(AWIDTH), .DWIDTH(DWIDTH)) data_mem (
        .clk(clk),
        .rst(reset),
        .addr_i(DMEM_ADDR_I),
        .data_i(DMEM_DATA_I),
        .read_en_i(DMEM_READ_EN_I),
        .write_en_i(DMEM_WRITE_EN_I),
        .data_o(DMEM_DATA_O),
        .data_vld_o(DMEM_DATA_VLD_O)
    );

    // -------------------------------------------------------------------------
    // IMPORTANT: Preload DMEM with IMEM contents for test compatibility
    // -------------------------------------------------------------------------
    initial begin
`ifdef LINE_COUNT
        integer _bytes_to_copy;
        _bytes_to_copy = `LINE_COUNT * 4;
        for (int _i = 0; _i < _bytes_to_copy && _i <= `MEM_DEPTH; _i = _i + 1) begin
            data_mem.main_memory[_i] = insn_mem.main_memory[_i];
        end
        $display("PD4: DMEM preloaded with IMEM contents (%0d bytes)", _bytes_to_copy);
`else
        for (int _i = 0; _i < 1024 && _i <= `MEM_DEPTH; _i = _i + 1) begin
            data_mem.main_memory[_i] = insn_mem.main_memory[_i];
        end
        $display("PD4: DMEM preloaded with IMEM contents (default 1024 bytes)");
`endif
    end

    // -------------------------------------------------------------------------
    // Writeback
    // -------------------------------------------------------------------------
    writeback #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH)) u_writeback (
        .pc_i(DECODE_PC_O),
        .alu_res_i(ALU_RES_O),
        .memory_data_i(DMEM_DATA_O),
        .wbsel_i(CTRL_WBSEL_O),
        .brtaken_i(ALU_BRTAKEN_O),
        .regwren_i(CTRL_REGWREN_O),
        .writeback_data_o(WB_DATA_O),
        .next_pc_o(WB_NEXT_PC_O)
    );

    // termination heuristic
    always_ff @(posedge clk) begin
        if (DMEM_DATA_O == 32'h00000073) $finish;
    end

    // probes mapping
    `include "probes.svh"

endmodule : pd4

