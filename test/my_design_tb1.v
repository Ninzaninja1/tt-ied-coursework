// =============================================================================
//  * Cycle numbering used in all comments (E = clock edge, sampled values):
//        E0  first posedge that samples ui_in[7]=1  (letter sampled here too)
//        E1  DUT decides: accept/drop.  ena is sampled HERE.
//        E8  encrypted result becomes visible (valid letters)
//        E1  echo result becomes visible (letters 26..31)
//        R0  first posedge with rst_n=1 (config byte 0 is sampled here)
//
//  Stimulus is driven 1 ns AFTER the falling clock edge and the DUT/monitor
//  sample on the rising edge, so there are no simulation races.
//
//  Simulator notes: written for Icarus Verilog 11/12 (-g2012) and Questa.  Only
//  procedural checks are used by default (Icarus has no concurrent assertions).
//  Define USE_SVA on Questa to add a few concurrent assertions (see bottom).
// =============================================================================



// Things I want checked in the testbench: 3 categories (Functionality, Response to signals, Boundary Conditions).

// Functionality:tests Enigma encryption behavior across rotors I–V, reflector B, plugboard cable swaps, mechanical rotor stepping (including notch carry, double-stepping, and '25 -> 0' rollovers), 8-cycle valid-letter latency, reciprocity ('encrypt(encrypt(x)) = x'), and known-answer vectors.


// Response: tests how the design responds to power-up and sync resets of different lengths, resets  at mid-config or mid-encryption (and check for remnants), strobe pulse widths and spacing, 'ena' held low or toggled across 'E0/E1'/mid-encryption/config loading, and unused plugboard values


// Boundary Conditions: This testbench tests out-of-range and unused values across inputs, including rotor positions 26 to 31, invalid rotor selects 5 to 7  (expected fallback to rotor I), unused plugboard endpoint codes (26 to 31) on single or both ends, invalid letter codes (26 to 31) (echoed without stepping), and reserved/junk bits on `ui_in[6:5]` and plug config bytes `uio_in[7:5]`.


