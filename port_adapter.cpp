// PortAdapter class implementation

#include "port_adapter.h"

PortAdapter::PortAdapter() 
    : pending_read(nullptr), pending_write(nullptr), expected_txn_count(0) {
}

PortAdapter::~PortAdapter() {
    // No dynamic memory to free for pending_read/write pointers
    // as they point to queue elements
}

DpiTxn* PortAdapter::get_pending_read() {
    return pending_read;
}

DpiTxn* PortAdapter::get_pending_write() {
    return pending_write;
}

bool PortAdapter::read_adapter(DpiTxn* txn) {
    if (read_queue.empty()) {
        return false;
    }
    
    // Get the next read from the queue
    *txn = read_queue.front();
    read_queue.erase(read_queue.begin());
    
    pending_read = txn;
    return true;
}

bool PortAdapter::write_adapter(DpiTxn* txn) {
    if (write_queue.empty()) {
        return false;
    }
    
    // Get the next write from the queue
    *txn = write_queue.front();
    write_queue.erase(write_queue.begin());
    
    pending_write = txn;
    return true;
}

void PortAdapter::queue_read(const DpiTxn& txn) {
    read_queue.push_back(txn);
}

void PortAdapter::queue_write(const DpiTxn& txn) {
    write_queue.push_back(txn);
}

void PortAdapter::set_expected_txn_count(int count) {
    expected_txn_count = count;
}

int PortAdapter::get_expected_txn_count() {
    return expected_txn_count;
}
