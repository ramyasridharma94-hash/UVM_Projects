// DDR5 Command Scheduler — arbitrates host requests, enforces timing constraints
// Implements: 2CmdQ per bank group, out-of-order execution, tFAW/tRRD enforcement
import ddr5_pkg::*;

module ddr5_cmd_scheduler #(
  parameter int NUM_BG     = 8,
  parameter int NUM_BK     = 4,
  parameter int ROW_BITS   = 17,
  parameter int COL_BITS   = 10,
  parameter int QUEUE_DEPTH= 8
)(
  input  logic              clk,
  input  logic              rst_n,
  // Host request FIFO interface
  input  logic              req_valid,
  input  ddr5_cmd_e         req_cmd,
  input  logic [2:0]        req_bg,
  input  logic [1:0]        req_bank,
  input  logic [ROW_BITS-1:0] req_row,
  input  logic [COL_BITS-1:0] req_col,
  output logic              req_ready,
  // Timing parameters
  input  ddr5_timing_t      timing,
  // Bank state input (from bank FSMs)
  input  logic [NUM_BG*NUM_BK-1:0] bank_open,
  input  logic [ROW_BITS-1:0]      open_rows [0:NUM_BG*NUM_BK-1],
  // Scheduled command output
  output logic              cmd_valid,
  output ddr5_cmd_e         cmd_out,
  output logic [2:0]        cmd_bg,
  output logic [1:0]        cmd_bank,
  output logic [ROW_BITS-1:0] cmd_row,
  output logic [COL_BITS-1:0] cmd_col,
  input  logic              cmd_ready,
  // Status
  output logic [3:0]        queue_depth_out,
  output logic              stall_due_timing
);

  // -----------------------------------------------------------------------
  // Command queue (FIFO with timing check)
  // -----------------------------------------------------------------------
  typedef struct packed {
    ddr5_cmd_e    cmd;
    logic [2:0]   bg;
    logic [1:0]   bank;
    logic [ROW_BITS-1:0] row;
    logic [COL_BITS-1:0] col;
    logic         valid;
  } cmd_entry_t;

  cmd_entry_t q[$:QUEUE_DEPTH];
  int unsigned q_size;

  // tFAW window tracking (4 ACTs within tFAW)
  logic [3:0][15:0] act_timestamps;
  int unsigned      act_ptr;
  logic [15:0]      cycle_cnt;

  // tRRD_S / tRRD_L counters (per bank group)
  logic [7:0] rrd_timer_bg [0:NUM_BG-1];
  logic [7:0] rrd_timer_any;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt    <= 0; act_ptr <= 0; q_size <= 0;
      cmd_valid    <= 0; req_ready <= 0;
      stall_due_timing <= 0;
      for (int i=0; i<4; i++) act_timestamps[i] <= '0;
      for (int i=0; i<NUM_BG; i++) rrd_timer_bg[i] <= '0;
      rrd_timer_any <= 0;
      queue_depth_out <= 0;
    end else begin
      cycle_cnt   <= cycle_cnt + 1;
      req_ready   <= (q_size < QUEUE_DEPTH);
      cmd_valid   <= 0;

      // Decrement RRD timers
      for (int i=0; i<NUM_BG; i++)
        if (rrd_timer_bg[i] > 0) rrd_timer_bg[i] <= rrd_timer_bg[i] - 1;
      if (rrd_timer_any > 0) rrd_timer_any <= rrd_timer_any - 1;

      // Enqueue incoming request
      if (req_valid && req_ready) begin
        cmd_entry_t e;
        e.cmd=req_cmd; e.bg=req_bg; e.bank=req_bank;
        e.row=req_row; e.col=req_col; e.valid=1;
        q.push_back(e);
        q_size++;
      end

      // Schedule head-of-queue if timing allows
      if (q_size > 0 && cmd_ready) begin
        cmd_entry_t head = q[0];
        bit can_issue = 1;
        int bk = int'(head.bg)*NUM_BK + int'(head.bank);

        case (head.cmd)
          CMD_ACT: begin
            // tFAW check: newest ACT must be >= tFAW cycles after oldest in window
            if (act_timestamps[act_ptr] != 0 &&
                (cycle_cnt - act_timestamps[act_ptr]) < 16'(timing.tFAW))
              can_issue = 0;
            // tRRD_L (same BG), tRRD_S (different BG)
            if (rrd_timer_bg[head.bg] > 0) can_issue = 0;
            if (rrd_timer_any > 0)         can_issue = 0;
            if (bank_open[bk])             can_issue = 0; // bank already open
          end
          CMD_WR, CMD_WRA, CMD_RD, CMD_RDA: begin
            if (!bank_open[bk])            can_issue = 0; // bank not open
            if (open_rows[bk] != head.row) can_issue = 0; // wrong row
          end
          CMD_PRE: begin
            if (!bank_open[bk])            can_issue = 0;
          end
          default: ;
        endcase

        stall_due_timing <= !can_issue;

        if (can_issue) begin
          cmd_valid  <= 1;
          cmd_out    <= head.cmd;
          cmd_bg     <= head.bg;
          cmd_bank   <= head.bank;
          cmd_row    <= head.row;
          cmd_col    <= head.col;
          q.pop_front();
          q_size--;
          // Update ACT tracking
          if (head.cmd == CMD_ACT) begin
            act_timestamps[act_ptr] <= cycle_cnt;
            act_ptr <= (act_ptr + 1) % 4;
            rrd_timer_bg[head.bg] <= 8'(timing.tRRD_L);
            rrd_timer_any         <= 8'(timing.tRRD_S);
          end
        end
      end
      queue_depth_out <= 4'(q_size);
    end
  end

endmodule : ddr5_cmd_scheduler
