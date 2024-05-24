`timescale 1ns / 1ps

// Instantiates AXI-Bus, memories, the processor and whatever bare-minimum
// essential is needed for synthesis

`include "axi/assign.svh"
`include "rvfi_types.svh"

import ariane_pkg::*;

module synth_harness (
  input  logic               sys_clk_in,
  output ariane_axi::req_t   axi_ariane_req,
  input  ariane_axi::resp_t  axi_ariane_resp
);
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(
    cva6_config_pkg::cva6_cfg
  );

  //localparam int unsigned CLOCK_PERIOD      = 20ns;
  //localparam int unsigned RTC_CLOCK_PERIOD  = 30.517us;
  localparam int unsigned AXI_USER_WIDTH    = CVA6Cfg.AxiUserWidth;
  localparam int unsigned AXI_USER_EN       = CVA6Cfg.AXI_USER_EN;
  localparam int unsigned AXI_ADDRESS_WIDTH = 64;
  localparam int unsigned AXI_DATA_WIDTH    = 64;
  localparam int unsigned AXI_STRB_WIDTH    = AXI_DATA_WIDTH / 8;
  localparam IdWidth      = ariane_axi::IdWidth;
  localparam IdWidthSlave = ariane_axi::IdWidth;

  localparam int unsigned NUM_WORDS         = 2**16;

  localparam bit          StallRandomOutput = 1'b0;
  localparam bit          StallRandomInput  = 1'b0;

  // RVFI PROBES
  localparam type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg);
  localparam type rvfi_probes_csr_t = `RVFI_PROBES_CSR_T(CVA6Cfg);
  localparam type rvfi_probes_t = struct packed {
    rvfi_probes_csr_t csr;
    rvfi_probes_instr_t instr;
  };

  typedef enum int unsigned {
    DRAM  = 0,
    CLINT = 1
  } axi_slaves_t;
  localparam NB_PERIPHERALS = CLINT + 1;

  typedef enum logic[63:0] {
    DRAMBase  = 64'h8000_0000,
    CLINTBase = 64'h0200_0000
  } bus_start_t;
  typedef enum logic[63:0] {
    DRAMLength  = 64'h1000,
    CLINTLength = 64'hC000
  } bus_length_t;

  // ---------------
  // Main signals
  // ---------------
  logic clk;
  logic rtc;
  logic rst_ni;

  //always #(CLOCK_PERIOD/2) sys_clk_i =~ sys_clk_i;
  //always #(RTC_CLOCK_PERIOD/2) sys_rtc_i =~ sys_rtc_i;
  initial begin
      //sys_clk_i <= 0;
      rtc <= 0;
      rst_ni = 0;
           
      @(posedge sys_clk_in) ;
      rst_ni <= 1;
  end

  clk_wiz clk_gen(
    .resetn   ( rst_ni     ),
    .clk_in1  ( sys_clk_in ),
    .clk_out1 ( clk        )
  );

  logic ndmreset_n;
  rstgen i_rstgen_main (
    .clk_i        ( clk        ),
    .rst_ni       ( rst_ni     ),
    .test_mode_i  ( test_en    ),
    .rst_no       ( ndmreset_n ),
    .init_no      (            ) // keep open
  );

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( IdWidth           ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) slave[0:0]();
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( IdWidthSlave      ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) master[NB_PERIPHERALS-1:0]();

  // ------------------
  // AXI typedefs
  // ------------------
  typedef logic [IdWidth-1:0] id_t;
  typedef logic [IdWidthSlave-1:0] id_slv_t;
  typedef logic [AXI_ADDRESS_WIDTH-1:0] addr_t;
  typedef logic [AXI_DATA_WIDTH-1:0] data_t;
  typedef logic [AXI_STRB_WIDTH-1:0] strb_t;
  typedef logic [AXI_USER_WIDTH-1:0] user_t;

  // AW Channel - Slave
  typedef struct packed {
      id_slv_t          id;
      addr_t            addr;
      axi_pkg::len_t    len;
      axi_pkg::size_t   size;
      axi_pkg::burst_t  burst;
      logic             lock;
      axi_pkg::cache_t  cache;
      axi_pkg::prot_t   prot;
      axi_pkg::qos_t    qos;
      axi_pkg::region_t region;
      axi_pkg::atop_t   atop;
      user_t            user;
  } aw_chan_slv_t;

  // B Channel - Slave
  typedef struct packed {
      id_slv_t        id;
      axi_pkg::resp_t resp;
      user_t          user;
  } b_chan_slv_t;

  // AR Channel - Slave
  typedef struct packed {
      id_slv_t          id;
      addr_t            addr;
      axi_pkg::len_t    len;
      axi_pkg::size_t   size;
      axi_pkg::burst_t  burst;
      logic             lock;
      axi_pkg::cache_t  cache;
      axi_pkg::prot_t   prot;
      axi_pkg::qos_t    qos;
      axi_pkg::region_t region;
      user_t            user;
  } ar_chan_slv_t;

  // R Channel - Slave
  typedef struct packed {
      id_slv_t        id;
      data_t          data;
      axi_pkg::resp_t resp;
      logic           last;
      user_t          user;
  } r_chan_slv_t;

  typedef struct packed {
      aw_chan_slv_t aw;
      logic         aw_valid;
      ariane_axi::w_chan_t      w;
      logic         w_valid;
      logic         b_ready;
      ar_chan_slv_t ar;
      logic         ar_valid;
      logic         r_ready;
  } req_slv_t;

  typedef struct packed {
      logic         aw_ready;
      logic         ar_ready;
      logic         w_ready;
      logic         b_valid;
      b_chan_slv_t  b;
      logic         r_valid;
      r_chan_slv_t  r;
  } resp_slv_t;


  // ------------------------------
  // Memory + Exclusive Access
  // ------------------------------
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( IdWidthSlave      ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) dram();

  logic                         req;
  logic                         we;
  logic [AXI_ADDRESS_WIDTH-1:0] addr;
  logic [AXI_DATA_WIDTH/8-1:0]  be;
  logic [AXI_DATA_WIDTH-1:0]    wdata;
  logic [AXI_DATA_WIDTH-1:0]    rdata;
  logic [AXI_USER_WIDTH-1:0]    wuser;
  logic [AXI_USER_WIDTH-1:0]    ruser;

  axi_riscv_atomics_wrap #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( IdWidthSlave      ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    ),
    .AXI_MAX_WRITE_TXNS ( 1  ),
    .RISCV_WORD_WIDTH   ( 64 )
  ) i_axi_riscv_atomics (
    .clk_i  ( clk          ),
    .rst_ni ( ndmreset_n   ),
    .slv    ( master[DRAM] ),
    .mst    ( dram         )
  );

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( IdWidthSlave      ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) dram_delayed();

  axi_delayer_intf #(
    .AXI_ID_WIDTH        ( IdWidthSlave      ),
    .AXI_ADDR_WIDTH      ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH      ( AXI_DATA_WIDTH    ),
    .AXI_USER_WIDTH      ( AXI_USER_WIDTH    ),
    .STALL_RANDOM_INPUT  ( StallRandomInput  ),
    .STALL_RANDOM_OUTPUT ( StallRandomOutput ),
    .FIXED_DELAY_INPUT   ( 0                 ),
    .FIXED_DELAY_OUTPUT  ( 0                 )
  ) i_axi_delayer (
    .clk_i  ( clk          ),
    .rst_ni ( ndmreset_n   ),
    .slv    ( dram         ),
    .mst    ( dram_delayed )
  );

  axi2mem #(
    .AXI_ID_WIDTH   ( IdWidthSlave      ),
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) i_axi2mem (
    .clk_i  ( clk          ),
    .rst_ni ( ndmreset_n   ),
    .slave  ( dram_delayed ),
    .req_o  ( req          ),
    .we_o   ( we           ),
    .addr_o ( addr         ),
    .be_o   ( be           ),
    .user_o ( wuser        ),
    .data_o ( wdata        ),
    .user_i ( ruser        ),
    .data_i ( rdata        )
  );

  sram #(
    .DATA_WIDTH ( AXI_DATA_WIDTH ),
    .USER_WIDTH ( AXI_USER_WIDTH ),
    .USER_EN    ( AXI_USER_EN    ),
    .SIM_INIT   ( "zeros"        ),
    .NUM_WORDS  ( NUM_WORDS      )
  ) i_sram (
    .clk_i      ( clk                                                                         ),
    .rst_ni     ( rst_ni                                                                      ),
    .req_i      ( req                                                                         ),
    .we_i       ( we                                                                          ),
    .addr_i     ( addr[$clog2(NUM_WORDS)-1+$clog2(AXI_DATA_WIDTH/8):$clog2(AXI_DATA_WIDTH/8)] ),
    .wuser_i    ( wuser                                                                       ),
    .wdata_i    ( wdata                                                                       ),
    .be_i       ( be                                                                          ),
    .ruser_o    ( ruser                                                                       ),
    .rdata_o    ( rdata                                                                       )
  );

  // ---------------          
  // Core-level interrupt controller                     
  // ---------------          
  logic timer_irq;
  logic ipi;

  always_ff @(posedge clk or negedge ndmreset_n) begin
    if (~ndmreset_n) begin
      rtc <= 0;
    end else begin
      rtc <= rtc ^ 1'b1;
    end
  end

  req_slv_t  axi_clint_req;
  resp_slv_t axi_clint_resp;

  clint #(
      .CVA6Cfg        ( CVA6Cfg           ),
      .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
      .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
      .AXI_ID_WIDTH   ( IdWidthSlave      ),
      .NR_CORES       ( 1                 ),
      .axi_req_t      ( req_slv_t         ),
      .axi_resp_t     ( resp_slv_t        )
  ) i_clint (
      .clk_i       ( clk            ),
      .rst_ni      ( ndmreset_n     ),
      .testmode_i  ( test_en        ),
      .axi_req_i   ( axi_clint_req  ),
      .axi_resp_o  ( axi_clint_resp ),
      .rtc_i       ( rtc            ),
      .timer_irq_o ( timer_irq      ),
      .ipi_o       ( ipi            )
  );

  `AXI_ASSIGN_TO_REQ(axi_clint_req, master[CLINT])
  `AXI_ASSIGN_FROM_RESP(master[CLINT], axi_clint_resp)

  // ---------------          
  // AXI Xbar                     
  // ---------------          
  axi_pkg::xbar_rule_64_t [NB_PERIPHERALS-1:0] addr_map;
  assign addr_map = '{
    '{ idx: CLINT, start_addr: CLINTBase, end_addr: CLINTBase + CLINTLength       },
    '{ idx: DRAM,  start_addr: DRAMBase,  end_addr: DRAMBase + DRAMLength         }
  };

  localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
    NoSlvPorts: 1,
    NoMstPorts: NB_PERIPHERALS,
    MaxMstTrans: 1,
    MaxSlvTrans: 1,
    FallThrough: 1'b0,
    LatencyMode: axi_pkg::CUT_ALL_PORTS,
    AxiIdWidthSlvPorts: IdWidth,
    AxiIdUsedSlvPorts: IdWidth,
    UniqueIds: 1'b0,
    AxiAddrWidth: AXI_ADDRESS_WIDTH,
    AxiDataWidth: AXI_DATA_WIDTH,
    NoAddrRules: NB_PERIPHERALS
  };

  axi_xbar_intf #(
    .AXI_USER_WIDTH ( AXI_USER_WIDTH          ),
    .Cfg            ( AXI_XBAR_CFG            ),
    .rule_t         ( axi_pkg::xbar_rule_64_t )
  ) i_axi_xbar (
    .clk_i                 ( clk        ),
    .rst_ni                ( ndmreset_n ),
    .test_i                ( 1'b0       ),
    .slv_ports             ( slave      ),
    .mst_ports             ( master     ),
    .addr_map_i            ( addr_map   ),
    .en_default_mst_port_i ( '0         ),
    .default_mst_port_i    ( '0         )
  );
                              
  // ---------------          
  // Core                     
  // ---------------          
  ariane #(
    .CVA6Cfg              ( CVA6Cfg             ),
    .rvfi_probes_instr_t  ( rvfi_probes_instr_t ),
    .rvfi_probes_csr_t    ( rvfi_probes_csr_t   ),
    .rvfi_probes_t        ( rvfi_probes_t       ),
    .noc_req_t            ( ariane_axi::req_t   ),
    .noc_resp_t           ( ariane_axi::resp_t  )
  ) i_ariane (
    .clk_i                ( clk                 ),
    .rst_ni               ( ndmreset_n          ),
    .boot_addr_i          ( 32'h0000_0000       ), // Doesn't matter, it is just for synth
    .hart_id_i            ( {24'h0, hart_id}    ),
    .irq_i                ( 1'b0                ), // We do not have any peripherals
    .ipi_i                ( ipi                 ),
    .time_irq_i           ( timer_irq           ),
    .rvfi_probes_o        (                     ), // unneeded
    .debug_req_i          ( 1'b0                ),
    .noc_req_o            ( axi_ariane_req      ),
    .noc_resp_i           ( axi_ariane_resp     )
  );

  `AXI_ASSIGN_FROM_REQ(slave[0], axi_ariane_req)
  `AXI_ASSIGN_TO_RESP(axi_ariane_resp, slave[0])
endmodule
