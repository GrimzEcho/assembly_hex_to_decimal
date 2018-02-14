				
				AREA ascii_hex_to_signed_dec, CODE, READONLY
				ENTRY
				EXPORT main




main
	
	; Hexadecimal to signed decimal conversion
	;
	; Reads characters from the input string one at a time. Valid characters are (0-9), (a-f), and (A-F). All other characters are invalid.
	; For each valid character, use its position in the ASCII table to calculate a sutiable offset, such that the character code can be
	; used to obtain the true numberic value of the digit.
	;
	; Uses an efficient fast-divide alrogithm to get positional values of powers of 10.
	;
	; Since all input characters are hexedecimal, the aggregrate result can be found by multiplying each result by 4 and then adding the next result
	;
	;
	; Negative values are detected when (numberOf(symbols) == 8)  $$ (MSB(symbol) >= 8). A flag is set if this occurs
	
	; R1 = 

	;R1 = pointer to next input symbol
	;R2 = symbol
	;R3 = valid symbol counter
	;R4 = result
	;R5 = offset counter
	;R6 = temp
	;R7 = neg flag
	
	
;uncomment these lines to use fast_divide
;otherwise uses power_divide for more accuracy
;	LDR R1, =0x7FFFFFFF
;	PUSH {R1}
;	BL fast_div_by_ten
;	rslts are on the system stack
;	B quit;
	
	
	MOV R5, #0
	MOV R4, #0
	MOV R7, #0
	MOV R3, #0
	
	LDR R1, =hex_string					;load the pointer to the first character
	
main_loop_a
	LDRB R2, [R1], #1					;get the next symbol and increment the pointer
	
	;all characters processed
	CMP R2, #0
	BEQ end_of_input

	;char < ascii(0)
	CMP R2, #'0'
	BLT invalid_symbol
	
	;ascii(0) <= char <= ascii(9)
	CMP R2, #'9'
	ITT LE
		MOVLE R5, #'0'					;set the offset
		BLE valid_symbol
	
	;ascii(9) < char < ascii(A)
	CMP R2, #'A'
	BLT invalid_symbol
	
	;ascii(A) <= char <= ascii(F)
	CMP R2, #'F'
	ITTT LE
		MOVLE R5, #'A'
		SUBLE R5, R5, #10				;subtract 10 to get acurate value
		BLE valid_symbol
	
	;ascii(A) < char < ascii(a)	
	CMP R2, #'a'
	BLT invalid_symbol
	
	;ascii(a) <= char <= ascii(f)
	CMP R2, #'f'
		MOVLE R5, #'a'
		SUBLE R5, R5, #10
		BLE valid_symbol
		
	;else
	;ascii(f) < char
	
invalid_symbol
	LDR R1, =str_error
	LDR R2, =dec_string
	MOV R3, R1
invalid_loop_a
	CMP R3, #0
	BEQ quit
	STR R3, [R2], #1
	LDR R3, [R1], #1
	B invalid_loop_a
	

valid_symbol
	ADD R3, #1						;increment the symbol counter
	LSL R4, #4						;multuply by 4 to make room

	CMP R3, #8						;are we processing the 8th+ character
	BGT invalid_symbol				;if more than 8, then string is malformed
	
	
	SUB R6, R2, R5					;use the offset to calculate the numeric representation
	ADD R4, R6						;add it to the accumulator
	
	B main_loop_a

end_of_input
	;R4 hold the numberic representation of the string
	CMN R4, #0						;update flags, including N
	BPL write_result
		
do_twos_comp
	MVN R4, R4			;invert
	ADD R4, #1			;add 1
	LDR R3, =dec_string	;get pointer to result
	LDR R2, ='-'		;load the negative character
	STR R2, [R3]		;append the negative sign

	
write_result
	;write the result to the twos_comp holder
	LDR R6, =twos_comp
	STR R4, [R6]

	MOV R5, R4						;place the value in the parameter register
	BL power_divide_to_ascii		;call the function
				
	BL quit			

