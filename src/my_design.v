// =============================================================================
//  Configuration stream:
//    byte 0 = {slot3_sel[1:0], slot2_sel[2:0], slot1_sel[2:0]}
//    byte 1 = {pos2[1:0], pos1[4:0], slot3_sel[2]}
//    byte 2 = {pos3[4:0], pos2[4:2]}
//
//    config_reg = {pos3[4:0], pos2[4:0], pos1[4:0], slot3_sel[2:0], slot2_sel[2:0], slot1_sel[2:0]}
//    [23:19] pos3 [18:14] pos2 [13:9] pos1 [8:6] slot3_sel [5:3] slot2_sel [2:0] slot1_sel
//
//  slot1 = right (fast) rotor
// =============================================================================

module tt_um_ninzaninja1_ied_coursework (
    input  wire [7:0] ui_in,
    input  wire [7:0] uio_in,
    input  wire clk, rst_n, ena,
    output wire [7:0] uo_out, uio_oe, uio_out
);

    reg [4:0] in;
    reg stb1, stb2;

    always @(posedge clk) begin
        in <= ui_in[4:0];

        if (!rst_n) begin
            stb1 <= 1'b0;
            stb2 <= 1'b0;
        end else begin
            stb1 <= ui_in[7];
            stb2 <= stb1;
        end
    end

    wire trig = stb1 & ~stb2; // rising edge of strobe
    wire letter_ok = (in < 5'd26);

    // ------------------------------------------------------------------
    // Load config - 3 bytes
    // ------------------------------------------------------------------
    reg [23:0] config_reg;
    reg [1:0] config_counter;
    reg config_loaded;
    reg config_done;

    always @(posedge clk) begin
        if (!rst_n) begin // if reset then put everything to 0
            config_counter <= 2'd0;
            config_loaded <= 1'b0;
            config_done <= 1'b0;
        end else begin
            config_done <= 1'b0;
			// load value from uio_in 3 times (counted by config_counter, and set config_done flag to true when its complete)
            if (!config_loaded) begin 
                // Count 0,1,2 to capture the three bytes, then use count 3 to
                // raise config_done one cycle LATER so config_reg is fully written to before reading
                if (config_counter == 2'd3) begin
                    config_loaded <= 1'b1;
                    config_done   <= 1'b1;
                end else begin
                    config_counter <= config_counter + 2'd1; //increment counter
                end
            end
        end
    end

    always @(posedge clk) begin // load config for 3 clk cycles
        if (rst_n && !config_loaded) begin
            case (config_counter)
                2'd0: config_reg[7:0]   <= uio_in;
                2'd1: config_reg[15:8]  <= uio_in;
                2'd2: config_reg[23:16] <= uio_in;
                default: ;
            endcase
        end
    end
	// 000 = I ; 001 = II ; 010 = III ; 011 = IV ; 100 = V Rotor selection
    wire [2:0] slot1_sel = config_reg[2:0];
    wire [2:0] slot2_sel = config_reg[5:3];
    wire [2:0] slot3_sel = config_reg[8:6];

    // ------------------------------------------------------------------
    // Modulo add & sub (to cap letters between 0-25)
    // ------------------------------------------------------------------
    function [4:0] mod26_add;
        input [4:0] a;
        input [4:0] b;
        reg [5:0] s;
        begin
            s = {1'b0, a} + {1'b0, b};

            if (s >= 6'd26)
                mod26_add = s[4:0] - 5'd26;
            else
                mod26_add = s[4:0];
        end
    endfunction

    function [4:0] mod26_sub;
        input [4:0] a;
        input [4:0] b;
        reg [5:0] d;
        begin
            d = {1'b0, a} + 6'd26 - {1'b0, b};

            if (d >= 6'd26)
                mod26_sub = d[4:0] - 5'd26;
            else
                mod26_sub = d[4:0];
        end
    endfunction

    // ------------------------------------------------------------------
    // LUTS
    // ------------------------------------------------------------------
    `include "rotor_luts.vh"
    // ------------------------------------------------------------------
    // Stages of machine
    // ------------------------------------------------------------------
    reg [4:0] pos1, pos2, pos3; // rotor offset
    reg [4:0] mid;
    reg [2:0] cnt;
    reg [1:0] state;
    reg [4:0] result;
    reg       valid;

    localparam [1:0] IDLE = 2'd0, ROT  = 2'd1;

    reg [1:0] curr_segment; // 2'd0 forward, 2'd1 reflector, 2'd2 inverse
    reg [2:0] curr_sel; // which rotor slot to use 
    reg [4:0] curr_pos; // rotating after each letter

    always @(*) begin
        curr_segment = 2'd0;
        curr_sel  = slot1_sel;
        curr_pos  = pos1;

        case (cnt) // select stage and params for that stage
            3'd0: begin
                curr_segment = 2'd0;
                curr_sel  = slot1_sel;
                curr_pos  = pos1;
            end

            3'd1: begin
                curr_segment = 2'd0;
                curr_sel  = slot2_sel;
                curr_pos  = pos2;
            end

            3'd2: begin
                curr_segment = 2'd0;
                curr_sel  = slot3_sel;
                curr_pos  = pos3;
            end

            3'd3: begin
                curr_segment = 2'd1;
                curr_sel  = 3'b000;
                curr_pos  = 5'd0;
            end

            3'd4: begin
                curr_segment = 2'd2;
                curr_sel  = slot3_sel;
                curr_pos  = pos3;
            end

            3'd5: begin
                curr_segment = 2'd2;
                curr_sel  = slot2_sel;
                curr_pos  = pos2;
            end

            3'd6: begin
                curr_segment = 2'd2;
                curr_sel  = slot1_sel;
                curr_pos  = pos1;
            end

            default: begin
                curr_segment = 2'd0;
                curr_sel  = slot1_sel;
                curr_pos  = pos1;
            end
        endcase
    end

    // ------------------------------------------------------------------
    // Rotor datapath (one stage per clock)
    // ------------------------------------------------------------------
    wire [4:0] shifted  = mod26_add(mid, curr_pos);
    wire [4:0] fwd_out  = apply_rotor(curr_sel, shifted);
    wire [4:0] inv_out  = apply_rotor_inv(curr_sel, shifted);
    wire [4:0] refl_out = apply_reflector(mid);

    reg [4:0] stage_out;

    always @(*) begin
        case (curr_segment) // 2'd1 = reflector, 2'd2 = inverse rotor, 2'd0 = forward rotor.
            2'd0: stage_out = mod26_sub(fwd_out, curr_pos);
            2'd1: stage_out = refl_out;
            2'd2: stage_out = mod26_sub(inv_out, curr_pos);
            default: stage_out = mid;
        endcase
    end

    // ------------------------------------------------------------------
    // Rotor stepping
    // ------------------------------------------------------------------
    wire notch1 = (pos1 == notch_of(slot1_sel));
    wire notch2 = (pos2 == notch_of(slot2_sel));

    wire [4:0] pos1_inc = (pos1 == 5'd25) ? 5'd0 : pos1 + 5'd1;
    wire [4:0] pos2_inc = (pos2 == 5'd25) ? 5'd0 : pos2 + 5'd1;
    wire [4:0] pos3_inc = (pos3 == 5'd25) ? 5'd0 : pos3 + 5'd1;

    // ------------------------------------------------------------------
    // Single read correrction
    // ------------------------------------------------------------------
    wire go = trig & ena & config_loaded & (state == IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            state  <= IDLE;
            cnt    <= 3'd0;
            result <= 5'd0;
            valid  <= 1'b0;
        end else if (config_done) begin
            // Rotor positions are loaded in the block below.
        end else begin
            case (state)
                IDLE: begin
                    if (go) begin
                        if (letter_ok) begin
                            valid <= 1'b0;
                            cnt   <= 3'd0;
                            state <= ROT;
                        end else begin
                            result <= in;
                            valid  <= 1'b1;
                        end
                    end
                end
                ROT: begin
                    if (cnt == 3'd6) begin
                        cnt    <= 3'd0;
                        result <= stage_out;
                        valid  <= 1'b1;
                        state  <= IDLE;
                    end else begin
                        cnt <= cnt + 3'd1;
                    end
                end
                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

    // ------------------------------------------------------------------
    // Rotor positions 
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && config_done) begin // set initial positions
            pos1 <= (config_reg[13:9]  < 5'd26) ? config_reg[13:9] : 5'd0;
            pos2 <= (config_reg[18:14] < 5'd26) ? config_reg[18:14] : 5'd0;
            pos3 <= (config_reg[23:19] < 5'd26) ? config_reg[23:19] : 5'd0;
        end else if (rst_n && go && letter_ok) begin
            // Step first, then process the current character.
            pos1 <= pos1_inc;
            if (notch1 | notch2) 
                pos2 <= pos2_inc; // double step
            if (notch2) 
                pos3 <= pos3_inc;
        end

        if (state == IDLE)
            mid <= in;
        else if (state == ROT)
            mid <= stage_out;
    end

    // ------------------------------------------------------------------
    // Outputs
    // ------------------------------------------------------------------
    assign uo_out  = {valid, 2'b00, result};
    assign uio_oe  = 8'd0;
    assign uio_out = 8'd0;

    // Unused inputs
    wire _unused = &{1'b0, ui_in[6:5], 1'b0};

endmodule
   
