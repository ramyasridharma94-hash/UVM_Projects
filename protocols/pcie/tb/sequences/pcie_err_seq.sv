`ifndef PCIE_ERR_SEQ_SV
`define PCIE_ERR_SEQ_SV

// Error injection sequence — covers correctable and uncorrectable errors
class pcie_err_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_err_seq)
  import pcie_pkg::*;

  // Which error to inject
  rand pcie_error_e err_type;

  // Restrict to injectable errors
  constraint c_err_sel {
    err_type inside {
      ERR_ECRC,
      ERR_BAD_TLP,
      ERR_BAD_DLLP,
      ERR_MALFORMED_TLP,
      ERR_POISONED_TLP,
      ERR_UNSUPPORTED_REQ,
      ERR_COMPLETER_ABORT,
      ERR_UNEXPECTED_CPL,
      ERR_DATA_LINK_PROTO,
      ERR_RECEIVER_OVERFLOW
    };
  }

  function new(string name = "pcie_err_seq");
    super.new(name);
  endfunction

  task body();
    pcie_tlp_seq_item item;
    // Send some good traffic first
    for (int i = 0; i < 4; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("pre_err_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type  inside {MWr32, MWr64};
          length    inside {[1:4]};
          inject_err == ERR_NONE; ep == 0;
      })
        `uvm_fatal("RAND", "pcie_err_seq: pre-error randomize failed")
      finish_item(item);
    end

    // Now inject the error
    `uvm_info("ERR_SEQ", $sformatf("Injecting error: %s", err_type.name()), UVM_LOW)
    item = pcie_tlp_seq_item::type_id::create("err_tlp");
    start_item(item);
    case (err_type)
      ERR_ECRC: begin
        if (!item.randomize() with {
            tlp_type == MWr32; length == 1;
            inject_err == ERR_ECRC; ecrc_en == 1;
        })
          `uvm_fatal("RAND", "ERR_ECRC randomize failed")
      end
      ERR_POISONED_TLP: begin
        if (!item.randomize() with {
            tlp_type == MWr64; length == 2;
            inject_err == ERR_POISONED_TLP; ep == 1;
        })
          `uvm_fatal("RAND", "ERR_POISONED_TLP randomize failed")
      end
      ERR_BAD_TLP, ERR_BAD_DLLP: begin
        if (!item.randomize() with {
            tlp_type == MWr32; length == 1;
            inject_err == err_type;
        })
          `uvm_fatal("RAND", "ERR_BAD_TLP randomize failed")
      end
      ERR_UNSUPPORTED_REQ: begin
        if (!item.randomize() with {
            tlp_type == MRd32;
            addr == 64'hFFFF_FFFF;  // Unsupported address
            inject_err == ERR_UNSUPPORTED_REQ;
        })
          `uvm_fatal("RAND", "ERR_UNSUPPORTED_REQ randomize failed")
      end
      ERR_COMPLETER_ABORT: begin
        if (!item.randomize() with {
            tlp_type  == CplD;
            cpl_status == CPL_CA;
            inject_err == ERR_COMPLETER_ABORT;
        })
          `uvm_fatal("RAND", "ERR_COMPLETER_ABORT randomize failed")
      end
      default: begin
        if (!item.randomize() with { inject_err == err_type; })
          `uvm_fatal("RAND", "pcie_err_seq: default randomize failed")
      end
    endcase
    finish_item(item);
    `uvm_info("ERR_SEQ", $sformatf("Error TLP sent: %s", item.convert2string()), UVM_LOW)

    // Recovery traffic after error
    for (int i = 0; i < 4; i++) begin
      item = pcie_tlp_seq_item::type_id::create($sformatf("post_err_%0d", i));
      start_item(item);
      if (!item.randomize() with {
          tlp_type inside {MRd32, MWr32}; length inside {[1:4]};
          inject_err == ERR_NONE; ep == 0;
      })
        `uvm_fatal("RAND", "pcie_err_seq: post-error randomize failed")
      finish_item(item);
    end
  endtask

endclass : pcie_err_seq

// AER sweep — iterate through all error types
class pcie_aer_sweep_seq extends pcie_base_seq;
  `uvm_object_utils(pcie_aer_sweep_seq)
  import pcie_pkg::*;

  pcie_error_e err_list [] = '{
    ERR_ECRC, ERR_BAD_TLP, ERR_BAD_DLLP,
    ERR_MALFORMED_TLP, ERR_UNSUPPORTED_REQ, ERR_COMPLETER_ABORT,
    ERR_POISONED_TLP, ERR_DATA_LINK_PROTO
  };

  function new(string name = "pcie_aer_sweep_seq");
    super.new(name);
  endfunction

  task body();
    foreach (err_list[i]) begin
      pcie_err_seq es = pcie_err_seq::type_id::create($sformatf("aer_err_%0d", i));
      es.err_type = err_list[i];
      es.start(m_sequencer);
    end
  endtask

endclass : pcie_aer_sweep_seq

`endif