`timescale 1ns/1ps

module tb_enigma;

    // =========================================================================
    // 0. USER-TUNABLE PARAMETERS  (override with  -P tb_enigma.NAME=value )
    // =========================================================================
    parameter integer DEFAULT_RANDOM_SEED       = 1;
    parameter integer NUM_RANDOM_CONFIGS        = 60;
    parameter integer LETTERS_PER_RANDOM_CONFIG = 40;
    parameter integer EXHAUSTIVE_POSITION_STEP  = 1;   // 1 = all 26 start positions; 5 = quick run
    parameter integer MAX_PRINTED_ERRORS        = 60;  // errors are always counted, only printing stops
    parameter integer MAX_SIM_TIME_NS           = 1000000000; // watchdog

    // =========================================================================
    // 1. CONSTANTS DESCRIBING THE DESIGN 
    // =========================================================================
    localparam integer CLOCK_PERIOD_NS   = 20;
    localparam integer SETTLE_DELAY_NS   = 1;

    localparam integer LATENCY_ENCRYPT_CYCLES  = 8;  // E0 -> result visible, letters 0..25
    localparam integer LATENCY_ECHO_CYCLES     = 1;  // E0 -> result visible, letters 26..31
    localparam integer CONFIG_BYTE_COUNT       = 7;  // bytes sampled at R0..R6
    localparam integer CONFIG_FIRST_STROBE_EDGE= 8;  // earliest R-index for E0 of an ACCEPTED request
    localparam integer CONFIG_FIRST_GO_EDGE    = 9;  // = CONFIG_FIRST_STROBE_EDGE + 1  (E1)
    localparam integer MIN_ACCEPTED_SPACING    = 8;  // E0 -> next accepted E0 for a valid letter
    localparam integer RESPONSE_TIMEOUT_CYCLES = 16;

    localparam integer NO_CABLE = 31;                // "unused plug endpoint" code
    localparam integer INVALID_SELECT_FALLBACK_ROTOR = 0; // intended meaning of select 5,6,7 = rotor I
    localparam [7:0]   IDLE_UIO_VALUE = 8'h00;

    // Error categories used in the final report
    localparam integer CAT_PROTOCOL = 0;  // response timing / count problems
    localparam integer CAT_DATA     = 1;  // wrong data
    localparam integer CAT_ASSERT   = 2;  // interface assertions (reserved bits, uio, X, stability, range)
    localparam integer CAT_INTENT   = 3;  // a test scenario expectation (e.g. "request should be accepted")

    // Rotor wirings and reflector B, copied from the comments in rotor_luts.vh.
    // (Written here as plain letter strings, NOT copied from the DUT's functions.)
    localparam [8*26-1:0] WIRING_ROTOR_I     = "EKMFLGDQVZNTOWYHXUSPAIBRCJ";
    localparam [8*26-1:0] WIRING_ROTOR_II    = "AJDKSIRUXBLHWTMCQGZNPYFVOE";
    localparam [8*26-1:0] WIRING_ROTOR_III   = "BDFHJLCPRTXVZNYEIWGAKMUSQO";
    localparam [8*26-1:0] WIRING_ROTOR_IV    = "ESOVPZJAYQUIRHXLNFTGKDCMWB";
    localparam [8*26-1:0] WIRING_ROTOR_V     = "VZBRGITYUPSDNHLXAWMJQOFECK";
    localparam [8*26-1:0] WIRING_REFLECTOR_B = "YRUHQSLDPXNGOKMIEBFZCWVJAT";
    localparam [8*5-1:0]  NOTCH_LETTERS      = "QEVJZ";   // rotors I-V

    // =========================================================================
    // 2. SIGNALS, DUT, CLOCK
    // =========================================================================
    reg        clk;
    reg        rst_n;
    reg        ena;
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Extra stimulus knobs (tests change these; defaults are the "normal" values)
    reg  [1:0] ui_junk_bits;               // driven on ui_in[6:5] (must be ignored by the DUT)
    reg  [2:0] plug_byte_junk_bits;        // driven on uio_in[7:5] of plug bytes (must be ignored)
    reg        hold_strobe_during_config;  // keep ui_in[7] high while config bytes are sent

    tt_um_ninzaninja1_ied_coursework dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    initial clk = 1'b0;
    always #(CLOCK_PERIOD_NS/2) clk = ~clk;

    // =========================================================================
    // 3. SHARED STATE
    // =========================================================================
    // --- bookkeeping / reporting ---
    integer cycle_count;
    integer total_error_count, protocol_error_count, data_error_count;
    integer assertion_error_count, intent_error_count;
    integer printed_error_count;
    reg     last_error_printed;
    integer tests_started, tests_passed, tests_failed;
    integer known_issue_failures, unexpected_failures, errors_in_known_issue_tests;
    reg [8*96-1:0] current_test_name;
    reg [8*96-1:0] name_buffer;
    integer current_known_issue_id, errors_at_test_start;
    reg     ki1_failed, ki2_failed;
    integer encrypted_chars_checked, echo_chars_checked, known_answer_checks;
    integer output_cycles_checked, responses_completed, last_response_result;
    integer random_seed_value, random_state, random_txn_index, random_transactions_sent;
    integer random_config_count, random_letters_per_config;
    reg     random_phase_active;
    reg     verbose_output, known_issues_nonfatal, waveform_enabled;
    reg     response_wait_timed_out;

    // --- reference model state ---
    integer rotor_forward [0:5*26-1];
    integer rotor_inverse [0:5*26-1];
    integer reflector_map [0:25];
    integer ref_notch     [0:4];
    integer ref_plug_map  [0:25];
    integer ref_rotor_slot1, ref_rotor_slot2, ref_rotor_slot3;   // slot1 = right/fast rotor
    integer ref_pos1, ref_pos2, ref_pos3;
    integer ref_cable1_a, ref_cable1_b, ref_cable2_a, ref_cable2_b;

    // --- config bytes as seen on the bus (predictor) and as driven (driver) ---
    reg [7:0] cfg_byte       [0:6];
    reg [7:0] cfg_drive_byte [0:6];
    reg [23:0] dec_word;

    // --- expected-transaction FIFO ---
    localparam integer FIFO_DEPTH = 16;
    integer q_letter        [0:FIFO_DEPTH-1];
    integer q_expected      [0:FIFO_DEPTH-1];
    integer q_request_cycle [0:FIFO_DEPTH-1];
    integer q_due_cycle     [0:FIFO_DEPTH-1];
    integer q_is_echo       [0:FIFO_DEPTH-1];
    integer q_visible       [0:FIFO_DEPTH-1];
    integer q_rotor1 [0:FIFO_DEPTH-1];
    integer q_rotor2 [0:FIFO_DEPTH-1];
    integer q_rotor3 [0:FIFO_DEPTH-1];
    integer q_pos1   [0:FIFO_DEPTH-1];
    integer q_pos2   [0:FIFO_DEPTH-1];
    integer q_pos3   [0:FIFO_DEPTH-1];
    integer q_cable1_a [0:FIFO_DEPTH-1];
    integer q_cable1_b [0:FIFO_DEPTH-1];
    integer q_cable2_a [0:FIFO_DEPTH-1];
    integer q_cable2_b [0:FIFO_DEPTH-1];
    integer q_is_random [0:FIFO_DEPTH-1];
    integer q_random_txn [0:FIFO_DEPTH-1];
    integer fifo_head, fifo_tail, fifo_count;
    integer snap_rotor1, snap_rotor2, snap_rotor3, snap_pos1, snap_pos2, snap_pos3;
    integer snap_cable1_a, snap_cable1_b, snap_cable2_a, snap_cable2_b;

    // --- protocol predictor state ---
    reg     predictor_armed;
    integer pred_cfg_edge_index;       // number of edges since reset release (R0 -> 0)
    integer pred_busy_cycles_left;
    reg     pred_request_pending;
    integer pred_request_letter, pred_request_cycle, pred_request_txn;
    reg     pred_strobe_previous, pred_was_busy, pred_config_ready;
    integer pred_pending_cipher, pred_cipher;
    integer pred_accepted_total, pred_dropped_total;
    reg     exp_valid;
    reg [4:0] exp_result;
    reg     exp_changed_this_edge;
    reg     last_published_was_encrypt;
    reg     visible_change;

    // --- monitor state ---
    reg       mon_valid, mon_event, mon_head_due, mon_mismatch, prev_valid;
    reg [4:0] mon_result, prev_result;
    reg [7:0] prev_uo_out;

    // --- known-answer vector storage (see get_known_vector) ---
    integer kv_sel1, kv_sel2, kv_sel3, kv_pos1, kv_pos2, kv_pos3;
    integer kv_p1a, kv_p1b, kv_p2a, kv_p2b, kv_len;
    reg [8*16-1:0] kv_input, kv_output;

    // =========================================================================
    // 4. SMALL UTILITIES
    // =========================================================================
    // Deterministic random number in [low, high] using a user-selectable seed.
    function automatic integer rand_range(input integer low, input integer high);
        integer span;
        begin
            span = high - low + 1;
            rand_range = low + ({$random(random_state)} % span);
        end
    endfunction

    // Printable character for a letter code (? for codes above 25)
    function automatic [7:0] letter_char(input integer code);
        begin
            if (code >= 0 && code <= 25) letter_char = 8'd65 + code;
            else                         letter_char = "?";
        end
    endfunction

    // Wait for the next falling edge, then a small settle delay.  Every driver
    // task starts and ends "just after a falling edge".
    task automatic next_cycle;
        begin
            @(negedge clk);
            #(SETTLE_DELAY_NS);
        end
    endtask

    task automatic wait_cycles(input integer count);
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) next_cycle;
        end
    endtask

    // =========================================================================
    // 5. ERROR REPORTING AND TEST BOOKKEEPING
    // =========================================================================
    task automatic report_error(input integer category, input [8*72-1:0] message);
        reg [8*10-1:0] category_label;
        begin
            total_error_count = total_error_count + 1;
            case (category)
                CAT_PROTOCOL: begin protocol_error_count  = protocol_error_count  + 1; category_label = "PROTOCOL"; end
                CAT_DATA:     begin data_error_count      = data_error_count      + 1; category_label = "DATA";     end
                CAT_ASSERT:   begin assertion_error_count = assertion_error_count + 1; category_label = "ASSERT";   end
                default:      begin intent_error_count    = intent_error_count    + 1; category_label = "INTENT";   end
            endcase
            last_error_printed = 1'b0;
            if (printed_error_count < MAX_PRINTED_ERRORS) begin
                printed_error_count = printed_error_count + 1;
                last_error_printed  = 1'b1;
                $display("  [ERROR %0s] test=\"%0s\" cycle=%0d time=%0t", category_label, current_test_name, cycle_count, $time);
                $display("        what      : %0s", message);
            end else if (printed_error_count == MAX_PRINTED_ERRORS) begin
                printed_error_count = printed_error_count + 1;
                $display("  ... further error messages suppressed (they are still counted) ...");
            end
        end
    endtask

    task automatic section_banner(input [8*72-1:0] title);
        begin
            $display("");
            $display("------------------------------------------------------------------");
            $display("  %0s", title);
            $display("------------------------------------------------------------------");
        end
    endtask

    // known_issue_id: 0 = normal test.  1 or 2 = failure is expected (see header).
    task automatic begin_test(input [8*96-1:0] test_name, input integer known_issue_id);
        begin
            tests_started          = tests_started + 1;
            current_test_name      = test_name;
            current_known_issue_id = known_issue_id;
            errors_at_test_start   = total_error_count;
            if (verbose_output) $display("[TEST %0d] %0s", tests_started, test_name);
        end
    endtask

    task automatic end_test;
        integer errors_in_test;
        begin
            wait_cycles(2);                       // let the monitor see anything still in flight
            errors_in_test = total_error_count - errors_at_test_start;
            if (errors_in_test == 0) begin
                tests_passed = tests_passed + 1;
                $display("  PASS  %0s", current_test_name);
            end else begin
                tests_failed = tests_failed + 1;
                if (current_known_issue_id != 0) begin
                    known_issue_failures        = known_issue_failures + 1;
                    errors_in_known_issue_tests = errors_in_known_issue_tests + errors_in_test;
                    if (current_known_issue_id == 1) ki1_failed = 1'b1;
                    if (current_known_issue_id == 2) ki2_failed = 1'b1;
                    $display("  FAIL  %0s   [KNOWN ISSUE KI-%0d, %0d error(s)]", current_test_name, current_known_issue_id, errors_in_test);
                end else begin
                    unexpected_failures = unexpected_failures + 1;
                    $display("  FAIL  %0s   [%0d error(s)]", current_test_name, errors_in_test);
                end
            end
        end
    endtask

    // =========================================================================
    // 6. INDEPENDENT REFERENCE MODEL (pure maths on permutation arrays)
    // =========================================================================
    // letter number (0..25) of the index-th character of a 26-character string
    function automatic integer wiring_letter(input [8*26-1:0] wiring_string, input integer index);
        reg [7:0] ch;
        begin
            ch = wiring_string[8*(25-index) +: 8];
            wiring_letter = ch - 8'd65;
        end
    endfunction

    function automatic integer ref_mod26(input integer value);
        integer r;
        begin
            r = value % 26;
            if (r < 0) r = r + 26;
            ref_mod26 = r;
        end
    endfunction

    // Build the forward/inverse permutation tables, reflector and notches.
    task automatic ref_build_tables;
        integer r, i, v;
        reg [7:0] ch;
        begin
            v = 0;
            for (r = 0; r < 5; r = r + 1) begin
                for (i = 0; i < 26; i = i + 1) begin
                    case (r)
                        0: v = wiring_letter(WIRING_ROTOR_I,   i);
                        1: v = wiring_letter(WIRING_ROTOR_II,  i);
                        2: v = wiring_letter(WIRING_ROTOR_III, i);
                        3: v = wiring_letter(WIRING_ROTOR_IV,  i);
                        default: v = wiring_letter(WIRING_ROTOR_V, i);
                    endcase
                    rotor_forward[r*26 + i] = v;
                    rotor_inverse[r*26 + v] = i;     // inverse permutation
                end
            end
            for (i = 0; i < 26; i = i + 1) reflector_map[i] = wiring_letter(WIRING_REFLECTOR_B, i);
            for (i = 0; i < 5; i = i + 1) begin
                ch = NOTCH_LETTERS[8*(4-i) +: 8];
                ref_notch[i] = ch - 8'd65;
            end
        end
    endtask

    // One pass through a rotor (forward = towards reflector).  The rotor wiring
    // is rotated by 'position': enter at (letter+position), leave at (wired-position).
    function automatic integer ref_rotor_pass(input integer rotor, input integer position,
                                              input integer letter, input integer is_forward);
        integer shifted, wired;
        begin
            shifted = ref_mod26(letter + position);
            if (is_forward != 0) wired = rotor_forward[rotor*26 + shifted];
            else              wired = rotor_inverse[rotor*26 + shifted];
            ref_rotor_pass = ref_mod26(wired - position);
        end
    endfunction

    // Rotor selection decode: 0..4 are rotors I..V.  5,6,7 are INVALID and are
    // intended to fall back to rotor I (this is what the RTL does for 6 and 7).
    function automatic integer ref_decode_rotor_select(input integer raw);
        begin
            if (raw >= 0 && raw <= 4) ref_decode_rotor_select = raw;
            else                      ref_decode_rotor_select = INVALID_SELECT_FALLBACK_ROTOR;
        end
    endfunction

    // Position decode: 26..31 are invalid and load as 0.
    function automatic integer ref_decode_position(input integer raw);
        begin
            if (raw >= 0 && raw <= 25) ref_decode_position = raw;
            else                       ref_decode_position = 0;
        end
    endfunction

    // Build the plugboard permutation.  A cable is used only if BOTH ends are
    // letters 0..25 and different.  26..31 on either end means "cable unused".
    // (Overlapping cables are not legal on a real plugboard and are not tested.)
    task automatic ref_set_plugboard(input integer a1, input integer b1, input integer a2, input integer b2);
        integer i;
        begin
            for (i = 0; i < 26; i = i + 1) ref_plug_map[i] = i;
            ref_cable1_a = a1; ref_cable1_b = b1; ref_cable2_a = a2; ref_cable2_b = b2;
            if (a1 >= 0 && a1 <= 25 && b1 >= 0 && b1 <= 25 && a1 != b1) begin
                ref_plug_map[a1] = b1;
                ref_plug_map[b1] = a1;
            end
            if (a2 >= 0 && a2 <= 25 && b2 >= 0 && b2 <= 25 && a2 != b2) begin
                ref_plug_map[a2] = b2;
                ref_plug_map[b2] = a2;
            end
        end
    endtask

    // Set the whole model configuration at once (inputs already decoded/legal).
    task automatic ref_set_config(input integer s1, input integer s2, input integer s3,
                                  input integer p1, input integer p2, input integer p3,
                                  input integer a1, input integer b1, input integer a2, input integer b2);
        begin
            ref_rotor_slot1 = s1; ref_rotor_slot2 = s2; ref_rotor_slot3 = s3;
            ref_pos1 = p1; ref_pos2 = p2; ref_pos3 = p3;
            ref_set_plugboard(a1, b1, a2, b2);
        end
    endtask

    // Decode the 7 bytes captured from the bus (layout from the RTL header):
    //   config word = {byte2, byte1, byte0}
    //   [2:0] slot1 [5:3] slot2 [8:6] slot3 [13:9] pos1 [18:14] pos2 [23:19] pos3
    //   byte3..6 [4:0] = plug cable1 A, cable1 B, cable2 A, cable2 B
    task automatic ref_apply_config_bytes;
        reg [7:0] b3, b4, b5, b6;
        begin
            dec_word = {cfg_byte[2], cfg_byte[1], cfg_byte[0]};
            b3 = cfg_byte[3]; b4 = cfg_byte[4]; b5 = cfg_byte[5]; b6 = cfg_byte[6];
            ref_set_config(ref_decode_rotor_select(dec_word[2:0]),
                           ref_decode_rotor_select(dec_word[5:3]),
                           ref_decode_rotor_select(dec_word[8:6]),
                           ref_decode_position(dec_word[13:9]),
                           ref_decode_position(dec_word[18:14]),
                           ref_decode_position(dec_word[23:19]),
                           b3[4:0], b4[4:0], b5[4:0], b6[4:0]);
        end
    endtask

    // Step the rotors for one key press using the PRE-step positions.
    //   * right rotor (slot1) always steps
    //   * middle steps if the right rotor is at its notch, OR if the middle
    //     rotor is itself at its notch (the "double step")
    //   * left rotor steps only if the middle rotor is at its notch
    task automatic ref_step_rotors;
        reg right_at_notch, middle_at_notch;
        begin
            right_at_notch  = (ref_pos1 == ref_notch[ref_rotor_slot1]);
            middle_at_notch = (ref_pos2 == ref_notch[ref_rotor_slot2]);
            if (middle_at_notch)                    ref_pos3 = ref_mod26(ref_pos3 + 1);
            if (right_at_notch || middle_at_notch)  ref_pos2 = ref_mod26(ref_pos2 + 1);
            ref_pos1 = ref_mod26(ref_pos1 + 1);
        end
    endtask

    // Full electrical path for one letter at the CURRENT rotor positions.
    function automatic integer ref_encrypt_core(input integer letter);
        integer x;
        begin
            x = ref_plug_map[letter];
            x = ref_rotor_pass(ref_rotor_slot1, ref_pos1, x, 1);
            x = ref_rotor_pass(ref_rotor_slot2, ref_pos2, x, 1);
            x = ref_rotor_pass(ref_rotor_slot3, ref_pos3, x, 1);
            x = reflector_map[x];
            x = ref_rotor_pass(ref_rotor_slot3, ref_pos3, x, 0);
            x = ref_rotor_pass(ref_rotor_slot2, ref_pos2, x, 0);
            x = ref_rotor_pass(ref_rotor_slot1, ref_pos1, x, 0);
            x = ref_plug_map[x];
            ref_encrypt_core = x;
        end
    endfunction

    // One accepted key press: step first, then encrypt (mechanical Enigma order).
    task automatic ref_process_key(input integer letter, output integer cipher);
        begin
            ref_step_rotors;
            cipher = ref_encrypt_core(letter);
        end
    endtask

    // =========================================================================
    // 7. EXPECTED-TRANSACTION FIFO (plain arrays: portable to Icarus)
    // =========================================================================
    task automatic fifo_clear;
        begin
            fifo_head = 0; fifo_tail = 0; fifo_count = 0;
        end
    endtask

    task automatic snapshot_reference_state;
        begin
            snap_rotor1 = ref_rotor_slot1; snap_rotor2 = ref_rotor_slot2; snap_rotor3 = ref_rotor_slot3;
            snap_pos1 = ref_pos1; snap_pos2 = ref_pos2; snap_pos3 = ref_pos3;
            snap_cable1_a = ref_cable1_a; snap_cable1_b = ref_cable1_b;
            snap_cable2_a = ref_cable2_a; snap_cable2_b = ref_cable2_b;
        end
    endtask

    task automatic fifo_push(input integer letter, input integer expected, input integer request_cycle,
                             input integer due_cycle, input integer is_echo, input integer visible);
        begin
            if (fifo_count == FIFO_DEPTH) begin
                report_error(CAT_INTENT, "internal testbench error: expected-transaction FIFO overflow");
            end else begin
                q_letter[fifo_tail] = letter;         q_expected[fifo_tail] = expected;
                q_request_cycle[fifo_tail] = request_cycle; q_due_cycle[fifo_tail] = due_cycle;
                q_is_echo[fifo_tail] = is_echo;       q_visible[fifo_tail] = visible;
                q_rotor1[fifo_tail] = snap_rotor1;    q_rotor2[fifo_tail] = snap_rotor2;  q_rotor3[fifo_tail] = snap_rotor3;
                q_pos1[fifo_tail] = snap_pos1;        q_pos2[fifo_tail] = snap_pos2;      q_pos3[fifo_tail] = snap_pos3;
                q_cable1_a[fifo_tail] = snap_cable1_a; q_cable1_b[fifo_tail] = snap_cable1_b;
                q_cable2_a[fifo_tail] = snap_cable2_a; q_cable2_b[fifo_tail] = snap_cable2_b;
                q_is_random[fifo_tail] = random_phase_active;
                q_random_txn[fifo_tail] = pred_request_txn;
                fifo_tail  = (fifo_tail + 1) % FIFO_DEPTH;
                fifo_count = fifo_count + 1;
            end
        end
    endtask

    task automatic fifo_pop;
        begin
            fifo_head  = (fifo_head + 1) % FIFO_DEPTH;
            fifo_count = fifo_count - 1;
        end
    endtask

    // Print everything needed to reproduce a failing transaction.
    task automatic print_entry_context(input integer slot);
        begin
            if (last_error_printed) begin
                $display("        request   : letter code %0d ('%c'), strobe sampled at cycle %0d",
                         q_letter[slot], letter_char(q_letter[slot]), q_request_cycle[slot]);
                $display("        rotors    : slot1=%0d slot2=%0d slot3=%0d  (0=I 1=II 2=III 3=IV 4=V; slot1 = right/fast)",
                         q_rotor1[slot], q_rotor2[slot], q_rotor3[slot]);
                $display("        positions : slot1=%0d slot2=%0d slot3=%0d  (before this key press)",
                         q_pos1[slot], q_pos2[slot], q_pos3[slot]);
                $display("        plugboard : cable1=(%0d,%0d) cable2=(%0d,%0d)  (26..31 = unused)",
                         q_cable1_a[slot], q_cable1_b[slot], q_cable2_a[slot], q_cable2_b[slot]);
                if (q_is_random[slot] != 0)
                    $display("        random    : seed=%0d random_test_number=%0d  (re-run with +SEED=%0d)",
                             random_seed_value, q_random_txn[slot], random_seed_value);
            end
        end
    endtask

    // =========================================================================
    // 8. PROTOCOL PREDICTOR  (watches ONLY the pins, decides accept/drop)
    //    Runs on posedge clk and reads the pins exactly as the DUT samples them.
    // =========================================================================
    always @(posedge clk) begin : protocol_predictor
        cycle_count = cycle_count + 1;
        exp_changed_this_edge = 1'b0;

        if (!rst_n) begin
            // Synchronous reset: everything the DUT clears, the predictor clears.
            predictor_armed = 1'b1;
            pred_cfg_edge_index   = 0;
            pred_busy_cycles_left = 0;
            pred_request_pending  = 1'b0;
            pred_strobe_previous  = 1'b0;
            fifo_clear;
            if (exp_valid !== 1'b0 || exp_result !== 5'd0) exp_changed_this_edge = 1'b1;
            exp_valid  = 1'b0;
            exp_result = 5'd0;
            last_published_was_encrypt = 1'b0;
        end else if (predictor_armed) begin
            // (1) in-flight encryption countdown; publish the result when it ends
            pred_was_busy = (pred_busy_cycles_left > 0);
            if (pred_was_busy) begin
                pred_busy_cycles_left = pred_busy_cycles_left - 1;
                if (pred_busy_cycles_left == 0) begin
                    exp_valid  = 1'b1;
                    exp_result = pred_pending_cipher;
                    exp_changed_this_edge = 1'b1;
                    last_published_was_encrypt = 1'b1;
                end
            end

            // (2) capture configuration bytes from the bus (R0..R6), decode at R7
            if (pred_cfg_edge_index < CONFIG_BYTE_COUNT) cfg_byte[pred_cfg_edge_index] = uio_in;
            if (pred_cfg_edge_index == CONFIG_BYTE_COUNT) ref_apply_config_bytes;
            pred_config_ready = (pred_cfg_edge_index >= CONFIG_FIRST_GO_EDGE);

            // (3) decide the fate of the request whose strobe was sampled last edge (E1)
            if (pred_request_pending) begin
                pred_request_pending = 1'b0;
                if (ena && pred_config_ready && !pred_was_busy) begin
                    pred_accepted_total = pred_accepted_total + 1;
                    snapshot_reference_state;
                    if (pred_request_letter < 26) begin
                        // valid letter: valid drops now, result appears 8 cycles after E0
                        ref_process_key(pred_request_letter, pred_cipher);
                        fifo_push(pred_request_letter, pred_cipher, pred_request_cycle,
                                  pred_request_cycle + LATENCY_ENCRYPT_CYCLES, 0, 1);
                        pred_pending_cipher   = pred_cipher;
                        pred_busy_cycles_left = LATENCY_ENCRYPT_CYCLES - 1;
                        if (exp_valid) exp_changed_this_edge = 1'b1;
                        exp_valid = 1'b0;
                    end else begin
                        // invalid letter: echoed one cycle later, no stepping
                        visible_change = !(exp_valid && (exp_result == pred_request_letter[4:0]));
                        fifo_push(pred_request_letter, pred_request_letter, pred_request_cycle,
                                  pred_request_cycle + LATENCY_ECHO_CYCLES, 1, visible_change);
                        if (visible_change) exp_changed_this_edge = 1'b1;
                        exp_valid  = 1'b1;
                        exp_result = pred_request_letter[4:0];
                        last_published_was_encrypt = 1'b0;
                    end
                end else begin
                    pred_dropped_total = pred_dropped_total + 1;
                end
            end

            // (4) rising-edge detection of the strobe (E0): remember letter + cycle
            if (ui_in[7] && !pred_strobe_previous) begin
                pred_request_pending = 1'b1;
                pred_request_letter  = ui_in[4:0];
                pred_request_cycle   = cycle_count;
                pred_request_txn     = random_txn_index;
            end
            pred_strobe_previous = ui_in[7];

            // (5) count edges since reset release
            if (pred_cfg_edge_index < 100000) pred_cfg_edge_index = pred_cfg_edge_index + 1;
        end
    end

    // =========================================================================
    // 9. OUTPUT MONITOR + SCOREBOARD + ASSERTION-STYLE CHECKS
    //    Runs on negedge clk (outputs are settled).  Checks, every cycle:
    //      A1 uo_out[6:5] == 0                A2 uio_oe == 0   A3 uio_out == 0
    //      A4 no X/Z on outputs               A5 valid never high before config done
    //      A6 encrypted results are 0..25     A7 output only changes when expected (stability)
    //    and compares valid/result with the cycle-accurate expectation, and
    //    matches every response against the expected-transaction FIFO.
    // =========================================================================
    always @(negedge clk) begin : output_monitor_and_scoreboard
        if (predictor_armed) begin
            mon_valid  = uo_out[7];
            mon_result = uo_out[4:0];
            output_cycles_checked = output_cycles_checked + 1;

            // ---- interface checks ----
            if (uo_out[6:5] !== 2'b00) report_error(CAT_ASSERT, "A1: uo_out[6:5] (reserved) is not zero");
            if (uio_oe  !== 8'h00)     report_error(CAT_ASSERT, "A2: uio_oe is not zero");
            if (uio_out !== 8'h00)     report_error(CAT_ASSERT, "A3: uio_out is not zero");
            if ((^uo_out) === 1'bx)    report_error(CAT_ASSERT, "A4: uo_out contains X or Z");
            if (mon_valid === 1'b1 && pred_cfg_edge_index <= CONFIG_FIRST_GO_EDGE)
                report_error(CAT_ASSERT, "A5: valid is high before configuration has completed");
            if (mon_valid === 1'b1 && last_published_was_encrypt && mon_result > 5'd25)
                report_error(CAT_ASSERT, "A6: encrypted result is outside 0..25");

            // ---- response event detection (valid rising, or result changing while valid) ----
            mon_event    = (mon_valid === 1'b1) && ((prev_valid !== 1'b1) || (mon_result !== prev_result));
            mon_head_due = (fifo_count > 0) && (q_due_cycle[fifo_head] == cycle_count);

            if (mon_event) begin
                if (fifo_count == 0) begin
                    report_error(CAT_PROTOCOL, "unexpected response: no accepted request is outstanding");
                    $display("        actual    : valid=%b result=%0d", mon_valid, mon_result);
                end else if (q_due_cycle[fifo_head] > cycle_count) begin
                    report_error(CAT_PROTOCOL, "response arrived EARLY");
                    print_entry_context(fifo_head);
                end
            end
            if (mon_head_due && q_visible[fifo_head] != 0 && !mon_event) begin
                report_error(CAT_PROTOCOL, "response MISSING at the expected cycle (lost or late)");
                print_entry_context(fifo_head);
            end

            // ---- cycle-accurate comparison of valid/result with the expectation ----
            mon_mismatch = (mon_valid !== exp_valid) || (mon_result !== exp_result);
            if (mon_mismatch) begin
                if (mon_head_due) begin
                    report_error(CAT_DATA, "DUT output differs from the reference model result");
                end else if (!exp_changed_this_edge && (uo_out !== prev_uo_out)) begin
                    report_error(CAT_ASSERT, "A7: output changed although no update was expected (stability)");
                end else if (exp_changed_this_edge && (uo_out === prev_uo_out)) begin
                    report_error(CAT_PROTOCOL, "an output update was expected this cycle but did not happen");
                end else begin
                    report_error(CAT_DATA, "DUT valid/result differ from expected state");
                end
                if (last_error_printed) begin
                    $display("        expected  : valid=%b result=%0d ('%c')", exp_valid, exp_result, letter_char(exp_result));
                    $display("        actual    : valid=%b result=%0d ('%c')", mon_valid, mon_result, letter_char(mon_result));
                    if (mon_head_due) print_entry_context(fifo_head);
                end
            end

            // ---- retire the transaction that was due this cycle ----
            if (mon_head_due) begin
                responses_completed  = responses_completed + 1;
                last_response_result = mon_result;
                if (q_is_echo[fifo_head] != 0) echo_chars_checked      = echo_chars_checked + 1;
                else                           encrypted_chars_checked = encrypted_chars_checked + 1;
                fifo_pop;
            end

            prev_valid  = mon_valid;
            prev_result = mon_result;
            prev_uo_out = uo_out;
        end
    end

`ifdef USE_SVA
    // Optional concurrent assertions (Questa/VCS/Xcelium).  NOT supported by Icarus.
    // They duplicate A1..A3 using the standard SVA flow so you can see both styles.
    assert_reserved_bits_zero: assert property (@(posedge clk) disable iff (!predictor_armed)
        (uo_out[6:5] == 2'b00)) else $error("SVA: uo_out[6:5] is not zero");
    assert_uio_oe_zero:        assert property (@(posedge clk) disable iff (!predictor_armed)
        (uio_oe == 8'h00))      else $error("SVA: uio_oe is not zero");
    assert_uio_out_zero:       assert property (@(posedge clk) disable iff (!predictor_armed)
        (uio_out == 8'h00))     else $error("SVA: uio_out is not zero");
`endif

    // =========================================================================
    // 10. DRIVER TASKS  (stimulus only - no checking in here)
    // =========================================================================
    // Put a strobe level and a letter on ui_in (junk bits go on ui_in[6:5]).
    task automatic drive_ui(input integer strobe_level, input integer letter_code);
        reg [4:0] letter5;
        begin
            letter5 = letter_code;
            ui_in   = {(strobe_level != 0), ui_junk_bits, letter5};
        end
    endtask

    // Assert reset for 'cycles' clock edges, then release.  On return rst_n is
    // already 1, so the NEXT rising edge is R0 (config byte 0 must be on uio_in now).
    task automatic apply_reset(input integer cycles);
        begin
            rst_n  = 1'b0;
            drive_ui(hold_strobe_during_config, 0);
            uio_in = IDLE_UIO_VALUE;
            wait_cycles(cycles);
            rst_n  = 1'b1;
        end
    endtask

    // Fill cfg_drive_byte[0..6] from human-readable fields.
    // Byte layout (matches the RTL header):
    //   byte0 = {slot3[1:0], slot2[2:0], slot1[2:0]}
    //   byte1 = {pos2[1:0],  pos1[4:0],  slot3[2]}
    //   byte2 = {pos3[4:0],  pos2[4:2]}
    //   byte3..6 = {junk[2:0], plug letter[4:0]} : cable1 A, cable1 B, cable2 A, cable2 B
    task automatic set_config_bytes_from_fields(
            input integer sel1, input integer sel2, input integer sel3,
            input integer pos1, input integer pos2, input integer pos3,
            input integer plug1_a, input integer plug1_b, input integer plug2_a, input integer plug2_b);
        reg [23:0] word;
        reg [4:0]  letter5;
        begin
            word = 24'd0;
            word[2:0]   = sel1;
            word[5:3]   = sel2;
            word[8:6]   = sel3;
            word[13:9]  = pos1;
            word[18:14] = pos2;
            word[23:19] = pos3;
            cfg_drive_byte[0] = word[7:0];
            cfg_drive_byte[1] = word[15:8];
            cfg_drive_byte[2] = word[23:16];
            letter5 = plug1_a; cfg_drive_byte[3] = {plug_byte_junk_bits, letter5};
            letter5 = plug1_b; cfg_drive_byte[4] = {plug_byte_junk_bits, letter5};
            letter5 = plug2_a; cfg_drive_byte[5] = {plug_byte_junk_bits, letter5};
            letter5 = plug2_b; cfg_drive_byte[6] = {plug_byte_junk_bits, letter5};
        end
    endtask

    // Drive the bus for 'num_edges' consecutive edges starting at R0:
    // edge i carries cfg_drive_byte[i] for i<=6, idle afterwards.  Optionally
    // pulse the strobe for exactly one cycle at edge 'strobe_edge' (-1 = never).
    // Returns just after edge number (num_edges-1) has passed.
    task automatic drive_config_edges(input integer num_edges, input integer strobe_edge, input integer strobe_letter);
        integer edge_index;
        begin
            for (edge_index = 0; edge_index < num_edges; edge_index = edge_index + 1) begin
                if (edge_index < CONFIG_BYTE_COUNT) uio_in = cfg_drive_byte[edge_index];
                else                                uio_in = IDLE_UIO_VALUE;
                drive_ui((edge_index == strobe_edge) || hold_strobe_during_config, strobe_letter);
                next_cycle;
            end
            drive_ui(hold_strobe_during_config, strobe_letter);
            uio_in = IDLE_UIO_VALUE;
        end
    endtask

    // Normal config: 8 edges (R0..R7).  On return the next edge is R8, so a
    // strobe driven NOW has E0 = R8 and is the earliest request that is accepted.
    task automatic load_configuration;
        begin
            drive_config_edges(CONFIG_BYTE_COUNT + 1, -1, 0);
        end
    endtask

    // Reset + configuration in one call (resets for 'reset_cycles' edges).
    task automatic start_machine_with_reset(input integer reset_cycles,
            input integer sel1, input integer sel2, input integer sel3,
            input integer pos1, input integer pos2, input integer pos3,
            input integer plug1_a, input integer plug1_b, input integer plug2_a, input integer plug2_b);
        begin
            ena = 1'b1;
            set_config_bytes_from_fields(sel1, sel2, sel3, pos1, pos2, pos3, plug1_a, plug1_b, plug2_a, plug2_b);
            apply_reset(reset_cycles);
            load_configuration;
        end
    endtask

    task automatic start_machine(
            input integer sel1, input integer sel2, input integer sel3,
            input integer pos1, input integer pos2, input integer pos3,
            input integer plug1_a, input integer plug1_b, input integer plug2_a, input integer plug2_b);
        begin
            start_machine_with_reset(2, sel1, sel2, sel3, pos1, pos2, pos3, plug1_a, plug1_b, plug2_a, plug2_b);
        end
    endtask

    // Same, but with no plugboard cables.
    task automatic start_machine_plain(input integer sel1, input integer sel2, input integer sel3,
                                       input integer pos1, input integer pos2, input integer pos3);
        begin
            start_machine(sel1, sel2, sel3, pos1, pos2, pos3, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
        end
    endtask

    // Present a letter with the strobe high for 'strobe_high_cycles' cycles, then
    // low, then wait 'idle_cycles_after' more cycles.
    //   spacing between two E0 edges = strobe_high_cycles + idle_cycles_after
    task automatic send_letter(input integer letter, input integer strobe_high_cycles, input integer idle_cycles_after);
        begin
            drive_ui(1, letter);
            wait_cycles(strobe_high_cycles);
            drive_ui(0, letter);
            wait_cycles(idle_cycles_after);
        end
    endtask

    // Wait until the scoreboard has retired one more expected response.
    // Sets response_wait_timed_out if nothing completed within the timeout.
    task automatic wait_for_valid(input integer timeout_cycles);
        integer start_count, waited;
        begin
            start_count = responses_completed;
            waited = 0;
            while (responses_completed == start_count && waited < timeout_cycles) begin
                next_cycle;
                waited = waited + 1;
            end
            response_wait_timed_out = (responses_completed == start_count);
        end
    endtask

    // Compare the DUT output right now with a literal expected letter.
    task automatic check_output(input integer expected_letter, input [8*48-1:0] label);
        begin
            known_answer_checks = known_answer_checks + 1;
            if (uo_out[7] !== 1'b1 || uo_out[4:0] !== expected_letter[4:0]) begin
                report_error(CAT_DATA, "literal known-answer check failed");
                if (last_error_printed) begin
                    $display("        check     : %0s", label);
                    $display("        expected  : valid=1 result=%0d ('%c')", expected_letter, letter_char(expected_letter));
                    $display("        actual    : valid=%b result=%0d ('%c')", uo_out[7], uo_out[4:0], letter_char(uo_out[4:0]));
                end
            end
        end
    endtask

    task automatic check_outputs_are_zero(input [8*48-1:0] label);
        begin
            if (uo_out !== 8'h00) begin
                report_error(CAT_DATA, "uo_out should be zero here");
                if (last_error_printed) $display("        where     : %0s   actual uo_out=%b", label, uo_out);
            end
        end
    endtask

    // Check how many requests the protocol predictor accepted since 'accepted_before'.
    task automatic check_accept_count(input integer accepted_before, input integer expected_delta, input [8*48-1:0] label);
        integer actual_delta;
        begin
            actual_delta = pred_accepted_total - accepted_before;
            if (actual_delta != expected_delta) begin
                report_error(CAT_INTENT, "number of accepted requests is not what the scenario expects");
                if (last_error_printed) $display("        where     : %0s   expected %0d accepted, model saw %0d", label, expected_delta, actual_delta);
            end
        end
    endtask

    // Send one letter (strobe 1 cycle), wait for its response.  The scoreboard
    // checks the data and timing; here we only make sure a response came.
    task automatic run_single_encryption_test(input integer letter);
        integer accepted_before;
        begin
            if (random_phase_active) begin
                random_txn_index = random_txn_index + 1;
            end
            accepted_before = pred_accepted_total;
            send_letter(letter, 1, 0);
            wait_for_valid(RESPONSE_TIMEOUT_CYCLES);
            check_accept_count(accepted_before, 1, "single encryption request accepted");
        end
    endtask

    // 'count' letters following a fixed, non-trivial pattern.
    task automatic encrypt_message(input integer count);
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) run_single_encryption_test((i * 7 + 3) % 26);
        end
    endtask

    // All 26 letters once, in order A..Z.
    task automatic encrypt_alphabet;
        integer i;
        begin
            for (i = 0; i < 26; i = i + 1) run_single_encryption_test(i);
        end
    endtask

    // ---- known-answer vectors, computed OUTSIDE this testbench from rotor_luts.vh ----
    task automatic get_known_vector(input integer id);
        begin
            kv_p1a = NO_CABLE; kv_p1b = NO_CABLE; kv_p2a = NO_CABLE; kv_p2b = NO_CABLE;
            case (id)
                1: begin // published Enigma test: rotors I-II-III (III on the right), AAA, AAAAA -> BDZGO
                    kv_sel1=2; kv_sel2=1; kv_sel3=0; kv_pos1=0; kv_pos2=0; kv_pos3=0;
                    kv_len=5; kv_input="AAAAA"; kv_output="BDZGO";
                end
                2: begin // textbook double step: window A D U, then ADV, AEW, BFX, BFY
                    kv_sel1=2; kv_sel2=1; kv_sel3=0; kv_pos1=20; kv_pos2=3; kv_pos3=0;
                    kv_len=6; kv_input="AAAAAA"; kv_output="EQIBMG";
                end
                3: begin // asymmetric rotors/positions + 2 plug cables (checks every config field)
                    kv_sel1=3; kv_sel2=1; kv_sel3=4; kv_pos1=22; kv_pos2=13; kv_pos3=25;
                    kv_p1a=4; kv_p1b=17; kv_p2a=9; kv_p2b=22;
                    kv_len=10; kv_input="HELLOWORLD"; kv_output="WWBUFZGWZJ";
                end
                4: begin // all positions at 25 with rotor V on the right (rollover + notch Z)
                    kv_sel1=4; kv_sel2=3; kv_sel3=0; kv_pos1=25; kv_pos2=25; kv_pos3=25;
                    kv_len=6; kv_input="AAAAAA"; kv_output="NKXNUP";
                end
                default: begin // right rotor I stepping through its notch Q
                    kv_sel1=0; kv_sel2=1; kv_sel3=2; kv_pos1=15; kv_pos2=0; kv_pos3=0;
                    kv_len=6; kv_input="AAAAAA"; kv_output="JJCOQT";
                end
            endcase
        end
    endtask

    task automatic run_known_vector_on_dut(input integer id);
        integer i, in_letter, expected_letter;
        reg [7:0] ch_in, ch_out;
        begin
            get_known_vector(id);
            start_machine(kv_sel1, kv_sel2, kv_sel3, kv_pos1, kv_pos2, kv_pos3, kv_p1a, kv_p1b, kv_p2a, kv_p2b);
            for (i = 0; i < kv_len; i = i + 1) begin
                ch_in  = kv_input [8*(kv_len-1-i) +: 8];
                ch_out = kv_output[8*(kv_len-1-i) +: 8];
                in_letter       = ch_in  - 8'd65;
                expected_letter = ch_out - 8'd65;
                run_single_encryption_test(in_letter);
                check_output(expected_letter, "known-answer vector");
            end
        end
    endtask

    // =========================================================================
    // 11. DIRECTED TESTS
    // =========================================================================

    // ---------------- T1: the reference model checks itself (no DUT) ----------------
    task automatic run_model_self_tests;
        integer r, i, v, x, y, cipher, errors;
        reg [25:0] seen;
        begin
            section_banner("T1  Reference-model self-tests (no DUT involved)");

            begin_test("T1.1 Notch letters are Q E V J Z", 0);
            if (ref_notch[0] != 16 || ref_notch[1] != 4 || ref_notch[2] != 21 ||
                ref_notch[3] != 9  || ref_notch[4] != 25)
                report_error(CAT_INTENT, "notch table is not Q,E,V,J,Z");
            end_test;

            begin_test("T1.2 Every rotor is a permutation and inverse(forward(x)) = x", 0);
            for (r = 0; r < 5; r = r + 1) begin
                seen = 26'd0;
                for (i = 0; i < 26; i = i + 1) begin
                    v = rotor_forward[r*26 + i];
                    seen[v] = 1'b1;
                    if (rotor_inverse[r*26 + v] != i) report_error(CAT_INTENT, "rotor inverse table is wrong");
                end
                if (seen != 26'h3FFFFFF) report_error(CAT_INTENT, "rotor wiring is not a permutation");
            end
            end_test;

            begin_test("T1.3 Reflector is an involution with no fixed points", 0);
            for (i = 0; i < 26; i = i + 1) begin
                if (reflector_map[reflector_map[i]] != i) report_error(CAT_INTENT, "reflector is not an involution");
                if (reflector_map[i] == i)                report_error(CAT_INTENT, "reflector maps a letter to itself");
            end
            end_test;

            begin_test("T1.4 Plugboard involution P(P(x)) = x and cable behaviour", 0);
            ref_set_plugboard(4, 17, 0, 25);
            for (i = 0; i < 26; i = i + 1)
                if (ref_plug_map[ref_plug_map[i]] != i) report_error(CAT_INTENT, "plugboard is not an involution");
            if (ref_plug_map[4] != 17 || ref_plug_map[17] != 4 || ref_plug_map[0] != 25 ||
                ref_plug_map[25] != 0  || ref_plug_map[10] != 10)
                report_error(CAT_INTENT, "plugboard cable mapping is wrong");
            ref_set_plugboard(NO_CABLE, 5, 7, 30);     // unused endpoints: cable must be ignored
            for (i = 0; i < 26; i = i + 1)
                if (ref_plug_map[i] != i) report_error(CAT_INTENT, "unused cable was applied by the model");
            end_test;

            begin_test("T1.5 Model reproduces published vector AAAAA -> BDZGO", 0);
            get_known_vector(1);
            ref_set_config(kv_sel1, kv_sel2, kv_sel3, kv_pos1, kv_pos2, kv_pos3, kv_p1a, kv_p1b, kv_p2a, kv_p2b);
            for (i = 0; i < kv_len; i = i + 1) begin
                ref_process_key(0, cipher);
                if (cipher != (kv_output[8*(kv_len-1-i) +: 8] - 8'd65)) report_error(CAT_INTENT, "model disagrees with published vector");
            end
            end_test;

            begin_test("T1.6 Model double-steps ADU -> ADV -> AEW -> BFX -> BFY", 0);
            ref_set_config(2, 1, 0, 20, 3, 0, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
            ref_step_rotors;  if (ref_pos3 != 0 || ref_pos2 != 3 || ref_pos1 != 21) report_error(CAT_INTENT, "expected ADV");
            ref_step_rotors;  if (ref_pos3 != 0 || ref_pos2 != 4 || ref_pos1 != 22) report_error(CAT_INTENT, "expected AEW");
            ref_step_rotors;  if (ref_pos3 != 1 || ref_pos2 != 5 || ref_pos1 != 23) report_error(CAT_INTENT, "expected BFX");
            ref_step_rotors;  if (ref_pos3 != 1 || ref_pos2 != 5 || ref_pos1 != 24) report_error(CAT_INTENT, "expected BFY");
            end_test;

            begin_test("T1.7 Model matches vectors V2..V5 computed independently in Python", 0);
            for (v = 2; v <= 5; v = v + 1) begin
                get_known_vector(v);
                ref_set_config(kv_sel1, kv_sel2, kv_sel3, kv_pos1, kv_pos2, kv_pos3, kv_p1a, kv_p1b, kv_p2a, kv_p2b);
                for (i = 0; i < kv_len; i = i + 1) begin
                    x = kv_input[8*(kv_len-1-i) +: 8] - 8'd65;
                    ref_process_key(x, cipher);
                    if (cipher != (kv_output[8*(kv_len-1-i) +: 8] - 8'd65)) report_error(CAT_INTENT, "model disagrees with a Python vector");
                end
            end
            end_test;

            begin_test("T1.8 Model is self-reciprocal (encrypt twice from same state = identity)", 0);
            for (x = 0; x < 26; x = x + 1) begin
                ref_set_config(1, 3, 4, 7, 21, 24, 4, 17, 9, 22);
                ref_process_key(x, y);
                ref_set_config(1, 3, 4, 7, 21, 24, 4, 17, 9, 22);
                ref_process_key(y, cipher);
                if (cipher != x) report_error(CAT_INTENT, "model is not reciprocal");
                if (y == x)      report_error(CAT_INTENT, "model encrypted a letter to itself");
            end
            end_test;
        end
    endtask

    // ---------------- T2: reset ----------------
    task automatic reset_length_test(input integer reset_cycles);
        begin
            $sformat(name_buffer, "T2.2 Reset held %0d cycle(s), then normal operation", reset_cycles);
            begin_test(name_buffer, 0);
            start_machine_plain(2, 1, 0, 5, 6, 7);
            run_single_encryption_test(4);                  // valid is now 1
            set_config_bytes_from_fields(0, 3, 4, 9, 2, 20, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
            apply_reset(reset_cycles);
            check_outputs_are_zero("immediately after reset");
            load_configuration;
            encrypt_message(4);
            end_test;
        end
    endtask

    task automatic reset_during_config_test(input integer edges_before_reset);
        begin
            $sformat(name_buffer, "T2.3 Reset after %0d config edge(s) restarts configuration", edges_before_reset);
            begin_test(name_buffer, 0);
            ena = 1'b1;
            set_config_bytes_from_fields(1, 2, 3, 11, 12, 13, 4, 17, 9, 22);   // configuration A (abandoned)
            apply_reset(2);
            drive_config_edges(edges_before_reset, -1, 0);
            set_config_bytes_from_fields(4, 0, 1, 20, 1, 6, 0, 25, NO_CABLE, NO_CABLE); // configuration B
            apply_reset(2);
            load_configuration;
            encrypt_message(5);                              // must follow configuration B only
            end_test;
        end
    endtask

    task automatic reset_during_encryption_test(input integer cycles_after_strobe);
        begin
            $sformat(name_buffer, "T2.4 Reset %0d cycle(s) after strobe aborts the encryption", cycles_after_strobe);
            begin_test(name_buffer, 0);
            start_machine_plain(2, 1, 0, 3, 4, 5);
            send_letter(9, 1, cycles_after_strobe);
            set_config_bytes_from_fields(0, 1, 2, 1, 2, 3, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
            apply_reset(2);
            check_outputs_are_zero("after reset during encryption");
            load_configuration;
            wait_cycles(10);                                 // a stray response would be caught by the monitor
            check_outputs_are_zero("10 cycles after config");
            encrypt_message(3);
            end_test;
        end
    endtask

    task automatic run_reset_tests;
        integer k;
        begin
            section_banner("T2  Reset behaviour");

            begin_test("T2.1 Outputs are zero after the power-up reset", 0);
            wait_cycles(3);
            check_outputs_are_zero("power-up reset");
            end_test;

            reset_length_test(1);
            reset_length_test(2);
            reset_length_test(3);
            reset_length_test(10);

            for (k = 1; k <= 8; k = k + 1) reset_during_config_test(k);
            for (k = 0; k <= 9; k = k + 1) reset_during_encryption_test(k);

            begin_test("T2.5 Strobe held high through reset and config is not a request", 0);
            ena = 1'b1;
            set_config_bytes_from_fields(2, 1, 0, 3, 3, 3, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
            hold_strobe_during_config = 1'b1;                // strobe high during reset, release and config
            apply_reset(3);
            drive_ui(1, 5);
            load_configuration;
            wait_cycles(12);
            hold_strobe_during_config = 1'b0;
            drive_ui(0, 5);
            wait_cycles(2);
            encrypt_message(4);                              // a fresh strobe works normally
            end_test;
        end
    endtask

    // ---------------- T3: configuration ----------------
    task automatic config_timing_test(input integer strobe_edge);
        integer accepted_before, expected_accept;
        begin
            $sformat(name_buffer, "T3.3 Strobe sampled at config edge R%0d", strobe_edge);
            begin_test(name_buffer, 0);
            ena = 1'b1;
            set_config_bytes_from_fields(2, 1, 0, 4, 8, 12, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
            apply_reset(2);
            accepted_before = pred_accepted_total;
            drive_config_edges(CONFIG_FIRST_STROBE_EDGE + 1, strobe_edge, 3);
            wait_cycles(14);
            expected_accept = (strobe_edge >= CONFIG_FIRST_STROBE_EDGE) ? 1 : 0;
            check_accept_count(accepted_before, expected_accept, "config-ready boundary");
            encrypt_message(3);                              // dropped early requests must not step rotors
            end_test;
        end
    endtask

    task automatic config_isolation_test(input integer field_id, input integer bit_index);
        integer value, s1, s2, s3, p1, p2, p3;
        begin
            value = 1 << bit_index;
            s1 = 2; s2 = 1; s3 = 0; p1 = 0; p2 = 0; p3 = 0;
            case (field_id)
                1: begin s1 = value; s2 = 3; s3 = 0; end
                2: begin s1 = 0; s2 = value; s3 = 3; end
                3: begin s1 = 0; s2 = 3; s3 = value; end
                4: p1 = value;
                5: p2 = value;
                default: p3 = value;
            endcase
            $sformat(name_buffer, "T3.1 Config field %0d, one-hot value %0d", field_id, value);
            begin_test(name_buffer, 0);
            start_machine_plain(s1, s2, s3, p1, p2, p3);
            encrypt_message(5);
            end_test;
        end
    endtask

    task automatic position_clamp_test(input integer slot);
        integer code, p1, p2, p3;
        begin
            $sformat(name_buffer, "T3.6 Invalid start position (26..31) in slot %0d loads as 0", slot);
            begin_test(name_buffer, 0);
            for (code = 26; code <= 31; code = code + 1) begin
                p1 = 4; p2 = 5; p3 = 6;
                if (slot == 1) p1 = code;
                if (slot == 2) p2 = code;
                if (slot == 3) p3 = code;
                start_machine_plain(2, 1, 0, p1, p2, p3);
                encrypt_message(4);
            end
            end_test;
        end
    endtask

    // Invalid rotor select (5,6,7) must behave like rotor I.  KI-2 covers select 5.
    task automatic invalid_select_test(input integer slot, input integer select_value);
        integer s1, s2, s3;
        begin
            s1 = 1; s2 = 2; s3 = 4;
            if (slot == 1) s1 = select_value;
            if (slot == 2) s2 = select_value;
            if (slot == 3) s3 = select_value;
            $sformat(name_buffer, "T3.7 Invalid rotor select %0d in slot %0d acts as rotor I", select_value, slot);
            begin_test(name_buffer, (select_value == 5) ? 2 : 0);
            start_machine_plain(s1, s2, s3, 12, 14, 13);
            encrypt_alphabet;                                 // passes the rotor I notch (Q) during the run
            end_test;
        end
    endtask

    // Unused plug endpoint: 'which_end' 1=cable1.A 2=cable1.B 3=cable2.A 4=cable2.B.  KI-1.
    task automatic unused_endpoint_test(input integer which_end);
        integer code, a1, b1, a2, b2;
        begin
            $sformat(name_buffer, "T3.8 Unused plug endpoint (code 26..31), end #%0d", which_end);
            begin_test(name_buffer, 1);
            for (code = 26; code <= 31; code = code + 1) begin
                a1 = NO_CABLE; b1 = NO_CABLE; a2 = NO_CABLE; b2 = NO_CABLE;
                case (which_end)
                    1: begin a1 = code; b1 = 1;    end
                    2: begin a1 = 1;    b1 = code; end
                    3: begin a2 = code; b2 = 5;    end
                    default: begin a2 = 5; b2 = code; end
                endcase
                start_machine(2, 1, 0, 3, 7, 11, a1, b1, a2, b2);
                encrypt_alphabet;                             // letters A,B,F show any unintended swap
            end
            end_test;
        end
    endtask

    task automatic run_configuration_tests;
        integer f, b, k, c1, c2;
        begin
            section_banner("T3  Configuration loading");

            for (f = 1; f <= 6; f = f + 1) begin
                for (b = 0; b < ((f <= 3) ? 3 : 5); b = b + 1) config_isolation_test(f, b);
            end

            begin_test("T3.2 Asymmetric config + plugboard, known-answer vector V3", 0);
            run_known_vector_on_dut(3);
            end_test;

            for (k = 0; k <= 8; k = k + 1) config_timing_test(k);

            begin_test("T3.4 Config bytes on uio_in after load do not change the config", 0);
            start_machine(2, 1, 0, 5, 9, 13, 4, 17, 9, 22);
            encrypt_message(3);
            set_config_bytes_from_fields(0, 3, 4, 20, 1, 2, 0, 25, 1, 24);   // a different config on the bus
            drive_config_edges(8, -1, 0);
            encrypt_message(4);
            drive_config_edges(8, -1, 0);
            encrypt_message(4);
            end_test;

            begin_test("T3.5 Reset restarts config loading; second config takes effect", 0);
            start_machine(2, 1, 0, 5, 9, 13, 4, 17, NO_CABLE, NO_CABLE);
            encrypt_message(3);
            start_machine(3, 4, 1, 1, 2, 3, 0, 25, 6, 7);
            encrypt_message(5);
            end_test;

            position_clamp_test(1);
            position_clamp_test(2);
            position_clamp_test(3);

            for (k = 1; k <= 3; k = k + 1) begin
                invalid_select_test(k, 5);       // KI-2 expected to fail today
                invalid_select_test(k, 6);
                invalid_select_test(k, 7);
            end

            for (k = 1; k <= 4; k = k + 1) unused_endpoint_test(k);   // KI-1 expected to fail today

            begin_test("T3.9 Both ends of a cable unused (26..31) means no cable", 0);
            for (c1 = 26; c1 <= 31; c1 = c1 + 5) begin
                for (c2 = 26; c2 <= 31; c2 = c2 + 5) begin
                    start_machine(2, 1, 0, 3, 7, 11, c1, c2, c2, c1);
                    encrypt_alphabet;
                end
            end
            end_test;
        end
    endtask

    // ---------------- T4: rotors, reflector, order ----------------
    task automatic rotor_exhaustive_test(input integer slot, input integer rotor);
        integer pos, letter, other_a, other_b;
        begin
            other_a = (rotor + 1) % 5;
            other_b = (rotor + 2) % 5;
            $sformat(name_buffer, "T4.1 Rotor %0d in slot %0d: all start positions x all letters", rotor, slot);
            begin_test(name_buffer, 0);
            // With the other rotors fixed, the 26 letters reach this rotor as 26 DIFFERENT
            // inputs (the earlier stages are a permutation), so every forward and inverse
            // table entry of this rotor is used at every start position.
            for (pos = 0; pos < 26; pos = pos + EXHAUSTIVE_POSITION_STEP) begin
                for (letter = 0; letter < 26; letter = letter + 1) begin
                    case (slot)
                        1: start_machine_with_reset(1, rotor, other_a, other_b, pos, 0, 0, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
                        2: start_machine_with_reset(1, other_a, rotor, other_b, 0, pos, 0, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
                        default: start_machine_with_reset(1, other_a, other_b, rotor, 0, 0, pos, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
                    endcase
                    run_single_encryption_test(letter);
                end
            end
            end_test;
        end
    endtask

    // Property test that does not use the reference model at all:
    //  encrypt(encrypt(x)) = x from the same start state, and encrypt(x) != x.
    task automatic reciprocity_test(input integer config_id);
        integer x, y, z, s1, s2, s3, p1, p2, p3, a1, b1, a2, b2;
        begin
            case (config_id)
                0: begin s1=2; s2=1; s3=0; p1=5;  p2=9;  p3=13; a1=NO_CABLE; b1=NO_CABLE; a2=NO_CABLE; b2=NO_CABLE; end
                1: begin s1=4; s2=0; s3=3; p1=25; p2=25; p3=25; a1=NO_CABLE; b1=NO_CABLE; a2=NO_CABLE; b2=NO_CABLE; end
                default: begin s1=1; s2=3; s3=4; p1=7; p2=0; p3=24; a1=4; b1=17; a2=9; b2=22; end
            endcase
            $sformat(name_buffer, "T4.2 Reciprocity and no-self-encryption, config %0d", config_id);
            begin_test(name_buffer, 0);
            for (x = 0; x < 26; x = x + 1) begin
                start_machine(s1, s2, s3, p1, p2, p3, a1, b1, a2, b2);
                run_single_encryption_test(x);
                y = last_response_result;
                start_machine(s1, s2, s3, p1, p2, p3, a1, b1, a2, b2);
                run_single_encryption_test(y);
                z = last_response_result;
                if (y == x) begin
                    report_error(CAT_DATA, "a letter was encrypted to itself");
                    if (last_error_printed) $display("        letter    : %0d", x);
                end
                if (z != x) begin
                    report_error(CAT_DATA, "encrypting the ciphertext did not give back the plaintext");
                    if (last_error_printed) $display("        letter    : %0d -> %0d -> %0d", x, y, z);
                end
            end
            end_test;
        end
    endtask

    task automatic rotor_order_test(input integer slot1_rotor);
        integer s2, s3;
        begin
            $sformat(name_buffer, "T4.3 All rotor orders with rotor %0d in slot 1", slot1_rotor);
            begin_test(name_buffer, 0);
            for (s2 = 0; s2 < 5; s2 = s2 + 1) begin
                for (s3 = 0; s3 < 5; s3 = s3 + 1) begin
                    if (s2 != slot1_rotor && s3 != slot1_rotor && s3 != s2) begin
                        start_machine_plain(slot1_rotor, s2, s3, 7, 3, 20);
                        encrypt_message(8);
                    end
                end
            end
            end_test;
        end
    endtask

    task automatic run_rotor_tests;
        integer s, r, k;
        begin
            section_banner("T4  Rotors, reflector and rotor order");
            for (s = 1; s <= 3; s = s + 1)
                for (r = 0; r < 5; r = r + 1) rotor_exhaustive_test(s, r);
            for (k = 0; k < 3; k = k + 1) reciprocity_test(k);
            for (k = 0; k < 5; k = k + 1) rotor_order_test(k);
        end
    endtask

    // ---------------- T5: stepping ----------------
    task automatic run_stepping_tests;
        integer r, v, s1, s2, s3, i;
        begin
            section_banner("T5  Rotor stepping");

            for (v = 1; v <= 5; v = v + 1) begin
                $sformat(name_buffer, "T5.0 Known-answer vector V%0d", v);
                begin_test(name_buffer, 0);
                run_known_vector_on_dut(v);
                end_test;
            end

            for (r = 0; r < 5; r = r + 1) begin
                s1 = r; s2 = (r + 1) % 5; s3 = (r + 2) % 5;
                $sformat(name_buffer, "T5.1 Right rotor %0d at its notch carries the middle rotor", r);
                begin_test(name_buffer, 0);
                start_machine_plain(s1, s2, s3, (ref_notch[s1] + 25) % 26, 2, 3);
                encrypt_message(6);
                end_test;
            end

            for (r = 0; r < 5; r = r + 1) begin
                s2 = r; s1 = (r + 1) % 5; s3 = (r + 2) % 5;
                $sformat(name_buffer, "T5.2 Middle rotor %0d notch: carry, double step, left rotor", r);
                begin_test(name_buffer, 0);
                start_machine_plain(s1, s2, s3, (ref_notch[s1] + 25) % 26, (ref_notch[s2] + 25) % 26, 0);
                encrypt_message(8);
                end_test;
            end

            for (r = 0; r < 5; r = r + 1) begin
                s1 = r; s2 = (r + 2) % 5; s3 = (r + 4) % 5;
                $sformat(name_buffer, "T5.3 Simultaneous step: right and middle both at notch (rotor %0d)", r);
                begin_test(name_buffer, 0);
                start_machine_plain(s1, s2, s3, ref_notch[s1], ref_notch[s2], 5);
                encrypt_message(5);
                end_test;
            end

            begin_test("T5.4 Rollover 25 -> 0 of the right rotor position", 0);
            start_machine_plain(0, 1, 2, 25, 0, 0);
            encrypt_message(4);
            end_test;

            begin_test("T5.5 Rollover of middle and left rotor (rotor V in middle at 25)", 0);
            start_machine_plain(0, 4, 2, 0, 25, 25);
            encrypt_message(5);
            end_test;

            begin_test("T5.6 Rollover of the left rotor (stepped by the middle notch)", 0);
            start_machine_plain(0, 1, 2, 0, 4, 25);
            encrypt_message(5);
            end_test;

            begin_test("T5.7 Left rotor sitting at its own notch has no effect", 0);
            start_machine_plain(0, 1, 2, 0, 0, 21);
            encrypt_message(6);
            end_test;

            begin_test("T5.8 Invalid letters (26..31) do not step the rotors", 0);
            start_machine_plain(2, 1, 0, 21, 3, 5);
            run_single_encryption_test(0);
            for (i = 26; i <= 31; i = i + 1) run_single_encryption_test(i);
            run_single_encryption_test(0);
            run_single_encryption_test(0);
            end_test;

            begin_test("T5.9 Long message crossing several notches", 0);
            start_machine_plain(2, 1, 0, 0, 0, 0);
            encrypt_message(60);
            end_test;
        end
    endtask

    // ---------------- T6: plugboard ----------------
    task automatic plugboard_scenario(input [8*48-1:0] scenario_name, input integer a1, input integer b1,
                                      input integer a2, input integer b2);
        begin
            $sformat(name_buffer, "T6 Plugboard: %0s", scenario_name);
            begin_test(name_buffer, 0);
            start_machine(2, 1, 0, 3, 7, 11, a1, b1, a2, b2);
            encrypt_alphabet;       // every letter enters the plugboard (matching and non-matching)
            encrypt_alphabet;       // second pass at different rotor positions
            end_test;
        end
    endtask

    task automatic run_plugboard_tests;
        begin
            section_banner("T6  Plugboard");
            plugboard_scenario("no cables", NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);
            plugboard_scenario("only cable 1 (E-R)", 4, 17, NO_CABLE, NO_CABLE);
            plugboard_scenario("only cable 2 (J-W)", NO_CABLE, NO_CABLE, 9, 22);
            plugboard_scenario("both cables (A-Z and M-N)", 0, 25, 12, 13);
            plugboard_scenario("endpoints written in reverse order", 17, 4, 22, 9);

            plug_byte_junk_bits = 3'b111;
            plugboard_scenario("junk on uio_in[7:5] of plug bytes is ignored", 4, 17, 9, 22);
            plug_byte_junk_bits = 3'b000;
        end
    endtask

    // ---------------- T7: input/output protocol ----------------
    task automatic strobe_width_test(input integer width);
        integer accepted_before;
        begin
            $sformat(name_buffer, "T7.3 Strobe held %0d cycle(s) gives exactly one encryption", width);
            begin_test(name_buffer, 0);
            start_machine_plain(2, 1, 0, 4, 5, 6);
            accepted_before = pred_accepted_total;
            send_letter(11, width, 0);
            wait_cycles(RESPONSE_TIMEOUT_CYCLES);
            check_accept_count(accepted_before, 1, "held strobe is one request");
            encrypt_message(3);
            end_test;
        end
    endtask

    task automatic pulse_pair_test(input integer spacing);
        integer accepted_before, expected_second;
        begin
            $sformat(name_buffer, "T7.4 Two strobes %0d cycles apart", spacing);
            begin_test(name_buffer, 0);
            start_machine_plain(2, 1, 0, 4, 5, 6);
            accepted_before = pred_accepted_total;
            send_letter(3, 1, spacing - 1);
            send_letter(11, 1, 0);
            wait_cycles(RESPONSE_TIMEOUT_CYCLES);
            expected_second = (spacing >= MIN_ACCEPTED_SPACING) ? 1 : 0;
            check_accept_count(accepted_before, 1 + expected_second, "second strobe inside/outside busy window");
            encrypt_message(3);
            end_test;
        end
    endtask

    task automatic measure_latency_test(input integer letter, input integer expected_latency);
        integer steps;
        begin
            $sformat(name_buffer, "T7.12 Latency of letter %0d is %0d cycle(s) after the strobe edge", letter, expected_latency);
            begin_test(name_buffer, 0);
            start_machine_plain(2, 1, 0, 0, 0, 0);          // valid=0 after reset
            drive_ui(1, letter);
            next_cycle;                                     // E0 has just happened
            steps = 1;
            drive_ui(0, letter);
            while (uo_out[7] !== 1'b1 && steps < 40) begin
                next_cycle;
                steps = steps + 1;
            end
            if ((steps - 1) != expected_latency) begin
                report_error(CAT_PROTOCOL, "latency from strobe-sampling edge to valid is wrong");
                if (last_error_printed) $display("        measured  : %0d cycle(s), expected %0d", steps - 1, expected_latency);
            end
            end_test;
        end
    endtask

    task automatic run_protocol_tests;
        integer k, accepted_before, w, i;
        begin
            section_banner("T7  Input / output protocol");

            begin_test("T7.1 Every valid letter 0..25 (latency checked by the scoreboard)", 0);
            start_machine_plain(2, 1, 0, 3, 3, 3);
            encrypt_alphabet;
            end_test;

            begin_test("T7.2 Invalid letters 26..31 are echoed, with junk on ui_in[6:5]", 0);
            start_machine_plain(2, 1, 0, 3, 3, 3);
            ui_junk_bits = 2'b11;
            for (k = 26; k <= 31; k = k + 1) run_single_encryption_test(k);
            ui_junk_bits = 2'b00;
            end_test;

            strobe_width_test(1);
            strobe_width_test(2);
            strobe_width_test(3);
            strobe_width_test(8);
            strobe_width_test(20);
            strobe_width_test(40);

            for (k = 2; k <= 12; k = k + 1) pulse_pair_test(k);

            begin_test("T7.5 Back-to-back invalid letters every 2 cycles are all accepted", 0);
            start_machine_plain(2, 1, 0, 3, 3, 3);
            accepted_before = pred_accepted_total;
            for (k = 26; k <= 31; k = k + 1) send_letter(k, 1, 1);
            wait_cycles(4);
            check_accept_count(accepted_before, 6, "six echoes");
            end_test;

            begin_test("T7.6 Letter changes without a strobe are ignored", 0);
            start_machine_plain(2, 1, 0, 3, 3, 3);
            accepted_before = pred_accepted_total;
            for (k = 0; k < 60; k = k + 1) begin
                drive_ui(0, rand_range(0, 31));
                next_cycle;
            end
            check_accept_count(accepted_before, 0, "no strobe, no request");
            encrypt_message(4);
            end_test;

            begin_test("T7.7 Letter changing after the strobe edge does not matter", 0);
            start_machine_plain(2, 1, 0, 3, 3, 3);
            accepted_before = pred_accepted_total;
            send_letter(7, 1, 0);
            for (k = 0; k < 12; k = k + 1) begin
                drive_ui(0, (k * 5 + 1) % 32);
                next_cycle;
            end
            wait_cycles(RESPONSE_TIMEOUT_CYCLES);
            check_accept_count(accepted_before, 1, "one request");
            encrypt_message(3);
            end_test;

            begin_test("T7.8 Enable low for the whole request: ignored, rotors do not step", 0);
            start_machine_plain(2, 1, 0, 21, 3, 5);
            accepted_before = pred_accepted_total;
            ena = 1'b0;
            send_letter(0, 1, 6);
            ena = 1'b1;
            wait_cycles(4);
            check_accept_count(accepted_before, 0, "enable low");
            encrypt_message(4);
            end_test;

            begin_test("T7.9 CORNER: enable low only when strobe first sampled (E0) - RTL checks ena at E1", 0);
            start_machine_plain(2, 1, 0, 3, 5, 6);
            accepted_before = pred_accepted_total;
            ena = 1'b0;
            drive_ui(1, 8);
            next_cycle;                  // E0 passes with ena=0
            ena = 1'b1;                  // E1 sees ena=1
            drive_ui(0, 8);
            wait_cycles(RESPONSE_TIMEOUT_CYCLES);
            check_accept_count(accepted_before, 1, "ena low at E0 only");
            end_test;

            begin_test("T7.10 CORNER: enable low only at the decision edge (E1) - request dropped", 0);
            start_machine_plain(2, 1, 0, 3, 5, 6);
            accepted_before = pred_accepted_total;
            drive_ui(1, 8);
            next_cycle;                  // E0 with ena=1
            ena = 1'b0;                  // E1 sees ena=0
            drive_ui(0, 8);
            next_cycle;
            ena = 1'b1;
            wait_cycles(RESPONSE_TIMEOUT_CYCLES);
            check_accept_count(accepted_before, 0, "ena low at E1 only");
            encrypt_message(3);
            end_test;

            begin_test("T7.11 CORNER: enable low during an encryption does not stall it", 0);
            start_machine_plain(2, 1, 0, 3, 5, 6);
            send_letter(8, 1, 1);
            ena = 1'b0;
            wait_cycles(4);
            ena = 1'b1;
            wait_for_valid(RESPONSE_TIMEOUT_CYCLES);
            encrypt_message(3);
            end_test;

            begin_test("T7.13 CORNER: enable low during config loading does not stop config", 0);
            set_config_bytes_from_fields(2, 1, 0, 3, 5, 6, 4, 17, NO_CABLE, NO_CABLE);
            apply_reset(2);
            ena = 1'b0;
            load_configuration;
            ena = 1'b1;
            encrypt_message(5);
            end_test;

            begin_test("T7.14 Reserved ui_in[6:5] and plug junk bits never affect results", 0);
            ui_junk_bits = 2'b10;
            start_machine(2, 1, 0, 3, 5, 6, 4, 17, 9, 22);
            encrypt_message(10);
            ui_junk_bits = 2'b00;
            end_test;

            measure_latency_test(5, LATENCY_ENCRYPT_CYCLES);
            measure_latency_test(30, LATENCY_ECHO_CYCLES);
        end
    endtask

    // =========================================================================
    // 12. RANDOMISED TESTS  (seeded, reproducible; scoreboard does all checking)
    // =========================================================================
    task automatic run_random_tests(input integer num_configs, input integer letters_per_config);
        integer c, k, r1, r2, r3, p1, p2, p3, cables, la, lb, lc, ld;
        integer letter, width, idle, reset_len;
        reg     block_enable;
        begin
            section_banner("T9  Randomised tests");
            $display("  random seed = %0d, %0d configurations x %0d letters (change with +SEED=n)",
                     random_seed_value, num_configs, letters_per_config);
            random_state = random_seed_value;
            random_phase_active = 1'b1;

            for (c = 0; c < num_configs; c = c + 1) begin
                $sformat(name_buffer, "T9.%0d Random configuration", c);
                begin_test(name_buffer, 0);

                // Legal Enigma setup: three DIFFERENT rotors, positions 0..25, 0..2 cables on distinct letters.
                r1 = rand_range(0, 4);
                r2 = r1; while (r2 == r1) r2 = rand_range(0, 4);
                r3 = r1; while (r3 == r1 || r3 == r2) r3 = rand_range(0, 4);
                p1 = rand_range(0, 25); p2 = rand_range(0, 25); p3 = rand_range(0, 25);
                cables = rand_range(0, 2);
                la = rand_range(0, 25);
                lb = la; while (lb == la) lb = rand_range(0, 25);
                lc = la; while (lc == la || lc == lb) lc = rand_range(0, 25);
                ld = la; while (ld == la || ld == lb || ld == lc) ld = rand_range(0, 25);
                if (cables < 1) begin la = NO_CABLE; lb = NO_CABLE; end
                if (cables < 2) begin lc = NO_CABLE; ld = NO_CABLE; end

                reset_len = rand_range(1, 4);
                start_machine_with_reset(reset_len, r1, r2, r3, p1, p2, p3, la, lb, lc, ld);
                if (verbose_output)
                    $display("    rotors %0d/%0d/%0d positions %0d/%0d/%0d cables (%0d,%0d) (%0d,%0d)", r1, r2, r3, p1, p2, p3, la, lb, lc, ld);

                for (k = 0; k < letters_per_config; k = k + 1) begin
                    random_txn_index         = random_txn_index + 1;
                    random_transactions_sent = random_transactions_sent + 1;

                    if (rand_range(0, 99) < 12) letter = rand_range(26, 31);   // invalid letter
                    else                        letter = rand_range(0, 25);
                    ui_junk_bits = rand_range(0, 3);
                    uio_in       = rand_range(0, 255);                          // bus noise after config
                    width        = rand_range(1, 3);
                    block_enable = (rand_range(0, 99) < 6);                     // enable low across the request

                    if (block_enable) ena = 1'b0;
                    drive_ui(1, letter);
                    wait_cycles(width);
                    drive_ui(0, letter);
                    if (block_enable) begin
                        next_cycle;                                             // E1 sees ena=0
                        ena = 1'b1;
                    end

                    // Mostly legal spacing (>= 8 edges between valid requests), sometimes too fast.
                    if (rand_range(0, 99) < 80) idle = (MIN_ACCEPTED_SPACING - width) + rand_range(0, 6);
                    else                        idle = rand_range(0, 6);
                    if (block_enable && idle > 0) idle = idle - 1;
                    if (idle < 0) idle = 0;

                    // Occasionally drop enable in the middle of an encryption.
                    if (rand_range(0, 99) < 5 && idle > 3) begin
                        ena = 1'b0;
                        wait_cycles(2);
                        ena = 1'b1;
                        idle = idle - 2;
                    end
                    wait_cycles(idle);
                end
                wait_cycles(RESPONSE_TIMEOUT_CYCLES);
                end_test;
            end
            random_phase_active = 1'b0;
        end
    endtask

    // =========================================================================
    // 13. SETUP AND FINAL REPORT
    // =========================================================================
    task automatic initialize_testbench;
        integer i;
        begin
            rst_n = 1'b0; ena = 1'b1; ui_in = 8'h00; uio_in = IDLE_UIO_VALUE;
            ui_junk_bits = 2'b00; plug_byte_junk_bits = 3'b000; hold_strobe_during_config = 1'b0;
            cycle_count = 0;
            total_error_count = 0; protocol_error_count = 0; data_error_count = 0;
            assertion_error_count = 0; intent_error_count = 0; printed_error_count = 0;
            last_error_printed = 1'b0;
            tests_started = 0; tests_passed = 0; tests_failed = 0;
            known_issue_failures = 0; unexpected_failures = 0; errors_in_known_issue_tests = 0;
            ki1_failed = 1'b0; ki2_failed = 1'b0;
            current_test_name = "(none)"; current_known_issue_id = 0; errors_at_test_start = 0;
            encrypted_chars_checked = 0; echo_chars_checked = 0; known_answer_checks = 0;
            output_cycles_checked = 0; responses_completed = 0; last_response_result = -1;
            random_txn_index = 0; random_transactions_sent = 0; random_phase_active = 1'b0;
            response_wait_timed_out = 1'b0;
            predictor_armed = 1'b0; pred_cfg_edge_index = 0; pred_busy_cycles_left = 0;
            pred_request_pending = 1'b0; pred_strobe_previous = 1'b0; pred_was_busy = 1'b0;
            pred_config_ready = 1'b0; pred_accepted_total = 0; pred_dropped_total = 0;
            pred_request_letter = 0; pred_request_cycle = 0; pred_request_txn = 0;
            pred_pending_cipher = 0; pred_cipher = 0;
            exp_valid = 1'b0; exp_result = 5'd0; exp_changed_this_edge = 1'b0;
            last_published_was_encrypt = 1'b0; visible_change = 1'b0;
            prev_valid = 1'b0; prev_result = 5'd0; prev_uo_out = 8'h00;
            for (i = 0; i < 7; i = i + 1) begin cfg_byte[i] = 8'h00; cfg_drive_byte[i] = 8'h00; end
            fifo_clear;
            ref_build_tables;
            ref_set_config(0, 1, 2, 0, 0, 0, NO_CABLE, NO_CABLE, NO_CABLE, NO_CABLE);

            // plusargs:  +SEED=n  +VERBOSE  +NOVCD  +KNOWN_ISSUES_NONFATAL  +RANDOM_CONFIGS=n  +LETTERS=n
            random_seed_value = DEFAULT_RANDOM_SEED;
            if ($value$plusargs("SEED=%d", random_seed_value)) ;
            random_config_count = NUM_RANDOM_CONFIGS;
            random_letters_per_config = LETTERS_PER_RANDOM_CONFIG;
            if ($value$plusargs("RANDOM_CONFIGS=%d", random_config_count)) ;
            if ($value$plusargs("LETTERS=%d", random_letters_per_config)) ;
            verbose_output        = $test$plusargs("VERBOSE");
            known_issues_nonfatal = $test$plusargs("KNOWN_ISSUES_NONFATAL");
            waveform_enabled      = !$test$plusargs("NOVCD");
            random_state = random_seed_value;

            $timeformat(-9, 0, " ns", 8);
            if (waveform_enabled) begin
                $dumpfile("tb_enigma.vcd");
                $dumpvars(0, tb_enigma);
            end
            $display("==================================================================");
            $display("  Enigma ASIC testbench  (tests assert INTENDED behaviour)");
            $display("  random seed = %0d", random_seed_value);
            $display("==================================================================");
        end
    endtask

    task automatic print_final_summary;
        integer fatal_errors;
        reg overall_pass;
        begin
            fatal_errors = total_error_count;
            if (known_issues_nonfatal) fatal_errors = total_error_count - errors_in_known_issue_tests;
            overall_pass = (fatal_errors == 0);

            $display("");
            $display("==================================================================");
            $display("  FINAL VERIFICATION REPORT");
            $display("==================================================================");
            $display("  Tests executed                 : %0d", tests_started);
            $display("  Tests passed                   : %0d", tests_passed);
            $display("  Tests failed                   : %0d  (%0d known-issue, %0d unexpected)", tests_failed, known_issue_failures, unexpected_failures);
            $display("  Encrypted characters checked   : %0d", encrypted_chars_checked);
            $display("  Echoed (invalid) chars checked : %0d", echo_chars_checked);
            $display("  Literal known-answer checks    : %0d", known_answer_checks);
            $display("  Randomised transactions        : %0d  (seed %0d)", random_transactions_sent, random_seed_value);
            $display("  Requests accepted / dropped    : %0d / %0d  (protocol model)", pred_accepted_total, pred_dropped_total);
            $display("  Output cycles checked          : %0d", output_cycles_checked);
            $display("  Protocol violations            : %0d", protocol_error_count);
            $display("  Data mismatches                : %0d", data_error_count);
            $display("  Assertion/interface failures   : %0d", assertion_error_count);
            $display("  Testbench-expectation failures : %0d", intent_error_count);
            if (ki1_failed) $display("  KNOWN ISSUE KI-1 still present : unused plug endpoint (26..31) is treated as letter A");
            if (ki2_failed) $display("  KNOWN ISSUE KI-2 still present : rotor select 5 is accepted as an identity rotor");
            if (known_issues_nonfatal && errors_in_known_issue_tests != 0)
                $display("  (+KNOWN_ISSUES_NONFATAL: %0d error(s) inside known-issue tests were excluded from the verdict)", errors_in_known_issue_tests);
            $display("------------------------------------------------------------------");
            if (overall_pass) $display("  TESTBENCH RESULT: PASS");
            else              $display("  TESTBENCH RESULT: FAIL");
            $display("------------------------------------------------------------------");
            $display("  PASS here means 'no mismatch found by THESE tests'.  It is not a");
            $display("  production sign-off: gate-level simulation, coverage review, X-propagation");
            $display("  and timing sign-off are still required.");
            $display("==================================================================");
        end
    endtask

    // Watchdog: a hung simulation must end with FAIL, not run forever.
    initial begin
        #(MAX_SIM_TIME_NS);
        $display("  TESTBENCH RESULT: FAIL  (watchdog timeout after %0d ns)", MAX_SIM_TIME_NS);
        $finish;
    end

    // =========================================================================
    // 14. MAIN TEST SEQUENCE  (add new directed tests here)
    // =========================================================================
    initial begin : main_test_sequence
        initialize_testbench;
        next_cycle;

        run_model_self_tests;         // T1
        run_reset_tests;              // T2
        run_configuration_tests;      // T3
        run_rotor_tests;              // T4
        run_stepping_tests;           // T5
        run_plugboard_tests;          // T6
        run_protocol_tests;           // T7
        run_random_tests(random_config_count, random_letters_per_config);  // T9

        print_final_summary;
        $finish;
    end

endmodule