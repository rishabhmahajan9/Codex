// PortAdapter class definition
// Matches dpi_txn_t struct from dpi_bridge_pkg.sv

#ifndef PORT_ADAPTER_H
#define PORT_ADAPTER_H

#include <cstdint>
#include <vector>

// DPI transaction structure matching SystemVerilog dpi_txn_t
struct DpiTxn {
    uint16_t data;     // bit [15:0] data
    uint16_t address;  // bit [15:0] address
    bool     portid;   // bit portid
};

class PortAdapter {
private:
    DpiTxn* pending_read;   // Handle to pending read transaction
    DpiTxn* pending_write;  // Handle to pending write transaction
    std::vector<DpiTxn> read_queue;   // Queue of pending reads
    std::vector<DpiTxn> write_queue;  // Queue of pending writes
    int expected_txn_count; // Expected total number of transactions

public:
    // Constructor
    PortAdapter();

    // Destructor
    ~PortAdapter();

    // Helper functions
    DpiTxn* get_pending_read();
    DpiTxn* get_pending_write();

    // Adapter functions - fill pending transaction
    bool read_adapter(DpiTxn* txn);
    bool write_adapter(DpiTxn* txn);

    // Queue management functions
    void queue_read(const DpiTxn& txn);
    void queue_write(const DpiTxn& txn);

    // Transaction count management
    void set_expected_txn_count(int count);
    int get_expected_txn_count();
};

#endif // PORT_ADAPTER_H