`ifndef DRAM_MEM_AGENT_SV
`define DRAM_MEM_AGENT_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
import dpi_bridge_pkg::*;

// dram_mem_agent — UVM agent for the DRAM AXI port (DUT-to-DRAM).
//
// Owns the mem_block memory model and the slave driver.
// mem_block is set into config_db here so dram_axi_driver can retrieve it.
class dram_mem_agent extends uvm_agent;
  `uvm_component_utils(dram_mem_agent)

  dram_axi_driver drv;
  mem_block       mem;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mem = mem_block::type_id::create("mem");
    drv = dram_axi_driver::type_id::create("drv", this);
    uvm_config_db #(mem_block)::set(this, "drv", "mem_block", mem);
  endfunction

endclass

`endif // DRAM_MEM_AGENT_SV
