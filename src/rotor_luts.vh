// =============================================================================
//  rotor_luts.vh
//  Enigma M3 rotor, reflector and notch lookup tables.
//
//  Pulled into my_design.v with:
//      `include "rotor_luts.vh"
//  placed INSIDE the my_design module body, so every function below becomes a
//  module-local function of my_design.
//
//  Do NOT add this file to VERILOG_FILES - it is not a compilation unit of its
//  own, it is textually included by my_design.v.
// =============================================================================

// --------------------- Forward rotor wirings ------------------------

    function [4:0] I;
    input [4:0] lut_in;
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
            default : I = lut_in;
        endcase
    end
    endfunction

    function [4:0] II;
    input [4:0] lut_in;
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
            default : II = lut_in;
        endcase
    end 
    endfunction

    function [4:0] III;
    input [4:0] lut_in;
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
            default : III = lut_in;
        endcase
    end
    endfunction

    function [4:0] IV;
    input [4:0] lut_in;
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
            default : IV = lut_in;
        endcase
    end
    endfunction

    function [4:0] V;
    input [4:0] lut_in;
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
            default : V = lut_in;
        endcase
    end
    endfunction


    function [4:0] apply_reflector;
    input [4:0] lut_in;
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
            default : apply_reflector = lut_in;
        endcase
    end
    endfunction

// --------------------- Inverse rotor wirings ------------------------

	function [4:0] I_inv;
	input [4:0] lut_in;
	begin
		case (in)
			5'd0  : I_inv = 5'd20;
			5'd1  : I_inv = 5'd22;
			5'd2  : I_inv = 5'd24;
			5'd3  : I_inv = 5'd6;
			5'd4  : I_inv = 5'd0;
			5'd5  : I_inv = 5'd3;
			5'd6  : I_inv = 5'd5;
			5'd7  : I_inv = 5'd15;
			5'd8  : I_inv = 5'd21;
			5'd9  : I_inv = 5'd25;
			5'd10 : I_inv = 5'd1;
			5'd11 : I_inv = 5'd4;
			5'd12 : I_inv = 5'd2;
			5'd13 : I_inv = 5'd10;
			5'd14 : I_inv = 5'd12;
			5'd15 : I_inv = 5'd19;
			5'd16 : I_inv = 5'd7;
			5'd17 : I_inv = 5'd23;
			5'd18 : I_inv = 5'd18;
			5'd19 : I_inv = 5'd11;
			5'd20 : I_inv = 5'd17;
			5'd21 : I_inv = 5'd8;
			5'd22 : I_inv = 5'd13;
			5'd23 : I_inv = 5'd16;
			5'd24 : I_inv = 5'd14;
			5'd25 : I_inv = 5'd9;
			default: I_inv = lut_in;
		endcase
	end
	endfunction

	function [4:0] II_inv;
	input [4:0] lut_in;
	begin
		case (in)
			5'd0  : II_inv = 5'd0;
			5'd1  : II_inv = 5'd9;
			5'd2  : II_inv = 5'd15;
			5'd3  : II_inv = 5'd2;
			5'd4  : II_inv = 5'd25;
			5'd5  : II_inv = 5'd22;
			5'd6  : II_inv = 5'd17;
			5'd7  : II_inv = 5'd11;
			5'd8  : II_inv = 5'd5;
			5'd9  : II_inv = 5'd1;
			5'd10 : II_inv = 5'd3;
			5'd11 : II_inv = 5'd10;
			5'd12 : II_inv = 5'd14;
			5'd13 : II_inv = 5'd19;
			5'd14 : II_inv = 5'd24;
			5'd15 : II_inv = 5'd20;
			5'd16 : II_inv = 5'd16;
			5'd17 : II_inv = 5'd6;
			5'd18 : II_inv = 5'd4;
			5'd19 : II_inv = 5'd13;
			5'd20 : II_inv = 5'd7;
			5'd21 : II_inv = 5'd23;
			5'd22 : II_inv = 5'd12;
			5'd23 : II_inv = 5'd8;
			5'd24 : II_inv = 5'd21;
			5'd25 : II_inv = 5'd18;
			default: II_inv = lut_in;
		endcase
	end
	endfunction

	function [4:0] III_inv;
	input [4:0] lut_in;
	begin
		case (in)
			5'd0  : III_inv = 5'd19;
			5'd1  : III_inv = 5'd0;
			5'd2  : III_inv = 5'd6;
			5'd3  : III_inv = 5'd1;
			5'd4  : III_inv = 5'd15;
			5'd5  : III_inv = 5'd2;
			5'd6  : III_inv = 5'd18;
			5'd7  : III_inv = 5'd3;
			5'd8  : III_inv = 5'd16;
			5'd9  : III_inv = 5'd4;
			5'd10 : III_inv = 5'd20;
			5'd11 : III_inv = 5'd5;
			5'd12 : III_inv = 5'd21;
			5'd13 : III_inv = 5'd13;
			5'd14 : III_inv = 5'd25;
			5'd15 : III_inv = 5'd7;
			5'd16 : III_inv = 5'd24;
			5'd17 : III_inv = 5'd8;
			5'd18 : III_inv = 5'd23;
			5'd19 : III_inv = 5'd9;
			5'd20 : III_inv = 5'd22;
			5'd21 : III_inv = 5'd11;
			5'd22 : III_inv = 5'd17;
			5'd23 : III_inv = 5'd10;
			5'd24 : III_inv = 5'd14;
			5'd25 : III_inv = 5'd12;
			default: III_inv = lut_in;
		endcase
	end
	endfunction

	function [4:0] IV_inv;
	input [4:0] lut_in;
	begin
		case (in)
			5'd0  : IV_inv = 5'd7;
			5'd1  : IV_inv = 5'd25;
			5'd2  : IV_inv = 5'd22;
			5'd3  : IV_inv = 5'd21;
			5'd4  : IV_inv = 5'd0;
			5'd5  : IV_inv = 5'd17;
			5'd6  : IV_inv = 5'd19;
			5'd7  : IV_inv = 5'd13;
			5'd8  : IV_inv = 5'd11;
			5'd9  : IV_inv = 5'd6;
			5'd10 : IV_inv = 5'd20;
			5'd11 : IV_inv = 5'd15;
			5'd12 : IV_inv = 5'd23;
			5'd13 : IV_inv = 5'd16;
			5'd14 : IV_inv = 5'd2;
			5'd15 : IV_inv = 5'd4;
			5'd16 : IV_inv = 5'd9;
			5'd17 : IV_inv = 5'd12;
			5'd18 : IV_inv = 5'd1;
			5'd19 : IV_inv = 5'd18;
			5'd20 : IV_inv = 5'd10;
			5'd21 : IV_inv = 5'd3;
			5'd22 : IV_inv = 5'd24;
			5'd23 : IV_inv = 5'd14;
			5'd24 : IV_inv = 5'd8;
			5'd25 : IV_inv = 5'd5;
			default: IV_inv = lut_in;
		endcase
	end
	endfunction

	function [4:0] V_inv;
	input [4:0] lut_in;
	begin
		case (in)
			5'd0  : V_inv = 5'd16;
			5'd1  : V_inv = 5'd2;
			5'd2  : V_inv = 5'd24;
			5'd3  : V_inv = 5'd11;
			5'd4  : V_inv = 5'd23;
			5'd5  : V_inv = 5'd22;
			5'd6  : V_inv = 5'd4;
			5'd7  : V_inv = 5'd13;
			5'd8  : V_inv = 5'd5;
			5'd9  : V_inv = 5'd19;
			5'd10 : V_inv = 5'd25;
			5'd11 : V_inv = 5'd14;
			5'd12 : V_inv = 5'd18;
			5'd13 : V_inv = 5'd12;
			5'd14 : V_inv = 5'd21;
			5'd15 : V_inv = 5'd9;
			5'd16 : V_inv = 5'd20;
			5'd17 : V_inv = 5'd3;
			5'd18 : V_inv = 5'd10;
			5'd19 : V_inv = 5'd6;
			5'd20 : V_inv = 5'd8;
			5'd21 : V_inv = 5'd0;
			5'd22 : V_inv = 5'd17;
			5'd23 : V_inv = 5'd15;
			5'd24 : V_inv = 5'd7;
			5'd25 : V_inv = 5'd1;
			default: V_inv = lut_in;
		endcase
	end
	endfunction

