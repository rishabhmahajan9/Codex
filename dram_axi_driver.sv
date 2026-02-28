`ifndef DRAM_AXI_DRIVER_SV
`define DRAM_AXI_DRIVER_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import dpi_bridge_pkg::*;

// dram_axi_driver — reactive slave driver for the DRAM AXI port.
//
// The DUT is the AXI master; this driver responds as a slave.
// It requires no sequencer — it monitors the interface directly and
// services write/read requests using mem_block as the backing store.
// mem_block is obtained from uvm_config_db, set by dram_mem_agent.
class dram_axi_driver extends uvm_component;
  `uvm_component_utils(dram_axi_driver)

  virtual dram_axi_if.SLV vif;
  mem_block                mem;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual dram_axi_if.SLV)::get(this, "", "vif", vif))
      `uvm_fatal("DRAM_DRV", "No virtual dram_axi_if.SLV found in config_db")
    if (!uvm_config_db #(mem_block)::get(this, "", "mem_block", mem))
      `uvm_fatal("DRAM_DRV", "No mem_block found in config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    bit [15:0] aw_addr;
    bit [15:0] rd_data;

    // Deassert all slave-driven signals at reset
    vif.awready <= 0;
    vif.wready  <= 0;
    vif.bvalid  <= 0;
    vif.arready <= 0;
    vif.rvalid  <= 0;
    vif.rdata   <= '0;
    @(posedge vif.clk iff vif.rst_n);

    forever begin
      @(posedge vif.clk);

      if (vif.awvalid) begin
        // ── Write transaction ─────────────────────────────────────
        // 1. Accept write address
        aw_addr      = vif.awaddr;
        vif.awready <= 1;
        @(posedge vif.clk);
        vif.awready <= 0;

        // 2. Accept write data
        @(posedge vif.clk iff vif.wvalid);
        mem.write(aw_addr, vif.wdata);
        `uvm_info("DRAM_DRV",
          $sformatf("Write: addr=0x%04h  data=0x%04h", aw_addr, vif.wdata),
          UVM_HIGH)
        vif.wready <= 1;
        @(posedge vif.clk);
        vif.wready <= 0;

        // 3. Send write response
        vif.bvalid <= 1;
        @(posedge vif.clk iff vif.bready);
        vif.bvalid <= 0;

      end else if (vif.arvalid) begin
        // ── Read transaction ──────────────────────────────────────
        // 1. Accept read address
        aw_addr      = vif.araddr;
        vif.arready <= 1;
        @(posedge vif.clk);
        vif.arready <= 0;

        // 2. Drive read data
        rd_data    = mem.read(aw_addr);
        vif.rdata <= rd_data;
        vif.rvalid <= 1;
        `uvm_info("DRAM_DRV",
          $sformatf("Read:  addr=0x%04h  data=0x%04h", aw_addr, rd_data),
          UVM_HIGH)
        @(posedge vif.clk iff vif.rready);
        vif.rvalid <= 0;
      end

    end
  endtask

endclass

`endif // DRAM_AXI_DRIVER_SV
