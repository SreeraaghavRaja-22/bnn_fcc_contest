`timescale 1ns/1ps
module config_manager_tb;

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    localparam int BUS_WIDTH      = 64;
    localparam int BEAT_WIDTH     = 16;
    localparam int POPCOUNT_WIDTH = 32;
    localparam int L1_INPUTS      = 256;
    localparam int L1_NEURONS     = 256;
    localparam int L2_NEURONS     = 256;
    localparam int L3_NEURONS     = 10;

    localparam int CLK_PERIOD  = 10;
    localparam int HBEATS      = (128 + BUS_WIDTH - 1) / BUS_WIDTH;

    localparam int L1_W_BEATS  = (L1_INPUTS  + BEAT_WIDTH-1) / BEAT_WIDTH;
    localparam int L2_W_BEATS  = (L1_NEURONS + BEAT_WIDTH-1) / BEAT_WIDTH;
    localparam int L3_W_BEATS  = (L2_NEURONS + BEAT_WIDTH-1) / BEAT_WIDTH;

    localparam int L1_W_WORDS  = L1_NEURONS * L1_W_BEATS;
    localparam int L2_W_WORDS  = L2_NEURONS * L2_W_BEATS;
    localparam int L3_W_WORDS  = L3_NEURONS * L3_W_BEATS;

    localparam int W_RATIO     = BUS_WIDTH / BEAT_WIDTH;
    localparam int T_RATIO     = BUS_WIDTH / POPCOUNT_WIDTH;

    // ----------------------------------------------------------------
    // DUT ports
    // ----------------------------------------------------------------
    logic clk, rst;
    logic [BUS_WIDTH-1:0]   config_data;
    logic [BUS_WIDTH/8-1:0] config_keep;
    logic                   config_valid;
    logic                   config_last;
    logic                   config_ready;

    logic                          l1_w_wr_en;
    logic [$clog2(L1_W_WORDS)-1:0] l1_w_wr_addr;
    logic [BEAT_WIDTH-1:0]         l1_w_wr_data;

    logic                          l2_w_wr_en;
    logic [$clog2(L2_W_WORDS)-1:0] l2_w_wr_addr;
    logic [BEAT_WIDTH-1:0]         l2_w_wr_data;

    logic                          l3_w_wr_en;
    logic [$clog2(L3_W_WORDS)-1:0] l3_w_wr_addr;
    logic [BEAT_WIDTH-1:0]         l3_w_wr_data;

    logic                          l1_t_wr_en;
    logic [$clog2(L1_NEURONS)-1:0] l1_t_wr_addr;
    logic [POPCOUNT_WIDTH-1:0]     l1_t_wr_data;

    logic                          l2_t_wr_en;
    logic [$clog2(L2_NEURONS)-1:0] l2_t_wr_addr;
    logic [POPCOUNT_WIDTH-1:0]     l2_t_wr_data;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    config_manager #(
        .BUS_WIDTH      (BUS_WIDTH),
        .BEAT_WIDTH     (BEAT_WIDTH),
        .POPCOUNT_WIDTH (POPCOUNT_WIDTH),
        .L1_INPUTS      (L1_INPUTS),
        .L1_NEURONS     (L1_NEURONS),
        .L2_NEURONS     (L2_NEURONS),
        .L3_NEURONS     (L3_NEURONS)
    ) dut (.*);

    // ----------------------------------------------------------------
    // Shadow RAMs
    // ----------------------------------------------------------------
    logic [BEAT_WIDTH-1:0]     l1_w_ram [L1_W_WORDS];
    logic [BEAT_WIDTH-1:0]     l2_w_ram [L2_W_WORDS];
    logic [BEAT_WIDTH-1:0]     l3_w_ram [L3_W_WORDS];
    logic [POPCOUNT_WIDTH-1:0] l1_t_ram [L1_NEURONS];
    logic [POPCOUNT_WIDTH-1:0] l2_t_ram [L2_NEURONS];

    // Written-address tracking — detect missed or out-of-range writes
    bit l1_w_written [L1_W_WORDS];
    bit l2_w_written [L2_W_WORDS];
    bit l3_w_written [L3_W_WORDS];
    bit l1_t_written [L1_NEURONS];
    bit l2_t_written [L2_NEURONS];

    // Use blocking assignments so the shadow RAM updates immediately
    // after posedge NBA resolution — correct for combinational DUT outputs.
    always @(posedge clk) begin
        if (l1_w_wr_en) begin l1_w_ram[l1_w_wr_addr] = l1_w_wr_data; l1_w_written[l1_w_wr_addr] = 1; end
        if (l2_w_wr_en) begin l2_w_ram[l2_w_wr_addr] = l2_w_wr_data; l2_w_written[l2_w_wr_addr] = 1; end
        if (l3_w_wr_en) begin l3_w_ram[l3_w_wr_addr] = l3_w_wr_data; l3_w_written[l3_w_wr_addr] = 1; end
        if (l1_t_wr_en) begin l1_t_ram[l1_t_wr_addr] = l1_t_wr_data; l1_t_written[l1_t_wr_addr] = 1; end
        if (l2_t_wr_en) begin l2_t_ram[l2_t_wr_addr] = l2_t_wr_data; l2_t_written[l2_t_wr_addr] = 1; end
    end

    // ----------------------------------------------------------------
    // Reference models
    // ----------------------------------------------------------------
    logic [BEAT_WIDTH-1:0]     ref_l1_w [L1_W_WORDS];
    logic [BEAT_WIDTH-1:0]     ref_l2_w [L2_W_WORDS];
    logic [BEAT_WIDTH-1:0]     ref_l3_w [L3_W_WORDS];
    logic [POPCOUNT_WIDTH-1:0] ref_l1_t [L1_NEURONS];
    logic [POPCOUNT_WIDTH-1:0] ref_l2_t [L2_NEURONS];

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ----------------------------------------------------------------
    // Scoreboard
    // ----------------------------------------------------------------
    int total_errors;

    // ----------------------------------------------------------------
    // Task: drive one beat, hold valid until ready, random idle before
    // ----------------------------------------------------------------
    task automatic drive_beat(
        input logic [BUS_WIDTH-1:0] beat,
        input logic                 last
    );
        // Random idle cycles before asserting valid
        repeat ($urandom_range(0, 3)) @(posedge clk);
        // Wait until config_ready is high BEFORE asserting valid
        while (!config_ready) @(posedge clk);
        // Drive data combinationally (blocking) so it is visible
        // to the DUT on the very next posedge without NBA delay
        config_data  = beat;
        config_valid = 1'b1;
        config_keep  = '1;
        config_last  = last;
        // Cycle 1: DUT sees valid=1, ready=1 → loads sr_r (NBA)
        @(posedge clk);
        // Cycle 2: sr_loaded_r=1, combinational wr_en fires,
        //          always_ff shadow captures the write
        // Hold valid low — beat already accepted
        config_valid = 1'b0;
        config_last  = 1'b0;
    endtask

    // ----------------------------------------------------------------
    // Task: send full packet (header + payload)
    // ----------------------------------------------------------------
    task automatic send_packet(
        input logic [127:0] header,
        input logic [7:0]   payload [],
        input int            total_payload_bytes
    );
        logic [BUS_WIDTH-1:0] beat;
        int payload_beats;
        int byte_offset;

        for (int h = 0; h < HBEATS; h++) begin
            beat = header[h*BUS_WIDTH +: BUS_WIDTH];
            drive_beat(beat, 1'b0);
        end

        payload_beats = (total_payload_bytes + (BUS_WIDTH/8) - 1) / (BUS_WIDTH/8);
        for (int p = 0; p < payload_beats; p++) begin
            beat = '0;
            for (int b = 0; b < BUS_WIDTH/8; b++) begin
                byte_offset = p * (BUS_WIDTH/8) + b;
                if (byte_offset < total_payload_bytes)
                    beat[b*8 +: 8] = payload[byte_offset];
            end
            drive_beat(beat, (p == payload_beats-1) ? 1'b1 : 1'b0);
        end
    endtask

    // ----------------------------------------------------------------
    // Task: build + send weight packet, fill reference model
    // ----------------------------------------------------------------
    task automatic send_weight_packet(
        input int layer,
        input int n_inputs,
        input int n_neurons
    );
        int                    words_per_neuron, total_words, total_bytes_payload;
        logic [7:0]            payload [];
        logic [127:0]          header;
        logic [BEAT_WIDTH-1:0] val;

        words_per_neuron    = (n_inputs + BEAT_WIDTH - 1) / BEAT_WIDTH;
        total_words         = n_neurons * words_per_neuron;
        total_bytes_payload = total_words * (BEAT_WIDTH / 8);

        // Align to bus width so bytes_left_r terminates cleanly
        if ((total_bytes_payload % (BUS_WIDTH/8)) != 0)
            total_bytes_payload += (BUS_WIDTH/8) - (total_bytes_payload % (BUS_WIDTH/8));

        payload = new[total_bytes_payload];

        for (int w = 0; w < total_words; w++) begin
            val = $urandom();
            for (int b = 0; b < BEAT_WIDTH/8; b++)
                payload[w*(BEAT_WIDTH/8) + b] = val[b*8 +: 8];
            case (layer)
                0: ref_l1_w[w] = val;
                1: ref_l2_w[w] = val;
                2: ref_l3_w[w] = val;
                default: ;
            endcase
        end

        header        = '0;
        header[7:0]   = 8'h00;
        header[15:8]  = 8'(layer);
        header[31:16] = 16'(n_inputs);
        header[47:32] = 16'(n_neurons);
        header[63:48] = 16'(words_per_neuron * (BEAT_WIDTH/8));
        header[95:64] = 32'(total_bytes_payload);

        $display("[TB] Weight pkt layer=%0d n_neurons=%0d n_inputs=%0d total_bytes=%0d",
                 layer, n_neurons, n_inputs, total_bytes_payload);
        send_packet(header, payload, total_bytes_payload);
    endtask

    // ----------------------------------------------------------------
    // Task: build + send threshold packet, fill reference model
    // ----------------------------------------------------------------
    task automatic send_threshold_packet(
        input int layer,
        input int n_neurons
    );
        int                        total_bytes_payload;
        logic [7:0]                payload [];
        logic [127:0]              header;
        logic [POPCOUNT_WIDTH-1:0] val;

        total_bytes_payload = n_neurons * (POPCOUNT_WIDTH / 8);

        if ((total_bytes_payload % (BUS_WIDTH/8)) != 0)
            total_bytes_payload += (BUS_WIDTH/8) - (total_bytes_payload % (BUS_WIDTH/8));

        payload = new[total_bytes_payload];

        for (int n = 0; n < n_neurons; n++) begin
            val = $urandom();
            for (int b = 0; b < POPCOUNT_WIDTH/8; b++)
                payload[n*(POPCOUNT_WIDTH/8) + b] = val[b*8 +: 8];
            case (layer)
                0: ref_l1_t[n] = val;
                1: ref_l2_t[n] = val;
                default: ;
            endcase
        end

        header        = '0;
        header[7:0]   = 8'h01;
        header[15:8]  = 8'(layer);
        header[47:32] = 16'(n_neurons);
        header[63:48] = 16'(POPCOUNT_WIDTH/8);
        header[95:64] = 32'(total_bytes_payload);

        $display("[TB] Threshold pkt layer=%0d n_neurons=%0d total_bytes=%0d",
                 layer, n_neurons, total_bytes_payload);
        send_packet(header, payload, total_bytes_payload);
    endtask

    // ----------------------------------------------------------------
    // Task: clear written-flags before fresh packet
    // ----------------------------------------------------------------
    task automatic clear_written_flags(input int layer, input bit is_threshold);
        if (!is_threshold) begin
            case (layer)
                0: foreach (l1_w_written[i]) l1_w_written[i] = 0;
                1: foreach (l2_w_written[i]) l2_w_written[i] = 0;
                2: foreach (l3_w_written[i]) l3_w_written[i] = 0;
                default: ;
            endcase
        end else begin
            case (layer)
                0: foreach (l1_t_written[i]) l1_t_written[i] = 0;
                1: foreach (l2_t_written[i]) l2_t_written[i] = 0;
                default: ;
            endcase
        end
    endtask

    // ----------------------------------------------------------------
    // Task: check weight shadow RAM vs reference
    // ----------------------------------------------------------------
    task automatic check_weights(input int layer, input int total_words);
        int errors;
        logic [BEAT_WIDTH-1:0] got, exp;
        bit written;

        errors = 0;
        for (int w = 0; w < total_words; w++) begin
            case (layer)
                0: begin got = l1_w_ram[w]; exp = ref_l1_w[w]; written = l1_w_written[w]; end
                1: begin got = l2_w_ram[w]; exp = ref_l2_w[w]; written = l2_w_written[w]; end
                2: begin got = l3_w_ram[w]; exp = ref_l3_w[w]; written = l3_w_written[w]; end
                default: begin got = '0; exp = '1; written = 0; end
            endcase

            if (!written) begin
                $error("[FAIL] Weight L%0d word[%0d] never written", layer+1, w);
                errors++;
            end else if (got !== exp) begin
                $error("[FAIL] Weight L%0d word[%0d]: got=0x%0h exp=0x%0h", layer+1, w, got, exp);
                errors++;
            end
        end

        total_errors += errors;
        if (errors == 0)
            $display("[PASS] Weight L%0d: all %0d words correct", layer+1, total_words);
        else begin
            $display("[FAIL] Weight L%0d: %0d errors", layer+1, errors);
            // Print first 4 to diagnose ordering
            for (int d = 0; d < 4 && d < total_words; d++) begin
                case (layer)
                    0: $display("[DIAG] word[%0d] shadow=0x%0h ref=0x%0h written=%0b",
                                d, l1_w_ram[d], ref_l1_w[d], l1_w_written[d]);
                    1: $display("[DIAG] word[%0d] shadow=0x%0h ref=0x%0h written=%0b",
                                d, l2_w_ram[d], ref_l2_w[d], l2_w_written[d]);
                    2: $display("[DIAG] word[%0d] shadow=0x%0h ref=0x%0h written=%0b",
                                d, l3_w_ram[d], ref_l3_w[d], l3_w_written[d]);
                    default: ;
                endcase
            end
        end
    endtask

    // ----------------------------------------------------------------
    // Task: check threshold shadow RAM vs reference
    // ----------------------------------------------------------------
    task automatic check_thresholds(input int layer, input int n_neurons);
        int errors;
        logic [POPCOUNT_WIDTH-1:0] got, exp;
        bit written;

        errors = 0;
        for (int n = 0; n < n_neurons; n++) begin
            case (layer)
                0: begin got = l1_t_ram[n]; exp = ref_l1_t[n]; written = l1_t_written[n]; end
                1: begin got = l2_t_ram[n]; exp = ref_l2_t[n]; written = l2_t_written[n]; end
                default: begin got = '0; exp = '1; written = 0; end
            endcase

            if (!written) begin
                $error("[FAIL] Threshold L%0d neuron[%0d] never written", layer+1, n);
                errors++;
            end else if (got !== exp) begin
                $error("[FAIL] Threshold L%0d neuron[%0d]: got=0x%0h exp=0x%0h",
                       layer+1, n, got, exp);
                errors++;
            end
        end

        total_errors += errors;
        if (errors == 0)
            $display("[PASS] Threshold L%0d: all %0d neurons correct", layer+1, n_neurons);
        else
            $display("[FAIL] Threshold L%0d: %0d errors", layer+1, errors);
    endtask

    // ----------------------------------------------------------------
    // Watchdog
    // ----------------------------------------------------------------
    int watchdog_ctr = 0;
    always_ff @(posedge clk) begin
        if (config_valid && !config_ready)
            watchdog_ctr <= watchdog_ctr + 1;
        else
            watchdog_ctr <= 0;
        if (watchdog_ctr > 2000) begin
            $error("[WATCHDOG] config_ready stuck low for 2000 cycles — FSM hung");
            $finish;
        end
    end

    // ----------------------------------------------------------------
    // Assertions: mutual exclusion on write enables
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if ((l1_w_wr_en + l2_w_wr_en + l3_w_wr_en) > 1)
            $error("[ASSERT] Multiple weight wr_en high simultaneously");
        if ((l1_t_wr_en + l2_t_wr_en) > 1)
            $error("[ASSERT] Multiple threshold wr_en high simultaneously");
    end

    // ----------------------------------------------------------------
    // Assertions: write address in range
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (l1_w_wr_en && (int'(l1_w_wr_addr) >= L1_W_WORDS))
            $error("[ASSERT] l1_w_wr_addr=%0d out of range (max=%0d)", l1_w_wr_addr, L1_W_WORDS-1);
        if (l2_w_wr_en && (int'(l2_w_wr_addr) >= L2_W_WORDS))
            $error("[ASSERT] l2_w_wr_addr=%0d out of range (max=%0d)", l2_w_wr_addr, L2_W_WORDS-1);
        if (l3_w_wr_en && (int'(l3_w_wr_addr) >= L3_W_WORDS))
            $error("[ASSERT] l3_w_wr_addr=%0d out of range (max=%0d)", l3_w_wr_addr, L3_W_WORDS-1);
        if (l1_t_wr_en && (int'(l1_t_wr_addr) >= L1_NEURONS))
            $error("[ASSERT] l1_t_wr_addr=%0d out of range (max=%0d)", l1_t_wr_addr, L1_NEURONS-1);
        if (l2_t_wr_en && (int'(l2_t_wr_addr) >= L2_NEURONS))
            $error("[ASSERT] l2_t_wr_addr=%0d out of range (max=%0d)", l2_t_wr_addr, L2_NEURONS-1);
    end

    // ----------------------------------------------------------------
    // Monitor (uncomment for verbose runs)
    // ----------------------------------------------------------------
    // always_ff @(posedge clk) begin
    //     if (l1_w_wr_en) $display("[MON] L1W addr=%0d data=0x%0h", l1_w_wr_addr, l1_w_wr_data);
    //     if (l2_w_wr_en) $display("[MON] L2W addr=%0d data=0x%0h", l2_w_wr_addr, l2_w_wr_data);
    //     if (l3_w_wr_en) $display("[MON] L3W addr=%0d data=0x%0h", l3_w_wr_addr, l3_w_wr_data);
    //     if (l1_t_wr_en) $display("[MON] L1T addr=%0d data=0x%0h", l1_t_wr_addr, l1_t_wr_data);
    //     if (l2_t_wr_en) $display("[MON] L2T addr=%0d data=0x%0h", l2_t_wr_addr, l2_t_wr_data);
    // end

    // ----------------------------------------------------------------
    // Main test sequence
    // ----------------------------------------------------------------
    initial begin
        total_errors = 0;
        rst          = 1;
        config_data  = '0;
        config_keep  = '0;
        config_valid = 0;
        config_last  = 0;
        repeat(4) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        // ---- Test 1: L1 weights ----
        $display("\n[TEST 1] L1 weights");
        clear_written_flags(0, 0);
        send_weight_packet(0, L1_INPUTS, L1_NEURONS);
        repeat(4) @(posedge clk);
        check_weights(0, L1_W_WORDS);

        // ---- Test 2: L1 thresholds ----
        $display("\n[TEST 2] L1 thresholds");
        clear_written_flags(0, 1);
        send_threshold_packet(0, L1_NEURONS);
        repeat(4) @(posedge clk);
        check_thresholds(0, L1_NEURONS);

        // ---- Test 3: L2 weights ----
        $display("\n[TEST 3] L2 weights");
        clear_written_flags(1, 0);
        send_weight_packet(1, L1_NEURONS, L2_NEURONS);
        repeat(4) @(posedge clk);
        check_weights(1, L2_W_WORDS);

        // ---- Test 4: L2 thresholds ----
        $display("\n[TEST 4] L2 thresholds");
        clear_written_flags(1, 1);
        send_threshold_packet(1, L2_NEURONS);
        repeat(4) @(posedge clk);
        check_thresholds(1, L2_NEURONS);

        // ---- Test 5: L3 weights ----
        $display("\n[TEST 5] L3 weights");
        clear_written_flags(2, 0);
        send_weight_packet(2, L2_NEURONS, L3_NEURONS);
        repeat(4) @(posedge clk);
        check_weights(2, L3_W_WORDS);

        // ---- Test 6: back-to-back all 5 packets ----
        $display("\n[TEST 6] Back-to-back all packets");
        clear_written_flags(0, 0); clear_written_flags(0, 1);
        clear_written_flags(1, 0); clear_written_flags(1, 1);
        clear_written_flags(2, 0);
        send_weight_packet(0, L1_INPUTS,  L1_NEURONS);
        send_threshold_packet(0, L1_NEURONS);
        send_weight_packet(1, L1_NEURONS, L2_NEURONS);
        send_threshold_packet(1, L2_NEURONS);
        send_weight_packet(2, L2_NEURONS, L3_NEURONS);
        repeat(4) @(posedge clk);
        check_weights(0, L1_W_WORDS);
        check_thresholds(0, L1_NEURONS);
        check_weights(1, L2_W_WORDS);
        check_thresholds(1, L2_NEURONS);
        check_weights(2, L3_W_WORDS);

        // ---- Test 7: overwrite same layer ----
        $display("\n[TEST 7] Overwrite L1 weights with new data");
        clear_written_flags(0, 0);
        send_weight_packet(0, L1_INPUTS, L1_NEURONS);
        repeat(4) @(posedge clk);
        check_weights(0, L1_W_WORDS);

        // ---- Summary ----
        $display("\n========================================");
        if (total_errors == 0)
            $display("[DONE] All tests PASSED");
        else
            $display("[DONE] FAILED — %0d total errors", total_errors);
        $display("========================================\n");
        $finish;
    end

endmodule