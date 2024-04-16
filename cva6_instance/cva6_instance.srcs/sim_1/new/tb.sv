`timescale 1ns / 1ps

module tb();

    localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);
    
    // FIXME: AXI types
    typedef struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } axi_ar_chan_t;
    typedef  struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiAddrWidth-1:0] addr;
      axi_pkg::len_t                   len;
      axi_pkg::size_t                  size;
      axi_pkg::burst_t                 burst;
      logic                            lock;
      axi_pkg::cache_t                 cache;
      axi_pkg::prot_t                  prot;
      axi_pkg::qos_t                   qos;
      axi_pkg::region_t                region;
      axi_pkg::atop_t                  atop;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } axi_aw_chan_t;
    typedef struct packed {
      logic [CVA6Cfg.AxiDataWidth-1:0]     data;
      logic [(CVA6Cfg.AxiDataWidth/8)-1:0] strb;
      logic                                last;
      logic [CVA6Cfg.AxiUserWidth-1:0]     user;
    } axi_w_chan_t;
    typedef struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      axi_pkg::resp_t                  resp;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } b_chan_t;
    typedef struct packed {
      logic [CVA6Cfg.AxiIdWidth-1:0]   id;
      logic [CVA6Cfg.AxiDataWidth-1:0] data;
      axi_pkg::resp_t                  resp;
      logic                            last;
      logic [CVA6Cfg.AxiUserWidth-1:0] user;
    } r_chan_t;
    typedef struct packed {
      axi_aw_chan_t aw;
      logic         aw_valid;
      axi_w_chan_t  w;
      logic         w_valid;
      logic         b_ready;
      axi_ar_chan_t ar;
      logic         ar_valid;
      logic         r_ready;
    } noc_req_t;
    typedef struct packed {
      logic    aw_ready;
      logic    ar_ready;
      logic    w_ready;
      logic    b_valid;
      b_chan_t b;
      logic    r_valid;
      r_chan_t r;
    } noc_resp_t;

    // From CPU specification
    localparam int unsigned CLOCK_PERIOD = 20ns;
    localparam int unsigned RTC_CLOCK_PERIOD = 30.517us;

    logic clk_i;
    logic rst_ni;
    logic rtc_i;

    //logic hart_id_i[CVA6Cfg.XLEN-1:0];
    
    always #(CLOCK_PERIOD/2) clk_i =~ clk_i;
    always #(RTC_CLOCK_PERIOD/2) rtc_i =~ rtc_i;
    
    initial begin
        clk_i <= 0;
        rtc_i <= 0;
        rst_ni = 1;

        //hart_id_i = 0;
             
        @(posedge clk_i) ;
        rst_ni <= 0;
    end
    
    cvxif_pkg::cvxif_req_t  cvxif_req;
    cvxif_pkg::cvxif_resp_t cvxif_resp;
    
    noc_req_t  noc_req;
    noc_resp_t noc_resp;
    
    cva6 #(.CVA6Cfg(CVA6Cfg)) dut (
        .clk_i         ( clock_i    ),
        .rst_ni        ( rst_i      ),
        .boot_addr_i   ( 0          ),
        .hart_id_i     ( 0  ),
        .irq_i         ( 2'b0       ),
        .ipi_i         ( 1'b0       ),
        .time_irq_i    ( rtc_i      ),
        .debug_req_i   ( 1'b0       ),
        .rvfi_probes_o (            ),
        .cvxif_req_o   ( cvxif_req  ),
        .cvxif_resp_i  ( cvxif_resp ),
        .noc_req_o     ( noc_req    ),
        .noc_resp_i    ( noc_resp   )
    );

endmodule
