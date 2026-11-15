// input config1 32b = 3b(rotor I) + 3b(rotor II) + 3b(rotor III) + 
    //                     3b(rotor pos) + 5b(rotor pos) + 5b(rotor pos) + 6b(empty) +1b(is it config?) + 1b(is there more config?)
    // input config2 32b = 5b(notch I) + 5b(notch II) + 5b(notch III) + 
    //                     5b(plug 1) + 5b(plug 1) + + 1b(is it config?) + 1b(more?)
    // input config3 32b = 5b(plug 2) + 5b(plug 2) + 5b(plug 3) + 5b(plug 3) 
    //                     5b(plug 4) + 5b(plug 4) + 1b(is it config?) + 1b(more?)
    // repeat config3 structure till plug 8

    // input op 32b = 5b(letter) + 5b(letter) + 5b(letter) + 5b(letter) + 5b(letter) + 5b(letter) + 1b(is it config?) + 1b(more?)


module tt_um_ninzaninja1_ied_coursework (
	// letter to code, letter output after rotors 
    input  wire [7:0] ui_in, // only using 4:0 for letter encryption
	input  wire [7:0] uio_in, // use for config
	input  wire clk, rst_n, ena,
	output wire [7:0] uo_out, uio_oe, uio_out
);

	//   ui_in[4:0]  live letter (0..25)
	//   uio_in one config byte per strobe
	//   configReg[23:0] = { pos3[5b], pos2[5b], pos1[5b], slot3_sel[3b], slot2_sel[3b], slot1_sel[3b] }

	reg [23:0] configReg;
	reg [1:0] configCounter;
	reg configDone;

	always @(posedge clk) begin
		if (!rst_n) begin
			configReg <= 24'd0;
			configCounter <= 2'd0;
			configDone <= 1'b0;
		end else begin
			configDone <= (configCounter == 2'd2);
				case (configCounter)
					2'd0: configReg[7:0] <= uio_in;
					2'd1: configReg[15:8] <= uio_in;
					2'd2: configReg[23:16] <= uio_in;
				endcase
				configCounter <= (configCounter == 2'd2) ? 2'd0 : configCounter + 2'd1; // check if counter is 2 if it is reset it otherwise increment
		end
	end
	
	wire [8:0] rotor_sel; // selecting which rotors and in which order
	wire [2:0] slot3_sel, slot2_sel, slot1_sel;
	reg [4:0] in;
	reg [4:0] pos1, pos2, pos3;

	// select the rotors and their order 000 to 100
	// ui_in is for the letter you want to encrypt
	assign rotor_sel = configReg[8:0];
	assign slot1_sel = rotor_sel[2:0];
	assign slot2_sel = rotor_sel[5:3];
	assign slot3_sel = rotor_sel[8:6];

	// only 0-25 are letters so anything larger cannot be encoded so straight to output.
	wire letterOk;
	assign letterOk = (ui_in[4:0] < 5'd26);
	always @(*) in = (letterOk == 1'b1) ? ui_in[4:0] : 5'b00000;


// --------------------- LUTs ------------------------
    function [4:0] I;
    input [4:0] in;
    begin
        case(in)
        //EKMFLGDQVZNTOWYHXUSPAIBRCJ
        // ROTOR 1
            5'd0  : I = 5'd4;  // a -> e
            5'd1  : I = 5'd10; // b -> k
            5'd2  : I = 5'd12; // c -> m
            5'd3  : I = 5'd5;  // d -> f
            5'd4  : I = 5'd11; // e -> l
            5'd5  : I = 5'd6;  // f -> g
            5'd6  : I = 5'd3;  // g -> d
            5'd7  : I = 5'd16; // h -> q
            5'd8  : I = 5'd21; // i -> v
            5'd9  : I = 5'd25; // j -> z
            5'd10 : I = 5'd13; // k -> n
            5'd11 : I = 5'd19; // l -> t
            5'd12 : I = 5'd14; // m -> o
            5'd13 : I = 5'd22; // n -> w
            5'd14 : I = 5'd24; // o -> y
            5'd15 : I = 5'd7;  // p -> h
            5'd16 : I = 5'd23; // q -> x
            5'd17 : I = 5'd20; // r -> u
            5'd18 : I = 5'd18; // s -> s
            5'd19 : I = 5'd15; // t -> p
            5'd20 : I = 5'd0;  // u -> a
            5'd21 : I = 5'd8;  // v -> i
            5'd22 : I = 5'd1;  // w -> b
            5'd23 : I = 5'd17; // x -> r
            5'd24 : I = 5'd2;  // y -> c
            5'd25 : I = 5'd9;  // z -> j
            default : I = in;
        endcase
    end
    endfunction
    
    function [4:0] II;
    input [4:0] in;
    begin
        case(in)
        //AJDKSIRUXBLHWTMCQGZNPYFVOE
        // ROTOR 2
            5'd0  : II = 5'd0;  // a -> a
            5'd1  : II = 5'd9;  // b -> j
            5'd2  : II = 5'd3;  // c -> d
            5'd3  : II = 5'd10; // d -> k
            5'd4  : II = 5'd18; // e -> s
            5'd5  : II = 5'd8;  // f -> i
            5'd6  : II = 5'd17; // g -> r
            5'd7  : II = 5'd20; // h -> u
            5'd8  : II = 5'd23; // i -> x
            5'd9  : II = 5'd1;  // j -> b
            5'd10 : II = 5'd11; // k -> l
            5'd11 : II = 5'd7;  // l -> h
            5'd12 : II = 5'd22; // m -> w
            5'd13 : II = 5'd19; // n -> t
            5'd14 : II = 5'd12; // o -> m
            5'd15 : II = 5'd2;  // p -> c
            5'd16 : II = 5'd16; // q -> q
            5'd17 : II = 5'd6;  // r -> g
            5'd18 : II = 5'd25; // s -> z
            5'd19 : II = 5'd13; // t -> n
            5'd20 : II = 5'd15; // u -> p
            5'd21 : II = 5'd24; // v -> y
            5'd22 : II = 5'd5;  // w -> f
            5'd23 : II = 5'd21; // x -> v
            5'd24 : II = 5'd14; // y -> o
            5'd25 : II = 5'd4;  // z -> e
            default : II = in;
        endcase
    end 
    endfunction

    function [4:0] III;
    input [4:0] in;
    begin
        case(in)
        //BDFHJLCPRTXVZNYEIWGAKMUSQO
        // ROTOR 3
            5'd0  : III = 5'd1;  // a -> b
            5'd1  : III = 5'd3;  // b -> d
            5'd2  : III = 5'd5;  // c -> f
            5'd3  : III = 5'd7;  // d -> h
            5'd4  : III = 5'd9;  // e -> j
            5'd5  : III = 5'd11; // f -> l
            5'd6  : III = 5'd2;  // g -> c
            5'd7  : III = 5'd15; // h -> p
            5'd8  : III = 5'd17; // i -> r
            5'd9  : III = 5'd19; // j -> t
            5'd10 : III = 5'd23; // k -> x
            5'd11 : III = 5'd21; // l -> v
            5'd12 : III = 5'd25; // m -> z
            5'd13 : III = 5'd13; // n -> n
            5'd14 : III = 5'd24; // o -> y
            5'd15 : III = 5'd4;  // p -> e
            5'd16 : III = 5'd8;  // q -> i
            5'd17 : III = 5'd22; // r -> w
            5'd18 : III = 5'd6;  // s -> g
            5'd19 : III = 5'd0;  // t -> a
            5'd20 : III = 5'd10; // u -> k
            5'd21 : III = 5'd12; // v -> m
            5'd22 : III = 5'd20; // w -> u
            5'd23 : III = 5'd18; // x -> s
            5'd24 : III = 5'd16; // y -> q
            5'd25 : III = 5'd14; // z -> o
            default : III = in;
        endcase
    end
    endfunction

    function [4:0] IV;
    input [4:0] in;
    begin
        case(in)
        //ESOVPZJAYQUIRHXLNFTGKDCMWB
        // ROTOR 4
            5'd0  : IV = 5'd4;  // a -> e
            5'd1  : IV = 5'd18; // b -> s
            5'd2  : IV = 5'd14; // c -> o
            5'd3  : IV = 5'd21; // d -> v
            5'd4  : IV = 5'd15; // e -> p
            5'd5  : IV = 5'd25; // f -> z
            5'd6  : IV = 5'd9;  // g -> j
            5'd7  : IV = 5'd0;  // h -> a
            5'd8  : IV = 5'd24; // i -> y
            5'd9  : IV = 5'd16; // j -> q
            5'd10 : IV = 5'd20; // k -> u
            5'd11 : IV = 5'd8;  // l -> i
            5'd12 : IV = 5'd17; // m -> r
            5'd13 : IV = 5'd7;  // n -> h
            5'd14 : IV = 5'd23; // o -> x
            5'd15 : IV = 5'd11; // p -> l
            5'd16 : IV = 5'd13; // q -> n
            5'd17 : IV = 5'd5;  // r -> f
            5'd18 : IV = 5'd19; // s -> t
            5'd19 : IV = 5'd6;  // t -> g
            5'd20 : IV = 5'd10; // u -> k
            5'd21 : IV = 5'd3;  // v -> d
            5'd22 : IV = 5'd2;  // w -> c
            5'd23 : IV = 5'd12; // x -> m
            5'd24 : IV = 5'd22; // y -> w
            5'd25 : IV = 5'd1;  // z -> b
            default : IV = in;
        endcase
    end
    endfunction

    function [4:0] V;
    input [4:0] in;
    begin
        case(in)
        //VZBRGITYUPSDNHLXAWMJQOFECK
        // ROTOR 5
            5'd0  : V = 5'd21; // a -> v
            5'd1  : V = 5'd25; // b -> z
            5'd2  : V = 5'd1;  // c -> b
            5'd3  : V = 5'd17; // d -> r
            5'd4  : V = 5'd6;  // e -> g
            5'd5  : V = 5'd8;  // f -> i
            5'd6  : V = 5'd19; // g -> t
            5'd7  : V = 5'd24; // h -> y
            5'd8  : V = 5'd20; // i -> u
            5'd9  : V = 5'd15; // j -> p
            5'd10 : V = 5'd18; // k -> s
            5'd11 : V = 5'd3;  // l -> d
            5'd12 : V = 5'd13; // m -> n
            5'd13 : V = 5'd7;  // n -> h
            5'd14 : V = 5'd11; // o -> l
            5'd15 : V = 5'd23; // p -> x
            5'd16 : V = 5'd0;  // q -> a
            5'd17 : V = 5'd22; // r -> w
            5'd18 : V = 5'd12; // s -> m
            5'd19 : V = 5'd9;  // t -> j
            5'd20 : V = 5'd16; // u -> q
            5'd21 : V = 5'd14; // v -> o
            5'd22 : V = 5'd5;  // w -> f
            5'd23 : V = 5'd4;  // x -> e
            5'd24 : V = 5'd2;  // y -> c
            5'd25 : V = 5'd10; // z -> k
            default : V = in;
        endcase
    end
    endfunction


    function [4:0] apply_reflector;
    input [4:0] in;
    begin
        case(in)
        //YRUHQSLDPXNGOKMIEBFZCWVJAT
        // REFLECTOR
            5'd0  : apply_reflector = 5'd24; // a -> y
            5'd1  : apply_reflector = 5'd17; // b -> r
            5'd2  : apply_reflector = 5'd20; // c -> u
            5'd3  : apply_reflector = 5'd7;  // d -> h
            5'd4  : apply_reflector = 5'd16; // e -> q
            5'd5  : apply_reflector = 5'd18; // f -> s
            5'd6  : apply_reflector = 5'd11; // g -> l
            5'd7  : apply_reflector = 5'd3;  // h -> d
            5'd8  : apply_reflector = 5'd15; // i -> p
            5'd9  : apply_reflector = 5'd23; // j -> x
            5'd10 : apply_reflector = 5'd13; // k -> n
            5'd11 : apply_reflector = 5'd6;  // l -> g
            5'd12 : apply_reflector = 5'd14; // m -> o
            5'd13 : apply_reflector = 5'd10; // n -> k
            5'd14 : apply_reflector = 5'd12; // o -> m
            5'd15 : apply_reflector = 5'd8;  // p -> i
            5'd16 : apply_reflector = 5'd4;  // q -> e
            5'd17 : apply_reflector = 5'd1;  // r -> b
            5'd18 : apply_reflector = 5'd5;  // s -> f
            5'd19 : apply_reflector = 5'd25; // t -> z
            5'd20 : apply_reflector = 5'd2;  // u -> c
            5'd21 : apply_reflector = 5'd22; // v -> w
            5'd22 : apply_reflector = 5'd21; // w -> v
            5'd23 : apply_reflector = 5'd9;  // x -> j
            5'd24 : apply_reflector = 5'd0;  // y -> a
            5'd25 : apply_reflector = 5'd19; // z -> t
            default : apply_reflector = in;
        endcase
    end
    endfunction

    // Inverse LUTs for Rotors I to V
    
    function [4:0] I_inv;
    input [4:0] in;
    begin
        case(in)
        // ROTOR 1 (Inverse)
            5'd0  : I_inv = 5'd20; // a -> u
            5'd1  : I_inv = 5'd22; // b -> w
            5'd2  : I_inv = 5'd24; // c -> y
            5'd3  : I_inv = 5'd6;  // d -> g
            5'd4  : I_inv = 5'd0;  // e -> a
            5'd5  : I_inv = 5'd3;  // f -> d
            5'd6  : I_inv = 5'd5;  // g -> f
            5'd7  : I_inv = 5'd15; // h -> p
            5'd8  : I_inv = 5'd21; // i -> v
            5'd9  : I_inv = 5'd25; // j -> z
            5'd10 : I_inv = 5'd1;  // k -> b
            5'd11 : I_inv = 5'd4;  // l -> e
            5'd12 : I_inv = 5'd2;  // m -> c
            5'd13 : I_inv = 5'd10; // n -> k
            5'd14 : I_inv = 5'd12; // o -> m
            5'd15 : I_inv = 5'd19; // p -> t
            5'd16 : I_inv = 5'd7;  // q -> h
            5'd17 : I_inv = 5'd23; // r -> x
            5'd18 : I_inv = 5'd18; // s -> s
            5'd19 : I_inv = 5'd11; // t -> l
            5'd20 : I_inv = 5'd17; // u -> r
            5'd21 : I_inv = 5'd8;  // v -> i
            5'd22 : I_inv = 5'd13; // w -> n
            5'd23 : I_inv = 5'd16; // x -> q
            5'd24 : I_inv = 5'd14; // y -> o
            5'd25 : I_inv = 5'd9;  // z -> j
            default : I_inv = in;
        endcase
    end
    endfunction
    
    function [4:0] II_inv;
    input [4:0] in;
    begin
        case(in)
        // ROTOR 2 (Inverse)
            5'd0  : II_inv = 5'd0;  // a -> a
            5'd1  : II_inv = 5'd9;  // b -> j
            5'd2  : II_inv = 5'd15; // c -> p
            5'd3  : II_inv = 5'd2;  // d -> c
            5'd4  : II_inv = 5'd25; // e -> z
            5'd5  : II_inv = 5'd22; // f -> w
            5'd6  : II_inv = 5'd17; // g -> r
            5'd7  : II_inv = 5'd11; // h -> l
            5'd8  : II_inv = 5'd5;  // i -> f
            5'd9  : II_inv = 5'd1;  // j -> b
            5'd10 : II_inv = 5'd3;  // k -> d
            5'd11 : II_inv = 5'd10; // l -> k
            5'd12 : II_inv = 5'd14; // m -> o
            5'd13 : II_inv = 5'd19; // n -> t
            5'd14 : II_inv = 5'd24; // o -> y
            5'd15 : II_inv = 5'd20; // p -> u
            5'd16 : II_inv = 5'd16; // q -> q
            5'd17 : II_inv = 5'd6;  // r -> g
            5'd18 : II_inv = 5'd4;  // s -> e
            5'd19 : II_inv = 5'd13; // t -> n
            5'd20 : II_inv = 5'd7;  // u -> h
            5'd21 : II_inv = 5'd23; // v -> x
            5'd22 : II_inv = 5'd12; // w -> m
            5'd23 : II_inv = 5'd8;  // x -> i
            5'd24 : II_inv = 5'd21; // y -> v
            5'd25 : II_inv = 5'd18; // z -> s
            default : II_inv = in;
        endcase
    end 
    endfunction

    function [4:0] III_inv;
    input [4:0] in;
    begin
        case(in)
        // ROTOR 3 (Inverse)
            5'd0  : III_inv = 5'd19; // a -> t
            5'd1  : III_inv = 5'd0;  // b -> a
            5'd2  : III_inv = 5'd6;  // c -> g
            5'd3  : III_inv = 5'd1;  // d -> b
            5'd4  : III_inv = 5'd15; // e -> p
            5'd5  : III_inv = 5'd2;  // f -> c
            5'd6  : III_inv = 5'd18; // g -> s
            5'd7  : III_inv = 5'd3;  // h -> d
            5'd8  : III_inv = 5'd16; // i -> q
            5'd9  : III_inv = 5'd4;  // j -> e
            5'd10 : III_inv = 5'd20; // k -> u
            5'd11 : III_inv = 5'd5;  // l -> f
            5'd12 : III_inv = 5'd21; // m -> v
            5'd13 : III_inv = 5'd13; // n -> n
            5'd14 : III_inv = 5'd25; // o -> z
            5'd15 : III_inv = 5'd7;  // p -> h
            5'd16 : III_inv = 5'd24; // q -> y
            5'd17 : III_inv = 5'd8;  // r -> i
            5'd18 : III_inv = 5'd23; // s -> x
            5'd19 : III_inv = 5'd9;  // t -> j
            5'd20 : III_inv = 5'd22; // u -> w
            5'd21 : III_inv = 5'd11; // v -> l
            5'd22 : III_inv = 5'd17; // w -> r
            5'd23 : III_inv = 5'd10; // x -> k
            5'd24 : III_inv = 5'd14; // y -> o
            5'd25 : III_inv = 5'd12; // z -> m
            default : III_inv = in;
        endcase
    end
    endfunction

    function [4:0] IV_inv;
    input [4:0] in;
    begin
        case(in)
        // ROTOR 4 (Inverse)
            5'd0  : IV_inv = 5'd7;  // a -> h
            5'd1  : IV_inv = 5'd25; // b -> z
            5'd2  : IV_inv = 5'd22; // c -> w
            5'd3  : IV_inv = 5'd21; // d -> v
            5'd4  : IV_inv = 5'd0;  // e -> a
            5'd5  : IV_inv = 5'd17; // f -> r
            5'd6  : IV_inv = 5'd19; // g -> t
            5'd7  : IV_inv = 5'd13; // h -> n
            5'd8  : IV_inv = 5'd11; // i -> l
            5'd9  : IV_inv = 5'd6;  // j -> g
            5'd10 : IV_inv = 5'd20; // k -> u
            5'd11 : IV_inv = 5'd15; // l -> p
            5'd12 : IV_inv = 5'd23; // m -> x
            5'd13 : IV_inv = 5'd16; // n -> q
            5'd14 : IV_inv = 5'd2;  // o -> c
            5'd15 : IV_inv = 5'd4;  // p -> e
            5'd16 : IV_inv = 5'd9;  // q -> j
            5'd17 : IV_inv = 5'd12; // r -> m
            5'd18 : IV_inv = 5'd1;  // s -> b
            5'd19 : IV_inv = 5'd18; // t -> s
            5'd20 : IV_inv = 5'd10; // u -> k
            5'd21 : IV_inv = 5'd3;  // v -> d
            5'd22 : IV_inv = 5'd24; // w -> y
            5'd23 : IV_inv = 5'd14; // x -> o
            5'd24 : IV_inv = 5'd8;  // y -> i
            5'd25 : IV_inv = 5'd5;  // z -> f
            default : IV_inv = in;
        endcase
    end
    endfunction

    function [4:0] V_inv;
    input [4:0] in;
    begin
        case(in)
        // ROTOR 5 (Inverse)
            5'd0  : V_inv = 5'd16; // a -> q
            5'd1  : V_inv = 5'd2;  // b -> c
            5'd2  : V_inv = 5'd24; // c -> y
            5'd3  : V_inv = 5'd11; // d -> l
            5'd4  : V_inv = 5'd23; // e -> x
            5'd5  : V_inv = 5'd22; // f -> w
            5'd6  : V_inv = 5'd4;  // g -> e
            5'd7  : V_inv = 5'd13; // h -> n
            5'd8  : V_inv = 5'd5;  // i -> f
            5'd9  : V_inv = 5'd19; // j -> t
            5'd10 : V_inv = 5'd25; // k -> z
            5'd11 : V_inv = 5'd14; // l -> o
            5'd12 : V_inv = 5'd18; // m -> s
            5'd13 : V_inv = 5'd12; // n -> m
            5'd14 : V_inv = 5'd21; // o -> v
            5'd15 : V_inv = 5'd9;  // p -> j
            5'd16 : V_inv = 5'd20; // q -> u
            5'd17 : V_inv = 5'd3;  // r -> d
            5'd18 : V_inv = 5'd10; // s -> k
            5'd19 : V_inv = 5'd6;  // t -> g
            5'd20 : V_inv = 5'd8;  // u -> i
            5'd21 : V_inv = 5'd0;  // v -> a
            5'd22 : V_inv = 5'd17; // w -> r
            5'd23 : V_inv = 5'd15; // x -> p
            5'd24 : V_inv = 5'd7;  // y -> h
            5'd25 : V_inv = 5'd1;  // z -> b
            default : V_inv = in;
        endcase
    end
    endfunction

	// add and subtract with loop so 25 and 0 are connected (e.g. 0-1 = 25)
	function [4:0] mod26_add;
		input [4:0] a;
		input [4:0] b;
		reg   [5:0] s;
		begin
			s = {1'b0, a} + {1'b0, b}; // 0 to 50
			
			if (s >= 6'd26) begin
				mod26_add = s - 6'd26;
			end else begin
				mod26_add = s[4:0];
			end
		end
	endfunction

	function [4:0] mod26_sub;
		input [4:0] a;
		input [4:0] b;
		reg   [5:0] d;
		begin
			d = {1'b0, a} + 6'd26 - {1'b0, b}; // 1 to 51
			if (d >= 6'd26) begin
				mod26_sub = d - 6'd26;
			end else begin
				mod26_sub = d[4:0];
			end
		end
	endfunction

	function [4:0] apply_rotor;
		input [2:0] sel;
		input [4:0] in;
        begin
            case (sel)
                3'b000: apply_rotor = I(in);
                3'b001: apply_rotor = II(in);
                3'b010: apply_rotor = III(in);
                3'b011: apply_rotor = IV(in);
                3'b100: apply_rotor = V(in);
                default: apply_rotor = in;
			endcase
		end
	endfunction

		function [4:0] apply_rotor_inv;
		input [2:0] sel;
		input [4:0] in;
        begin
            case (sel)
                3'b000: apply_rotor_inv = I_inv(in);
                3'b001: apply_rotor_inv = II_inv(in);
                3'b010: apply_rotor_inv = III_inv(in);
                3'b011: apply_rotor_inv = IV_inv(in);
                3'b100: apply_rotor_inv = V_inv(in);
                default: apply_rotor_inv = in;
			endcase
		end
	endfunction

	// forward:  shift the contact index up by pos -> run the wiring LUT -> then shift the result back down by pos
	// inverse:  same structure is used in the inverse wiring LUT
	// index_in = (signal + pos) % 26
	// index_out = (LUT_output - pos + 26) % 26
	function [4:0] rotor_fwd;
		input [2:0] sel;
		input [4:0] idx;
		input [4:0] pos;
		begin
			rotor_fwd = mod26_sub(apply_rotor(sel, mod26_add(idx, pos)), pos);
		end
	endfunction

	function [4:0] rotor_inv;
		input [2:0] sel;
		input [4:0] idx;
		input [4:0] pos;
		begin
			rotor_inv = mod26_sub(apply_rotor_inv(sel, mod26_add(idx, pos)), pos);
		end
	endfunction

	// The middle rotor steps when it sits on its own notch OR when the right rotor is on its notch (double step sequence)

	function [4:0] notch_of;
		input [2:0] sel;
		begin
			case (sel)
				3'b000: notch_of = 5'd16;   // I   notch Q
				3'b001: notch_of = 5'd4;    // II  notch E
				3'b010: notch_of = 5'd21;   // III notch V
				3'b011: notch_of = 5'd9;    // IV  notch J
				3'b100: notch_of = 5'd25;   // V   notch Z
				default: notch_of = 5'd26;  // no notch
			endcase
		end
	endfunction


	// ---------------- combinational signal path ------------------------
	wire [4:0] w1, w2, w3, wr, w4, w5, w6;

	assign w1 = rotor_fwd(slot1_sel, in, pos1);   // right rotor, forward
	assign w2 = rotor_fwd(slot2_sel, w1, pos2);   // middle rotor, forward
	assign w3 = rotor_fwd(slot3_sel, w2, pos3);   // left rotor, forward
	assign wr = apply_reflector(w3);              // reflector turnaround
	assign w4 = rotor_inv(slot3_sel, wr, pos3);   // left rotor, return
	assign w5 = rotor_inv(slot2_sel, w4, pos2);   // middle rotor, return
	assign w6 = rotor_inv(slot1_sel, w5, pos1);   // right rotor, return

	reg [7:0] uo_out_r;
	always @(*) begin
		if (letterOk) begin
			uo_out_r = {3'b000, w6};          // valid letter: rotor result
		end else begin
			uo_out_r = {3'b000, ui_in[4:0]};  // non-letter: pass through
		end
	end
	assign uo_out = uo_out_r;
	
	// ---------------- rotor stepping -----------------------------------
	wire notch1 = (pos1 == notch_of(slot1_sel));
	wire notch2 = (pos2 == notch_of(slot2_sel));

	wire step1 = ena & letterOk;               // right rotor turns every key
	wire step2 = step1 & (notch1 | notch2);  // middle: notched OR double-step
	wire step3 = step1 & notch2;             // left rotor follows the middle

	always @(posedge clk) begin
		if (!rst_n) begin
			pos1 <= 5'd0;
			pos2 <= 5'd0;
			pos3 <= 5'd0;
		end
		else if (configDone) begin
			// A complete config word has just been written: start the
			// rotors from the positions it holds, masked to 0-25.
			pos1 <= (configReg[13:9]  < 5'd26) ? configReg[13:9]  : 5'd0;
			pos2 <= (configReg[18:14] < 5'd26) ? configReg[18:14] : 5'd0;
			pos3 <= (configReg[23:19] < 5'd26) ? configReg[23:19] : 5'd0;
		end
		else begin
			if (step1) pos1 <= (pos1 == 5'd25) ? 5'd0 : pos1 + 5'd1;
			if (step2) pos2 <= (pos2 == 5'd25) ? 5'd0 : pos2 + 5'd1;
			if (step3) pos3 <= (pos3 == 5'd25) ? 5'd0 : pos3 + 5'd1;
		end
	end

	// Tie off the unused bidirectional pins. Leaving uio_oe/uio_out
	// undriven makes Yosys 'check' report 16 undriven-bit errors
	// (8 bits each) and fails the flow at the Synth Checks stage.
	assign uio_oe  = 8'b0000_0000;
	assign uio_out = 8'b0000_0000;

endmodule