quit
	MOV		r0, #0x18
	LDR		r1, =0x20026
	SVC		#0x11

				
				
power_divide_to_ascii
	; loop divides by the largest power of 10 that is smaller than dividend, using subtraction.
	; on each subsequent iteration, the remainder is divided by the next smaller power of 10, eventally
	; ending at 10^0 = 1. At each stage, the quotent forms the next digit from left to right, and the remainder
	; forms new new quotient.
	;
	; This works because all numbers in base10 can be represented as A10^n + B10^n-1 + C10^n - 3 + ... + D10^2 + D10^1 + D10^0
	; If needed, finding n, such that 10^n <= some_integer <= 10^n+1, will tell you how many digits are in some_integer
	;
	; inputs 
	;	R5 = diviidend
	; outputs
	;	ascii reprsentation of a signed decimal
	;	
	;

	;R1 = quotient
	;R2 = remainder
	;R3 = counter
	;R5 = dividend
	;R7 = ptr_power
	;R8 = power_value
	;R9 = ptr_dec_string

	LDR R9, =dec_string
	LDR R7, =powers_of_ten				;R7 pts to biggest value
	
	LDR R3, [R9]						;get the first character of output
	CMP R3, #'-'						;if it is a negative sign
	IT	EQ
		ADDEQ R9, #1					;leave it there and start with the next placeholder
	
	MOV R3, #0
	MOV R1, #0
	
	CMP R5, #0x80000000					;special case has to be hardcoded, as no way to represent +2147483648
	BEQ write_min						;in memory
	
power_loop_a
	LDR R8, [R7]						;load 10^x
	CMP R8, R5							;compare potential divisor to dividend
	ITT GT								;it's too big
		ADDGT R7, #4					;increment the ptr to the next smaller power
		BGT power_loop_a				;loop
	
power_loop_b
	;else LT							;R5 / R8
	CMP R5, R8
	
	SUBS R5, R5, R8						;R5 = R5 - R8

	ADD R1, #1							;increment quotient
		
	CMP R5, R8							;compare dividend to divisor
	BGE power_loop_b					;if its still greater or equal, subtract again
										;quotient is formed, and becomes the nth digit of the result
	ADD R3, R1, #'0'					;add the result to "0" to get the ASCII value
	STR R3, [R9], #1					;write the result
	
