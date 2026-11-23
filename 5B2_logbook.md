# 1/11/26 & 2/11/26
Iterated through designs on an notepad to answer these questions (answers given in italics):
- what inputs are required to for configuration and letter coding

*inputs are letter (5bits 26 letters); rotor selection (3bits per rotor choose 3 out of 5) initial position (5bits per rotor); plugboard (10bits per connection using up to 10 letter links).*
*As for the regular input, each letter would need 5bits (to encode 26 letters) looking at these numbers, it seems that a 32bit input would be ideal*

*Input Configuration: first 32b:3+3+3+5+5+5+6+1+1 as Rotors 1,2&3 + Rotor Position 1,2&3, 6b empty + config bit + concatenate bit
second 32b:5+5+5+5+5+5+1+1 as Notch position: 1,2&3 + plugboard letter 1&2 + 5 empty + config bit + concatenate bit
nth 32b:5+5+5+5+5+5+1+1 as plugboard letter 1&2 + plugboard letter 1&2, plugboard letter 1&2 + config + concatenate bit*

- what elements make up the enigma machine?
  
*consists of the following statemachine: input letter -> plugboard -> Rotor 1->2->3 -> reflector -> reverse rotor order 3->2->1 -> plugboard -> output*

  - and what elements can I include in my first iteration?
    
*I can include the rotors to encode the letter with only the rotor selection configuration option. Then check how much space this would take up and continue working on expanding it.*

# 6/11/26
I created a testbench to test the code I have written, to make sure that all the code is running properly. Testing out the rotors and the rotor configuration, checking the output and the individual flops that store the data. 
Synthesised the design using librelane, and ran into some problems with this. Need to look at this further.

# 11/11/26
I fixed the issue, as it need some initialised values for some of the wires. After synthesis, I checked the area utilisation which was around 0.4. I did notice errors regarding slew, which doesn't seem to interferer with the programming and will fix this in the future.

I implemented the reflector as a LUT and implemented this into the design, like the other rotors. For the rotor inverse, I coded in more LUTs as it makes visualising and coding easier, but will need to change this in the future to optimise for area. I updated the testbench to check that the rotors are moving through the system correctly and match the expected outputs.

I spent a long time trying te design and and implement a system that increments the rotor by 1 after every key press, like the real enigma machine. As these are all using LUTs, I need to index the LUTs differently and include an offset with my binary encoded letter. I found that the equation (given below) allow this to work using the existing LUT method. I implemented this but am yet to check it.
$$Index_{fwd}=(input+pos)$$
$$Index_{inv}=(LUT(Index_{fwd})-pos)$$

# 14/11/26
Implemented the equation from before, and updated the testbench to test that it worked. It worked in simulation. I fixed some other small bugs that I missed last time, with typos in the binary.

I added a separate add and subtract function that rolls over back to 25, implemented the notch position rotating the second rotor and third rotor when needed, accounting for the double shift. Created a check to make sure the input is not over 26 as this would not work in the LUT.

There is a space limitation now, which stops me synthesising the design. Optimisations need to be made to the tables to allow for placement. My first idea is to somehow reuse the LUTs for the inverse.

Another error crept up when I tried to upload the design to github. The inputs ui_in and uio_in are both restricted to being 8 bits long, I will have to find a way to reduce this length.

# 15/11/26
I fixed the issue with the input being too long. I created a register that loads values into it over 3 clock cycles to write the configuration 3 times (total 24 bits: 15 bits for initial rotor position and 9 bits for rotor selection).

The next optimisation was to reduce redundancy by removing the extra LUTs, the method I used to implement this is by iterating over the existing LUTs to look for the target letter and store the input. However, this implementation caused the system to expand even further from 103% to 127%. 

# 16/11/26

I have fixed the overutilisation issue with my design. After reading more about how functions work, I understood that the LUTs were rebuilt every time the function was called as I was not waiting for a clock signal. This also explains why when I removed the reverse LUTs and replaced it with a module that goes through each element in the LUT, it increased the area. To fix this, I implemented a clocked sequence that steps through each rotor using a clock which also allows for better clock distribution with a lower critical path time.

This implementation was followed by an update to the testbench to allow for accurate checking with the new output clock timings. This now only uses 59% of the area as a significant improvement of 48%.

# 23/11/26
I am reworking the code to fix bugs and make it easier to read/edit. I have made a new header file .vh to store all the LUTs which will be used, but won't need to be changed as they are constant. I have fixed the issue of the stages starting on 1 rather 0. I have fixed the issue of the input being read multiple times and have implemented a read once block that checks parameters:
-> `wire go = trig & ena & config_loaded & (state == IDLE);` this checks for (strobe rising edge, if its enabled, if config bytes are loaded, if its not currently encrypting)
This helps prevent encryption before config is loaded, new characters being accepted before old ones are in progress, 

The 2 states are IDLE and ROT where the state machine is either in IDLE where the values are stored in result or before any encryption, or with ROT where the values are being propagated through the rotors where the values are being encrypted through rotor1->rotor2->rotor3->reflector->inv_rotor3->inv_rotor2->inv_rotor1. 

Both these changes reduced some redundancy and reduced my overall utilisation down to 54.7%.

Expanded the testbench to run standardised tests for the enigma machine with different rotor initial conditions and rotor configurations. Inputting A and seeing the change in the letter and comparing this to the expected values. Testing values between rotor and final values. I also tested edge cases where the numbers roll over from A->Z or vice versa through modulo addation and subtraction, and testing the double notch step where the notch of rotor 1 and 2 are trigged making the rotor rotate twice.
