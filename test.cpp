// Test file for PortAdapter and DPI bridge functions
// Calls read and write randomly 20 times at different addresses

#include <iostream>
#include <cstdlib>
#include <ctime>
#include "port_adapter.h"

// External test functions from dpi_bridge.cpp
extern void test_queue_read(const DpiTxn& txn);
extern void test_queue_write(const DpiTxn& txn);
extern void test_set_expected_txn_count(int count);

// Forward declarations of DPI functions (simulated for standalone test)
extern "C" {
    int maybe_read(DpiTxn* txn);
    int maybe_write(DpiTxn* txn);
}

// Helper to generate random 16-bit value
uint16_t random_uint16() {
    return static_cast<uint16_t>(rand() % 65536);
}

// Helper to generate random address (within valid range)
uint16_t random_address() {
    // Addresses in range 0x0000 to 0x8000 based on dpi_bridge_pkg.sv
    return static_cast<uint16_t>(rand() % 0x8001);
}

// Helper to generate random portid
bool random_portid() {
    return (rand() % 2) == 1;
}

int main() {
    // Seed random number generator
    srand(static_cast<unsigned int>(time(nullptr)));

    // Generate random number of operations (1 to 50)
    int num_operations = (rand() % 50) + 1;

    // Set the expected transaction count for SystemVerilog to check against
    test_set_expected_txn_count(num_operations);

    std::cout << "=== PortAdapter Test ===" << std::endl;
    std::cout << "Testing " << num_operations << " random read/write operations\n" << std::endl;

    // Track statistics
    int reads_queued = 0;
    int writes_queued = 0;
    int reads_retrieved = 0;
    int writes_retrieved = 0;

    // Perform random number of operations
    for (int i = 0; i < num_operations; i++) {
        // Randomly decide: queue a read or write
        bool is_write = (rand() % 2) == 1;

        DpiTxn txn;
        txn.data = random_uint16();
        txn.address = random_address();
        txn.portid = random_portid();

        if (is_write) {
            test_queue_write(txn);
            writes_queued++;
            std::cout << "[" << (i + 1) << "] QUEUED WRITE: "
                      << "addr=0x" << std::hex << txn.address
                      << "  data=0x" << txn.data
                      << "  portid=" << std::dec << txn.portid
                      << std::endl;
        } else {
            test_queue_read(txn);
            reads_queued++;
            std::cout << "[" << (i + 1) << "] QUEUED READ:  "
                      << "addr=0x" << std::hex << txn.address
                      << "  data=0x" << txn.data
                      << "  portid=" << std::dec << txn.portid
                      << std::endl;
        }
    }

    std::cout << "\n--- Retrieving queued transactions ---\n" << std::endl;

    // Now retrieve all writes first (simulating SV polling)
    DpiTxn retrieved_txn;
    while (maybe_write(&retrieved_txn)) {
        writes_retrieved++;
        std::cout << "[WRITE] Retrieved: "
                  << "addr=0x" << std::hex << retrieved_txn.address
                  << "  data=0x" << retrieved_txn.data
                  << "  portid=" << std::dec << retrieved_txn.portid
                  << std::endl;
    }

    // Then retrieve all reads
    while (maybe_read(&retrieved_txn)) {
        reads_retrieved++;
        std::cout << "[READ]  Retrieved: "
                  << "addr=0x" << std::hex << retrieved_txn.address
                  << "  data=0x" << retrieved_txn.data
                  << "  portid=" << std::dec << retrieved_txn.portid
                  << std::endl;
    }

    // Print summary
    std::cout << "\n=== Test Summary ===" << std::endl;
    std::cout << "Reads  queued: " << reads_queued << std::endl;
    std::cout << "Writes queued: " << writes_queued << std::endl;
    std::cout << "Reads  retrieved: " << reads_retrieved << std::endl;
    std::cout << "Writes retrieved: " << writes_retrieved << std::endl;

    // Verify counts match
    bool success = (reads_queued == reads_retrieved) && 
                   (writes_queued == writes_retrieved);

    if (success) {
        std::cout << "\nTEST PASSED: All transactions retrieved correctly!" << std::endl;
        return 0;
    } else {
        std::cout << "\nTEST FAILED: Transaction count mismatch!" << std::endl;
        return 1;
    }
}