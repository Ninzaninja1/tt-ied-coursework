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

I spent a long time trying te design and and implement a system that increments the rotor by 1 after every key press, like the real enigma machine. As these are all using LUTs, I need to index the LUTs differently and include an offset with my binary encoded letter. I found that the equation 

For short expresions and not so fancy math you could use the inline HTML to get your latex rendered math on codecogs and then embed the resulting image. Here an example:
$$Index_{fwd}=(input+pos)$$
- <img src="https://latex.codecogs.com/png.latex?Index_{inv}=(LUT(Index_{fwd})-pos)" />
