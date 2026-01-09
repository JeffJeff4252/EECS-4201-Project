// ----  Probes  ----

// FETCH stage
`define PROBE_F_PC          FETCH_PC_O
`define PROBE_F_INSN        FETCH_INSN_O

// DECODE (D) stage
`define PROBE_D_PC          DECODE_PC_O
`define PROBE_D_OPCODE      DECODE_OPCODE_O
`define PROBE_D_RD          DECODE_RD_O
`define PROBE_D_FUNCT3      DECODE_FUNCT3_O
`define PROBE_D_RS1         DECODE_RS1_O
`define PROBE_D_RS2         DECODE_RS2_O
`define PROBE_D_FUNCT7      DECODE_FUNCT7_O
`define PROBE_D_IMM         DECODE_IMM_O
`define PROBE_D_SHAMT       DECODE_SHAMT_O

// REGISTER (R) stage: register file access
// Reads are from decode stage, writes are from WB stage
`define PROBE_R_WRITE_ENABLE      mem_wb_reg.regwren
`define PROBE_R_WRITE_DESTINATION mem_wb_reg.rd
`define PROBE_R_WRITE_DATA        WB_DATA_O
`define PROBE_R_READ_RS1          DECODE_RS1_O
`define PROBE_R_READ_RS2          DECODE_RS2_O
`define PROBE_R_READ_RS1_DATA     RF_RS1DATA_O
`define PROBE_R_READ_RS2_DATA     RF_RS2DATA_O

// EXECUTE (E) stage: ID/EX + ALU outputs
`define PROBE_E_PC                id_ex_reg.pc
`define PROBE_E_ALU_RES           ALU_RES_O
`define PROBE_E_BR_TAKEN          ALU_BRTAKEN_O


// MEMORY (M) stage: EX/MEM + DMEM interface
`define PROBE_M_PC                ex_mem_reg.pc
`define PROBE_M_ADDRESS           DMEM_ADDR_I

// If your pattern encodes size via funct3, use the instruction in M stage.
// ex_mem_reg.insn[14:12] = funct3 of the instruction currently in M.
`define PROBE_M_SIZE_ENCODED      ex_mem_reg.insn[14:12]

// Data going to memory (store data)
`define PROBE_M_DATA              DMEM_DATA_I

// WRITEBACK (W) stage: MEM/WB + writeback mux
`define PROBE_W_PC                mem_wb_reg.pc
`define PROBE_W_ENABLE            mem_wb_reg.regwren
`define PROBE_W_DESTINATION       mem_wb_reg.rd
`define PROBE_W_DATA              WB_DATA_O

// ----  Top module  ----
`define TOP_MODULE  pd5 
// ----  Top module  ----

