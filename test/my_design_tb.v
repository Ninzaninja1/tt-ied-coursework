`timescale 1ns/1ps

module my_design_tb;

    // ------------------------------------------------------------
    // DUT inputs and outputs
    // ------------------------------------------------------------
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    reg clk;
    reg rst_n;
    reg ena;

    wire [7:0] uo_out;
    wire [7:0] uio_oe;
    wire [7:0] uio_out;

    // ------------------------------------------------------------
    // Instantiate DUT
    // ------------------------------------------------------------
    tt_um_ninzaninja1_ied_coursework uut (
        .ui_in(ui_in),
        .uio_in(uio_in),
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .uo_out(uo_out),
        .uio_oe(uio_oe),
        .uio_out(uio_out)
    );

    // ------------------------------------------------------------
    // Clock generation: 10ns period
    // ------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Test counters
    // ------------------------------------------------------------
    integer tests_passed;
    integer tests_failed;

    // ------------------------------------------------------------
    // Reset task
    // ------------------------------------------------------------
    task reset_dut;
        begin
            rst_n = 0;
            ui_in = 8'd0;
            uio_in = 8'd0;
            ena = 1;

            repeat (3) @(posedge clk);

            @(negedge clk);
            rst_n = 1;

            $display("--------------------------------------");
            $display("RESET RELEASED");
            $display("--------------------------------------");
        end
    endtask

    // ------------------------------------------------------------
    // Generalised configuration task
    //
    // s1/s2/s3 = rotor selection for slot1(right)/slot2(mid)/slot3(left)
    //            000=I 001=II 010=III 011=IV 100=V
    // p1/p2/p3 = starting position for slot1/slot2/slot3 (0=A ... 25=Z)
    // pg1a/pg1b = plugboard cable 1 letters, pg2a/pg2b = cable 2.
    //             Use 26..31 to leave a cable unused (pass-through).
    //
    // Builds the 24-bit config word
    //   {pos3, pos2, pos1, slot3_sel, slot2_sel, slot1_sel}
    // and streams it as SEVEN bytes (3 rotor bytes + 4 plug letters),
    // MSB mapping follows the RTL header.
    //
    // The loader is free-running: it starts counting the moment rst_n goes
    // high, so byte 0 must be presented on the FIRST clock after reset
    // release -- we are still on that negedge now, so drive it immediately.
    // ------------------------------------------------------------
    task load_config;
        input [2:0] s1;
        input [2:0] s2;
        input [2:0] s3;
        input [4:0] p1;
        input [4:0] p2;
        input [4:0] p3;
        input [4:0] pg1a;
        input [4:0] pg1b;
        input [4:0] pg2a;
        input [4:0] pg2b;
        reg [23:0] cfg;
        begin
            cfg = {p3, p2, p1, s3, s2, s1};

            $display("\nLoading Enigma configuration...");
            $display("  slot1(right)=%0d  slot2(mid)=%0d  slot3(left)=%0d",
                     s1, s2, s3);
            $display("  pos1=%0d  pos2=%0d  pos3=%0d", p1, p2, p3);
            $display("  plug cables: %0d-%0d  %0d-%0d",
                     pg1a, pg1b, pg2a, pg2b);

            // byte 0 = {slot3[1:0], slot2[2:0], slot1[2:0]}
            uio_in = cfg[7:0];

            // byte 1 = {pos2[1:0], pos1[4:0], slot3[2]}
            @(negedge clk);
            uio_in = cfg[15:8];

            // byte 2 = {pos3[4:0], pos2[4:2]}
            @(negedge clk);
            uio_in = cfg[23:16];

            // byte 3..6 = plugboard cable letters (upper 3 bits ignored)
            @(negedge clk);
            uio_in = {3'b000, pg1a};

            @(negedge clk);
            uio_in = {3'b000, pg1b};

            @(negedge clk);
            uio_in = {3'b000, pg2a};

            @(negedge clk);
            uio_in = {3'b000, pg2b};

            // Allow the 7-byte loader to finish and positions to load
            repeat (3) @(posedge clk);

            @(negedge clk);
            uio_in = 8'h00;
        end
    endtask

    // ------------------------------------------------------------
    // Compare one 5-bit value against the expected value
    // ------------------------------------------------------------
    task check_val;
        input [8*24:1] label;
        input [4:0] got;
        input [4:0] exp;
        begin
            if (got === exp) begin
                $display("  PASS: %0s = %0d", label, got);
                tests_passed = tests_passed + 1;
            end
            else begin
                $display("  FAIL: %0s = %0d (expected %0d)", label, got, exp);
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Drive one encrypted character and wait for the result
    // ------------------------------------------------------------
    task send_char;
        input [4:0] letter;
        begin
            // Apply plaintext and generate rising STROBE
            @(negedge clk);
            ui_in = {1'b1, 2'b00, letter};

            // E0: input and strobe registered
            @(posedge clk);

            // Lower STROBE
            @(negedge clk);
            ui_in[7] = 1'b0;

            // E1: character accepted
            @(posedge clk);
            #1;

            // Wait for encryption to finish
            wait (uo_out[7] === 1'b1);
            #1;
        end
    endtask

    // ------------------------------------------------------------
    // Encrypt one valid character and check ciphertext + VALID
    // ------------------------------------------------------------
    task encrypt_and_check;
        input [4:0] letter;
        input [4:0] expected;
        input [8*24:1] test_name;

        begin
            // Apply plaintext and generate rising STROBE
            @(negedge clk);
            ui_in = {1'b1, 2'b00, letter};

            // E0: input and strobe registered
            @(posedge clk);

            // Lower STROBE
            @(negedge clk);
            ui_in[7] = 1'b0;

            // E1: character accepted
            @(posedge clk);
            #1;

            // VALID must go low while processing
            if (uo_out[7] !== 1'b0) begin
                $display("FAIL: %0s - VALID did not go LOW", test_name);
                tests_failed = tests_failed + 1;
            end
            else begin
                $display("PASS: %0s - VALID went LOW", test_name);
                tests_passed = tests_passed + 1;
            end

            // Wait for encryption to finish
            wait (uo_out[7] === 1'b1);
            #1;

            // Check ciphertext
            if (uo_out[4:0] === expected) begin
                $display(
                    "PASS: %0s - Input=%0d Output=%0d Expected=%0d",
                    test_name, letter, uo_out[4:0], expected
                );
                tests_passed = tests_passed + 1;
            end
            else begin
                $display(
                    "FAIL: %0s - Input=%0d Output=%0d Expected=%0d",
                    test_name, letter, uo_out[4:0], expected
                );
                tests_failed = tests_failed + 1;
            end

            // Check unused output bits
            if (uo_out[6:5] !== 2'b00) begin
                $display("FAIL: Output bits [6:5] are not zero");
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Per-stage trace check
    //
    // Drives one character, then samples the internal "mid" register
    // after every pipeline step and compares it against the expected
    // letter leaving that stage. The pipeline is:
    //
    //   cnt=0 : slot1 forward (right rotor)
    //   cnt=1 : slot2 forward (middle rotor)
    //   cnt=2 : slot3 forward (left rotor)
    //   cnt=3 : reflector
    //   cnt=4 : slot3 inverse (left rotor)
    //   cnt=5 : slot2 inverse (middle rotor)
    //   cnt=6 : slot1 inverse (right rotor)  -> result / lamp
    //
    // Expected values (5-bit, A=0):
    //   e_in   = letter presented to the machine
    //   e_f1   = letter leaving right rotor (forward)
    //   e_f2   = letter leaving middle rotor (forward)
    //   e_f3   = letter leaving left rotor (forward)
    //   e_refl = letter leaving the reflector
    //   e_i3   = letter leaving left rotor (inverse)
    //   e_i2   = letter leaving middle rotor (inverse)
    //   e_i1   = letter leaving right rotor (inverse) = final lamp
    // ------------------------------------------------------------
    task trace_and_check;
        input [4:0] letter;
        input [8*24:1] test_name;
        input [4:0] e_in;
        input [4:0] e_f1;
        input [4:0] e_f2;
        input [4:0] e_f3;
        input [4:0] e_refl;
        input [4:0] e_i3;
        input [4:0] e_i2;
        input [4:0] e_i1;
        begin
            $display("\n-- Stage trace: %0s (input %0d) --", test_name, letter);

            // Apply plaintext and generate rising STROBE
            @(negedge clk);
            ui_in = {1'b1, 2'b00, letter};
            @(posedge clk);       // E0: input and strobe registered

            @(negedge clk);
            ui_in[7] = 1'b0;
            @(posedge clk);       // E1: accepted, mid <= input, state -> ROT
            #1;
            check_val("input reg          ", uut.mid, e_in);

            @(posedge clk); #1; check_val("rotor1 fwd (right) ", uut.mid, e_f1);
            @(posedge clk); #1; check_val("rotor2 fwd (mid)   ", uut.mid, e_f2);
            @(posedge clk); #1; check_val("rotor3 fwd (left)  ", uut.mid, e_f3);
            @(posedge clk); #1; check_val("reflector          ", uut.mid, e_refl);
            @(posedge clk); #1; check_val("rotor3 inv (left)  ", uut.mid, e_i3);
            @(posedge clk); #1; check_val("rotor2 inv (mid)   ", uut.mid, e_i2);
            @(posedge clk); #1; check_val("rotor1 inv (right) ", uut.mid, e_i1);

            check_val("final lamp         ", uut.result, e_i1);
        end
    endtask

    // ------------------------------------------------------------
    // Encrypt one character and check ciphertext AND the resulting
    // rotor positions (used by the edge-case tests)
    // ------------------------------------------------------------
    task key_and_check;
        input [4:0] letter;
        input [4:0] exp_out;
        input [4:0] exp_p1;
        input [4:0] exp_p2;
        input [4:0] exp_p3;
        input [8*24:1] test_name;
        begin
            $display("\n-- %0s (input %0d) --", test_name, letter);
            send_char(letter);

            if (uo_out[4:0] === exp_out) begin
                $display("  PASS: lamp = %0d (expected %0d)", uo_out[4:0], exp_out);
                tests_passed = tests_passed + 1;
            end
            else begin
                $display("  FAIL: lamp = %0d (expected %0d)", uo_out[4:0], exp_out);
                tests_failed = tests_failed + 1;
            end

            check_val("pos1 (right)", uut.pos1, exp_p1);
            check_val("pos2 (mid)  ", uut.pos2, exp_p2);
            check_val("pos3 (left) ", uut.pos3, exp_p3);
        end
    endtask

    // ------------------------------------------------------------
    // Invalid input test
    //
    // Invalid letters (26-31) should:
    //   - Be echoed directly to the output
    //   - Not undergo encryption
    //   - Not step the rotors
    //   - Set VALID high
    // ------------------------------------------------------------
    task invalid_input_test;
        input [4:0] letter;

        begin
            $display("\nTesting invalid input: %0d", letter);

            @(negedge clk);
            ui_in = {1'b1, 2'b00, letter};

            @(posedge clk);

            @(negedge clk);
            ui_in[7] = 1'b0;

            @(posedge clk);
            #1;

            if (uo_out[4:0] === letter && uo_out[7] === 1'b1) begin
                $display("PASS: Invalid input correctly echoed");
                tests_passed = tests_passed + 1;
            end
            else begin
                $display(
                    "FAIL: Invalid input - Output=%0d Expected=%0d VALID=%b",
                    uo_out[4:0], letter, uo_out[7]
                );
                tests_failed = tests_failed + 1;
            end
        end
    endtask

    // ------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------
    initial begin

        tests_passed = 0;
        tests_failed = 0;

        $dumpfile("enigma.vcd");
        $dumpvars(0, my_design_tb);

        $display("\n======================================");
        $display("       ENIGMA M3 TESTBENCH");
        $display("======================================");

        // ============================================================
        // TEST 1: STANDARD ENIGMA REFERENCE VECTOR
        //   Rotors I-II-III (left-mid-right), reflector B, AAA
        //   Plaintext AAAAA -> Ciphertext BDZGO
        // ============================================================
        reset_dut();
        load_config(3'b010, 3'b001, 3'b000, 5'd0, 5'd0, 5'd0, 5'd31, 5'd31, 5'd31, 5'd31);

        $display("\n--------------------------------------");
        $display("TEST 1: STANDARD ENIGMA ENCRYPTION");
        $display("--------------------------------------");

        encrypt_and_check(5'd0, 5'd1,  "Letter 1: A -> B");
        encrypt_and_check(5'd0, 5'd3,  "Letter 2: A -> D");
        encrypt_and_check(5'd0, 5'd25, "Letter 3: A -> Z");
        encrypt_and_check(5'd0, 5'd6,  "Letter 4: A -> G");
        encrypt_and_check(5'd0, 5'd14, "Letter 5: A -> O");

        // ============================================================
        // TEST 2: INVALID INPUTS
        // ============================================================
        $display("\n--------------------------------------");
        $display("TEST 2: INVALID INPUTS");
        $display("--------------------------------------");

        invalid_input_test(5'd26);
        invalid_input_test(5'd27);
        invalid_input_test(5'd31);

        // ============================================================
        // TEST 3: OUTPUT AND INTERFACE CHECKS
        // ============================================================
        $display("\n--------------------------------------");
        $display("TEST 3: OUTPUT AND INTERFACE CHECKS");
        $display("--------------------------------------");

        if (uio_oe === 8'b00000000) begin
            $display("PASS: uio_oe is zero");
            tests_passed = tests_passed + 1;
        end
        else begin
            $display("FAIL: uio_oe is not zero");
            tests_failed = tests_failed + 1;
        end

        if (uio_out === 8'b00000000) begin
            $display("PASS: uio_out is zero");
            tests_passed = tests_passed + 1;
        end
        else begin
            $display("FAIL: uio_out is not zero");
            tests_failed = tests_failed + 1;
        end

        // ============================================================
        // TEST 4: PER-STAGE ROTOR TRACE
        //
        //   Fresh machine, I-II-III at AAA. Drive one character and
        //   assert the letter leaving every stage (each rotor forward
        //   and inverse, plus the reflector), not just the final lamp.
        //
        //   Stage order = right(III) -> mid(II) -> left(I) -> reflector
        //                 -> left(I) -> mid(II) -> right(III)
        // ============================================================
        reset_dut();
        load_config(3'b010, 3'b001, 3'b000, 5'd0, 5'd0, 5'd0, 5'd31, 5'd31, 5'd31, 5'd31);

        $display("\n--------------------------------------");
        $display("TEST 4: PER-STAGE ROTOR TRACE");
        $display("--------------------------------------");

        // Key 1: right rotor has just stepped A->B (pos1 = 1)
        //   A -> III fwd C -> II fwd D -> I fwd F -> refl S
        //     -> I inv S -> II inv E -> III inv B (lamp)
        trace_and_check(
            5'd0, "Key1 AAA",
            5'd0,    // input
            5'd2,    // III fwd = C
            5'd3,    // II  fwd = D
            5'd5,    // I   fwd = F
            5'd18,   // reflector = S
            5'd18,   // I   inv = S
            5'd4,    // II  inv = E
            5'd1     // III inv = B
        );

        // Key 2: right rotor now at C (pos1 = 2)
        //   A -> III fwd D -> II fwd K -> I fwd N -> refl K
        //     -> I inv B -> II inv J -> III inv D (lamp)
        trace_and_check(
            5'd0, "Key2 AAA",
            5'd0,    // input
            5'd3,    // III fwd = D
            5'd10,   // II  fwd = K
            5'd13,   // I   fwd = N
            5'd10,   // reflector = K
            5'd1,    // I   inv = B
            5'd9,    // II  inv = J
            5'd3     // III inv = D
        );

        // ============================================================
        // TEST 5: ROTOR EDGE CASES
        //
        //   Each test resets and reloads the machine with positions
        //   chosen to hit a specific rotor boundary, then checks both
        //   the lamp and the resulting rotor positions.
        // ============================================================
        $display("\n--------------------------------------");
        $display("TEST 5: ROTOR EDGE CASES");
        $display("--------------------------------------");

        // 5a: right rotor wraps Z -> A
        //   III (right) starts at Z (25); one keypress must step it to A.
        //   All-at-A encryption of A gives U (20).
        reset_dut();
        load_config(3'b010, 3'b001, 3'b000, 5'd25, 5'd0, 5'd0, 5'd31, 5'd31, 5'd31, 5'd31);
        key_and_check(5'd0, 5'd20, 5'd0, 5'd0, 5'd0,
                      "Wrap: right Z -> A");

        // 5b: right-rotor notch kicks the middle rotor
        //   III notch = V (21), II notch = E (4).
        //   Right starts at U (20):
        //     press 1 -> right U->V, middle not yet stepped
        //     press 2 -> right is at V(notchV) so middle steps 0->1
        reset_dut();
        load_config(3'b010, 3'b001, 3'b000, 5'd20, 5'd0, 5'd0, 5'd31, 5'd31, 5'd31, 5'd31);
        key_and_check(5'd0, 5'd12, 5'd21, 5'd0, 5'd0,
                      "Notch: right U -> V");
        key_and_check(5'd0, 5'd20, 5'd22, 5'd1, 5'd0,
                      "Notch: right V kicks middle");

        // 5c: middle-rotor notch double-steps middle + left
        //   Middle starts at E (4) = II notch. One keypress must advance
        //   BOTH the middle (4->5) and the left rotor (0->1).
        reset_dut();
        load_config(3'b010, 3'b001, 3'b000, 5'd0, 5'd4, 5'd0, 5'd31, 5'd31, 5'd31, 5'd31);
        key_and_check(5'd0, 5'd5, 5'd1, 5'd5, 5'd1,
                      "Notch: middle E double-step");

        // ============================================================
        // TEST 6: FINAL REPORT
        // ============================================================
        $display("\n======================================");
        $display("             TEST RESULTS");
        $display("======================================");

        $display("Tests passed : %0d", tests_passed);
        $display("Tests failed : %0d", tests_failed);
        $display("--------------------------------------");

        if (tests_failed == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: SOME TESTS FAILED");

        $display("======================================");

        #20;
        $finish;
    end

    // ------------------------------------------------------------
    // Simulation timeout protection
    // ------------------------------------------------------------
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
