// DPI Bridge C file
// Provides extern "C" functions for SystemVerilog DPI calls

#include <svdpi.h>
#include "port_adapter.h"

// Global instance of PortAdapter
static PortAdapter g_port_adapter;

// ──────────────────────────────────────────────────────────────────
// DPI-C exported functions (extern for SV DPI call)
// These match the imports in dpi_bridge_pkg.sv:
//   import "DPI-C" function bit maybe_read  (output dpi_txn_t txn);
//   import "DPI-C" function bit maybe_write (output dpi_txn_t txn);
//   import "DPI-C" function int  get_expected_txn_count();
// ──────────────────────────────────────────────────────────────────

extern "C" {

// maybe_read - Called by SV to check for pending read transactions
// Returns 1 (true) if a pending read exists and fills txn
// Returns 0 (false) if no pending read
int maybe_read(DpiTxn* txn) {
    return g_port_adapter.read_adapter(txn) ? 1 : 0;
}

// maybe_write - Called by SV to check for pending write transactions
// Returns 1 (true) if a pending write exists and fills txn
// Returns 0 (false) if no pending write
int maybe_write(DpiTxn* txn) {
    return g_port_adapter.write_adapter(txn) ? 1 : 0;
}

// get_expected_txn_count - Called by SV to get the expected total number of transactions
int get_expected_txn_count() {
    return g_port_adapter.get_expected_txn_count();
}

} // extern "C"

// ──────────────────────────────────────────────────────────────────
// Test functions (for use by test.cpp)
// These allow queueing reads and writes for testing
// ──────────────────────────────────────────────────────────────────

// test_queue_read - Queue a read transaction for testing
void test_queue_read(const DpiTxn& txn) {
    g_port_adapter.queue_read(txn);
}

// test_queue_write - Queue a write transaction for testing
void test_queue_write(const DpiTxn& txn) {
    g_port_adapter.queue_write(txn);
}

// Accessor functions to get pending handles (for testing)
DpiTxn* test_get_pending_read() {
    return g_port_adapter.get_pending_read();
}

DpiTxn* test_get_pending_write() {
    return g_port_adapter.get_pending_write();
}

// test_set_expected_txn_count - Set the expected total number of transactions for testing
void test_set_expected_txn_count(int count) {
    g_port_adapter.set_expected_txn_count(count);
}
