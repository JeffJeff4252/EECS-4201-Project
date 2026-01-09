`include "constants.svh"

module pd5 #(
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32,
    parameter logic [31:0] BASEADDR = 32'h01000000
)(
    input  logic clk,
    input  logic reset
);


    // Pipeline Register Types
    // Each typedef below represents the "bundle" of signals that gets passed
    // from one stage of the pipeline to the next (like a latch between stages).


    // IF/ID Pipeline Register
    // Holds the PC and instruction as they move from Fetch (IF) to Decode (ID).

    typedef struct packed {
        logic [AWIDTH-1:0] pc;
        logic [DWIDTH-1:0] insn;
    } if_id_reg_t;

    // ID/EX Pipeline Register
    // Holds everything the Execute stage needs: decoded fields, immediates,
    // register values, and control signals.
    typedef struct packed {
        logic [AWIDTH-1:0] pc;
        logic [DWIDTH-1:0] insn;
        logic [6:0]        opcode;
        logic [4:0]        rd;
        logic [4:0]        rs1;
        logic [4:0]        rs2;
        logic [2:0]        funct3;
        logic [6:0]        funct7;
        logic [DWIDTH-1:0] imm;
        logic [DWIDTH-1:0] rs1_data;
        logic [DWIDTH-1:0] rs2_data;
        // Control signals generated in ID and used in EX/MEM/WB

        logic              regwren;
        logic [1:0]        wbsel;
        logic              memren;
        logic              memwren;
        logic [3:0]        alusel;
        logic              immsel;
    } id_ex_reg_t;

    // EX/MEM Pipeline Register
    // Holds results produced by EX and control bits needed in MEM and WB.

    typedef struct packed {
        logic [AWIDTH-1:0] pc;
        logic [DWIDTH-1:0] insn;
        logic [4:0]        rd;
        logic [DWIDTH-1:0] alu_result;
        logic [DWIDTH-1:0] rs2_data;   // store data (possibly forwarded)
        logic              brtaken;
        // Control
        logic              regwren;
        logic [1:0]        wbsel;
        logic              memren;
        logic              memwren;
    } ex_mem_reg_t;

    // MEM/WB Pipeline Register
    // Holds final values going into the WB stage.

    typedef struct packed {
        logic [AWIDTH-1:0] pc;
        logic [4:0]        rd;
        logic [DWIDTH-1:0] alu_result;
        logic [DWIDTH-1:0] mem_data;
        logic              regwren;
        logic [1:0]        wbsel;
    } mem_wb_reg_t;

    // Pipeline registers (current and next)
    if_id_reg_t  if_id_reg,  if_id_reg_next;
    id_ex_reg_t  id_ex_reg,  id_ex_reg_next;
    ex_mem_reg_t ex_mem_reg, ex_mem_reg_next;
    mem_wb_reg_t mem_wb_reg, mem_wb_reg_next;


    // Hazard Detection & Forwarding
    // These signals help the pipeline deal with data hazards:
    // stall_pipeline: insert a bubble (pause stages) when needed.
    // flush_: squash instructions that should not be executed
    // forward_a/forward_b: select where EX should get its operands from.
    logic stall_pipeline;
    logic flush_if_id;
    logic flush_id_ex;

    // Forwarding select: 00 = ID/EX, 01 = EX/MEM, 10 = MEM/WB
    logic [1:0] forward_a;
    logic [1:0] forward_b;

    // Test harness / probe-facing signals 

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
    logic              ALU_BRTAKEN_O;   // EX-stage branch decision

    // "Raw" decode control signals (ID stage)
    logic        CTRL_REGWREN_O;
    logic [1:0]  CTRL_WBSEL_O;
    logic        CTRL_MEMREN_O;
    logic        CTRL_MEMWREN_O;
    logic [3:0]  CTRL_ALUSEL_O;
    logic        CTRL_IMMSEL_O;

        // Final EX ALU operands after forwarding & immediate selection

    logic [DWIDTH-1:0] alu_operand_a;
    logic [DWIDTH-1:0] alu_operand_b_pre_mux;
    logic [DWIDTH-1:0] alu_operand_b;

    // PC / Memory Interfaces

    // PC control
    logic [AWIDTH-1:0] pc_next;
    logic              pc_write;

    // Data memory
    logic [AWIDTH-1:0] DMEM_ADDR_I;
    logic [DWIDTH-1:0] DMEM_DATA_I;
    logic              DMEM_READ_EN_I;
    logic              DMEM_WRITE_EN_I;
    logic [DWIDTH-1:0] DMEM_DATA_O;
    logic              DMEM_DATA_VLD_O;

    // Instruction memory
    logic [AWIDTH-1:0] IMEM_ADDR_I;
    logic [DWIDTH-1:0] IMEM_DATA_O;
    logic              IMEM_DATA_VLD_O;

    // Writeback data
    logic [DWIDTH-1:0] WB_DATA_O;
    logic [AWIDTH-1:0] WB_NEXT_PC_O; // not used for PC, but useful for probes

    // Debug
    logic   printed_debug;
    integer cycle_cnt;

    // Instruction Memory (IMEM)

    // Instruction memory: load program from MEM_PATH
    // as instruction memory: we read at FETCH_PC_O and get FETCH_INSN_O.

    memory #(
        .AWIDTH        (AWIDTH),
        .DWIDTH        (DWIDTH),
        .BASE_ADDR     (BASEADDR),
        .INIT_FROM_MEM (1)            
    ) insn_mem (
        .clk        (clk),
        .rst        (reset),
        .addr_i     (IMEM_ADDR_I),
        .data_i     (32'd0),
        .read_en_i  (1'b1),
        .write_en_i (1'b0),
        .data_o     (IMEM_DATA_O),
        .data_vld_o (IMEM_DATA_VLD_O)
    );

    assign IMEM_ADDR_I  = FETCH_PC_O;
    assign FETCH_INSN_O = IMEM_DATA_O;

    // FETCH Stage
    // The fetch module holds the PC register. It updates PC with pc_next when

    fetch #(
        .DWIDTH   (DWIDTH),
        .AWIDTH   (AWIDTH),
        .BASEADDR (BASEADDR)
    ) u_fetch (
        .clk        (clk),
        .rst        (reset),
        .pc_write_i (pc_write),
        .pc_next_i  (pc_next),
        .pc_o       (FETCH_PC_O),
        .insn_o     ()           // unused, we use IMEM directly
    );

    // IF/ID pipeline register (next-state logic)
    //If we flush, we insert a NOP into the pipeline.
    //If we stall, we keep the current IF/ID value.
    //Otherwise, we latch the latest fetched PC and instruction.
    always_comb begin
        if (flush_if_id) begin
            if_id_reg_next.pc   = '0;
            if_id_reg_next.insn = 32'h00000013;  // NOP: ADDI x0,x0,0
        end else if (stall_pipeline) begin
            if_id_reg_next = if_id_reg;  // hold
        end else begin
            if_id_reg_next.pc   = FETCH_PC_O;
            if_id_reg_next.insn = FETCH_INSN_O;
        end
    end

    // DECODE Stage
    //splits the instruction into fields (opcode, rd, rs1, rs2, funct3, funct7)
    //generates the immediate
    //passes PC and instruction along for later stages

    decode #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) u_decode (
        .clk      (clk),
        .rst      (reset),
        .insn_i   (if_id_reg.insn),
        .pc_i     (if_id_reg.pc),
        .pc_o     (DECODE_PC_O),
        .insn_o   (DECODE_INSN_O),
        .opcode_o (DECODE_OPCODE_O),
        .rd_o     (DECODE_RD_O),
        .rs1_o    (DECODE_RS1_O),
        .rs2_o    (DECODE_RS2_O),
        .funct7_o (DECODE_FUNCT7_O),
        .funct3_o (DECODE_FUNCT3_O),
        .shamt_o  (DECODE_SHAMT_O),
        .imm_o    (DECODE_IMM_O)
    );

    // Control unit (ID stage)
    // Takes the decoded fields and decides:

    control #(.DWIDTH(DWIDTH)) u_control (
        .insn_i    (DECODE_INSN_O),
        .opcode_i  (DECODE_OPCODE_O),
        .funct7_i  (DECODE_FUNCT7_O),
        .funct3_i  (DECODE_FUNCT3_O),
        .pcsel_o   (),                // PC is handled manually in EX
        .immsel_o  (CTRL_IMMSEL_O),
        .regwren_o (CTRL_REGWREN_O),
        .rs1sel_o  (),
        .rs2sel_o  (),
        .memren_o  (CTRL_MEMREN_O),
        .memwren_o (CTRL_MEMWREN_O),
        .wbsel_o   (CTRL_WBSEL_O),
        .alusel_o  (CTRL_ALUSEL_O)
    );

    // Register file (write occurs in WB stage)
    // reads rs1 and rs2 based on DECODE_RS1_O and DECODE_RS2_O
    // writes rd in the WB stage using mem_wb_reg.*


    register_file #(.DWIDTH(DWIDTH)) u_register_file (
        .clk        (clk),
        .rst        (reset),
        .rs1_i      (DECODE_RS1_O),
        .rs2_i      (DECODE_RS2_O),
        .rd_i       (mem_wb_reg.rd),
        .datawb_i   (WB_DATA_O),
        .regwren_i  (mem_wb_reg.regwren),
        .rs1data_o  (RF_RS1DATA_O),
        .rs2data_o  (RF_RS2DATA_O)
    );

    // Optional igen instance (not used at top-level)
    igen u_igen (
        .opcode_i (DECODE_OPCODE_O),
        .insn_i   (DECODE_INSN_O),
        .imm_o    ()
    );

    // Hazard Detection (load-use)
    // If the instruction in EX is a load, and the next instruction in ID
    // needs the loaded register, we must:
    // stall the pipeline for one cycle
    // insert a bubble into EX 

    always_comb begin
        stall_pipeline = 1'b0;

        if (id_ex_reg.memren && (id_ex_reg.rd != 5'd0) &&
           ((id_ex_reg.rd == DECODE_RS1_O) ||
            (id_ex_reg.rd == DECODE_RS2_O))) begin
            stall_pipeline = 1'b1;
        end
    end

    // ID/EX Pipeline Register (next-state)
    // We captures everything Decode produced and attaches the control bits so EX can do all its work without looking back.
    always_comb begin
        if (flush_id_ex) begin
            id_ex_reg_next = '0;
            id_ex_reg_next.insn = 32'h00000013; // NOP
        end else if (stall_pipeline) begin
            id_ex_reg_next = id_ex_reg; // hold
        end else begin
            id_ex_reg_next.pc       = DECODE_PC_O;
            id_ex_reg_next.insn     = DECODE_INSN_O;
            id_ex_reg_next.opcode   = DECODE_OPCODE_O;
            id_ex_reg_next.rd       = DECODE_RD_O;
            id_ex_reg_next.rs1      = DECODE_RS1_O;
            id_ex_reg_next.rs2      = DECODE_RS2_O;
            id_ex_reg_next.funct3   = DECODE_FUNCT3_O;
            id_ex_reg_next.funct7   = DECODE_FUNCT7_O;
            id_ex_reg_next.imm      = DECODE_IMM_O;
            id_ex_reg_next.rs1_data = RF_RS1DATA_O;
            id_ex_reg_next.rs2_data = RF_RS2DATA_O;
            id_ex_reg_next.regwren  = CTRL_REGWREN_O;
            id_ex_reg_next.wbsel    = CTRL_WBSEL_O;
            id_ex_reg_next.memren   = CTRL_MEMREN_O;
            id_ex_reg_next.memwren  = CTRL_MEMWREN_O;
            id_ex_reg_next.alusel   = CTRL_ALUSEL_O;
            id_ex_reg_next.immsel   = CTRL_IMMSEL_O;
        end
    end

    // Forwarding Unit (EX stage)
    // Fixes data hazards without stalling when the data is already available
    // If EX needs a value that is being written by the instruction in the MEM or WB stage, we select that newer value instead of the stale one from the register file.
    always_comb begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // From EX/MEM
        if (ex_mem_reg.regwren && (ex_mem_reg.rd != 5'd0) &&
            (ex_mem_reg.rd == id_ex_reg.rs1)) begin
            forward_a = 2'b01;
        end
        if (ex_mem_reg.regwren && (ex_mem_reg.rd != 5'd0) &&
            (ex_mem_reg.rd == id_ex_reg.rs2)) begin
            forward_b = 2'b01;
        end

        // From MEM/WB (if EX/MEM didn't already match)
        if (mem_wb_reg.regwren && (mem_wb_reg.rd != 5'd0) &&
            (mem_wb_reg.rd == id_ex_reg.rs1) &&
           !(ex_mem_reg.regwren && (ex_mem_reg.rd != 5'd0) &&
             (ex_mem_reg.rd == id_ex_reg.rs1))) begin
            forward_a = 2'b10;
        end

        if (mem_wb_reg.regwren && (mem_wb_reg.rd != 5'd0) &&
            (mem_wb_reg.rd == id_ex_reg.rs2) &&
           !(ex_mem_reg.regwren && (ex_mem_reg.rd != 5'd0) &&
             (ex_mem_reg.rd == id_ex_reg.rs2))) begin
            forward_b = 2'b10;
        end
    end

    // EXECUTE Stage
    // This is where arithmetic, comparisons, and branch target calculations
    // happen. We also decide here if we take a branch/jump and compute the
    // next PC value.
    // Forwarding muxes
    always_comb begin
        case (forward_a)
            2'b00: alu_operand_a = id_ex_reg.rs1_data;
            2'b01: alu_operand_a = ex_mem_reg.alu_result;
            2'b10: alu_operand_a = WB_DATA_O;
            default: alu_operand_a = id_ex_reg.rs1_data;
        endcase
    end

    always_comb begin
        case (forward_b)
            2'b00: alu_operand_b_pre_mux = id_ex_reg.rs2_data;
            2'b01: alu_operand_b_pre_mux = ex_mem_reg.alu_result;
            2'b10: alu_operand_b_pre_mux = WB_DATA_O;
            default: alu_operand_b_pre_mux = id_ex_reg.rs2_data;
        endcase

        // Immediate vs rs2
        alu_operand_b = id_ex_reg.immsel ? id_ex_reg.imm : alu_operand_b_pre_mux;
    end

    // ALU
    alu #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH)) u_alu (
        .pc_i      (id_ex_reg.pc),
        .rs1_i     (alu_operand_a),
        .rs2_i     (alu_operand_b),
        .funct3_i  (id_ex_reg.funct3),
        .funct7_i  (id_ex_reg.funct7),
        .alusel_i  (id_ex_reg.alusel),
        .res_o     (ALU_RES_O),
        .brtaken_o ()
    );

    // Branch / compare logic (EX stage)
    // For branches, we compare rs1 vs rs2 (using the pre-immediate rs2 path)

    always_comb begin
        if (id_ex_reg.opcode == BRANCH) begin
            unique case (id_ex_reg.funct3)
                3'h0: ALU_BRTAKEN_O = (alu_operand_a == alu_operand_b_pre_mux); // BEQ
                3'h1: ALU_BRTAKEN_O = (alu_operand_a != alu_operand_b_pre_mux); // BNE
                3'h4, 3'h6: ALU_BRTAKEN_O =
                    ($signed(alu_operand_a) < $signed(alu_operand_b_pre_mux));   // BLT/BLTU
                3'h5, 3'h7: ALU_BRTAKEN_O =
                    !($signed(alu_operand_a) < $signed(alu_operand_b_pre_mux));  // BGE/BGEU
                default: ALU_BRTAKEN_O = 1'b0;
            endcase
        end else begin
            ALU_BRTAKEN_O = 1'b0;
        end
    end

    // Compute branch/jump target
    // For branches and JAL, ALU typically computes PC + imm.
    // For JALR, ALU computes rs1 + imm and we clear bit 0.

    logic [AWIDTH-1:0] branch_target;
    always_comb begin
        branch_target = ALU_RES_O;     // PC+imm or rs1+imm

        // For JALR, clear LSB per spec
        if (id_ex_reg.opcode == JALR) begin
            branch_target = {ALU_RES_O[AWIDTH-1:1], 1'b0};
        end
    end

    // Decide branch/jump
    logic take_branch_or_jump;
    always_comb begin
        take_branch_or_jump = 1'b0;

        if (id_ex_reg.opcode == BRANCH && ALU_BRTAKEN_O) begin
            take_branch_or_jump = 1'b1;
        end else if (id_ex_reg.opcode == JAL) begin
            take_branch_or_jump = 1'b1;
        end else if (id_ex_reg.opcode == JALR) begin
            take_branch_or_jump = 1'b1;
        end
    end

    // PC control
    always_comb begin
        pc_next  = FETCH_PC_O + 32'd4;
        pc_write = !stall_pipeline;   // stall PC on load-use

        if (take_branch_or_jump) begin
            pc_next  = branch_target;
            pc_write = 1'b1;
        end
    end

    // Flush control
    always_comb begin
        flush_if_id = 1'b0;
        flush_id_ex = 1'b0;

        if (take_branch_or_jump) begin
            flush_if_id = 1'b1;
            flush_id_ex = 1'b1;
        end

        if (stall_pipeline) begin
            flush_id_ex = 1'b1;
        end
    end

    // EX/MEM pipeline register (next-state)
    // Carries the outputs of EX into MEM.

    always_comb begin
        ex_mem_reg_next.pc         = id_ex_reg.pc;
        ex_mem_reg_next.insn       = id_ex_reg.insn;
        ex_mem_reg_next.rd         = id_ex_reg.rd;
        ex_mem_reg_next.alu_result = ALU_RES_O;
        ex_mem_reg_next.rs2_data   = alu_operand_b_pre_mux; // store data after forwarding
        ex_mem_reg_next.brtaken    = ALU_BRTAKEN_O;
        ex_mem_reg_next.regwren    = id_ex_reg.regwren;
        ex_mem_reg_next.wbsel      = id_ex_reg.wbsel;
        ex_mem_reg_next.memren     = id_ex_reg.memren;
        ex_mem_reg_next.memwren    = id_ex_reg.memwren;
    end


    // MEMORY Stage
    // For loads and stores:
    //Address = ALU result (rs1 + imm).
    //Store data = rs2 value (after forwarding).
    //Load data = DMEM_DATA_O.
    assign DMEM_ADDR_I     = ex_mem_reg.alu_result;
    assign DMEM_DATA_I     = ex_mem_reg.rs2_data;
    assign DMEM_READ_EN_I  = ex_mem_reg.memren;
    assign DMEM_WRITE_EN_I = ex_mem_reg.memwren;

    // Data memory: DO NOT preload from MEM_PATH
    memory #(
        .AWIDTH        (AWIDTH),
        .DWIDTH        (DWIDTH),
        .BASE_ADDR     (BASEADDR),
        .INIT_FROM_MEM (0)            // pure data RAM, start at 1
    ) data_mem (
        .clk        (clk),
        .rst        (reset),
        .addr_i     (DMEM_ADDR_I),
        .data_i     (DMEM_DATA_I),
        .read_en_i  (DMEM_READ_EN_I),
        .write_en_i (DMEM_WRITE_EN_I),
        .data_o     (DMEM_DATA_O),
        .data_vld_o (DMEM_DATA_VLD_O)
    );

    // MEM/WB pipeline register (next-state)
    // Captures the result of MEM so WB can decide what to write to the RF.

    always_comb begin
        mem_wb_reg_next.pc         = ex_mem_reg.pc;
        mem_wb_reg_next.rd         = ex_mem_reg.rd;
        mem_wb_reg_next.alu_result = ex_mem_reg.alu_result;
        mem_wb_reg_next.mem_data   = DMEM_DATA_O;
        mem_wb_reg_next.regwren    = ex_mem_reg.regwren;
        mem_wb_reg_next.wbsel      = ex_mem_reg.wbsel;
    end

    // WRITEBACK Stage
    // This is the last stage: we pick which value goes back into the register
    // file (ALU result, memory data, or PC+4) based on wbsel.

    writeback #(.DWIDTH(DWIDTH), .AWIDTH(AWIDTH)) u_writeback (
        .clk             (clk),
        .pc_i            (mem_wb_reg.pc),
        .alu_res_i       (mem_wb_reg.alu_result),
        .memory_data_i   (mem_wb_reg.mem_data),
        .wbsel_i         (mem_wb_reg.wbsel),
        .brtaken_i       (1'b0),
        .regwren_i       (mem_wb_reg.regwren),
        .writeback_data_o(WB_DATA_O),
        .next_pc_o       (WB_NEXT_PC_O)
    );

    // Pipeline Register Sequential Logic

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            if_id_reg     <= '0;
            id_ex_reg     <= '0;
            ex_mem_reg    <= '0;
            mem_wb_reg    <= '0;
            printed_debug <= 1'b0;
            cycle_cnt     <= 0;
        end else begin
            if_id_reg   <= if_id_reg_next;
            id_ex_reg   <= id_ex_reg_next;
            ex_mem_reg  <= ex_mem_reg_next;
            mem_wb_reg  <= mem_wb_reg_next;
            cycle_cnt   <= cycle_cnt + 1;

            if (cycle_cnt < 4) begin
                $display("PD5-CYC=%0d IF_PC=0x%08h IF_INSN=0x%08h STALL=%0b BRJUMP=%0b",
                         cycle_cnt, FETCH_PC_O, FETCH_INSN_O, stall_pipeline, take_branch_or_jump);
            end

            if ((FETCH_PC_O == BASEADDR) && !printed_debug) begin
                $display("PD5-DBG: IF  PC=0x%08h INSN=0x%08h", FETCH_PC_O, FETCH_INSN_O);
                $display("PD5-DBG: ID  PC=0x%08h INSN=0x%08h", if_id_reg.pc, if_id_reg.insn);
                $display("PD5-DBG: EX  PC=0x%08h ALU=0x%08h BR=%0b", id_ex_reg.pc, ALU_RES_O, ALU_BRTAKEN_O);
                $display("PD5-DBG: MEM PC=0x%08h DOUT=0x%08h", ex_mem_reg.pc, DMEM_DATA_O);
                $display("PD5-DBG: WB  PC=0x%08h DATA=0x%08h RD=%0d WREN=%0b",
                         mem_wb_reg.pc, WB_DATA_O, mem_wb_reg.rd, mem_wb_reg.regwren);
                printed_debug <= 1'b1;
            end
        end
    end

    // WB Debug + Termination

    always_ff @(posedge clk) begin
        $display("PD5-WB: PC=0x%08h WB_DATA=0x%08h RD=%0d WREN=%0b FWD_A=%0d FWD_B=%0d",
                 mem_wb_reg.pc, WB_DATA_O, mem_wb_reg.rd, mem_wb_reg.regwren,
                 forward_a, forward_b);
    end

    always_ff @(posedge clk) begin
        if (DMEM_DATA_O == 32'h00000073) $finish;
    end

    `include "probes.svh"

endmodule : pd5

