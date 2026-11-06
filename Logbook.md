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