power_loop_c
	LDR R8, [R7, #4]!					;load the next lower power of 10
	
	
	CMP R8, #0							;compare the new divisor to the new dividend
	BEQ quit							;if the divisor is zero then we are done
	
	CMP R8, R5	
	ITT LE
		MOVLE R1, #0
		BLE power_loop_b
	
	LDR R3, ='0'
	STR R3, [R9], #1
	B power_loop_c
	
	;else
	MOV R1, #0							;reset the quotient
	B power_loop_b						;work on the next digit


write_min
	;R9 = dec_string pointer
	;R8 = min_str ptr
	LDR R8, =str_min
	SUB R9, #1
write_min_loop_a
	LDR R1, [R8], #1
	CMP R1, #0
	BEQ quit
	STR R1, [R9], #1
	B write_min_loop_a




slow_divide_by_ten		

	POP {R1}							;get the input
	
	;R1 = divisor
	;R2 = quotient_counter
	;R3 = remainder
	;R4 = temp
	
	MOV R2, #0
	MOV R3, #0
	MOV R4, R1
loop_e
	CMP R4, #10
	BLT done_slow
	SUB R4, R4, #10
	ADD R2, R2, #1
	B loop_e
			


done_slow
	PUSH {R4}							;place remander on stack
	PUSH {R2}							;place quotient on stack
	
	B quit





fast_div_by_ten
; Uses an efficient algrorithm adapted from "The Hackers Delight".
; available at http://www.hackersdelight.org/divcMore.pdf. Link and an example
; provided by "realtime" at http://stackoverflow.com/questions/5558492/divide-by-10-using-bit-shifts
;
; The algorithm multiplies the dividend by the recipricoal of the divisor, which in this case
; is 1/10. Since 10 cannot be represented perfectly in binary, a close approximation is used.
; After the remainder is calculated, the result is then corrected. However, the appx. result can still be off a
; max of 1
;
; Inputs
;	n = stack_value_1 = divisor
; Outputs
;	quotient = stack[0]
;	remainder = stack[1]
; Registers Used:
;	R0 - R6
; Registers Corrupted:
;	R0

	POP {R1}							;get the input
	
	;n = R1; q = R2, tmp = R3, r = R4
	
	;q = (n >> 1) + (n >> 2);
	MOV R3, R1, LSR #1
	ADD R2, R3, R1, LSR #2
	
	;q = q + (q >> 4);
	ADD R2, R2, LSR #4

	;q = q + (q >> 8);
	ADD R2, R2, LSR #8
	
	;q = q + (q >> 16);
	ADD R2, R2, LSR #16	

	;q = q >> 3;
	LSR R2, #3
	
	;r = n - q*10;
	;q*10
	;= (q * 4 + q) * 2 = (4q + q) * 2 = 5q * 2 = 10q
	;= ((q << 2) + q) << 1
	MOV R3, R2, LSL #2
	ADD R3, R3, R2
	LSL R3, #1

	;r = n - q*10;
	SUB R4, R1, R3
		
	;rslt = q + ((r + 6) >> 4)
	ADD R3, R4, #6
	LSR R3, #4
	ADD R5, R2, R3

	;check if remainder is 10, if so, set it to 0
	CMP R4, #10
	IT GE
	MOVGE R4, #0


	PUSH {R4}							;place remander on stack
	PUSH {R5}							;place quotient on stack
	
	B quit	
				
				
				
				
				
				
				
				
				
				
				
	ALIGN
	AREA main_daata, DATA, READWRITE
	
	ALIGN
hex_string
	DCB "0ddC0DE", 0
	
	ALIGN
twos_comp
	DCD 0
					
dec_string
	SPACE 50
		
	ALIGN
reg_stack
	SPACE 400
		
	ALIGN
powers_of_ten
	DCD 0x3B9ACA00, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1, 0
		
str_error
	DCB "INVALID SYMBOL OR TOO MANY DIGITS", 0
	ALIGN
		
str_min
	DCB "-2147483648", 0
	ALIGN

adr_hex_string
	DCD hex_string
adr_twos_comp
	DCD twos_comp
adr_dec_string
	DCD dec_string
			
			
	EXPORT adr_hex_string
	EXPORT adr_twos_comp
	EXPORT adr_dec_string
					
			END	
				
				
;   TESTING
	
;   in:		3C34EB12
;   exp:	1010101010
;   PASS!

;   in:		3B9ACA01
;   exp:	1000000001

;   PASS!

;   in:		3B9ACA00	
;   exp:	1000000000
;   ACT:	00000000
;   FAIL!

;   BUG[3]
;   Line 169: Changed GE to GT


;   in:		3B9ACA00
;   exp:	1000000000
;   PASS!

;   in:		3B8B8BA7
;   exp:	999000999
;   PASS!	

;   in:		80000001
;   exp:	-2147483647
;   PASS!

;   in:		70000000
;   exp:	1879048192
;   PASS!	

;   in:		80000000
;   exp:	-2147483648
;   PASS

;   in:		7FFFFFFF
;   exp:	2147483647
;   PASS

;   in:		FFFFFFFF
;   exp:	-1
;   PASS

;   in: 	0000000F		
;   exp:	15
;   PASS

;   in: 	[blank]		
;   exp:	[blank]
;   PASS

;   in: 	00000		
;   exp:	[blank]
;   PASS

;   in: 987654321
;   in: -234
;   in:	12g
;   in: H12
;   exp: "INVALID..."
;   PASS