// --------------------- Selectors & notch lookup ------------------------

    function [4:0] apply_rotor;
        input [2:0] sel;
        input [4:0] lut_in;
        begin
            case (sel)
                3'b000: apply_rotor = I(in);
                3'b001: apply_rotor = II(in);
                3'b010: apply_rotor = III(in);
                3'b011: apply_rotor = IV(in);
                3'b100: apply_rotor = V(in);
                default: apply_rotor = lut_in;
            endcase
        end
    endfunction

    function [4:0] apply_rotor_inv;
        input [2:0] sel;
        input [4:0] letter_out;
        begin
            case (sel)
                3'b000: apply_rotor_inv = I_inv(letter_out);
                3'b001: apply_rotor_inv = II_inv(letter_out);
                3'b010: apply_rotor_inv = III_inv(letter_out);
                3'b011: apply_rotor_inv = IV_inv(letter_out);
                3'b100: apply_rotor_inv = V_inv(letter_out);
                default: apply_rotor_inv = letter_out;
            endcase
        end
    endfunction

    function [4:0] notch_of;
        input [2:0] sel;
        begin
            case (sel)
                3'b000: notch_of = 5'd16; // I: Q
                3'b001: notch_of = 5'd4;  // II: E
                3'b010: notch_of = 5'd21; // III: V
                3'b011: notch_of = 5'd9;  // IV: J
                3'b100: notch_of = 5'd25; // V: Z
                default: notch_of = 5'd26;
            endcase
        end
    endfunction
