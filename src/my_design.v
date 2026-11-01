// input config1 32b = 3b(rotor I) + 3b(rotor II) + 3b(rotor III) + 
    //                     3b(rotor pos) + 5b(rotor pos) + 5b(rotor pos) + 6b(empty) +1b(is it config?) + 1b(is there more config?)
    // input config2 32b = 5b(notch I) + 5b(notch II) + 5b(notch III) + 
    //                     5b(plug 1) + 5b(plug 1) + + 1b(is it config?) + 1b(more?)
    // input config3 32b = 5b(plug 2) + 5b(plug 2) + 5b(plug 3) + 5b(plug 3) 
    //                     5b(plug 4) + 5b(plug 4) + 1b(is it config?) + 1b(more?)
    // repeat config3 structure till plug 8

    // input op 32b = 5b(letter) + 5b(letter) + 5b(letter) + 5b(letter) + 5b(letter) + 5b(letter) + 1b(is it config?) + 1b(more?)




module tt_um_ninzaninja1_ied_coursework (
    input  wire [7:0] ui_in, uio_in, // letter to code
	input  wire clk, rst_n, ena,
	output wire [7:0] uo_out, uio_oe, uio_out // letter output after rotors
);

	wire [15:0] rotors_sel, // selecting which rotors and in which order
	reg [4:0] out1, out2, out3;
	wire [2:0] slot1_sel, slot2_sel, slot3_sel;

	// select the rotors and order of rotors
	assign slot1_sel = rotor_sel[2:0]
	assign slot2_sel = rotor_sel[5:3]
	assign slot3_sel = rotor_sel[8:6]

	always @(*) begin
  	case (slot1_sel)
    	2'b000 : out1 = I;
    	2'b001 : out1 = II;
    	2'b010 : out1 = III;
    	2'b011 : out1 = IV;
		2'b100 : out1 = V;
		default: out1 = 5'b00000
  	endcase

  	case (slot2_sel)
    	2'b000 : out2 = I;
    	2'b001 : out2 = II;
    	2'b010 : out2 = III;
    	2'b011 : out2 = IV;
		2'b100 : out2 = V;
		default: out2 = 5'b00000
  	endcase

  	case (slot3_sel)
    	2'b000 : out3 = I;
    	2'b001 : out3 = II;
    	2'b010 : out3 = III;
    	2'b011 : out3 = IV;
		2'b100 : out3 = V;
		default: out3 = 5'b00000
  	endcase
	end
    // LUT
    always @(*) begin
    case(in)
    //EKMFLGDQVZNTOWYHXUSPAIBRCJ
	// ROTOR 1
		5'b00000 : I = 5'b00100; // a -> e
		5'b00001 : I = 5'b01010; // b -> k
		5'b00010 : I = 5'b01100; // c -> m
		5'b00011 : I = 5'b00101; // d -> f
		5'b00100 : I = 5'b01011; // e -> l
		5'b00101 : I = 5'b00110; // f -> g
		5'b00110 : I = 5'b00011; // g -> d
		5'b00111 : I = 5'b10000; // h -> q
		5'b01000 : I = 5'b10101; // i -> v
		5'b01001 : I = 5'b11001; // j -> z
		5'b01010 : I = 5'b01101; // k -> n
		5'b01011 : I = 5'b10011; // l -> t
		5'b01100 : I = 5'b01110; // m -> o
		5'b01101 : I = 5'b10110; // n -> w
		5'b01110 : I = 5'b11000; // o -> y
		5'b01111 : I = 5'b00111; // p -> h
		5'b10000 : I = 5'b10111; // q -> x
		5'b10001 : I = 5'b10100; // r -> u
		5'b10010 : I = 5'b10010; // s -> s
		5'b10011 : I = 5'b01111; // t -> p
		5'b10100 : I = 5'b00000; // u -> a
		5'b10101 : I = 5'b01000; // v -> i
		5'b10110 : I = 5'b00001; // w -> b
		5'b10111 : I = 5'b10001; // x -> r
		5'b11000 : I = 5'b00010; // y -> c
		5'b11001 : I = 5'b01001; // z -> j
	endcase
	
	case(in)
	//AJDKSIRUXBLHWTMCQGZNPYFVOE
	// ROTOR 2
		5'b00000 : II = 5'b00000; // a -> a
		5'b00001 : II = 5'b01001; // b -> j
    	5'b00010 : II = 5'b00011; // c -> d
    	5'b00011 : II = 5'b01010; // d -> k
    	5'b00100 : II = 5'b10010; // e -> s
    	5'b00101 : II = 5'b01000; // f -> i
    	5'b00110 : II = 5'b10001; // g -> r
    	5'b00111 : II = 5'b10100; // h -> u
    	5'b01000 : II = 5'b10111; // i -> x
    	5'b01001 : II = 5'b00001; // j -> b
    	5'b01010 : II = 5'b01011; // k -> l
    	5'b01011 : II = 5'b00111; // l -> h
    	5'b01100 : II = 5'b10110; // m -> w
    	5'b01101 : II = 5'b10011; // n -> t
    	5'b01110 : II = 5'b01100; // o -> m
    	5'b01111 : II = 5'b00010; // p -> c
    	5'b10000 : II = 5'b10000; // q -> q
    	5'b10001 : II = 5'b00110; // r -> g
    	5'b10010 : II = 5'b11001; // s -> z
    	5'b10011 : II = 5'b01101; // t -> n
    	5'b10100 : II = 5'b01111; // u -> p
    	5'b10101 : II = 5'b11000; // v -> y
    	5'b10110 : II = 5'b00101; // w -> f
    	5'b10111 : II = 5'b10101; // x -> v
    	5'b11000 : II = 5'b01110; // y -> o
    	5'b11001 : II = 5'b00100; // z -> e
	endcase

	case(in)
	//BDFHJLCPRTXVZNYEIWGAKMUSQO
	// ROTOR 3
		5'b00000 : III = 5'b00001; // a -> b
		5'b00001 : III = 5'b00011; // b -> d
		5'b00010 : III = 5'b00101; // c -> f
		5'b00011 : III = 5'b00111; // d -> h
		5'b00100 : III = 5'b01001; // e -> j
		5'b00101 : III = 5'b01011; // f -> l
		5'b00110 : III = 5'b00010; // g -> c
		5'b00111 : III = 5'b01111; // h -> p
		5'b01000 : III = 5'b10001; // i -> r
		5'b01001 : III = 5'b10011; // j -> t
		5'b01010 : III = 5'b10111; // k -> x
		5'b01011 : III = 5'b10101; // l -> v
		5'b01100 : III = 5'b11001; // m -> z
		5'b01101 : III = 5'b01101; // n -> n
		5'b01110 : III = 5'b11000; // o -> y
		5'b01111 : III = 5'b00100; // p -> e
		5'b10000 : III = 5'b01000; // q -> i
		5'b10001 : III = 5'b10110; // r -> w
		5'b10010 : III = 5'b00110; // s -> g
		5'b10011 : III = 5'b00000; // t -> a
		5'b10100 : III = 5'b01010; // u -> k
		5'b10101 : III = 5'b01100; // v -> m
		5'b10110 : III = 5'b10100; // w -> u
		5'b10111 : III = 5'b10010; // x -> s
		5'b11000 : III = 5'b10000; // y -> q
		5'b11001 : III = 5'b01110; // z -> o
	endcase

	case(in)
	//ESOVPZJAYQUIRHXLNFTGKDCMWB
	// ROTOR 4
		5'b00000 : IV = 5'b00100; // a -> e
    	5'b00001 : IV = 5'b10010; // b -> s
    	5'b00010 : IV = 5'b01110; // c -> o
    	5'b00011 : IV = 5'b10101; // d -> v
    	5'b00100 : IV = 5'b01111; // e -> p
    	5'b00101 : IV = 5'b11001; // f -> z
    	5'b00110 : IV = 5'b01001; // g -> j
    	5'b00111 : IV = 5'b00000; // h -> a
    	5'b01000 : IV = 5'b11000; // i -> y
    	5'b01001 : IV = 5'b10000; // j -> q
    	5'b01010 : IV = 5'b10100; // k -> u
    	5'b01011 : IV = 5'b01000; // l -> i
    	5'b01100 : IV = 5'b10001; // m -> r
    	5'b01101 : IV = 5'b00111; // n -> h
    	5'b01110 : IV = 5'b10111; // o -> x
    	5'b01111 : IV = 5'b01011; // p -> l
    	5'b10000 : IV = 5'b01101; // q -> n
    	5'b10001 : IV = 5'b00101; // r -> f
    	5'b10010 : IV = 5'b10011; // s -> t
    	5'b10011 : IV = 5'b00110; // t -> g
    	5'b10100 : IV = 5'b01010; // u -> k
    	5'b10101 : IV = 5'b00011; // v -> d
    	5'b10110 : IV = 5'b00010; // w -> c
    	5'b10111 : IV = 5'b01100; // x -> m
    	5'b11000 : IV = 5'b10110; // y -> w
    	5'b11001 : IV = 5'b00001; // z -> b
	endcase

	case(in)
	//VZBRGITYUPSDNHLXAWMJQOFECK
	// ROTOR 5
		5'b00000 : V = 5'b10101; // a -> v
    	5'b00001 : V = 5'b11001; // b -> z
    	5'b00010 : V = 5'b00001; // c -> b
    	5'b00011 : V = 5'b10001; // d -> r
    	5'b00100 : V = 5'b00110; // e -> g
    	5'b00101 : V = 5'b01000; // f -> i
    	5'b00110 : V = 5'b10011; // g -> t
    	5'b00111 : V = 5'b11000; // h -> y
    	5'b01000 : V = 5'b10100; // i -> u
    	5'b01001 : V = 5'b01111; // j -> p
    	5'b01010 : V = 5'b10010; // k -> s
    	5'b01011 : V = 5'b00011; // l -> d
    	5'b01100 : V = 5'b01101; // m -> n
    	5'b01101 : V = 5'b00111; // n -> h
    	5'b01110 : V = 5'b01011; // o -> l
    	5'b01111 : V = 5'b10111; // p -> x
    	5'b10000 : V = 5'b00000; // q -> a
    	5'b10001 : V = 5'b10110; // r -> w
    	5'b10010 : V = 5'b01100; // s -> m
    	5'b10011 : V = 5'b01001; // t -> j
    	5'b10100 : V = 5'b10000; // u -> q
    	5'b10101 : V = 5'b01110; // v -> o
    	5'b10110 : V = 5'b00101; // w -> f
    	5'b10111 : V = 5'b00100; // x -> e
    	5'b11000 : V = 5'b00010; // y -> c
    	5'b11001 : V = 5'b01010; // z -> k
	endcase

	end

endmodule
