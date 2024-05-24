`timescale 1ns / 1ps

// Instantiates AXI-Bus, memories, the processor and whatever bare-minimum
// essential is needed for synthesis

`include "axi/assign.svh"
`include "rvfi_types.svh"

import ariane_pkg::*;

module synth_harness (
  // -----------
  // Main Inputs
  // -----------
  input logic sys_clk_i,
  input logic sys_rst_ni,

  // -------------------
  // DRAM inputs/outputs
  // -------------------
  inout  wire [15:0]   ddr3_dq     ,
  output wire [ 1:0]   ddr3_dm     ,
  inout  wire [ 1:0]   ddr3_dqs_n  ,
  inout  wire [ 1:0]   ddr3_dqs_p  ,
  output wire [13:0]   ddr3_addr   ,
  output wire [ 2:0]   ddr3_ba     ,
  output wire [ 0:0]   ddr3_ck_p   ,
  output wire [ 0:0]   ddr3_ck_n   ,
  output wire          ddr3_ras_n  ,
  output wire          ddr3_cas_n  ,
  output wire          ddr3_we_n   ,
  output wire          ddr3_reset_n,
  output wire [ 0:0]   ddr3_cke    ,
  output wire [ 0:0]   ddr3_odt    ,
  output wire [ 0:0]   ddr3_cs_n
);
  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(
    cva6_config_pkg::cva6_cfg
  );

  localparam AXI_USER_WIDTH     = CVA6Cfg.AxiUserWidth;
  localparam AXI_USER_EN        = CVA6Cfg.AXI_USER_EN;
  localparam AXI_ADDR_WIDTH     = synth_harness_axi::AddrWidth;
  localparam AXI_DATA_WIDTH     = synth_harness_axi::DataWidth;
  localparam AXI_STRB_WIDTH     = synth_harness_axi::StrbWidth;
  localparam AXI_ID_WIDTH       = synth_harness_axi::IdWidth;
  localparam AXI_ID_WIDTH_SLAVE = synth_harness_axi::IdWidth;
  localparam N_PERIPHERALS      = synth_harness_axi::NPeripherals;

  localparam type rvfi_probes_instr_t = `RVFI_PROBES_INSTR_T(CVA6Cfg);
  localparam type rvfi_probes_csr_t   = `RVFI_PROBES_CSR_T(CVA6Cfg);
  localparam type rvfi_probes_t = struct packed {
    rvfi_probes_csr_t csr;
    rvfi_probes_instr_t instr;
  };

  // ---------------
  // Main signals
  // ---------------
  logic rtc;
  initial begin
      rtc <= 0;
  end

  logic dram_clk;
  logic dram_clk_200mhz;
  logic clk;
  logic clk_100mhz;
  logic pll_locked;
  clk_wiz clk_gen(
    .resetn     ( sys_rst_ni      ),
    .clk_in1    ( dram_clk        ),
    .clk_50mhz  ( clk             ),
    .clk_100mhz ( clk_100mhz      ),
    .clk_200mhz ( dram_clk_200mhz ),
    .locked     ( pll_locked      )
  );

  logic dram_sync_rst;
  logic rst_n;
  rstgen i_rstgen_main (
    .clk_i        ( clk                        ),
    .rst_ni       ( pll_locked & (~sys_rst_ni) ),
    .test_mode_i  ( 1'b0                       ),
    .rst_no       ( rst_n                      ),
    .init_no      (                            ) // keep open
  );

  // ---------------
  // AXI Busses
  // ---------------
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
    .AXI_ID_WIDTH   ( AXI_ID_WIDTH   ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH )
  ) slave[0:0]();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH     ),
    .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVE ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
  ) master[N_PERIPHERALS-1:0]();


  // ------------------------------
  // DRAM
  // ------------------------------
  logic [AXI_ID_WIDTH_SLAVE-1:0] s_axi_awid;
  logic [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr;
  logic [7:0]                    s_axi_awlen;
  logic [2:0]                    s_axi_awsize;
  logic [1:0]                    s_axi_awburst;
  logic [0:0]                    s_axi_awlock;
  logic [3:0]                    s_axi_awcache;
  logic [2:0]                    s_axi_awprot;
  logic [3:0]                    s_axi_awregion;
  logic [3:0]                    s_axi_awqos;
  logic                          s_axi_awvalid;
  logic                          s_axi_awready;
  logic [AXI_DATA_WIDTH-1:0]     s_axi_wdata;
  logic [AXI_STRB_WIDTH-1:0]     s_axi_wstrb;
  logic                          s_axi_wlast;
  logic                          s_axi_wvalid;
  logic                          s_axi_wready;
  logic [AXI_ID_WIDTH_SLAVE-1:0] s_axi_bid;
  logic [1:0]                    s_axi_bresp;
  logic                          s_axi_bvalid;
  logic                          s_axi_bready;
  logic [AXI_ID_WIDTH_SLAVE-1:0] s_axi_arid;
  logic [AXI_ADDR_WIDTH-1:0]     s_axi_araddr;
  logic [7:0]                    s_axi_arlen;
  logic [2:0]                    s_axi_arsize;
  logic [1:0]                    s_axi_arburst;
  logic [0:0]                    s_axi_arlock;
  logic [3:0]                    s_axi_arcache;
  logic [2:0]                    s_axi_arprot;
  logic [3:0]                    s_axi_arregion;
  logic [3:0]                    s_axi_arqos;
  logic                          s_axi_arvalid;
  logic                          s_axi_arready;
  logic [AXI_ID_WIDTH_SLAVE-1:0] s_axi_rid;
  logic [AXI_DATA_WIDTH-1:0]     s_axi_rdata;
  logic [1:0]                    s_axi_rresp;
  logic                          s_axi_rlast;
  logic                          s_axi_rvalid;
  logic                          s_axi_rready;

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH     ),
    .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVE ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
  ) dram();
  assign dram.r_user = '0;
  assign dram.b_user = '0;

  axi_riscv_atomics_wrap #(
    .AXI_ADDR_WIDTH     ( AXI_ADDR_WIDTH     ),
    .AXI_DATA_WIDTH     ( AXI_DATA_WIDTH     ),
    .AXI_ID_WIDTH       ( AXI_ID_WIDTH_SLAVE ),
    .AXI_USER_WIDTH     ( AXI_USER_WIDTH     ),
    .AXI_MAX_WRITE_TXNS ( 1                  ),
    .RISCV_WORD_WIDTH   ( 64                 )
  ) i_axi_riscv_atomics (
    .clk_i  ( clk                             ),
    .rst_ni ( rst_n                           ),
    .slv    ( master[synth_harness_axi::DRAM] ),
    .mst    ( dram                            )
  );

  axi_clock_converter_ddr axi_clock_converter_ddr (
    .s_axi_aclk     ( clk              ),
    .s_axi_aresetn  ( rst_n            ),
    .s_axi_awid     ( dram.aw_id       ),
    .s_axi_awaddr   ( dram.aw_addr     ),
    .s_axi_awlen    ( dram.aw_len      ),
    .s_axi_awsize   ( dram.aw_size     ),
    .s_axi_awburst  ( dram.aw_burst    ),
    .s_axi_awlock   ( dram.aw_lock     ),
    .s_axi_awcache  ( dram.aw_cache    ),
    .s_axi_awprot   ( dram.aw_prot     ),
    .s_axi_awregion ( dram.aw_region   ),
    .s_axi_awqos    ( dram.aw_qos      ),
    .s_axi_awvalid  ( dram.aw_valid    ),
    .s_axi_awready  ( dram.aw_ready    ),
    .s_axi_wdata    ( dram.w_data      ),
    .s_axi_wstrb    ( dram.w_strb      ),
    .s_axi_wlast    ( dram.w_last      ),
    .s_axi_wvalid   ( dram.w_valid     ),
    .s_axi_wready   ( dram.w_ready     ),
    .s_axi_bid      ( dram.b_id        ),
    .s_axi_bresp    ( dram.b_resp      ),
    .s_axi_bvalid   ( dram.b_valid     ),
    .s_axi_bready   ( dram.b_ready     ),
    .s_axi_arid     ( dram.ar_id       ),
    .s_axi_araddr   ( dram.ar_addr     ),
    .s_axi_arlen    ( dram.ar_len      ),
    .s_axi_arsize   ( dram.ar_size     ),
    .s_axi_arburst  ( dram.ar_burst    ),
    .s_axi_arlock   ( dram.ar_lock     ),
    .s_axi_arcache  ( dram.ar_cache    ),
    .s_axi_arprot   ( dram.ar_prot     ),
    .s_axi_arregion ( dram.ar_region   ),
    .s_axi_arqos    ( dram.ar_qos      ),
    .s_axi_arvalid  ( dram.ar_valid    ),
    .s_axi_arready  ( dram.ar_ready    ),
    .s_axi_rid      ( dram.r_id        ),
    .s_axi_rdata    ( dram.r_data      ),
    .s_axi_rresp    ( dram.r_resp      ),
    .s_axi_rlast    ( dram.r_last      ),
    .s_axi_rvalid   ( dram.r_valid     ),
    .s_axi_rready   ( dram.r_ready     ),
    // to size converter
    .m_axi_aclk     ( dram_clk         ),
    .m_axi_aresetn  ( rst_n            ),
    .m_axi_awid     ( s_axi_awid       ),
    .m_axi_awaddr   ( s_axi_awaddr     ),
    .m_axi_awlen    ( s_axi_awlen      ),
    .m_axi_awsize   ( s_axi_awsize     ),
    .m_axi_awburst  ( s_axi_awburst    ),
    .m_axi_awlock   ( s_axi_awlock     ),
    .m_axi_awcache  ( s_axi_awcache    ),
    .m_axi_awprot   ( s_axi_awprot     ),
    .m_axi_awregion ( s_axi_awregion   ),
    .m_axi_awqos    ( s_axi_awqos      ),
    .m_axi_awvalid  ( s_axi_awvalid    ),
    .m_axi_awready  ( s_axi_awready    ),
    .m_axi_wdata    ( s_axi_wdata      ),
    .m_axi_wstrb    ( s_axi_wstrb      ),
    .m_axi_wlast    ( s_axi_wlast      ),
    .m_axi_wvalid   ( s_axi_wvalid     ),
    .m_axi_wready   ( s_axi_wready     ),
    .m_axi_bid      ( s_axi_bid        ),
    .m_axi_bresp    ( s_axi_bresp      ),
    .m_axi_bvalid   ( s_axi_bvalid     ),
    .m_axi_bready   ( s_axi_bready     ),
    .m_axi_arid     ( s_axi_arid       ),
    .m_axi_araddr   ( s_axi_araddr     ),
    .m_axi_arlen    ( s_axi_arlen      ),
    .m_axi_arsize   ( s_axi_arsize     ),
    .m_axi_arburst  ( s_axi_arburst    ),
    .m_axi_arlock   ( s_axi_arlock     ),
    .m_axi_arcache  ( s_axi_arcache    ),
    .m_axi_arprot   ( s_axi_arprot     ),
    .m_axi_arregion ( s_axi_arregion   ),
    .m_axi_arqos    ( s_axi_arqos      ),
    .m_axi_arvalid  ( s_axi_arvalid    ),
    .m_axi_arready  ( s_axi_arready    ),
    .m_axi_rid      ( s_axi_rid        ),
    .m_axi_rdata    ( s_axi_rdata      ),
    .m_axi_rresp    ( s_axi_rresp      ),
    .m_axi_rlast    ( s_axi_rlast      ),
    .m_axi_rvalid   ( s_axi_rvalid     ),
    .m_axi_rready   ( s_axi_rready     )
  );

  mig_7_ddr3 i_ddr (
    .sys_clk_i       ( sys_clk_i       ),
    .clk_ref_i       ( dram_clk_200mhz ),
    .ddr3_dq,
    .ddr3_dm,
    .ddr3_dqs_n,
    .ddr3_dqs_p,
    .ddr3_addr,
    .ddr3_ba,
    .ddr3_ck_p,
    .ddr3_ck_n,
    .ddr3_ras_n,
    .ddr3_cas_n,
    .ddr3_we_n,
    .ddr3_reset_n,
    .ddr3_cke,
    .ddr3_odt,
    .ddr3_cs_n,
    .mmcm_locked     (                ), // keep open
    .app_sr_req      ( '0             ),
    .app_ref_req     ( '0             ),
    .app_zq_req      ( '0             ),
    .app_sr_active   (                ), // keep open
    .app_ref_ack     (                ), // keep open
    .app_zq_ack      (                ), // keep open
    .ui_clk          ( dram_clk       ),
    .ui_clk_sync_rst ( dram_sync_rst  ),
    .aresetn         ( rst_n          ),
    .s_axi_awid,
    .s_axi_awaddr    ( s_axi_awaddr[27:0] ),
    .s_axi_awlen,
    .s_axi_awsize,
    .s_axi_awburst,
    .s_axi_awlock,
    .s_axi_awcache,
    .s_axi_awprot,
    .s_axi_awqos,
    .s_axi_awvalid,
    .s_axi_awready,
    .s_axi_wdata,
    .s_axi_wstrb,
    .s_axi_wlast,
    .s_axi_wvalid,
    .s_axi_wready,
    .s_axi_bready,
    .s_axi_bid,
    .s_axi_bresp,
    .s_axi_bvalid,
    .s_axi_arid,
    .s_axi_araddr     ( s_axi_araddr[27:0] ),
    .s_axi_arlen,
    .s_axi_arsize,
    .s_axi_arburst,
    .s_axi_arlock,
    .s_axi_arcache,
    .s_axi_arprot,
    .s_axi_arqos,
    .s_axi_arvalid,
    .s_axi_arready,
    .s_axi_rready,
    .s_axi_rid,
    .s_axi_rdata,
    .s_axi_rresp,
    .s_axi_rlast,
    .s_axi_rvalid,
    .init_calib_complete (            ), // keep open
    .device_temp         (            ), // keep open
    .sys_rst             ( sys_rst_ni )
  );

  // ---------------
  // Core-level interrupt controller
  // ---------------
  logic timer_irq;
  logic ipi;
  synth_harness_axi::req_slv_t  axi_clint_req;
  synth_harness_axi::resp_slv_t axi_clint_resp;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      rtc <= 0;
    end else begin
      rtc <= rtc ^ 1'b1;
    end
  end

  clint #(
      .CVA6Cfg        ( CVA6Cfg                       ),
      .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH                ),
      .AXI_DATA_WIDTH ( AXI_DATA_WIDTH                ),
      .AXI_ID_WIDTH   ( AXI_ID_WIDTH_SLAVE            ),
      .NR_CORES       ( 1                             ),
      .axi_req_t      ( synth_harness_axi::req_slv_t  ),
      .axi_resp_t     ( synth_harness_axi::resp_slv_t )
  ) i_clint (
      .clk_i       ( clk            ),
      .rst_ni      ( rst_n          ),
      .testmode_i  ( 1'b0           ),
      .axi_req_i   ( axi_clint_req  ),
      .axi_resp_o  ( axi_clint_resp ),
      .rtc_i       ( rtc            ),
      .timer_irq_o ( timer_irq      ),
      .ipi_o       ( ipi            )
  );

  `AXI_ASSIGN_TO_REQ(axi_clint_req, master[synth_harness_axi::CLINT])
  `AXI_ASSIGN_FROM_RESP(master[synth_harness_axi::CLINT], axi_clint_resp)

  // ---------------
  // AXI Xbar
  // ---------------
  axi_pkg::xbar_rule_64_t [N_PERIPHERALS-1:0] addr_map;
  assign addr_map = '{
    '{ idx: synth_harness_axi::CLINT,
       start_addr: synth_harness_axi::CLINTBase,
       end_addr: synth_harness_axi::CLINTBase + synth_harness_axi::CLINTLength },
    '{ idx: synth_harness_axi::DRAM,
       start_addr: synth_harness_axi::DRAMBase,
       end_addr: synth_harness_axi::DRAMBase + synth_harness_axi::DRAMLength }
  };

  localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
    NoSlvPorts: 1,
    NoMstPorts: N_PERIPHERALS,
    MaxMstTrans: 1,
    MaxSlvTrans: 1,
    FallThrough: 1'b0,
    LatencyMode: axi_pkg::CUT_ALL_PORTS,
    AxiIdWidthSlvPorts: AXI_ID_WIDTH,
    AxiIdUsedSlvPorts: AXI_ID_WIDTH,
    UniqueIds: 1'b0,
    AxiAddrWidth: AXI_ADDR_WIDTH,
    AxiDataWidth: AXI_DATA_WIDTH,
    NoAddrRules: N_PERIPHERALS
  };

  axi_xbar_intf #(
    .AXI_USER_WIDTH ( AXI_USER_WIDTH          ),
    .Cfg            ( AXI_XBAR_CFG            ),
    .rule_t         ( axi_pkg::xbar_rule_64_t )
  ) i_axi_xbar (
    .clk_i                 ( clk        ),
    .rst_ni                ( rst_n      ),
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
  ariane_axi::req_t    axi_ariane_req;
  ariane_axi::resp_t   axi_ariane_resp;

  ariane #(
    .CVA6Cfg              ( CVA6Cfg             ),
    .rvfi_probes_instr_t  ( rvfi_probes_instr_t ),
    .rvfi_probes_csr_t    ( rvfi_probes_csr_t   ),
    .rvfi_probes_t        ( rvfi_probes_t       ),
    .noc_req_t            ( ariane_axi::req_t   ),
    .noc_resp_t           ( ariane_axi::resp_t  )
  ) i_ariane (
    .clk_i                ( clk                 ),
    .rst_ni               ( rst_n               ),
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
