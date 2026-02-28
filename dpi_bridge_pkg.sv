`ifndef DPI_BRIDGE_PKG_SV
`define DPI_BRIDGE_PKG_SV

package dpi_bridge_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ──────────────────────────────────────────────────────────────────
  // DPI-C struct passed by reference from the C side
  // ──────────────────────────────────────────────────────────────────
  typedef struct {
    bit [15:0] data;
    bit [15:0] address;
    bit        portid;
  } dpi_txn_t;

  // ──────────────────────────────────────────────────────────────────
  // DPI-C function imports
  //   Return 1 when a pending read/write exists; txn is filled via
  //   pass-by-reference.
  // ──────────────────────────────────────────────────────────────────
  import "DPI-C" function bit maybe_read  (output dpi_txn_t txn);
  import "DPI-C" function bit maybe_write (output dpi_txn_t txn);
  import "DPI-C" function int  get_expected_txn_count();

  // ──────────────────────────────────────────────────────────────────
  // Number of ports (cpu + 4 tile)
  // ──────────────────────────────────────────────────────────────────
  localparam int NUM_PORTS = 5;

  // Port index constants
  localparam int PORT_CPU   = 0;
  localparam int PORT_TILE0 = 1;
  localparam int PORT_TILE1 = 2;
  localparam int PORT_TILE2 = 3;
  localparam int PORT_TILE3 = 4;

  // ──────────────────────────────────────────────────────────────────
  // AXI Sequence Item
  // ──────────────────────────────────────────────────────────────────
  class axi_seq_item extends uvm_sequence_item;

    rand bit [15:0] data;
    rand bit [15:0] address;
    rand bit        rw;        // 1 = write, 0 = read

    `uvm_object_utils_begin(axi_seq_item)
      `uvm_field_int(data,    UVM_ALL_ON)
      `uvm_field_int(address, UVM_ALL_ON)
      `uvm_field_int(rw,      UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "axi_seq_item");
      super.new(name);
    endfunction

  endclass


  // ──────────────────────────────────────────────────────────────────
  // AXI Sequencer  (one instance per port)
  // ──────────────────────────────────────────────────────────────────
  class axi_sequencer extends uvm_sequencer #(axi_seq_item);

    `uvm_component_utils(axi_sequencer)

    function new(string name = "axi_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction

  endclass


  // ──────────────────────────────────────────────────────────────────
  // Virtual Sequencer – aggregates the 5 sub-sequencers
  // ──────────────────────────────────────────────────────────────────
  class axi_virtual_sequencer extends uvm_sequencer;

    `uvm_component_utils(axi_virtual_sequencer)

    axi_sequencer cpu_axi_port;      // portid == 1
    axi_sequencer tile_axi_port0;    // portid == 0, addr 0x0000–0x2000
    axi_sequencer tile_axi_port1;    // portid == 0, addr 0x2001–0x4000
    axi_sequencer tile_axi_port2;    // portid == 0, addr 0x4001–0x6000
    axi_sequencer tile_axi_port3;    // portid == 0, addr 0x6001–0x8000

    function new(string name = "axi_virtual_sequencer", uvm_component parent = null);
      super.new(name, parent);
    endfunction

  endclass


  // ──────────────────────────────────────────────────────────────────
  // DPI Bridge Virtual Sequence
  //
  //  Synchronisation rules (per port):
  //    1. Writes within a port are strictly ordered (FIFO).
  //    2. Reads  within a port are strictly ordered (FIFO).
  //    3. A read on port P can only issue when
  //         write_count[P] > read_count[P]
  //       i.e. at least one more write has completed than reads
  //       issued so far.
  //    4. Transactions on *different* ports run fully in parallel
  //       (fork…join_none).
  // ──────────────────────────────────────────────────────────────────
  class dpi_bridge_vseq extends uvm_sequence;

    `uvm_object_utils(dpi_bridge_vseq)
    `uvm_declare_p_sequencer(axi_virtual_sequencer)

    // ── Per-port bookkeeping ──────────────────────────────────────
    // Semaphores enforce strict ordering within a port for each
    // direction independently.
    semaphore wr_order_sem[NUM_PORTS];
    semaphore rd_order_sem[NUM_PORTS];

    // Counters: write_cnt tracks completed writes,
    //           read_cnt  tracks issued reads.
    int write_cnt[NUM_PORTS];
    int read_cnt [NUM_PORTS];

    // Total transaction counter for validation
    int total_txn_cnt;
    int expected_txn_cnt;

    // ── Constructor ──────────────────────────────────────────────
    function new(string name = "dpi_bridge_vseq");
      super.new(name);
    endfunction

    // ──────────────────────────────────────────────────────────────
    // body()  –  main entry point
    // ──────────────────────────────────────────────────────────────
    virtual task body();

      // Get expected transaction count from C side
      expected_txn_cnt = get_expected_txn_count();
      total_txn_cnt = 0;

      // Initialise semaphores & counters
      foreach (wr_order_sem[i]) begin
        wr_order_sem[i] = new(1);   // binary semaphore – one writer at a time per port
        rd_order_sem[i] = new(1);   // binary semaphore – one reader at a time per port
        write_cnt[i]    = 0;
        read_cnt[i]     = 0;
      end

      fork
        dpi_write_poll();           // Thread 1 – polls maybe_write()
        dpi_read_poll();            // Thread 2 – polls maybe_read()
      join_none

      // Let the spawned threads live beyond body() return if needed.
      // The test/phase objection mechanism controls overall lifetime.
    endtask


    // ──────────────────────────────────────────────────────────────
    // Resolve a DPI transaction to a port index [0..4]
    // ──────────────────────────────────────────────────────────────
    function int unsigned resolve_port(dpi_txn_t txn);
      if (txn.portid == 1'b1)
        return PORT_CPU;

      // portid == 0  →  decode from address
      if      (txn.address <= 16'h2000) return PORT_TILE0;
      else if (txn.address <= 16'h4000) return PORT_TILE1;
      else if (txn.address <= 16'h6000) return PORT_TILE2;
      else                              return PORT_TILE3;
    endfunction


    // ──────────────────────────────────────────────────────────────
    // Return the sequencer handle for a given port index
    // ──────────────────────────────────────────────────────────────
    function uvm_sequencer_base get_sequencer_by_port(int unsigned pidx);
      case (pidx)
        PORT_CPU   : return p_sequencer.cpu_axi_port;
        PORT_TILE0 : return p_sequencer.tile_axi_port0;
        PORT_TILE1 : return p_sequencer.tile_axi_port1;
        PORT_TILE2 : return p_sequencer.tile_axi_port2;
        PORT_TILE3 : return p_sequencer.tile_axi_port3;
        default    : begin
          `uvm_fatal("DPI_BRIDGE", $sformatf("Invalid port index %0d", pidx))
          return null;
        end
      endcase
    endfunction


    // ──────────────────────────────────────────────────────────────
    // WRITE poll thread
    //
    //   For every pending write returned by maybe_write():
    //     • Determine the target port.
    //     • Spawn a fork…join_none so writes to *different* ports
    //       proceed in parallel.
    //     • wr_order_sem[port] serialises writes within the same
    //       port to maintain order.
    // ──────────────────────────────────────────────────────────────
    virtual task dpi_write_poll();
      dpi_txn_t txn;

      forever begin
        if (maybe_write(txn)) begin
          // Capture into automatics for the forked thread
          automatic dpi_txn_t       t    = txn;
          automatic int unsigned    pidx = resolve_port(t);

          fork
            begin
              automatic dpi_txn_t       lt    = t;
              automatic int unsigned    lpidx = pidx;
              automatic axi_seq_item    item;
              automatic uvm_sequencer_base sqr;

              // ── Serialise writes within this port ──
              wr_order_sem[lpidx].get(1);

              item = axi_seq_item::type_id::create("wr_item");
              sqr  = get_sequencer_by_port(lpidx);

              start_item(item, -1, sqr);
              item.data    = lt.data;
              item.address = lt.address;
              item.rw      = 1'b1;                  // write
              finish_item(item);

              // Increment completed-write counter *after* the
              // transaction has finished on the bus.
              write_cnt[lpidx]++;

              // Track total transaction count and check against expected
              total_txn_cnt++;
              if (total_txn_cnt > expected_txn_cnt) begin
                `uvm_fatal("TXN_COUNT_EXCEEDED", $sformatf(
                  "Transaction count %0d exceeds expected count %0d",
                  total_txn_cnt, expected_txn_cnt))
              end

              `uvm_info("DPI_WR", $sformatf(
                "WRITE complete – port %0d  addr=0x%04h  data=0x%04h  wr_cnt=%0d  total=%0d/%0d",
                lpidx, lt.address, lt.data, write_cnt[lpidx], total_txn_cnt, expected_txn_cnt), UVM_MEDIUM)

              wr_order_sem[lpidx].put(1);
            end
          join_none

        end else begin
          // No pending write – yield for a delta / small delay to
          // avoid a zero-time busy loop.
          #1;
        end
      end
    endtask


    // ──────────────────────────────────────────────────────────────
    // READ poll thread
    //
    //   For every pending read returned by maybe_read():
    //     • Determine the target port.
    //     • Spawn a fork…join_none so reads to *different* ports
    //       proceed in parallel.
    //     • Before issuing the read, wait until
    //         write_cnt[port] > read_cnt[port]
    //       This guarantees at least one extra write has completed
    //       on that port before this read fires.
    //     • rd_order_sem[port] serialises reads within the same
    //       port to maintain FIFO order.
    // ──────────────────────────────────────────────────────────────
    virtual task dpi_read_poll();
      dpi_txn_t txn;

      forever begin
        if (maybe_read(txn)) begin
          automatic dpi_txn_t       t    = txn;
          automatic int unsigned    pidx = resolve_port(t);

          fork
            begin
              automatic dpi_txn_t       lt    = t;
              automatic int unsigned    lpidx = pidx;
              automatic axi_seq_item    item;
              automatic uvm_sequencer_base sqr;

              // ── Serialise reads within this port ──
              rd_order_sem[lpidx].get(1);

              // ── Wait until write_cnt > read_cnt ──
              // This ensures at least one more write has completed
              // on this port than the number of reads already issued.
              wait (write_cnt[lpidx] > read_cnt[lpidx]);

              // Bump the read counter *before* driving so the next
              // queued read sees the updated count and waits for yet
              // another write to complete.
              read_cnt[lpidx]++;

              item = axi_seq_item::type_id::create("rd_item");
              sqr  = get_sequencer_by_port(lpidx);

              start_item(item, -1, sqr);
              item.data    = lt.data;
              item.address = lt.address;
              item.rw      = 1'b0;                  // read
              finish_item(item);

              // Track total transaction count and check against expected
              total_txn_cnt++;
              if (total_txn_cnt > expected_txn_cnt) begin
                `uvm_fatal("TXN_COUNT_EXCEEDED", $sformatf(
                  "Transaction count %0d exceeds expected count %0d",
                  total_txn_cnt, expected_txn_cnt))
              end

              `uvm_info("DPI_RD", $sformatf(
                "READ  complete – port %0d  addr=0x%04h  data=0x%04h  rd_cnt=%0d  total=%0d/%0d",
                lpidx, lt.address, lt.data, read_cnt[lpidx], total_txn_cnt, expected_txn_cnt), UVM_MEDIUM)

              rd_order_sem[lpidx].put(1);
            end
          join_none

        end else begin
          #1;
        end
      end
    endtask

  endclass

endpackage

`endif // DPI_BRIDGE_PKG_SV
