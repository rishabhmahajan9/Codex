`ifndef DRAM_AXI_IF_SV
`define DRAM_AXI_IF_SV

// DRAM AXI interface — DUT is master, DRAM agent is slave.
// The SLV modport is used by dram_axi_driver: it samples incoming
// address/data requests and drives the ready/response signals.
interface dram_axi_if (input logic clk, input logic rst_n);

  // Write Address Channel
  logic [15:0] awaddr;
  logic        awvalid;
  logic        awready;

  // Write Data Channel
  logic [15:0] wdata;
  logic        wvalid;
  logic        wready;

  // Write Response Channel
  logic        bvalid;
  logic        bready;

  // Read Address Channel
  logic [15:0] araddr;
  logic        arvalid;
  logic        arready;

  // Read Data Channel
  logic [15:0] rdata;
  logic        rvalid;
  logic        rready;

  // Slave modport: agent samples master requests, drives ready/response
  modport SLV (
    input  clk,    rst_n,
    input  awaddr, awvalid,
    output awready,
    input  wdata,  wvalid,
    output wready,
    output bvalid,
    input  bready,
    input  araddr, arvalid,
    output arready,
    output rdata,  rvalid,
    input  rready
  );

endinterface

`endif // DRAM_AXI_IF_SV
