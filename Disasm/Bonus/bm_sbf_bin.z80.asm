;; -----------------------------------------------------------------------------------------------------------
;; Disassembly of "Batman" - Amstrad CPC (Jon Ritman and Bernie Drummond)
;; Batman BM.SCF
;; Author : Fred Limouzin (fphenix@hotmail.com)
;; Tool used: mostly WinApe and Notepad++!
;; -----------------------------------------------------------------------------------------------------------
;; This is a Bonus work of the Head Over Heels dissassembly.
;; Compilable (need to run the txt2asm script). WORK UNDER PROGRESS
;; Note that Batman was the base game "HoH" was developped from, hence many functions are identical.
;; -----------------------------------------------------------------------------------------------------------
;; WARNING : Some of the comments have simply been copied from HoH, hence do not always apply to Batman!!
;; -----------------------------------------------------------------------------------------------------------

						ORG		&0100
						run		Entry
Stack:
Entry:
	JP Reentry
Reentry:
	LD SP,Stack
	CALL Init_setup
	CALL Keyboard_scanning_ending
	JR Main

;; -----------------------------------------------------------------------------------------------------------
current_Room_ID
	DEFW NULL_PTR ;; curr room id
Sound_amount
	DEFB 2 ;; 2="nasty" (plenty), 1="useful", 0="late at night" (quiet)

Do_Objects_Phase
	DEFB 0

Current_User_Inputs
	DEFB &FF
Last_User_Inputs:
	DEFB &EF

action_key_pressed
	DEFB 0

Frame_counter:
	DEFB	&01
win_state
	DEFB 0		;; Boolean : 0 if not in last room in batcraft with all parts, else (winner) &FF

;; -----------------------------------------------------------------------------------------------------------
RoomID_Victory			EQU		&E500
RoomID_Batman_1st		EQU		&8A40					;; This is first room ID (8A4)

;; -----------------------------------------------------------------------------------------------------------
;; Main : Entry point and main loop
;; Game_over : Entry point after a game has been played
.Game_over:													;; when "game over" branch here and continue at 'Main'
	CALL Game_over_screen
Main:
	LD SP,Stack
	XOR A
	LD (win_state),A					;; reset ....
	CALL Main_Screen
	PUSH AF
	CALL clr_screen
	POP AF
	JR NC,Main_continue_game
	CALL Init_new_game
	JR Main_game_start
Main_continue_game
	CALL Init_Continue_game
Main_game_start
	CALL WaitKey
Enter_New_Room
	XOR A
	LD (Do_Objects_Phase),A
	LD BC,(current_Room_ID)
	CALL EnterRoom
Main_loop
	CALL Check_User_Input
	CALL Do_Objects
	CALL WaitFrame_Delay
	CALL Victory_Room
	JR Main_loop

;; -----------------------------------------------------------------------------------------------------------
Victory_Room
	LD A,(parts_got_Mask)
	CP &7F
	RET NZ
	LD HL,(current_Room_ID)
	LD DE,RoomID_Victory		;; Victory room
	AND A						;; carry = 0
	SBC HL,DE					;; test if in victory room
	RET NZ						;; no: leave
test_right_posish		;; test if the Batman sprite is in the right position in the room
	LD HL,Batman_variables+O_FLAGS
	LD DE,test_posish_data
	LD BC,5
test_posish_loop
	LD A,(DE)
	CPI							;; CP (HL) ; INC HL; DEC BC
	INC DE
	RET NZ						;; leave if Batman not at the right position
	JP PE,test_posish_loop		;; at CPI, if BC != 0, V (overflow floag) is set (loop), if BC=0 V is reset (cont)
beat_the_game:
	CALL Play_Batman_Theme
	CALL Wait_key_pressed
	CALL Batcraft_complete_screen
	LD A,&FF
	LD (win_state),A
	JP Game_over

;; -----------------------------------------------------------------------------------------------------------
;; position for winning the game
test_posish_data
	DEFB &08, &14, &28, &B4, SPR_BATMAN_0 ;; Winning position : Flag, U,V,Z,Sprite

;; -----------------------------------------------------------------------------------------------------------
;; from the access code (1:Down,2:Right,3:Up,4:Left,5:Below,6:Above),
;; go to the next room (roomID = UVZx) resp U-1, V-1, U+1, V+1, Z+1, Z-1
Go_to_room
	LD A,(access_new_room_code)
	DEC A
	LD HL,(current_Room_ID)
	CP 5
	JR NC,goto_choose_z					;; >=5 jump 1b6
	RRA
	JR c,goto_v
	LD DE,&F0 * WORD_HIGH_BYTE + &10	;; -16 ; +16 (+/-1 for U)
	RRA
	JR NC,goto_u
	LD D,E
goto_u
	LD A,H
	ADD A,D								;; U : H-16 if access_new_room_code=1 ; H+16 if access_new_room_code=3
	JR goto_newroomuv

goto_v
	LD DE,&FF * WORD_HIGH_BYTE + &01	;; -/+1 for V
	RRA
	JR NC,goto_uv
	LD D,E
goto_uv
	LD A,H
	ADD A,D								;; V : H-1 if access_new_room_code=2 ; H+1 if access_new_room_code=4
	XOR H
	AND &0F
	XOR H
goto_newroomuv
	LD H,A
goto_newroom
	LD (current_Room_ID),HL
Reenter_room
	LD SP,Stack
	JP Enter_New_Room

goto_choose_z
	RRA
	LD A,&10			;; +1 for Z
	JR c,goto_z
	LD A,&F0			;; -1 for Z
goto_z
	ADD A,L				;; Z : L+16 if access_new_room_code=5 ; L-16 if access_new_room_code=6
	LD L,A				;; (+/-1 for Z)
	JR goto_newroom

;; -----------------------------------------------------------------------------------------------------------
;; Controls the frame rate (FPS) by syncing with a number of VSYNC.
;; Frame_counter is updated in the Interrupt Handler and it
;; waits that it goes to 0 and sets it back to 4.
.WaitFrame_Delay:
	LD A,(Frame_counter)
	AND A
	JR NZ,WaitFrame_Delay
	LD A,4
	LD (Frame_counter),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Depending on the Sensitivity settings (Sensitivity Menu) self-modifying
;; the code to use either the Routine_High_sensitivity or the
;; Routine_Low_sensitivity. This only has an impact when pressing two keys
;; to move diagonally.
.Sub_Update_Sensitivity:													;; A = sensitivity ; (self-modifying code at &0232):
	LD HL,Routine_High_sensitivity
	AND A
	JR Z,us_skip
	LD HL,Routine_Low_sensitivity
us_skip
	LD (smc_sens_routine+1),HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will scan the keyboard and get the user inputs
;; The value A from Get_user_inputs is:
;;		bit7:Carry, Fire, Swop, Left, Right, Down, Up, bit0: Jump (active low)
.Check_User_Input:
	CALL Get_user_inputs
	BIT 7,A
	LD HL,action_key_pressed
	LD (HL),0
	JR NZ,cuiskp
	LD (HL),&FF
cuiskp:
	BIT 6,A
	JR NZ,Update_key
;;Check_Pause
	CALL Silence_all_Voices
	CALL Wait_anykey_released
	LD A,Print_Paused
	CALL Print_String
pause_loop
	CALL Test_Enter_Shift_keys
	JR c,pause_loop
	DEC C
	JP Z,Game_over
leave_pause
	CALL Wait_anykey_released
	CALL LeavePause
	JR Check_User_Input

Update_key
	LD C,A
	RRA
	CALL DirCode_from_LRDU
	CP &FF
	JR Z,No_Key_pressed
	RRA
smc_sens_routine
	JP c,Routine_Low_sensitivity
	LD A,C
	LD (Last_User_Inputs),A
	LD (Current_User_Inputs),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Runs if HIGH Sensitivity is choosen in the menu (value set in smc_sens_routine)
;; If moving diagonaly, set the new direction each time.
;; Input: reg C has the "Carry,Fire,Swop,Left,Right,Down,Up,Jump" state (active low)
.Routine_High_sensitivity:
	LD A,(Last_User_Inputs)
	XOR C
	CPL
	XOR C
	AND &FE
	XOR C
	LD (Current_User_Inputs),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Runs if LOW Sensitivity is choosen in the menu (value set in smc_sens_routine)
;; if moving diagonaly, keep the old direction (the same one in the pair creating the diag)
;; Input: reg C has the "Carry,Fire,Swop,Left,Right,Down,Up,Jump" state (active low)
.Routine_Low_sensitivity:
	LD A,(Last_User_Inputs)
	XOR C
	AND &FE
	XOR C
	LD B,A
	OR C
	CP B
	JR Z,rls_1
	LD A,B
	XOR &FE
rls_1
	LD (Current_User_Inputs),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Nothing pressed, update Current_User_Inputs with current CFSLRDUJ (active low)
;; Input: reg C has the "Carry,Fire,Swop,Left,Right,Down,Up,Jump" state
.No_Key_pressed:
	LD A,C
	LD (Current_User_Inputs),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; leave pause
LeavePause
	CALL Update_Screen_Periph
	LD HL,&4C * WORD_HIGH_BYTE + &50
pause_message_draw_over_loop
	PUSH HL
	LD DE,&60 * WORD_HIGH_BYTE + &88
	CALL Draw_View
	POP HL
	LD A,L
	LD H,A
	ADD A,20
	LD L,A
	CP 181
	JR c,pause_message_draw_over_loop
	RET

;; -----------------------------------------------------------------------------------------------------------
;; In sync with the Do_Objects_Phase, process the next object in the
;; linked list (CallObjFn : call object function) and point on next Object.
;; The phase mechanism allows an object to not get processed for one frame.
.Do_Objects:
	LD A,(Do_Objects_Phase)
	XOR &80				;; flip bit7
	LD (Do_Objects_Phase),A
	LD HL,(ObjList_Regular_Near2Far)
	JR Sub_Do_Objects_entry

doob_loop
	PUSH HL
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	EX (SP),HL
	EX DE,HL
	LD HL,O_FUNC
	ADD HL,DE
	LD A,(Do_Objects_Phase)
	XOR (HL)
	CP &80
	JR c,doob_skip
	LD A,(HL)
	XOR &80
	LD (HL),A
	AND &7F
	CALL NZ,CallObjFn
doob_skip
	POP HL
Sub_Do_Objects_entry
	LD A,H
	OR L
	JR NZ,doob_loop
	JP Characters_Update

;; -----------------------------------------------------------------------------------------------------------
;; RST init
JUMP_OPCODE				EQU		&C3						;; "JP addr", used to generate RST7 (int handler) and 0 (reset to Entry)
LDIX_OPCODE				EQU		&DD						;; to transform a "LD HL,.." into a "LD IX,..." in order to cancel it
LDAvv_OPCODE			EQU		&3E 					;; "LD A,vv", used in BlitRot<*> functions

RST0_ADDR				EQU		&0000
RST7_ADDR				EQU		&0038

WORD_LOW_BYTE			EQU		&00FF
WORD_HIGH_BYTE			EQU		256

;; -----------------------------------------------------------------------------------------------------------
;; Amastrad CPC System specific constants
GATEARRAY_BORDER		EQU		&7F10
GATEARRAY_PENS			EQU		&7F00
GATEARRAY_INKS			EQU		&7F40
GATEARRAY_MODE1			EQU		&7F8D

CRTC_REGSEL				EQU		&BC00
CRTC_DATAOUT			EQU		&BD00
;;CRTC_STATUS			EQU		&BE00
;;CRTC_DATAIN			EQU		&BF00

PSG_PORTA				EQU		&F400
PSG_PORTB				EQU		&F500
PSG_PORTC				EQU		&F600
PSG_INACTIVE			EQU		&F600
PSG_KB_LINESEL			EQU		&F600
PSG_REG_READ			EQU		&F640
PSG_REG_WRITE			EQU		&F680
PSG_REG_SEL				EQU		&F6C0
PSG_PORTCTRL			EQU		&F700
PSG_PORTA_OUT			EQU		&F782
PSG_PORTA_IN			EQU		&F792

;; -----------------------------------------------------------------------------------------------------------
;; Data block is moved at init from 4C00-AC8F to 56D8-B767 . That frees the 4C00-56D7 area, used by buffers.
;; The copy is done backwards (from last byte to first)
;; &0AD8 is the offset between the pre-init (data) block.
;; in Init_table_and_crtc (see move_loaded_data_section)
MOVE_BLOCK_DEST_END		EQU		&B767												;; last byte of the destination block
MOVE_BLOCK_SOURCE_END	EQU		&AC8F												;; last byte of the source block
MOVE_BLOCK_LENGTH		EQU		&6090												;; length of the moved block
MOVE_OFFSET				EQU		MOVE_BLOCK_DEST_END - MOVE_BLOCK_SOURCE_END			;; &0AD8 : gap betwwen blocks

;; -----------------------------------------------------------------------------------------------------------CPC
;; This will 1) Move a big block of loaded data 2) initialize some
;; Tables 3) set the interrupts/RST and 4) initialize the CRT (mode, colors, etc.).
Init_table_and_crtc:
	DI
move_loaded_data_section
	LD DE,MOVE_BLOCK_DEST_END
	LD HL,MOVE_BLOCK_SOURCE_END
	LD BC,MOVE_BLOCK_LENGTH
	LDDR
erase_buffer_6800
	LD HL,DestBuff
	LD BC,BUFFER_LENGTH
	CALL Erase_forward_Block_RAM
	CALL clr_screen
	LD A,COLOR_SCHEME_ALLBLACK
	CALL Set_colors
inth_and_rst
	LD A,JUMP_OPCODE
	LD HL,Interrupt_Handler
	LD (RST7_ADDR),A
	LD (RST7_ADDR+1),HL
	LD HL,Entry
	LD (RST0_ADDR),A
	LD (RST0_ADDR+1),HL
	IM 1
	CALL Init_6600_table
init_CTRC_and_screen
	LD BC,GATEARRAY_MODE1
	OUT (C),C
	LD HL,array_CRTC_init_values
	LD BC,CRTC_REGSEL
init_CRTC_loop
	OUT (C),C
	LD A,(HL)
	INC B
	OUT (C),A
	DEC B
	INC HL
	INC C
	LD A,C
	CP &10
	JR NZ,init_CRTC_loop
	EI
	RET

;; -----------------------------------------------------------------------------------------------------------CPC
array_CRTC_init_values:
	DEFB 	&3F             	;; CRTC reg 0 value : Width of the screen, in characters. Should always be 63 (&3F) (64 characters). 1 character == 1μs
	DEFB 	&28 				;; CRTC reg 1 value : Displayed char value, 40 (&28) is the default!
	DEFB 	&2E		 			;; CRTC reg 2 value : 46; When to start the HSync signal.
	DEFB 	&8E	  				;; CRTC reg 3 value : 142 (128+14); HSync pulse width in characters
	DEFB 	&26					;; CRTC reg 4 value : 38; Height of the screen, in characters
	DEFB 	&00					;; CRTC reg 5 value : 0; Measured in scanlines
	DEFB 	&19					;; CRTC reg 6 value : 25; Height of displayed screen in characters
	DEFB	&21					;; CRTC reg 7 value : 33 Note: default is 30; when to start the VSync signal, in characters.
	DEFB 	&00					;; CRTC reg 8 value : 0 = No interlace
	DEFB 	&07					;; CRTC reg 9 value : 7; Maximum scan line address
	DEFB 	&0F					;; CRTC reg 10 value : Cursor Start Raster (0 is the default)
	DEFB 	&0F					;; CRTC reg 11 value : Cursor End Raster (0 is the default)
	DEFB 	&30					;; CRTC reg 12 value : 48 (&30) Display Start Address (High)
	DEFB 	&00					;; CRTC reg 13 value : Display Start Address (Low) (0 is the default)
	DEFB 	&30					;; CRTC reg 14 value : Cursor Address (High) (0 is the default)
	DEFB 	&00 				;; CRTC reg 15 value : Cursor Address (Low)

;; -----------------------------------------------------------------------------------------------------------
VSYNC_wait_value:
	DEFB 	6

;; -----------------------------------------------------------------------------------------------------------CPC
;; The interrupt is only run every VSYNC_wait_value VSYNCs
.Interrupt_Handler:
	PUSH AF
	PUSH BC
	PUSH HL
	LD HL,VSYNC_wait_value
	LD B,PSG_PORTB / WORD_HIGH_BYTE
	IN C,(C)
	RR C
	JR c,ih_0
	DEC (HL)
	JR NZ,exit_int_handler
ih_0
	PUSH DE
	LD (HL),6
	PUSH IX
	PUSH IY
	CALL sub_IntH_play_update
	POP IY
	POP IX
	LD A,(Frame_counter)
	AND A
	JR Z,ih_1
	DEC A
	LD (Frame_counter),A
ih_1
	POP DE
exit_int_handler
	POP HL
	POP BC
	POP AF
	EI
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This initialize a table for the blit routines from 6600 to 66FF:
;;    6600 : 00 10 20 30 ... E0 F0
;;    6610 : 01 11 21 31 ... E1 F1
;;    6620 : 02 12 22 32 ... E2 F2
;;     ...
;;    66E0 : 0E 1E 2E 3E ... EE EF
;;    66F0 : 0F 1F 2F 3F ... EF FF
.Init_6600_table:
	LD HL,BlitBuff
init_fill_loop
	LD A,L
	RRCA
	RRCA
	RRCA
	RRCA
	LD (HL),A
	INC L
	JR NZ,init_fill_loop
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Draws the screen, box per box, all colors black to hides the room drawing process.
;; X extent from 24 (&30/2 = 48/2 = 24) to 208 (< 209 (&D1)) (7 boxes wide)
;; Y extent from 64 (&40) to 255 maxY. (5 boxes high)
X_START 				EQU 	&30
Y_START					EQU		&40

.DrawBlacked:
	LD A,8
	CALL Set_colors
	LD HL,&30 * WORD_HIGH_BYTE + &40			;; first box X extent (min=&30, first block up to &40, 16 pix, 4pix per byts (mode1) so 4 bytes per block);
	LD DE,&40 * WORD_HIGH_BYTE + &57			;; first box Y extent (min=&40, first block up to &57, 23 lines per block)
dbl_loop1
	PUSH HL
	PUSH DE
	CALL DrawXSafe
	POP DE
	POP HL
	LD H,L
	LD A,L
	ADD A,&18	;; 24
	LD L,A
	CP &D1		;; 209
	JR c,dbl_loop1
	LD HL,&30 * WORD_HIGH_BYTE + &40
	LD D,E
	LD A,E
	ADD A,&2A	;; 42
	LD E,A
	JR NC,dbl_loop1
	RET

;; -----------------------------------------------------------------------------------------------------------CPC
;; This reconfigure the value of PEN 3 only from the color Scheme numer in A
;; Note : not used in HoH but used in Batman!
Set_pen3_only:
	CALL Get_color_scheme_value
	INC HL
	INC HL
	INC HL
	LD BC,GATEARRAY_PENS+3
	LD E,1
	JP program_Gate_array_colors

;; -----------------------------------------------------------------------------------------------------------CPC
;; Reconfigure the CRTC to setup the color Scheme, from the color Scheme
;; number in A (0 to 10, 8 is "All black").
.Set_colors:
	CALL Get_color_scheme_value
	LD BC,GATEARRAY_BORDER
	LD E,1
	CALL program_Gate_array_colors
	DEC HL
	LD E,4
	LD BC,GATEARRAY_PENS
program_Gate_array_colors
	OUT (C),C
	INC C
	LD A,(HL)
	OR GATEARRAY_INKS and WORD_LOW_BYTE
	OUT (C),A
	INC HL
	DEC E
	JR NZ,program_Gate_array_colors
	RET

;; -----------------------------------------------------------------------------------------------------------CPC
;; This converts the color Scheme number in A to the pointer in HL
;; on the Color Scheme data.
.Get_color_scheme_value:
	ADD A,A
	ADD A,A
	LD DE,array_Color_Schemes
	LD L,A
	LD H,0
	ADD HL,DE
	RET

;; -----------------------------------------------------------------------------------------------------------CPC
;; Table for the Color Scheme 4 colors
;; (Index = color Scheme number * 4)
C_BLACK					EQU		&14	;; Firmware color 0, Hardware color &14 (program &54)
C_DKBLUE				EQU		&04
C_BLUE					EQU		&15
C_MAROON				EQU		&1C
C_MAGENTA				EQU		&18
C_MAUVE					EQU		&1D
C_RED					EQU		&0C
C_PURPLE				EQU		&05 ;; or &08
C_MAGENTAVIF			EQU		&0D
C_DKGREEN				EQU		&16
C_DKCYAN				EQU		&06
C_SKYBLUE				EQU		&17
C_DRKYELLOW				EQU		&1E
C_GREY					EQU		&00 ;; or &01
C_PASTELBLUE			EQU		&1F
C_ORANGE				EQU		&0E
C_PINK					EQU		&07
C_DARKPINK				EQU		&0F
C_GREEN					EQU		&12
C_SEAGREEN				EQU		&02	;; or &11
C_CYAN					EQU		&13
C_LIME					EQU		&1A
C_PSTLGREEN				EQU		&19
C_TURQUOISE				EQU		&1B
C_YELLOW				EQU		&0A
C_CREAM					EQU		&03	;; or &09
C_WHITE					EQU		&0B	;; Firmware color 26, Hardware color &0B (program &4B)

COLOR_SCHEME_ALLBLACK	EQU		8

array_Color_Schemes:
	DEFB  C_BLACK, C_RED,		C_BLUE,		  C_YELLOW		;; Scheme 0
	DEFB  C_BLACK, C_BLUE,		C_RED,		  C_CYAN		;; Scheme 1
	DEFB  C_BLACK, C_DRKYELLOW,	C_RED,		  C_TURQUOISE	;; Scheme 2
	DEFB  C_BLACK, C_DKGREEN,	C_SKYBLUE,	  C_ORANGE		;; Scheme 3
	DEFB  C_BLACK, C_RED,		C_MAGENTAVIF, C_LIME		;; Scheme 4
	DEFB  C_BLACK, C_BLUE,		C_DRKYELLOW,  C_TURQUOISE	;; Scheme 5
	DEFB  C_BLACK, C_BLUE,		C_RED,		  C_YELLOW		;; Scheme 6
	DEFB  C_BLACK, C_RED,		C_DKGREEN,	  C_CREAM		;; Scheme 7
	DEFB  C_BLACK, C_BLACK,		C_BLACK,	  C_BLACK		;; Scheme 8
	DEFB  C_BLACK, C_RED,		C_BLUE,		  C_YELLOW		;; Scheme 9
	DEFB  C_BLACK, C_DKGREEN,	C_BLUE,		  C_YELLOW		;; Scheme 10

;; -----------------------------------------------------------------------------------------------------------
;; Tap foot if facing us and not moving
TapFoot_Offset			EQU		85    ;; Batman's foot offset in SPR_BM_STANDING sprite

TapFoot:
	LD A,(SpriteFlips_buffer + 2 + MOVE_OFFSET) ;; 56E2 : check if the sprite is flipped or not
	BIT 0,A
	LD DE,TapFoot_XOR_facing_Right		;; Blink_XOR_facing_right
	JR Z,weybw_doit
	LD DE,TapFoot_XOR_facing_Left		;; Blink_XOR_facing_Left
weybw_doit
	LD HL,img_bm_standing_1 + TapFoot_Offset + MOVE_OFFSET ;; 83E5
	LD B,3
	CALL TapFoot_XORify
	LD B,4
	LD HL,msk_bm_standing_1 + TapFoot_Offset + MOVE_OFFSET ;; 8445
TapFoot_XORify: ;; BlinkEyes_XORify
	LD A,(DE)
	XOR (HL)
	LD (HL),A
	INC DE
	INC HL
	INC HL
	INC HL
	DJNZ TapFoot_XORify
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Xor table to invert chosen bits and move Batman's foot;
;; One set is used if Batman is facing left, the other for facing right.
TapFoot_XOR_facing_Left: ;; Blink_XOR_facing_Left
	DEFB	&10, &02, &18, &10, &02, &3A, &18
TapFoot_XOR_facing_Right: ;; Blink_XOR_facing_right
	DEFB	&08, &40, &18, &08, &40, &5C, &18

;; -----------------------------------------------------------------------------------------------------------
;; Convert the CharCode - &20 to a Symbol data address in DE
Char_code_to_Addr
	CP &08
	JR c,cc2a_0
	SUB 4
	CP &18
	JR c,cc2a_0
	SUB 4
cc2a_0
	ADD A,A
	ADD A,A
	LD L,A
	LD H,0
	ADD HL,HL
	LD DE,Char_symbol_data + MOVE_OFFSET ;; B500
	ADD HL,DE
	EX DE,HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Provides 2 functions:
;; 	* Clear_View_Buffer: This will be implicitely CALLed by
;; 			the RET of the blit subroutines (blit_sub_subroutine_1 to 6)
;;			It erases the sprite buffer.
;;	* Clear_mem_array_256bytes: This will erase a memory block from the
;;			addr value in HL (Starts at HL, HL++ and until Lmax = &FF)
Clear_View_Buffer
	LD HL,ViewBuff ;; 4D00
Clear_mem_array_256bytes
	XOR A
cma_loop
	LD (HL),A
	INC L
	LD (HL),A
	INC L
	LD (HL),A
	INC L
	LD (HL),A
	INC L
	JR NZ,cma_loop
	RET

;; -----------------------------------------------------------------------------------------------------------
;; BlitScreen copies from ViewBuff to the screen coordinates of
;; ViewYExtent and ViewXExtent. The X extent can be from 1 up to 6 bytes
;; (4 pix per bytes, so up to 24 double pixels).
;; The "Extent" are Max,Min values.
;; At the end, the selected blit subroutine (having been pushed on the stack)
;; is implicitely CALLed by the RET (and so is the Erase function).
;;
;; ViewBuff is expected to be a 6 bytes wide, and the Y origin can
;; be adjusted by overwriting BlitYOffset. It is usually Y_START, but
;; is set to 0 during Draw_Sprite. The X origin is always fixed at 0x30
;; in double-width pixels.
.Blit_screen:
	LD HL,(ViewXExtent)
	LD A,H
	SUB X_START
	LD C,A
	LD A,L
	SUB H
	RRA
	RRA
	AND &07
	DEC A
	ADD A,A
	LD E,A
	LD D,0
	LD HL,Sub_routines_table
	ADD HL,DE
	LD DE,Clear_View_Buffer
	PUSH DE
	LD E,(HL)
	INC HL
	LD D,(HL)
	PUSH DE
	LD HL,(ViewYExtent)
	LD A,L
	SUB H
	EX AF,AF'
	LD A,H
smc_BlitYOffset_value
	SUB Y_START
	LD B,A
	CALL Get_screen_mem_addr
	EX AF,AF'
	LD B,BlitBuff / WORD_HIGH_BYTE ;; 4C00
	LD HL,ViewBuff ;; 4D00
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This table will return the pointer address for the blit routine to
;; be used, with index = N-1; N being the byte width of the sprite.
.Sub_routines_table:
	DEFW 	blit_sub_subroutine_1
	DEFW 	blit_sub_subroutine_2
	DEFW 	blit_sub_subroutine_3
	DEFW 	blit_sub_subroutine_4
	DEFW 	blit_sub_subroutine_5
	DEFW 	blit_sub_subroutine_6

;; -----------------------------------------------------------------------------------------------------------
;; All these (6 functions) provide Sprite Bliting functions.
;; They are implicitely CALLed by the final RET of Blit_screen.
;; The "blit_sub_subroutine_1 to 6" copies an N-byte-wide image
;; (in the buffer at HL) to the screen.
;; They use the table initialized at 6600-66FF and a buffer at 6700-67FF.
;; Input: HL = image location; DE = screen location, size in lines in B.
;; Note : HL buffer must be 6 bytes wide.
;; The RET will implicitely CALL the Clear_View_Buffer (that has
;; been pushed on the Stack)
.blit_sub_subroutine_1:
	EX		AF,AF'
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC L
	INC L
	INC L
	INC L
	INC L
	LD BC,&FFFF
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	LD B,BlitBuff / WORD_HIGH_BYTE
	LD A,D
	ADD A,8
	LD D,A
	JR c,blit_ss_1
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_1
	RET
blit_ss_1
	LD A,E
	ADD A,&50
	LD E,A
	ADC A,D
	SUB E
	SUB &40
	LD D,A
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_1
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_2:
	EX AF,AF'
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC L
	INC L
	INC L
	INC L
	LD BC,&FFFD
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	LD B,BlitBuff / WORD_HIGH_BYTE
	LD A,D
	ADD A,8
	LD D,A
	JR c,blit_ss_2
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_2
	RET
blit_ss_2
	LD A,E
	ADD A,&50
	LD E,A
	ADC A,D
	SUB E
	SUB &40
	LD D,A
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_2
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_3:
	EX AF,AF'
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC L
	INC L
	INC L
	LD BC,&FFFB
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	LD B,BlitBuff / WORD_HIGH_BYTE
	LD A,D
	ADD A,8
	LD D,A
	JR c,blit_ss_3
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_3
	RET
blit_ss_3
	LD A,E
	ADD A,&50
	LD E,A
	ADC A,D
	SUB E
	SUB &40
	LD D,A
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_3
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_4:
	EX AF,AF'
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC L
	INC L
	LD BC,&FFF9
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	LD B,BlitBuff / WORD_HIGH_BYTE   ;; 4C(00)
	LD A,D
	ADD A,8
	LD D,A
	JR c,blit_ss_4
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_4
	RET
blit_ss_4
	LD A,E
	ADD A,&50
	LD E,A
	ADC A,D
	SUB E
	SUB &40
	LD D,A
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_4
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_5:
	EX AF,AF'
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC L
	LD BC,&FFF7
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	LD B,BlitBuff / WORD_HIGH_BYTE
	LD A,D
	ADD A,8
	LD D,A
	JR c,blit_ss_5
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_5
	RET
blit_ss_5
	LD A,E
	ADD A,&50
	LD E,A
	ADC A,D
	SUB E
	SUB &40
	LD D,A
	EX AF,AF'
	DEC A
	JR NZ,blit_sub_subroutine_5
	RET

;; -----------------------------------------------------------------------------------------------------------
.blit_sub_subroutine_6:
	EX AF,AF'
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	INC DE
	LD C,(HL)
	INC H
	LD A,(BC)
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (DE),A
	LD C,(HL)
	LD A,(BC)
	DEC H
	XOR (HL)
	AND &F0
	XOR (HL)
	INC E
	LD (DE),A
	INC L
	LD BC,&FFF5
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	LD B,BlitBuff / WORD_HIGH_BYTE
	LD A,D
	ADD A,8
	LD D,A
	JR c,blit_ss_6
	EX AF,AF'
	DEC A
	JP NZ,blit_sub_subroutine_6
	RET
blit_ss_6
	LD A,E
	ADD A,&50
	LD E,A
	ADC A,D
	SUB E
	SUB &40
	LD D,A
	EX AF,AF'
	DEC A
	JP NZ,blit_sub_subroutine_6
	RET

;; -----------------------------------------------------------------------------------------------------------CPC
;; This is the CPC screen mem address calculation from the pixel we target.
;; Input: B = y (line),
;;        C = x single-pixel coordinate (in mode 1 real x is double that value).
;; Note: top left coord is (0,0) at addr &C000. Mode 1 ppb (pix per byte) is 4
;; This will calculate the Output in DE:
;; 		DE = address = 0xC000 + ((y / 8) * 80) + ((y % 8) * &0800) + (x / ppb)
SCREEN_ADDR_START		EQU		&C000
SCREEN_LENGTH			EQU		&4000

.Get_screen_mem_addr:
	LD A,B
	AND &F8
	LD E,A
	RRCA
	RRCA
	ADD A,E
	ADD A,A
	RL B
	ADD A,A
	RL B
	ADD A,A
	RL B
	SRL C
	ADD A,C
	LD E,A
	ADC A,B
	SUB E
	OR SCREEN_ADDR_START / WORD_HIGH_BYTE
	LD D,A
	RET

;; -----------------------------------------------------------------------------------------------------------
clr_screen:
	LD HL,SCREEN_ADDR_START
	LD BC,SCREEN_LENGTH
	JP Erase_forward_Block_RAM

;; -----------------------------------------------------------------------------------------------------------
;; Draw a sprite (or char Symbol), with attributes in A (color style).
;; Source in DE, dest coords in BC, size in HL (H height, L width)
;; Attribute "color style" in A (1 = shadow mode, 3 = color mode)
;; (X measured in double-pixels, centered on &80)
;; Top of screen is Y = 8, for once.
.Draw_Sprite:
	PUSH DE
	PUSH AF
	LD A,&F8
	LD (smc_BlitYOffset_value+1),A
	LD D,B
	LD A,B
	ADD A,H
	LD E,A
	LD (ViewYExtent),DE
	LD A,C
	LD B,C
	ADD A,L
	LD C,A
	LD (ViewXExtent),BC
	LD A,L
	RRCA
	RRCA
	AND &07
	LD C,A
	POP AF
	LD DE,ViewBuff
	CP &03
	CCF
	JR c,drwspr_1
	CP &01
	JR NZ,drwspr_1
	INC D
drwspr_1
	LD A,H
	EX AF,AF'
	LD HL,DestBuff
	CALL Clear_mem_array_256bytes
	EX AF,AF'
	EX DE,HL
	POP DE
drwspr_2
	EX AF,AF'
	LD B,C
drwspr_3
	LD A,(DE)
	LD (HL),A
	EX AF,AF'
	JR NC,drwspr_4
	INC H
	EX AF,AF'
	LD (HL),A
	EX AF,AF'
	DEC H
drwspr_4
	EX AF,AF'
	INC L
	INC DE
	DJNZ drwspr_3
	LD A,6
	SUB C
	ADD A,L
	LD L,A
	EX AF,AF'
	DEC A
	JR NZ,drwspr_2
	CALL Blit_screen
	LD A,Y_START
	LD (smc_BlitYOffset_value+1),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This table will be used to convert a keyboard key code to a printable char or string.
;; (scan line * 8) + bitnb, or can be seen as [7:3]=scan line and [2:0]=bitnb.
;; These are therefore listed in the keyboard scan order: line0 to line9 and bit 0 to 7
;; For instance the &AF (line0, bit6) is related to the string ID &AF ie Print_ENTER
;; whereas the &36 (line6, bit0) is the symbol for "6".
KEPMAP_RETURN			EQU		2 * 8 + 2		;; &12 : line=2, bitnb=2, "Enter/Return" key
KEPMAP_4				EQU		2 * 8 + 4		;; &14 : line=1, bitnb=4, "4" key
KEPMAP_SHIFT			EQU		2 * 8 + 5		;; &15 : line=2, bitnb=5, "Shift" key
KEPMAP_ESC				EQU		8 * 8 + 2		;; &42 : line=8, bitnb=2, "ESC" key

.Char_Set:													;;     bit:  0    1    2   3     4   5    6    7
	DEFB &5E, &60, &5F, &39, &36, &33, &AF, &2E	;; (line 0) "Up", "Right", "Down", "9", "6", "3", "ENTER", "."
	DEFB &61, &A7, &37, &38, &35, &31, &32, &30 ;; line 1 "Left", "COPY", "7", "8", "5", "1", "2", 0"
	DEFB &AE, &5B, &AF, &5D, &34, &A2, &5C, &A6 ;; line 2 "CLR", "[", "|RETURN", "]", "4", "|SHIFT", "\", "CTRL"
	DEFB &5E, &2D, &40, &50, &3B, &3A, &2F, &2E ;; line 3 "^", "-", "@", "P", ";", ":", "/", ","
	DEFB &30, &39, &4F, &49, &4C, &4B, &4D, &2C ;; line 4 "0", "9", "O", "I", "L", "K", "M", "."
	DEFB &38, &37, &55, &59, &48, &4A, &4E, &A0 ;; line 5 "8", "7", "U", "Y", "H", "J", "N", "SPACE"
	DEFB &36, &35, &52, &54, &47, &46, &42, &56 ;; line 6 "6", "5", "R", "T", "G", "F", "B", "V"
	DEFB &34, &33, &45, &57, &53, &44, &43, &58 ;; line 7 "4", "3", "E", "W", "S", "D", "C", "X"
	DEFB &31, &32, &A8, &51, &A3, &41, &A5, &5A ;; line 8 "1", "2", ESC, "Q", TAB, "A", LOCK, "Z"
	DEFB &B9, &BA, &BC, &BB, &B8, &B8, &58, &A4 ;; line 9 JOYU, JOYD, JOYL, JOYR, JOYF, JOYF, (unused), DEL

;; -----------------------------------------------------------------------------------------------------------
;; These are the map codes for the keyboard (CPC 6128) when scanning the
;; keyloard lines, in order to check if the wanted key is pressed or not.
;; For exemple, if, while scanning the keyboard lines, at line1, bit0,
;; (current offset = 1*8 + 0 = 8 (9th value)) the value returned by the
;; AY-3 is "FE", the matching (reg OR map) will result in "FE" (ie. non-FF)
;; indicating that the "Left" arrow key is being pressed. (active low)
;; In other words, if (only) the Right key is pressed, since it corresponds
;; to bit1, the line0 will return &FD (bit1=0, others are 1), hence the &FD
;; at index 1 below, which will match that we want to do "Right" when scanning line0.
.Array_Key_map:		;;		Lft  Rgt  Dwn  Up _ Jmp  Cry  Fir		; line	Left  Rgt   Down  Up   Jump  Carry  Fire
	DEFB &FF, &FD, &FB, &FE, &FF, &0F, &FF		;; 0 :	___ , RGT , DWN , UP , ___ , (*)  , ___   : (*) Carry : Left or Copy or 7 or 8
	DEFB &FE, &FF, &FF, &FF, &FD, &0F, &FF		;; 1 : LEFT , ___ , ___ , ___, Copy, (*)  , ___   : (*) Carry : Left or Copy or 7 or 8
	DEFB &FF, &FF, &FF, &FF, &FF, &EF, &FF		;; 2 :  ___ , ___ , ___ , ___, ___ , CTRL , ___
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; 3 : nothing
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; 4 : nothing
	DEFB &FF, &FF, &FF, &FF, &7F, &7F, &FF		;; 5 :  ___ , ___ , ___ , ___, Spc ,  Spc , ___
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; 6 : nothing
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF		;; 7 : nothing
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FB		;; 8 :  ___ , ___ , ___ , ___, ___ ,  ___ , Esc
	DEFB &FB, &F7, &FD, &FE, &EF, &FF, &FF		;; 9 : JOYL , JOYR, JOYD,JOYU,JOYF ,  ___ , ___

KB_SCAN_LINES			EQU		10

;; -----------------------------------------------------------------------------------------------------------
;; Scan the keyboard;
;; Output: A = 0: a key was pressed;
;;         A != 0: no key pressed;
;; If a key has been pressed, the key map index is in B
;; (B[7:3] = line_number ; B[2:0] = active_bit_number)
.Scan_keyboard:
	LD HL,KeyScanningBuffer
	DI
	CALL Keyboard_scanning_setup
	LD C,PSG_REG_READ and WORD_LOW_BYTE
scan_loop_1
	LD B,PSG_KB_LINESEL / WORD_HIGH_BYTE
	OUT (C),C
	LD B,PSG_PORTA / WORD_HIGH_BYTE
	IN A,(C)
	INC A
	JR NZ,find_key_pressed
	INC HL
	INC C
	LD A,C
	AND &0F
	CP KB_SCAN_LINES
	JR c,scan_loop_1
	CALL Keyboard_scanning_ending
	INC A
	RET

find_key_pressed
	DEC A
	LD BC,&FF * WORD_HIGH_BYTE + &7F
fkp_1
	RLC C
	INC B
	RRA
	JR c,fkp_1
	LD A,L
	SUB &C0
	ADD A,A
	ADD A,A
	ADD A,A
	ADD A,B
	LD B,A
	EXX
	CALL Keyboard_scanning_ending
	EXX
	XOR A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; From a Char_Set key code index in B, get the printable character in A.
;; eg. B = &26 will return A = &4D ("M", keyboard scan line 4 in B[7:3],
;; bitnb=6 in B[2:0], or B=(4*8)+6 = 38 = &26)
.GetCharStrId:
	LD A,B
	ADD A,Char_Set and WORD_LOW_BYTE
	LD L,A
	ADC A,Char_Set / WORD_HIGH_BYTE	 ;; 072A
	SUB L
	LD H,A
	LD A,(HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Check if a key has been pressed and released.
.Wait_anykey_released:
	CALL Scan_keyboard
	JR Z,Wait_anykey_released
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Test if Enter of Shift has been pressed
;; Output: Carry=1 (and NZ): no key pressed, A=non-0
;;    else Carry=0 (and Z) and C=0: Enter, C=1: Shift, C=2: other, A=0
.Test_Enter_Shift_keys:
	CALL Scan_keyboard
	SCF
	RET NZ
	LD A,B
	LD C,0
	CP KEPMAP_RETURN
	RET Z
	INC C
	CP KEPMAP_SHIFT
	RET Z
	INC C
	XOR A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Input: A = key map index we want to point ((scan line * 8) + bitnb)
;; Output: HL : the address of the key map data for the wanted key
.Get_Key_Map_Addr:
	LD DE,Array_Key_map
	LD L,A
	LD H,0
	ADD HL,DE
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Used by the "Controls" Menu to list all assigned keys.
.ListControls:
	CALL Get_Key_Map_Addr
	LD C,0
lc_3
	LD A,(HL)
	LD B,&FF
lc_0
	CP &FF
	JR Z,lc_2
lc_1
	INC B
	SCF
	RRA
	JR c,lc_1
	PUSH HL
	PUSH AF
	LD A,C
	ADD A,B
	PUSH BC
	LD B,A
	CALL GetCharStrId
	CALL PrintCharAttr2
	POP BC
	POP AF
	POP HL
	JR lc_0
lc_2
	LD DE,7			;; 7 keys
	ADD HL,DE
	LD A,C
	ADD A,&08
	LD C,A
	CP &50
	JR c,lc_3
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Used by the "Controls" Menu to Edit the assigned keys.
Edit_control
	CALL Get_Key_Map_Addr
	PUSH HL
	CALL Wait_anykey_released
	LD HL,KeyScanningBuffer
	LD E,&FF
	LD BC,10
	CALL Erase_block_val_in_E
ec_wait
	CALL Scan_keyboard
	JR NZ,ec_wait
	LD A,B
	CP KEPMAP_RETURN
	JR Z,ec_1
ec_0
	LD A,C
	AND (HL)
	CP (HL)
	LD (HL),A
	JR Z,ec_wait
	CALL GetCharStrId
	CALL PrintCharAttr2
	LD HL,(Char_cursor_pixel_position)
	PUSH HL
	LD A,Print_Enter2Finish
	CALL Print_String
	CALL Wait_anykey_released
	POP HL
	LD (Char_cursor_pixel_position),HL
	LD A,&C0
	SUB L
	CP &14			;; KEPMAP_4
	JR NC,ec_wait
ec_1
	EXX
	LD HL,KeyScanningBuffer
	LD A,&FF
	LD B,KB_SCAN_LINES
ec_1_loop
	CP (HL)
	INC HL
	JR NZ,ec_2
	DJNZ ec_1_loop
	EXX
	LD A,&12 		;; KEPMAP_RETURN
	JR ec_0
ec_2
	POP HL
	LD BC,7			;; 7 keys
	LD A,10			;; ??10 lines?
	LD DE,KeyScanningBuffer
ec_3
	EX AF,AF'
	LD A,(DE)
	LD (HL),A
	INC DE
	ADD HL,BC
	EX AF,AF'
	DEC A
	JR NZ,ec_3
	JP Wait_anykey_released

;; -----------------------------------------------------------------------------------------------------------
;; This is used on the "Select the keys" Menu;
;; Note that some of the keys have an attribute attached to them
;; But most keys do not have an attribute attached, so this function
;; will attached a color attribute.
;;   &83 (yellow on that page) for the arrows, the numbers, the dot.
;;        (ie. all keyboard scanline 0 & 1, plus the "4" on scanline 2)
;;   &82 (darkblue) for anything else (again, except if they have an
;;       attribute attached)
;; Input: B = Key scan code index in Char_Set array
;;        A = corresponding printable Character
;; Output: None
.PrintCharAttr2:
	PUSH AF
	LD A,B
	CP KEPMAP_4
	JR Z,pca2_1
	CP &10
	LD A,Print_Color_Attr_2
	JR NC,pca2_2
pca2_1
	LD A,Print_Color_Attr_3
pca2_2
	CALL Print_String
	POP AF
	JP Print_String

;; -----------------------------------------------------------------------------------------------------------
;; Read user inputs, scan the keyboard and returns A so that
;; from MSb to LSb ("CFLRDUJ" format, active low bits):
;; 		bit7:Carry, Fire, Left, Right, Down, Up, bit0: Jump
.Get_user_inputs:
	DI
	CALL Keyboard_scanning_setup
	LD C,PSG_REG_READ and WORD_LOW_BYTE
	LD A,&FF
	LD HL,Array_Key_map
	EX AF,AF'
gui_0
	LD B,PSG_KB_LINESEL / WORD_HIGH_BYTE
	OUT (C),C
	LD B,PSG_PORTA / WORD_HIGH_BYTE
	IN E,(C)
	LD B,7			;; 7 keys, 7 bits per line
gui_1
	LD A,(HL)
	OR E
	CP &FF
	CCF
	RL D
	INC HL
	DJNZ gui_1
	EX AF,AF'
	AND D
	EX AF,AF'
	INC C
	LD A,C
	CP PSG_REG_READ and WORD_LOW_BYTE + KB_SCAN_LINES
	JR c,gui_0
	EX AF,AF'
	OR &80 ;; Head Over heels as a RRCA here
	RRCA
	RRCA
	JR Keyboard_scanning_ending

;; -----------------------------------------------------------------------------------------------------------
;; This will setup the PSG for keyboard scanning
.Keyboard_scanning_setup:
	LD BC,PSG_PORTA + &0E							;; select PSG reg14 (Keyboard Reg)
	OUT (C),C
	LD BC,PSG_KB_LINESEL							;; prepare PSG Control (Keyboard feature)
	LD A,PSG_REG_SEL and WORD_LOW_BYTE				;; line 0 + &C0
	OUT (C),A										;; PSG control : reg select (reg value on portA = reg14)
	OUT (C),C										;; Validate
	INC B											;; Port Control BC=F700 : PSG_PORTCTRL
	LD A,PSG_PORTA_IN and WORD_LOW_BYTE				;; Port A in, Port C out
	OUT (C),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will end the keyboard scanning in the PSG
Keyboard_scanning_ending:
	LD BC,PSG_PORTA_OUT
	OUT (C),C
	LD BC,PSG_INACTIVE
	OUT (C),C
	EI
	RET

;; -----------------------------------------------------------------------------------------------------------
	DEFB 0		;; ref note
	DEFB 9
	DEFB 0		;; envp num
silence_sound
	DEFB 0
	DEFB &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 0		;; envp num
sound_walk
	DEFB 0
	DEFB &81, &B9, &A1, &E1, &FF, &00

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 0		;; envp num
sound_run
	DEFB 0
	DEFB &80, &B8, &A0, &E0, &FF, &00

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 0		;; envp num
sound_todo_1
	DEFB 0
	DEFB &81, &79, &69, &59, &49, &41, &FF, &00

;; -----------------------------------------------------------------------------------------------------------
	DEFB 30		;; ref note
	DEFB 8
	DEFB 4		;; envp num
sound_todo_2
	DEFB 0
	DEFB &30, &50, &68, &90, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 1
	DEFB 6		;; envp num
sound_todo_3
	DEFB 0
	DEFB &54, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 0		;; envp num
sound_todo_4
	DEFB 0
	DEFB &10, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 4		;; envp num
sound_blip
	DEFB 0
	DEFB &18, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 30		;; ref note
	DEFB 8
	DEFB 4		;; envp num
sound_todo_5
	DEFB 0
	DEFB &A2, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 18		;; ref note
	DEFB 8
	DEFB 2		;; envp num
sound_fly
	DEFB 0
	DEFB &11, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 30		;; ref note
	DEFB 8
	DEFB 4		;; envp num
sound_jump
	DEFB 0
	DEFB &30, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_pickupsong_voice0
	DEFB 0
	DEFB &6A, &8A, &6A, &AA, &92, &AA, &D3, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 30		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_pickupsong_voice1
	DEFB 0
	DEFB &3A, &5A, &3A, &7A, &62, &7A, &AB, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_pickupsong_voice2
	DEFB 0
	DEFB &42, &62, &42, &82, &6A, &82, &AB, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 25		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_deadlysong_voice0
	DEFB 0
	DEFB &92, &8A, &6A, &83, &00, &2A, &32, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_deadlysong_voice1
	DEFB 0
	DEFB &7A, &72, &52, &6B, &00, &12, &1A, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_deadlysong_voice2
	DEFB 0
	DEFB &92, &8A, &6A, &83, &00, &2A, &32, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 28		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_bmsong_voice0
	DEFB 0
	DEFB &32, &32, &2A, &2A, &12, &12, &2A, &2A, &32, &32, &2A, &2A, &12, &12, &2A, &2A
	DEFB &5A, &5A, &52, &52, &4A, &4A, &52, &52, &5A, &5A, &52, &52, &4A, &4A, &52, &52
	DEFB &32, &32, &2A, &2A, &12, &12, &2A, &2A, &93, &05, &94, &97, &07, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 20		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_bmsong_voice1
	DEFB 0
	DEFB &24, &24, &24, &24, &24, &24, &24, &24, &4C, &4C, &4C, &4C, &4C, &4C, &4C, &4C
	DEFB &5C, &5C, &84, &5C, &73, &05, &74, &77, &07, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
	DEFB 30		;; ref note
	DEFB 8
	DEFB 7		;; envp num
hq_bmsong_voice2
	DEFB 0
	DEFB &8A, &8A, &82, &82, &7A, &7A, &82, &82, &8A, &8A, &82, &82, &7A, &7A, &82, &82
	DEFB &B2, &B2, &AA, &AA, &A2, &A2, &AA, &AA, &B2, &B2, &AA, &AA, &A2, &A2, &AA, &AA
	DEFB &92, &92, &8A, &8A, &82, &82, &8A, &8A, &33, &05, &34, &37, &07, &FF, &FF

;; -----------------------------------------------------------------------------------------------------------
Play_Batman_Theme
	CALL Check_volume_amount	;; if Sound_amount = 0 ("late at night") silence it, else
	XOR A						;; V0
	LD HL,hq_bmsong_voice0
	CALL Snd_Play				;; play
	LD A,1						;; V1
	LD HL,hq_bmsong_voice1
	CALL Snd_Play				;; play
	LD A,2						;; V2
	LD HL,hq_bmsong_voice2
	JP PlayVoice				;; play

GetSpecialSong
	CALL Check_volume_amount	;; if Sound_amount = 0 ("late at night") silence it, else
	XOR A       				;; V0
	LD HL,hq_pickupsong_voice0
	CALL Snd_Play   			;; play
	LD A,1    	  				;; V1
	LD HL,hq_pickupsong_voice1
	CALL Snd_Play   			;; play
	LD A,2    					;; V2
	LD HL,hq_pickupsong_voice2
	JR PlayVoice		  		;; play

DeadlyContactSong
	CALL Check_volume_amount    ;; if Sound_amount = 0 ("late at night") silence it, else
	XOR A        				;; V0
	LD HL,hq_deadlysong_voice0
	CALL Snd_Play   			;; play
	LD A,1       				;; V1
	LD HL,hq_deadlysong_voice1
	CALL Snd_Play    			;; play
	LD A,2       				;; V2
	LD HL,hq_deadlysong_voice2
	;; flows in PlayVoice
PlayVoice
	JR Snd_Play_curr_voice

;; -----------------------------------------------------------------------------------------------------------
;; *****
Sound_ID_Todo_3
	LD HL,sound_todo_3
	DEFB LDIX_OPCODE			;; LD IX,&095A
;; *****
Sound_ID_Todo_4
	LD HL,sound_todo_4			;; this instruction is cancelled if comming from 0A99
	CALL Check_volume_amount	;; if Sound_amount = 0 ("late at night") silence it, else
	PUSH HL
	CALL HasVoice1DataToPlay
	POP HL
	RET NZ
	LD A,1
	JR Snd_Play_curr_voice

;; -----------------------------------------------------------------------------------------------------------
Sound_ID_Silence
	LD HL,silence_sound
	CALL Snd_Play_voice0
	LD HL,silence_sound
	JR Snd_Play_voice2

;; -----------------------------------------------------------------------------------------------------------
Sound_ID_WalkRun
	LD HL,sound_walk
	LD A,(Counter_speed)
	AND A
	JR Z,playsnd
	LD HL,sound_run
	DEFB LDIX_OPCODE			;; LD IX,&0949
;; *****
Sound_ID_Todo_2
	LD HL,sound_todo_2			;; this instruction is cancelled if comming from 0AC4
	DEFB LDIX_OPCODE			;; LD IX,&093D
;; *****
Sound_ID_Todo_1
	LD HL,sound_todo_1			;; this instruction is cancelled if comming from 0AC5

playsnd
	CALL Check_volume_amount
	RET Z
Snd_Play_voice0
	XOR A
Snd_Play_curr_voice:
	JP Snd_Play

;; -----------------------------------------------------------------------------------------------------------
Sound_ID_Fly
	LD HL,sound_fly
	DEFB LDIX_OPCODE			;; LD IX,&0976
Sound_ID_PickUp
Sound_ID_Jump
	LD HL,sound_jump			;; this instruction is cancelled if comming from 0AD4
	DEFB LDIX_OPCODE			;; LD IX,&0961
Sound_ID_Menu_Blip
	LD HL,sound_blip			;; this instruction is cancelled if comming from 0AD8
	DEFB LDIX_OPCODE			;; LD IX,&0968
;; *****
Sound_ID_Todo_5
	LD HL,sound_todo_5			;; this instruction is cancelled if comming from 0ADC
	CALL Check_volume_amount
Snd_Play_voice2
	LD A,2
	JR Snd_Play_curr_voice

;; -----------------------------------------------------------------------------------------------------------
;; AY-3-8912 registers:
AY_A_FINE				EQU 	&00			;; Channel A fine pitch    8-bit (0-255)
AY_A_COARSE				EQU 	&01			;; Channel A coarse pitch  4-bit (0-15)
AY_B_FINE				EQU 	&02			;; Channel B fine pitch    8-bit (0-255)
AY_B_COARSE				EQU 	&03			;; Channel B coarse pitch  4-bit (0-15)
AY_C_FINE				EQU 	&04			;; Channel C fine pitch    8-bit (0-255)
AY_C_COARSE				EQU 	&05			;; Channel C coarse pitch  4-bit (0-15)
AY_NOISE				EQU 	&06			;; Noise pitch             5-bit (0-31)
AY_MIXER				EQU 	&07			;; Mixer                   8-bit
AY_A_VOL				EQU 	&08			;; Channel A volume        4-bit (0-15)
AY_B_VOL				EQU 	&09			;; Channel B volume        4-bit (0-15)
AY_C_VOL				EQU 	&0A			;; Channel C volume        4-bit (0-15)

SONG_PTR				EQU		5

;; -----------------------------------------------------------------------------------------------------------
Voice_0_data
	DEFB 0			;; +0	; voice nb
	DEFB 0			;; +1	; duration offset
	DEFB 0			;; +2	;
	DEFB 0			;; +3 	; envp ???
	DEFB 0			;; +4 	; note offset
	DEFW silence_sound      ;; +5&6 SONG_PTR

Voice_1_data
	DEFB 1			;; +0
	DEFB 0			;; +1
	DEFB 0			;; +2
	DEFB 0			;; +3
	DEFB 0			;; +4
	DEFW silence_sound     ;; +5&6 SONG_PTR

Voice_2_data
	DEFB 2			;; +0
	DEFB 0			;; +1
	DEFB 0			;; +2
	DEFB 0			;; +3
	DEFB 0			;; +4
	DEFW silence_sound      ;; +5&6 SONG_PTR

;; -----------------------------------------------------------------------------------------------------------
Mixer_control
	DEFB &3F

Envelope_array:
	DEFB 3, 7, 7, 6, 4, 2, 1, 0		;; enveloppe
Duration_array:
	DEFB 3, 5, 7, 11, 15, 23, 31, 47 ;; duration fast to slow

;; -----------------------------------------------------------------------------------------------------------
Notes_array
	DEFW &0777 ;; id &00 : do oct -2 ; 65.4Hz 1911
	DEFW &070C ;; id &01 : do# oct -2 ; 69.3Hz 1804
	DEFW &06A7 ;; id &02 : re
	DEFW &0647 ;; id &03 : re#
	DEFW &05ED ;; id &04 : mi
	DEFW &0598 ;; id &05 : fa
	DEFW &0547 ;; id &06 : fa#
	DEFW &04FC ;; id &07 : sol
	DEFW &04D4 ;; id &08 : sol#
	DEFW &0470 ;; id &09 : la
	DEFW &0431 ;; id &0A : la#
	DEFW &03F4 ;; id &0B : si
	DEFW &03BC ;; id &0C : do oct -1
	DEFW &0386 ;; id &0D : do#
	DEFW &0353 ;; id &0E : re
	DEFW &0324 ;; id &0F : re#
	DEFW &02F6 ;; id &10 : mi
	DEFW &02CC ;; id &11 : fa
	DEFW &02A4 ;; id &12 : fa#
	DEFW &027E ;; id &13 : sol
	DEFW &025A ;; id &14 : sol#
	DEFW &0238 ;; id &15 : la
	DEFW &0218 ;; id &16 : la#
	DEFW &01FA ;; id &17 : si
	DEFW &01DE ;; id &18 : do oct 0
	DEFW &01C3 ;; id &19 : do#
	DEFW &01AA ;; id &1A : re
	DEFW &0192 ;; id &1B : re#
	DEFW &017B ;; id &1C : mi
	DEFW &0166 ;; id &1D : fa
	DEFW &0152 ;; id &1E : fa#
	DEFW &013F ;; id &1F : sol
	DEFW &012D ;; id &20 : sol#
	DEFW &011C ;; id &21 : la
	DEFW &010C ;; id &22 : la#
	DEFW &00FD ;; id &23 : si
	DEFW &00EF ;; id &24 : do oct 1
	DEFW &00E1 ;; id &25 : do#
	DEFW &00D5 ;; id &26 : re
	DEFW &00C9 ;; id &27 : re#
	DEFW &00BE ;; id &28 : mi
	DEFW &00B3 ;; id &29 : fa
	DEFW &00A9 ;; id &2A : fa#
	DEFW &009F ;; id &2B : sol
	DEFW &0096 ;; id &2C : sol#
	DEFW &008E ;; id &2D : la
	DEFW &0086 ;; id &2E : la#
	DEFW &007F ;; id &2F : si
	DEFW &0077 ;; id &30 : do oct 2
	DEFW &0071 ;; id &31 : do#
	DEFW &006A ;; id &32 : re
	DEFW &0064 ;; id &33 : re#
	DEFW &005F ;; id &34 : mi
	DEFW &0059 ;; id &35 : fa
	DEFW &0054 ;; id &36 : fa#
	DEFW &0050 ;; id &37 : sol
	DEFW &004B ;; id &38 : sol#
	DEFW &0047 ;; id &39 : la
	DEFW &0043 ;; id &3A : la#
	DEFW &003F ;; id &3B (59) ; si oct2 1975.5Hz

;; -----------------------------------------------------------------------------------------------------------
Snd_Play
	LD IX,Voice_0_data
	EX DE,HL				;;
	AND A					;; test voice 0
	JR Z,Snd_Program		;; if so, play
	DEC A					;; test voice 1
	LD IX,Voice_1_data
	JR Z,Snd_Program		;; if so play
	LD IX,Voice_2_data 		;; else voice2
Snd_Program
	LD L,(IX+SONG_PTR)
	LD H,(IX+SONG_PTR+1)	;; HL = pointer on current song data
	XOR A					;; clear Carry and reset byte pointer to 0
	SBC HL,DE				;; diff HL and DE
	RET Z					;; if they were equal, leave
	LD (DE),A				;; else 1st byte is voice num ## &09CB
	DI
	LD (IX+SONG_PTR),E		;; ## IX=&0AEA (v0), &0AF1 (v1), &0A1D (v2)
	LD (IX+SONG_PTR+1),D
	LD (IX+1),A				;; byte pointer reset
	EI
	RET

;; -----------------------------------------------------------------------------------------------------------
Silence_all_Voices:
	LD HL,silence_sound
	LD (Voice_0_data+SONG_PTR),HL
	LD (Voice_1_data+SONG_PTR),HL
	LD (Voice_2_data+SONG_PTR),HL
	RET

;; -----------------------------------------------------------------------------------------------------------
sub_IntH_play_update
	LD IY,Voice_0_data
	LD B,3					;; 3 voices
pu_loopv
	LD L,(IY+SONG_PTR)
	LD H,(IY+SONG_PTR+1)
	PUSH HL
	POP IX					;; ## 09CB
	PUSH BC					;; ## 032F
	CALL &0BDB
	POP BC					;; ## 032F
	LD DE,7					;; length of data array
	ADD IY,DE				;; next Voice_x_data
	DJNZ pu_loopv			;; loop all voices
	RET

;; -----------------------------------------------------------------------------------------------------------
	LD A,(IY+1)				;; ## 0AEA get byte pointer
	AND A
	JP NZ,&0C84				;; not 0 (already started), jump 0c84

	PUSH IX					;; else, starting
	POP HL					;; ## &09CB
	INC (HL) 				;; point on next data
	LD A,(HL)				;; read data
	ADD A,L
	LD L,A
	ADC A,H
	SUB L
	LD H,A					;; HL = HL + A (byte nb)
	LD A,(HL)				;; read song note
	CP &FF
	JR NZ,&0C1A				;; not &FF, jump
	INC HL					;; else read next byte
	CP (HL)					;; CP avec un 2eme &FF
	JR Z,&0BFB				;; if &FF jump (end) 0BFB
	LD (IX+0),0
	JR &0BE2

	LD HL,silence_sound
	LD (HL),0
	LD (IY+SONG_PTR),L
	LD (IY+SONG_PTR+1),H

	LD A,(IY+3)
	AND A
	RET Z
	DEC (IY+3)

	LD E,(IY+3)	;; AY3 value
	LD A,(IY+0)	;; voice num
	ADD A,&08
	LD D,A	     ;; AY3 reg (8: AY_A_VOL, 9: AY_B_VOL, 10: AY_C_VOL)
	JP SubF_Write_AY3Reg

	LD C,A		;; data ##&32 = 6 (offset from refnote) << 3 + 2 (duration index)
	AND &07		;; 1st song byte [7:3] ; [2:0]=idx Duration_array array array(2) = 7
	LD E,A
	LD D,0
	LD HL,Duration_array
	ADD HL,DE
	LD A,(HL)
	LD (IY+1),A			;; &0AEA+1
	LD A,C				;; first byte data
	AND &F8
	RRCA
	RRCA
	RRCA				;; [7:3] >> 3 put [7:3] as [4:0]
	LD (IY+4),A 		;; offset note = &30 >> 3 = 6
	JR Z,&0C06
	ADD A,(IX-3) 		;; refnote	## &09CB-3 = &1C+6 = &22
	LD L,A				;; ## HL = &22
	LD H,0
	ADD HL,HL   		;; HL = 2*A ## &44
	LD DE,Notes_array
	ADD HL,DE			;; HL = Notes_array + 2*index # &0B54
	LD E,(HL)  			;; AY3 value ## &0C
	INC HL
	LD H,(HL) 			;; AY3 next value  ## &0155
	LD A,(IY+0)			;; voice num
	ADD A,A				;; voice num x2
	LD D,A     			;; AY3 reg (0 : AY_A_FINE, 2 : AY_B_FINE or 4 : AY_C_FINE)
	CALL SubF_Write_AY3Reg
	INC D				;; next AY3 reg (0 : AY_A_COARSE, 2 : AY_B_COARSE or 4 : AY_C_COARSE)
	LD E,H				;; AY3 value
	CALL SubF_Write_AY3Reg
	LD (IY+2),0			;; &0AEA+2
	LD B,(IY+0)			;;
	INC B
	LD A,(IX-2)			;; &09CB-2 ##8
	RRCA				;; >> 1
	LD C,&84

mixerset
	RLCA				;; << 1
	RLC C				;; &09
	DJNZ mixerset
	LD HL,Mixer_control
	XOR (HL)    		;; &37
	AND C				;; &01
	XOR (HL)			;; &3E
	LD (HL),A
	LD E,A				;; AY3 value
	LD D,7				;; AY3 reg : AY_MIXER ; D/E=&07/&3E en voice0
	CALL SubF_Write_AY3Reg

	LD A,(IY+2)			;; &0AEA ## 0
	CP &08
	RET NC
	LD L,A
	LD H,0				;; idx b00 = 0
	LD DE,Envelope_array
	ADD HL,DE			;; HL = &0B00 + A
	LD A,(HL)			;; value 3
	ADD A,(IX-1)		;; &09CB-1
	LD (IY+3),A			;; &0aea+3
	JR &0C0E

	DEC (IY+1)
	LD A,(IY+4)
	AND A
	JP Z,&0C06
	INC (IY+2)
	JR &0C6E

;; -----------------------------------------------------------------------------------------------------------
;; Sub function for Write_AY3_Registers (write one AY-3 reg)
;; Input: D = reg number, E = value
.SubF_Write_AY3Reg:
	LD B,PSG_PORTA	/ WORD_HIGH_BYTE
	OUT (C),D
	LD BC,PSG_INACTIVE
	LD A,PSG_REG_SEL and WORD_LOW_BYTE
	OUT (C),A
	OUT (C),C
	LD A,PSG_REG_WRITE and WORD_LOW_BYTE
	LD B,PSG_PORTA / WORD_HIGH_BYTE
	OUT (C),E
	LD B,PSG_PORTC / WORD_HIGH_BYTE
	OUT (C),A
	OUT (C),C
	RET

;; -----------------------------------------------------------------------------------------------------------
Check_volume_amount
	LD A,(Sound_amount)
	CP &01			;; amount 1 or 2, ret NC
	RET NC
	POP HL			;; else Silence
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Returns Zero if nothing to play, NZ if something to play on voice 1
HasVoice1DataToPlay
	LD HL,(Voice_1_data+SONG_PTR)
	LD DE,silence_sound
	AND A
	SBC HL,DE
	RET

;; -----------------------------------------------------------------------------------------------------------
;; BlitMaskNofM does a masked blit into a dest buffer assumed 6 bytes wide.
;; The blit is from a source N bytes wide in a buffer M bytes wide.
;; The height is in B.
;; Destination is BC', source image is in DE', mask is in HL'.
BlitMask1of3
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,6
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask1of3
	RET

BlitMask2of3
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,5
	LD C,A
	INC HL
	INC DE
	EXX
	DJNZ BlitMask2of3
	RET

BlitMask3of3
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,4
	LD C,A
	EXX
	DJNZ BlitMask3of3
	RET

BlitMask1of4
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,6
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask1of4
	RET

BlitMask2of4
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,5
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask2of4
	RET

BlitMask3of4
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,4
	LD C,A
	INC HL
	INC DE
	EXX
	DJNZ BlitMask3of4
	RET

BlitMask4of4
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	INC C
	INC C
	INC C
	EXX
	DJNZ BlitMask4of4
	RET

BlitMask1of5
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,6
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask1of5
	RET

BlitMask2of5
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,5
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask2of5
	RET

BlitMask3of5
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	LD A,C
	ADD A,4
	LD C,A
	INC HL
	INC DE
	INC HL
	INC DE
	EXX
	DJNZ BlitMask3of5
	RET

BlitMask4of5
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	INC C
	INC C
	INC C
	INC HL
	INC DE
	EXX
	DJNZ BlitMask4of5
	RET

BlitMask5of5
	EXX
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC C
	INC HL
	INC DE
	LD A,(BC)
	AND (HL)
	EX DE,HL
	OR (HL)
	LD (BC),A
	INC B
	LD A,(BC)
	OR (HL)
	EX DE,HL
	AND (HL)
	LD (BC),A
	DEC B
	INC HL
	INC DE
	INC C
	INC C
	EXX
	DJNZ BlitMask5of5
	RET

;; -----------------------------------------------------------------------------------------------------------
;; When we need to draw pillar sprites below a Door, this is the height of the pillars.
;; In multiples of 6.
.PillarHeight:
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; Re-fills the Pillar sprite buffer. Preserves 16b registers.
.FillPillarBuf:
	PUSH DE
	PUSH BC
	PUSH HL
	LD A,(PillarHeight)
	CALL DrawPillarBuf
	POP HL
	POP BC
	POP DE
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Redraws the Pillar in PillarBuf, pillar height in A.
;; In function of the height, the middle part will be stacked as many times as needed
;; Output: pointer on result sprite in DE.
.SetPillarHeight:
	LD (PillarHeight),A
DrawPillarBuf
	PUSH AF
	LD HL,PillarBuf + MOVE_OFFSET ;; B768
	LD BC,PILLARBUF_LENGTH
	CALL Erase_forward_Block_RAM
	XOR A
	LD (IsPillarBufFlipped),A
	DEC A
	LD (hasPillarUnderDoor),A
	POP AF
	AND A
	RET Z
	LD DE,PillarBuf + PILLARBUF_LENGTH - 1 + MOVE_OFFSET
	PUSH AF
	CALL drawPillarBtm
drawPillarLoop
	POP AF
	SUB 6
	JR Z,drawPillarTop
	PUSH AF
	CALL drawPillarMid
	JR drawPillarLoop

drawPillarTop
	LD HL,img_pillar_top + &48 - 1 + MOVE_OFFSET ;; B6D0-B717
	LD BC,&48
	JR drawPillarReverseCopy
drawPillarMid
	LD HL,img_pillar_mid + &30 - 1 + MOVE_OFFSET ;; B718-B747
	LD BC,&30
	JR drawPillarReverseCopy
drawPillarBtm
	LD HL,img_pillar_btm + &20 - 1 + MOVE_OFFSET ;; B748-B767
	LD BC,&20
drawPillarReverseCopy
	LDDR
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given extents stored in ViewXExtent and ViewYExtent,
;; draw the appropriate piece of screen background into
;; ViewBuff (to be drawn over and blitted to display later)
;; Buffer to write to is assumed to be 6 bytes wide.
.DrawBkgnd:
	LD HL,(ViewXExtent)
	LD A,H
	RRA
	RRA
	LD C,A
	AND &3E
	EXX
	LD L,A
	LD H,BackgrdBuff / WORD_HIGH_BYTE ;; 50
	EXX
	LD A,L
	SUB H
	RRA
	RRA
	AND &07
	SUB 2
	LD DE,DestBuff
	RR C
	JR NC,dbg_1
	LD IY,ClearOne
	LD IX,OneColBlitR
	LD HL,BlitFloorR
	CALL DrawBkgndCol
	CP &FF
	RET Z
	SUB 1
	JR dbg_2
dbg_1
	LD IY,ClearTwo
	LD IX,TwoColBlit
	LD HL,BlitFloor
	CALL DrawBkgndCol
	INC E
	SUB 2
dbg_2
	JR NC,dbg_1
	INC A
	RET NZ
	LD IY,ClearOne
	LD IX,OneColBlitL
	LD HL,BlitFloorL
	LD (smc_blitfloor_fnptr+1),HL
	EXX
	JR DrawBkgndCol2

;; -----------------------------------------------------------------------------------------------------------
;; ???TODO??? Performs register-saving and incrementing HL'/E. Not needed
;; for the last call from DrawBkgnd.
.DrawBkgndCol:
	LD (smc_blitfloor_fnptr+1),HL
	PUSH DE
	PUSH AF
	EXX
	PUSH HL
	CALL DrawBkgndCol2
	POP HL
	INC L
	INC L
	EXX
	POP AF
	POP DE
	INC E
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Reads from ViewYExtent
;; * Takes in:
;;   HL' - Floor drawing function
;;   DE' - Destination buffer (only modified via IX, IY, etc.)
;;   IX  - Copying function (takes &rows in A, writes to DE' and updates it)
;;   IY  - Clearing function (takes &rows in A, writes to DE' and updates it)
;;   HL  - Pointer to BackgrdBuff array entry:
;;           Byte 0: Y of wall bottom (0 = clear)
;;           Byte 1: Id for wall panel sprite
;;                   (0-3 - world-specific, 4 - Pillar, 5 - blank, | &80 to flip)
;; Note that the Y coordinates are downward-increasing, matching memory.
;; The basic walls are 56 pixels high
SHORT_WALL     			EQU 	56				;; &38
;; Pillar/spaces (indices 4 and 5) are up to 74 pixels high, made up
;; of top, repeated middle and bottom section.
TALL_WALL	      		EQU 	74				;; &4A =  (9 + 24 + 4) * 2
EDGE_HEIGHT				EQU 	&0B

DrawBkgndCol2
	LD DE,(ViewYExtent)
	LD A,E
	SUB D
	LD E,A
	LD A,(HL)
	AND A
	JR Z,DBC_Clear
	LD A,D
	SUB (HL)
	LD D,A
	JR NC,DBC_DoFloor
	INC HL
	LD C,SHORT_WALL
	BIT 2,(HL)
	JR Z,dbcflag
	LD C,TALL_WALL
dbcflag
	ADD A,C
	JR NC,DBC_TopSpace
	ADD A,A
	CALL GetOffsetWall
	EXX
	LD A,D
	NEG
	JP DBC_Wall

;; We start before the top of the wall panel, so we'll start off by clearing above.
;; A holds -number of rows to top of wall panel, E holds number of rows to write.
.DBC_TopSpace:
	NEG
	CP E
	JR NC,DBC_Clear
	LD B,A
	NEG
	ADD A,E
	LD E,A
	LD A,B
	CALL DoJumpIY
	LD A,(HL)
	EXX
	CALL GetWall
	EXX
	LD A,SHORT_WALL
	BIT 2,(HL)
	JR Z,DBC_Wall
	LD A,TALL_WALL
DBC_Wall
	CP E
	JR NC,dbc_copy
	LD B,A
	NEG
	ADD A,E
	EX AF,AF'
	LD A,B
	CALL DoJumpIX
	EX AF,AF'
	LD D,0
	JR DBC_FloorEtc
dbc_copy
	LD A,E
	JP (IX)
DBC_Clear
	LD A,E
	JP (IY)

;; Point we jump to if we're initially below the top edge of the floor.
.DBC_DoFloor:
	LD A,E
	INC HL
;; Code to draw the floor, bottom edge, and any space below
;;
;; At this point, HL has been incremented by 1, A contains
;; number of rows to draw, D contains number of lines below
;; bottom of wall we're at.
;; First, calculate the position of the bottom edge.
.DBC_FloorEtc:
	LD B,A
	DEC HL
	LD A,L
	ADD A,A
	ADD A,A
	ADD A,4
smc_CornerPos:
	CP 0
	JR c,DBC_Left
	LD E,0
	JR NZ,DBC_Right
	LD E,DBEdge_Center - DBEdge_Right
DBC_Right
	SUB 4
.smc_RightAdj:
	ADD A,0
	JR DBC_CrnrJmp
DBC_Left
	ADD A,4
	NEG
.smc_LeftAdj:
	ADD A,0
	LD E,DBEdge_Left - DBEdge_Right
;; Store coordinate of bottom edge in C, write out edge graphic
.DBC_CrnrJmp:
	NEG
	ADD A,EDGE_HEIGHT
	LD C,A
	LD A,E
	LD (smc_whichEdge+1),A
	LD A,(HL)
	ADD A,D
	INC HL
	SUB C
	JR NC,subclr
	ADD A,EDGE_HEIGHT
	JR NC,dbcfloor
	LD E,A
	SUB EDGE_HEIGHT
	ADD A,B
	JR c,DBC_AllBottom
	LD A,B
	JR DrawBottomEdge
;; Case where we're drawing
.DBC_AllBottom:
	PUSH AF
	SUB B
	NEG
DBC_Bottom
	CALL DrawBottomEdge
	POP AF
	RET Z
	JP (IY)
subclr
	LD A,B
	JP (IY)
dbcfloor
	ADD A,B
	JR c,DBC_FloorNEdge
	LD A,B
BlitFloorFnPtr:
smc_blitfloor_fnptr:
	JP NULL_PTR
;; Draw the floor and then edge etc.
.DBC_FloorNEdge:
	PUSH AF
	SUB B
	NEG
	CALL BlitFloorFnPtr
	POP AF
	RET Z
	SUB EDGE_HEIGHT
	LD E,0
	JR NC,DBC_EdgeNSpace
	ADD A,EDGE_HEIGHT
	JR DrawBottomEdge
DBC_EdgeNSpace
	PUSH AF
	LD A,EDGE_HEIGHT
	JR DBC_Bottom
DrawBottomEdge
	PUSH DE
	EXX
	POP HL
	LD H,0
	ADD HL,HL
	ADD HL,HL
	LD BC,LeftEdge
smc_whichEdge:
	JR DBEdge_Left
DBEdge_Right:
	LD BC,RightEdge
	JR DBEdge_Left
DBEdge_Center:
	LD BC,CornerEdge
DBEdge_Left
	ADD HL,BC
	EXX
	JP (IX)

;; -----------------------------------------------------------------------------------------------------------
;; Data to draw the edge of the rooms
LeftEdge
	;; 4 bytes * 11  interlaced :
	;;     2 bytes x 11 (height) mask and
	;;     2 bytes x 11 for image
	;; in memory : maskwall1 + wall1 + maskwall2 + wall2 (each are 1byte wide * 11 rows)
	DEFB &00, &40, &00, &00, &00, &70, &00, &00, &00, &74, &00, &00, &00, &77, &00, &00
	DEFB &00, &37, &00, &40, &00, &07, &00, &70, &00, &03, &00, &74, &00, &00, &00, &77
	DEFB &00, &00, &00, &37, &00, &00, &00, &07, &00, &00, &00, &03
	;;	................ .@..............
	;;	................ .@@@............
	;;	................ .@@@.@..........
	;;	................ .@@@.@@@........
	;;	................ ..@@.@@@.@......
	;;	................ .....@@@.@@@....
	;;	................ ......@@.@@@.@..
	;;	................ .........@@@.@@@
	;;	................ ..........@@.@@@
	;;	................ .............@@@
	;;	................ ..............@@
RightEdge
	DEFB &00, &00, &03, &03, &00, &00, &0F, &07, &00, &00, &3F, &37, &00, &00, &FF, &77
	DEFB &03, &03, &FC, &74, &0F, &07, &F0, &70, &3F, &37, &C0, &40, &FF, &77, &00, &00
	DEFB &FC, &74, &00, &00, &F0, &70, &00, &00, &C0, &40, &00, &00

	;;	..............@@ ..............@@
	;;	............@@@@ .............@@@
	;;	..........@@@@@@ ..........@@.@@@
	;;	........@@@@@@@@ .........@@@.@@@
	;;	......@@@@@@@@.. ......@@.@@@.@..
	;;	....@@@@@@@@.... .....@@@.@@@....
	;;	..@@@@@@@@...... ..@@.@@@.@......
	;;	@@@@@@@@........ .@@@.@@@........
	;;	@@@@@@.......... .@@@.@..........
	;;	@@@@............ .@@@............
	;;	@@.............. .@..............
CornerEdge
	DEFB &00, &40, &03, &03, &00, &70, &0F, &07, &00, &74, &3F, &37, &00, &77, &FF, &77
	DEFB &00, &37, &FC, &74, &00, &07, &F0, &70, &00, &03, &C0, &40, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00

	;;	..............@@ .@............@@
	;;	............@@@@ .@@@.........@@@
	;;	..........@@@@@@ .@@@.@....@@.@@@
	;;	........@@@@@@@@ .@@@.@@@.@@@.@@@
	;;	........@@@@@@.. ..@@.@@@.@@@.@..
	;;	........@@@@.... .....@@@.@@@....
	;;	........@@...... ......@@.@......
	;;	................ ................
	;;	................ ................
	;;	................ ................
	;;	................ ................

;; -----------------------------------------------------------------------------------------------------------
;; Takes the room origin in BC, and stores it, and then updates the edge patterns
;; to include a part of the floor pattern.
.TweakEdges:
	LD HL,(FloorAddr)
	LD BC,2*5
	ADD HL,BC
	LD C,2*8
	LD A,(Has_Door)
	RRA
	PUSH HL
	JR NC,txedg_1
	ADD HL,BC
	EX (SP),HL
txedg_1
	ADD HL,BC
	RRA
	JR NC,txedg_2
	AND A
	SBC HL,BC
txedg_2
	LD DE,RightEdge
	CALL TweakEdgesInner
	POP HL
	INC HL
	LD DE,LeftEdge+2
TweakEdgesInner
	LD A,4
tei_1
	LDI
	INC HL
	INC DE
	INC DE
	INC DE
	DEC A
	JR NZ,tei_1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Wrap up a call to GetWall, and add in the starting offset from A.
;; TODO
.GetOffsetWall:
	PUSH AF
	LD A,(HL)
	EXX
	CALL GetWall
	POP AF
	ADD A,A
	PUSH AF
	ADD A,L
	LD L,A
	ADC A,H
	SUB L
	LD H,A
	POP AF
	RET NC
	INC H
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Zero means Pillar buffer is zeroed, non-zero means filled with Pillar image.
hasPillarUnderDoor:
	DEFB 0

;; Returns PillarBuf in HL.
;; If hasPillarUnderDoor is non-zero, it zeroes the buffer, and the flag.
.GetEmptyPillarBuf:
	LD A,(hasPillarUnderDoor)
	AND A
	LD HL,PillarBuf + MOVE_OFFSET
	RET Z
	PUSH HL
	PUSH BC
	PUSH DE
	LD BC,PILLARBUF_LENGTH
	CALL Erase_forward_Block_RAM
	POP DE
	POP BC
	POP HL
	XOR A
	LD (hasPillarUnderDoor),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Called by GetWall for high-index sprites, to draw the space under a door
;;   A=5 -> blank space, A=4 -> Pillars
.GetUnderDoor:
	BIT 0,A
	JR NZ,GetEmptyPillarBuf
	LD L,A
	LD A,(hasPillarUnderDoor)
	AND A
	CALL Z,FillPillarBuf
	LD A,(IsPillarBufFlipped)
	XOR L
	RLA
	LD HL,PillarBuf + MOVE_OFFSET
	RET NC
	LD A,(IsPillarBufFlipped)
	XOR &80
	LD (IsPillarBufFlipped),A
	LD B,TALL_WALL
	JP FlipPillar

;; -----------------------------------------------------------------------------------------------------------
;; Get a wall section/panel (id 0 to 3, cases 4 and 5 are the space under
;; a door (blank or pillars) and handled by GetUnderDoor).
;; In A : 0-3 - world-specific, 4 - Pillar, 5 - blank, + &80 to flip.
;; Top bit represents whether flip is required.
;; Return: Pointer to data in HL. Panel id in A, Carry if flip required
.GetWall:
	BIT 2,A
	JR NZ,GetUnderDoor
	PUSH AF
	CALL NeedsFlip2
	EX AF,AF'
	POP AF
	CALL GetPanelAddr
	EX AF,AF'
	RET NC
	JP FlipPanel

;; -----------------------------------------------------------------------------------------------------------
;; Takes a Wall panel id in A.
;; If the top bit was set (bit7 = needs flip), we flip the bit in
;; corresponding PanelFlips if necessary,
;; Return: Carry if a modification in PanelFlips was needed.
;; Return: A the flip bitmap
.NeedsFlip2:
	LD C,A
	LD HL,(Walls_PanelFlipsPtr)
	AND &03
	LD B,A
	INC B
	LD A,&01
nf2_wander1loop
	RRCA
	DJNZ nf2_wander1loop
	LD B,A
	AND (HL)
	JR NZ,nf2_2
	RL C
	RET NC
	LD A,B
	OR (HL)
	LD (HL),A
	SCF
	RET
nf2_2
	RL C
	CCF
	RET NC
	LD A,B
	CPL
	AND (HL)
	LD (HL),A
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
.DoJumpIX:
	JP (IX)
.DoJumpIY:
	JP (IY)

;; -----------------------------------------------------------------------------------------------------------
;; Zero a single column of the 6-byte-wide buffer at DE' (A rows).
.ClearOne:
	EXX
	LD B,A
	EX DE,HL
	LD E,0
clro_1
	LD (HL),E
	LD A,L
	ADD A,6
	LD L,A
	DJNZ clro_1
	EX DE,HL
	EXX
	RET

;; Zero two columns of the 6-byte-wide buffer at DE' (A rows).
.ClearTwo:
	EXX
	LD B,A
	EX DE,HL
	LD E,0
clr2_1
	LD (HL),E
	INC L
	LD (HL),E
	LD A,L
	ADD A,5
	LD L,A
	DJNZ clr2_1
	EX DE,HL
	EXX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Set FloorAddr to the floor sprite indexed in A.
;; HL : pointer on the floor tile patterns selected; also copied into FloorAddr.
.SetFloorAddr:
	LD C,A
	ADD A,A
	ADD A,C
	ADD A,A
	ADD A,A
	ADD A,A
	LD L,A
	LD H,0
	ADD HL,HL
	LD DE,floor_tiles + MOVE_OFFSET
	ADD HL,DE
	LD (FloorAddr),HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Address of the sprite data used to draw the floor.
;; This is updated by SetFloorAddr.
.FloorAddr:     															;; IMG_2x24 + 2 * &30
	DEFW 	floor_tile_pattern1 + MOVE_OFFSET

;; -----------------------------------------------------------------------------------------------------------
;; HL' points to the floor sprite id.
;; If it's floor tile 5, we return a blank floor tile (no floor).
;; Otherwise we return the current tile address pointer, plus an
;; offset C (0 or 2*8), in BC.
.GetFloorAddr:
	PUSH AF
	EXX
	LD A,(HL)
	OR &FA			;; ~&05
	INC A
	EXX
	JR Z,Blank_Tile
	LD A,C
	LD BC,(FloorAddr)
	ADD A,C
	LD C,A
	ADC A,B
	SUB C
	LD B,A
	POP AF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Use the empty floor tile (no floor) if floor sprite ID = 5
.Blank_Tile:
	LD BC,empty_floor_tile + MOVE_OFFSET
	POP AF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Fill a 6-byte-wide buffer at DE' with both columns of a floor tile.
;; A contains the number of rows to generate.
;; D contains the initial offset in rows.
;; HL points to the floor sprite id.
;; The +0 or +16 in C below will align the left part (+0) and the right
;; part (+16 : flipped side) of the floor tiles in the Y axis:
;;    /|\
;;    \|/
.BlitFloor:
	LD B,A
	LD A,D
	BIT 7,(HL)
	EXX
	LD C,0
	JR Z,bf_1
	LD C,2*8
bf_1
	CALL GetFloorAddr
	AND &0F
	ADD A,A
	LD H,0
	LD L,A
	EXX
bf_2
	EXX
	PUSH HL
	ADD HL,BC
	LD A,(HL)
	LD (DE),A
	INC HL
	INC E
	LD A,(HL)
	LD (DE),A
	LD A,E
	ADD A,5
	LD E,A
	POP HL
	LD A,L
	ADD A,2
	AND &1F
	LD L,A
	EXX
	DJNZ bf_2
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Fill a 6-byte-wide buffer at DE' with the right column of background tile.
;; A  contains number of rows to generate.
;; D  contains initial offset in rows.
;; HL contains pointer to wall sprite id.
.BlitFloorR:
	LD B,A
	LD A,D
	BIT 7,(HL)
	EXX
	LD C,&01
	JR Z,bfl_1
	LD C,2*8 + 1
	JR bfl_1

;; -----------------------------------------------------------------------------------------------------------
;; Fill a 6-byte-wide buffer at DE' with the left column of background tile.
;; A  contains number of rows to generate.
;; D  contains initial offset in rows.
;; HL contains pointer to wall sprite id.
;; (This is to refresh the background (floor tiles) when a sprite moves)
.BlitFloorL:
	LD B,A
	LD A,D
	BIT 7,(HL)
	EXX
	LD C,&00
	JR Z,bfl_1
	LD C,&10
bfl_1
	CALL GetFloorAddr
	AND &0F
	ADD A,A
	LD H,0
	LD L,A
	EXX
bfl_2
	EXX
	PUSH HL
	ADD HL,BC
	LD A,(HL)
	LD (DE),A
	LD A,E
	ADD A,6
	LD E,A
	POP HL
	LD A,L
	ADD A,2
	AND &1F
	LD L,A
	EXX
	DJNZ bfl_2
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Blit from HL' to DE', right byte of a 2-byte-wide sprite in a 6-byte wide buffer.
;; Number of rows in A.
;; (This is to refresh the background (especially if in front of a wall) when a sprite moves)
.OneColBlitR:
	EXX
	INC HL
	INC HL
	JR ocbt_1
OneColBlitL:
	EXX
ocbt_1
	LD B,A
ocbt_2
	LD A,(HL)
	LD (DE),A
	INC HL
	DEC D
	LD A,(HL)
	LD (DE),A
	INC D
	INC HL
	INC HL
	INC HL
	LD A,E
	ADD A,6
	LD E,A
	DJNZ ocbt_2
	EXX
	RET

;; Blit from HL' to DE', a 2-byte-wide sprite in a 6-byte wide buffer.
;; Number of rows in A.
.TwoColBlit:
	EXX
	LD B,A
tcbl_1
	LD A,(HL)
	LD (DE),A
	INC HL
	DEC D
	LD A,(HL)
	LD (DE),A
	INC HL
	LD C,(HL)
	INC HL
	INC E
	LD A,(HL)
	LD (DE),A
	INC HL
	INC D
	LD A,C
	LD (DE),A
	LD A,E
	ADD A,5
	LD E,A
	DJNZ tcbl_1
	EXX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Reverse a two-byte-wide image.
;; * FlipPanel : pointer to data in HL
;; 		Flip a normal wall panel
;; 		Used to flip the wall sprite for the right side of the screen.
;; * FlipPillar : Height in B, pointer to data in HL.
.FlipPanel:
	LD B,SHORT_WALL
FlipPillar
	PUSH DE
	LD D,RevTable / WORD_HIGH_BYTE ;; 4F00
	PUSH HL
fcol_1
	LD (smc_dest_addr2+1),HL
	LD E,(HL)
	LD A,(DE)
	INC HL
	LD E,(HL)
	LD (smc_dest_addr1+1),HL
	INC HL
	LD C,(HL)
	LD (HL),A
	INC HL
	LD A,(DE)
	LD E,(HL)
	LD (HL),A
	LD A,(DE)
smc_dest_addr1:
	LD (NULL_PTR),A
	LD E,C
	LD A,(DE)
smc_dest_addr2
	LD (NULL_PTR),A
	INC HL
	DJNZ fcol_1
	POP HL
	POP DE
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Top bit is set if the column image buffer is flipped
IsPillarBufFlipped:
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; Return the wall panel address in HL, given panel index in A.
.GetPanelAddr:
	AND &03
	ADD A,A
	ADD A,A
	LD C,A
	ADD A,A
	ADD A,A
	ADD A,A
	SUB C
	ADD A,A
	LD L,A
	LD H,0
	ADD HL,HL
	ADD HL,HL
	LD BC,(Walls_PanelBase)
	ADD HL,BC
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given sprite data, return a rotated version of it.
;;
;; A holds the rotation size (in 2-bit units).
;; At start, HL holds source image, DE hold mask image.
;; At end, HL holds dest image, DE holds mask image.
;; A' is incremented.
;; The sprite width and number of bytes are read from SpriteWidth and
;; SpriteRowCount. SpriteWidth is incremented. Uses 'Buffer'.
.BlitRot:
	DEC A
	ADD A,A
	EXX
	LD C,A
	LD B,0
	LD A,(Sprite_Width)
	INC A
	LD (Sprite_Width),A
	CP &05
	LD HL,BlitRot3s
	JR NZ,btrot_0
	LD HL,BlitRot4s
btrot_0
	ADD HL,BC
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	LD (smc_btrot_1+1),HL
	LD (smc_btrot_2+1),HL
	EXX
	EX AF,AF'
	PUSH AF
	LD A,(SpriteRowCount)
	PUSH DE
	LD DE,BlitRot_Buffer ;; = KeyScanningBuffer
	LD B,0
	DI
smc_btrot_1
	CALL NULL_PTR
	EX DE,HL
	POP HL
	PUSH DE
	LD A,(SpriteRowCount)
	LD B,&FF
smc_btrot_2
	CALL NULL_PTR
	LD HL,BlitRot_Buffer ;; = KeyScanningBuffer
	POP DE
	EI
	POP AF
	INC A
	EX AF,AF'
	RET

;; -----------------------------------------------------------------------------------------------------------
;; pointers on the BlitRot<*> function to use
BlitRot3s:
	DEFW 	BlitRot2on3
	DEFW 	BlitRot4on3
	DEFW 	BlitRot6on3
BlitRot4s
	DEFW 	BlitRot2on4
	DEFW 	BlitRot4on4
	DEFW 	BlitRot6on4

;; -----------------------------------------------------------------------------------------------------------
Save_Stack_ptr:
	DEFW NULL_PTR

;; -----------------------------------------------------------------------------------------------------------
;; Do a copy with 2-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot2on3:
	LD (Save_Stack_ptr),SP
	LD C,LDAvv_OPCODE
	LD (smc_br23_1),BC
	LD (smc_br23_2),BC
	LD SP,HL
	EX DE,HL
	SRL A
	JR NC,br23_1
	INC A
	EX AF,AF'
	POP BC
	LD B,C
	DEC SP
	JP br23_2
br23_1
	EX AF,AF'
	POP DE
	POP BC
smc_br23_1
	LD A,0
	RRCA
	RR E
	RR D
	RR C
	RRA
	RR E
	RR D
	RR C
	RRA
	LD (HL),E
	INC HL
	LD (HL),D
	INC HL
	LD (HL),C
	INC HL
	LD (HL),A
	INC HL
br23_2
	POP DE
smc_br23_2
	LD A,0
	RRCA
	RR B
	RR E
	RR D
	RRA
	RR B
	RR E
	RR D
	RRA
	LD (HL),B
	INC HL
	LD (HL),E
	INC HL
	LD (HL),D
	INC HL
	LD (HL),A
	INC HL
	EX AF,AF'
	DEC A
	JR NZ,br23_1
	LD SP,(Save_Stack_ptr)
	RET

;; Do a copy with 6-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot6on3:
	LD (Save_Stack_ptr),SP
	LD C,LDAvv_OPCODE
	LD (smc_br63_1),BC
	LD (smc_br63_2),BC
	LD SP,HL
	EX DE,HL
	SRL A
	JR NC,br63_1
	INC A
	EX AF,AF'
	POP BC
	LD B,C
	DEC SP
	JP br63_2
br63_1
	EX AF,AF'
	POP DE
	POP BC
smc_br63_1
	LD A,0
	RLCA
	RL C
	RL D
	RL E
	RLA
	RL C
	RL D
	RL E
	RLA
	LD (HL),A
	INC HL
	LD (HL),E
	INC HL
	LD (HL),D
	INC HL
	LD (HL),C
	INC HL
br63_2
	POP DE
smc_br63_2
	LD A,0
	RLCA
	RL D
	RL E
	RL B
	RLA
	RL D
	RL E
	RL B
	RLA
	LD (HL),A
	INC HL
	LD (HL),B
	INC HL
	LD (HL),E
	INC HL
	LD (HL),D
	INC HL
	EX AF,AF'
	DEC A
	JR NZ,br63_1
	LD SP,(Save_Stack_ptr)
	RET

;; Do a copy with 4-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot4on3:
	LD C,B
	LD B,A
	LD A,C
	PUSH BC
	LD C,&FF
	PUSH DE
br43_1
	LDI
	LDI
	LDI
	LD (DE),A
	INC DE
	DJNZ br43_1
	POP HL
	POP BC
	LD A,C
br43_2
	RRD
	INC HL
	RRD
	INC HL
	RRD
	INC HL
	RRD
	INC HL
	DJNZ br43_2
	RET

;; Do a copy with 2-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot2on4:
	LD (Save_Stack_ptr),SP
	LD C,LDAvv_OPCODE
	LD (smc_bt24_1),BC
	LD SP,HL
	EX DE,HL
br24_1
	EX AF,AF'
	POP DE
	POP BC
smc_bt24_1
	LD A,0
	RRCA
	RR E
	RR D
	RR C
	RR B
	RRA
	RR E
	RR D
	RR C
	RR B
	RRA
	LD (HL),E
	INC HL
	LD (HL),D
	INC HL
	LD (HL),C
	INC HL
	LD (HL),B
	INC HL
	LD (HL),A
	INC HL
	EX AF,AF'
	DEC A
	JR NZ,br24_1
	LD SP,(Save_Stack_ptr)
	RET

;; Do a copy with 6-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot6on4:
	LD (Save_Stack_ptr),SP
	LD C,LDAvv_OPCODE
	LD (smc_br64_1),BC
	LD SP,HL
	EX DE,HL
bt64_1
	EX AF,AF'
	POP DE
	POP BC
smc_br64_1
	LD A,0
	RLCA
	RL B
	RL C
	RL D
	RL E
	RLA
	RL B
	RL C
	RL D
	RL E
	RLA
	LD (HL),A
	INC HL
	LD (HL),E
	INC HL
	LD (HL),D
	INC HL
	LD (HL),C
	INC HL
	LD (HL),B
	INC HL
	EX AF,AF'
	DEC A
	JR NZ,bt64_1
	LD SP,(Save_Stack_ptr)
	RET

;; Do a copy with 4-bit shift.
;; Source HL, width 3 bytes.
;; Destination DE, width 4 bytes.
;; A contains byte-count, B contains filler character
;; Returns next space after destination write in HL
.BlitRot4on4:
	LD C,B
	LD B,A
	LD A,C
	PUSH BC
	LD C,&FF
	PUSH DE
brot44_1
	LDI
	LDI
	LDI
	LDI
	LD (DE),A
	INC DE
	DJNZ brot44_1
	POP HL
	POP BC
brot44_2
	RRD
	INC HL
	RRD
	INC HL
	RRD
	INC HL
	RRD
	INC HL
	RRD
	INC HL
	DJNZ brot44_2
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Sprite variables
;; LSB is upper extent, MSB is lower extent
;; X extent is in screen units (2 pixels per unit).
;; Units increase down and to the right.
ViewXExtent
	DEFW &60 * WORD_HIGH_BYTE + &66
ViewYExtent
	DEFW &50 * WORD_HIGH_BYTE + &70

SpriteXStart
	DEFB 0
SpriteRowCount
	DEFB 0

ObjXExtent
	DEFW &00 * WORD_HIGH_BYTE + &00
ObjYExtent
	DEFW &00 * WORD_HIGH_BYTE + &00
SpriteFlags
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; Update the object extent
;; Hl object pointer, calculate and store the object extents.
.StoreObjExtents:
	INC HL
	INC HL
	CALL GetObjExtents
	LD (ObjXExtent),BC
	LD (ObjYExtent),HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes object in HL, gets union of the extents of that object and
;; Obj[XY]Extent. Returns X extent in HL, Y extent in DE.
.UnionExtents:
	INC HL
	INC HL
	CALL GetObjExtents
	LD DE,(ObjYExtent)
	LD A,H
	CP D
	JR NC,unext_1
	LD D,H
unext_1
	LD A,E
	CP L
	JR NC,unext_2
	LD E,L
unext_2
	LD HL,(ObjXExtent)
	LD A,B
	CP H
	JR NC,unext_3
	LD H,B
unext_3
	LD A,L
	CP C
	RET NC
	LD L,C
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes X extent in HL, rounds it to the byte, and stores in ViewXExtent.
.PutXExtent:
	LD A,L
	ADD A,3
	AND &FC
	LD L,A
	LD A,H
	AND &FC
	LD H,A
	LD (ViewXExtent),HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes X extent in HL and Y extent in DE.
DrawXSafe
	CALL PutXExtent
	JR Draw_small_start

;; -----------------------------------------------------------------------------------------------------------
;; If the end is before Y_START, give up. Otherwise bump the start down
;; and continue.
.BumpYMinAndDraw:
	LD A,Y_START
	CP E
	RET NC
	LD D,Y_START
	JR DrawCore

;; -----------------------------------------------------------------------------------------------------------
;; Draw a given range of the screen, drawing into ViewBuff and then
;; blitting to the screen. This entry point sanity-checks the extents
;; first.
;; X extent in HL, Y extent in DE
.UnionAndDraw:
	CALL UnionExtents
Draw_View
	CALL PutXExtent
	LD A,E
	CP &F1
	RET NC
Draw_small_start
	LD A,D
	CP E
	RET NC
	CP Y_START
	JR c,BumpYMinAndDraw
DrawCore
	LD (ViewYExtent),DE
	CALL DrawBkgnd
	LD A,(Has_no_wall)
	AND &0C
	JR Z,drwc_1
	LD E,A
	AND &08
	JR Z,drwc_2
	LD BC,(ViewXExtent)
	LD HL,Walls_CornerX
	LD A,B
	CP (HL)
	JR NC,drwc_2
	LD A,(ViewYExtent+1)
	ADD A,B
	RRA
	LD D,A
	LD A,(Walls_ScreenMaxV)
	CP D
	JR c,drwc_2
	LD HL,ObjList_NextRoomV_Far2Near
	PUSH DE
	CALL Blit_Objects
	POP DE
	BIT 2,E
	JR Z,drwc_1
drwc_2
	LD BC,(ViewXExtent)
	LD A,(Walls_CornerX)
	CP C
	JR NC,drwc_1
	LD A,(ViewYExtent+1)
	SUB C
	CCF
	RRA
	LD D,A
	LD A,(Walls_ScreenMaxU)
	CP D
	JR c,drwc_1
	LD HL,ObjList_NextRoomU_Far2Near
	CALL Blit_Objects
drwc_1
	LD HL,ObjList_Far_Far2Near
	CALL Blit_Objects
	LD HL,ObjList_Regular_Far2Near
	CALL Blit_Objects
	LD HL,ObjList_Near_Far2Near
	CALL Blit_Objects
	JP Blit_screen

;; -----------------------------------------------------------------------------------------------------------
;; Call Sub_BlitObject for each object in the linked list pointed to by
;; HL. Note that we're using the second link, so the passed HL is an
;; object + 2.
.Blit_Objects:
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	RET Z
	LD (smc_CurrObject2+1),HL
	CALL Sub_BlitObject
smc_CurrObject2
	LD HL,NULL_PTR
	JR Blit_Objects

;; -----------------------------------------------------------------------------------------------------------
;;  Set carry flag if there's overlap
;;  X adjustments in HL', X overlap in A'
;;  Y adjustments in HL,  Y overlap in A
.Sub_BlitObject:
	CALL IntersectObj
	RET NC
	LD (SpriteRowCount),A
	LD A,H
	ADD A,A
	ADD A,H
	ADD A,A
	EXX
	SRL H
	SRL H
	ADD A,H
	LD E,A
	LD D,ViewBuff / WORD_HIGH_BYTE ;; 4D00
	PUSH DE
	PUSH HL
	EXX
	LD A,L
	NEG
	LD B,A
	LD A,(Sprite_Width)
	AND &04
	LD A,B
	JR NZ,btobj_0
	ADD A,A
	ADD A,B
	JR btobj_1
btobj_0
	ADD A,A
	ADD A,A
btobj_1
	PUSH AF
	CALL Load_sprite_image_address_into_DE
	POP BC
	LD C,B
	LD B,0
	ADD HL,BC
	EX DE,HL
	ADD HL,BC
	LD A,(SpriteXStart)
	AND &03
	CALL NZ,BlitRot
	POP BC
	LD A,C
	NEG
	ADD A,&03
	RRCA
	RRCA
	AND &07
	LD C,A
	LD B,0
	ADD HL,BC
	EX DE,HL
	ADD HL,BC
	POP BC
	EXX
	LD A,(Sprite_Width)
	SUB 3
	ADD A,A
	LD E,A
	LD D,0
	LD HL,BlitMaskFns
	ADD HL,DE
	LD E,(HL)
	INC HL
	LD D,(HL)
	EX AF,AF'
	DEC A
	RRA
	AND &0E
	LD L,A
	LD H,0
	ADD HL,DE
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	LD A,(SpriteRowCount)
	LD B,A
	JP (HL)

;; -----------------------------------------------------------------------------------------------------------
.BlitMaskFns:
	DEFW 	BlitMasksOf1				;; BlitMasksOf1
	DEFW 	BlitMasksOf2				;; BlitMasksOf2
	DEFW 	BlitMasksOf3				;; BlitMasksOf3
BlitMasksOf1
	DEFW 	BlitMask1of3				;; BlitMask1of3
	DEFW 	BlitMask2of3				;; BlitMask2of3
	DEFW 	BlitMask3of3				;; BlitMask3of3
BlitMasksOf2
	DEFW 	BlitMask1of4				;; BlitMask1of4
	DEFW 	BlitMask2of4				;; BlitMask2of4
	DEFW 	BlitMask3of4				;; BlitMask3of4
	DEFW 	BlitMask4of4				;; BlitMask4of4
BlitMasksOf3
	DEFW 	BlitMask1of5				;; BlitMask1of5
	DEFW 	BlitMask2of5				;; BlitMask2of5
	DEFW 	BlitMask3of5				;; BlitMask3of5
	DEFW 	BlitMask4of5				;; BlitMask4of5
	DEFW 	BlitMask5of5				;; BlitMask5of5

;; -----------------------------------------------------------------------------------------------------------
;; Given an object, calculate the intersections with
;; ViewXExtent and ViewYExtent. Also saves the X start in SpriteXStart.
;;
;; Parameters: HL contains object+2 (O_FAR2NEAR_LST)
;; Returns:
;;  Set carry flag if there's overlap
;;  X adjustments in HL', X overlap in A'
;;  Y adjustments in HL,  Y overlap in A
.IntersectObj:
	CALL GetShortObjExt
	LD A,B
	LD (SpriteXStart),A
	PUSH HL
	LD DE,(ViewXExtent)
	CALL IntersectExtent
	EXX
	POP BC
	RET NC
	EX AF,AF'
	LD DE,(ViewYExtent)
	CALL IntersectExtent
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Like GetShortObjExt, except it copes with tall objects.
;;
;; Parameters: Object+2 (O_FAR2NEAR_LST) in HL
;; Returns: X extent in BC, Y extent in HL
.GetObjExtents:
	INC HL
	INC HL
	LD A,(HL)
	BIT 3,A
	JR Z,gsobjext_1
	CALL gsobjext_1
	LD A,H
	SUB &10
	LD H,A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Sets SpriteFlags and generates extents for the object.
;; Parameters: Object+2 (O_FAR2NEAR_LST) in HL
;; Returns: X extent in BC, Y extent in HL
.GetShortObjExt:
	INC HL
	INC HL
	LD A,(HL)
gsobjext_1
	BIT 4,A
	LD A,&00
	JR Z,gsobjext_2
	LD A,&80
gsobjext_2
	EX AF,AF'
	INC HL
	CALL UVZtoXY
	INC HL
	INC HL
	LD A,(HL)
	LD (SpriteFlags),A
	DEC HL
	EX AF,AF'
	XOR (HL)
	JP GetSprExtents

;; -----------------------------------------------------------------------------------------------------------
;; Calculate parameters to do with overlapping extents
;; Parameters:
;;  BC holds extent of sprite
;;  DE holds current extent
;; Returns:
;;  Sets carry flag if there's any overlap.
;;  H holds the extent adjustment
;;  L holds the sprite adjustment
;;  A holds the overlap size.
.IntersectExtent:
	LD A,D
	SUB C
	RET NC
	LD A,B
	SUB E
	RET NC
	NEG
	LD L,A
	LD A,B
	SUB D
	JR c,subIntersectExtent
	LD H,A
	LD A,C
	SUB B
	LD C,L
	LD L,0
	CP C
	RET c
	LD A,C
	SCF
	RET

.subIntersectExtent:
	LD L,A
	LD A,C
	SUB D
	LD C,A
	LD A,E
	SUB D
	CP C
	LD H,0
	RET c
	LD A,C
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given HP pointing to an Object + 5 (O_U)
;; Return X coordinate in C, Y coordinate in B.
;; (Return: Increments HL by 2 (points on O_Z))
;; 		.----------> X
;; 		|  V   U							eg. U,V,Z = &24, &0C, &C0
;; 		|   \ /									BC = &CF98
;; 		|    |
;; 		|    Z
;; 		Y
.UVZtoXY:
	LD A,(HL)
	LD D,A
	INC HL
	LD E,(HL)
	SUB E
	ADD A,&80
	LD C,A
	INC HL
	LD A,(HL)
	ADD A,A
	SUB E
	SUB D
	ADD A,&7F
	LD B,A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Pointer into stack for current origin coordinates
.DecodeOrgPtr:
	DEFW DecodeOrgStack

;; Each stack entry contains UVZ coordinates
DecodeOrgStack
	DEFB 	&00, &00, &00
	DEFB 	&00, &00, &00
	DEFB 	&00, &00, &00
	DEFB 	&00, &00, &00

BaseFlags
	DEFB	&00, &00

;; -----------------------------------------------------------------------------------------------------------
;; This is the length of an object instance (as in OOP/Class "object")
;; Head, Heels, a FireObject and any other item (that we also call object,
;; but in the sense "item") in the room (using the TmpObj) use the same
;; data collection format, 18 bytes long.
OBJECT_LENGTH			EQU		18					;; &0012

;; -----------------------------------------------------------------------------------------------------------
O_NEAR2FAR_LST			EQU		&00
O_FAR2NEAR_LST			EQU		&02
O_FLAGS					EQU 	&04
O_U						EQU 	&05
O_V						EQU 	&06
O_Z						EQU 	&07
O_SPRITE				EQU 	&08
O_SPRFLAGS				EQU 	&09
O_FUNC					EQU 	&0A
O_IMPACT				EQU		&0B
;; ????					EQU		&0C
O_OBJUNDER				EQU		&0D				;; D and E = "object under" pointer
O_ANIM					EQU 	&0F
O_DIRECTION				EQU 	&10
O_SPECIAL				EQU 	&11

NULL_PTR				EQU		&0000

;; Temp Object used during unpacking room data
.TmpObj_variables:								;; 18 bytes
	DEFW 	NULL_PTR		;; 0&1 : O_NEAR2FAR_LST (A list)
	DEFW 	NULL_PTR		;; 2&3 : O_FAR2NEAR_LST (B list)
	DEFB 	&00				;; 4 : O_FLAGS
	DEFB 	&00				;; 5 : O_U coordinate
	DEFB 	&00				;; 6 : O_V coordinate
	DEFB 	&00				;; 7 : O_Z coordinate
	DEFB 	&00				;; 8 : O_SPRITE
	DEFB 	&00				;; 9 : O_SPRFLAGS
	DEFB 	&00				;; A : O_FUNC
	DEFB 	&FF				;; B : O_IMPACT
	DEFB 	&FF				;; C :
	DEFW 	NULL_PTR		;; D&E : O_OBJUNDER
	DEFB 	&00				;; F : O_ANIM
	DEFB 	&00				;; 10 : O_DIRECTION (dir code (0 to 7 or FF))
	DEFB 	&00				;; 11 : O_SPECIAL

UnpackFlags
	DEFB &00

DataPtr
	DEFW &004C
CurrData
	DEFB 0

ExpandDone
	DEFB 0
DoorSprites
	DEFB &00, &00

currentRoomID
	DEFW NULL_PTR

;; -----------------------------------------------------------------------------------------------------------
;; Half-Door flags when building a room (the value will be copied in the object O_FLAGS).
;; Note that a door is composed of 2 half-doors objects.
;;
;; Bits [5:4] as follows (ie. which wall side):
;;   nw(left)=10/\01=ne(up)
;;   sw(down)=11\/00=se(right)
;; Bits [2:0]: UVZ extent:
;; 	      Umax Umin Vmax Vmin Zmax Zmin
;; 	* 7 : U+4, U,   V,   V-4, Z,   Z-18
;; 	* 6 : U,   U-4, V,   V-4, Z,   Z-18
;; 	* 5 : U+4, U,   V+4, V,   Z,   Z-18
;; 	* 4 : U,   U-4, V+4, V,   Z,   Z-18
Door_Obj_Flags: ;; L  R  L  R  L  R  L  R
	DEFB 	&27, &26, &17, &15, &05, &04, &36, &34

RoomDimensionsIdx
	DEFB &00
RoomDimensionsIdxTmp
	DEFB &00
FloorCode
	DEFB &00
FloorAboveFlag
	DEFB &00

color_scheme
	DEFB 0
WorldId
	DEFB 0
Has_no_wall
	DEFB 0
Has_Door:
	DEFB 0

Max_min_UV_Table:
MinU
	DEFB &4D  ;; MinU (don't care default value)
MinV
	DEFB &41  ;; minV (don't care default value)
MaxU
	DEFB &49  ;; MaxU (don't care default value)
MaxV
	DEFB &4E  ;; maxV (don't care default value)

;; AltLimits[12] are also used as IY for drawing extra rooms.
AltLimits1:
	DEFB	&20, &20, &20, &50
AltLimits2:
	DEFB	&52, &4E, &00, &00

;; -----------------------------------------------------------------------------------------------------------
;; Room Dimensions Array: Min U, Min V, Max U, Max V
;; Index = Room type RoomDimensionsIdx
RoomDimensions:
	DEFB &08, &08, &48, &48
	DEFB &08, &10, &48, &40
	DEFB &08, &18, &48, &38
	DEFB &08, &20, &48, &30
	DEFB &10, &08, &40, &48
	DEFB &18, &08, &38, &48
	DEFB &20, &08, &30, &48
	DEFB &10, &10, &40, &40

GROUND_LEVEL			EQU 	&C0

;; -----------------------------------------------------------------------------------------------------------
;; Heights of the 4 doors, for the main room.
;; 0/\1
;; 3\/2
DoorHeights
	DEFB 	&00, &00, &00, &00					;; nw ne se sw doors
;; Locations of the 4 doors along their respective
;; walls, for the room currently being processed.
DoorHeightsTmp
	DEFB 	&00, &00, &00, &00					;; nw ne se sw doors

;; The height of the highest door present.
HighestDoor
	DEFB 	GROUND_LEVEL						;; The height of the highest door present. reset value = GROUND_LEVEL

;; -----------------------------------------------------------------------------------------------------------
BuildRoom
	LD IY,Max_min_UV_Table
	LD HL,&30 * WORD_HIGH_BYTE + &D0
	LD (ViewXExtent),HL
	LD HL,&00 * WORD_HIGH_BYTE + &FF
	LD (ViewYExtent),HL
	LD (currentRoomID),BC
	LD HL,GROUND_LEVEL * WORD_HIGH_BYTE + GROUND_LEVEL
	LD (DoorHeightsTmp),HL
	LD (DoorHeightsTmp+2),HL
	LD HL,0
	CALL ReadRoom
	LD A,(RoomDimensionsIdxTmp)
	LD (RoomDimensionsIdx),A
	LD DE,DoorHeights
	LD HL,DoorHeightsTmp
	LD BC,4
	LDIR
	LD HL,(DoorHeights)
	LD A,L
	CP H
	JR c,br_sk1
	LD A,H
br_sk1
	NEG
	ADD A,GROUND_LEVEL
	LD (HighestDoor),A
	LD HL,(DoorSprites)
	PUSH AF
	CALL OccludeDoorway
	POP AF
	PUSH AF
	CALL SetPillarHeight
	CALL HasFloorAbove
	LD A,0
	RLA
	LD (FloorAboveFlag),A
	POP AF
	CALL DoConfigWalls
	CALL StoreCorner
	LD HL,(Has_no_wall)
	PUSH HL
	LD A,L
	AND &08
	JR Z,test_if_wall_far_U
	;; Draw the room in V direction (Nw side)
	LD A,&01
	CALL SetObjList
	LD BC,(currentRoomID)
	LD A,B
	INC A
	XOR B
	AND &0F
	XOR B
	LD B,A
	LD A,(MaxV)
	LD H,A
	LD L,0
	CALL ReadRoom
	LD A,(HighestDoor)
	CALL DoConfigWalls
test_if_wall_far_U
	LD IY,AltLimits2
	POP HL
	PUSH HL
	LD A,L
	AND &04
	JR Z,bldroom_2
	;; Draw the room in U direction (Ne side)
	LD A,&02
	CALL SetObjList
	LD BC,(currentRoomID)
	LD A,B
	ADD A,&10
	XOR B
	AND &F0
	XOR B
	LD B,A
	LD A,(MaxU)
	LD L,A
	LD H,0
	CALL ReadRoom
	LD A,(HighestDoor)
	CALL DoConfigWalls
bldroom_2
	POP HL
	LD (Has_no_wall),HL
	XOR A
	JP SetObjList

;; -----------------------------------------------------------------------------------------------------------
;; Unpacks a room, adds all its sprites to the lists.
;; See "Room_list1" comments for the Room data format.
;; Inputs: IY points to where we stash the room size.
;; 		   BC = Room Id
;; 		   HL = UV origin of the room
ReadRoom
	LD (DecodeOrgStack),HL
	XOR A
	LD (DecodeOrgStack+2),A
	PUSH BC
	CALL FindVisitRoom
	LD B,3
	CALL FetchData
	LD (RoomDimensionsIdxTmp),A
	ADD A,A
	ADD A,A
	ADD A,RoomDimensions and WORD_LOW_BYTE
	LD L,A
	ADC A,RoomDimensions / WORD_HIGH_BYTE ;; 16F4
	SUB L
	LD H,A
	LD B,2
	LD IX,DecodeOrgStack
rdroom_1
	LD C,(HL)
	LD A,(IX+0)
	AND A
	JR Z,rdroom_jump
	SUB C
	LD E,A
	RRA
	RRA
	RRA
	AND &1F
	LD (IX+0),A
	LD A,E
rdroom_jump
	ADD A,C
	LD (IY+0),A
	INC HL
	INC IX
	INC IY
	DJNZ rdroom_1
	LD B,2
rdroom_2
	LD A,(IX-2)
	ADD A,A
	ADD A,A
	ADD A,A
	ADD A,(HL)
	LD (IY+0),A
	INC IY
	INC IX
	INC HL
	DJNZ rdroom_2
	LD B,3
	CALL FetchData
	LD (color_scheme),A
	LD B,3
	CALL FetchData
	LD (WorldId),A
	CALL DoWallsnDoors
	LD B,3
	CALL FetchData
	LD (FloorCode),A
	CALL SetFloorAddr
rdroom_loop
	CALL ProcEntry
	JR NC,rdroom_loop
	POP BC
	JP AddSpecialItems

;; -----------------------------------------------------------------------------------------------------------
;; value going in are 3-bit signed value (-4 to +3)
;; we add that value to the value in (HL)
;; Return result in A
Add3Bit
	BIT 2,A
	JR Z,add3b_1
	OR &F8
add3b_1
	ADD A,(HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Recursively do ProcEntry. Macro code is in A.
.RecProcEntry:
	EX AF,AF'
	CALL FetchData333
	LD HL,(DecodeOrgPtr)
	PUSH AF
	LD A,B
	CALL Add3Bit
	LD B,A
	INC HL
	LD A,C
	CALL Add3Bit
	LD C,A
	INC HL
	POP AF
	SUB 7
	ADD A,(HL)
	INC HL
	LD (DecodeOrgPtr),HL
	LD (HL),B
	INC HL
	LD (HL),C
	INC HL
	LD (HL),A
	LD A,(CurrData)
	LD HL,(DataPtr)
	PUSH AF
	PUSH HL
	CALL FindMacro
	LD (DataPtr),HL
rpent_loop
	CALL ProcEntry
	JR NC,rpent_loop
	LD HL,(DecodeOrgPtr)
	DEC HL
	DEC HL
	DEC HL
	LD (DecodeOrgPtr),HL
	POP HL
	POP AF
	LD (DataPtr),HL
	LD (CurrData),A
	;; flow into ProcEntry
;; -----------------------------------------------------------------------------------------------------------
;; Process one entry in the room description array. Returns carry when done.
ROOM_DATA_BREAK			EQU		&FF
ROOM_DATA_MACRO			EQU		&C0

.ProcEntry:
	LD B,8
	CALL FetchData
	CP ROOM_DATA_BREAK
	SCF
	RET Z
	CP ROOM_DATA_MACRO
	JR NC,RecProcEntry
	PUSH IY
	LD IY,TmpObj_variables
	CALL InitObj
	POP IY
	LD B,2
	CALL FetchData
	;; The 2 bits fetched are:
	;; Bit0, if 0 : only one object with current object code;
	;;       if 1 : several objects to create with current object code.
	;; Bit1, if 0 : we will need to fetch one bit before every coord-set to get the per-object orientation bit.
	;;       if 1 : the next fetched bit will serve as orientation bit for all onjects in that group.
	BIT 1,A
	JR NZ,global_orientation_bit
	LD A,&01
	JR pent_1

global_orientation_bit
	PUSH AF
	LD B,1
	CALL FetchData
	POP BC
	RLCA
	RLCA
	OR B
pent_1
	LD (UnpackFlags),A
pent_loop
	CALL SetTmpObjFlags
	CALL SetTmpObjUVZEx
	LD A,(UnpackFlags)
	RRA
	JR NC,pent_one_obj
	LD A,(ExpandDone)
	INC A
	AND A
	RET Z
	CALL AddObjOpt
	JR pent_loop
pent_one_obj
	CALL AddObjOpt
	AND A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; do an "AddObject"
.AddObjOpt:
	LD HL,TmpObj_variables
	LD BC,OBJECT_LENGTH
	PUSH IY
	CALL AddObject
	POP IY
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Initialise the doors. IY is pointing a byte after Max_min_UV_Table
;; (ie. IY = Max_min_UV_Table+4) and will be accessed with negative offsets.
.DoWallsnDoors:
	LD B,3
	CALL FetchData
	ADD A,A
	LD L,A
	LD H,A
	INC H
	LD (DoorSprites),HL
	LD IX,Door_Obj_Flags
	LD HL,DoorHeightsTmp
	EXX
	LD A,(IY-1)
	ADD A,4
	CALL DoWallnDoorU
	LD HL,DoorHeightsTmp+1
	EXX
	LD A,(IY-2)
	ADD A,4
	CALL DoWallnDoorV
	LD HL,DoorHeightsTmp+2
	EXX
	LD A,(IY-3)
	SUB 4
	CALL DoWallnDoorU
	LD HL,DoorHeightsTmp+3
	EXX
	LD A,(IY-4)
	SUB 4
	JP DoWallnDoorV

;; -----------------------------------------------------------------------------------------------------------
;; Update flags into Has_no_vall and Has_Door; this will be called for all 4 walls/doors
;; so both Has_no_vall and Has_Door will have 4 meaningful bits [3:0] for Nw,Ne,Se,Sw
;; if needed; sets the door Z coord in TmpObj_variables and HL' (DoorHeightsTmp pointer).
;; Read value:
;;  0 : Wall, No door
;;  1 : No wall, No door.
;;  2..7 :  Door; Door Height &A2 to &C0 (GROUND_LEVEL)
;; Return: Has_no_vall and Has_Door updated
;;         Carry reset = has no door; Carry set = has door
.FetchWallnDoor:
	LD B,3
	CALL FetchData
	LD HL,Has_no_wall
	SUB 2
	JR c,FetchedNoDoor
	RL (HL)
	INC HL
	SCF
	RL (HL)
	SUB 7
	NEG
	LD C,A							;; x1
	ADD A,A							;; x2
	ADD A,C							;; x3
	ADD A,A							;; x6
	ADD A,&96						;; x6 + &96
	LD (TmpObj_variables+O_Z),A
	SCF
	EXX
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; If no door is found on the current side, update the corresponding bit in:
;;  * Has_no_vall (0  = Wall or 1 NoWall);
;;  * Has_Door (0 = No Door)
FetchedNoDoor:																;; No door case:
	CP &FF
	CCF
	RL (HL)
	AND A
	INC HL
	RL (HL)
	AND A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Build a Door on the U or V axis:
;; DoWallnDoorV : Build a door parallel to the V axis (Nw and Se sides).
;; DoWallnDoorU : Build a door parallel to the U axis (Ne and Sw sides).
;; Coordinate of the wall plane in A
;; HL' point on the coordinates
;; IX points to flags to use (Door_Obj_Flags).
.DoWallnDoorV:
	LD (TmpObj_variables+O_U),A
	LD HL,TmpObj_variables+O_V
	LD A,(DecodeOrgStack+1)
	JP DoWallnDoorAux
.DoWallnDoorU:
	LD (TmpObj_variables+O_V),A
	LD HL,TmpObj_variables+O_U
	LD A,(DecodeOrgStack)
	;; will flow into DoWallnDoorAux
;; -----------------------------------------------------------------------------------------------------------
;; HL points to the object's coordinate field to write to
;; A holds the origin value in that dimension.
;; Takes extra parameters in IX
;; IX (object flags) and HL' (pointer to relevant DoorHeightsTmp entry).
;; 		V   U
;; 		 \ /
;; 		  |
;; 		  Z
.DoWallnDoorAux:
	ADD A,A
	ADD A,A
	ADD A,A
	PUSH AF
	ADD A,DOOR_LOW
	LD (HL),A
	PUSH HL
	CALL FetchWallnDoor
	JR NC,NoDoorRet
	LD A,(IX+0)
	LD (TmpObj_variables+O_FLAGS),A
	INC IX
	LD A,(DoorSprites)
	LD (TmpObj_variables+O_SPRITE),A
	CALL AddHalfDoorObj
	LD A,(IX+0)
	LD (TmpObj_variables+O_FLAGS),A
	INC IX
	LD A,(DoorSprites+1)
	LD (TmpObj_variables+O_SPRITE),A
	POP HL
	POP AF
	ADD A,DOOR_HIGH
	LD (HL),A
AddHalfDoorObj
	CALL AddObjOpt
	LD A,(TmpObj_variables+O_FLAGS)
	LD C,A
	AND &30
	RET PO
	AND &10
	OR &01
	LD (TmpObj_variables+O_FLAGS),A
	LD A,(TmpObj_variables+O_Z)
	CP GROUND_LEVEL
	RET Z
	PUSH AF
	ADD A,6
	LD (TmpObj_variables+O_Z),A
	LD A,SPR_DOORSTEP
	LD (TmpObj_variables+O_SPRITE),A
	CALL AddObjOpt
	POP AF
	LD (TmpObj_variables+O_Z),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; No door case - unwind variables and return
.NoDoorRet:
	POP HL
	POP AF
	INC IX
	INC IX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Finds a Macro used to Build a room
;; Reset CurrData. Macro id we are searching is passed in A'.
;; Returns a pointer to a specific room description macro in Room_Macro_data
.FindMacro:
	LD A,&80
	LD (CurrData),A
	LD HL,Room_Macro_data
	EX AF,AF'
	LD D,0
fm_loop
	LD E,(HL)
	INC HL
	CP (HL)
	RET Z
	ADD HL,DE
	JR fm_loop

;; -----------------------------------------------------------------------------------------------------------
;; Checks if the room above the current one exists and has no floor (so we can get in by going up)
;; Returns with Carry set if the room above has a floor.
;; Returns with Carry reset if the room above has No floor.
.HasFloorAbove:
	LD BC,(currentRoomID)
	LD A,C
	DEC A
	AND &F0
	LD C,A
	CALL FindRoom
	RET c
check_floorid_above:
    ;; Room Data Format (excluding size byte) is:
	;; 12b roomID UVZ, 3b roomDimensions, 3b colorScheme,
	;; 3b WorldId, 15b door data, 3b floorId, 8b Object, etc.
	;; 		uuuuvvvv_zzzzdddc_ccwwwDDD_pppDDDpp_pDDDfffo_ooooooo..
	;; DE currently pointing on the second byte, so +3 points on the
	;; byte with the floorId. ORing &F1 checks if floorId is 7 (no floor).
	INC DE
	INC DE
	INC DE
	LD A,(DE)
	OR &F1
	INC A
	RET Z
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Like FindRoom, but set the "visited" bit (in RoomMask_buffer) as well.
;; Input: Takes room Id in BC.
;; Return: First data byte in A, and room bit mask & location (in RoomMask_buffer) in C' and HL'.
;; Return: Carry set=not found or Carry reset=found)
;; If found, DataPtr and CurrData are updated, and pointing on the
;; begining of the room actual data (after room ID)
FindVisitRoom
	CALL FindRoom
	EXX
	LD A,C
	OR (HL)
	LD (HL),A
	EXX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Find room data if room exist.
;; Input: Takes room Id in BC.
;; Return: First data byte in A, and room bit mask & location (in RoomMask_buffer) in C' and HL'.
;; Return: Carry set=not found or Carry reset=found)
;; If found, DataPtr and CurrData are updated, and pointing on the
;; begining of the room actual data (after room ID)
.FindRoom:
	LD D,0
	LD HL,Room_list
;; -----------------------------------------------------------------------------------------------------------
;; Finds an entry in the room list.
;; The data structure is:
;;  -  1 byte = size (excluding this byte); a size of zero terminates the list.
;;  -  1.5 bytes = room id "UVZ" (Bottom nibble is ignored for matching),
;;							 eg. "8A 43" means Room &8A40, also note these are
;;							    in big_endian format: U=8,V=&A,Z=4 (3=don't care)
;;  -  0.5 + N bytes of Data
;; Input:
;;   HL pointing to the start of the tagged list
;;   BC is the room id we're looking for (eg. &8A40 for Head's first room)
;;   HL' and C' are incremented as the address in RoomMask_buffer and
;;      bit mask for a bitfield associated with the Nth entry.
;; Return:
;;   DE will be the entry size (D should be zero)
;; 	 The carry flag is set if nothing's found.
;; 	 If the room is found, you can read data with FetchData:
;;      Current byte to process in CurrData;
;;      Addr pointer on data in DataPtr
.Sub_FindRoom:
	EXX
	LD HL,RoomMask_buffer
	LD C,&01
	EXX
Sub_FindRoom_more
	LD E,(HL)
	INC E
	DEC E
	SCF
	RET Z
	INC HL
	LD A,B
	CP (HL)
	JR Z,frin_b_matched
frin_2
	ADD HL,DE
	EXX
	RLC C
	JR NC,frin_1
	INC HL
frin_1
	EXX
	JR Sub_FindRoom_more
frin_b_matched
	INC HL
	DEC E
	LD A,(HL)
	AND &F0
	CP C
	JR NZ,frin_2
	DEC HL
	LD (DataPtr),HL
	LD A,&80
	LD (CurrData),A
	LD B,4
	JP FetchData

;; -----------------------------------------------------------------------------------------------------------
;; When unpacking Room data, will set the flags of the object processed.
.SetTmpObjFlags:
	LD A,(UnpackFlags)
	RRA
	RRA
	JR c,stof_1
	LD B,1
	CALL FetchData
stof_1
	AND &01
	RLCA
	RLCA
	RLCA
	RLCA
	AND &10
	LD C,A
	LD A,(BaseFlags+1)
	XOR C
	LD (TmpObj_variables+O_FLAGS),A
	LD BC,(BaseFlags)
	BIT 4,A
	JR Z,stof_end
	BIT 1,A
	JR Z,stof_2
	XOR &01
	LD (TmpObj_variables+O_FLAGS),A
stof_2
	DEC C
	DEC C
stof_end
	LD A,C
	LD (TmpObj_variables+O_DIRECTION),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Read (ie. FetchData) U, V, Z coords (3 bits each), and
;; set TmpObj_variables's location
.SetTmpObjUVZEx:
	CALL FetchData333
SetTmpObjUVZ
	EX AF,AF'
	LD HL,(DecodeOrgPtr)
	LD DE,TmpObj_variables+O_U
;; Calculates U, V and Z coordinates
;;  DE points to where we will write the U, V and Z coordinates
;;  HL points to the address of the origin data.
;;  We pass in coordinates: B contains U, C contains V, A' contains Z
;;  U/V coordinates are built on a grid of * 8 + 12
;;  Z coordinate is built on a grid of * 6 + 0x96 (0..7 will return &96 to &C0=GROUND_LEVEL)
;;  Sets ExpandDone to 0xFF (done) if "B = 7, C = 7, A' = 0"
.Set_UVZ:
	LD A,B
	CALL CalcGridPos
	LD (DE),A
	LD A,C
	CALL CalcGridPos
	INC DE
	LD (DE),A
	EX AF,AF'
	PUSH AF
	ADD A,(HL)
	LD L,A
	ADD A,A
	ADD A,L
	ADD A,A
	ADD A,&96
	INC DE
	LD (DE),A
	POP AF
	CPL
	AND C
	AND B
	OR &F8
	LD (ExpandDone),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Add curr coord (U or V) to the Origin (U or V) from (HL) and
;; calculate the resulting pixel position.
;; Input: A = U or V current value;
;;        HL : pointer on U or V origin value.
;; Output: A = ((coord+origin) * 8) + 12
;;         HL is incremented
.CalcGridPos:
	ADD A,(HL)
	INC HL
	RLCA
	RLCA
	RLCA
	ADD A,&0C
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will fetch (see FetchData) 3 values of 3-bits.
;; Output: First value in B, next in C and Last in A.
;;         CurrData and DataPtr are updated as needed
;; It is used to get the UVZ coords from the Room data.
.FetchData333:
	LD B,3
	CALL FetchData
	PUSH AF
	LD B,3
	CALL FetchData
	PUSH AF
	LD B,3
	CALL FetchData
	POP HL
	POP BC
	LD C,H
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Fetch a value from bit-packed data.
;; Input: Number of bits in B.
;;        Also the current byte of data must be in CurrData;
;;        and current data pointer in DataPtr
;; Output: DataPtr and CurrData updated
;;         Fetched B-bit value in A
;; Exemple: From the 2 consecutive bytes "B1" and "72" ("101|1_000|1_0|111_00|10"),
;;     if we FetchData with B being 3 then 4, 2 and finaly 5 we get in A
;;     respectively &05, then &08, &02 and finaly &1C, with CurrData being &80
;;     and DataPtr increase by 1.
FetchData
	LD DE,CurrData
	LD A,(DE)
	LD HL,(DataPtr)
	LD C,A
	XOR A
fetchd_0
	RL C
	JR Z,fdta_next
fetchd
	RLA
	DJNZ fetchd_0
	EX DE,HL
	LD (HL),C
	RET
fdta_next
	INC HL
	LD (DataPtr),HL
	LD C,(HL)
	SCF
	RL C
	JP fetchd

;; -----------------------------------------------------------------------------------------------------------
;; Calls all the initialization functions
Init_setup:
	CALL Init_table_and_crtc
	JP Init_table_rev

;; -----------------------------------------------------------------------------------------------------------
;; Initialization of a new game
;; Note that it build Heels room, save it and switch to Head
.Init_new_game:
	XOR A
	LD (parts_got_Mask),A		;; Nb parts got
	LD (access_new_room_code),A
	LD (Save_point_value),A
	LD HL,RoomID_Batman_1st		;; 1st room ID
	LD (current_Room_ID),HL
	CALL Erase_visited_room
	CALL Reinitialise
	DEFW StatusReinit
	CALL Reinitialise
	DEFW reset_count_val ;; reset nbtimes_died and nbcollected_bonus
	JP ResetSpecials

;; -----------------------------------------------------------------------------------------------------------
.Init_Continue_game:
	CALL Reinitialise
	DEFW StatusReinit
	JP DoContinue

;; -----------------------------------------------------------------------------------------------------------
EnterRoom
	EXX
	CALL Reinitialise
	DEFW ObjVars
	CALL Reinitialise
	DEFW reset_stat			;; reset some sta like jump height, isStill, etc.
	LD HL,BackgrdBuff
	LD BC,BACKGRDBUFF_LENGTH
	CALL Erase_forward_Block_RAM
	EXX
	CALL BuildRoom
	CALL GetScreenEdges
	CALL DrawBlacked
	CALL CharThing15

Update_Screen_Periph
	LD A,(color_scheme)
	CALL Set_colors
	CALL PrintStatus
	JP Draw_Screen_Periphery

;; -----------------------------------------------------------------------------------------------------------
.GetScreenEdges:
	LD HL,(Max_min_UV_Table)
	LD A,(Has_Door)
	PUSH AF
	BIT 1,A
	JR Z,br_2408
	;; If there's a door, bump up MinV.
	DEC H
	DEC H
	DEC H
	DEC H
br_2408
	RRA
	LD A,L				;; minU
	JR NC,br_240F
	;; If there's the other door, reduce MinU.
	SUB 4
	LD L,A
	;; Find MinU - MinV
br_240F
	SUB H
	;; And use this to set the X coordinate of the corner.
	ADD A,&80
	LD (smc_CornerPos+1),A
	LD C,A
	;; Then set the Y coordinate of the corner, taking into
    ;; account various fudge factors.
	LD A,&FC
	SUB H
	SUB L
	;; Save Y coordinate of the corner in B for TweakEdges
	LD B,A
	;; Then generate offsets to convert from screen X coordinates to
    ;; associated Y coordinates.
	NEG
	LD E,A
	ADD A,C
	LD (smc_LeftAdj+1),A
	LD A,C
	NEG
	ADD A,E
	LD (smc_RightAdj+1),A
	CALL TweakEdges
	;; Then, inspect Has_Doors to see if we need to remove
	;; a column panel or two.
	POP AF
	RRA
	PUSH AF
	CALL NC,NukeColL
	POP AF
	RRA
	RET c
;; Scan from the right for the first drawn column
NukeColR
	LD HL,BackgrdBuff + 62  ;; &503E = &5000 + 31*2
ScanR
	LD A,(HL)
	AND A
	JR NZ,NukeCol
	DEC HL
	DEC HL
	JR ScanR

;; If the current screen column sprite is a blank, delete it.
.NukeCol:
	INC HL
	LD A,(HL)
	OR &FA
	INC A
	RET NZ
	LD (HL),A
	DEC HL
	LD (HL),A
	RET

;; Scan from the left for the first drawn column
.NukeColL:
	LD HL,BackgrdBuff
ScanL:
	LD A,(HL)
	AND A
	JR NZ,NukeCol
	INC HL
	INC HL
	JR ScanL

;; -----------------------------------------------------------------------------------------------------------
;; This copies a block of data to another block in order to reset the
;; values of the destination block.
;; The "CALL Reinitialise" must be followed by a DEFW argument with
;; the address of the byte indicating both block length.
;; Then the first byte of data to copy is the addr after it up to the
;; block length.
;; The destination block is the contiguous block after that.
Reinitialise:
	POP HL
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	PUSH HL
	EX DE,HL
	LD C,(HL)
	LD B,0
	INC HL
	LD D,H
	LD E,L
	ADD HL,BC
	EX DE,HL
	LDIR
	RET

;; -----------------------------------------------------------------------------------------------------------
;; 2 available functions to Erase a block of memory.
;; Erase_forward_Block_RAM will erase using the value 00
;; Erase_block_val_in_E will erase using the value in E
;; Input: HL=start addr, BC=length, E (erase value for Erase_block_val_in_E only)
Erase_forward_Block_RAM:
	LD E,0
Erase_block_val_in_E:
	LD (HL),E
	INC HL
	DEC BC
	LD A,B
	OR C
	JR NZ,Erase_block_val_in_E
	RET

;; -----------------------------------------------------------------------------------------------------------
;; tapfoot counter??
	DEFB &30
	DEFB &02
	DEFB &30

;; -----------------------------------------------------------------------------------------------------------
sounds_pointer_array
	DEFW Sound_ID_Silence		;; 0 &0AAD (data &0923)
	DEFW Sound_ID_WalkRun		;; 1 &0AB8 (data &0929 and &0933)
	DEFW Sound_ID_Todo_5		;; 2 &0AE0 (data &0968)
	DEFW Sound_ID_Todo_2		;; 3 &0AC5 (data &0949)
	DEFW Sound_ID_Todo_1		;; 4 &0AC9 (data &093D)
	DEFW Sound_ID_Menu_Blip		;; 5 &0ADC (data &0961)
	DEFW Sound_ID_Menu_Blip		;; 6 &0ADC (data &0961)
	DEFW Sound_ID_Fly			;; 7 &0AD4 (data &096F)
	DEFW Sound_ID_Jump			;; 8 &0AD8 (data &0976)
	DEFW Sound_ID_PickUp		;; 9 &0AD8 (data &0976)

;; -----------------------------------------------------------------------------------------------------------
;; These are the init/default values for the Inventory (see 247B) and
;; Counters (see 247C). First byte is the length of the array (9).
;; Then the reset values to initialize the variables.
;; The Reinitialise call with 2471 as argument will copy the 9 bytes of
;; StatusReinit_reset_data into the Inventory (247B) & after
CNT_SPEED				EQU		1
CNT_SPRING				EQU		2
CNT_SHIELD				EQU		3
CNT_LIVES				EQU		4

StatusReinit:
	DEFB	5 ;; length
StatusReinit_reset_data:
	DEFB 	0 ;; Inventory
	DEFB 	0 ;; CNT_SPEED
	DEFB 	0 ;; CNT_SPRING
	DEFB 	0 ;; CNT_SHIELD
	DEFB 	8 ;; CNT_LIVES

;; -----------------------------------------------------------------------------------------------------------
;; This will indicate the available character inventory.
;; A '1' means that the item has been picked up.
;;		bit0 : BatThruster
;;		bit1 : BatBelt
;;		bit2 : BatBoots
;;		bit3 : BatBag
Inventory:
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; These are the main counters (Lives, Invuln, Speed, Spring, Donuts)
NB_COUNTERS				EQU		4

.Counters:
Counter_speed
	DEFB 	0	;; CNT_SPEED
Counter_spring
	DEFB 	0	;; CNT_SPRING
Counter_shield
	DEFB 	0	;; CNT_SHIELD
Counter_lives
	DEFB 	4	;; CNT_LIVES
InvulnModulo
	DEFB	3	;; InvulnModulo
SpeedModulo
	DEFB	2	;; SpeedModulo

;; -----------------------------------------------------------------------------------------------------------
;; the 5 bytes of reset_stat_data will be copied into Jump_Height and following
reset_stat
	DEFB 5 ;; length
reset_stat_data
	DEFB 0
	DEFB &FF
	DEFW NULL_PTR
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
Jump_Height
	DEFB 0
IsStill
	DEFB &FF

Carried_Object
	DEFW NULL_PTR
Corrying_bool
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
	DEFB 0
character_direction
	DEFB &0F
Other_sound_ID
	DEFB 0
Saved_Objects_List_index
	DEFB 0
Movement
	DEFB &FF
saved_access_code
	DEFB 0

EntryPosition_uvz
	DEFB 0, 0, 0

;; -----------------------------------------------------------------------------------------------------------
;; Character instance
Batman_variables:  							;; &12 = 18
	DEFW NULL_PTR		;; Batman_variables+O_NEAR2FAR_LST
	DEFW NULL_PTR		;; Batman_variables+O_FAR2NEAR_LST
	DEFB &08			;; Batman_variables+O_FLAGS
	DEFB &28			;; Batman_variables+O_U
	DEFB &0B			;; Batman_variables+O_V
	DEFB GROUND_LEVEL	;; Batman_variables+O_Z
	DEFB &10			;; Batman_variables+O_SPRITE
	DEFB &01			;; Batman_variables+O_SPRFLAGS
	DEFB &00			;; Batman_variables+O_FUNC
	DEFB &FF			;; Batman_variables+O_IMPACT
	DEFB &FF			;; Batman_variables+&0C
	DEFW NULL_PTR		;; Batman_variables+O_OBJUNDER
	DEFB &00			;; Batman_variables+O_ANIM
	DEFB &00			;; Batman_variables+O_DIRECTION
	DEFB &00			;; Batman_variables+O_SPECIAL

;; -----------------------------------------------------------------------------------------------------------
;; Object instance                 			; &12 = 18
Object_variables
	DEFW NULL_PTR		;; Obj_variables+O_NEAR2FAR_LST
	DEFW NULL_PTR		;; Obj_variables+O_FAR2NEAR_LST
	DEFB 0				;; Obj_variables+O_FLAGS
	DEFB 0				;; Obj_variables+O_U
	DEFB 0				;; Obj_variables+O_V
	DEFB 0				;; Obj_variables+O_Z
	DEFB 0				;; Obj_variables+O_SPRITE
	DEFB 3				;; Obj_variables+O_SPRFLAGS
	DEFB 0				;; Obj_variables+O_FUNC
	DEFB 0				;; Obj_variables+O_IMPACT
	DEFB 0				;; Obj_variables+&0C
	DEFW NULL_PTR		;; Obj_variables+O_OBJUNDER
	DEFB 0				;; Obj_variables+O_ANIM
	DEFB 0				;; Obj_variables+O_DIRECTION
	DEFB 0				;; Obj_variables+O_SPECIAL

;; -----------------------------------------------------------------------------------------------------------
;; This defines the sprites list that compose an animation for
;; Batman (facing and rearward) and also for the "Vape"
;; animations (Dying, Teleporting, Vanishing, etc.).
;; The first byte is the current index in the animation (which is
;; the current sprite in the anim). The list is 0-terminated.
;; If the bit7 of the sprite code is set, the sprite is mirrored.
.Anim_Loops:
Front_Batman_Walk_Loop
	DEFB 0, SPR_BATMAN_1, SPR_BATMAN_0, SPR_BATMAN_2, SPR_BATMAN_0, 0
Back_Batman_Walk_Loop
	DEFB 0, SPR_BATMAN_B1, SPR_BATMAN_B1, SPR_BATMAN_B0, SPR_BATMAN_B0, 0
Vape_loop
	DEFB 0, SPR_VAPE_2 or SPR_FLIP, SPR_VAPE_2, SPR_VAPE_2 or SPR_FLIP
	DEFB SPR_VAPE_1 or SPR_FLIP, SPR_VAPE_1, SPR_VAPE_1 or SPR_FLIP, SPR_VAPE_0
	DEFB SPR_VAPE_0, SPR_VAPE_0 or SPR_FLIP, SPR_VAPE_0 or SPR_FLIP, SPR_VAPE_0, SPR_VAPE_0, 0

;; -----------------------------------------------------------------------------------------------------------
;; checks if need to play anims, check Death anim
;; Decrease invuln counter if needed,
.Characters_Update:
	LD HL,Dying
	LD A,(HL)
	AND A
	JR NZ,HandleDeath
	LD HL,InvulnModulo
	DEC (HL)
	JR NZ,ct_mvt
	LD (HL),3
decr_invuln
	LD A,CNT_SHIELD
	CALL Decrement_counter_and_display
ct_mvt
	LD A,&FF
	LD (&1BE5),A ;; Movement
	LD A,(access_new_room_code)
	AND A
	JR Z,br_25B6
change_room
	LD A,(Saved_Objects_List_index)
	AND A
	JR Z,br_25B3
	LD A,(character_direction)
	SCF
	RLA
	LD (Current_User_Inputs),A
	JR br_25B6
br_25B3
	LD (access_new_room_code),A
br_25B6
	CALL CharThing4
	LD A,(Batman_variables+O_Z)
	CP GROUND_LEVEL - 60
	JR NC,CheckEnd		;; CheckFired or CheckDying
	XOR A
	LD (Jump_Height),A
	LD A,(FloorAboveFlag)
	AND A
	JR NZ,CheckEnd		;; CheckFired or CheckDying
	LD A,7
	LD (access_new_room_code),A
CheckEnd
	LD A,(access_new_room_code)
	AND &7F
	RET Z
	JP Go_to_room

;; -----------------------------------------------------------------------------------------------------------
.HandleDeath:
	DEC (HL)
	JR NZ,CharThing20
	INC (HL)
	CALL HasVoice1DataToPlay
	LD A,8
	JP NZ,Set_colors
	CALL Incr_died_number
lose_a_life
	LD HL,Counter_lives
	LD A,(HL)
	SUB 1					;; Infinite lives : POKE &1C90,0
	DAA
	LD (HL),A
	CALL c,NoMoreLives
	LD HL,EntryPosition_uvz
	LD DE,Batman_variables+O_U
	LD BC,&0003
	LDIR
	LD A,(saved_access_code)
	LD (access_new_room_code),A
	JP Reenter_room

CharThing20
	XOR A
	LD (Batman_variables+O_FLAGS),A
	LD (Object_variables+O_FLAGS),A
	LD HL,Vape_loop
	LD IY,Batman_variables
	CALL Read_Loop_byte
	LD (Object_variables+O_SPRITE),A
	PUSH AF
	LD HL,Object_variables
	CALL StoreObjExtents
	LD HL,Object_variables
	CALL UnionAndDraw
	POP AF
	XOR &80
	LD (Batman_variables+O_SPRITE),A
	LD HL,Batman_variables
	CALL StoreObjExtents
	LD HL,Batman_variables
	CALL UnionAndDraw
	LD A,(Dying)
	AND &07
	JP Set_pen3_only		;; This will blink the colors when dying

;; -----------------------------------------------------------------------------------------------------------
;; when no more lives, randomly give onke Bonus life (25% of the time), else Game over.
NoMoreLives
	LD (HL),0
	CALL Random_gen
	LD A,L
	AND &03					;; "POKE &1CEC,0" to give an extra life 100% of the time (instead of 25%)
	JP NZ,Game_over
	JP GiveOneMoreLife

;; -----------------------------------------------------------------------------------------------------------
;; Looks like more movement stuff
CharThing4:
	LD IY,Batman_variables
	XOR A
	LD (Other_sound_ID),A
	LD A,(Saved_Objects_List_index)
	CALL SetObjList
	LD HL,Batman_variables
	CALL StoreObjExtents
	LD HL,Jump_Height
	LD A,(HL)
	AND A
	JR Z,br_27F8
	LD A,(Saved_Objects_List_index)
	AND A
	JR Z,br_27AF
	LD (HL),0
	JR br_27F8

br_27AF
	DEC (HL)
	LD HL,Batman_variables
	CALL ChkSatOn
	JR c,br_27C2
	DEC (IY+O_Z)
	LD A,3
	CALL SetOtherSound
	JR br_27D3

br_27C2
	EX AF,AF'
	LD A,6
	BIT 4,(IY+O_IMPACT)
	SET 4,(IY+O_IMPACT)
	CALL Z,SetOtherSound
	EX AF,AF'
	JR Z,br_27DE
br_27D3
	RES 4,(IY+O_IMPACT)
	SET 5,(IY+O_IMPACT)
	DEC (IY+O_Z)
br_27DE
	LD A,(Inventory)
	RRA				;; bit0 in carry
	JR c,br_27EB	;; if we have ??? 1D53
br_27E5
	LD A,(character_direction) ;; else
	JP HandleMove

br_27EB
	LD A,(Current_User_Inputs)
	RRA
	CALL DirCode_from_LRDU
	INC A
	JP NZ,br_2855
	JR br_27E5

br_27F8
	SET 4,(IY+O_IMPACT)
	SET 5,(IY+&0C)
	LD HL,Batman_variables
	CALL DoorContact
	JP NC,CharThing23
	JR Z,br_2812
	LD A,(Inventory)
	AND &02
	JP NZ,&1E49
	INC (IY+O_Z)
	LD A,(Batman_variables+O_SPRITE)
	SUB SPR_BATMAN_FLY
	AND &FE				;; test if SPR_BATMAN_FLY or SPR_BATMAN_FLYB
	LD A,7
	CALL Z,SetOtherSound
	JP br_284B

br_2812
	LD A,(access_new_room_code)
	RLA
	JR NC,br_281C
	LD (IY+&0C),&FF
br_281C
	LD A,7
	BIT 5,(IY+O_IMPACT)
	SET 5,(IY+O_IMPACT)
	CALL Z,SetOtherSound
	BIT 4,(IY+&0C)
	SET 4,(IY+&0C)
	JR NZ,br_284B
	LD HL,Batman_variables
	CALL ChkSatOn
	JR NC,EPIC_40
	JR NZ,EPIC_40
	LD A,6
	CALL SetOtherSound
	JR br_284B

EPIC_40
	DEC (IY+O_Z)
	RES 4,(IY+O_IMPACT)
br_284B
	XOR A
	LD (&1BE1),A
	CALL TryCarry
	CALL DoJump
br_2855
	LD A,(Current_User_Inputs)
	RRA
;; Do the movement with LRDU direction in A.
.HandleMove:
	CALL MoveChar
	CALL Orient
	EX AF,AF'
	LD A,(IsStill)
	INC A
	JR NZ,br_288C
	XOR A
	LD (Front_Batman_Walk_Loop),A
	LD (Back_Batman_Walk_Loop),A
	EX AF,AF'
	LD A,&13			;; SPR_BATMAN_B0
	JR c,br_28BC
	LD A,&10			;; SPR_BATMAN_0
	JR DoFootTap
br_288C
	CALL &1E9E
	EX AF,AF'
	LD HL,Front_Batman_Walk_Loop
	JR NC,br_289B
	LD HL,Back_Batman_Walk_Loop
br_289B
	CALL Read_Loop_byte
br_28BC
	SET 5,(IY+O_IMPACT)
;; Update the character animation frames to values in BC, and then
;; call UpdateChar.
.UpdateCharFrame:
	LD (Batman_variables+O_SPRITE),A
	LD A,(&1BE5)
	LD (Batman_variables+&0C),A
	LD HL,Batman_variables
	CALL Relink
	CALL SaveObjListIdx
	XOR A
	CALL SetObjList
	LD HL,Batman_variables
	CALL UnionAndDraw
	JP Play_Other_Sound

;; -----------------------------------------------------------------------------------------------------------
DoFootTap ;; br_1e23
	LD HL,&1BB2 ;; BlinkEyesCounter ???
	DEC (HL)
	JR NZ,br_28BC
	LD (HL),&01
	LD HL,&1BB3
	DEC (HL)
	JR NZ,do_blink
	LD (HL),&02
	CALL TapFoot
do_blink
	LD HL,&1BB4
	DEC (HL)
	LD A,&17
	JR NZ,br_28BC
	LD A,&30
	LD (HL),&60
	LD (&1BB2),A
	LD A,&17
	JR br_28BC

	LD HL,(ObjContact)
	INC H
	DEC H
	JR Z,&1E59
	PUSH HL
	POP IX
	BIT 5,(IX+O_FLAGS)
	JR NZ,CharThing23

	LD HL,&1BE1
	LD A,(HL)
	AND A
	LD (HL),&FF
	JR Z,&1E6E
	CALL TryCarry
	CALL DoJump
	JR &1E6E

;; -----------------------------------------------------------------------------------------------------------
CharThing23
	XOR A
	LD (&1BE1),A ;; TODO_248e
	CALL &1E9E
	LD A,4
	CALL SetOtherSound
	RES 5,(IY+O_IMPACT)
	LD A,(Inventory)
	AND &02
	JR NZ,br_292E
	INC (IY+O_Z)	;; down
br_292E
	INC (IY+O_Z)	;; down
	LD A,(Inventory)
	RRA
	JR NC,br_2949
	LD A,(Current_User_Inputs)
	RRA
	CALL MoveChar
br_2949
	CALL Orient
	LD A,&15		;; SPR_BATMAN_FLY ???
	ADC A,0
	JP UpdateCharFrame

;; -----------------------------------------------------------------------------------------------------------
	LD A,&30
	LD (&1BB2),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Sprite orientation (flip/no-flip and Front/Back)
;; Reset bit4 of O_FLAGS if bit1 is set (U)
;; set bit4 of O_FLAGS if bit1 is reset (V) (sprite needs flip)
;; Returns with carry set if facing away or Carry reset if rearward.
Orient
	LD A,(character_direction)
	CALL DirCode_from_LRDU
	RRA
	RES 4,(IY+O_FLAGS)
	RRA
	JR c,br_2976
	SET 4,(IY+O_FLAGS)
br_2976
	RRA
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Move the character.
.MoveChar:
	OR &F0
	CP &FF
	LD (IsStill),A
	JR Z,br_2993
	EX AF,AF'
	XOR A
	LD (IsStill),A
	LD A,1
	CALL SetOtherSound
	EX AF,AF'
	LD HL,character_direction
	CP (HL)
	LD (HL),A
	JR Z,br_2998
	LD A,&FF
br_2998
br_2993
	PUSH AF
	AND (IY+&0C)
	CALL DirCode_from_LRDU
	CP &FF
	JR Z,br_29B6
	LD HL,Batman_variables
	CALL MoveCurrent
	JR NC,Sub_Move_Char
	LD A,(Batman_variables+O_IMPACT)
	OR &F0
	INC A
	LD A,5
	CALL NZ,SetOtherSound ;; sound
br_29B6
	POP AF
	LD A,(Batman_variables+O_IMPACT)
	OR &0F
	LD (Batman_variables+O_IMPACT),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Direction bitmask is on stack. "Move" has been called.
;; Update position and do the speed-related movement when when
;; TickTock hits zero.
.Sub_Move_Char
	LD HL,Batman_variables
	CALL UpdatePos
	POP BC
	LD A,(Counter_speed)
	AND A
	RET Z
	LD HL,SpeedModulo
	DEC (HL)
	PUSH BC
	JR NZ,speedskip
	LD (HL),&02
	LD A,0
	CALL Decrement_counter_and_display
speedskip
	POP AF
	CALL DirCode_from_LRDU
	CP &FF
	RET Z
	LD HL,Batman_variables
	PUSH HL
	CALL MoveCurrent
	POP HL
	JP NC,UpdatePos
	LD A,5
	JP SetOtherSound

;; -----------------------------------------------------------------------------------------------------------
.DoJump:
	LD A,(Inventory)
	AND &04
	RET Z
	LD A,(Saved_Objects_List_index)
	AND A
	RET NZ
	LD A,(Current_User_Inputs)
	RRA
	RET c
djmp_jumpkey
	LD C,0
	LD HL,(Batman_variables+O_OBJUNDER)
	LD A,H
	OR L
	JR Z,br_jpbonus
	PUSH HL
	POP IX
br_teststandingon
	LD A,(IX+O_SPRITE)
	CP SPR_SMILEY
	JR Z,onSpringStool
	CP SPR_S_CUSHION
	JR NZ,br_jpbonus
onSpringStool
	INC C
br_jpbonus
	PUSH BC
	LD A,CNT_SPRING
	CALL Decrement_counter_and_display
	POP BC
	JR Z,calculate_jump
br_bigjump
	INC C
calculate_jump
	LD A,C
	ADD A,A
	ADD A,A
	ADD A,4
	CP 12
	JR NZ,br_gotjumpheight
	CP 10
br_gotjumpheight
	LD (Jump_Height),A
	LD A,8
	JP SetOtherSound

;; -----------------------------------------------------------------------------------------------------------
TryCarry
	LD A,(Inventory)			;; check if batbag owned
	AND &08						;; test bit3 (bag)
	RET Z						;; no leave
	LD HL,Corrying_bool			;; else try to pick up
	LD A,(action_key_pressed)
	AND A
	JR NZ,DoCarry
	LD (HL),0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This will handle the pick-up (by Heels with the Purse) of an object
;; in the room, and drawing it on the HUD if carried.
CARRIED_OBJ_HUD_POS		EQU		&D0 * WORD_HIGH_BYTE + &40

.DoCarry:
	LD A,(HL)
	AND A
	RET NZ
	LD (HL),&01
	LD A,9
	CALL SetOtherSound
	LD A,(Carried_Object+1)
	AND A
	JR NZ,DropCarried
	LD HL,Batman_variables
	CALL CheckStoodUponNPickable
	RET NC
	LD A,(IX+O_SPRITE)
	PUSH HL
	LD (Carried_Object),HL
	LD BC,CARRIED_OBJ_HUD_POS
	PUSH AF
	CALL Draw_sprite_3x24
	POP AF
	POP HL
	JP RemoveObject

;; -----------------------------------------------------------------------------------------------------------
;; This is to drop the object carried in the Purse by Heels.
.DropCarried:
	LD A,(Saved_Objects_List_index)
	AND A
	RET NZ
	LD BC,(Batman_variables+O_Z)
	LD B,3
carryLoop
	LD HL,Batman_variables
	PUSH BC
	CALL ChkSatOn
	POP BC
	JR c,NoDrop
	DEC (IY+O_Z)
	DEC (IY+O_Z)
	DJNZ carryLoop
	LD HL,(Carried_Object)
	PUSH HL
	LD DE,O_Z
	ADD HL,DE
	LD DE,Batman_variables+O_V
	LD (HL),C
	EX DE,HL
	DEC DE
	LDD
	LDD
	POP HL
	CALL InsertObject
	LD HL,NULL_PTR
	LD (Carried_Object),HL
	LD BC,CARRIED_OBJ_HUD_POS
	CALL Clear_3x24
	LD HL,Batman_variables
	CALL DoorContact
	LD HL,Batman_variables
	JP StoreObjExtents
NoDrop
	LD (IY+O_Z),C
	RET

;; -----------------------------------------------------------------------------------------------------------
SetOtherSound
	LD HL,Other_sound_ID
BumpUp
	CP (HL)
	RET c
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
Play_Other_Sound
	CALL HasVoice1DataToPlay
	RET NZ
	LD A,(Other_sound_ID)
	ADD A,A
	ADD A,sounds_pointer_array and WORD_LOW_BYTE
	LD L,A
	ADC A,sounds_pointer_array / WORD_HIGH_BYTE	;; 1BB5  sounds_pointer_array???
	SUB L
	LD H,A
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	JP (HL)

;; -----------------------------------------------------------------------------------------------------------
CharThing15:
	XOR A
	LD (Batman_variables+O_FUNC),A
	LD (Vape_loop),A
	LD A,&08
	LD (Batman_variables+O_FLAGS),A
	LD A,(access_new_room_code)
	LD (saved_access_code),A
	PUSH AF
	PUSH AF
	DEC A
	CP 4
	JR NC,EPIC_86
	XOR &01
	LD E,A
	LD D,0
	LD HL,DoorHeights
	ADD HL,DE
	LD C,(HL)
	LD HL,WallSideBitmap
	ADD HL,DE
	LD A,(Has_no_wall)
	AND (HL)
	JR NZ,EPIC_86
	LD A,C
	LD (Batman_variables+O_Z),A

EPIC_86
	POP AF
	SUB 1
	LD DE,Batman_variables+O_U
	JR c,EPIC_93
	CP &04
	JR Z,EPIC_92
	CP &05
	JR NC,EPIC_90
	LD HL,Max_min_UV_Table
	RRA
	JR NC,EPIC_87
	INC DE
	INC HL
EPIC_87
	RRA
	JR c,EPIC_95
	INC HL
	INC HL
	JR EPIC_95

EPIC_90
	INC DE
	INC DE
	RRA
	LD A,GROUND_LEVEL - 60
	JR c,EPIC_91
	LD A,GROUND_LEVEL - 6
EPIC_91
	LD (DE),A
	POP AF
	JR EPIC_96_bis

EPIC_92
	LD HL,UVZ_coord_Set_UVZ
	JR EPIC_94

EPIC_93
	LD HL,TODO_2c54_uvz_reset_values
EPIC_94
	LDI
	LDI
EPIC_95
	LDI
EPIC_96
	POP AF
	ADD A,Facing_in_new_Room_tab and WORD_LOW_BYTE ;; 20D9
	LD L,A
	ADC A,Facing_in_new_Room_tab / WORD_HIGH_BYTE ;; 20D9
	SUB L
	LD H,A				;; HL = Facing_in_new_Room_tab + A
	LD A,(HL)
	LD (character_direction),A
EPIC_96_bis
EPIC_97
	LD A,&80
	LD (access_new_room_code),A
	LD HL,Batman_variables+O_U
	LD DE,EntryPosition_uvz
	LD BC,&0003
	LDIR
	LD HL,NULL_PTR
	LD (Batman_variables+O_OBJUNDER),HL
	DEC HL
	LD (Batman_variables+O_IMPACT),HL
	LD HL,Batman_variables
	LD IY,Batman_variables
	CALL Enlist
	CALL SaveObjListIdx
	XOR A
	LD (Dying),A
	JP SetObjList

;; -----------------------------------------------------------------------------------------------------------
.SaveObjListIdx:
	LD A,(ObjListIdx)
	LD (Saved_Objects_List_index),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; if Heels selected and picked up an object in the Purse, Draw the object
;; sprite on the HUD.
.Draw_carried_objects:
	LD HL,(Carried_Object)
	INC H
	DEC H
	RET Z
	LD DE,O_SPRITE
	ADD HL,DE
	LD A,(HL)
	LD BC,CARRIED_OBJ_HUD_POS
	JP Draw_sprite_3x24

;; -----------------------------------------------------------------------------------------------------------
TODO_2c54_uvz_reset_values:											;; UVZ for ???
	DEFB &2C, &45, &84

;; -----------------------------------------------------------------------------------------------------------
;; From access_new_room_code
;; get the facing direction when entering a new room from:
Facing_in_new_Room_tab:
	DEFB FACING_LEFT, FACING_DOWN, FACING_RIGHT, FACING_UP, FACING_LEFT ;; ???continue???, Down Right Up Left

;; -----------------------------------------------------------------------------------------------------------
;; From access_new_room_code
;; get the facing direction when entering a new room from:
WallSideBitmap:											;; index 0 = 8 = bit3, index 1 = 4 = bit2 etc.
	DEFB	&08, &04, &02, &01

;; -----------------------------------------------------------------------------------------------------------
;; Takes object (character?) in IY. Pointer to an object contacting the character.
.ObjContact:
	DEFW NULL_PTR

;; -----------------------------------------------------------------------------------------------------------
.DoorContact:
	CALL GetDoorHeight
	LD A,(IY+O_Z)
	SUB C
	JR DoContact

;; Takes object in IY, returns height of relevant door.
.GetDoorHeight:
	LD C,GROUND_LEVEL
	LD A,(Saved_Objects_List_index)
	AND A
	RET Z
	LD IX,DoorHeights
	LD C,(IX+0)
	LD A,(MaxV)
	SUB 3
	CP (IY+O_V)
	RET c
	LD C,(IX+2)
	LD A,(MinV)
	ADD A,2
	CP (IY+O_V)
	RET NC
	LD C,(IX+1)
	LD A,(MaxU)
	SUB 3
	CP (IY+O_U)
	RET c
	LD C,(IX+3)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This handles the "on ground level" state. It'll check if the Floor is deadly
;; or if the room has no floor hence falling in room below.
;; We are one the ground (HitFloor) or one above (NearHitFloor) : Input A = 0
.NearHitFloor:
	CP &FF
	;; A is zero. We've hit, or nearly hit, the floor.
.HitFloor:
	SCF
	LD (IY+O_OBJUNDER),A
	LD (IY+O_OBJUNDER+1),A
	RET NZ
	BIT 0,(IY+O_SPRFLAGS)
	RET Z
	LD A,(Saved_Objects_List_index)
	AND A
	JR NZ,RetZero_Cset
	LD A,(FloorCode)
	CP &06
	JR Z,DeadlyFloorCase
	CP &07
	JR NZ,RetZero_Cset
	LD A,6
	LD (access_new_room_code),A
	RET

DeadlyFloorCase
	CALL DeadlyContact
RetZero_Cset
	XOR A
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Object (character?) in IY.
.DoContact2:
	LD A,(IY+O_Z)
	SUB GROUND_LEVEL
;; A has the difference between the height and the ground level
.DoContact:
	LD BC,0
	LD (ObjContact),BC
	JR Z,HitFloor
	INC A
	JR Z,NearHitFloor
	CALL GetUVZExtents_AdjustLowZ
	LD C,B
	INC C
	EXX
	LD A,(IY+O_OBJUNDER+1)
	AND A
	JR Z,ChkSitOn
	LD H,A
	LD L,(IY+O_OBJUNDER)
	PUSH HL
	POP IX
	BIT 7,(IX+O_FLAGS)
	JR NZ,ChkSitOn
	LD A,(IX+O_Z)
	SUB 6
	EXX
	CP B
	EXX
	JR NZ,ChkSitOn
	CALL CheckWeOverlap
	JR NC,ChkSitOn
;; We're still standing on the object
;; Deal with contact between a character and a thing.
;; IY is the character, IX is what it's resting on.
.DoObjContact:
	BIT 1,(IX+O_SPRFLAGS)
	JR Z,DOC_1
	RES 5,(IX-OBJECT_LENGTH+&0C)
	LD A,(IX-OBJECT_LENGTH+O_IMPACT)
	JR DOC_2
DOC_1
	RES 5,(IX+&0C)
	LD A,(IX+O_IMPACT)
DOC_2
	OR &E0
	LD C,A
	LD A,(IY+&0C)
	AND C
	LD (IY+&0C),A
.DoAltContact:
	XOR A
	SCF
	JP ProcContact

;; -----------------------------------------------------------------------------------------------------------
;; Run through all the objects in the main object list and check their
;; contact with our object in IY, see if it's sitting on them or
;; touching them.
;;
;; Object extents should be in primed registers.
.ChkSitOn:
	LD HL,ObjList_Regular_Near2Far
CSIT_nextobject
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,CSIT_4
	PUSH HL
	POP IX
	BIT 7,(IX+O_FLAGS)
	JR NZ,CSIT_nextobject
	LD A,(IX+O_Z)
	SUB 6
	EXX
	CP B
	JR NZ,CSIT_3
	EXX
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSIT_nextobject
CSIT_2
	LD (IY+O_OBJUNDER),L
	LD (IY+O_OBJUNDER+1),H
	JR DoObjContact
CSIT_3
	CP C
	EXX
	JR NZ,CSIT_nextobject
	LD A,(ObjContact+1)
	AND A
	JR NZ,CSIT_nextobject
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSIT_nextobject
	LD (ObjContact),HL
	JR CSIT_nextobject
CSIT_4
	LD A,(Saved_Objects_List_index)
	AND A
	JR Z,CSIT_7
	LD A,(Batman_variables+O_Z)
	SUB &0C
	EXX
	CP B
	JR NZ,CSIT_6
	EXX
	LD IX,Batman_variables
	CALL CheckWeOverlap
	JR NC,CSIT_7
	LD HL,Batman_variables
	JR CSIT_2
CSIT_6
	CP C
	EXX
	JR NZ,CSIT_7
	LD A,(ObjContact+1)
	AND A
	JR NZ,CSIT_7
	LD IX,Batman_variables
	CALL CheckWeOverlap
	JR NC,CSIT_7
	LD (IY+O_OBJUNDER),0
	LD (IY+O_OBJUNDER+1),0
	JR CSIT_11
CSIT_7
	LD HL,(ObjContact)
	LD (IY+O_OBJUNDER),0
	LD (IY+O_OBJUNDER+1),0
	LD A,H
	AND A
	RET Z
	PUSH HL
	POP IX
	BIT 1,(IX+O_SPRFLAGS)
	JR Z,CSIT_9
	BIT 4,(IX-OBJECT_LENGTH+O_IMPACT)
	JR CSIT_10
CSIT_9
	BIT 4,(IX+O_IMPACT)
CSIT_10
	JR NZ,CSIT_11
	RES 4,(IY+&0C)
CSIT_11
	XOR A
	SUB 1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Called by the purse routine to find something below Heels to pick up.
;; Carry flag set if something is found, and thing returned in HL.
;;
;; Loop through all items, finding ones which match maxZ+6 ot +7 (below)
;; Then call CheckWeOverlap to see if ok candidate. Return it in HL if it is.
.CheckStoodUponNPickable:
	CALL GetUVZExtents_AdjustLowZ
	LD A,B
	ADD A,6
	LD B,A
	INC A
	LD C,A
	EXX
	LD HL,ObjList_Regular_Near2Far
gsu_1
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	RET Z
	PUSH HL
	POP IX
	BIT 6,(IX+O_FLAGS)
	JR Z,gsu_1
	LD A,(IX+O_Z)
	EXX
	CP B
	JR Z,gsu_2
	CP C
gsu_2
	EXX
	JR NZ,gsu_1
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,gsu_1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Object in IY, extents in primed registers.
;; Very similar to ChkSitOn. Checks to see if stuff is on us.
.ChkSatOn:
	CALL GetUVZExtents_AdjustLowZ
	LD B,C
	DEC B
	EXX
	XOR A
	LD (ObjContact),A
	LD HL,ObjList_Regular_Near2Far
CSAT_nextobj
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,CSAT_endlist
	PUSH HL
	POP IX
	BIT 7,(IX+O_FLAGS)
	JR NZ,CSAT_nextobj
	LD A,(IX+O_Z)
	EXX
	CP C
	JR NZ,CSAT_3
	EXX
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSAT_nextobj
CSAT_2
	LD A,(IY+O_IMPACT)
	OR &E0
	AND &EF
	LD C,A
	LD A,(IX+&0C)
	AND C
	LD (IX+&0C),A
	XOR A
	SCF
	JP ProcContact
CSAT_3
	CP B
	EXX
	JR NZ,CSAT_nextobj
	LD A,(ObjContact)
	AND A
	JR NZ,CSAT_nextobj
	PUSH HL
	CALL CheckWeOverlap
	POP HL
	JR NC,CSAT_nextobj
	LD A,&FF
	LD (ObjContact),A
	JR CSAT_nextobj
CSAT_endlist
	LD A,(Saved_Objects_List_index)
	AND A
	JR Z,CSAT_7
	LD A,(Batman_variables+O_Z)
	EXX
	CP C
	JR NZ,CSAT_5
	EXX
	LD IX,Batman_variables
	CALL CheckWeOverlap
	JR NC,CSAT_7
	JR CSAT_2
CSAT_5
	CP B
	EXX
	JR NZ,CSAT_7
	LD A,(ObjContact)
	AND A
	JR NZ,CSAT_7
	LD IX,Batman_variables
	CALL CheckWeOverlap
	JR NC,CSAT_7
	LD A,&FF
	JR CSAT_8
CSAT_7
	LD A,(ObjContact)
CSAT_8
	AND A
	RET Z
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes object point in IX and checks to see if we overlap with it.
;; Assumes our extents are in DE',HL'.
.CheckWeOverlap:
	CALL GetUVExt
;; Assuming X and Y extents in DE,HL and DE',HL', check two boundaries overlap.
;; Sets carry flag if they do.
.CheckOverlap:
	LD A,E
	EXX
	CP D
	LD A,E
	EXX
	RET NC
	CP D
	RET NC
	LD A,L
	EXX
	CP H
	LD A,L
	EXX
	RET NC
	CP H
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given an object in IX, returns its U and V centered extents.
;; Very like GetUVZExtents, but for UV.
;;
;; Values are based on the bottom 2 flag bits ([1:0])
;; Flag   U      V
;; 00   +3 -3  +3 -3
;; 01   +4 -4  +4 -4		DE = high,low U
;; 10   +4 -4  +1 -1		HL = high,low V
;; 11   +1 -1  +4 -4
.GetUVExt:
	LD A,(IX+O_FLAGS)
	BIT 1,A
	JR NZ,sub_GetUV_Ext
	RRA
	LD A,&03
	ADC A,0
	LD C,A
	ADD A,(IX+O_U)
	LD D,A
	SUB C
	SUB C
	LD E,A
	LD A,C
	ADD A,(IX+O_V)
	LD H,A
	SUB C
	SUB C
	LD L,A
	RET

sub_GetUV_Ext
	RRA
	JR c,sub2_GetUV_Ext
	LD A,(IX+O_U)
	ADD A,4
	LD D,A
	SUB 8
	LD E,A
	LD L,(IX+O_V)
	LD H,L
	INC H
	DEC L
	RET
sub2_GetUV_Ext
	LD A,(IX+O_V)
	ADD A,4
	LD H,A
	SUB 8
	LD L,A
	LD E,(IX+O_U)
	LD D,E
	INC D
	DEC E
	RET

;; -----------------------------------------------------------------------------------------------------------
MenuCursor
	DEFW 0

;; -----------------------------------------------------------------------------------------------------------
;; This is the Main Menu
;; Return with Carry set if new game or with Carry reset for "Continue"
Main_Screen:
	LD A,10
	CALL Set_colors
MainScreen
	LD A,Print_Title_Instr
	CALL Print_String
	LD IX,Main_menu_data
	LD (IX+MENU_CURR_SEL),0
	CALL Draw_Menu
fms_1
	CALL Random_gen
	LD BC,&60 * WORD_HIGH_BYTE + &7B
	LD A,SPR_BM_STANDING
	CALL Main_screen_anim
	CALL Step_Menu
	JR c,fms_1
	LD A,(IX+MENU_CURR_SEL)
	CP &01
	JP c,Play_Game_menu
	JR NZ,fms_2
	CALL Control_menu
	JR Main_Screen

;; -----------------------------------------------------------------------------------------------------------
Batman_anim_vars:
	DEFB 0
	DEFB 2
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
Main_screen_anim
	LD HL,Batman_anim_vars
	DEC (HL)
	RET NZ
	INC HL
	DEC (HL)
	RET NZ
	LD (HL),&02
	INC HL
	DEC (HL)
	BIT 0,(HL)
	PUSH BC
	PUSH AF
	CALL Z,TapFoot
	POP AF
	POP BC
	JP NZ,Draw_sprite_3x32
	CALL Draw_sprite_3x32
	JP TapFoot
fms_2
	CP &03
	JR Z,MenuSensi
	CALL Sound_Menu
	JR MainScreen

MenuSensi
	CALL Sensitivity_Menu
	JR MainScreen

;; -----------------------------------------------------------------------------------------------------------
MENU_CURR_SEL 			EQU		&00							;; Which_selected in menu ; 0 = first
MENU_NB_ITEMS			EQU		&01							;; Number of items
MENU_INIT_COL			EQU		&02							;; Initial column (x)
MENU_INIT_ROW			EQU		&03							;; Initial row (y)
MENU_SEL_STRINGID		EQU		&04							;; Selected item; default: String ID STR_PLAY_THE_GAME

MENU_PRINTDOUBLE_SIZE	EQU		&00							;; if bit7 of MENU_INIT_ROW is reset, then double size the selected row
MENU_PRINTSINGLE_SIZE	EQU		&80							;; if bit7 of MENU_INIT_ROW is set, then single size the selected row

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Main"
;; This is the "Play/Controls/sound/Sensitivity" menu
Main_menu_data
	DEFB 	0     								;; MENU_CURR_SEL : Which_selected in menu ; 0 = firs
	DEFB 	4  									;; MENU_NB_ITEMS : Number of items
	DEFB 	&05    								;; MENU_INIT_COL : Initial column
	DEFB 	&09 or MENU_PRINTSINGLE_SIZE  		;; MENU_INIT_ROW : Initial row, single size the selected row
	DEFB 	Print_PlayTheGame					;; MENU_SEL_STRINGID : Selected item; default: String ID STR_PLAY_THE_GAME

;; -----------------------------------------------------------------------------------------------------------
;; This handle the Sound Menu
.Sound_Menu:
	LD A,Print_BatSound_Menu
	CALL Print_String
	LD IX,Sound_menu_data
	CALL Draw_Menu
smstp_1
	CALL Step_Menu
	JR c,smstp_1
	LD A,&02
	SUB (IX+0)				;; "volume" = 2 - menu index so that "Nasty" has the value 2, "useful" has 1, and "late at night" has 0
	LD (Sound_amount),A		;; store that value
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Sound"
.Sound_menu_data:
	DEFB	0     								;; MENU_CURR_SEL : Which_selected_in_menu ; 0 = first
	DEFB	3 	   								;; MENU_NB_ITEMS : Number of items
	DEFB	&07    								;; MENU_INIT_COL : Initial column
	DEFB	&08 or MENU_PRINTDOUBLE_SIZE		;; MENU_INIT_ROW : Initial row, double size selected
	DEFB	Print_Nasty							;; MENU_SEL_STRINGID : Current Selected item; default String ID STR_LOTS

;; -----------------------------------------------------------------------------------------------------------
Control_menu
	LD A,Print_BatKeys_Menu
	CALL Print_String
	LD IX,Control_menu_data
	CALL Draw_Menu
	LD B,7
ctrlme_loop
	PUSH BC
	LD A,B
	DEC A
	CALL PrepCtrlEdit
	POP BC
	PUSH BC
	LD A,B
	DEC A
	CALL ListControls
	POP BC
	DJNZ ctrlme_loop
cmloop
	CALL Menu_step_Control_Edit
	JR c,cmloop
	RET NZ
	LD A,Print_ChooseNewKey
	CALL Print_String
	LD A,(IX+MENU_CURR_SEL)
	ADD A,(IX+MENU_SEL_STRINGID)
	CALL Print_String
	LD A,Print_ClrEOL
	CALL Print_String
	LD A,(IX+MENU_CURR_SEL)
	CALL PrepCtrlEdit
	LD A,(IX+MENU_CURR_SEL)
	CALL Edit_control
	LD A,Print_ShiftToFinish
	CALL Print_String
	JR cmloop

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Controls"
Control_menu_data
	DEFB	0     								;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB	7	    							;; MENU_NB_ITEMS : Number of items
	DEFB	&00    								;; MENU_INIT_COL : Initial column
	DEFB	&06 or MENU_PRINTSINGLE_SIZE		;; MENU_INIT_ROW : Initial row, single size the selected row
	DEFB	Print_Left							;; MENU_SEL_STRINGID : Selected item String ID

;; -----------------------------------------------------------------------------------------------------------
;; Handle the Sensitivity Menu
.Sensitivity_Menu:
	LD A,Print_SensMenu
	CALL Print_String
	LD IX,Sensitivity_menu_data
	CALL Draw_Menu
sensmenu_1
	CALL Step_Menu
	JR c,sensmenu_1
	LD A,(IX+MENU_CURR_SEL)
	JP Sub_Update_Sensitivity

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Sensitivity"
Sensitivity_menu_data
	DEFB	1     								;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB	2 	   								;; MENU_NB_ITEMS : Number of items
	DEFB	&05    								;; MENU_INIT_COL : Initial column
	DEFB	&09 or MENU_PRINTDOUBLE_SIZE		;; MENU_INIT_ROW : Initial row, double size the selcted row
	DEFB	Print_High							;; MENU_SEL_STRINGID : Selected item String ID

;; -----------------------------------------------------------------------------------------------------------
;; Menu "Old game/New game/Main menu"; only available if we consumed
;; a living fish in a previous game. (RET if Save_point_value = 0)
;; Output: Zero reset: No saved game (go to new Game)
;;         Zero set and Carry reset : Play Old game (saved game)
;;         Zero set and Carry set : Play New game (even though a save exists)
.Play_Game_menu:
	LD A,(Save_point_value) ;; Save_point_value
	CP &01
	RET c
	LD A,Print_PlayOldNew
	CALL Print_String
	LD IX,Play_Game_menu_data
	LD (IX+MENU_CURR_SEL),0
	CALL Draw_menu
pgmen_1
	CALL Step_menu
	JR c,pgmen_1
	LD A,(IX+MENU_CURR_SEL)
	RRA
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Data for the Menu "Play" (only shown if a previous game has been saved = "Fish")
Play_Game_menu_data
	DEFB	0     								;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB	2 	   								;; MENU_NB_ITEMS : Number of items
	DEFB	&09    								;; MENU_INIT_COL : Initial column
	DEFB	&09 or MENU_PRINTDOUBLE_SIZE		;; MENU_INIT_ROW : Initial row, double size the selected row
	DEFB	Print_Old_Game						;; MENU_SEL_STRINGID : Selected item ; default String ID (&A0 = "OLD GAME")

;; -----------------------------------------------------------------------------------------------------------
;; Game over Screen
Game_over_screen
	CALL clr_screen
	CALL Play_Batman_Theme
	LD A,10
	CALL Set_colors
	LD A,Print_GO_assembled
	CALL Print_String
	CALL RecoreredParts
	LD A,E
	CALL subprint_2Digits
	LD A,Print_GO_parts
	CALL Print_String
	CALL RoomCount
	CALL Print_2Digits
	LD A,Print_GO_rooms
	CALL Print_String
	LD A,(nbtimes_died)			;; nb times died 34f2
	CALL subprint_2Digits
	LD A,Print_GO_score
	CALL Print_String
	CALL GetScore
	EX DE,HL
	CALL Print_2Digits
	CALL Batman_Walking_animation
gobw_loop
	CALL Play_Batman_Walking
	JR c,gobw_loop
	RET

;; -----------------------------------------------------------------------------------------------------------
Batman_Walking_animation
	LD BC,&3000
bwa_loop1
	PUSH BC
	CALL Play_Batman_Walking
	POP BC
	DEC BC
	LD A,B
	OR C
	JR NZ,bwa_loop1
bwa_loop2
	CALL Play_Batman_Walking
	CALL HasVoice1DataToPlay
	JR NZ,bwa_loop2
	RET

;; -----------------------------------------------------------------------------------------------------------
Play_Batman_Walking
	LD HL,(Batman_anim_vars)
	LD A,1
	CP L
	JR NZ,Place_Batman_Walking
	CP H
	LD HL,Anim_Batman_walking
	CALL Z,Read_Loop_byte

Place_Batman_Walking
	LD BC,&D0 * WORD_HIGH_BYTE + &78 ;; y,x pos
	CALL Main_screen_anim
	JP Test_Enter_Shift_keys

Anim_Batman_walking:
Anim_Batman_walking_idx:
	DEFB 0
Anim_Batman_walking_data:
	DEFB SPR_BATMAN_1, SPR_BATMAN_0, SPR_BATMAN_2, SPR_BATMAN_0, 0

;; -----------------------------------------------------------------------------------------------------------
Batcraft_complete_screen:
	LD A,9
	CALL Set_colors
	LD A,Print_Completed
	CALL Print_String
	LD BC,&E8 * WORD_HIGH_BYTE + &9C
	LD A,SPR_DEMONB
	CALL Draw_sprite_3x32
	LD BC,&B8 * WORD_HIGH_BYTE + &54
	LD A,SPR_RIDDLER
	CALL Draw_sprite_3x32
	LD BC,&B8 * WORD_HIGH_BYTE + &9C
	LD A,SPR_WOLF_2 or SPR_FLIP
	CALL Draw_sprite_3x32
	LD BC,&E8 * WORD_HIGH_BYTE + &54
	LD A,SPR_JOKER_B1 or SPR_FLIP
	CALL Draw_sprite_3x32
	CALL Play_Batman_Theme
	JP Batman_Walking_animation

;; -----------------------------------------------------------------------------------------------------------
GiveOneMoreLife
	CALL Play_Batman_Theme
	LD A,10
	CALL Set_colors
	LD A,Print_Dogs
	CALL Print_String
	LD BC,&88 * WORD_HIGH_BYTE + &78
	LD A,SPR_DOG_0
	CALL Draw_sprite_3x32
	JP Batman_Walking_animation

;; -----------------------------------------------------------------------------------------------------------
Joystick_Menu
	LD A,10
	CALL Set_colors
	LD A,Print_JoySelect
	CALL Print_String
	LD IX,Joystick_menu_data
	CALL Draw_Menu
jymenu_loop
	CALL Step_Menu
	JR c,jymenu_loop
	RET

;; -----------------------------------------------------------------------------------------------------------
Joystick_menu_data
	DEFB	0				;; MENU_CURR_SEL : Which_selected in menu ; 0 = first
	DEFB	3				;; MENU_NB_ITEMS : Number of items
	DEFB	4				;; MENU_INIT_COL : Initial column
	DEFB	10				;; MENU_INIT_ROW : Initial row, double size the selected row0
	DEFB	Print_JoyMenu	;; MENU_SEL_STRINGID : Selected item ; default String ID

;; -----------------------------------------------------------------------------------------------------------
;; Clear out the screen area and move the cursor for editing a
;; keyboard control setting
.PrepCtrlEdit:
	ADD A,A
	ADD A,(IX+MENU_INIT_ROW)
	AND &7F
	LD B,A
	LD C,&0B
	PUSH BC
	CALL Set_Cursor_position
	LD A,Print_ClrEOL
	CALL Print_String
	POP BC
	JP Set_Cursor_position

;; -----------------------------------------------------------------------------------------------------------
.Menu_step_Control_Edit:
	CALL Test_Enter_Shift_keys
	RET c
	LD A,C
	CP &01
	JR NZ,MenuStepCore
	AND A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Step_Menu : Step thru the menu items and loop over if needs be.
;; Draw_Menu : Draw the menu pointed by IX
.Step_Menu:
	CALL Test_Enter_Shift_keys
	RET c
	LD A,C
MenuStepCore
	AND A
	RET Z
	LD A,(IX+MENU_CURR_SEL)
	INC A
	CP (IX+MENU_NB_ITEMS)
	JR c,mstepc_1
	XOR A
mstepc_1
	LD (IX+MENU_CURR_SEL),A
	PUSH IX
	CALL Sound_ID_Menu_Blip
	POP IX
Draw_Menu
	LD B,(IX+MENU_INIT_ROW)
	RES 7,B
	LD C,(IX+MENU_INIT_COL)
	LD (MenuCursor),BC
	CALL Set_Cursor_position
	LD B,(IX+MENU_NB_ITEMS)
	LD C,(IX+MENU_CURR_SEL)
	INC C
drwmen_loop
	LD A,Print_UnselArrow
	DEC C
	PUSH BC
	JR NZ,smenu_print
	BIT 7,(IX+MENU_INIT_ROW)
	JR NZ,smenu_singlesize
smenu_doublesize
	LD A,Print_DoubleSize
	CALL Print_String
	LD A,Print_BatArrow
	JR smenu_print
smenu_singlesize
	LD A,Print_SingleSize
	CALL Print_String
	LD A,Print_BatArrow
smenu_print
	CALL Print_String
	LD A,(IX+MENU_NB_ITEMS)
	POP BC
	PUSH BC
	SUB B
	ADD A,(IX+MENU_SEL_STRINGID)
	CALL Print_String
	POP HL
	PUSH HL
	LD BC,(MenuCursor)
	LD A,L
	AND A
	JR NZ,br_310E
	BIT 7,(IX+MENU_INIT_ROW)
	JR NZ,br_310E
	INC B
br_310E
	INC B
	PUSH BC
	CALL Set_Cursor_position
	LD A,Print_SingleSize
	CALL Print_String
	BIT 7,(IX+MENU_INIT_ROW)
	JR NZ,br_3123
	LD A,Print_ClrEOL
	CALL Print_String
br_3123
	POP BC
	INC B
	LD (MenuCursor),BC
	CALL Set_Cursor_position
	POP BC
	DJNZ drwmen_loop
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; String attributes
Delimiter						EQU		&FF
Print_WipeScreen				EQU		&00
Print_NewLine					EQU		&01
Print_ClrEOL					EQU		&02
Print_SingleSize				EQU		&03
Print_DoubleSize				EQU		&04
Print_ColorAttr					EQU		&05
Print_SetPos					EQU		&06
;;Print_ColorScheme				EQU		&07
Print_Arrow_1					EQU		&21
Print_Arrow_2					EQU		&22
Print_Arrow_3					EQU		&23
Print_Arrow_4					EQU		&24
Print_Icon_Speed				EQU		&25
Print_Icon_Spring				EQU		&26
Print_Icon_Shield				EQU		&27
Print_PRESS						EQU 	&80
Print_Color_Attr_1				EQU		&81
Print_Color_Attr_2				EQU		&82
Print_Color_Attr_3				EQU		&83
Print_THE						EQU		&84
Print_TO						EQU		&85
Print_BAT						EQU		&86
Print_KEY						EQU		&87
Print_SELECT 					EQU		&88
Print_Instructions				EQU		&89
Print_FINISH 					EQU		&8A
Print_Title 					EQU		&8B
Print_PlayTheGame				EQU		&8C
Print_CONTROL					EQU		&8F
Print_SOUND						EQU		&90
Print_Nasty						EQU		&91
Print_BatKeys_Menu				EQU		&94
Print_ShiftToFinish				EQU		&95
Print_ChooseNewKey				EQU		&96
Print_LEFT						EQU		&97
Print_BatArrow					EQU		&9E
Print_UnselArrow				EQU		&9F
Print_RIGHT						EQU		&98
Print_ENTER 					EQU		&AF
Print_SHIFT 					EQU		&B0
Print_Enter2Finish				EQU		&B1
Print_JoySelect					EQU		&B2
Print_JOYSTICK					EQU		&B3
Print_JoyMenu					EQU		&B4
Print_JOY						EQU		&B7
Print_Spaces					EQU		&BD
Print_Paused					EQU		&BE
Print_ANY						EQU		&BF
Print_GAME						EQU		&C0
Print_HUD_Left					EQU		&C1
Print_BatSound_Menu				EQU		&C2
Print_SENSITIVITY				EQU		&C3
Print_SensMenu					EQU		&C4
Print_High						EQU		&C5
Print_Sgl_Pos					EQU		&C7
Print_PlayOldNew				EQU		&CB
Print_Old_Game					EQU		&CC
Print_Title_Instr				EQU		&CE
Print_GO_assembled				EQU		&CF
Print_GO_parts					EQU		&D0
Print_YOU						EQU		&D1
Print_ClrDbl_Pos				EQU		&D2
Print_1Chance					EQU		&D3
Print_Right_2					EQU		&D6
Print_Left_2					EQU		&D7
Print_Dogs						EQU		&D8
Print_GO_rooms					EQU		&D9
Print_GO_score					EQU		&DA
Print_BATCRAFT					EQU		&DB
Print_Completed					EQU		&DC

;; -----------------------------------------------------------------------------------------------------------
;; Main Strings data
String_Table_Main
	DEFB 	Delimiter, Print_Color_Attr_2, "PRESS "			;; ID &80
	DEFB 	Delimiter, Print_ColorAttr, 1					;; ID &81
	DEFB 	Delimiter, Print_ColorAttr, 2					;; ID &82
	DEFB 	Delimiter, Print_ColorAttr, 3					;; ID &83
	DEFB 	Delimiter, " THE "								;; ID &84
	DEFB 	Delimiter, Print_Color_Attr_2, " TO "			;; ID &85
	DEFB 	Delimiter, "BAT"								;; ID &86
	DEFB 	Delimiter, "KEY"								;; ID &87
	DEFB 	Delimiter, "SELECT"								;; ID &88
	DEFB 	Delimiter, Print_SingleSize						;; ID &89
	DEFB		Print_SetPos, 2, 21
	DEFB		Print_PRESS, Print_ENTER, Print_TO, Print_SELECT
	DEFB		" OPTION", Print_SetPos, 1, 23, " "
	DEFB		Print_PRESS, Print_Color_Attr_3
	DEFB		Print_ANY, Print_KEY, Print_TO
	DEFB 		"MOVE CURSOR", Print_ClrEOL
	DEFB 	Delimiter, "FINISH"								;; ID &8A
	DEFB 	Delimiter, Print_ClrDbl_Pos, 13, 0				;; ID &8B
	DEFB 		Print_Color_Attr_2, Print_BAT, "MAN"
	DEFB 		Print_SingleSize, Print_SetPos, 2, 0
	DEFB 		Print_Color_Attr_3, "JON"
	DEFB 		Print_SetPos, 1, 2, "RITMAN"
	DEFB 		Print_SetPos, &19, 0, "BERNIE"
	DEFB 		Print_SetPos, &18, 2, "DRUMMOND"
	DEFB 	Delimiter, "PLAY", Print_THE, Print_GAME		;; ID &8C
	DEFB 	Delimiter, Print_SELECT, Print_THE			 	;; ID &8D
	DEFB		Print_KEY, "S"
	DEFB 	Delimiter, "ADJUST", Print_THE, Print_SOUND 	;; ID &8E
	DEFB 	Delimiter, "CONTROL", Print_SENSITIVITY			;; ID &8F
	DEFB 	Delimiter, "SOUND"								;; ID &90
	DEFB 	Delimiter, "NASTY"								;; ID &91
	DEFB 	Delimiter, "USEFUL"								;; ID &92
	DEFB 	Delimiter, "LATE AT NIGHT"						;; ID &93
	DEFB 	Delimiter, Print_ClrDbl_Pos, 12, 0				;; ID &94
	DEFB		Print_Color_Attr_1, Print_BAT
	DEFB		Print_KEY, "S", Print_ShiftToFinish
	DEFB 	Delimiter, Print_Instructions					;; ID &95
	DEFB		Print_SetPos, 5, 3, Print_PRESS
	DEFB		Print_Color_Attr_1, Print_SHIFT
	DEFB		Print_TO, Print_FINISH, Print_ClrEOL
	DEFB 	Delimiter, Print_SetPos, 5, 3					;; ID &96
	DEFB		Print_ClrEOL, Print_SetPos, 1, 21
	DEFB		Print_ClrEOL, Print_SetPos, 1, 23
	DEFB		Print_PRESS, Print_Color_Attr_3
	DEFB		Print_KEY, "S", Print_Color_Attr_2
	DEFB		" REQUIRED FOR ", Print_Color_Attr_3
	DEFB 	Delimiter, "LEFT"								;; ID &97
	DEFB 	Delimiter, "RIGHT"								;; ID &98
	DEFB 	Delimiter, "DOWN"								;; ID &99
	DEFB 	Delimiter, "UP"									;; ID &9A
	DEFB 	Delimiter, "JUMP"								;; ID &9B
	DEFB 	Delimiter, "CARRY"								;; ID &9C
	DEFB 	Delimiter, "PAUSE"								;; ID &9D
	DEFB 	Delimiter, Print_Color_Attr_3					;; ID &9E
	DEFB		Print_Arrow_1, Print_Arrow_2, Print_Spaces
	DEFB 	Delimiter, Print_SingleSize, Print_Color_Attr_1	;; ID &9F
	DEFB		Print_Arrow_3, Print_Arrow_4, Print_Spaces
	DEFB 	Delimiter, Print_Color_Attr_3, "SPC"			;; ID &A0
	DEFB 	Delimiter, Print_Color_Attr_3, "SSH"		 	;; ID &A1
	DEFB 	Delimiter, Print_Color_Attr_3, "SHF" 			;; ID &A2
	DEFB 	Delimiter, Print_Color_Attr_3, "TAB" 			;; ID &A3
	DEFB 	Delimiter, Print_Color_Attr_3, "DEL" 			;; ID &A4
	DEFB 	Delimiter, Print_Color_Attr_3, "LCK"			;; ID &A5
	DEFB 	Delimiter, Print_Color_Attr_3, "CTRL"			;; ID &A6
	DEFB 	Delimiter, Print_Color_Attr_3, "COPY"			;; ID &A7
	DEFB 	Delimiter, Print_Color_Attr_3, "ESC"			;; ID &A8
	DEFB 	Delimiter, Print_Color_Attr_3, "ALT"			;; ID &A9
	DEFB 	Delimiter, Print_Color_Attr_3, "ERAZE"			;; ID &AA
	DEFB 	Delimiter, Print_Color_Attr_3, "INS"			;; ID &AB
	DEFB 	Delimiter, Print_Color_Attr_3, "STOP"			;; ID &AC
	DEFB 	Delimiter, Print_Color_Attr_3, "HOLD"			;; ID &AD
	DEFB 	Delimiter, Print_Color_Attr_3, "CLR"			;; ID &AE
	DEFB 	Delimiter, Print_Color_Attr_3, "ENTER"			;; ID &AF
	DEFB 	Delimiter, "SHIFT"								;; ID &B0
	DEFB 	Delimiter, Print_SetPos, 5, 3 					;; ID &B1
	DEFB		Print_PRESS, Print_ENTER, Print_TO
	DEFB		Print_FINISH, Print_ClrEOL
	DEFB 	Delimiter, Print_ClrDbl_Pos, 6, 0				;; ID &B2
	DEFB		Print_Color_Attr_3, Print_JOYSTICK
	DEFB		" ", Print_SELECT, "ION", Print_1Chance
	DEFB 	Delimiter, " JOYSTICK"							;; ID &B3
	DEFB 	Delimiter, Print_KEY, "S", &2F					;; ID &B4
	DEFB		Print_KEY, Print_JOYSTICK
	DEFB 	Delimiter, "KEMPSTON", Print_JOYSTICK			;; ID &B5
	DEFB 	Delimiter, "FULLER", Print_JOYSTICK				;; ID &B6
	DEFB 	Delimiter, Print_Color_Attr_1, "JOY"			;; ID &B7
	DEFB 	Delimiter, Print_JOY, "F"						;; ID &B8
	DEFB 	Delimiter, Print_JOY, "U"						;; ID &B9
	DEFB 	Delimiter, Print_JOY, "D"						;; ID &BA
	DEFB 	Delimiter, Print_JOY, "R"						;; ID &BB
	DEFB 	Delimiter, Print_JOY, "L"						;; ID &BC
	DEFB 	Delimiter, "   "								;; ID &BD
	DEFB 	Delimiter, Print_DoubleSize, Print_Color_Attr_2 ;; ID &BE
	DEFB		Print_SetPos, 3, 3, Print_PRESS
	DEFB		Print_Color_Attr_3, Print_SHIFT, Print_TO
	DEFB		Print_FINISH, " ", Print_GAME
	DEFB		Print_SetPos, 4, 6, Print_PRESS
	DEFB		Print_Color_Attr_3, Print_ANY, Print_KEY
	DEFB		Print_TO, "RESUME"
	DEFB 	Delimiter, "ANY "								;; ID &BF
	DEFB 	Delimiter, "GAME" 								;; ID &C0
	DEFB 	Delimiter, Print_SingleSize, Print_Color_Attr_1	;; ID &C1
	DEFB		Print_SetPos, 0, 21
	DEFB		Print_Arrow_1, Print_Arrow_2
	DEFB		Print_Color_Attr_3, Print_SetPos, 5, 22
	DEFB		Print_Icon_Spring, " ", Print_Color_Attr_2
	DEFB		" ", Print_Icon_Shield, " "
	DEFB		Print_Color_Attr_1, " ", Print_Icon_Speed
	DEFB 	Delimiter, Print_ClrDbl_Pos, 12, 0 				;; ID &C2
	DEFB		Print_Color_Attr_2, Print_BAT, Print_SOUND
	DEFB		Print_Instructions
	DEFB 	Delimiter, " SENSITIVITY"						;; ID &C3
	DEFB 	Delimiter, Print_ClrDbl_Pos, 6, 0  				;; ID &C4
	DEFB		Print_Color_Attr_2, Print_CONTROL
	DEFB		Print_Instructions
	DEFB 	Delimiter, "HIGH", Print_SENSITIVITY			;; ID &C5
	DEFB 	Delimiter, "LOW", Print_SENSITIVITY				;; ID &C6
	DEFB 	Delimiter, Print_SingleSize 					;; ID &C7
	DEFB		Print_SetPos, 10, 23, Print_Color_Attr_2
	DEFB 	Delimiter, Print_DoubleSize  					;; ID &C8
	DEFB		Print_SetPos, 0, 22, Print_Color_Attr_3
	DEFB 	Delimiter, Print_SingleSize  					;; ID &C9
	DEFB		Print_SetPos, 4, 23, Print_Color_Attr_1
	DEFB 	Delimiter, Print_SingleSize						;; ID &CA
	DEFB		Print_SetPos, 7, 23, Print_Color_Attr_3
	DEFB 	Delimiter, Print_ClrDbl_Pos, 9, 0 				;; ID &CB
	DEFB		Print_PlayTheGame, Print_Instructions
	DEFB 	Delimiter, "OLD ", Print_GAME					;; ID &CC
	DEFB 	Delimiter, "NEW ", Print_GAME					;; ID &CD
	DEFB 	Delimiter, Print_Title, Print_Instructions		;; ID &CE
	DEFB 	Delimiter, Print_Title, Print_Color_Attr_3		;; ID &CF
	DEFB		Print_DoubleSize, Print_SetPos, 11, 4
	DEFB		Print_GAME, "  OVER", Print_SingleSize
	DEFB		Print_Color_Attr_1, Print_SetPos, 12, 8
	DEFB		Print_YOU, "HAVE", Print_SetPos, 3, 10
	DEFB		Print_Color_Attr_2, "ASSEMBLED"
	DEFB 	Delimiter, " ", Print_BATCRAFT, "PARTS" 		;; ID &D0
	DEFB		Print_SetPos, 7, 12, "EXPLORED"
	DEFB 	Delimiter, "YOU "								;; ID &D1
	DEFB 	Delimiter, Print_WipeScreen, Print_DoubleSize	;; ID &D2 (needs to be followed by pos x,y)
	DEFB		Print_SetPos
	DEFB	Delimiter,Print_Instructions					;; ID &D3
	DEFB		Print_SetPos, 4, 3, Print_YOU
	DEFB		"ONLY GET ONE CHANCE"
	DEFB		Print_SetPos, 10, 5, "GET IT ", Print_RIGHT
	DEFB	Delimiter, Print_ClrDbl_Pos, 10, 0				;; ID &D4
	DEFB		Print_Color_Attr_3, "SCREEN ", Print_SHIFT
	DEFB		Print_1Chance, Print_SetPos, 0, 0
	DEFB		Print_Color_Attr_1, Print_Left_2
	DEFB		Print_SetPos, &1B, 0, Print_Right_2
	DEFB	Delimiter, Print_FINISH							;; ID &D5
	DEFB	Delimiter, Print_RIGHT							;; ID &D6
	DEFB	Delimiter, Print_LEFT				 			;; ID &D7
	DEFB	Delimiter, Print_ClrDbl_Pos, 10, 9				;; ID &D8
	DEFB		Print_Color_Attr_1, "DOGS"
	DEFB		Print_SetPos, 17, 9, "LIFE"
	DEFB	Delimiter, " ROOMS"								;; ID &D9
	DEFB		Print_SetPos, 9, 14, "DIED "
	DEFB	Delimiter, "  TIMES"							;; ID &DA
	DEFB		Print_SetPos, 11, &16
	DEFB		Print_DoubleSize, Print_Color_Attr_3
	DEFB		"SCORE "
	DEFB	Delimiter, "BATCRAFT "							;; ID &DB
	DEFB	Delimiter, Print_Title, Print_DoubleSize		;; ID &DC
	DEFB		Print_Color_Attr_1, Print_SetPos, 7, 5
	DEFB 		Print_BATCRAFT, "COMPLETE"
	DEFB	Delimiter										;; END ID &DD

;; -----------------------------------------------------------------------------------------------------------
;; Burries the doorway edge into the ground if needed.
;; Takes sprite codes in L and a height in A, and applies truncation
;; of the third column A * 2 + from the top of the column. This
;; performs removal of the bits of the door hidden by the walls.
;; If the door is raised, more of the frame is visible, so A is
;; the height of the door.
.OccludeDoorway:
	PUSH AF
	LD A,L
	LD H,0
	LD (Sprite_Code),A
	CALL Sprite3x56
	EX DE,HL
	LD DE,DoorwayBuf + MOVE_OFFSET
	PUSH DE
	LD BC,56 * 3 * 2
	LDIR
	POP HL
	POP AF
	ADD A,A
	ADD A,8
	CP &39
	JR c,occdw_1
	LD A,&38
occdw_1
	LD B,A
	ADD A,A
	ADD A,B
	LD E,A
	LD D,0
	ADD HL,DE
	EX DE,HL
	LD HL,56 * 3
	ADD HL,DE
	LD A,B
	NEG
	ADD A,&39
	LD B,A
	LD C,&FC
	JR occdw_2

occdw_3
	LD A,(DE)
	AND C
	LD (DE),A
	INC DE
	INC DE
	INC DE
	LD A,C
	CPL
	OR (HL)
	LD (HL),A
	INC HL
	INC HL
	INC HL
	AND A
	RL C
	AND A
	RL C
occdw_2
	DJNZ occdw_3
	XOR A
	LD (DoorwayFlipped),A
	RET

;; -----------------------------------------------------------------------------------------------------------
.Sprite_Width:
	DEFB 	4								;; width of sprite in bytes
Sprite_Code
	DEFB	&00

;; -----------------------------------------------------------------------------------------------------------
	DEFB	0
	DEFB	1

;; -----------------------------------------------------------------------------------------------------------
;; This will init another table in 4F00-4FFF used as a look-up table
;; for byte reverses (RevTable).
;; The final table is:
;;  4F00 : 00 80 40 C0 20 A0 60 E0 10 90 50 D0 30 B0 70 F0
;;  4F10 : 08 88 48 C8    ....                       78 F8
;;  4F20 : 04 84 44 C4    ....                       74 F4
;;  ...    ...            ....                       ...
;;  4FE0 : 07 87 47 C7    ....                       77 F7
;;  4FF0 : 0F 8F 4F CF 2F AF 6F EF 1F 9F 5F DF 3F BF 7F FF
Init_table_rev:
	LD HL,RevTable ;; 4F00
table2_next_idx
	LD C,L
	LD A,1
	AND A
table2_decomp
	RRA
	RL C
	JR NZ,table2_decomp
	LD (HL),A
	INC L
	JR NZ,table2_next_idx
	RET

;; -----------------------------------------------------------------------------------------------------------
;; For a given sprite code, generates the X and Y extents, and sets
;; the current sprite code and sprite width.
;;
;; Parameters: Sprite code in A. X coordinate in C, Y coordinate in B
;; Returns: X extent in BC, Y extent in HL
GetSprExtents:
	LD (Sprite_Code),A
	AND &7F
	CP SPR_1st_3x32_sprite
	JR c,Case3x56
	LD DE,&06 * WORD_HIGH_BYTE + &06
	LD H,&12
	CP SPR_1st_4x28_sprite
	JR c,gsext_1
	LD DE,&08 * WORD_HIGH_BYTE + &08
	LD H,&14
gsext_1
	CP SPR_1st_3x24_sprite
	JR NC,SSW_2
	LD A,(SpriteFlags)
	AND &02
	LD D,&04
	LD H,&0C
	JR Z,SSW_2
	LD D,&00
	LD H,&10
SSW_2
	LD A,B
	ADD A,D
	LD L,A
	SUB D
	SUB H
	LD H,A
	LD A,C
	ADD A,E
	LD C,A
	SUB E
	SUB E
	LD B,A
	LD A,E
	AND A
	RRA
	LD (Sprite_Width),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Horrible hack to get the current object - we're usually
;; called via Blit_Objects, which sets this.
;;
;; However, IntersectObj is also called via AddObject, so err...
;; either something clever's going on, or the extents can be
;; slightly wrong in the AddObject case for doors.
.Case3x56:
	LD HL,(smc_CurrObject2+1)
	INC HL
	INC HL
	BIT 5,(HL)
	EX AF,AF'
	LD A,(HL)
	SUB &10
	CP &20
	LD L,&04
	JR NC,br_359A
	LD L,&08
br_359A
	LD A,B
	ADD A,L
	LD L,A
	SUB &38
	LD H,A
	EX AF,AF'
	LD A,C
	LD B,&08
	JR NZ,br_35A8
	LD B,&04
br_35A8
	ADD A,B
	LD C,A
	SUB &0C
	LD B,A
	LD A,&03
	LD (Sprite_Width),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Looks up based on SpriteCode. Top bit set means flip horizontally.
;; Return height in B, image in DE, mask in HL.
.Load_sprite_image_address_into_DE:
	LD A,(Sprite_Code)
	AND &7F
	CP SPR_1st_4x28_sprite
	JP NC,Sprite4x28
	CP SPR_1st_3x24_sprite
	JR NC,Sprite3x24
	CP SPR_1st_3x32_sprite
	LD H,0
	JR NC,Sprite3x32
	LD L,A
	LD DE,(smc_CurrObject2+1)
	INC DE
	INC DE
	LD A,(DE)
	OR &FC
	INC A
	JR NZ,Sprite3x56
	LD A,(Sprite_Code)
	LD C,A
	RLA
	LD A,(RoomDimensionsIdx)
	JR c,br_35E2
	CP &06
	JR br_35E4
br_35E2
	CP &03
br_35E4
	JR Z,Sprite3x56
	LD A,(DoorwayFlipped)
	XOR C
	RLA
	LD DE,DoorwayImgBuf + MOVE_OFFSET
	LD HL,DoorwayMaskBuf + MOVE_OFFSET
	RET NC
	LD A,C
	LD (DoorwayFlipped),A
	LD B,56*2
	JR FlipSprite3

;; -----------------------------------------------------------------------------------------------------------
;; Deal with a 3 byte x sprite 56 pixels high.
;; Same parameters/return as Load_sprite_image_address_into_DE.
Sprite3x56
	LD A,L
	LD E,A
	ADD A,A
	ADD A,A
	ADD A,E
	ADD A,A
	LD L,A
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	LD A,E
	ADD A,H
	LD H,A
	LD DE,img_3x56_bin	+ MOVE_OFFSET ;; 6BF0 : Doorways
	ADD HL,DE
	LD DE,56*3
	LD B,56*2
	JR Sprite3Wide

;; -----------------------------------------------------------------------------------------------------------
;; Deal with a 3 byte x 32 pixel high sprite.
;; Same parameters/return as Load_sprite_image_address_into_DE.
;;
;; Returns a half-height offset sprite if bit 2 is not set, since the
;; 3x32 sprites are broken into 2 16-bit-high chunks.
.Sprite3x32:
	SUB SPR_1st_3x32_sprite
	LD L,A
	ADD A,A
	ADD A,L
	LD L,A
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	LD DE,img_3x32_bin	+ MOVE_OFFSET ;; 7E50 : Regular sprites
	ADD HL,DE
	LD DE,32*3
	LD B,32*2
	EX DE,HL
	ADD HL,DE
	EXX
	CALL NeedsFlip
	EXX
	CALL NC,FlipSprite3
	LD A,(SpriteFlags)
	AND &02
	RET NZ
	LD BC,16*3
	ADD HL,BC
	EX DE,HL
	ADD HL,BC
	EX DE,HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Deal with a 3 byte (x2 img/mask, 4pix per byte, hence 3*2*4 = 24 pix wide) x 24 pixel high sprite
;; Same parameters/return as Load_sprite_image_address_into_DE.
;; Return : height image+mask in B, image in DE, mask in HL.
.Sprite3x24:
	SUB SPR_1st_3x24_sprite
	LD L,A
	ADD A,A
	ADD A,A
	ADD A,A
	ADD A,L
	LD L,A
	ADC A,0
	SUB L
	LD H,A
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	LD DE,img_3x24_bin	+ MOVE_OFFSET ;; 9410
	ADD HL,DE
	LD DE,24*3
	LD B,24*2
Sprite3Wide
	EX DE,HL
	ADD HL,DE
	EXX
	CALL NeedsFlip
	EXX
	RET c
;; Flip a 3-character-wide sprite. Height in B, source in DE.
.FlipSprite3:
	PUSH HL
	PUSH DE
	EX DE,HL
	LD D,RevTable / WORD_HIGH_BYTE	 ;; 4F
fspr3_loop
	LD C,(HL)
	LD (smc_flipsprite3+1),HL
	INC HL
	LD E,(HL)
	LD A,(DE)
	LD (HL),A
	INC HL
	LD E,(HL)
	LD A,(DE)
smc_flipsprite3
	LD (NULL_PTR),A
	LD E,C
	LD A,(DE)
	LD (HL),A
	INC HL
	DJNZ fspr3_loop
	POP DE
	POP HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Looks up a 4x28 sprite.
;; Same parameters/return as Load_sprite_image_address_into_DE.
.Sprite4x28:
	SUB SPR_1st_4x28_sprite
	LD D,A
	RLCA
	RLCA
	LD H,0
	LD L,A
	LD E,H
	ADD HL,HL
	ADD HL,HL
	ADD HL,HL
	EX DE,HL
	SBC HL,DE
	LD DE,img_4x28_bin	+ MOVE_OFFSET ;; A580
	ADD HL,DE
	LD DE,28*4
	LD B,28*2
	EX DE,HL
	ADD HL,DE
	EXX
	CALL NeedsFlip
	EXX
	RET c
;; Flip a 4-character-wide sprite. Height in B, source in DE.
flipSprite4:
	PUSH HL
	PUSH DE
	EX DE,HL
	LD D,RevTable / WORD_HIGH_BYTE	 ;; 4F
fspr4_loop
	LD C,(HL)
	LD (smc_fs_addr+1),HL
	INC HL
	LD E,(HL)
	INC HL
	LD A,(DE)
	LD E,(HL)
	LD (HL),A
	DEC HL
	LD A,(DE)
	LD (HL),A
	INC HL
	INC HL
	LD E,(HL)
	LD A,(DE)
smc_fs_addr
	LD (NULL_PTR),A
	LD E,C
	LD A,(DE)
	LD (HL),A
	INC HL
	DJNZ fspr4_loop
	POP DE
	POP HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Look up the sprite in the bitmap, returns with Carry set if the top bit of
;; SpriteCode matches the bitmap, otherwise updates the bitmap (assumes
;; that the caller will flip the sprite if we return NC). In effect, a
;; simple cache.
.NeedsFlip:
	LD A,(Sprite_Code)
	LD C,A
	AND &07
	INC A
	LD B,A
	LD A,&01
ndflp_1
	RRCA
	DJNZ ndflp_1
	LD B,A
	LD A,C
	RRA
	RRA
	RRA
	AND &0F
	LD E,A
	LD D,0
	LD HL,SpriteFlips_buffer + MOVE_OFFSET ;; 56E0
	ADD HL,DE
	LD A,B
	AND (HL)
	JR Z,SubNeedsFlip
	RL C
	RET c
	LD A,B
	CPL
	AND (HL)
	LD (HL),A
	RET

SubNeedsFlip
	RL C
	CCF
	RET c
	LD A,B
	OR (HL)
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Are the contents of DoorwayBuf flipped?
.DoorwayFlipped:
	DEFB 0

CurrObject
	DEFW &00FA

ObjDir
	DEFB &FF

;; -----------------------------------------------------------------------------------------------------------
;; Takes an object pointer in IY, an object code in A (index in the
;; ObjDefns list when ReadRoom), and initialises it.
;; Doesn't set flags, direction code, or coordinates.
;; Must then call AddObject to copy it into the room.
InitObj
	LD L,A
	LD E,A
	LD D,0				;; DE = index
	LD H,D				;; HL = index
	ADD HL,HL			;; HL = 2 * index
	ADD HL,DE			;; HL = 3 * index
	LD DE,ObjDefns 		;; ObjDefns 2C85
	ADD HL,DE			;; HL = ObjDefns + (3 * index)
	LD A,(HL)			;; get sprite
SetObjSprite
	LD (IY+O_ANIM),0
	LD (IY+O_SPRITE),A
	CP &80
	JR c,sos_skip		;; if < &80 skip, else it has anim loop
	ADD A,A				;; else if >= &80:
	ADD A,A
	ADD A,A				;; A[4:0]<<3
	LD (IY+O_ANIM),A
	PUSH HL
	CALL AnimateObj
	POP HL
sos_skip
	INC HL
	LD A,(HL)
	LD (IY+O_FUNC),A
	INC HL
	LD A,(HL)
	CP &80
	RES 7,A
	LD (IY-1),A			;; BaseFlags+1 (IY = TmpObj_variables)
	LD (IY-2),&02		;; BaseFlags (IY = TmpObj_variables)
	RES 2,(IY+O_SPRFLAGS)
	RET c
	SET 2,(IY+O_SPRFLAGS)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes an object pointer in DE (From ObjectsBuffer 6A40-...), and
;; index the object function in A.
;; Note that the function ID starts at 1, so to align on the ObjFnTbl
;; table, need to do a -1.
;; The object is of the same format that TmpObj_variables.
.CallObjFn:
	LD (CurrObject),DE
	PUSH DE
	POP IY
	DEC A
	ADD A,A
	ADD A,ObjFnTbl and WORD_LOW_BYTE
	LD L,A
	ADC A,ObjFnTbl / WORD_HIGH_BYTE ;; 2C4F
	SUB L
	LD H,A			;; HL = ObjFnTbl + 2 * (A-1)
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	XOR A
	LD (DrawFlags),A
	LD A,(IY+O_IMPACT)
	LD (ObjDir),A
	LD (IY+O_IMPACT),&FF
	JP (HL)

;; -----------------------------------------------------------------------------------------------------------
;; Update the animation. IY points to an object.
;; Returns with carry flag set if it's an animation. (NC if not)
AnimateObj
.Animate:
	LD C,(IY+O_ANIM)
	LD A,C
	AND &F8
	CP FIRST_ANIM_code
	CCF
	RET NC
	RRCA
	RRCA
	SUB 2
	ADD A,AnimTable and WORD_LOW_BYTE
	LD L,A
	ADC A,AnimTable / WORD_HIGH_BYTE ;; 2BDD
	SUB L
	LD H,A			;; HL = AnimTable
	LD A,C
	INC A
	AND &07
	LD B,A
	ADD A,(HL)
	LD E,A
	INC HL
	ADC A,(HL)
	SUB E
	LD D,A
	LD A,(DE)
	AND A
	JR NZ,Anim1
	LD B,0
	LD A,(HL)
	DEC HL
	LD L,(HL)
	LD H,A
	LD A,(HL)
Anim1
	LD (IY+O_SPRITE),A
	LD A,B
	XOR C
	AND &07
	XOR C
	LD (IY+O_ANIM),A
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Pointers on the anim sprites list from the anim codes [7:3] and [2:0] frame
;; Note : The 'B' version is the moving-away-from-viewers version (Back/rear view).
;; The code &00 = no anim.
ANIM_VAPE				EQU		&81
ANIM_WOLF				EQU		&82
ANIM_SHARK 				EQU		&84
ANIM_DOG 				EQU		&86
ANIM_JOKER 				EQU		&88
ANIM_DEMON 				EQU		&8A
ANIM_SALT 				EQU		&8C
ANIM_RIDDLER 			EQU		&8E
ANIM_WORM 				EQU		&90
ANIM_BIGVAPE 			EQU		&92
ANIM_BEACON 			EQU		&94
;; -----------------------------------------------------------------------------------------------------------
;; value set in O_ANIM; [7:3] = AnimID (bit3=Front/Back for most values); [2:0] = frame index
NO_ANIM_code			EQU		&00					;; [7:3] AnimID = 0 (no anim), [2:0] frame = 0
ANIM_VAPE_code			EQU		&08					;; [7:3] AnimID = 1 (&81), [2:0] frame = 0
FIRST_ANIM_code			EQU		ANIM_VAPE_code
;; -----------------------------------------------------------------------------------------------------------

.AnimTable:
	DEFW anim_sml_vape		;; &81 ; bit7 set, code1 will become &08 + phase in O_ANIM
	DEFW anim_f_wolf		;; &82
	DEFW anim_b_wolf        ;; &83
	DEFW anim_f_shark       ;; &84
	DEFW anim_b_shark       ;; &85
	DEFW anim_f_dog         ;; &86
	DEFW anim_b_dog         ;; &87
	DEFW anim_f_joker       ;; &88
	DEFW anim_b_joker       ;; &89
	DEFW anim_f_demon       ;; &8A
	DEFW anim_b_demon       ;; &8B
	DEFW anim_x_salt        ;; &8C
	DEFW anim_x_salt        ;; &8D
	DEFW anim_f_riddler     ;; &8E
	DEFW anim_b_riddler     ;; &8F
	DEFW anim_x_worm        ;; &90
	DEFW anim_x_worm        ;; &91
	DEFW anim_big_vape      ;; &92
	DEFW anim_big_vape      ;; &93
	DEFW anim_x_beacon      ;; &94
	DEFW anim_x_beacon      ;; &95 ; bit7 set, code1 will become &A0 + phase in O_ANIM

;; -----------------------------------------------------------------------------------------------------------
.AnimTable_data:
anim_sml_vape:
	DEFB SPR_VAPE_2 or SPR_FLIP, SPR_VAPE_2, SPR_VAPE_1, SPR_VAPE_0, 0
anim_f_wolf:
	DEFB SPR_WOLF_0, SPR_WOLF_1, SPR_WOLF_0, SPR_WOLF_2, 0
anim_b_wolf:
	DEFB SPR_WOLF_B0, SPR_WOLF_B1, SPR_WOLF_B0, SPR_WOLF_B2, 0
anim_f_shark:
	DEFB SPR_SHARK_0, SPR_SHARK_0, SPR_SHARK_1, SPR_SHARK_1, 0
anim_b_shark:
	DEFB SPR_SHARK_B0, SPR_SHARK_B0, SPR_SHARK_B1, SPR_SHARK_B1, 0
anim_f_dog:
	DEFB SPR_DOG_0, SPR_DOG_0, SPR_DOG_1, SPR_DOG_1, 0
anim_b_dog:
	DEFB SPR_DOG_B0, SPR_DOG_B0, SPR_DOG_B1, SPR_DOG_B1, 0
anim_f_joker
	DEFB SPR_JOKER, 0
anim_b_joker:
	DEFB SPR_JOKERB, SPR_JOKERB, SPR_JOKERB, SPR_JOKERB, SPR_JOKER_B1, SPR_JOKER_B1, 0
anim_f_demon:
	DEFB SPR_DEMON, 0
anim_b_demon:
	DEFB SPR_DEMONB, 0
anim_x_salt:
	DEFB SPR_SALT, SPR_SALT or SPR_FLIP, 0
anim_f_riddler:
	DEFB SPR_RIDDLER, 0
anim_b_riddler:
	DEFB SPR_RIDDLERB, 0
anim_x_worm:
	DEFB SPR_WORM_0, SPR_WORM_0, SPR_WORM_1, SPR_WORM_1, 0
anim_big_vape:
	DEFB SPR_VAPE_0, SPR_VAPE_0 or SPR_FLIP, SPR_VAPE_1 or SPR_FLIP, SPR_VAPE_1, SPR_VAPE_2, SPR_VAPE_2 or SPR_FLIP, SPR_VAPE_1 or SPR_FLIP, SPR_VAPE_1, 0
anim_x_beacon:
	DEFB SPR_BEACON, SPR_BEACON or SPR_FLIP, 0

;; -----------------------------------------------------------------------------------------------------------
;; Function names will be kept consitent with the ones in Head Over Heels
OBJFN_FADE				EQU	&12

.ObjFnTbl:
	DEFW ObjFnPushable		;; &01 	3DD0
	DEFW ObjFnRollers1		;; &02  3D85
	DEFW ObjFnRollers2		;; &03  3D89
	DEFW ObjFnRollers3		;; &04  3D8D
	DEFW ObjFnRollers4		;; &05  3D91
	DEFW ObjFnVisor1		;; &06  3DE7
	DEFW ObjFnMonocat		;; &07  3DEC
	DEFW ObjFnAnticlock		;; &08  3DF1
	DEFW ObjFnRandB			;; &09  3E05
	DEFW ObjFnBall			;; &0A  3D04
	DEFW ObjFnBee			;; &0B  3DF6
	DEFW ObjFnRandK			;; &0C  3DFB
	DEFW ObjFnRandR			;; &0D  3E00
	DEFW ObjFnTowards		;; &0E  3E0F
	DEFW ObjFnSwitch		;; &0F  3D52
	DEFW ObjFnHomeIn		;; &10  3E0A
	DEFW ObjFnHeliplat3		;; &11  3E6B
	DEFW ObjFnFade			;; &12  3DB6
	DEFW ObjFnHeliplat60	;; &13  3D6A
	DEFW ObjFnHeliplat10	;; &14  3D70
	DEFW ObjFnColapse		;; &15  3D7A
	DEFW ObjFnDissolve2		;; &16  3D9E
	DEFW ObjFnSquarePatrol	;; &17  3DE1
	DEFW ObjFnLinePatrol	;; &18  3DDB
	DEFW ObjFnHeliplat90	;; &19  3D67
	DEFW ObjFnHeliplat30	;; &1A  3D6D
	DEFW ObjFnDissolve		;; &1B  3D9B

;; -----------------------------------------------------------------------------------------------------------
;; Define the objects that can appear in a room definition
;; "sprite codes" >= &81 are animations
ObjDefns: 		;;		<sprite code> 	<function> 						<flag>
	DEFB SPR_S_CUSHION, &01, &40 ;; SPR_S_CUSHION
	DEFB SPR_PRESENT, &01, &40 ;; SPR_PRESENT
	DEFB SPR_WELL, &01, &40 ;; SPR_WELL
	DEFB SPR_PAWDRUM, &01, &40 ;; SPR_PAWDRUM
	DEFB SPR_STOOL, &01, &40 ;; SPR_STOOL
	DEFB SPR_PILLAR, 0, &00 ;; SPR_PILLAR
	DEFB SPR_KETTLE, &01, &40 ;; SPR_KETTLE
	DEFB SPR_SUGARBOX, &01, &40 ;; SPR_SUGARBOX
	DEFB SPR_BUNDLE, &01, &40 ;; SPR_BUNDLE
	DEFB SPR_QBALL, &0A, &20 ;; SPR_QBALL
	DEFB SPR_BUBBLE, &0A, &00 ;; SPR_BUBBLE
	DEFB SPR_CRATE, &01, &01 ;; SPR_CRATE
	DEFB SPR_WELL, 0, &00 ;; SPR_WELL
	DEFB SPR_SWITCH, &0F, &00 ;; SPR_SWITCH
	DEFB ANIM_SALT, &09, &20
	DEFB SPR_SHROOM, 0, &20 ;; SPR_SHROOM
	DEFB SPR_TURTLE, &19, &01 ;; SPR_TURTLE
	DEFB SPR_QBALL, &16, &00 ;; SPR_QBALL
	DEFB SPR_SMILEY, &01, &01 ;; SPR_SMILEY
	DEFB SPR_ROLLER, &02, &11 ;; SPR_ROLLER
	DEFB SPR_ROLLER, &03, &11 ;; SPR_ROLLER
	DEFB SPR_ROLLER, &04, &01 ;; SPR_ROLLER
	DEFB SPR_ROLLER, &05, &01 ;; SPR_ROLLER
	DEFB SPR_STEPBOX, &02, &01 ;; SPR_STEPBOX
	DEFB SPR_STEPBOX, &03, &01 ;; SPR_STEPBOX
	DEFB SPR_STEPBOX, &04, &01 ;; SPR_STEPBOX
	DEFB SPR_STEPBOX, &05, &01 ;; SPR_STEPBOX
	DEFB SPR_CLEARBOX, 0, &01 ;; SPR_CLEARBOX
	DEFB SPR_STEPBOX, 0, &01 ;; SPR_STEPBOX
	DEFB SPR_COLUMN, 0, &01 ;; SPR_COLUMN
	DEFB SPR_Z_CUSHION, 0, &21 ;; SPR_Z_CUSHION
	DEFB SPR_TURTLE, 0, &01 ;; SPR_TURTLE
	DEFB SPR_TABLE, 0, &01 ;; SPR_HELIPLAT
	DEFB SPR_CRATE, 0, &01 ;; SPR_CRATE
	DEFB SPR_DSPIKES, 0, &01 ;; SPR_DSPIKES
	DEFB SPR_BRICKW, 0, &02 ;; SPR_BRICKW
	DEFB SPR_LAVAPIT, 0, &21 ;; SPR_LAVAPIT
	DEFB SPR_ECRIN, 0, &21 ;; SPR_ECRIN
	DEFB SPR_BOX, 0, &21 ;; SPR_BOX
	DEFB SPR_TARBOX, 0, &21 ;; SPR_TARBOX
	DEFB &60, 0, &A2
	DEFB SPR_DSPIKES, &1A, &A2 ;; SPR_DSPIKES
	DEFB SPR_STEPBOX, &16, &01 ;; SPR_STEPBOX
	DEFB SPR_CLEARBOX, &16, &01 ;; SPR_CLEARBOX
	DEFB SPR_COLUMN, &16, &01 ;; SPR_COLUMN
	DEFB SPR_CRATE, &16, &01 ;; SPR_CRATE
	DEFB ANIM_BEACON, &0B, &20
	DEFB ANIM_WORM, &0B, &20
	DEFB ANIM_BIGVAPE, &0C, &20
	DEFB ANIM_WOLF, &06, &28
	DEFB ANIM_DEMON, &06, &28
	DEFB ANIM_SHARK, &0D, &28
	DEFB SPR_RIDDLER, 0, &28 ;; SPR_ONEEYE
	DEFB ANIM_JOKER, &08, &28
	DEFB SPR_DEMON, 0, &28 ;; SPR_DEMON
	DEFB SPR_DEMONB, 0, &28 ;; SPR_DEMONB
	DEFB ANIM_DOG, &07, &28
	DEFB SPR_STEPBOX, &19, &01 ;; SPR_STEPBOX
	DEFB SPR_STEPBOX, &15, &01 ;; SPR_STEPBOX
	DEFB SPR_COLUMN, &18, &01 ;; SPR_COLUMN
	DEFB SPR_COLUMN, &17, &01 ;; SPR_COLUMN
	DEFB SPR_COLUMN, &15, &01 ;; SPR_COLUMN
	DEFB SPR_TARBOX, &19, &21 ;; SPR_TARBOX
	DEFB SPR_PILLAR, &14, &A0 ;; SPR_PILLAR
	DEFB SPR_TARBOX, &13, &21 ;; SPR_TARBOX
	DEFB ANIM_RIDDLER, &10, &28
	DEFB ANIM_SALT, &0E, &00
	DEFB SPR_PRESENT, &1B, &20 ;; SPR_PRESENT

;; -----------------------------------------------------------------------------------------------------------
;; Reinitialisation size of the array
;; The Reinitialise call with 3986 as argument will copy the 27 bytes of
;; ObjVars_reset_data into the ObjListIdx & after
ObjVars:
	DEFB 27 ;; length
ObjVars_reset_data
	DEFB 	&00								;; reset for idx Objects
	DEFW 	ObjectsBuffer      				;; reset for dest Objects 5040
	DEFW 	ObjList_Regular_Far2Near		;; reset for B List Pointer ObjectLists
	DEFW 	ObjList_Regular_Near2Far		;; reset for A List Pointer ObjectLists + 2
	DEFW 	NULL_PTR, NULL_PTR				;; reset for B and A usual list 1st item
	DEFW 	NULL_PTR, NULL_PTR				;; reset for Next V room B & A
	DEFW 	NULL_PTR, NULL_PTR				;; reset for Next U room B & A
	DEFW 	NULL_PTR, NULL_PTR				;; reset for Next Far room B & A
	DEFW 	NULL_PTR, NULL_PTR				;; reset for Next Near room B & A

.SaveRestore_Block2:											;; Save/Restore block 2 : &1D (29 bytes)
.ObjListIdx:													;; The index into ObjectLists.
	DEFB 	&00
Object_Destination:												;; Current pointer for where we write objects into (6A40 buffer)
	DEFW 	ObjectsBuffer
;; 'A' list item pointers are offset +2 from 'B' list pointers.
.ObjListF2NPtr:
	DEFW 	ObjList_Regular_Far2Near		;; pointer on the B list start (ObjectLists + 0
.ObjListN2FPtr:
	DEFW 	ObjList_Regular_Near2Far		;; pointer on the A list start (ObjectLists + 2

ObjectLists:
ObjList_Regular_Far2Near:										;; list type 0 ; ObjectLists + 0 ; Regular B (Far to Near) list 1st item pointer
	DEFW 	NULL_PTR
ObjList_NextRoomV_Far2Near:                        				;; list type 1 ; ObjectLists + 4 ; Next room in V direction B list pointers
	DEFW 	NULL_PTR
ObjList_NextRoomU_Far2Near:           							;; list type 2 ; ObjectLists + 8 ; Next room in U direction B list pointers
	DEFW 	NULL_PTR
ObjList_Far_Far2Near:                 							;; list type 3 ; ObjectLists + 12 ; Far (far corner of main room) B list pointers
	DEFW 	NULL_PTR
ObjList_Near_Far2Near:                							;; list type 4 ; ObjectLists + 16 ; Near (near corner of main room) B list pointers
	DEFW 	NULL_PTR

ObjList_Regular_Near2Far:                         				;; list type 0 ; ObjectLists + 2 ; Regular A (Near to Far) list 1st item pointer
	DEFW 	NULL_PTR
ObjList_NextRoomV_Near2Far:           		            		;; list type 1 ; ObjectLists + 6 ; Next room in V direction A list pointers
	DEFW 	NULL_PTR
ObjList_NextRoomU_Near2Far:          							;; list type 2 ; ObjectLists + 10 ; Next room in U direction A list pointers
	DEFW 	NULL_PTR
ObjList_Far_Near2Far:                 							;; list type 3 ; ObjectLists + 14 ; Far A list pointers
	DEFW 	NULL_PTR
ObjList_Near_Near2Far:                							;; list type 4 ; ObjectLists + 18 ; Near A list pointers
	DEFW 	NULL_PTR

;; -----------------------------------------------------------------------------------------------------------
.SortObj:
	DEFW 	NULL_PTR

;; -----------------------------------------------------------------------------------------------------------
;; Set the object list index and pointers. list index in A (3 far, 4 near, 0 mid), .
.SetObjList:
	LD (ObjListIdx),A
	ADD A,A
	ADD A,A
	ADD A,ObjectLists_ptr and WORD_LOW_BYTE ;; 2D9F
	LD L,A
	ADC A,ObjectLists_ptr / WORD_HIGH_BYTE ;; 2D9F
	SUB L
	LD H,A
	LD DE,ObjListF2NPtr
	LD BC,4
	LDIR
	RET

;; -----------------------------------------------------------------------------------------------------------
ObjectLists_ptr
	DEFW ObjList_Regular_Far2Near
	DEFW ObjList_Regular_Near2Far
	DEFW ObjList_NextRoomV_Far2Near
	DEFW ObjList_NextRoomV_Near2Far
	DEFW ObjList_NextRoomU_Far2Near
	DEFW ObjList_NextRoomU_Near2Far
	DEFW ObjList_Far_Far2Near
	DEFW ObjList_Far_Near2Far
	DEFW ObjList_Near_Far2Near
	DEFW ObjList_Near_Near2Far

;; -----------------------------------------------------------------------------------------------------------
;; DE contains an 'A' list object pointer. Assumes the other half of the object
;; is in the next slot (+0x12). Syncs the object UVZ and state.
.SyncDoubleObject:
	LD HL,OBJECT_LENGTH
	ADD HL,DE
	PUSH HL
	EX DE,HL
	LD BC,5
	LDIR
	LD A,(HL)
	SUB 6
	LD (DE),A
	INC DE
	INC HL
	LDI
	POP HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Copy an object into the object buffer, add a second object if it's
;; doubled, and link it into the depth-sorted lists.
;;
;; HL is a 'B' pointer to an object.
;; BC contains the size of the object (18 bytes).
.AddObject:
	PUSH HL
	PUSH BC
	INC HL
	INC HL
	CALL IntersectObj
	POP BC
	POP HL
	RET NC
	LD DE,(Object_Destination)
	PUSH DE
	LDIR
	LD (Object_Destination),DE
	POP HL
	PUSH HL
	POP IY
	BIT 3,(IY+O_FLAGS)
	JR Z,Enlist
	;; Bit3 of O_FLAGS is set = tall object. Make the second object like
    ;; the first, copying offsets 0 to 8, then offset 9 (setting bit1)
	;; offset 10 will be &00,
	LD BC,&0009
	PUSH HL
	LDIR
	EX DE,HL
	LD A,(DE)
	OR &02
	LD (HL),A
	INC HL
	LD (HL),0
	INC HL					;; In Head Over Heels this HL + 8 is
	INC HL					;; done like so:
	INC HL					;; LD DE,8
	INC HL					;; ADD HL,DE
	INC HL
	INC HL
	INC HL
	INC HL
	LD (Object_Destination),HL
	POP HL
	;; will fall in Enlist
;; -----------------------------------------------------------------------------------------------------------
;; Enlist the object. Both HL and IY point on the copied Object addr
.Enlist:
	LD A,(ObjListIdx)
	DEC A
	CP &02
	JR NC,EnlistAux
	INC HL
	INC HL
	BIT 3,(IY+O_FLAGS)
	JR Z,EnlistObj
	PUSH HL
	CALL EnlistObj
	POP DE
	CALL SyncDoubleObject
	PUSH HL
	CALL GetUVZExtents_Far2Near
	EXX
	PUSH IY
	POP HL
	INC HL
	INC HL
	JR DepthInsert

;; -----------------------------------------------------------------------------------------------------------
;; Put the object in HL into its depth-sorted position in the list.
.EnlistObj:
	PUSH HL
	CALL GetUVZExtents_Far2Near
	EXX
	JR DepthInsertHd

;; -----------------------------------------------------------------------------------------------------------
;; Takes a B pointer in HL/IY. Enlists it, and its other half if it's a
;; double-size object. Inserts inthe the appropriate list.
EnlistAux
	INC HL
	INC HL
	BIT 3,(IY+O_FLAGS)
	JR Z,EnlistObjAux
	PUSH HL
	CALL EnlistObjAux
	POP DE
	CALL SyncDoubleObject
	PUSH HL
	CALL GetUVZExtents_Far2Near
	EXX
	PUSH IY
	POP HL
	INC HL
	INC HL
	JR DepthInsert

;; -----------------------------------------------------------------------------------------------------------
;; Object in HL. Inserts object into appropriate object list
;; based on coordinates.
;; List 3 is far away in the main room, 0 in "middle", 4 is near.
EnlistObjAux
	PUSH HL
	CALL GetUVZExtents_Far2Near
	LD A,3
	EX AF,AF'
	LD A,(MaxU)
	CP D
	JR c,elonjax_1
	LD A,(MaxV)
	CP H
	JR c,elonjax_1
	LD A,4
	EX AF,AF'
	LD A,(MinU)
	DEC A
	CP E
	JR NC,elonjax_1
	LD A,(MinV)
	DEC A
	CP L
	JR NC,elonjax_1
	XOR A
	EX AF,AF'
elonjax_1
	EXX
	EX AF,AF'
	CALL SetObjList
	;; will fall in DepthInsertHd
;; -----------------------------------------------------------------------------------------------------------
;; DepthInsertHd : Does a DepthInsert on the list pointed to by ObjListF2NPtr.
;; DepthInsert : Object extents in alt registers, 'B' pointer (far to near) in HL.
;; Object to insert is on the stack.
;; Goes thru the list sorted far-to-near, and loads up HL with the
;; nearest object further away from our object.
.DepthInsertHd:
	LD HL,(ObjListF2NPtr)
DepthInsert
	LD (SortObj),HL
DepIns2
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,DepIns3
	PUSH HL
	CALL GetUVZExtents_Far2Near
	CALL DepthCmp
	POP HL
	JR NC,DepthInsert
	AND A
	JR NZ,DepIns2
DepIns3
	LD HL,(SortObj)
	POP DE
	LD A,(HL)
	LDI
	LD C,A
	LD A,(HL)
	LD (DE),A
	DEC DE
	LD (HL),D
	DEC HL
	LD (HL),E
	LD L,C
	LD H,A
	OR C
	JR NZ,br_3ADF
	LD HL,(ObjListN2FPtr)
	INC HL
	INC HL
br_3ADF
	DEC HL
	DEC DE
	LDD
	LD A,(HL)
	LD (DE),A
	LD (HL),E
	INC HL
	LD (HL),D
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Take an object out of the list, and reinserts it in the
;; appropriate list.
.Relink:
	PUSH HL
	CALL Unlink
	POP HL
	JP EnlistAux

;; -----------------------------------------------------------------------------------------------------------
;; Unlink the object in HL. If bit 3 of IY+4 is set, it's an
;; object made out of two subcomponents, and both must be
;; unlinked.
.Unlink:
	BIT 3,(IY+O_FLAGS)
	JR Z,UnlinkObj
	PUSH HL
	CALL UnlinkObj
	POP DE
	LD HL,OBJECT_LENGTH
	ADD HL,DE
UnlinkObj
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	PUSH DE
	LD A,D
	OR E
	JR NZ,ulnk_1
	LD DE,(ObjListF2NPtr)
	DEC DE
	DEC DE
ulnk_1
	INC DE
	INC DE
	LD A,(HL)
	LDI
	LD C,A
	LD A,(HL)
	LD (DE),A
	LD H,A
	LD L,C
	OR C
	JR NZ,br_3B1F
	LD HL,(ObjListN2FPtr)
	INC HL
	INC HL
br_3B1F
	DEC HL
	POP DE
	LD (HL),D
	DEC HL
	LD (HL),E
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Like "GetUVZExtents_Near2Far", but applies extra height adjustment.
;; A has the object flags.
;; Increases height by 6 if flag bit 3 is set.
.GetUVZExtents_AdjustLowZ:
	CALL GetUVZExtents_Near2Far
	AND &08
	RET Z
	LD A,C
	SUB 6
	LD C,A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; * GetUVZExtents_Near2Far : At entry, HL points on the object variables array + 0 (ie. A list pointer)
;;    (Apparently GetUVZExtents_Near2Far is only used by Heels_variables and Head_variables).
;;    Then first thing, HL will be updated to point on Object O_FLAGS
;; * GetUVZExtents_Far2Near :  At entry, HL points on the object variables array + 2 (ie. B list pointer)
;; 	  Then first thing, HL will be updated to point on Object O_FLAGS
;; So given an object (variables array) in HL, returns its U, V and Z extents.
;; Moves in a particular direction:
;;
;; Values are based on the bottom 3 bits [2:0] of O_FLAGS
;; Flag   U      V      Z
;; 000	+3 -3  +3 -3  0  -6
;; 001	+4 -4  +4 -4  0  -6
;; 010	+4 -4  +1 -1  0  -6		DE = high,low U
;; 011	+1 -1  +4 -4  0  -6		HL = high,low V
;; 100	+4  0  +4  0  0 -18		BC = high,low Z (note: the smaller the higher)
;; 101	 0 -4  +4  0  0 -18
;; 110	+4  0   0 -4  0 -18		It returns flags in A.
;; 111	 0 -4   0 -4  0 -18
GetUVZExtents_Near2Far
	INC HL
	INC HL
GetUVZExtents_Far2Near
	INC HL
	INC HL
	LD A,(HL)
	INC HL
	LD C,A
	EX AF,AF'
	LD A,C
	BIT 2,A
	JR NZ,GUVZE_1xx
	BIT 1,A
	JR NZ,GUVZE_01x
	AND &01
	ADD A,3
	LD B,A
	ADD A,A
	LD C,A
	LD A,(HL)
	ADD A,B
	LD D,A
	SUB C
	LD E,A
	INC HL
	LD A,(HL)
	INC HL
	ADD A,B
	LD B,(HL)
	LD H,A
	SUB C
	LD L,A
GUVZE_z_zm6
	LD A,B
	SUB 6
	LD C,A
	EX AF,AF'
	RET

GUVZE_01x
	RRA
	JR c,GUVZE_011
	LD A,(HL)
	ADD A,4
	LD D,A
	SUB 8
	LD E,A
	INC HL
	LD A,(HL)
	INC HL
	LD B,(HL)
	LD H,A
	LD L,A
	INC H
	DEC L
	JR GUVZE_z_zm6

GUVZE_011
	LD D,(HL)
	LD E,D
	INC D
	DEC E
	INC HL
	LD A,(HL)
	INC HL
	ADD A,4
	LD B,(HL)
	LD H,A
	SUB 8
	LD L,A
	JR GUVZE_z_zm6

GUVZE_1xx
	LD A,(HL)
	RR C
	JR c,GUVZE_1x1
	LD E,A
	ADD A,4
	LD D,A
	JR GUVZE_1xA

GUVZE_1x1
	LD D,A
	SUB 4
	LD E,A
GUVZE_1xA
	INC HL
	LD A,(HL)
	INC HL
	LD B,(HL)
	RR C
	JR c,GUVZE_11A
	LD L,A
	ADD A,4
	LD H,A
	JR GUVZE_z_zm18

GUVZE_11A
	LD H,A
	SUB 4
	LD L,A
GUVZE_z_zm18
	LD A,B
	SUB &12
	LD C,A
	EX AF,AF'
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Provides a single, long-winded function to depth-order two set of
;; UVZ extents.
;; Two set of UVZ extents (as returned from GetUVZExtents), in main
;; and EXX'd registers.
;;
;; Returns:
;;  Carry set if EXX'd registers represent a further-away object.
;;  A = 0 if there's an overlap in 2 dimensions, &FF otherwise
.DepthCmp:
	LD A,L
	EXX
	CP H
	LD A,L
	EXX
	JR NC,NoUOverlap
	CP H
	JR c,UOverlap
NoUOverlap
	LD A,E
	EXX
	CP D
	LD A,E
	EXX
	JR NC,dpth_1
	CP D
	JR c,VNoUOverlap
dpth_1
	LD A,C
	EXX
	CP B
NoUVOverlap
	LD A,C
	EXX
	JR NC,NoUVZOverlap
	CP B
	JR c,ZNoUVOverlap
NoUVZOverlap
	LD A,L
	ADD A,E
	ADD A,C
	LD L,A
	ADC A,0
	SUB L
	LD H,A
	EXX
	LD A,L
	ADD A,E
	ADD A,C
	EXX
	LD E,A
	ADC A,0
	SUB E
	LD D,A
	SBC HL,DE
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
ZNoUVOverlap
	LD A,L
	ADD A,E
	LD L,A
	EXX
	LD A,L
	ADD A,E
	EXX
	CP L
	CCF
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
.UOverlap:
	LD A,E
	EXX
	CP D
	LD A,E
	EXX
	JR NC,UNoVOverlap
	CP D
	JR c,UVOverlap
UNoVOverlap
	LD A,C
	EXX
	CP B
	LD A,C
	EXX
	JR NC,UNoVZOverlap
	CP B
	JR c,UZNoVOverlap
UNoVZOverlap
	EXX
	ADD A,E
	EXX
	LD L,A
	ADC A,0
	SUB L
	LD H,A
	LD A,C
	ADD A,E
	LD E,A
	ADC A,0
	SUB E
	LD D,A
	SBC HL,DE
	CCF
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
UZNoVOverlap
	LD A,E
	EXX
	CP E
	EXX
	LD A,0
	RET

;; -----------------------------------------------------------------------------------------------------------
.UVOverlap:
	LD A,C
	EXX
	CP C
	EXX
	LD A,0
	RET

;; -----------------------------------------------------------------------------------------------------------
.VNoUOverlap:
	LD A,C
	EXX
	CP B
	LD A,C
	EXX
	JR NC,VNoUZOverlap
	CP B
	JR c,VZNoUOverlap
VNoUZOverlap
	EXX
	ADD A,L
	EXX
	LD E,A
	ADC A,0
	SUB E
	LD D,A
	LD A,C
	ADD A,L
	LD L,A
	ADC A,0
	SUB L
	LD H,A
	SBC HL,DE
	LD A,&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
VZNoUOverlap
	LD A,L
	EXX
	CP L
	EXX
	LD A,0
	RET

;; -----------------------------------------------------------------------------------------------------------
Walls_PanelBase
	DEFW 	NULL_PTR
Walls_PanelFlipsPtr
	DEFW 	NULL_PTR
Walls_ScreenMaxV
	DEFB 	&00
Walls_ScreenMaxU
	DEFB 	&00
Walls_CornerX
	DEFB 	&00
Walls_DoorZ
	DEFB 	&00

;; -----------------------------------------------------------------------------------------------------------
;; Set the various variables used to work out the edges of the walls.
.StoreCorner:
	CALL GetCorner
	LD A,C
	SUB 6
	LD C,A
	ADD A,B
	RRA
	LD (Walls_ScreenMaxV),A
	LD A,B
	NEG
	ADD A,C
	RRA
	LD (Walls_ScreenMaxU),A
	LD A,B
	LD (Walls_CornerX),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Configure the walls.
;; Height of highest door in A.
DoConfigWalls
.ConfigWalls:
	LD (Walls_DoorZ),A
	CALL VWall
	LD A,(Has_no_wall)
	AND &04
	RET NZ
	LD B,4
	EXX
	LD A,&80
	LD (smc_OWFlag+1),A
	CALL GetCorner
	LD DE,2
	LD A,(IY-1)
	SUB (IY-3)
	JR OneWall

;; -----------------------------------------------------------------------------------------------------------
;; Draw wall parallel to U axis.
.VWall:
	LD A,(Has_no_wall)
	AND &08
	RET NZ
	LD B,&08
	EXX
	XOR A
	LD (smc_OWFlag+1),A
	CALL GetCorner
	DEC L
	DEC L
	LD DE,&FFFE
	LD A,(IY-2)
	SUB (IY-4)
;; Room extent in A, movement step in DE, BackgrdBuff pointer in HL,
;; X/Y in B/C. The flag for this wall in B'
.OneWall:
	RRA
	RRA
	RRA
	RRA
	AND &0F
	PUSH HL
	POP IX
	EXX
	LD C,A
	LD A,(Has_Door)
	AND B
	CP &01
	EX AF,AF'
	LD A,(WorldId)
	LD B,A
PanelFlips_after_move	EQU		PanelFlips + MOVE_OFFSET
	ADD A,PanelFlips_after_move and WORD_LOW_BYTE ;; 56D8
	LD L,A
	ADC A,PanelFlips_after_move / WORD_HIGH_BYTE ;; 56D8
	SUB L
	LD H,A
	LD (Walls_PanelFlipsPtr),HL
	LD A,B
	ADD A,A
	LD B,A
	ADD A,A
	ADD A,A
Panel_WorldData_m1		EQU		Panel_WorldData - 1							;; = &3173; minus 1 so that the FetchData2b (using DataPtr and dummy CurrData) will start at Panel_WorldData
	ADD A,Panel_WorldData_m1 and WORD_LOW_BYTE ;; 3172
	LD L,A
	ADC A,Panel_WorldData_m1 / WORD_HIGH_BYTE ;; 3172
	SUB L
	LD H,A
	LD (DataPtr),HL
	LD A,&80
	LD (CurrData),A
	LD A,PanelsBaseAddr and WORD_LOW_BYTE ;; 3163
	ADD A,B
	LD L,A
	ADC A,PanelsBaseAddr / WORD_HIGH_BYTE ;; 3163
	SUB L
	LD H,A
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	LD (Walls_PanelBase),HL
	LD A,&FF
	EX AF,AF'
	LD A,C
	PUSH AF
	SUB 4
	LD B,1
	JR Z,owctd_1
	LD B,&0F
	INC A
	JR Z,owctd_1
	LD B,&19
	INC A
	JR Z,owctd_1
	LD B,&1F
owctd_1
	POP AF
	JR c,owctd_2
	LD A,C
	ADD A,A
	ADD A,B
	LD B,A
	LD A,C
	EX AF,AF'
owctd_2
	CALL FetchData2b
	DJNZ owctd_2
	LD B,C
	SLA B
.OWPanel:
	EX AF,AF'
	DEC A
	JR Z,OWDoor
	EX AF,AF'
.smc_OWFlag:
	OR &00
	LD (IX+1),A
	EXX
	LD A,C
	ADD A,&08
	LD (IX+0),C
	LD C,A
	ADD IX,DE
	EXX
	CALL FetchData2b
.OWPanelLoop:
	DJNZ OWPanel
	EXX
	PUSH IX
	POP HL
	LD A,L
	CP &40
	RET NC
	LD A,(IX+0)
	AND A
	RET NZ
	LD A,(smc_OWFlag+1)
	OR &05
	LD (IX+1),A
	LD A,C
	SUB &10
	LD (IX+0),A
	RET

.OWDoor:
	EXX
	LD A,(Walls_DoorZ)
	AND A
	LD A,C
	JR Z,br_3D4C
	ADD A,&10
	LD C,A
br_3D4C
	SUB &10
	LD (IX+0),A
	LD A,(smc_OWFlag+1)
	OR &04
	LD (IX+1),A
	ADD IX,DE
	LD (IX+1),A
	LD A,C
	SUB 8
	LD (IX+0),A
	ADD A,&18
	LD C,A
	LD A,(Walls_DoorZ)
	AND A
	JR Z,br_3D71
	LD A,C
	SUB &10
	LD C,A
br_3D71
	ADD IX,DE
	LD A,&FF
	EX AF,AF'
	EXX
	DEC B
	JR OWPanelLoop

;; -----------------------------------------------------------------------------------------------------------
;; Fetch 2 bits from data in CurrData, returned in A
;; CurrData and DataPtr updated as needed
.FetchData2b:
	PUSH BC
	LD B,2
	CALL FetchData
	POP BC
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Gets values associated with the far back corner of the screen.
;; IY must point just after Max_min_UV_Table. (IY=Max_min_UV_Table+4)
;; Returns X in B, Y in C, BackgrdBuff pointer in HL
.GetCorner:
	LD A,(IY-2)
	LD D,A
	LD E,(IY-1)
	SUB E
	ADD A,&80
	LD B,A
	RRA
	RRA
	AND &3E
	LD L,A
	LD H,BackgrdBuff / WORD_HIGH_BYTE ;; &5000
	LD A,&07
	SUB E
	SUB D
	LD C,A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This table returns a pointer on the base wall panel for the current
;; world. From that base value, the Panel_WorldData will add an offset
;; to pick the wall panel we want for each part of the wall.
.PanelsBaseAddr:															;; panel images base addr
	DEFW		img_wall_0 + MOVE_OFFSET ;; 56F0
	DEFW		img_wall_4 + MOVE_OFFSET ;; 5A70
	DEFW		img_wall_8 + MOVE_OFFSET ;; 5DF0
	DEFW		img_wall_11 + MOVE_OFFSET ;; 6090
	DEFW		img_wall_14 + MOVE_OFFSET ;; 6330
	DEFW		img_wall_17 + MOVE_OFFSET ;; 65D0
	DEFW		img_wall_20 + MOVE_OFFSET ;; 6870
	DEFW		img_wall_22 + MOVE_OFFSET ;; 6A30

;; -----------------------------------------------------------------------------------------------------------
;; Used when Wall building.
;; These data consists of packed 2-bit values to choose the panel sprite
;; to pick for each part of the wall. It is essentially an index to add
;; to PanelsBaseAddr
.Panel_WorldData:
	DEFB	&EB, &EB, &F5, &FD, &07, &D7, &EB, &F0		;; 3,2,1,3,....
	DEFB	&E4, &E4, &E3, &4E, &34, &CC, &E4, &CC
	DEFB	&06, &18, &10, &82, &04, &10, &00, &01
	DEFB	&08, &20, &10, &42, &08, &00, &14, &00
	DEFB	&08, &20, &05, &02, &08, &14, &00, &50
	DEFB	&41, &41, &10, &41, &04, &41, &14, &0A
	DEFB	&40, &01, &55, &54, &01, &55, &41, &54
	DEFB	&00, &00, &00, &05, &55, &55, &00, &05

;; -----------------------------------------------------------------------------------------------------------
;; Bit mask of worlds saved (5 bits : "1" means got crown for corresponding world).
;; This will be used to count how many worlds have been saved:
;; bit4 to 0 are : Blacktooth, BookWorld, Safari, Penitentiary, Egyptus
;;.saved_World_Mask:
parts_got_Mask:
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; Byte 0 : room ID lowbyte
;; Byte 1 : room ID highbyte
;; Byte 2 : U
;; Byte 3 : V
;; Byte 4 : Z
;; Byte 5 : Sprite (bit7 = flipped)
;; Byte 6 : function index
Special_obj_List ;; total of 41 (&29)
NB_TOOLS				EQU		4
NB_PARTS				EQU		7
NB_BONUSES				EQU		30
NB_SPECIAL_OBJ			EQU		NB_TOOLS + NB_PARTS + NB_BONUSES ;; 41
LEN_ENTRY_SPECIAL_OBJ	EQU		7

InventoryList: ;; 4
	;;						roomID l h,  U    V    Z    SPR          func
	DEFB &40, &49, &02, &07, &05, SPR_BATTHRUSTER, &00    		;; SPR_BATTHRUSTER
	DEFB &30, &54, &00, &03, &02, SPR_BATBELT, &01				;; SPR_BATBELT
	DEFB &40, &A7, &07, &02, &06, SPR_BATBOOTS, &02			;; SPR_BATBOOTS
	DEFB &40, &A9, &06, &04, &07, SPR_BATBAG, &03				;; SPR_BATBAG
PartsList: ;; 7
	DEFB &50, &6D, &00, &06, &04, SPR_BATCRAFT_RFNT, &0A		;; SPR_BATCRAFT_RFNT
	DEFB &20, &A4, &04, &00, &07, SPR_BATCRAFT_LBCK, &0B		;; SPR_BATCRAFT_LBCK
	DEFB &30, &5D, &04, &03, &07, SPR_BATCRAFT_RBLF or SPR_FLIP, &0C		;; SPR_BATCRAFT_RBLF or SPR_FLIP
	DEFB &30, &81, &07, &02, &07, SPR_BATCRAFT_RBLF, &0D		;; SPR_BATCRAFT_RBLF
	DEFB &80, &57, &01, &07, &02, SPR_BATCRAFT_FINS, &0E		;; SPR_BATCRAFT_FINS
	DEFB &30, &89, &01, &07, &07, SPR_BATCRAFT_FINS, &0F		;; SPR_BATCRAFT_FINS
	DEFB &30, &12, &00, &07, &05, SPR_BATCRAFT_CKPIT, &10		;; SPR_BATCRAFT_CKPIT
SpecialList: ;; 30
	DEFB &40, &68, &03, &04, &00, SPR_BONUS, &05				;; SPR_BONUS : CNT_SPEED
	DEFB &30, &73, &02, &04, &06, SPR_BONUS, &05
	DEFB &30, &41, &00, &03, &00, SPR_BONUS, &05
	DEFB &60, &5D, &04, &04, &07, SPR_BONUS, &05
	DEFB &30, &4A, &00, &03, &00, SPR_BONUS, &05				;; ...
	DEFB &30, &1F, &03, &02, &06, SPR_BONUS, &05
	DEFB &30, &4D, &06, &03, &06, SPR_BONUS, &05
	DEFB &30, &33, &03, &06, &07, SPR_BONUS, &05
	DEFB &40, &46, &03, &01, &00, SPR_BONUS, &05  				;; SPR_BONUS : CNT_SPEED
	DEFB &30, &74, &04, &03, &06, SPR_BONUS, &08 				;; SPR_BONUS : CNT_LIVES
	DEFB &30, &8B, &01, &00, &07, SPR_BONUS, &08
	DEFB &80, &7A, &04, &03, &06, SPR_BONUS, &08				;; ...
	DEFB &40, &88, &03, &01, &00, SPR_BONUS, &08 				;; SPR_BONUS : CNT_LIVES
	DEFB &30, &51, &05, &05, &03, SPR_BONUS, &06 				;; SPR_BONUS : CNT_SPRING
	DEFB &30, &8B, &04, &06, &05, SPR_BONUS, &06
	DEFB &20, &A4, &06, &07, &07, SPR_BONUS, &06				;; ...
	DEFB &80, &6A, &00, &03, &07, SPR_BONUS, &06				;; This one may be changed (randomly) to a Malus
	DEFB &30, &56, &04, &04, &00, SPR_BONUS, &06 				;; SPR_BONUS : CNT_SPRING
	DEFB &40, &59, &01, &06, &06, SPR_BONUS, &07 				;; SPR_BONUS : CNT_SHIELD
	DEFB &30, &2F, &00, &01, &01, SPR_BONUS, &07
	DEFB &30, &B3, &06, &01, &06, SPR_BONUS, &07				;; ...
	DEFB &50, &5C, &00, &03, &06, SPR_BONUS, &07 				;; SPR_BONUS : CNT_SHIELD
	DEFB &30, &75, &03, &02, &07, SPR_BONUS, &09 				;; SPR_BONUS : Reset boost
	DEFB &80, &8A, &07, &04, &07, SPR_BONUS, &09				;; ... This one may be changed (randomly) to a Bonus
	DEFB &30, &35, &02, &00, &07, SPR_BONUS, &09 				;; SPR_BONUS : Reset boost
	DEFB &40, &48, &04, &04, &04, SPR_BATSIGNAL, &04			;; SPR_BATSIGNAL (same thing than FISH in HoH)
	DEFB &30, &33, &03, &03, &04, SPR_BATSIGNAL, &04
	DEFB &40, &A8, &05, &04, &07, SPR_BATSIGNAL, &04			;; ...
	DEFB &60, &7E, &02, &07, &05, SPR_BATSIGNAL, &04
	DEFB &30, &8A, &01, &01, &06, SPR_BATSIGNAL, &04      		;; SPR_BATSIGNAL

;; -----------------------------------------------------------------------------------------------------------
AddSpecialItems
	LD HL,Special_obj_List
	LD DE,LEN_ENTRY_SPECIAL_OBJ - 1
	LD A,NB_SPECIAL_OBJ

addspe_loop
	PUSH AF
	LD A,(HL)
	INC HL
	CP C
	JR NZ,AddCollectedPartsInVictoryRoom
	LD A,(HL)
	CP B
	JR Z,br_3F25

AddCollectedPartsInVictoryRoom
	ADD HL,DE
	POP AF
	DEC A
	JR NZ,addspe_loop
	LD HL,RoomID_Victory
	XOR A
	SBC HL,BC
	RET NZ
	LD (TmpObj_variables+O_FUNC),A
	LD (TmpObj_variables+O_FLAGS),A
	LD A,(parts_got_Mask)
	SCF
	RLA
position_Batcraft_parts:
	LD HL,BatCraftList
pbcp_loop:
	LD DE,TmpObj_variables+O_U
	LD BC,4
	LDIR
	ADD A,A
	RET Z
	PUSH AF
	PUSH HL
	CALL c,AddObjOpt
	POP HL
	POP AF
	JR pbcp_loop

br_3F25
	PUSH HL
	PUSH DE
	PUSH BC
	INC HL
	LD B,(HL)
	INC HL
	LD C,(HL)
	INC HL
	LD E,(HL)
	INC HL
	LD A,(HL)
	LD (TmpObj_variables+O_SPRITE),A
	XOR A
	LD (TmpObj_variables+O_ANIM),A
	LD A,E
	CALL SetTmpObjUVZ
	LD A,&01
	LD (TmpObj_variables+O_FUNC),A
	LD A,&60
	LD (TmpObj_variables+O_FLAGS),A
	CALL AddObjOpt
	POP BC
	POP DE
	POP HL
	JR AddCollectedPartsInVictoryRoom

;; -----------------------------------------------------------------------------------------------------------
;; Batcraft parts in the last room
BatCraftList
	DEFB &14, &22, &B4, SPR_BATCRAFT_CKPIT		;; U V Z Sprite
	DEFB &17, &2E, &B4, SPR_BATCRAFT_FINS
	DEFB &11, &2E, &B4, SPR_BATCRAFT_FINS
	DEFB &11, &2B, &BA, SPR_BATCRAFT_RBLF
	DEFB &17, &25, &BA, SPR_BATCRAFT_RBLF or SPR_FLIP
	DEFB &17, &2B, &BA, SPR_BATCRAFT_LBCK
	DEFB &11, &25, &BA, SPR_BATCRAFT_RFNT

;; -----------------------------------------------------------------------------------------------------------
;; Reset the "collected" flag (bit0 of room ID) on all the specials.
;; When a special item is picked-up, the corresponding RoomID bit0 in
;; tab_Specials_collectible is set, so that a search will no longer
;; match that item.
.ResetSpecials:
	LD HL,Special_obj_List ;; special objects table (tools, parts, special)
	LD DE,LEN_ENTRY_SPECIAL_OBJ ;; length 7 bytes per entry
	LD B,NB_SPECIAL_OBJ ;; number of objects
rstspe_loop
	RES 0,(HL) ;; reset "found" bit
	ADD HL,DE ;; next
	DJNZ rstspe_loop ;; loop

Change_Special_Effect:
	CALL Random_gen		;; get a ramdom value in L
	LD A,&06
	RR L
	JR c,Mutate_items	;; if L[0] = 1 use A=6 (bonus), else use A=9 (malus)
	LD A,&09
	;; flow in Mutate_items
;; -----------------------------------------------------------------------------------------------------------
;; This will swap (or not) 2 specific items depending on a random value
Mutable_Item1_fn		EQU		16*7 + SpecialList + 6	;; 3277 : id 16 in SpecialList, 7 bytes per entry, byte #6 (ie. last one = function)
Mutable_Item2_fn		EQU		23*7 + SpecialList + 6	;; 32A8 : id 23 in SpecialList, 7 bytes per entry, byte #6 (ie. last one = function)

Mutate_items:
	LD (Mutable_Item1_fn),A		;; Will keep 6 (Spring Bonus) or change to 9 (Malus) depending on random value
	XOR &0F						;; 6 <--> 9
	LD (Mutable_Item2_fn),A		;; Will keep 9 (Malus) or change to 6 (Spring Bonus) depending on random value
	RET

;; -----------------------------------------------------------------------------------------------------------
Find_Specials
	EX AF,AF'
	LD HL,Special_obj_List
	LD DE,6
	LD A,NB_SPECIAL_OBJ ;; number of objects

findspec_loop
	PUSH AF
	LD A,(HL)
	INC HL
	CP C
	JR NZ,FindSpecCont
	LD A,(HL)
	CP B
	JR Z,&3390

FindSpecCont
	ADD HL,DE
	POP AF
	DEC A
	JR NZ,findspec_loop
	RET

	PUSH HL
	EX AF,AF'
	INC HL
	INC HL
	INC HL
	INC HL
	CP (HL)
	JR Z,&339D
	POP HL
	EX AF,AF'
	JR FindSpecCont

	INC HL
	LD A,(HL)
	BIT 0,C
	JP NZ,dconti_1
	POP HL
	DEC HL
	SET 0,(HL)						;; set bit0 to says "already picked up"
	POP HL
	SUB 4							;; test if 7th byte (special function) is >= 4
	JR NC,pu_skip					;; yes: jump 33B8
PickedUp_Tool:
	ADD A,5							;; else picked up a tools; beacuse of the "sub 4" above and because wa want bitN for the (N+1)th item; need to add 5 here
	LD HL,Inventory
	CALL Set_bit_nb_A_in_content_HL ;; bit0:SPR_BATTHRUSTER, 1:SPR_BATBELT, 2:SPR_BATBOOTS, bit3:SPR_BATBAG
	JP Draw_Screen_Periphery
pu_skip
	SUB 1							;; align special fn "4, 5, ..." to "FF, 0, ..."
	JR c,Picked_BatSignal			;; if was a BATSIGNAL (save game), jump 33E6
	CP &04							;; if special fn was 9
	JR Z,PickedUp_Malus				;; then special fn "reset boost" , jump 33D9
	JP NC,PickedUp_Part				;; if was >= &0A (batcraft parts) jump 346E
PickedUp_Bonus
	CALL Get_Count_pointer			;; else was a Bonus (5 (0):speed, 6 (1):spring, 7 (2):shield, 8 (3):lives)
	CALL Boost_HLcontent_base10_clamp99
	PUSH AF
	CALL Incr_Bonus_collected		;; TOVERIFY
	POP AF
Show_Num
	PUSH AF
	LD A,C
	ADD A,Print_Sgl_Pos
	CALL Print_String
	POP AF
	JP subprint_2Digits

;; -----------------------------------------------------------------------------------------------------------
;; some of the SPR_BONUS actually are bad, as they make you forget every boost you currently have.
;; So this is it: when we get a "reset" bonus, aka Malus, clears all active bonuses
PickedUp_Malus
	XOR A
	LD (Counter_shield),A
	LD (Counter_speed),A
	LD (Counter_spring),A
	JP PrintStatus

;; -----------------------------------------------------------------------------------------------------------
Picked_BatSignal:		;; save game (C, B, CNT_LIVES, parts_got_Mask)
	CALL GetContinueData ;; get save game pointer
	LD (HL),C
	RRD
	LD A,(Inventory)
	RLD
	INC HL
	LD (HL),B
	LD A,(Counter_lives)
	INC HL
	LD (HL),A
	LD A,(parts_got_Mask)
	INC HL
	LD (HL),A
	LD HL,Save_point_value
	INC (HL)
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
.DoContinue:
	LD HL,Save_point_value
	DEC (HL)
	CALL GetContinueData
	LD A,(HL)
	AND &0F
	LD (Inventory),A
	LD A,(HL)
	AND &F0
	LD C,A
	INC HL
	LD B,(HL)
	LD (current_Room_ID),BC
	INC HL
	LD A,(HL)
	LD (Counter_lives),A
	INC HL
	LD A,(HL)
	LD (parts_got_Mask),A
	SET 0,C
	LD A,SPR_BATSIGNAL
	JP Find_Specials

dconti_1
	DEC HL
	DEC HL
	LD A,(HL)
	DEC HL
	LD C,(HL)
	DEC HL
	LD B,(HL)
	LD DE,UVZ_coord_Set_UVZ
	EX AF,AF'
	LD HL,UVZ_origin
	CALL Set_UVZ
	LD A,5									;; room access code
	LD (access_new_room_code),A
	POP HL
	POP HL
	;; realign what inventory and parts we have got
	LD HL,Special_obj_List
	CALL Update_Inventory_from_save
	LD B,NB_PARTS							;; 7 Batcraft parts
	LD A,(parts_got_Mask)					;; parts
	JR Update_from_save_state

Update_Inventory_from_save
	LD B,NB_TOOLS							;; 4 Inventory items
	LD A,(Inventory)
	LD DE,LEN_ENTRY_SPECIAL_OBJ				;; 7 bytes per entry in the InventoryTable table
Update_from_save_state:
savedgotit_loop:
	RR (HL)				;; This loop replaces the bit 0 of (HL) n°i (i 0 to 3) [= low byte of room ID in the crown search table]....
	RRA					;; ...with the bit n°i in A (saved world (complement))...
	RL (HL)				;; ...to indicate if we saved the corresponding world (currbit=0, will match during search in InventoryTable table)
	ADD HL,DE			;; ...or if we did not save it (currbit=1 will no longer match during search)
	DJNZ savedgotit_loop			;; loop
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Output : HL points on the Continue_Data data for the Save point in Save_point_value
GetContinueData
	LD A,(Save_point_value)	;; save point index
	ADD A,A
	ADD A,A					;; * 4
	ADD A,Save_Data and WORD_LOW_BYTE
	LD L,A
	ADC A,Save_Data / WORD_HIGH_BYTE 				;; 34D5
	SUB L
	LD H,A					;; HL = 34D5 + 4*index
	RET

;; -----------------------------------------------------------------------------------------------------------
PickedUp_Part
	SUB 4
	LD HL,parts_got_Mask
	CALL Set_bit_nb_A_in_content_HL
	JP Refresh_HUD

;; -----------------------------------------------------------------------------------------------------------
;; This function will set a bit (bit number in A) in a byte pointed by HL, leaving the
;; other bits in (HL) untouched.
;; Input: A: the bit number to set
;;        HL: the pointer on the data byte where to set the bit.
.Set_bit_nb_A_in_content_HL:
	LD B,A
	LD A,&80
fsbn_loop
	RLCA
	DJNZ fsbn_loop
	OR (HL)
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
Counters_increments
	DEFB &99 ;; (BCD) ; Bonus value , 1BD0 : Counters CNT_SPEED
	DEFW Counter_speed
	DEFB &01
	DEFW Counter_lives ;; 1BD3 CNT_LIVES
	DEFB &10
	DEFW Counter_spring ;; 1BD1 CNT_SPRING
	DEFB &99
	DEFW Counter_shield ;; 1BD2 CNT_SHIELD

;; -----------------------------------------------------------------------------------------------------------
;; Decrement one of the counters and print new value
;; Input : A can be: 0: speed, 1: spring, 2:Heels Invul, 3: Head Invul, 4:Heels Lives, 5:Head Lives, 6:Donuts
;; Output : Zero flag set if was 0; Zero flag reset is was able to decrement the counter.
Decrement_counter_and_display
	CALL Get_Count_pointer
	CALL Sub_1_HLcontent_base10_clamp0
	RET Z
	LD A,(HL)
	CALL Show_Num
	OR &FF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Re-prints all the Counters values on the HUD.
.PrintStatus:
	LD A,Print_HUD_Left
	CALL Print_String
	LD A,NB_COUNTERS
prntstat_1
	PUSH AF
	DEC A
	CALL Get_Count_pointer
	LD A,(HL)
	CALL Show_Num
	POP AF
	DEC A
	JR NZ,prntstat_1
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Increment the Counter pointer by HL with the increment value in A.
;; Output: Carry reset: counter incremented;
;;         Carry set: counter incremented and clamped at 99
.Boost_HLcontent_base10_clamp99:
	ADD A,(HL)
	DAA
	LD (HL),A
	RET NC
	LD A,&99
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Input: HL = pointer on the counter we want to decrement (by 1)
;; Output: A=0/Zset : was already 0 (clapmed at 0);
;;         A=-1/Zreset : value in (HL) decremented by 1
.Sub_1_HLcontent_base10_clamp0:
	LD A,(HL)
	AND A
	RET Z
	SUB 1
	DAA
	LD (HL),A
	OR &FF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Given a count index in A, return the corresponding counter increment
;; and Counters address in HL.
;; Input: A can be 0: speed, 1: spring, 2:Heels Invul, 3: Head Invul, 4:Heels Lives, 5:Head Lives, 6:Donuts
;; If access_new_room_code is non-zero, return 3 as the increment. (dec invulnr counters by 3 if changing room ???)
;; Output: HL selected Counter pointer
.Get_Count_pointer:
	LD C,A		;; i
	ADD A,A		;; i*2
	ADD A,C		;; i*3
	ADD A,Counters_increments and WORD_LOW_BYTE
	LD L,A
	ADC A,Counters_increments / WORD_HIGH_BYTE	;; 3482
	SUB L
	LD H,A		;; &3482 + 3*index
	LD A,(HL)	;; first item in A = value
	INC HL
	LD B,(HL)
	INC HL
	LD H,(HL)	;; H=3rd
	LD L,B		;; L=2nd : HL = counter pointer
	RET

;; -----------------------------------------------------------------------------------------------------------
Save_point_value
	DEFB 0 ;; there are 5 batsignals

Save_Data
	DEFS 4,0
	DEFS 4,0
	DEFS 4,0
	DEFS 4,0
	DEFS 4,0

;; -----------------------------------------------------------------------------------------------------------
UVZ_origin
	DEFS 3,0

UVZ_coord_Set_UVZ
	DEFS 3,0

;; -----------------------------------------------------------------------------------------------------------
reset_count_val
	DEFB 2 ;; length
nbtimes_died_resetval
	DEFB 0
nbcollected_bonus_resetval
	DEFB 0

nbtimes_died
	DEFB 0
nbcollected_bonus
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
NB_ROOMS				EQU		&A0 ;;	151 defined but 160 forseen

RoomMask_buffer
	DEFS 	NB_ROOMS, &00

;; -----------------------------------------------------------------------------------------------------------
RecoreredParts
	LD DE,&0000		;; init to 0
	JR gotParts
CountInventory
	LD HL,Inventory
	LD B,1 ;; 1 byte in which to check all bits set
	CALL countBits
gotParts: ;; SavedWorldCount
	LD HL,parts_got_Mask
	LD B,1 ;; 1 byte in which to check all bits set
	JR cbi1

RoomCount
	LD HL,RoomMask_buffer
	LD B,NB_ROOMS
countBits
	LD DE,0
cbi1
	LD C,(HL)
	SCF
	RL C
cbi2
	LD A,E
	ADC A,0
	DAA
	LD E,A
	LD A,D
	ADC A,0
	DAA
	LD D,A
	SLA C
	JR NZ,cbi2
	INC HL
	DJNZ cbi1
	RET

;; -----------------------------------------------------------------------------------------------------------
.Erase_visited_room:
	LD HL,RoomMask_buffer
	LD BC,NB_ROOMS
	JP Erase_forward_Block_RAM

;; -----------------------------------------------------------------------------------------------------------
Incr_Bonus_collected
	LD HL,nbcollected_bonus
	JR Incr_DAA_value

;; -----------------------------------------------------------------------------------------------------------
Incr_died_number
	LD HL,nbtimes_died
Incr_DAA_value
	LD A,(HL)
	ADD A,1
	DAA
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Calculate the score in HL (BCD).
.GetScore: ;; ???
	CALL RoomCount
	LD A,(win_state)
	AND A
	LD HL,&0000
	JR Z,gs_1
	LD HL,&0900
gs_1
	LD BC,&0010
	CALL MulAccBCD
	PUSH HL
	CALL CountInventory
	POP HL
	LD BC,&0190
	CALL MulAccBCD
	LD DE,(nbcollected_bonus)
	LD D,0
	LD BC,&0064
	JR MulAccBCD

;; The function MulAccBCD adds to HL (BCD), the product
;; of DE (BCD) and BC (not in BCD) :  HL = HL + (DE * BC)
.MulAccBCD:																	;; HL and DE are in BCD. BC is not.
	LD A,E
	ADD A,L
	DAA
	LD L,A
	LD A,H
	ADC A,D
	DAA
	LD H,A
	DEC BC
	LD A,B
	OR C
	JR NZ,MulAccBCD
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Get the direction code from a LRDU user input in A (and ignore conflicting inputs).
;; In other words: LRDU -> Dir code (0 to 7 and FF)
;; Input: a 4-bit bitmask Left,Right,Down,Up (active low)
;; North is the far corner on the game screen, South the near corner
;; 		Let's take "A"=active (0), "I"=inactive (1)
;;  	(note: we must ignore conflicting inputs (eg. L+R = no move))              (Back)
;;		LRDU : return_code					LRDU : return_code			  (Back)	 Up    East (?)
;;		AAAA : FF	(no move)				IAAA : 02	(Right)				North __________> U
;;  	AAAI : 00	(Down)					IAAI : 01	(Down and Right)		 |05 04 03
;;		AAIA : 04	(Up)					IAIA : 03	(Up and Right)		Left |06 FF 02 Right (Front)
;;  	AAII : FF 	(no move)				IAII : 02	(Right)			  (Back) |07 00 01
;;		AIAA : 06	(Left)					IIAA : FF 	(no move)				 |  Down   South
;;  	AIAI : 07	(Down and Left)			IIAI : 00	(Down)          West     Y  (Front)  (Front)
;;		AIIA : 05	(Up and Left)			IIIA : 04	(Up)			(?)	    V
;;  	AIII : 06 	(Left)					IIII : FF 	(no move)
;; Output in A: the validated direction as described above
.DirCode_from_LRDU:
	AND &0F
	ADD A,Array_direction_table and WORD_LOW_BYTE
	LD L,A
	ADC A,Array_direction_table / WORD_HIGH_BYTE ;; 3621
	SUB L
	LD H,A
	LD A,(HL)
	RET

Array_direction_table
	DEFB 	&FF, &00, &04, &FF, &06, &07, &05, &06
	DEFB 	&02, &01, &03, &02, &FF, &00, &04, &FF

;; -----------------------------------------------------------------------------------------------------------
;; A has a direction, returns Y delta in C, X delta in B, and
;; third entry goes in A and is the DirTable inverse mapping.
.DirDeltas:
	LD L,A
	ADD A,A
	ADD A,L
	ADD A,DirTable2 and WORD_LOW_BYTE
	LD L,A
	ADC A,DirTable2 / WORD_HIGH_BYTE ;; 3641
	SUB L
	LD H,A
	LD C,(HL)
	INC HL
	LD B,(HL)
	INC HL
	LD A,(HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; First byte is Y delta, second X, third is reverse lookup
;; (Only DirTable[3:0] give direction; DirTable inverse mapping?)
.DirTable2:
	DEFB 	-1,  0, &0D          	;; Ydelta, Xdelta, DirTable FD ; 0:down
	DEFB 	-1, -1, &09          	;; Ydelta, Xdelta, DirTable F9 ; 1:south
	DEFB 	 0, -1, &0B          	;; Ydelta, Xdelta, DirTable FB ; 2:right
	DEFB 	 1, -1, &0A       		;; Ydelta, Xdelta, DirTable FA ; 3:east
	DEFB 	 1,  0, &0E       		;; Ydelta, Xdelta, DirTable FE ; 4:up
	DEFB 	 1,  1, &06       		;; Ydelta, Xdelta, DirTable F6 ; 5:north
	DEFB 	 0,  1, &07       		;; Ydelta, Xdelta, DirTable F7 ; 6:left
	DEFB 	-1,  1, &05				;; Ydelta, Xdelta, DirTable F5 ; 7:west

;; -----------------------------------------------------------------------------------------------------------
.UpdatePos:
	PUSH HL
	CALL DirDeltas
	LD DE,O_IMPACT
	POP HL
	ADD HL,DE
	XOR (HL)
	AND &0F
	XOR (HL)
	LD (HL),A
	LD DE,&FFFA
	ADD HL,DE
	LD A,(HL)
	ADD A,C
	LD (HL),A
	INC HL
	LD A,(HL)
	ADD A,B
	LD (HL),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; HL is a pointer to an index, incremented into a byte-array
;; that follows it. Next item is returned in A. Array is 0-terminated
;; at which point we read the first item again.
.Read_Loop_byte:
	INC (HL)
	LD A,(HL)
	ADD A,L
	LD E,A
	ADC A,H
	SUB E
	LD D,A
	LD A,(DE)
	AND A
	RET NZ
	LD (HL),&01
	INC HL
	LD A,(HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Word version of ReadLoop.
ReadLoopW:
unused_Read_Loop_word:														;; same than Read_Loop_byte, but for word (NOT USED!)
	LD A,(HL)
	INC (HL)
	ADD A,A
	ADD A,L
	LD E,A
	ADC A,H
	SUB E
	LD D,A
	INC DE
	LD A,(DE)
	AND A
	JR Z,Read_Loop_word_sub1
	EX DE,HL
	LD E,A
	INC HL
	LD D,(HL)
	RET
Read_Loop_word_sub1
	LD (HL),&01
	INC HL
	LD E,(HL)
	INC HL
	LD D,(HL)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Pseudo random generator
;; value in HL
.Random_gen:
	LD HL,(Rand_seed_2)
	LD D,L
	ADD HL,HL
	ADC HL,HL
	LD C,H
	LD HL,(Rand_seed_1)
	LD B,H
	RL B
	LD E,H
	RL E
	RL D
	ADD HL,BC
	LD (Rand_seed_1),HL
	LD HL,(Rand_seed_2)
	ADC HL,DE
	RES 7,H
	LD (Rand_seed_2),HL
	JP M,rg_2
	LD HL,Rand_seed_1
rg_1
	INC (HL)
	INC HL
	JR Z,rg_1
rg_2
	LD HL,(Rand_seed_1)
	RET

Rand_seed_1
	DEFW 	&6F4A
Rand_seed_2
	DEFW 	&216E

;; -----------------------------------------------------------------------------------------------------------
;; HL : Pointer to object to remove
.RemoveObject:
	PUSH HL
	PUSH HL
	PUSH IY
	PUSH HL
	POP IY
	CALL Unlink
	POP IY
	POP HL
	CALL DrawObject
	POP IX
	SET 7,(IX+O_FLAGS)
	LD A,(Do_Objects_Phase)
	LD C,(IX+O_FUNC)
	XOR C
	AND &80
	XOR C
	LD (IX+O_FUNC),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; HL : Object pointer
.DrawObject:
	PUSH IY
	INC HL
	INC HL
	CALL GetShortObjExt		;; GetObjExtents
	EX DE,HL
	LD H,B
	LD L,C
	CALL Draw_View
	POP IY
	RET

;; -----------------------------------------------------------------------------------------------------------
.InsertObject:
	PUSH HL
	PUSH HL
	PUSH IY
	PUSH HL
	POP IY
	CALL EnlistAux
	POP IY
	POP HL
	CALL DrawObject
	POP IX
	RES 7,(IX+O_FLAGS)
	LD (IX+O_IMPACT),&FF
	LD (IX+&0C),&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
Refresh_HUD
	CALL WaitKey
	CALL DrawBlacked
	CALL Draw_carried_objects
	JP Update_Screen_Periph

;; -----------------------------------------------------------------------------------------------------------
;; Wait a key press to leave the screen shown (crown/worlds screen)
;; but leave automatically after a while (about 18-20 sec)
MAX_DELAY_IF_NO_KEY		EQU		&1400										;; Show the page for a max 18/20 seconds if no key is pressed

WaitKey
	CALL clr_screen
	LD A,9
	CALL Set_colors
	CALL Play_Batman_Theme
	LD HL,Parts_Sprites_list ;; 3756
	LD DE,(parts_got_Mask)
	LD D,NB_PARTS
	CALL Draw_from_list
Wait_key_pressed
	LD HL,MAX_DELAY_IF_NO_KEY ;; delay
waitkp_loop
	DJNZ waitkp_loop
	PUSH HL
	POP HL
	DEC HL
	LD A,H
	OR L
	JR NZ,waitkp_loop
wait_loop
	CALL HasVoice1DataToPlay
	RET Z
	JR wait_loop

;; -----------------------------------------------------------------------------------------------------------
Parts_Sprites_list
	DEFB 	SPR_BATCRAFT_RFNT,             &78, &B0 ;; BATCRAFT Right Front part, y, x coord
	DEFB 	SPR_BATCRAFT_LBCK,             &78, &90 ;; BATCRAFT Back Left part
	DEFB 	SPR_BATCRAFT_RBLF or SPR_FLIP, &88, &A0 ;; BATCRAFT Left Front part
	DEFB 	SPR_BATCRAFT_RBLF,             &68, &A0 ;; BATCRAFT Back Right part
	DEFB 	SPR_BATCRAFT_FINS,             &58, &80 ;; BATCRAFT Left Fin part
	DEFB 	SPR_BATCRAFT_FINS,             &68, &70 ;; BATCRAFT Right Fin part
	DEFB 	SPR_BATCRAFT_CKPIT,            &98, &B8 ;; BATCRAFT Cockpit part

;; -----------------------------------------------------------------------------------------------------------
;; This draws the game HUD, called the "Periphery".
;; It also provide an entry for drawing Head and Heels (Draw_sprites_from_list).
.Draw_Screen_Periphery:
	LD HL,Inventory_sprite_list
	LD DE,(Inventory)
	LD D,4 ;; 4 sprites
;; -----------------------------------------------------------------------------------------------------------
;; Draw a list of 3x24 sprites.
;; Inputs: D: number of sprites
;; 		   E: bitmask indicating to drawn the nth sprite or to shadow it
;; 		   HL: pointer on Sprites list/array (like Inventory_sprite_list, EmperorPageSpriteList, Planet_Sprites_list, Crown_sprites_list, etc.)
;; The sprites array data should contain for each entry:
;;         a Sprite code (1 byte), the Coordinates (2 bytes)
;; Important Note: if the bitmap is 0, a sprite is still drawn, but without the
;;                 vibrant color, to give a shadowed effect.
.Draw_from_list:
	LD A,(HL)
	INC HL
	LD C,(HL)
	INC HL
	LD B,(HL)
	INC HL
	PUSH HL
	RR E
	PUSH DE
	JR NC,dfl_2
	LD L,1
	INC L
	DEC L
	LD D,3
	JR Z,dfl_3
	CALL Draw_sprite_3x24
dfl_1
	POP DE
	POP HL
	DEC D
	JR NZ,Draw_from_list
	RET

dfl_2
	LD D,1
dfl_3
	CALL Draw_sprite_3x24_and_attribute
	JR dfl_1

;; -----------------------------------------------------------------------------------------------------------
.Inventory_sprite_list:
	DEFB SPR_BATTHRUSTER, 	&B4, &D0 ;; spr y,x coords on HUD
	DEFB SPR_BATBELT, 		&B4, &F0
	DEFB SPR_BATBOOTS, 		&94, &F0
	DEFB SPR_BATBAG, 		&A4, &E0

;; -----------------------------------------------------------------------------------------------------------
;; Draw a 3 byte x 24 row sprite on clear background, complete with
;; attributes in D, via Draw_Sprite.
;; Input: Sprite code in A.
;;        position the sprite in BC - bottomleft corner
;;        Attribute style in D:
;;				1 = "Shadow" mode
;;				3 = "Color" mode (this is the one used if using "Draw_sprite_3x24_attr3")
;; If entering directly at Draw_sprite_3x24_and_attribute, we
;; expect the attribute in D.
.Draw_sprite_3x24_and_attribute:
	LD (Sprite_Code),A
	LD A,B
	SUB 3*24
	LD B,A
	PUSH DE
	PUSH BC
	CALL Load_sprite_image_address_into_DE
	LD HL,&18 * WORD_HIGH_BYTE + &0C
	POP BC
	POP AF
	JP Draw_Sprite

;; -----------------------------------------------------------------------------------------------------------
;; Draw a 3-byte * 24 rows sprite on clear background
;; BC=bottomleft origin (without attribute)
;; A has the sprite code
.Draw_sprite_3x24:
	LD (Sprite_Code),A
	CALL Calculate_Extents_3x24
	CALL Clear_Dest_buffer
	CALL Load_sprite_image_address_into_DE
	LD BC,ViewBuff ;; 4D00
	EXX
	LD B,24
	CALL BlitMask3of3
	JP Blit_screen

;; -----------------------------------------------------------------------------------------------------------
;; Clear a 3x24 area
.Clear_3x24:
	CALL Calculate_Extents_3x24
	CALL Clear_Dest_buffer
	JP Blit_screen

;; -----------------------------------------------------------------------------------------------------------
;; Calculate the X and Y Extent for a 3x24 sprite
;; Input: coordinate (bottom left) : y in B, x in C
;; Output: HL = x, x+12, BC = y, y+24
.Calculate_Extents_3x24:
	LD H,C
	LD A,H
	ADD A,12
	LD L,A
	LD (ViewXExtent),HL
	LD A,B
	ADD A,24
	LD C,A
	LD (ViewYExtent),BC
	RET

;; -----------------------------------------------------------------------------------------------------------
;; how is this used? if it is used? &_NOTUSED_& ???
;; Draw a 3-byte * 32 rows sprite on clear background
;; BC=bottomleft origin (without attribute)
Draw_sprite_3x32:
	LD (Sprite_Code),A
	CALL Calculate_Extents_3x24
	LD A,B
	ADD A,32
	LD (ViewYExtent),A
	CALL Clear_Dest_buffer
	LD A,&02
	LD (SpriteFlags),A
	CALL Load_sprite_image_address_into_DE
	LD BC,ViewBuff ;; 4D00
	EXX
	LD B,32
	CALL BlitMask3of3
	JP Blit_screen

;; -----------------------------------------------------------------------------------------------------------
;; Clear the 6800 buffer
.Clear_Dest_buffer:
	LD HL,DestBuff
	LD BC,BUFFER_LENGTH
	JP Erase_forward_Block_RAM

;; -----------------------------------------------------------------------------------------------------------
Movement_Facing
	DEFB 0
access_new_room_code
	DEFB 0
Dying
	DEFB 0

NR_Direction
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; HL contains an object, A contains a direction
;; TODO: I guess IY holds the character object?
;; If collision: Carry set
MoveCurrent
.Move:
	PUSH AF
	CALL GetUVZExtents_AdjustLowZ
	EXX
	POP AF
	LD (NR_Direction),A
DoMove
	CALL DoMoveAux
	LD A,(NR_Direction)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Takes direction in A, and UV extents in DE', HL'.
;; From the direction code in A, lookup in MoveTbl the Move and Collide functions
;; to call (being pushed on the stack, they are called when encountering a RET)
;; Then the final RET will launch the PostMove function.
.DoMoveAux:
	LD DE,PostMove
	PUSH DE
	LD C,A
	ADD A,A
	ADD A,A
	ADD A,C
	ADD A,MoveTbl and WORD_LOW_BYTE ;; 3923
	LD L,A
	ADC A,MoveTbl / WORD_HIGH_BYTE ;; 3923
	SUB L
	LD H,A
	LD A,(HL)
	LD (Movement_Facing),A
	INC HL
	LD E,(HL)
	INC HL
	LD D,(HL)
	INC HL
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	PUSH DE
	EXX
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Called after the call to the function in DoMoveAux.
;; The second movement function is in HL', the direction in C'.
.PostMove:
	EXX
	RET Z
	PUSH HL
	POP IX
	BIT 2,C
	JR NZ,PM_Alt
	LD HL,ObjList_Regular_Far2Near
PM_ALoop
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,PM_ABreak
	PUSH HL
	CALL DoJumpIX
	POP HL
	JR c,PM_AFound
	JR NZ,PM_ALoop
	JR PM_ABreak

PM_Alt
	LD HL,ObjList_Regular_Near2Far
PM_BLoop
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H
	JR Z,PM_BBreak
	PUSH HL
	CALL DoJumpIX
	POP HL
	JR c,PM_BFound
	JR NZ,PM_BLoop
PM_BBreak
	LD HL,Batman_variables
	JR PM_Break
PM_ABreak
	LD HL,Batman_variables+O_FAR2NEAR_LST
PM_Break
	BIT 0,(IY+O_SPRFLAGS)
	RET NZ
	LD A,(Saved_Objects_List_index)
	AND A
	RET Z
	CALL DoJumpIX
	RET NC
	LD HL,Batman_variables+O_FAR2NEAR_LST
PM_AFound
	DEC HL
	DEC HL
PM_BFound
	PUSH HL
	POP IX
	LD A,(Movement_Facing)
	BIT 1,(IX+O_SPRFLAGS)
	JR Z,PM_Found2
	AND (IX-OBJECT_LENGTH+&0C)
	LD (IX-OBJECT_LENGTH+&0C),A
	JR PM_Found3
PM_Found2
	AND (IX+&0C)
	LD (IX+&0C),A
PM_Found3
	XOR A
	SUB 1
ProcContact
	PUSH AF
	PUSH IX
	PUSH IY
	CALL ContactAux
	POP IY
	POP IX
	POP AF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; IX and IY are both objects, may be characters.
;; Something is in A.
.ContactAux:
	BIT 0,(IY+O_SPRFLAGS)
	JR Z,Contact_Player_Obj
	BIT 5,(IX+O_FLAGS)
	RET Z
	BIT 6,(IX+O_FLAGS)
	JR NZ,CollectSpecial
	AND A
	JR Z,DeadlyContact
	BIT 2,(IX+O_SPRFLAGS)
	RET NZ
	JR DeadlyContact
Contact_Player_Obj
	BIT 0,(IX+O_SPRFLAGS)
	RET Z
	BIT 5,(IY+O_FLAGS)
	RET Z
	BIT 6,(IY+O_FLAGS)
	RET NZ
	AND A
	JR Z,DeadlyContact
	BIT 2,(IY+O_SPRFLAGS)
	RET NZ
DeadlyContact
	LD A,(Counter_shield)
	AND A
	RET NZ
	LD A,(Dying)
	AND A
	RET NZ
	LD A,&0C
	LD (Dying),A
	JP DeadlyContactSong ;; sound dying

;; -----------------------------------------------------------------------------------------------------------
;; Make the special object disappear when picking it up
;; and call the associated function.
.CollectSpecial:
	LD (IX+O_ANIM),&08 ;; ANIM_VAPE1_code
	LD (IX+O_FLAGS),&80
	LD A,(IX+O_FUNC)
	AND &80
	OR OBJFN_FADE
	LD (IX+O_FUNC),A
	LD BC,(current_Room_ID)
	LD A,(IX+O_SPRITE)
	CALL Find_Specials
	JP GetSpecialSong

;; -----------------------------------------------------------------------------------------------------------
;; MoveTbl is indexed on a direction, as per LookupDir.
;; First element is LRDU bit mask for directions.
;; Second is the function to move in that direction.
;; Third element is the function to check collisions.
FACING_DOWN				EQU		&FD				;; bit1 = 0 (active low) in LRDU
FACING_NEAR				EQU		&F9				;; bits 1&2 = 0 (active low) in LRDU
FACING_RIGHT			EQU		&FB				;; bit2 = 0 (active low) in LRDU
FACING_EAST				EQU		&FA				;; bits 0&2 = 0 (active low) in LRDU
FACING_UP				EQU		&FE				;; bit0 = 0 (active low) in LRDU
FACING_FAR				EQU		&F6				;; bits 0&3 = 0 (active low) in LRDU
FACING_LEFT				EQU		&F7				;; bit3 = 0 (active low) in LRDU
FACING_WEST				EQU		&F5				;; bits 1&3 = 0 (active low) in LRDU

MoveTbl:
	DEFB	FACING_DOWN
	DEFW	MoveT_Down, CollideT_Down		;; MoveT_Down 3A6A, CollideT_Down 3A30
	DEFB	&FF
	DEFW	MoveT_DownRight, NULL_PTR		;; MoveT_DownRight 394B
	DEFB	FACING_RIGHT
	DEFW	MoveT_Right, CollideT_Right		;; MoveT_Right 3AC1, CollideT_Right 3A4E
	DEFB	&FF
	DEFW	MoveT_UpRight, NULL_PTR			;; MoveT_UpRight 396C
	DEFB	FACING_UP
	DEFW	MoveT_Up, CollideT_Up			;; MoveT_Up 3B11, CollideT_Up 39D4
	DEFB	&FF
	DEFW 	MoveT_UpLeft, NULL_PTR			;; MoveT_UpLeft 3990
	DEFB	FACING_LEFT
	DEFW	MoveT_Left, CollideT_Left		;; MoveT_Left 3B59, CollideT_Left 3A15
	DEFB	&FF
	DEFW	MoveT_DownLeft, NULL_PTR		;; MoveT_DownLeft 39B3

DOOR_LOW				EQU		&24
DOOR_HIGH				EQU		&2C

;; -----------------------------------------------------------------------------------------------------------
;; The diagonal movement functions rearrange things:
;; * They remove two elements of the stack, removing the call to
;;   PostMove and the return into DoMove (which puts (Direction) into A).
;; * They call DoMove, and check the resultant carry flag. Carry means
;;   failure to move in that direction. They move one direction, then the
;;   other.
;; * If the first move succeeds, the extents are updated to represent the
;;   successful move, before the second check is attempted.
;; * Depending on what works, they generate a movement direction in A,
;;   and success/failure in the carry flag.
MoveT_DownRight
	EXX
	POP HL
	POP DE
	XOR A
	CALL DoMove
	JR c,drght_1
	EXX
	DEC D
	DEC E
	EXX
	LD A,2
	CALL DoMove
	LD A,1
	RET NC
	XOR A
	RET
drght_1
	LD A,2
	CALL DoMove
	RET c
	AND A
	LD A,2
	RET

;; -----------------------------------------------------------------------------------------------------------
MoveT_UpRight
	EXX
	POP HL
	POP DE
	LD A,4
	CALL DoMove
	JR c,urght_1
	EXX
	INC D
	INC E
	EXX
	LD A,2
	CALL DoMove
	LD A,3
	RET NC
	LD A,4
	AND A
	RET
urght_1
	LD A,2
	CALL DoMove
	RET c
	AND A
	LD A,2
	RET

;; -----------------------------------------------------------------------------------------------------------
MoveT_UpLeft
	EXX
	POP HL
	POP DE
	LD A,4
	CALL DoMove
	JR c,ulft_1
	EXX
	INC D
	INC E
	EXX
	LD A,6
	CALL DoMove
	LD A,5
	RET NC
	LD A,4
	AND A
	RET
ulft_1
	LD A,6
	CALL DoMove
	RET c
	LD A,6
	RET

;; -----------------------------------------------------------------------------------------------------------
MoveT_DownLeft
	EXX
	POP HL
	POP DE
	XOR A
	CALL DoMove
	JR c,dlft_1
	EXX
	DEC D
	DEC E
	EXX
	LD A,6
	CALL DoMove
	LD A,7
	RET NC
	XOR A
	RET
dlft_1
	LD A,6
	CALL DoMove
	RET c
	AND A
	LD A,6
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Collide functions. Object in HL, check it against the
;; character whose extents are in DE' and HL'
;;
;; Returned flags are:
;;  Carry = Collided
;;  NZ = No collision, but further collisions are possible.
;;  Z = Stop now, no further collisions possible.
CollideT_Up
	INC HL
	INC HL
	CALL GetSimpleSize
	LD A,(HL)
	SUB C
	EXX
	CP D
	EXX
	JR c,CollideContinue
	JR NZ,ChkBack
	INC HL
ChkVCollide
	LD A,(HL)
	SUB B
	EXX
	CP H
	LD A,L
	EXX
	JR NC,CollideContinue
	SUB B
	CP (HL)
	JR NC,CollideContinue
ChkZCollide
	INC HL
	EXX
	LD A,C
	EXX
	CP (HL)
	JR NC,CollideContinue
	LD A,(HL)
	SUB E
	EXX
	CP B
	EXX
	JR NC,CollideContinue
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
.ChkBack:
	INC HL
	LD A,(HL)
	SUB B
	EXX
	CP H
	EXX
	JR c,CollideContinue
	INC HL
	LD A,(HL)
	SUB E
	EXX
	CP B
	EXX
	JR c,CollideContinue
	XOR A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; No carry = no collision, non-zero = keep searching.
;; return -1, no Z and no Carry
.CollideContinue:
	LD A,&FF
	AND A
	RET

;; -----------------------------------------------------------------------------------------------------------
CollideT_Left
	INC HL
	INC HL
	CALL GetSimpleSize
	LD A,(HL)
	SUB C
	EXX
	CP D
	LD A,E
	EXX
	JR NC,ChkBack
	SUB C
	CP (HL)
	JR NC,CollideContinue
	INC HL
	LD A,(HL)
	SUB B
	EXX
	CP H
	EXX
	JR Z,ChkZCollide
	JR CollideContinue

;; -----------------------------------------------------------------------------------------------------------
CollideT_Down
	CALL GetSimpleSize
	EXX
	LD A,E
	EXX
	SUB C
	CP (HL)
	JR c,CollideContinue
	INC HL
	JR Z,ChkVCollide
ChkFront
	EXX
	LD A,L
	EXX
	SUB B
	CP (HL)
	JR c,CollideContinue
	INC HL
	LD A,(HL)
	ADD A,E
	EXX
	CP B
	EXX
	JR NC,CollideContinue
	XOR A
	RET

;; -----------------------------------------------------------------------------------------------------------
CollideT_Right
	CALL GetSimpleSize
	EXX
	LD A,E
	EXX
	SUB C
	CP (HL)
	INC HL
	JR NC,ChkFront
	DEC HL
	LD A,(HL)
	SUB C
	EXX
	CP D
	LD A,L
	EXX
	JR NC,CollideContinue
	INC HL
	SUB B
	CP (HL)
	JP Z,ChkZCollide
	JR CollideContinue

;; -----------------------------------------------------------------------------------------------------------
;; Up, Down, Left and Right
;;
;; Takes U extent in DE, V extent in HL.
;; U/D work in U direction, L/R work in V direction. ???????Check if this is right?????????TODO
;; IX points on the Max_min_UV_Table. IX-1 is the Has_Door variable, IX-2 is the Has_no_wall variable.
;; Sets NZ and Carry if you can move in a direction.
;; Sets Zero and Carry if you cannot.
;; Leaving room sets direction in NextRoom, sets Carry and Zero.
MoveT_Down
	CALL ChkCantLeave
	JR Z,D_NoExit
	CALL UD_InOtherDoor
	LD A,DOOR_LOW
	JR c,D_NoExit2
	BIT 0,(IX-1)
	JR Z,D_NoDoor
	LD A,(DoorHeights+3)
	CALL DoorHeightCheck
	JR c,D_NoExit
	CALL UD_InFrame
	JR c,D_NearDoor
	LD A,(MinU)
	SUB 4
	JR D_Exit

D_NoDoor
	BIT 0,(IX-2)
	JR Z,D_NoExit
	LD A,(MinU)
D_Exit
	CP E
	RET NZ
	LD A,1
LeaveRoom
	LD (access_new_room_code),A
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; The case where we can't exit the room, but may hit the wall.
D_NoExit
	LD A,(MinU)
D_NoExit2
	CP E
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Handle the near-door case: If we're not near the door frame,
;; we do the normal "not door" case. Otherwise, we do that and
;; then nudge into the door.
.D_NearDoor:
	CALL UD_InFrameW
	JR c,D_NoExit
	CALL D_NoExit
UD_Nudge
	RET NZ
	LD A,L
	CP DOOR_LOW + 1
	LD A,FACING_LEFT
	JR c,Nudge
	LD A,FACING_RIGHT
Nudge
	LD (Movement),A ;; 1BE5
	XOR A
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; IX points on the Max_min_UV_Table. IX-1 is the Has_Door variable, IX-2 is the Has_no_wall variable.
MoveT_Right
	CALL ChkCantLeave
	JR Z,R_NoExit
	CALL LR_InOtherDoor
	LD A,DOOR_LOW
	JR c,R_NoExit2
	BIT 1,(IX-1)
	JR Z,R_NoDoor
	LD A,(DoorHeights+2)
	CALL DoorHeightCheck
	JR c,R_NoExit
	CALL LR_InFrame
	JR c,R_NearDoor
	LD A,(MinV)
	SUB 4
	JR R_Exit

R_NoDoor
	BIT 1,(IX-2)
	JR Z,R_NoExit
	LD A,(MinV)
R_Exit
	CP L
	RET NZ
	LD A,2
	JR LeaveRoom

R_NoExit
	LD A,(MinV)
;; (or some other value given in A).
.R_NoExit2:
	CP L
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; The case where we can't exit the room, but may hit the wall.
.R_NearDoor:
	CALL LR_InFrameW
	JR c,R_NoExit
	CALL R_NoExit
;; Choose a direction to move based on which side of the door
;; we're trying to get through.
.LR_Nudge:
	RET NZ
	LD A,E
	CP DOOR_LOW + 1
	LD A,FACING_UP
	JR c,Nudge
	LD A,FACING_DOWN
	JR Nudge

;; -----------------------------------------------------------------------------------------------------------
;; IX points on the Max_min_UV_Table. IX-1 is the Has_Door variable, IX-2 is the Has_no_wall variable.
MoveT_Up
	CALL ChkCantLeave
	JR Z,U_NoExit
	CALL UD_InOtherDoor
	LD A,DOOR_HIGH
	JR c,U_NoExit2
	BIT 2,(IX-1)
	JR Z,U_NoDoor
	LD A,(DoorHeights+1)
	CALL DoorHeightCheck
	JR c,U_NoExit
	CALL UD_InFrame
	JR c,U_NearDoor
	LD A,(MaxU)
	ADD A,4
	JR U_Exit
U_NoDoor
	BIT 2,(IX-2)
	JR Z,U_NoExit
	LD A,(MaxU)
U_Exit
	CP D
	RET NZ
	LD A,3
	JP LeaveRoom
U_NoExit
	LD A,(MaxU)
U_NoExit2
	CP D
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Handle the near-door case: If we're not near the door frame,
;; we do the normal "not door" case. Otherwise, we do that and
;; then nudge into the door.
.U_NearDoor:
	CALL UD_InFrameW
	JR c,U_NoExit
	CALL U_NoExit
	JP UD_Nudge

;; -----------------------------------------------------------------------------------------------------------
;; IX points on the Max_min_UV_Table. IX-1 is the Has_Door variable, IX-2 is the Has_no_wall variable.
MoveT_Left
	CALL ChkCantLeave
	JR Z,L_NoExit
	CALL LR_InOtherDoor
	LD A,DOOR_HIGH
	JR c,L_NoExit2
	BIT 3,(IX-1)
	JR Z,L_NoDoor
	LD A,(DoorHeights)
	CALL DoorHeightCheck
	JR c,L_NoExit
	CALL LR_InFrame
	JR c,L_NearDoor
	LD A,(MaxV)
	ADD A,4
	JR L_Exit
L_NoDoor
	BIT 3,(IX-2)
	JR Z,L_NoExit
	LD A,(MaxV)
L_Exit
	CP H
	RET NZ
	LD A,4
	JP LeaveRoom
L_NoExit
	LD A,(MaxV)
L_NoExit2
	CP H
	RET NZ
	SCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Handle the near-door case: If we're not near the door frame,
;; we do the normal "not door" case. Otherwise, we do that and
;; then nudge into the door.
.L_NearDoor:
	CALL LR_InFrameW
	JR c,L_NoExit
	CALL L_NoExit
	JP LR_Nudge

;; -----------------------------------------------------------------------------------------------------------
;; If we're not inside the V extent, we must be in the doorframes to
;; the side. Set Carry if this is the case.
;; IX points on the Max_min_UV_Table.
.UD_InOtherDoor:
	LD A,(MaxV)
	CP H
	RET c
	LD A,L
	CP (IX+1)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; If we're not inside the U extent, we must be in the doorframes to
;; the side. Set Carry if this is the case.
;; IX points on the Max_min_UV_Table.
.LR_InOtherDoor:
	LD A,(MaxU)
	CP D
	RET c
	LD A,E
	CP (IX+0)
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Return NC if within the interval associated with the door.
;; Specifically, returns NC if D <= DOOR_HIGH and E >= DOOR_LOW
.LR_InFrame:
	LD A,DOOR_HIGH
	CP D
	RET c
	LD A,E
	CP DOOR_LOW
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Same, but for the whole door, not just the inner arch
.LR_InFrameW:
	LD A,DOOR_HIGH + 4
	CP D
	RET c
	LD A,E
	CP DOOR_LOW - 4
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Return NC if within the interval associated with the door.
;; Specifically, returns NC if H <= DOOR_HIGH and L >= DOOR_LOW
.UD_InFrame:
	LD A,DOOR_HIGH
	CP H
	RET c
	LD A,L
	CP DOOR_LOW
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Same, but for the whole door, not just the inner arch
.UD_InFrameW:
	LD A,DOOR_HIGH + 4
	CP H
	RET c
	LD A,L
	CP DOOR_LOW - 4
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Door height check.
;;
;; Checks to see if the character Z coord (in A) is between B
;; and either B + 3 or B + 9 (depending on if you're both head
;; and heels currently). Returns NC if the character is in the right
;; height range to go through door.
.DoorHeightCheck:
	SUB B
	RET c
	CP 3
	CCF
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Points IX at the room boundaries, sets zero flag (can't leave room) if:
;; Bit 0 of IY+O_SPRFLAGS is not zero, or bottom 7 bits of IY+0A are not zero.
;;
;; Assumes IY points at the object.
;; Returns with zero flag set if it can't leave the room.
;; Also points IX at the room boundaries.
;;
;; TODO: Can't leave room if it's a not a player, or the object
;; function is zero'd.
.ChkCantLeave:
	BIT 0,(IY+O_SPRFLAGS)
	LD IX,Max_min_UV_Table
	RET

;; -----------------------------------------------------------------------------------------------------------
;; HL points to the object to check + 2.
;; Assumes flags are in range 0-3.
;; Returns fixed height of 6 in E.
;; Returns V extent in B, U extent in C.
;; Leaves HL pointing at the U coordinate.
.GetSimpleSize:
	INC HL
	INC HL
	LD A,(HL)
	INC HL
	LD E,6
	BIT 1,A
	JR NZ,GSS_1
	RRA
	LD A,3
	ADC A,0
	LD B,A
	LD C,A
	RET

GSS_1
	RRA
	JR c,GSS_2
	LD BC,&01 * WORD_HIGH_BYTE + &04
	RET
GSS_2
	LD BC,&04 * WORD_HIGH_BYTE + &01
	RET

;; -----------------------------------------------------------------------------------------------------------
Double_size_char_buffer
	DEFS 16, 0

current_pen_number
	DEFB &02

Char_cursor_pixel_position
	DEFW &80 * WORD_HIGH_BYTE + &40
text_size
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; This will Print a string and in the meantime handles the attribute
;; codes inserted within the string data.
;; -----------------------------------------------------------------------------------------------------------
;; If the string code is >= &80, then use the string data defined in the string tables:
;;  * String ID &80 to &CB come from String_Table_Main index 0 to &4B;
;;  * String ID &E0 to &FF come from String_Table_Kb index 0 to &1F.
;; But we can also use the following codes:
;; 	 00 : Wipe Screen effect
;; 	 01 : New Line
;; 	 02 : Space to erase until the end of the line
;;   03 : Text_single_size (double height Off)
;;   04 : Text_double_size (double height On)
;;   05 xx : Color attribute
;;			xx = 00 : Rainbow (each letter changes the color)
;;				 else : color (1, 2 or 3)
;; 	 06 xx yy : Set_Text_Position col xx, row yy
;; -----------------------------------------------------------------------------------------------------------
Print_String
smc_print_string_routine
	JP Print_Char_base
Print_Char_base
	CP &80
	JR NC,Sub_Print_String
	SUB &20
	JR c,Control_Codes
	CALL Char_code_to_Addr
	LD HL,&08 * WORD_HIGH_BYTE + &04
	LD A,(text_size)
	AND A
	CALL NZ,Double_sized_char
	LD BC,(Char_cursor_pixel_position)
	LD A,C
	ADD A,&04
	LD (Char_cursor_pixel_position),A
	LD A,(current_pen_number)
	JP Draw_Sprite

Sub_Print_String
	AND &7F
	CALL Get_String_code_A
print_char_until_delimiter
	LD A,(HL)
	CP Delimiter
	RET Z
	INC HL
	PUSH HL
	CALL Print_String
	POP HL
	JR print_char_until_delimiter

;; -----------------------------------------------------------------------------------------------------------
;; Available string attribute codes:
;; 	 00 : Wipe Screen effect
;; 	 01 : New Line
;; 	 02 : Space to erase until the end of the line
;;   03 : Text_single_size (double height Off)
;;   04 : Text_double_size (double height On)
;;   05 xx : Color attribute
;;			xx = 00 : Rainbow (each letter changes the current color (cycle 1 to 3))
;;				 else : color (1, 2 or 3)
;; 	 06 xx yy : Set_Text_Position col xx, row yy
;; -----------------------------------------------------------------------------------------------------------
;; First part of the string attributes parsing. Handles the codes
;; 0 to 4. It'll jump to Control_Codes_more for codes 5 to 7
Control_Codes
	ADD A,&20
	CP &05
	JR NC,Control_Codes_more
	AND A
	JP Z,clr_screen
	SUB 2
	JR c,Control_Code_new_line
	JR Z,Control_Code_space_erase_end
	DEC A
	LD (text_size),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This is the string attribute 02: clear the line from current cursor
;; position to the end of line (erase any old character that could
;; remain when text has changed)
SPACE_CHAR				EQU		&20

Control_Code_space_erase_end:
	LD A,(Char_cursor_pixel_position)
	CP &C0
	RET NC
	LD A,SPACE_CHAR
	CALL Print_String
	JR Control_Code_space_erase_end

;; -----------------------------------------------------------------------------------------------------------
;; This is the string attribute 01: "New line" (go to begining of next line)
.Control_Code_new_line:
	LD HL,(Char_cursor_pixel_position)
	LD A,(text_size)
	AND A
	LD A,H
	JR Z,ccnewln_single
	ADD A,&08
ccnewln_single
	ADD A,&08
	LD H,A
	LD L,&40
	LD (Char_cursor_pixel_position),HL
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Next part of the string attributes parsing. Here it'll handle the
;; codes 5, 6 and 7; these are followed by parameters
.Control_Codes_more:											;; Handles Codes 5, 6 and 7
	LD HL,Control_Code_attribute_5_setmode  ;; Control_Code_attribute_5_setmode
	JR Z,Update_attribute_jump_address
	LD HL,Control_Code_attribute_6_getcol
Update_attribute_jump_address
	LD (smc_print_string_routine+1),HL
	RET

Control_Code_attribute_5_setmode
	LD (current_pen_number),A
Control_Code_attribute_funnel
	LD HL,Print_Char_base
	JR Update_attribute_jump_address

Control_Code_attribute_6_getcol
	LD HL,Control_Code_attribute_6_getrow
	ADD A,A
	ADD A,A
	ADD A,&40			;; &40=minX
	LD (Char_cursor_pixel_position),A
	JR Update_attribute_jump_address

Control_Code_attribute_6_getrow
	ADD A,A
	ADD A,A
	ADD A,A
	LD (Char_cursor_pixel_position+1),A
	JR Control_Code_attribute_funnel

;; -----------------------------------------------------------------------------------------------------------
;; Produce a String attribute 06 (position "LOCATE")
;; Input: BC is the position;
;; Output: HL = pointer on Cursor_position_code string attribute.
.Set_Cursor_position:
	LD (smc_Cursor_pos),BC
	LD HL,Cursor_position_code
	JP print_char_until_delimiter

;; -----------------------------------------------------------------------------------------------------------
;; This produce a "String" attribute code 06 (position).
;; the position is set by Set_Cursor_position
.Cursor_position_code:
	DEFB	Print_SetPos ;; 06
smc_Cursor_pos
	DEFW	&00 * WORD_HIGH_BYTE + &00
	DEFB	Delimiter

;; -----------------------------------------------------------------------------------------------------------
;; This will find the pointer on the String we are looking for.
;; The "String ID AND &7F" is in A.
;;  * String ID &80 to &CB come from String_Table_Main index 0 to &4B;
;;  * String ID &E0 to &FF come from String_Table_Kb index 0 to &1F.
;; Output: HL = pointer on the wanted String data.
.Get_String_code_A:
	LD B,A
	INC B
	LD A,Delimiter
	LD HL,String_Table_Main
loop_search_nth_Delimiter
	LD C,A
	CPIR
	DJNZ loop_search_nth_Delimiter
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This creates a zoomed char sprite from the original char
;; Output: DE will point on the double sized char buffer
Double_sized_char
	LD B,8
	LD HL,Double_size_char_buffer
dsc_loop
	LD A,(DE)
	LD (HL),A
	INC HL
	LD (HL),A
	INC HL
	INC DE
	DJNZ dsc_loop
	LD HL,&10 * WORD_HIGH_BYTE + &04
	LD DE,Double_size_char_buffer
	RET

;; -----------------------------------------------------------------------------------------------------------
DIGIT2ASCII				EQU		&30

Print_2Digits
	PUSH DE
	LD A,D
	CALL subprint_2Digits
	POP DE
	LD A,E
	PUSH AF
	RRA
	RRA
	RRA
	RRA
	AND &0F
	JR subprint_number
subprint_2Digits
	PUSH AF
	RRA
	RRA
	RRA
	RRA
	AND &0F
	JR NZ,subprint_number
	LD A,&F0
subprint_number
	CALL subprint_num
	POP AF
	AND &0F
subprint_num
	ADD A,DIGIT2ASCII
	JP Print_String

;; -----------------------------------------------------------------------------------------------------------
;; Bit 0 set = have updated object extents
;; Bit 1 set = needs redraw
DrawFlags:
	DEFB 0
Collided
	DEFB &FF

;; -----------------------------------------------------------------------------------------------------------
;; when pushed, the object will "roll" like a ball until it collides with something.
;; can be pushed by playable characters or moving enemies
ObjFnBall:
	LD A,(ObjDir)
	INC A
	JR NZ,ObjFnEnd2
	LD A,(IY+&0C)
	INC A
	JR Z,ObjFnEnd4
ObjFnEnd2
	CALL ObjAgain8
	CALL ObjFnSub
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
ObjFnEnd4
	PUSH IY
	CALL ObjFnPushable
	POP IY
	LD (IY+O_IMPACT),&FF
	RET

;; -----------------------------------------------------------------------------------------------------------
ObjFnSub
	LD A,(ObjDir)
	AND (IY+&0C)
	CALL DirCode_from_LRDU
	CP &FF
	RET Z
	LD HL,(CurrObject)
	CALL MoveCurrent
	JP c,Sound_ID_Todo_4
	PUSH AF
	CALL UpdateObjExtents
	POP AF
	LD HL,(CurrObject)
	PUSH HL
	PUSH HL
	PUSH AF
	CALL UpdatePos
	POP AF
	POP HL
	CALL MoveCurrent
	POP HL
	RET c
	JP UpdatePos

;; -----------------------------------------------------------------------------------------------------------
;; Turn off all object function is touched
ObjFnSwitch
	LD A,(IY+&0C)
	OR &C0
	INC A
	RET Z
	CALL Sound_ID_Todo_5
	LD HL,ObjFn_SwitchOff
	JP objfnsw_2

ObjFn_SwitchOff
	LD (IX+O_FUNC),0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Heliplat are used to lift the player upwards.
;; Peculiarity: If comming from ObjFnHeliplat10, the LD A,&10 is done.
;; But if coming from ObjFnHeliplat60 (for instance), the "DEFB 01" at 3D6C and 3D6F
;; will take the "3E xx" as data in a dummy instruction "LD BC,&xx3E" to cancel the "LD A,&xx"
;; hence letting the "LD A,&60" take over.
ObjFnHeliplat90:
	LD		A,&90
	DEFB 	&01						;;LD BC,... to cancel the LD A,&60
ObjFnHeliplat60:
	LD		A,&60
	DEFB 	&01						;;LD BC,... to cancel the LD A,&30
ObjFnHeliplat30:
	LD		A,&30
	DEFB 	&01						;;LD BC,... to cancel the LD A,&10
ObjFnHeliplat10:
	LD		A,&10
	LD		(IY+O_SPECIAL),A
	LD		(IY+O_FUNC),&11			;; OBJFN_HELIPLAT3
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This makes an elevated object - on which the player stands - gently
;; colapse to the ground (in other words it loses altitude as pressure is
;; applied on it). It does not go back up when pressure is released.
;; The cushions around the room &ABD (all but the ones under the doors)
;; use this feature.
ObjFnColapse:
	BIT 5,(IY+&0C)
	RET NZ
	CALL ObjAgain9
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; Rollers in the various LRDU directions (bits are active low)
ObjFnRollers1
	LD A,FACING_UP
	JR writeRollerDir
ObjFnRollers2:
	LD A,FACING_DOWN
	JR writeRollerDir
ObjFnRollers3
	LD A,FACING_LEFT
	JR writeRollerDir
ObjFnRollers4
	LD A,FACING_RIGHT
writeRollerDir
	LD (IY+O_IMPACT),A
	LD (IY+O_FUNC),0
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Make an object dissolve upon contact or presence in the room:
;; * ObjFnDissolve: : dissolving grating (eg. room 476).
;;      Note: The &01 at &4D45 will cancel the "LD A,&CF" at 4D66.
;; * ObjFnDissolve2: : dissolving cushion, pad, book and rollers
;;		Note: 2 cushions in the room 526 are set as Dissolve2, but when
;;	 	the switch in the room is turned off, it freezes the Beacon, but
;;	 	also makes the cushions no longer dissolvable.
;; * TestAndFade : dissolving hushpuppies if Head is in the room (no contact needed here, just entering)
ObjFnDissolve:
	LD		A,&C0
	DEFB 	&01									;; LD BC,... to cancel the "LD A,&CF" below
ObjFnDissolve2:														;; dissolving cushion, pad, book and rollers
	;; if comming from ObjFnDissolve, the "LD A,&CF" does not exist
	;; as it became a dummy "LD BC,&CF3E"
	LD		A,&CF								;; ObjFnDissolve2: A=&CF, ObjFnDissolve: A=&C0
	OR		(IY+&0C)
	INC		A
TestAndFade
	RET Z
Fadeify
	CALL Sound_ID_Todo_3	;; noise?
	LD A,(IY+O_FUNC)
	AND &80
	OR OBJFN_FADE
	LD (IY+O_FUNC),A
	LD (IY+O_ANIM),&08		;; ANIM_VAPE1_code
ObjFnFade
	LD (IY+O_FLAGS),&80
	CALL UpdateObjExtents
	CALL AnimateMe
	LD A,(IY+O_ANIM)
	AND &07
	JR Z,ObjFnDisappear
	JP ObjDraw
ObjFnDisappear
	LD HL,(CurrObject)
	JP RemoveObject

;; -----------------------------------------------------------------------------------------------------------
;; ObjFnPushable: Pushing item
.ObjFnPushable:		;; can be pushed
	CALL ObjAgain8
	LD A,&FF
	CALL TestCollisions
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; The Different ways an object can move.
;; Will define in HL the addr of the function to be used to move the enemy.
ObjFnLinePatrol:	;; used by the Anvil : Moves formard until an obstacle, then turns around (180° turn), and starts advancing again.
	LD HL,HalfTurn
	JP ObjFnUpdatePatroller
ObjFnSquarePatrol:	;; used by sandwich room &240 : it moves forward clockwise until an obstacle, then makes a 90° turn clockwise and starts advancing again.
	LD HL,Clockwise
	JP ObjFnUpdatePatroller

ObjFnVisor1: 		;; ObjFnLinePatrol but ???? TODO ; eg. robot in room &786, it moves back and forth on one lane.
	LD HL,HalfTurn
	JR TurnOnCollision
ObjFnMonocat:		;; ObjFnSquarePatrol but ???? TODO
	LD HL,Clockwise
	JR TurnOnCollision
ObjFnAnticlock:		;; ObjFnMonocat but in the other direction
	LD HL,Anticlockwise
	JR TurnOnCollision
ObjFnBee			;; used by bee (eg. room 476), move to any random direction
	LD HL,DirAny
	JR TurnOnCollision

ObjFnRandK:			;; Random direction change (any like a Chess King)
	LD HL,DirAny
	JR TurnRandomly
ObjFnRandR:			;; Random direction change, axially (like a Chess Rook).
	LD HL,DirAxes
	JR TurnRandomly
ObjFnRandB:			;; Random direction change, in diagonal (like a Chess Bishop). ; eg. Beacon room 516
	LD HL,DirDiag
	JR TurnRandomly

ObjFnHomeIn:		;; Home in, like a robomouse (attracted by the player if close enough, but can also go in lines, like a rook).
	LD HL,HomeIn
	JR GoThatWay
ObjFnTowards:		;; goes directly towards
	LD HL,MoveTowards
	JR GoThatWay

;; -----------------------------------------------------------------------------------------------------------
;; Update the Patroller objects (anim)
ObjFnUpdatePatroller:
	PUSH HL
	CALL FaceAndAnimate
	JR ObjFnWalk

;; -----------------------------------------------------------------------------------------------------------
.TurnOnCollision:
	PUSH HL
TurnOnColl2
	CALL FaceAndAnimate
	CALL ObjAgain8
	LD A,&FF
	JR c,ObjFnBounce
ObjFnWalk
	CALL DirCode_to_LRDU
ObjFnBounce
	CALL TestCollisions
	POP HL
	LD A,(Collided)
	INC A
	JP Z,ObjDraw
	CALL DoTurn
	JP ObjDraw

;; =-----------------------------------------------------------------------------------------------------------
;; Call the turning function provided earlier in HL.
DoTurn
	JP (HL)

;; -----------------------------------------------------------------------------------------------------------
;; get the chosen direction, and go that way!
.GoThatWay:
	PUSH HL
	CALL ObjAgain8
	POP HL
	CALL DoTurn
	CALL FaceAndAnimate
	CALL DirCode_to_LRDU
	CALL TestCollisions
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; Turn randomly. If not turning randomly, act like TurnOnCollision.
.TurnRandomly:
	PUSH HL
	CALL Random_gen
	LD A,L
	AND &0F
	JR NZ,TurnOnColl2
	CALL ObjAgain8
	POP HL
	CALL DoTurn
MoveObjAndDraw_bis
	CALL FaceAndAnimate
	CALL DirCode_to_LRDU
	CALL TestCollisions
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; This handles the Heliplat ascend and descend
.HeliPadDir:
	DEFB 0

;; -----------------------------------------------------------------------------------------------------------
;; Running heliplat
ObjFnHeliplat3:
	CALL FaceAndAnimate
	LD A,(IY+O_SPECIAL)
	LD B,A
	BIT 3,A
	JR Z,ofn_hp3_descent
	RRA
	RRA
	AND &3C
	LD C,A
	RRCA
	ADD A,C
	NEG
	ADD A,GROUND_LEVEL
	CP (IY+O_Z)
	JR NC,ofn_hp3_limit
	LD HL,(CurrObject)
	CALL ChkSatOn
	RES 4,(IY+O_IMPACT)
	JR NC,hp3_do_ascent
	RET Z
hp3_do_ascent
	CALL UpdateObjExtents
	DEC (IY+O_Z)
	JP ObjDraw
ofn_hp3_limit
	LD HL,HeliPadDir
	LD A,(HL)
	AND A
	JR NZ,br_4EC1
	LD (HL),2
br_4EC1
	DEC (HL)
	RET NZ
	LD A,B
	XOR &08
	LD (IY+O_SPECIAL),A
	AND &08
	RET
ofn_hp3_descent
	AND &07
	ADD A,A
	LD C,A
	ADD A,A
	ADD A,C
	NEG
	ADD A,GROUND_LEVEL - 1
	CP (IY+O_Z)
	JR c,ofn_hp3_limit
	LD HL,(CurrObject)
	CALL DoContact2
	JR NC,hp3_do_descent
	RET Z
hp3_do_descent
	CALL UpdateObjExtents
	RES 5,(IY+O_IMPACT)
	INC (IY+O_Z)
	JP ObjDraw

;; =-----------------------------------------------------------------------------------------------------------
;; Go to a NEW axial direction (different to the current one).
;; Axial direction is the Up-Down (V axis) and Left-Right (U axis) directions.
DirAxes:
	CALL Random_gen
	LD A,L
	AND &06
	CP (IY+O_DIRECTION)
	JR Z,DirAxes
	JR MoveDir

;; =-----------------------------------------------------------------------------------------------------------
;; Go to a NEW diagonal direction (different to the current one).
;; Diagonal are the axis North-South and West-East
.DirDiag:
	CALL Random_gen
	LD A,L
	AND &06
	OR &01
	CP (IY+O_DIRECTION)
	JR Z,DirDiag
	JR MoveDir

;; =-----------------------------------------------------------------------------------------------------------
;; Turn to any NEW direction.
.DirAny:
	CALL Random_gen
	LD A,L
	AND &07
	CP (IY+O_DIRECTION)
	JR Z,DirAny
	JR MoveDir

;; =-----------------------------------------------------------------------------------------------------------
;; Turn 90 degrees clockwise.
;; 		0 (Down), 1 (South), 2 (Right), 3 (East),  4 (Up),    5 (North), 6 (Left), 7 (West)
;; -2 : 6 (Left), 7 (West),  0 (Down),  1 (South), 2 (Right), 3 (East),  4 (Up),   5 (North)
.Clockwise:
	LD A,(IY+O_DIRECTION)
	SUB 2
	JR Mod8MoveDir

;; =-----------------------------------------------------------------------------------------------------------
;; Turn 90 degrees anticlockwise.
;; 		0 (Down),  1 (South), 2 (Right), 3 (East),  4 (Up),   5 (North), 6 (Left), 7 (West)
;; +2 : 2 (Right), 3 (East),  4 (Up), 	 5 (North), 6 (Left), 7 (West),  0 (Down), 1 (South)
.Anticlockwise:
	LD A,(IY+O_DIRECTION)
	ADD A,2
Mod8MoveDir
	AND &07
MoveDir
	LD (IY+O_DIRECTION),A
	RET

;; =-----------------------------------------------------------------------------------------------------------
;; Turn 180 degree (half-turn).
;; 		0 (Down), 1 (South), 2 (Right), 3 (East), 4 (Up), 	5 (North), 6 (Left),  7 (West)
;; +4 : 4 (Up),   5 (North), 6 (Left),  7 (West), 0 (Down), 1 (South), 2 (Right), 3 (East)
HalfTurn
	LD A,(IY+O_DIRECTION)
	ADD A,4
	JR Mod8MoveDir

;; -----------------------------------------------------------------------------------------------------------
;; Find the direction number associated with zeroing the
;; smaller distance, and then working towards the other axis.
.HomeIn:
	CALL CharDistAndDir
	LD A,D
	CP E
	LD B,&F3		;; %11110011
	JR c,hmin_1
	LD A,E
	LD B,&FC		;; %11111100
hmin_1
	AND A
	LD A,B
	JR NZ,hmin_2
	XOR &0F
hmin_2
	OR C
MoveToDirMask
	CALL DirCode_from_LRDU
	JR MoveDir

;; -----------------------------------------------------------------------------------------------------------
;; Compare Enemy and character and get the enemy direction LRDU vector in A
;; "Distance" in DE (deltaV,deltaU)
;; MoveTowards : Move enemy towards target
.MoveTowards:
	CALL CharDistAndDir
	JR MoveToDirMask

;; -----------------------------------------------------------------------------------------------------------
;; From an object/Enemy in IY (rather the ref to its variables/object instance)
;; get the direction vector to the current character.
;; Return: A is of type LRDU (Left/Right/Down/Up) active low
;; Return: DE has the distance (deltaV in D, deltaU in E)
CharDistAndDir
	LD HL,(Batman_variables+O_U)
	LD C,&FF
	LD A,H
	SUB (IY+O_V)
	LD D,A
	JR Z,VCoordMatch
	JR NC,VCoordDiff
	NEG
	LD D,A
	SCF
VCoordDiff
	PUSH AF
	RL C
	POP AF
	CCF
	RL C
VCoordMatch
	LD A,(IY+O_U)
	SUB L
	LD E,A
	JR Z,UCoordMatch
	JR NC,UCoordDiff
	NEG
	LD E,A
	SCF
UCoordDiff
	PUSH AF
	RL C
	POP AF
	CCF
	RL C
	LD A,C
	RET

UCoordMatch
	RLC C
	RLC C
	LD A,C
	RET

;; -----------------------------------------------------------------------------------------------------------
;; Mark as previously touched...
objfnsw_2
	LD (smc_objfnsw+1),HL
	LD HL,ObjList_Regular_Near2Far
objfnsw_loop
	LD A,(HL)
	INC HL
	LD H,(HL)
	LD L,A
	OR H				;; get next object pointer
	JR Z,objfnsw_3		;; if NULL (end) then jump objfnsw_3
	PUSH HL
	PUSH HL
	POP IX
smc_objfnsw
	CALL NULL_PTR			;; call SwitchOff
	POP HL
	JR objfnsw_loop

;; End part, mark for redraw and toggle the switch state flag.
objfnsw_3:
	CALL MarkToDraw
	LD A,(IY+O_FLAGS)
	XOR &10
	LD (IY+O_FLAGS),A
	JP ObjDraw

;; -----------------------------------------------------------------------------------------------------------
;; If bit 0 of DrawFlags is not set, set it and update the object extents.
UpdateObjExtents
	LD A,(DrawFlags)
	BIT 0,A
	RET NZ
	OR &01
	LD (DrawFlags),A
	LD HL,(CurrObject)
	JP StoreObjExtents

;; -----------------------------------------------------------------------------------------------------------
;; Clear &0C and if any of DrawFlags are set, draw the thing.
ObjDraw
	LD (IY+&0C),&FF
	LD A,(DrawFlags)
	AND A
	RET Z
	CALL UpdateObjExtents
	LD HL,(CurrObject)
	CALL Relink
	LD HL,(CurrObject)
	JP UnionAndDraw

;; -----------------------------------------------------------------------------------------------------------
;; From how the object in IY moves, update the anim sprite (forward/backward)
;; and animate + MarkToDraw if it's an animation.
.FaceAndAnimate:
	CALL SetFacingDirEx
AnimateMe
	CALL AnimateObj
	RET NC
MarkToDraw
	LD A,(DrawFlags)
	OR &02
	LD (DrawFlags),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; collision check?
;; input A = ??; IY = ??
TestCollisions:
	AND (IY+&0C)
	CP &FF
	LD (Collided),A
	RET Z
	CALL DirCode_from_LRDU
	CP &FF
	LD (Collided),A
	RET Z
	PUSH AF
	LD (Collided),A
	LD HL,(CurrObject)
	CALL MoveCurrent
	POP BC
	CCF
	JP NC,br_501F
	PUSH AF
	CP B
	JR NZ,br_5016
	LD A,&FF
	LD (Collided),A
br_5016
	CALL UpdateObjExtents
	POP AF
	LD HL,(CurrObject)
	CALL UpdatePos
	SCF
	RET

br_501F
	LD A,(ObjDir)
	INC A
	RET Z
	JP Sound_ID_Todo_4

;; -----------------------------------------------------------------------------------------------------------
;; check something and return Carry or NotCarry.
;; also deals with object falling or going up.
;;
;; For exemple, this will turn ObjFnVisor1 into ObjFnLinePatrol (or ObjFnMonocat into ObjFnSquarePatrol)
;; when the result is NC (will reconvert DirCode_to_LRDU).
;; Else the ObjFnVisor1 (or ObjFnMonocat) won't get the new dirCode.
ObjAgain8:
	BIT 4,(IY+&0C)
	JR Z,ObjAgain10
ObjAgain9
	LD HL,(CurrObject)
	CALL DoContact2
	JR NC,OA9c
	CCF
	JR NZ,OA9b
	BIT 4,(IY+&0C)
	RET NZ
	JR ObjAgain10

OA9b
	BIT 4,(IY+&0C)
	SCF
	JR NZ,OA9c
	RES 4,(IY+O_IMPACT)
	RET
OA9c
	PUSH AF
	CALL UpdateObjExtents
	RES 5,(IY+O_IMPACT)
	INC (IY+O_Z)
	POP AF
	RET c
	INC (IY+O_Z)
	SCF
	RET

ObjAgain10
	LD HL,(CurrObject)
	CALL ChkSatOn
	RES 4,(IY+O_IMPACT)
	JR NC,br_5072
	CCF
	RET Z
br_5072
	CALL UpdateObjExtents
	DEC (IY+O_Z)
	SCF
	RET

;; =-----------------------------------------------------------------------------------------------------------
;; From direction code in O_DIRECTION (0 to 7 or FF), returns               Up   east
;; the coresponding LRDU (Left/Right/Down/Up) value (active low)   north __________> U              Up
;;             															|05 04 03         	     F6 FE FA
;;                                                                 Left |06 FF 02 Right     Left F7    FB Right
;; This is pretty much the reverse of DirCode_from_LRDU					|07 00 01         	     F5 FD F9
;; Note : "Up/Left" is the far corner, "DownRight"                 west |  Down  south     	       Down
;;        the near corner                                             V Y
DirCode_to_LRDU:
	LD A,(IY+O_DIRECTION)
	ADD A,DirCode2LRDU_table and WORD_LOW_BYTE ;; 405D
	LD L,A
	ADC A,DirCode2LRDU_table / WORD_HIGH_BYTE ;; 405D
	SUB L
	LD H,A
	LD A,(HL)
	RET

DirCode2LRDU_table
	DEFB 	FACING_DOWN, FACING_NEAR, FACING_RIGHT, FACING_EAST
	DEFB	FACING_UP, FACING_FAR, FACING_LEFT, FACING_WEST

;; -----------------------------------------------------------------------------------------------------------
;; This will keep or flip the anim sprite to the forward/backward sprite
;; as required by how the object moves.
;; IY points on the object's object (variables)
.SetFacingDirEx:
	LD C,(IY+O_DIRECTION)
	BIT 1,C
	RES 4,(IY+O_FLAGS)
	JR NZ,SetFacingDir
	SET 4,(IY+O_FLAGS)
SetFacingDir
	LD A,(IY+O_ANIM)
	AND A
	RET Z
	BIT 2,C
	LD C,A
	JR Z,sfd_tw
	BIT 3,C
	RET NZ
	LD A,&08 ;; ANIM_VAPE1_code
	JR sfd_1
sfd_tw
	BIT 3,C
	RET Z
	XOR A
sfd_1
	XOR C
	AND &0F
	XOR C
	LD (IY+O_ANIM),A
	RET

;; -----------------------------------------------------------------------------------------------------------
;; This is most likely a left over copy of some code from 4011
;;	4091 30 16          JR NC,40A9
;;	4093 3F             CCF
;;	4094 20 07          JR NZ,409D
;;	4096 FD CB 0C 66    BIT 4,(IY+0C)
;;	409A C0             RET NZ
;;	409B 18 1E          JR 40BB
;;	409D FD CB 0C 66    BIT 4,(IY+0C)
;;	40A1 37             SCF
;;	40A2 20 05          JR NZ,40A9
;;	40A4 FD CB 0B A6    RES 4,(IY+0B)
;;	40A8 C9             RET
;;	40A9 F5             PUSH AF
;;	40AA CD 8E 3F       CALL 3F8E
;;	40AD FD CB 0B AE    RES 5,(IY+0B)
;;	40B1 FD 34 07       INC (IY+07)
;;	40B4 F1             POP AF
;;	40B5 D8             RET c
;;	40B6 FD 34 07       INC (IY+07)
;;	40B9 37             SCF
;;	40BA C9             RET
;;	40BB 2A 41 2B       LD HL,(2B41)
;;	40BE CD 81 22       CALL 2281
;;	40C1 FD CB 0B A6    RES 4,(IY+0B)
;;	40C5 30 02          JR NC,40C9
;;	40C7 3F             CCF
;;	40C8 C8             RET Z
;;	40C9 CD 8E 3F       CALL 3F8E
;;	40CC FD 35 07       DEC (IY+07)
;;	40CF 37             SCF
;;	40D0 C9             RET
;;	40D1 FD 7E 10       LD A,(IY+10)
;;	40D4 C6 5D          ADD A,5D
;;	40D6 6F             LD L,A
;;	40D7 CE 40          ADC A,40
;;	40D9 95             SUB L
;;	40DA 67             LD H,A
;;	40DB 7E             LD A,(HL)
;;	40DC C9             RET
;;	40DD FD F9          LD SP,IY
;;	40DF FB             EI
;;	40E0 FA FE F6       JP M,F6FE
;;	40E3 F7             RST 30
;;	40E4 F5             PUSH AF
;;	40E5 FD 4E 10       LD C,(IY+10)
;;	40E8 CB 49          BIT 1,C
;;	40EA FD CB 04 A6    RES 4,(IY+04)
;;	40EE 20 04          JR NZ,40F4
;;	40F0 FD CB 04 E6    SET 4,(IY+04)
;;	40F4 FD 7E 0F       LD A,(IY+0F)
;;	40F7 A7             AND A
;;	40F8 C8             RET Z
;;	40F9 CB 51          BIT 2,C
;;	40FB 4F             LD C,A
;;	40FC 28 07          JR Z,4105
;;	40FE CB 59          BIT 3,C
;;	4100 F8             RET M
;;	4101 08             EX AF,AF'
;;	4102 8F             ADC A,A
;;	4103 F0             RET P
;;	4104 08             EX AF,AF'
;;	4105 8F             ADC A,A
;;	4106 E0             RET PE
;;	4107 00             NOP
;;	4108 07             RLCA
;;	4109 E0             RET PE
;;	410A 00             NOP
;;	410B 01 F0 00       LD BC,00F0
;;	410E 06 F8          LD B,F8
;;	4110 E0             RET PE
;;	4111 06 FC          LD B,FC
;;	4113 C0             RET NZ
;;	4114 2D             DEC L
;;	4115 FF             RST 38
;;	4116 00             NOP
;;	4117 73             LD (HL),E
;;	4118 FF             RST 38
;;	4119 00             NOP
;;	411A 3F             CCF
;;	411B FE 00          CP 00
;;	411D 7F             LD A,A
;;	411E FC 00 FF       CALL M,FF00
;;	4121 FE 03          CP 03
;;	4123 FF             RST 38
;;	4124 FF             RST 38
;;	4125 01 FF FF       LD BC,FFFF
;;	4128 80             ADD A,B
;;	4129 FF             RST 38
;;	412A FF             RST 38
;;	412B C0             RET NZ
;;	412C 7F             LD A,A
;;	412D FF             RST 38
;;	412E E0             RET PE
;;	412F 3F             CCF
;;	4130 FF             RST 38
;;	4131 F0             RET P
;;	4132 3F             CCF
;;	4133 FF             RST 38
;;	4134 F9             LD SP,HL
;;	4135 7F             LD A,A
;;	4136 00             NOP
;;	4137 00             NOP
;;	4138 00             NOP
;;	4139 01 CF 80       LD BC,80CF
;;	413C 03             INC BC
;;	413D F3             DI
;;	413E E0             RET PE
;;	413F 07             RLCA
;;	4140 F9             LD SP,HL
;;	4141 F0             RET P
;;	4142 0F             RRCA
;;	4143 EE F8          XOR F8
;;	4145 0F             RRCA
;;	4146 E1             POP HL
;;	4147 A0             AND B
;;	4148 0F             RRCA
;;	4149 F7             RST 30
;;	414A B0             OR B
;;	414B 07             RLCA
;;	414C 9B             SBC A,E
;;	414D B0             OR B
;;	414E 0B             DEC BC
;;	414F C7             RST 00
;;	4150 78             LD A,B
;;	4151 0D             DEC C
;;	4152 BF             CP A
;;	4153 C0             RET NZ
;;	4154 07             RLCA
;;	4155 BF             CP A
;;	4156 60             LD H,B
;;	4157 05             DEC B
;;	4158 5F             LD E,A
;;	4159 00             NOP
;;	415A 01 7B C0       LD BC,C07B
;;	415D 03             INC BC
;;	415E FF             RST 38
;;	415F E0             RET PE
;;	4160 03             INC BC
;;	4161 9F             SBC A,A
;;	4162 A0             AND B
;;	4163 03             INC BC
;;	4164 BF             CP A
;;	4165 A0             AND B
;;	4166 07             RLCA
;;	4167 BF             CP A
;;	4168 A0             AND B
;;	4169 17             RLA
;;	416A 7F             LD A,A
;;	416B A0             AND B
;;	416C 36 FF          LD (HL),FF
;;	416E 40             LD B,B
;;	416F 19             ADD HL,DE
;;	4170 FF             RST 38
;;	4171 80             ADD A,B
;;	4172 03             INC BC
;;	4173 FB             EI
;;	4174 80             ADD A,B
;;	4175 03             INC BC
;;	4176 E7             RST 20
;;	4177 03             INC BC
;;	4178 10 6B          DJNZ 41E5
;;	417A 80             ADD A,B
;;	417B 41             LD B,C
;;	417C FF             RST 38
;;	417D FF             RST 38
;;	417E FF             RST 38
;;	417F FF             RST 38

		org &4180

;; -----------------------------------------------------------------------------------------------------------
;; These macros (MacroID &C0 to &DB) are used when processing the Room_list1 and 2 data to
;; build a room. They define groups of objects that can be imported as a block.
;; See algo in Room_list1 below.
Room_Macro_data
	DEFB &08, &C0, &0C, &D2, &79, &34, &97, &F1, &FE
	DEFB &0E, &C1, &1C, &C2, &73, &3A, &9D, &CF, &27, &B3, &E9, &FC, &FF, &8F, &F0
	DEFB &08, &C2, &21, &D2, &79, &34, &97, &F1, &FE
	DEFB &0D, &C3, &14, &C6, &75, &3B, &9E, &4F, &67, &D3, &F9, &FF, &1F, &E0
	DEFB &0B, &C4, &16, &D3, &79, &7C, &9E, &3F, &17, &FC, &7F, &80
	DEFB &19, &C5, &0A, &C7, &6D, &B6, &38, &9D, &F8, &25, &C6, &F3, &BA, &DE, &EF, &B7, &D7, &D3, &F1, &F9, &72, &79, &5D, &1F, &F8, &FF
	DEFB &0C, &C6, &C5, &03, &92, &E9, &3B, &9E, &3E, &DF, &FC, &7F, &80
	DEFB &08, &C7, &05, &D2, &79, &34, &97, &F1, &FE
	DEFB &14, &C8, &C7, &A7, &E3, &DD, &F1, &D1, &F8, &EB, &73, &7E, &6C, &2A, &7E, &0D, &BE, &B3, &29, &F8, &FF
	DEFB &09, &C9, &0F, &C2, &75, &3C, &9F, &4F, &F8, &FF
	DEFB &0E, &CA, &C0, &0B, &E0, &0D, &C8, &FC, &7E, &3D, &2F, &97, &7E, &3F, &C0
	DEFB &0B, &CB, &CA, &3F, &E5, &6F, &F3, &05, &F9, &80, &FF, &F0
	DEFB &09, &CC, &23, &D2, &79, &33, &9D, &CD, &F8, &FF
	DEFB &12, &CD, &1E, &C6, &F5, &7A, &DE, &EF, &6F, &D7, &D3, &EA, &F9, &72, &BA, &5D, &1F, &F8, &FF
	DEFB &00

;; -----------------------------------------------------------------------------------------------------------
;; Left over garbage (more likely)
;;	4243 06 00          LD B,00
;;	4245 7E             LD A,(HL)
;;	4246 FE 1A          CP 1A
;;	4248 28 07          JR Z,4251
;;	424A ED A0          LDI
;;	424C E2 FC 12       JP PE,12FC
;;	424F 18

;; -----------------------------------------------------------------------------------------------------------
;; Room_list1 + Room_list2 = 230 + 71 rooms = 301 rooms
;; 		Note that the victory room is in fact "composed" of 2 rooms : &8D30 and &8E30.
;;      The 8D3 has no far wall, hence we load and see 8E3, therefore counts as 2 even
;;		though we cannot enter 8E3.
;; Format:
;; <length> <high_id> <low_id in [7:4]; data in [3:0]> <data n bytes>
;; until length = 0. (Note that the room ID is in Big-Endian format)
;;
;; The data is shifted by one nibble in the roomID low byte.
;; For exemple, looking at Head's first room data at address 54C7:
;; 		54C7 10 8A 43 F8 01 02 01 3E E0 58 62 33 1A 8D FF 1F E0
;; Length = &10 (16 bytes of data not including length byte)
;; RoomID = &8A4  (1.5 bytes: "8A 4X" with low nibble ignored because it is data)
;; So the data are:  X3 F8 01 02 01 3E E0 58 62 33 1A 8D FF 1F E0
;;         0011_1111_1000_0000_0001_0000_0010_0000_0001_0011_1110_1110...
;;
;; The data is bit packed: 001_111_111_000_000_000_010_000_001_00000000__10_0_111_110_111_...
;; First 3 bits = Room Dimensions (see RoomDimensions table at addr 1ECE)
;; 			here "001" = "MinU=8, MinV=16, MaxU=72, MaxV=64"
;; Next 3 bits is Color Scheme (see array_Color_Schemes at addr 0554)
;;			here "111" = 7 (Black, Red, Blue, Pastel_yellow)
;; Next 3 bits is WorldId (see WorldId at 1EBF), to choose the walls sprites
;;			here "111" = 7 (Prison)
;; Next 3 bits is Door sprite Id (see ToDoorId at 045D) can be 0 to 3
;;   although ToDoorId will convert it to 0 to 2 to use one of the 3 types
;;   of door sprites. Here "000" = 0 : Doorway type 0.
;; Next 4x3 bits are the Walls&Doors data for FarLeft, FarRight, NearRight and  NearLeft sides
;; 			here "000 000 010 000" means Wall/NoDoor, Wall/NoDoor, Wall+Door at ground level, Wall/NoDoor
;; Next 3 bits defines the Floor tile to use.
;;			here "001" = 1 : uses floor_tile_pattern1
;; Then it will loop over the objects in the room or the Macros to use.
;; 	 * 8 bits = Object ID (as defined in the ObjDefns table at 38C9)
;;                 or (if value >= &C0) Macro ID in the Room_Macro_data table at 50D0).
;;				Here "00000000" = object ID 0 = ANIM_TELEPORT (the Teleport_data at addr 3490 says that
;;				room "8A4" goes to room "715")
;;		if Object:
;;			* 2 bits : controls how many objects of current type will be inserted ("?0" = 1; "?1" = several)
;;              and how orientation flag will be applied to the object(s) ("1?"=global, "0?"=per object);
;;				So we can have:
;;					only 1b more fetched to be used as the global orientation flag (no other bit inserted
;; 						between coordinates if several objects to get);
;;					or 1b orientation flag fetched before each set of coordinates.
;;						Here 2b flag = "10" : 1 object of current type ANIM_TELEPORT and 1b more to fetch.
;;          Loop (1 time or until coordinates = "7, 7, 0" (which means "end") as defined in the 2bit flag):
;;				1b : NoFlip/Flip bit. Global (only first loop) or per-object flag (every loop)
;;					Here 1b flag = "0" (NO Flip; if it is "1" then flip the sprite)
;;				3x3 bits: UVZ coordinates;
;;					Here "111 110 111" = U=7, V=6, Z=7 (ground level). Because only 1 object needed to be
;;						fetched (2b flag "?0"), it goes back to fetching next object/macro Id, which here is
;;                      SPR_GRATING, flag "11" (several/global), global orientation flag = "0" (No Flip)
;;                      and 4 coords fetched 0;6;1 0;6;3 0;6;5 0;6;7 (then the ending code 7;7;0).
;;						That finishes the data for that room.
;;						Note that the Special object "SPR_BUNNY (lives)" at 0;6;0 is added in another routine
;;						and is not part of the room data.
;;		if Macro:
;;			* 3x3 bits for origin offset coordinate added to all objects in the macro;
;;				Then it loops to fetching 8b object id or Macro id until the code is "FF" to leave
;;				the macro and go back where we were in the room data.
		org &4250
Room_list: ;; 151 rooms
	DEFB &0D, &05, &1E, &0B, &40, &00, &03, &24, &F9, &A0, &73, &98, &4F, &FF
	DEFB &06, &06, &1D, &CB, &41, &01, &FE
	DEFB &08, &07, &15, &8B, &01, &8F, &82, &37, &FF
	DEFB &17, &07, &25, &4B, &00, &0E, &01, &02, &C5, &78, &4E, &2F, &FC, &0D, &E0, &BB, &56, &A7, &D1, &0F, &BB, &FF, &1F, &E0
	DEFB &16, &94, &23, &80, &10, &0F, &82, &17, &2A, &9E, &71, &CD, &EF, &EF, &FE, &08, &FA, &DA, &6D, &B6, &FC, &7F, &80
	DEFB &11, &07, &35, &0B, &08, &00, &25, &23, &E0, &13, &A8, &37, &9D, &3D, &5B, &67, &E3, &FC
	DEFB &06, &10, &3C, &24, &20, &8B, &FE
	DEFB &06, &11, &3C, &24, &40, &8B, &FE
	DEFB &24, &12, &31, &E6, &01, &00, &47, &3A, &A0, &73, &CC, &1D, &B8, &E0, &7F, &C1, &1E, &EA, &E5, &F2, &B9, &6F, &C0, &56, &EA, &6F, &BF, &04, &98, &7D, &E7, &DF, &8F, &DF, &FF, &8F, &F0
	DEFB &08, &17, &30, &8B, &40, &21, &9A, &07, &FF
	DEFB &0B, &19, &3E, &4B, &92, &01, &9A, &07, &0B, &92, &7F, &F0
	DEFB &06, &1A, &3C, &24, &41, &0B, &FE
	DEFB &0D, &1B, &30, &64, &41, &0B, &8C, &07, &33, &DE, &71, &FF, &E3, &FC
	DEFB &13, &1C, &30, &E4, &41, &0A, &85, &3C, &F9, &48, &72, &6D, &27, &5F, &21, &97, &E8, &7F, &C7, &F8
	DEFB &12, &1D, &3D, &64, &41, &00, &63, &1C, &E5, &31, &BE, &4F, &99, &F3, &79, &7C, &7F, &F1, &FE
	DEFB &0B, &1E, &3F, &24, &6D, &8A, &1D, &B1, &E4, &FF, &C7, &F8
	DEFB &09, &1F, &3C, &24, &21, &0A, &41, &1A, &FF, &E0
	DEFB &06, &29, &37, &8B, &08, &21, &FE
	DEFB &10, &2D, &3F, &F9, &B4, &0A, &67, &89, &ED, &FF, &C0, &1E, &2B, &A3, &FF, &1F, &E0
	DEFB &06, &2E, &3C, &A4, &41, &4B, &FE
	DEFB &06, &32, &3C, &92, &28, &03, &FE
	DEFB &10, &33, &3C, &92, &40, &83, &85, &FF, &21, &91, &F0, &BD, &1E, &8E, &FE, &3F, &C0
	DEFB &15, &34, &39, &52, &23, &0D, &90, &07, &2A, &8E, &F1, &CC, &C4, &66, &B5, &9B, &EE, &77, &BB, &FF, &F1, &FE
	DEFB &18, &35, &39, &52, &E0, &8D, &90, &07, &2A, &CE, &E7, &AC, &F1, &F9, &F8, &1C, &CE, &76, &3B, &3D, &BE, &D7, &FC, &7F, &80
	DEFB &3B, &36, &31, &12, &E1, &01, &8F, &07, &C7, &8F, &92, &40, &C1, &DC, &00, &1F, &40, &78, &1E, &0B, &F1, &FF, &04, &98, &A2, &18, &10, &7E, &04, &F4, &F0, &78, &7C, &5E, &3F, &3F, &02
	DEFB	        &B8, &38, &2C, &1A, &09, &3F, &03, &78, &A4, &54, &29, &86, &49, &A5, &72, &B1, &54, &22, &8E, &67, &FE, &3F, &C0
	DEFB &0C, &37, &32, &12, &D9, &02, &05, &A4, &F6, &75, &3F, &E3, &FC
	DEFB &06, &38, &3C, &FC, &41, &0B, &FE
	DEFB &06, &39, &3F, &7C, &09, &2B, &FE
	DEFB &06, &3D, &37, &39, &04, &2B, &FE
	DEFB &0F, &41, &34, &D2, &84, &0D, &90, &07, &C1, &03, &8E, &67, &7C, &BF, &F1, &FE
	DEFB &0D, &42, &3F, &D2, &25, &23, &8A, &07, &31, &4A, &FA, &5D, &F8, &FF
	DEFB &0D, &43, &3F, &D2, &08, &83, &8C, &07, &32, &F9, &6D, &77, &E3, &FC
	DEFB &06, &47, &36, &FC, &0C, &3B, &FE
	DEFB &15, &49, &31, &3C, &90, &4C, &25, &80, &F0, &79, &3F, &E0, &73, &3F, &E7, &E2, &70, &FF, &9F, &BF, &F8, &FF
	DEFB &06, &4A, &36, &9B, &09, &09, &FE
	DEFB &09, &4D, &37, &39, &08, &1A, &41, &33, &FF, &E0
	DEFB &13, &51, &34, &D2, &04, &1C, &43, &2D, &99, &00, &7C, &10, &39, &6E, &96, &BB, &95, &FF, &8F, &F0
	DEFB &0D, &52, &3F, &D2, &08, &13, &8C, &07, &32, &CB, &6B, &B7, &E3, &FC
	DEFB &06, &53, &36, &BC, &48, &27, &FE
	DEFB &13, &54, &31, &C9, &01, &8E, &55, &02, &67, &30, &0F, &86, &27, &1C, &DF, &F0, &D8, &2F, &F1, &FE
	DEFB &0D, &55, &3E, &7C, &2C, &0B, &8C, &07, &31, &56, &FA, &BD, &F8, &FF
	DEFB &08, &56, &3E, &7C, &60, &8B, &8A, &07, &FF
	DEFB &0B, &57, &3E, &7C, &01, &2A, &67, &12, &F8, &C0, &7F, &F0
	DEFB &0B, &59, &3F, &F6, &00, &3E, &39, &8C, &E5, &FF, &C7, &F8
	DEFB &12, &5A, &35, &DE, &FC, &20, &55, &B5, &D6, &EF, &C0, &E6, &76, &4B, &7C, &DE, &EF, &C7, &F8
	DEFB &10, &5B, &3C, &1E, &41, &01, &80, &3F, &C0, &07, &94, &E6, &F3, &99, &DD, &F8, &FF
	DEFB &0B, &60, &3E, &12, &C0, &08, &01, &25, &E1, &13, &1F, &FE
	DEFB &10, &61, &34, &D2, &11, &9C, &5B, &1A, &E4, &31, &BF, &90, &07, &C1, &03, &FF, &80
	DEFB &0B, &62, &3E, &3C, &40, &26, &61, &24, &F9, &A0, &7F, &F0
	DEFB &0B, &63, &3E, &7C, &01, &26, &61, &24, &F9, &A0, &7F, &F0
	DEFB &15, &65, &35, &BC, &08, &2A, &5F, &2A, &E5, &D2, &4E, &77, &14, &E4, &B8, &DE, &57, &D7, &E5, &FF, &1F, &E0
	DEFB &17, &6A, &33, &5E, &08, &20, &15, &15, &E8, &78, &4E, &1F, &FC, &0F, &61, &7B, &5F, &DF, &9F, &A7, &C9, &FF, &1F, &E0
	DEFB &1C, &71, &31, &12, &90, &48, &79, &28, &E5, &D9, &CE, &07, &FC, &12, &62, &76, &DB, &2C, &46, &DF, &75, &96, &C4, &7D, &FF, &5D, &6F, &F8, &FF
	DEFB &06, &72, &3E, &12, &49, &03, &FE
	DEFB &09, &73, &3A, &BC, &21, &00, &41, &14, &FF, &E0
	DEFB &09, &74, &3A, &BC, &40, &80, &41, &23, &FF, &E0
	DEFB &09, &75, &3F, &7C, &11, &20, &23, &2C, &FF, &E0
	DEFB &0C, &78, &3B, &9B, &10, &0E, &3F, &AA, &F5, &FB, &3F, &E3, &FC
	DEFB &15, &7A, &32, &1B, &08, &28, &63, &99, &EF, &7F, &C0, &4E, &73, &BB, &FF, &01, &5B, &4E, &5F, &FC, &7F, &80
	DEFB &22, &81, &35, &D6, &C0, &20, &09, &BD, &FA, &FF, &C1, &FE, &73, &B7, &BF, &04, &DA, &5F, &17, &FC, &15, &E3, &39, &7D, &5E, &A7, &4F, &A5, &D4, &C9, &E9, &3C, &7F, &F1, &FE
	DEFB &06, &82, &35, &52, &03, &A3, &FE
	DEFB &06, &85, &37, &3C, &08, &21, &FE
	DEFB &22, &88, &32, &1B, &08, &24, &0F, &3E, &E6, &76, &6E, &6B, &29, &E1, &FB, &9E, &8F, &FC, &21, &EC, &FE, &9F, &5F, &B7, &FC, &04, &EB, &BD, &BE, &CF, &5F, &AB, &FE, &3F, &C0
	DEFB &30, &89, &31, &9B, &08, &00, &3F, &34, &E7, &16, &F6, &11, &38, &B8, &0D, &F0, &CD, &C7, &EB, &FE, &05, &77, &1B, &9D, &D6, &FC, &0F, &68, &FD, &F3, &79, &FC, &FA, &7B, &3C, &73, &B1, &39, &9E, &7E, &2F, &37, &9D, &D4, &EF, &F7, &BF, &E3, &FC
	DEFB &09, &8A, &3E, &5B, &48, &28, &41, &09, &FF, &E0
	DEFB &0C, &8B, &39, &5B, &01, &08, &41, &A6, &F3, &62, &7F, &E3, &FC
	DEFB &1E, &94, &33, &80, &08, &04, &73, &06, &E6, &52, &4E, &0B, &AC, &D6, &7A, &BD, &5B, &F0, &3F, &A6, &D2, &E8, &77, &E0, &7B, &4D, &E5, &F0, &FF, &C7, &F8
	DEFB &16, &95, &3F, &80, &08, &24, &61, &23, &E4, &DA, &1F, &17, &97, &CD, &E4, &FF, &82, &9E, &DE, &AF, &7E, &3F, &C0
	DEFB &06, &97, &3B, &5B, &48, &05, &FE
	DEFB &06, &99, &3C, &5B, &41, &25, &FE
	DEFB &29, &9A, &3B, &9B, &01, &20, &09, &2D, &E6, &B6, &F6, &29, &1F, &C2, &D1, &7E, &13, &9F, &B3, &6F, &C0, &9E, &5B, &BD, &FF, &03, &D9, &2F, &7C, &9B, &D5, &EC, &F4, &77, &3B, &7D, &9F, &3F, &BF, &FE, &3F, &C0
	DEFB &0B, &A3, &3E, &00, &28, &04, &53, &F3, &FA, &7F, &C7, &F8
	DEFB &0E, &A4, &3E, &00, &40, &F4, &3B, &9D, &EE, &66, &EA, &70, &B7, &F8, &FF
	DEFB &0D, &A5, &3F, &00, &43, &A4, &3B, &93, &ED, &E6, &AB, &33, &F1, &FE
	DEFB &21, &A6, &30, &C0, &E1, &80, &83, &07, &E8, &53, &FE, &77, &7F, &84, &DB, &4E, &96, &BB, &71, &A4, &C9, &7E, &38, &7E, &EF, &27, &FC, &16, &E5, &AA, &B9, &4F, &F8, &FF
	DEFB &06, &A7, &3E, &80, &01, &23, &FE
	DEFB &30, &B3, &33, &C0, &00, &20, &77, &39, &23, &33, &1A, &11, &24, &E8, &13, &BE, &31, &B9, &FC, &BF, &C1, &56, &5B, &1D, &FF, &02, &FB, &2B, &35, &7A, &ED, &6E, &BF, &81, &AD, &D8, &FA, &F4, &BD, &BE, &5E, &AF, &E0, &9B, &4C, &F1, &FF, &8F, &F0
	DEFB &06, &45, &46, &6D, &48, &0B, &FE
	DEFB &09, &46, &4C, &AD, &C2, &0A, &07, &24, &FF, &E0
	DEFB &1A, &47, &49, &AD, &C2, &84, &75, &1B, &A5, &DA, &4E, &97, &FC, &15, &66, &6B, &15, &DA, &E5, &FC, &0E, &68, &2B, &F6, &7B, &F8, &FF
	DEFB &0B, &48, &45, &2D, &49, &0A, &01, &3A, &F8, &40, &7F, &F0
	DEFB &23, &54, &41, &C9, &C0, &00, &0D, &2C, &F8, &11, &71, &78, &0C, &C3, &12, &62, &41, &01, &F6, &9E, &DF, &F8, &39, &DF, &F0, &3F, &E0, &97, &03, &C2, &E4, &F2, &3A, &1F, &F1, &FE
	DEFB &06, &55, &44, &AD, &01, &2B, &FE
	DEFB &11, &57, &4F, &6D, &B4, &0A, &41, &B3, &FA, &7D, &37, &E0, &0F, &37, &E9, &FF, &8F, &F0
	DEFB &0B, &58, &41, &AD, &01, &2A, &15, &24, &C3, &72, &4F, &FE
	DEFB &18, &59, &4E, &36, &10, &0E, &4D, &0E, &64, &9A, &CF, &5F, &D7, &DB, &EA, &F9, &7F, &C0, &E6, &3B, &E9, &F3, &FF, &8F, &F0
	DEFB &06, &67, &4E, &6D, &48, &3B, &FE
	DEFB &06, &68, &4C, &ED, &41, &0B, &FE
	DEFB &0B, &69, &4F, &AD, &09, &3A, &69, &1C, &98, &1C, &7F, &F0
	DEFB &16, &77, &44, &2D, &1C, &6D, &82, &34, &C0, &3B, &E0, &6D, &C7, &30, &70, &49, &F8, &18, &DD, &CF, &27, &E3, &FC
	DEFB &09, &79, &47, &ED, &08, &2A, &71, &2C, &FF, &E0
	DEFB &0D, &87, &4F, &2D, &48, &2B, &8C, &07, &38, &69, &75, &BD, &F8, &FF
	DEFB &08, &89, &4F, &6D, &49, &3B, &8A, &07, &FF
	DEFB &10, &8A, &4D, &ED, &09, &01, &98, &10, &CC, &E8, &11, &E5, &8B, &C6, &63, &F8, &FF	;; &8A4 Batman 1st room
	DEFB &06, &97, &46, &ED, &08, &2B, &FE
	DEFB &12, &99, &44, &ED, &08, &2A, &4B, &9D, &F2, &F6, &BC, &5F, &F0, &63, &95, &F5, &7F, &C7, &F8
	DEFB &11, &9A, &45, &AD, &08, &3A, &39, &93, &F2, &7C, &FF, &E0, &BF, &37, &EB, &FF, &8F, &F0
	DEFB &25, &A7, &43, &C9, &A0, &4D, &89, &06, &C3, &0B, &18, &DE, &70, &D4, &AB, &95, &46, &BE, &08, &BC, &57, &7B, &BC, &DF, &81, &CC, &57, &EB, &FE, &03, &37, &9C, &6F, &F7, &0B, &FE, &3F, &C0
	DEFB &0C, &A8, &49, &2D, &61, &0A, &5F, &A4, &EA, &7D, &3F, &E3, &FC
	DEFB &17, &A9, &41, &C9, &41, &20, &63, &2D, &E3, &7A, &EF, &4F, &F7, &EB, &FD, &DA, &EE, &BF, &5B, &2F, &96, &FC, &7F, &80
	DEFB &0E, &AA, &4F, &6D, &01, &2A, &67, &12, &E0, &79, &BF, &5F, &FC, &7F, &80
	DEFB &0B, &59, &5E, &76, &00, &0E, &2F, &89, &E7, &7F, &C7, &F8
	DEFB &0E, &5E, &5E, &36, &10, &0F, &89, &47, &2D, &D2, &7B, &3E, &9F, &F1, &FE
	DEFB &11, &6C, &5F, &5B, &E0, &6E, &37, &A6, &8B, &47, &A1, &70, &C8, &6C, &3A, &7E, &3F, &C0
	DEFB &20, &6E, &51, &36, &03, &A2, &01, &25, &E7, &13, &8E, &4D, &A7, &73, &3F, &C0, &E6, &EC, &CD, &E6, &D2, &68, &FD, &7B, &B9, &9D, &FC, &0C, &E9, &AC, &B7, &F1, &FE
	DEFB &18, &78, &5B, &2D, &40, &0A, &01, &14, &E1, &72, &B6, &0D, &2B, &E0, &32, &A6, &3B, &AE, &F6, &EB, &2D, &52, &B9, &F8, &FF
	DEFB &0B, &79, &5E, &AD, &01, &8E, &3F, &A1, &EC, &FF, &C7, &F8
	DEFB &0B, &59, &6F, &36, &80, &0C, &5B, &9E, &F3, &7F, &C7, &F8
	DEFB &17, &5A, &61, &B6, &41, &0B, &92, &07, &C9, &3B, &E4, &95, &CC, &F3, &BC, &1F, &F8, &0F, &C0, &74, &3E, &1F, &F1, &FE
	DEFB &0B, &5C, &6F, &76, &25, &04, &67, &24, &F9, &A0, &7F, &F0
	DEFB &08, &5D, &6F, &76, &48, &85, &9A, &07, &FF
	DEFB &16, &5E, &6E, &36, &05, &04, &5B, &2E, &C0, &10, &E0, &3B, &AE, &47, &15, &96, &C8, &EE, &F6, &DB, &7E, &3F, &C0
	DEFB &08, &6C, &6F, &76, &48, &15, &9A, &07, &FF
	DEFB &0B, &6D, &6F, &B6, &49, &24, &67, &24, &F9, &A0, &7F, &F0
	DEFB &12, &6E, &6E, &36, &01, &14, &25, &36, &63, &B8, &E4, &F2, &DA, &1D, &9E, &B7, &4F, &C7, &F8
	DEFB &0B, &7B, &6E, &2E, &80, &0E, &3F, &9E, &F3, &7F, &C7, &F8
	DEFB &06, &7C, &6C, &76, &21, &23, &FE
	DEFB &09, &7D, &6C, &76, &80, &A2, &01, &21, &FF, &E0
	DEFB &0C, &6A, &84, &6B, &08, &00, &1D, &A4, &ED, &F7, &3F, &E3, &FC
	DEFB &09, &7A, &8F, &2D, &49, &26, &41, &23, &FF, &E0
	DEFB &0C, &05, &0E, &0B, &00, &3E, &3F, &8B, &E5, &72, &7F, &E3, &FC
	DEFB &08, &F5, &02, &CB, &08, &21, &90, &07, &FF
	DEFB &09, &7B, &8E, &ED, &01, &06, &21, &26, &FF, &E0
	DEFB &09, &7B, &7E, &6D, &00, &0E, &21, &26, &FF, &E0
	DEFB &09, &79, &8F, &6D, &40, &26, &21, &21, &FF, &E0
	DEFB &09, &79, &7F, &ED, &00, &0E, &21, &21, &FF, &E0
	DEFB &09, &79, &6E, &2D, &00, &0E, &21, &21, &FF, &E0
	DEFB &09, &78, &4A, &ED, &00, &0E, &21, &2A, &FF, &E0
	DEFB &09, &5C, &43, &9E, &00, &0E, &21, &01, &FF, &E0
	DEFB &20, &2F, &33, &A4, &01, &01, &8F, &2F, &C7, &96, &0E, &CF, &68, &B4, &1A, &E1, &85, &42, &F4, &9E, &4D, &25, &F6, &7A, &FD, &5F, &82, &BD, &E6, &EF, &FE, &3F, &C0
	DEFB &21, &5D, &31, &DE, &01, &20, &13, &23, &A0, &D8, &2E, &7F, &5F, &FE, &06, &F6, &7A, &BC, &DE, &8F, &7E, &07, &76, &5F, &4F, &57, &B3, &B9, &E4, &ED, &78, &BF, &E3, &FC
	DEFB &1A, &49, &41, &CE, &01, &8C, &47, &56, &E1, &51, &9D, &82, &2F, &C1, &13, &95, &E5, &FA, &FB, &F0, &41, &89, &C1, &F1, &7F, &E3, &FC
	DEFB &08, &6D, &52, &F3, &C1, &01, &82, &15, &FF
	DEFB &1F, &5B, &68, &F6, &41, &04, &65, &66, &E1, &B8, &FF, &AC, &FC, &0E, &ED, &6E, &37, &F0, &57, &A8, &F8, &6D, &2F, &E0, &9F, &2D, &EE, &F7, &F3, &BF, &E3, &FC
	DEFB &14, &A4, &21, &C0, &00, &26, &61, &23, &F9, &60, &72, &3E, &B6, &5F, &21, &90, &EB, &75, &FF, &E3, &FC
	DEFB &0C, &8A, &85, &EB, &00, &20, &1D, &A4, &ED, &F7, &3F, &E3, &FC
	DEFB &12, &98, &32, &9B, &E3, &F4, &1D, &B2, &E5, &7F, &C0, &26, &6F, &B7, &9B, &AD, &CF, &C7, &F8
	DEFB &1F, &18, &39, &4B, &41, &01, &98, &BD, &CC, &DE, &84, &C4, &BE, &12, &7C, &4A, &2D, &F3, &17, &F9, &9B, &F0, &DD, &87, &DE, &7E, &0C, &B9, &5F, &2F, &F8, &FF
	DEFB &0D, &5C, &53, &DE, &08, &02, &41, &03, &E6, &D5, &BF, &97, &87, &FF
	DEFB &2A, &E5, &01, &CB, &18, &00, &03, &3D, &87, &B3, &AA, &77, &3B, &B9, &8F, &3C, &C6, &59, &A7, &AE, &59, &3F, &03, &BA, &CB, &5D, &CE, &E9, &7D, &BE, &5F, &C0, &76, &03, &8F, &FF, &00, &B8, &CE, &5F, &FC, &7F, &80 ;; &E50 = Victory room
	DEFB &0B, &88, &4A, &2D, &81, &0A, &5D, &9C, &F1, &FF, &C7, &F8
	DEFB &0E, &7E, &6A, &B6, &01, &02, &49, &27, &C7, &75, &7E, &39, &17, &DF, &E0
	DEFB &13, &69, &85, &6D, &10, &4C, &59, &1B, &E7, &76, &3E, &3B, &AB, &F9, &FE, &F8, &78, &4D, &F8, &FF
	DEFB &16, &57, &89, &ED, &40, &00, &77, &4F, &60, &72, &4E, &57, &89, &E6, &32, &E1, &54, &9C, &BB, &5D, &7E, &3F, &C0
	DEFB &06, &59, &8E, &2D, &09, &01, &FE
	DEFB &11, &58, &8A, &ED, &41, &01, &98, &57, &CC, &3B, &E6, &71, &CC, &73, &BE, &4F, &F8, &FF
	DEFB &08, &5C, &22, &9E, &00, &0F, &82, &2F, &FF
	DEFB &13, &5C, &32, &9E, &DB, &0E, &21, &01, &E5, &B1, &EA, &43, &99, &AD, &56, &EB, &95, &DB, &F8, &FF
	DEFB &06, &6C, &37, &1E, &08, &21, &FE
	DEFB &0B, &8C, &35, &DE, &00, &20, &69, &74, &98, &08, &7F, &F0
	DEFB &0D, &7C, &33, &5E, &1C, &7C, &0F, &24, &C1, &D2, &4F, &82, &05, &FF
	DEFB &00

;; -----------------------------------------------------------------------------------------------------------
;; Left over garbage (most likely).
;;	4BFD 1A             LD A,(DE)
;;	4BFE ED B1          CPIR

	org &4c00		;; (will be overridden at build, this space is freed at init when data is moved further)

BUFFER_LENGTH			EQU		256
BlitBuff:
	DEFS	BUFFER_LENGTH, 0
ViewBuff
	DEFS	BUFFER_LENGTH, 0
DestBuff
	DEFS	BUFFER_LENGTH, 0
RevTable
	DEFS	BUFFER_LENGTH, 0

BACKGRDBUFF_LENGTH		EQU		64
BackgrdBuff
	DEFS 	BACKGRDBUFF_LENGTH

SR_BLOCK4_LENGTH		EQU		&03F0
SaveRestore_Block4
ObjectsBuffer
	DEFS 	SR_BLOCK4_LENGTH
TODO_6E30
	DEFS 	&190 			;; ???

BlitRot_Buffer
KeyScanningBuffer
	DEFS 	10				;; Buffer (key scanning)
	DEFS 	&10E

;; -----------------------------------------------------------------------------------------------------------CPC
;; Moved Data from 4C00-AC8F to 56D8-B767
	org &4C00 ;; &4C00 at build but is moved to 56D8 duing the init stuff

PanelFlips
	DEFS 8, 0
SpriteFlips_buffer
	DEFS 16, 0

;; -----------------------------------------------------------------------------------------------------------
img_wall_deco:
img_wall_0:
	;; 4 bytes * 56 : interlaced : wall1 + maskwall1 + wall2 + maskwall2 (each are 1byte wide*56)
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &00, &01
	DEFB &00, &00, &00, &03, &00, &07, &00, &E2, &00, &1C, &00, &16, &03, &30, &E0, &0E
	DEFB &0F, &60, &F0, &06, &1C, &C0, &38, &02, &3B, &80, &9C, &00, &71, &00, &0E, &00
	DEFB &70, &00, &E6, &00, &E0, &00, &86, &00, &E0, &00, &72, &00, &CE, &00, &42, &08
	DEFB &CF, &00, &02, &30, &DC, &00, &0A, &C0, &90, &03, &2A, &00, &80, &0C, &42, &00
	DEFB &82, &30, &EA, &00, &8E, &00, &EA, &00, &B7, &00, &6A, &00, &BA, &00, &AA, &00
	DEFB &BC, &00, &D2, &00, &91, &00, &DA, &00, &AD, &00, &DA, &00, &9E, &00, &BA, &00
	DEFB &9C, &00, &0A, &00, &A4, &00, &CA, &C0, &B1, &01, &E2, &E0, &A1, &01, &EA, &E8
	DEFB &AD, &0D, &AC, &AC, &8E, &0E, &1C, &1C, &9E, &1E, &0C, &CC, &8C, &0D, &02, &60
	DEFB &A0, &01, &0C, &2C, &8C, &0C, &0E, &CE, &9E, &1E, &1C, &1C, &8E, &0E, &EA, &E8
	DEFB &85, &05, &E2, &E0, &A0, &00, &E2, &E0, &90, &00, &4A, &40, &BA, &00, &0A, &00
	DEFB &B3, &00, &6A, &00, &B6, &00, &C2, &00, &86, &00, &06, &30, &A8, &00, &06, &D0
	DEFB &A0, &03, &0C, &40, &80, &0D, &30, &00, &80, &34, &C0, &00, &83, &10, &00, &00
	DEFB &CC, &00, &00, &00, &F0, &00, &00, &00, &C0, &00, &00, &00, &00, &00, &00, &00
	;; displaying the images and masks as "wall1+wall2 mask1+mask2"
	;; so it is easier to see, we have the following results:
	;;
	;;	................ ................
	;;	................ ................
	;;	................ ...............@
	;;	................ ...............@
	;;	................ ..............@@
	;;	................ .....@@@@@@...@.
	;;	................ ...@@@.....@.@@.
	;;	......@@@@@..... ..@@........@@@.
	;;	....@@@@@@@@.... .@@..........@@.
	;;	...@@@....@@@... @@............@.
	;;	..@@@.@@@..@@@.. @...............
	;;	.@@@...@....@@@. ................
	;;	.@@@....@@@..@@. ................
	;;	@@@.....@....@@. ................
	;;	@@@......@@@..@. ................
	;;	@@..@@@..@....@. ............@...
	;;	@@..@@@@......@. ..........@@....
	;;	@@.@@@......@.@. ........@@......
	;;	@..@......@.@.@. ......@@........
	;;	@........@....@. ....@@..........
	;;	@.....@.@@@.@.@. ..@@............
	;;	@...@@@.@@@.@.@. ................
	;;	@.@@.@@@.@@.@.@. ................
	;;	@.@@@.@.@.@.@.@. ................
	;;	@.@@@@..@@.@..@. ................
	;;	@..@...@@@.@@.@. ................
	;;	@.@.@@.@@@.@@.@. ................
	;;	@..@@@@.@.@@@.@. ................
	;;	@..@@@......@.@. ................
	;;	@.@..@..@@..@.@. ........@@......
	;;	@.@@...@@@@...@. .......@@@@.....
	;;	@.@....@@@@.@.@. .......@@@@.@...
	;;	@.@.@@.@@.@.@@.. ....@@.@@.@.@@..
	;;	@...@@@....@@@.. ....@@@....@@@..
	;;	@..@@@@.....@@.. ...@@@@.@@..@@..
	;;	@...@@........@. ....@@.@.@@.....
	;;	@.@.........@@.. .......@..@.@@..
	;;	@...@@......@@@. ....@@..@@..@@@.
	;;	@..@@@@....@@@.. ...@@@@....@@@..
	;;	@...@@@.@@@.@.@. ....@@@.@@@.@...
	;;	@....@.@@@@...@. .....@.@@@@.....
	;;	@.@.....@@@...@. ........@@@.....
	;;	@..@.....@..@.@. .........@......
	;;	@.@@@.@.....@.@. ................
	;;	@.@@..@@.@@.@.@. ................
	;;	@.@@.@@.@@....@. ................
	;;	@....@@......@@. ..........@@....
	;;	@.@.@........@@. ........@@.@....
	;;	@.@.........@@.. ......@@.@......
	;;	@.........@@.... ....@@.@........
	;;	@.......@@...... ..@@.@..........
	;;	@.....@@........ ...@............
	;;	@@..@@.......... ................
	;;	@@@@............ ................
	;;	@@.............. ................
	;;	................ ................

img_wall_1:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &00, &01
	DEFB &00, &00, &00, &03, &00, &07, &00, &E2, &00, &1C, &00, &16, &03, &30, &E0, &0E
	DEFB &0F, &60, &F0, &06, &1E, &C0, &18, &02, &39, &80, &CC, &00, &70, &00, &86, &00
	DEFB &70, &00, &76, &00, &E5, &07, &42, &00, &E8, &0D, &32, &00, &C1, &03, &82, &88
	DEFB &C4, &0C, &02, &18, &C2, &16, &A2, &E0, &D5, &1D, &1A, &B8, &C1, &01, &B2, &F0
	DEFB &96, &1E, &02, &00, &A3, &37, &52, &70, &D6, &1E, &8C, &DC, &C0, &00, &58, &78
	DEFB &94, &1C, &02, &00, &A3, &37, &A8, &B8, &96, &1E, &46, &6E, &20, &20, &2C, &3C
	DEFB &47, &6F, &42, &40, &AC, &3C, &C4, &EC, &80, &00, &6A, &78, &AA, &00, &02, &00
	DEFB &BA, &00, &B2, &00, &96, &00, &A2, &00, &9A, &00, &B2, &00, &95, &00, &B2, &00
	DEFB &95, &00, &A2, &00, &95, &00, &62, &00, &97, &00, &D2, &00, &95, &00, &52, &00
	DEFB &AD, &00, &72, &00, &B5, &00, &52, &00, &95, &00, &F2, &00, &B7, &00, &6A, &00
	DEFB &AD, &00, &7A, &00, &AD, &00, &EC, &00, &AD, &00, &A6, &00, &AE, &00, &E2, &00
	DEFB &B6, &00, &78, &00, &97, &00, &0C, &00, &BB, &00, &C0, &00, &78, &00, &C0, &00
	DEFB &59, &00, &80, &00, &D8, &00, &00, &00, &30, &00, &00, &00, &C0, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ ...............@
	;;	................ ...............@
	;;	................ ..............@@
	;;	................ .....@@@@@@...@.
	;;	................ ...@@@.....@.@@.
	;;	......@@@@@..... ..@@........@@@.
	;;	....@@@@@@@@.... .@@..........@@.
	;;	...@@@@....@@... @@............@.
	;;	..@@@..@@@..@@.. @...............
	;;	.@@@....@....@@. ................
	;;	.@@@.....@@@.@@. ................
	;;	@@@..@.@.@....@. .....@@@........
	;;	@@@.@.....@@..@. ....@@.@........
	;;	@@.....@@.....@. ......@@@...@...
	;;	@@...@........@. ....@@.....@@...
	;;	@@....@.@.@...@. ...@.@@.@@@.....
	;;	@@.@.@.@...@@.@. ...@@@.@@.@@@...
	;;	@@.....@@.@@..@. .......@@@@@....
	;;	@..@.@@.......@. ...@@@@.........
	;;	@.@...@@.@.@..@. ..@@.@@@.@@@....
	;;	@@.@.@@.@...@@.. ...@@@@.@@.@@@..
	;;	@@.......@.@@... .........@@@@...
	;;	@..@.@........@. ...@@@..........
	;;	@.@...@@@.@.@... ..@@.@@@@.@@@...
	;;	@..@.@@..@...@@. ...@@@@..@@.@@@.
	;;	..@.......@.@@.. ..@.......@@@@..
	;;	.@...@@@.@....@. .@@.@@@@.@......
	;;	@.@.@@..@@...@.. ..@@@@..@@@.@@..
	;;	@........@@.@.@. .........@@@@...
	;;	@.@.@.@.......@. ................
	;;	@.@@@.@.@.@@..@. ................
	;;	@..@.@@.@.@...@. ................
	;;	@..@@.@.@.@@..@. ................
	;;	@..@.@.@@.@@..@. ................
	;;	@..@.@.@@.@...@. ................
	;;	@..@.@.@.@@...@. ................
	;;	@..@.@@@@@.@..@. ................
	;;	@..@.@.@.@.@..@. ................
	;;	@.@.@@.@.@@@..@. ................
	;;	@.@@.@.@.@.@..@. ................
	;;	@..@.@.@@@@@..@. ................
	;;	@.@@.@@@.@@.@.@. ................
	;;	@.@.@@.@.@@@@.@. ................
	;;	@.@.@@.@@@@.@@.. ................
	;;	@.@.@@.@@.@..@@. ................
	;;	@.@.@@@.@@@...@. ................
	;;	@.@@.@@..@@@@... ................
	;;	@..@.@@@....@@.. ................
	;;	@.@@@.@@@@...... ................
	;;	.@@@@...@@...... ................
	;;	.@.@@..@@....... ................
	;;	@@.@@........... ................
	;;	..@@............ ................
	;;	@@.............. ................

img_wall_2:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &00, &01
	DEFB &00, &00, &00, &03, &00, &07, &00, &E2, &00, &1C, &00, &16, &03, &30, &E0, &0E
	DEFB &0F, &60, &F0, &06, &1C, &C0, &18, &02, &38, &80, &0C, &00, &73, &03, &C6, &C0
	DEFB &64, &04, &26, &20, &E8, &08, &12, &10, &C8, &0B, &12, &10, &D0, &10, &0A, &08
	DEFB &D0, &12, &0A, &08, &90, &10, &0A, &08, &90, &10, &0A, &08, &88, &08, &12, &10
	DEFB &88, &08, &12, &10, &84, &04, &22, &20, &83, &03, &C2, &C0, &80, &00, &02, &00
	DEFB &80, &00, &02, &00, &80, &00, &02, &00, &80, &00, &02, &00, &80, &00, &02, &00
	DEFB &80, &00, &02, &00, &80, &00, &02, &00, &80, &00, &02, &00, &80, &00, &02, &00
	DEFB &87, &00, &C2, &00, &9F, &07, &F2, &C0, &9F, &0F, &F2, &E0, &BF, &1F, &3A, &30
	DEFB &BF, &1F, &3A, &30, &B1, &1F, &FA, &F0, &A0, &11, &EA, &F0, &A0, &00, &0A, &E0
	DEFB &A6, &06, &0A, &00, &A6, &06, &2A, &20, &90, &00, &4A, &40, &90, &00, &12, &00
	DEFB &8C, &00, &22, &00, &83, &00, &C2, &00, &80, &00, &02, &00, &80, &00, &02, &00
	DEFB &80, &00, &0C, &00, &80, &00, &30, &00, &80, &00, &C0, &00, &83, &00, &00, &00
	DEFB &8C, &00, &00, &00, &B0, &00, &00, &00, &C0, &00, &00, &00, &00, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ ...............@
	;;	................ ...............@
	;;	................ ..............@@
	;;	................ .....@@@@@@...@.
	;;	................ ...@@@.....@.@@.
	;;	......@@@@@..... ..@@........@@@.
	;;	....@@@@@@@@.... .@@..........@@.
	;;	...@@@.....@@... @@............@.
	;;	..@@@.......@@.. @...............
	;;	.@@@..@@@@...@@. ......@@@@......
	;;	.@@..@....@..@@. .....@....@.....
	;;	@@@.@......@..@. ....@......@....
	;;	@@..@......@..@. ....@.@@...@....
	;;	@@.@........@.@. ...@........@...
	;;	@@.@........@.@. ...@..@.....@...
	;;	@..@........@.@. ...@........@...
	;;	@..@........@.@. ...@........@...
	;;	@...@......@..@. ....@......@....
	;;	@...@......@..@. ....@......@....
	;;	@....@....@...@. .....@....@.....
	;;	@.....@@@@....@. ......@@@@......
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@....@@@@@....@. ................
	;;	@..@@@@@@@@@..@. .....@@@@@......
	;;	@..@@@@@@@@@..@. ....@@@@@@@.....
	;;	@.@@@@@@..@@@.@. ...@@@@@..@@....
	;;	@.@@@@@@..@@@.@. ...@@@@@..@@....
	;;	@.@@...@@@@@@.@. ...@@@@@@@@@....
	;;	@.@.....@@@.@.@. ...@...@@@@@....
	;;	@.@.........@.@. ........@@@.....
	;;	@.@..@@.....@.@. .....@@.........
	;;	@.@..@@...@.@.@. .....@@...@.....
	;;	@..@.....@..@.@. .........@......
	;;	@..@.......@..@. ................
	;;	@...@@....@...@. ................
	;;	@.....@@@@....@. ................
	;;	@.............@. ................
	;;	@.............@. ................
	;;	@...........@@.. ................
	;;	@.........@@.... ................
	;;	@.......@@...... ................
	;;	@.....@@........ ................
	;;	@...@@.......... ................
	;;	@.@@............ ................
	;;	@@.............. ................
	;;	................ ................

img_wall_3:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &00, &01
	DEFB &00, &00, &00, &03, &00, &07, &00, &E2, &00, &1C, &00, &16, &03, &30, &E0, &0E
	DEFB &0F, &60, &F0, &06, &1C, &C0, &38, &02, &3B, &80, &9C, &00, &71, &00, &0E, &00
	DEFB &70, &00, &E6, &00, &E0, &00, &86, &00, &E0, &00, &72, &00, &CE, &00, &42, &00
	DEFB &CF, &00, &02, &00, &D8, &00, &F2, &F0, &91, &01, &0C, &0C, &B2, &02, &04, &24
	DEFB &B2, &02, &06, &16, &A3, &03, &06, &06, &A1, &01, &DC, &DC, &A2, &00, &72, &70
	DEFB &A3, &00, &8C, &00, &A5, &00, &72, &00, &A4, &02, &06, &00, &A8, &03, &5C, &40
	DEFB &A8, &00, &52, &40, &A8, &04, &06, &00, &90, &02, &BC, &80, &90, &00, &AA, &80
	DEFB &A0, &08, &04, &00, &A1, &05, &3C, &00, &A1, &01, &7A, &00, &40, &18, &04, &00
	DEFB &41, &05, &7C, &00, &41, &01, &52, &00, &80, &30, &0A, &00, &82, &0A, &FA, &00
	DEFB &42, &02, &B2, &00, &80, &30, &0A, &00, &82, &02, &FA, &00, &42, &02, &B2, &00
	DEFB &80, &30, &0A, &00, &82, &02, &FA, &00, &42, &02, &A8, &00, &80, &30, &18, &00
	DEFB &82, &02, &F0, &00, &42, &02, &A8, &00, &80, &30, &18, &00, &82, &02, &F0, &00
	DEFB &60, &08, &60, &00, &BF, &00, &80, &00, &C0, &00, &00, &00, &00, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ ...............@
	;;	................ ...............@
	;;	................ ..............@@
	;;	................ .....@@@@@@...@.
	;;	................ ...@@@.....@.@@.
	;;	......@@@@@..... ..@@........@@@.
	;;	....@@@@@@@@.... .@@..........@@.
	;;	...@@@....@@@... @@............@.
	;;	..@@@.@@@..@@@.. @...............
	;;	.@@@...@....@@@. ................
	;;	.@@@....@@@..@@. ................
	;;	@@@.....@....@@. ................
	;;	@@@......@@@..@. ................
	;;	@@..@@@..@....@. ................
	;;	@@..@@@@......@. ................
	;;	@@.@@...@@@@..@. ........@@@@....
	;;	@..@...@....@@.. .......@....@@..
	;;	@.@@..@......@.. ......@...@..@..
	;;	@.@@..@......@@. ......@....@.@@.
	;;	@.@...@@.....@@. ......@@.....@@.
	;;	@.@....@@@.@@@.. .......@@@.@@@..
	;;	@.@...@..@@@..@. .........@@@....
	;;	@.@...@@@...@@.. ................
	;;	@.@..@.@.@@@..@. ................
	;;	@.@..@.......@@. ......@.........
	;;	@.@.@....@.@@@.. ......@@.@......
	;;	@.@.@....@.@..@. .........@......
	;;	@.@.@........@@. .....@..........
	;;	@..@....@.@@@@.. ......@.@.......
	;;	@..@....@.@.@.@. ........@.......
	;;	@.@..........@.. ....@...........
	;;	@.@....@..@@@@.. .....@.@........
	;;	@.@....@.@@@@.@. .......@........
	;;	.@...........@.. ...@@...........
	;;	.@.....@.@@@@@.. .....@.@........
	;;	.@.....@.@.@..@. .......@........
	;;	@...........@.@. ..@@............
	;;	@.....@.@@@@@.@. ....@.@.........
	;;	.@....@.@.@@..@. ......@.........
	;;	@...........@.@. ..@@............
	;;	@.....@.@@@@@.@. ......@.........
	;;	.@....@.@.@@..@. ......@.........
	;;	@...........@.@. ..@@............
	;;	@.....@.@@@@@.@. ......@.........
	;;	.@....@.@.@.@... ......@.........
	;;	@..........@@... ..@@............
	;;	@.....@.@@@@.... ......@.........
	;;	.@....@.@.@.@... ......@.........
	;;	@..........@@... ..@@............
	;;	@.....@.@@@@.... ......@.........
	;;	.@@......@@..... ....@...........
	;;	@.@@@@@@@....... ................
	;;	@@.............. ................
	;;	................ ................

img_wall_4:
	DEFB &00, &00, &01, &00, &00, &00, &1D, &00, &00, &00, &7E, &00, &01, &00, &E2, &00
	DEFB &07, &00, &8C, &0C, &1E, &00, &66, &06, &79, &00, &9C, &1C, &E6, &00, &72, &70
	DEFB &99, &01, &C4, &C0, &67, &07, &12, &00, &9C, &1C, &4C, &00, &B1, &30, &32, &00
	DEFB &B4, &30, &CC, &00, &B3, &30, &32, &00, &B4, &30, &C8, &08, &B3, &30, &2A, &28
	DEFB &B4, &30, &B8, &38, &B3, &30, &22, &20, &B4, &30, &80, &18, &B3, &30, &02, &20
	DEFB &B4, &30, &80, &38, &B3, &30, &02, &08, &B4, &30, &80, &30, &B3, &30, &0A, &08
	DEFB &B4, &30, &B8, &38, &B3, &30, &12, &10, &B4, &30, &CC, &00, &B3, &30, &32, &00
	DEFB &B4, &30, &C4, &00, &B3, &30, &02, &18, &B4, &30, &00, &68, &B0, &31, &02, &A8
	DEFB &B0, &36, &00, &A8, &B0, &32, &02, &A8, &B0, &32, &00, &A8, &B0, &32, &02, &A8
	DEFB &B0, &32, &04, &A0, &B0, &32, &12, &80, &B0, &36, &4C, &00, &B1, &30, &32, &00
	DEFB &B4, &30, &CC, &0C, &B3, &30, &26, &06, &B4, &30, &9C, &1C, &B2, &30, &72, &70
	DEFB &B1, &31, &C4, &C0, &B7, &37, &12, &00, &BC, &3C, &4C, &00, &89, &08, &33, &00
	DEFB &C4, &00, &CE, &00, &B3, &00, &38, &00, &CC, &00, &E0, &00, &B3, &00, &80, &00
	DEFB &CE, &00, &00, &00, &38, &00, &00, &00, &E0, &00, &00, &00, &00, &00, &00, &00
	;;	...............@ ................
	;;	...........@@@.@ ................
	;;	.........@@@@@@. ................
	;;	.......@@@@...@. ................
	;;	.....@@@@...@@.. ............@@..
	;;	...@@@@..@@..@@. .............@@.
	;;	.@@@@..@@..@@@.. ...........@@@..
	;;	@@@..@@..@@@..@. .........@@@....
	;;	@..@@..@@@...@.. .......@@@......
	;;	.@@..@@@...@..@. .....@@@........
	;;	@..@@@...@..@@.. ...@@@..........
	;;	@.@@...@..@@..@. ..@@............
	;;	@.@@.@..@@..@@.. ..@@............
	;;	@.@@..@@..@@..@. ..@@............
	;;	@.@@.@..@@..@... ..@@........@...
	;;	@.@@..@@..@.@.@. ..@@......@.@...
	;;	@.@@.@..@.@@@... ..@@......@@@...
	;;	@.@@..@@..@...@. ..@@......@.....
	;;	@.@@.@..@....... ..@@.......@@...
	;;	@.@@..@@......@. ..@@......@.....
	;;	@.@@.@..@....... ..@@......@@@...
	;;	@.@@..@@......@. ..@@........@...
	;;	@.@@.@..@....... ..@@......@@....
	;;	@.@@..@@....@.@. ..@@........@...
	;;	@.@@.@..@.@@@... ..@@......@@@...
	;;	@.@@..@@...@..@. ..@@.......@....
	;;	@.@@.@..@@..@@.. ..@@............
	;;	@.@@..@@..@@..@. ..@@............
	;;	@.@@.@..@@...@.. ..@@............
	;;	@.@@..@@......@. ..@@.......@@...
	;;	@.@@.@.......... ..@@.....@@.@...
	;;	@.@@..........@. ..@@...@@.@.@...
	;;	@.@@............ ..@@.@@.@.@.@...
	;;	@.@@..........@. ..@@..@.@.@.@...
	;;	@.@@............ ..@@..@.@.@.@...
	;;	@.@@..........@. ..@@..@.@.@.@...
	;;	@.@@.........@.. ..@@..@.@.@.....
	;;	@.@@.......@..@. ..@@..@.@.......
	;;	@.@@.....@..@@.. ..@@.@@.........
	;;	@.@@...@..@@..@. ..@@............
	;;	@.@@.@..@@..@@.. ..@@........@@..
	;;	@.@@..@@..@..@@. ..@@.........@@.
	;;	@.@@.@..@..@@@.. ..@@.......@@@..
	;;	@.@@..@..@@@..@. ..@@.....@@@....
	;;	@.@@...@@@...@.. ..@@...@@@......
	;;	@.@@.@@@...@..@. ..@@.@@@........
	;;	@.@@@@...@..@@.. ..@@@@..........
	;;	@...@..@..@@..@@ ....@...........
	;;	@@...@..@@..@@@. ................
	;;	@.@@..@@..@@@... ................
	;;	@@..@@..@@@..... ................
	;;	@.@@..@@@....... ................
	;;	@@..@@@......... ................
	;;	..@@@........... ................
	;;	@@@............. ................
	;;	................ ................

img_wall_5:
	DEFB &00, &00, &01, &00, &00, &00, &1D, &00, &00, &00, &7E, &00, &01, &00, &E2, &00
	DEFB &07, &00, &8C, &0C, &1E, &00, &66, &06, &79, &00, &9C, &1C, &E6, &00, &7A, &78
	DEFB &99, &01, &E4, &E0, &67, &67, &92, &80, &7E, &7E, &4C, &00, &39, &38, &32, &00
	DEFB &84, &00, &CC, &00, &B3, &00, &32, &00, &CC, &00, &C4, &00, &B3, &00, &02, &10
	DEFB &CC, &00, &44, &40, &91, &10, &12, &00, &38, &38, &04, &40, &15, &55, &12, &10
	DEFB &0C, &2C, &44, &00, &0C, &4D, &02, &10, &08, &28, &44, &40, &0D, &4C, &12, &00
	DEFB &08, &28, &04, &44, &0D, &4D, &02, &1C, &08, &28, &00, &74, &0C, &4D, &02, &D4
	DEFB &0C, &2D, &00, &54, &0C, &4D, &02, &54, &0C, &2D, &00, &54, &0C, &4D, &02, &54
	DEFB &08, &29, &00, &54, &82, &01, &02, &54, &A4, &21, &00, &54, &B2, &31, &02, &54
	DEFB &B4, &31, &00, &5C, &B2, &31, &02, &70, &B4, &31, &0C, &C0, &B3, &31, &32, &00
	DEFB &B4, &30, &CC, &0C, &B3, &30, &26, &06, &B4, &30, &9C, &1C, &B2, &30, &72, &70
	DEFB &B1, &31, &C4, &C0, &B7, &37, &12, &00, &BC, &3C, &4C, &00, &89, &08, &33, &00
	DEFB &C4, &00, &CE, &00, &B3, &00, &38, &00, &CC, &00, &E0, &00, &B3, &00, &80, &00
	DEFB &CE, &00, &00, &00, &38, &00, &00, &00, &E0, &00, &00, &00, &00, &00, &00, &00
	;;	...............@ ................
	;;	...........@@@.@ ................
	;;	.........@@@@@@. ................
	;;	.......@@@@...@. ................
	;;	.....@@@@...@@.. ............@@..
	;;	...@@@@..@@..@@. .............@@.
	;;	.@@@@..@@..@@@.. ...........@@@..
	;;	@@@..@@..@@@@.@. .........@@@@...
	;;	@..@@..@@@@..@.. .......@@@@.....
	;;	.@@..@@@@..@..@. .@@..@@@@.......
	;;	.@@@@@@..@..@@.. .@@@@@@.........
	;;	..@@@..@..@@..@. ..@@@...........
	;;	@....@..@@..@@.. ................
	;;	@.@@..@@..@@..@. ................
	;;	@@..@@..@@...@.. ................
	;;	@.@@..@@......@. ...........@....
	;;	@@..@@...@...@.. .........@......
	;;	@..@...@...@..@. ...@............
	;;	..@@@........@.. ..@@@....@......
	;;	...@.@.@...@..@. .@.@.@.@...@....
	;;	....@@...@...@.. ..@.@@..........
	;;	....@@........@. .@..@@.@...@....
	;;	....@....@...@.. ..@.@....@......
	;;	....@@.@...@..@. .@..@@..........
	;;	....@........@.. ..@.@....@...@..
	;;	....@@.@......@. .@..@@.@...@@@..
	;;	....@........... ..@.@....@@@.@..
	;;	....@@........@. .@..@@.@@@.@.@..
	;;	....@@.......... ..@.@@.@.@.@.@..
	;;	....@@........@. .@..@@.@.@.@.@..
	;;	....@@.......... ..@.@@.@.@.@.@..
	;;	....@@........@. .@..@@.@.@.@.@..
	;;	....@........... ..@.@..@.@.@.@..
	;;	@.....@.......@. .......@.@.@.@..
	;;	@.@..@.......... ..@....@.@.@.@..
	;;	@.@@..@.......@. ..@@...@.@.@.@..
	;;	@.@@.@.......... ..@@...@.@.@@@..
	;;	@.@@..@.......@. ..@@...@.@@@....
	;;	@.@@.@......@@.. ..@@...@@@......
	;;	@.@@..@@..@@..@. ..@@...@........
	;;	@.@@.@..@@..@@.. ..@@........@@..
	;;	@.@@..@@..@..@@. ..@@.........@@.
	;;	@.@@.@..@..@@@.. ..@@.......@@@..
	;;	@.@@..@..@@@..@. ..@@.....@@@....
	;;	@.@@...@@@...@.. ..@@...@@@......
	;;	@.@@.@@@...@..@. ..@@.@@@........
	;;	@.@@@@...@..@@.. ..@@@@..........
	;;	@...@..@..@@..@@ ....@...........
	;;	@@...@..@@..@@@. ................
	;;	@.@@..@@..@@@... ................
	;;	@@..@@..@@@..... ................
	;;	@.@@..@@@....... ................
	;;	@@..@@@......... ................
	;;	..@@@........... ................
	;;	@@@............. ................
	;;	................ ................

img_wall_6:
	DEFB &00, &00, &01, &00, &00, &00, &1D, &00, &00, &00, &7E, &00, &01, &00, &E2, &00
	DEFB &07, &00, &9C, &00, &1E, &00, &60, &03, &79, &00, &80, &0D, &E6, &00, &00, &75
	DEFB &99, &01, &80, &95, &67, &67, &C0, &D5, &7E, &7E, &C0, &D5, &38, &38, &C0, &D4
	DEFB &C4, &00, &C0, &D0, &92, &00, &C2, &C0, &CC, &00, &CC, &C0, &B2, &00, &D2, &C0
	DEFB &CC, &00, &C4, &C0, &B2, &00, &DA, &D8, &CC, &00, &20, &20, &B3, &03, &8A, &88
	DEFB &CE, &0E, &28, &28, &A0, &00, &B2, &B0, &C2, &0A, &C8, &C8, &A3, &0B, &2A, &28
	DEFB &C0, &08, &B0, &B0, &A2, &0A, &CA, &C8, &C3, &0B, &28, &28, &A0, &08, &AA, &A8
	DEFB &C2, &0A, &A4, &A0, &A2, &0A, &82, &80, &C2, &0A, &0C, &00, &B0, &00, &52, &40
	DEFB &CC, &00, &CC, &C0, &B2, &00, &D2, &C0, &CC, &00, &CC, &C0, &B2, &00, &D2, &C0
	DEFB &CC, &00, &CC, &C0, &91, &01, &B2, &80, &67, &67, &4C, &00, &7C, &7C, &32, &00
	DEFB &30, &30, &CC, &0C, &83, &00, &26, &06, &CC, &00, &9C, &1C, &B2, &00, &72, &70
	DEFB &89, &01, &C4, &C0, &67, &67, &12, &00, &7C, &7C, &4C, &00, &11, &10, &33, &00
	DEFB &84, &00, &CE, &00, &B3, &00, &38, &00, &CC, &00, &E0, &00, &B3, &00, &80, &00
	DEFB &CE, &00, &00, &00, &38, &00, &00, &00, &E0, &00, &00, &00, &00, &00, &00, &00
	;;	...............@ ................
	;;	...........@@@.@ ................
	;;	.........@@@@@@. ................
	;;	.......@@@@...@. ................
	;;	.....@@@@..@@@.. ................
	;;	...@@@@..@@..... ..............@@
	;;	.@@@@..@@....... ............@@.@
	;;	@@@..@@......... .........@@@.@.@
	;;	@..@@..@@....... .......@@..@.@.@
	;;	.@@..@@@@@...... .@@..@@@@@.@.@.@
	;;	.@@@@@@.@@...... .@@@@@@.@@.@.@.@
	;;	..@@@...@@...... ..@@@...@@.@.@..
	;;	@@...@..@@...... ........@@.@....
	;;	@..@..@.@@....@. ........@@......
	;;	@@..@@..@@..@@.. ........@@......
	;;	@.@@..@.@@.@..@. ........@@......
	;;	@@..@@..@@...@.. ........@@......
	;;	@.@@..@.@@.@@.@. ........@@.@@...
	;;	@@..@@....@..... ..........@.....
	;;	@.@@..@@@...@.@. ......@@@...@...
	;;	@@..@@@...@.@... ....@@@...@.@...
	;;	@.@.....@.@@..@. ........@.@@....
	;;	@@....@.@@..@... ....@.@.@@..@...
	;;	@.@...@@..@.@.@. ....@.@@..@.@...
	;;	@@......@.@@.... ....@...@.@@....
	;;	@.@...@.@@..@.@. ....@.@.@@..@...
	;;	@@....@@..@.@... ....@.@@..@.@...
	;;	@.@.....@.@.@.@. ....@...@.@.@...
	;;	@@....@.@.@..@.. ....@.@.@.@.....
	;;	@.@...@.@.....@. ....@.@.@.......
	;;	@@....@.....@@.. ....@.@.........
	;;	@.@@.....@.@..@. .........@......
	;;	@@..@@..@@..@@.. ........@@......
	;;	@.@@..@.@@.@..@. ........@@......
	;;	@@..@@..@@..@@.. ........@@......
	;;	@.@@..@.@@.@..@. ........@@......
	;;	@@..@@..@@..@@.. ........@@......
	;;	@..@...@@.@@..@. .......@@.......
	;;	.@@..@@@.@..@@.. .@@..@@@........
	;;	.@@@@@....@@..@. .@@@@@..........
	;;	..@@....@@..@@.. ..@@........@@..
	;;	@.....@@..@..@@. .............@@.
	;;	@@..@@..@..@@@.. ...........@@@..
	;;	@.@@..@..@@@..@. .........@@@....
	;;	@...@..@@@...@.. .......@@@......
	;;	.@@..@@@...@..@. .@@..@@@........
	;;	.@@@@@...@..@@.. .@@@@@..........
	;;	...@...@..@@..@@ ...@............
	;;	@....@..@@..@@@. ................
	;;	@.@@..@@..@@@... ................
	;;	@@..@@..@@@..... ................
	;;	@.@@..@@@....... ................
	;;	@@..@@@......... ................
	;;	..@@@........... ................
	;;	@@@............. ................
	;;	................ ................

img_wall_7:
	DEFB &00, &00, &01, &00, &00, &00, &1D, &00, &00, &00, &7E, &00, &01, &00, &E2, &00
	DEFB &07, &00, &9C, &00, &1E, &00, &62, &00, &79, &00, &9C, &00, &E6, &00, &62, &60
	DEFB &99, &01, &F4, &F0, &67, &67, &B2, &B0, &7E, &7E, &34, &30, &38, &38, &B2, &30
	DEFB &83, &00, &34, &30, &4C, &00, &B2, &30, &33, &00, &34, &30, &4C, &00, &B2, &30
	DEFB &33, &00, &34, &30, &4C, &00, &B2, &30, &33, &00, &34, &30, &CC, &00, &B2, &30
	DEFB &B1, &00, &34, &30, &C0, &04, &B2, &30, &81, &28, &34, &30, &80, &14, &B2, &30
	DEFB &81, &28, &34, &30, &80, &14, &B2, &30, &81, &28, &34, &30, &80, &14, &B2, &30
	DEFB &81, &28, &34, &30, &80, &14, &B2, &30, &81, &28, &34, &30, &80, &14, &B2, &30
	DEFB &81, &28, &34, &30, &80, &14, &B2, &30, &83, &20, &34, &30, &8C, &00, &B2, &30
	DEFB &B3, &00, &34, &30, &CC, &00, &B2, &30, &B3, &00, &34, &30, &CC, &00, &B2, &30
	DEFB &B3, &00, &34, &30, &CC, &00, &B2, &30, &B3, &00, &34, &30, &CC, &00, &62, &60
	DEFB &91, &01, &CC, &C0, &67, &67, &12, &00, &7C, &7C, &4C, &00, &11, &10, &33, &00
	DEFB &84, &00, &CE, &00, &B3, &00, &38, &00, &CC, &00, &E0, &00, &B3, &00, &80, &00
	DEFB &CE, &00, &00, &00, &38, &00, &00, &00, &E0, &00, &00, &00, &00, &00, &00, &00
	;;	...............@ ................
	;;	...........@@@.@ ................
	;;	.........@@@@@@. ................
	;;	.......@@@@...@. ................
	;;	.....@@@@..@@@.. ................
	;;	...@@@@..@@...@. ................
	;;	.@@@@..@@..@@@.. ................
	;;	@@@..@@..@@...@. .........@@.....
	;;	@..@@..@@@@@.@.. .......@@@@@....
	;;	.@@..@@@@.@@..@. .@@..@@@@.@@....
	;;	.@@@@@@...@@.@.. .@@@@@@...@@....
	;;	..@@@...@.@@..@. ..@@@.....@@....
	;;	@.....@@..@@.@.. ..........@@....
	;;	.@..@@..@.@@..@. ..........@@....
	;;	..@@..@@..@@.@.. ..........@@....
	;;	.@..@@..@.@@..@. ..........@@....
	;;	..@@..@@..@@.@.. ..........@@....
	;;	.@..@@..@.@@..@. ..........@@....
	;;	..@@..@@..@@.@.. ..........@@....
	;;	@@..@@..@.@@..@. ..........@@....
	;;	@.@@...@..@@.@.. ..........@@....
	;;	@@......@.@@..@. .....@....@@....
	;;	@......@..@@.@.. ..@.@.....@@....
	;;	@.......@.@@..@. ...@.@....@@....
	;;	@......@..@@.@.. ..@.@.....@@....
	;;	@.......@.@@..@. ...@.@....@@....
	;;	@......@..@@.@.. ..@.@.....@@....
	;;	@.......@.@@..@. ...@.@....@@....
	;;	@......@..@@.@.. ..@.@.....@@....
	;;	@.......@.@@..@. ...@.@....@@....
	;;	@......@..@@.@.. ..@.@.....@@....
	;;	@.......@.@@..@. ...@.@....@@....
	;;	@......@..@@.@.. ..@.@.....@@....
	;;	@.......@.@@..@. ...@.@....@@....
	;;	@.....@@..@@.@.. ..@.......@@....
	;;	@...@@..@.@@..@. ..........@@....
	;;	@.@@..@@..@@.@.. ..........@@....
	;;	@@..@@..@.@@..@. ..........@@....
	;;	@.@@..@@..@@.@.. ..........@@....
	;;	@@..@@..@.@@..@. ..........@@....
	;;	@.@@..@@..@@.@.. ..........@@....
	;;	@@..@@..@.@@..@. ..........@@....
	;;	@.@@..@@..@@.@.. ..........@@....
	;;	@@..@@...@@...@. .........@@.....
	;;	@..@...@@@..@@.. .......@@@......
	;;	.@@..@@@...@..@. .@@..@@@........
	;;	.@@@@@...@..@@.. .@@@@@..........
	;;	...@...@..@@..@@ ...@............
	;;	@....@..@@..@@@. ................
	;;	@.@@..@@..@@@... ................
	;;	@@..@@..@@@..... ................
	;;	@.@@..@@@....... ................
	;;	@@..@@@......... ................
	;;	..@@@........... ................
	;;	@@@............. ................
	;;	................ ................

img_wall_8:
	DEFB &00, &00, &00, &00, &00, &00, &00, &05, &00, &00, &00, &16, &00, &00, &01, &58
	DEFB &00, &01, &00, &60, &00, &05, &1C, &80, &00, &16, &7A, &00, &01, &58, &7E, &00
	DEFB &04, &60, &BE, &00, &1C, &80, &DE, &00, &7A, &00, &FE, &00, &7E, &00, &FE, &00
	DEFB &BE, &00, &FE, &00, &DE, &00, &FE, &00, &FE, &00, &F6, &00, &FE, &00, &FA, &00
	DEFB &FE, &00, &FC, &00, &FE, &00, &B9, &00, &F6, &00, &A0, &00, &F8, &00, &1C, &00
	DEFB &FC, &00, &7A, &00, &B9, &00, &7E, &00, &80, &00, &BE, &00, &1C, &00, &DE, &00
	DEFB &7A, &00, &FE, &00, &7E, &00, &FE, &00, &BE, &00, &FE, &00, &DE, &00, &F6, &00
	DEFB &FE, &00, &FA, &00, &FE, &00, &FC, &00, &FE, &00, &B9, &00, &F6, &00, &A0, &00
	DEFB &FA, &00, &1C, &00, &FC, &00, &7A, &00, &B9, &00, &7E, &00, &A0, &00, &BE, &00
	DEFB &1C, &00, &DE, &00, &7A, &00, &FE, &00, &7E, &00, &FE, &00, &BE, &00, &FE, &00
	DEFB &DE, &00, &F6, &00, &FE, &00, &FA, &00, &FE, &00, &FC, &00, &FE, &00, &B9, &00
	DEFB &F6, &00, &A0, &01, &FA, &00, &00, &06, &FC, &00, &00, &1A, &B9, &00, &01, &68
	DEFB &A0, &01, &06, &A0, &00, &06, &18, &80, &00, &1A, &60, &00, &01, &68, &80, &00
	DEFB &06, &A0, &00, &00, &18, &80, &00, &00, &60, &00, &00, &00, &00, &00, &00, &00
	;;	................ ................
	;;	................ .............@.@
	;;	................ ...........@.@@.
	;;	...............@ .........@.@@...
	;;	................ .......@.@@.....
	;;	...........@@@.. .....@.@@.......
	;;	.........@@@@.@. ...@.@@.........
	;;	.......@.@@@@@@. .@.@@...........
	;;	.....@..@.@@@@@. .@@.............
	;;	...@@@..@@.@@@@. @...............
	;;	.@@@@.@.@@@@@@@. ................
	;;	.@@@@@@.@@@@@@@. ................
	;;	@.@@@@@.@@@@@@@. ................
	;;	@@.@@@@.@@@@@@@. ................
	;;	@@@@@@@.@@@@.@@. ................
	;;	@@@@@@@.@@@@@.@. ................
	;;	@@@@@@@.@@@@@@.. ................
	;;	@@@@@@@.@.@@@..@ ................
	;;	@@@@.@@.@.@..... ................
	;;	@@@@@......@@@.. ................
	;;	@@@@@@...@@@@.@. ................
	;;	@.@@@..@.@@@@@@. ................
	;;	@.......@.@@@@@. ................
	;;	...@@@..@@.@@@@. ................
	;;	.@@@@.@.@@@@@@@. ................
	;;	.@@@@@@.@@@@@@@. ................
	;;	@.@@@@@.@@@@@@@. ................
	;;	@@.@@@@.@@@@.@@. ................
	;;	@@@@@@@.@@@@@.@. ................
	;;	@@@@@@@.@@@@@@.. ................
	;;	@@@@@@@.@.@@@..@ ................
	;;	@@@@.@@.@.@..... ................
	;;	@@@@@.@....@@@.. ................
	;;	@@@@@@...@@@@.@. ................
	;;	@.@@@..@.@@@@@@. ................
	;;	@.@.....@.@@@@@. ................
	;;	...@@@..@@.@@@@. ................
	;;	.@@@@.@.@@@@@@@. ................
	;;	.@@@@@@.@@@@@@@. ................
	;;	@.@@@@@.@@@@@@@. ................
	;;	@@.@@@@.@@@@.@@. ................
	;;	@@@@@@@.@@@@@.@. ................
	;;	@@@@@@@.@@@@@@.. ................
	;;	@@@@@@@.@.@@@..@ ................
	;;	@@@@.@@.@.@..... ...............@
	;;	@@@@@.@......... .............@@.
	;;	@@@@@@.......... ...........@@.@.
	;;	@.@@@..@.......@ .........@@.@...
	;;	@.@..........@@. .......@@.@.....
	;;	...........@@... .....@@.@.......
	;;	.........@@..... ...@@.@.........
	;;	.......@@....... .@@.@...........
	;;	.....@@......... @.@.............
	;;	...@@........... @...............
	;;	.@@............. ................
	;;	................ ................

img_wall_9:
	DEFB &00, &00, &00, &00, &00, &00, &00, &05, &00, &00, &00, &16, &00, &00, &01, &58
	DEFB &00, &01, &00, &60, &00, &05, &1C, &80, &00, &16, &7A, &00, &01, &58, &7E, &00
	DEFB &04, &60, &BE, &00, &1C, &80, &DE, &00, &7A, &00, &FE, &00, &7E, &00, &FE, &00
	DEFB &BE, &00, &FE, &00, &DE, &00, &FE, &00, &FE, &00, &F6, &00, &FE, &00, &FA, &00
	DEFB &FE, &00, &FC, &00, &FE, &00, &B9, &00, &F6, &00, &A0, &00, &F8, &00, &1C, &00
	DEFB &FD, &00, &06, &20, &B8, &00, &02, &F8, &80, &03, &00, &FC, &00, &0F, &00, &0E
	DEFB &40, &1C, &40, &06, &02, &38, &08, &03, &00, &30, &20, &03, &00, &60, &04, &01
	DEFB &00, &60, &00, &01, &01, &C0, &24, &01, &00, &C0, &00, &01, &00, &80, &04, &01
	DEFB &00, &80, &20, &01, &39, &B8, &04, &01, &30, &B0, &00, &01, &00, &88, &24, &01
	DEFB &00, &B0, &00, &01, &0F, &8F, &04, &01, &3E, &BE, &20, &01, &38, &B9, &04, &01
	DEFB &20, &A6, &00, &01, &01, &99, &E4, &E1, &07, &A7, &C0, &C1, &1F, &9F, &04, &21
	DEFB &3C, &BC, &00, &C1, &30, &B3, &3C, &3D, &00, &8C, &F8, &F9, &03, &B3, &E1, &E4
	DEFB &0F, &8F, &86, &90, &3E, &BE, &18, &40, &38, &B9, &60, &00, &01, &A4, &80, &00
	DEFB &06, &90, &00, &00, &18, &80, &00, &00, &60, &80, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ .............@.@
	;;	................ ...........@.@@.
	;;	...............@ .........@.@@...
	;;	................ .......@.@@.....
	;;	...........@@@.. .....@.@@.......
	;;	.........@@@@.@. ...@.@@.........
	;;	.......@.@@@@@@. .@.@@...........
	;;	.....@..@.@@@@@. .@@.............
	;;	...@@@..@@.@@@@. @...............
	;;	.@@@@.@.@@@@@@@. ................
	;;	.@@@@@@.@@@@@@@. ................
	;;	@.@@@@@.@@@@@@@. ................
	;;	@@.@@@@.@@@@@@@. ................
	;;	@@@@@@@.@@@@.@@. ................
	;;	@@@@@@@.@@@@@.@. ................
	;;	@@@@@@@.@@@@@@.. ................
	;;	@@@@@@@.@.@@@..@ ................
	;;	@@@@.@@.@.@..... ................
	;;	@@@@@......@@@.. ................
	;;	@@@@@@.@.....@@. ..........@.....
	;;	@.@@@.........@. ........@@@@@...
	;;	@............... ......@@@@@@@@..
	;;	................ ....@@@@....@@@.
	;;	.@.......@...... ...@@@.......@@.
	;;	......@.....@... ..@@@.........@@
	;;	..........@..... ..@@..........@@
	;;	.............@.. .@@............@
	;;	................ .@@............@
	;;	.......@..@..@.. @@.............@
	;;	................ @@.............@
	;;	.............@.. @..............@
	;;	..........@..... @..............@
	;;	..@@@..@.....@.. @.@@@..........@
	;;	..@@............ @.@@...........@
	;;	..........@..@.. @...@..........@
	;;	................ @.@@...........@
	;;	....@@@@.....@.. @...@@@@.......@
	;;	..@@@@@...@..... @.@@@@@........@
	;;	..@@@........@.. @.@@@..@.......@
	;;	..@............. @.@..@@........@
	;;	.......@@@@..@.. @..@@..@@@@....@
	;;	.....@@@@@...... @.@..@@@@@.....@
	;;	...@@@@@.....@.. @..@@@@@..@....@
	;;	..@@@@.......... @.@@@@..@@.....@
	;;	..@@......@@@@.. @.@@..@@..@@@@.@
	;;	........@@@@@... @...@@..@@@@@..@
	;;	......@@@@@....@ @.@@..@@@@@..@..
	;;	....@@@@@....@@. @...@@@@@..@....
	;;	..@@@@@....@@... @.@@@@@..@......
	;;	..@@@....@@..... @.@@@..@........
	;;	.......@@....... @.@..@..........
	;;	.....@@......... @..@............
	;;	...@@........... @...............
	;;	.@@............. @...............
	;;	@............... ................

img_wall_10:
	DEFB &00, &00, &00, &00, &00, &00, &00, &05, &00, &00, &00, &16, &00, &00, &01, &58
	DEFB &00, &01, &00, &60, &00, &05, &1C, &80, &00, &16, &7A, &00, &01, &58, &7E, &00
	DEFB &04, &60, &BE, &00, &1C, &80, &DE, &00, &7A, &00, &FE, &00, &7E, &00, &FE, &00
	DEFB &BE, &00, &FE, &00, &DE, &00, &FE, &00, &FE, &00, &F6, &00, &FE, &00, &FA, &00
	DEFB &FE, &00, &FC, &00, &FE, &00, &B9, &00, &F6, &00, &A0, &00, &F8, &00, &1C, &00
	DEFB &FD, &00, &02, &20, &B8, &00, &02, &F8, &80, &03, &00, &FC, &00, &0F, &00, &0E
	DEFB &00, &1C, &80, &06, &00, &38, &88, &03, &00, &30, &88, &03, &08, &60, &88, &01
	DEFB &08, &60, &88, &01, &08, &C0, &88, &01, &08, &C0, &8A, &03, &08, &C0, &88, &01
	DEFB &08, &80, &88, &01, &08, &80, &88, &01, &08, &80, &88, &01, &08, &80, &88, &01
	DEFB &1C, &9C, &88, &01, &32, &B2, &88, &01, &22, &A2, &88, &01, &1C, &9C, &8A, &03
	DEFB &08, &80, &88, &01, &08, &80, &88, &01, &08, &80, &88, &01, &08, &80, &88, &01
	DEFB &08, &80, &88, &03, &08, &80, &80, &0C, &08, &80, &80, &32, &08, &80, &01, &C8
	DEFB &08, &83, &06, &20, &00, &8C, &18, &80, &00, &B2, &60, &00, &01, &C8, &80, &00
	DEFB &06, &20, &00, &00, &18, &80, &00, &00, &60, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ .............@.@
	;;	................ ...........@.@@.
	;;	...............@ .........@.@@...
	;;	................ .......@.@@.....
	;;	...........@@@.. .....@.@@.......
	;;	.........@@@@.@. ...@.@@.........
	;;	.......@.@@@@@@. .@.@@...........
	;;	.....@..@.@@@@@. .@@.............
	;;	...@@@..@@.@@@@. @...............
	;;	.@@@@.@.@@@@@@@. ................
	;;	.@@@@@@.@@@@@@@. ................
	;;	@.@@@@@.@@@@@@@. ................
	;;	@@.@@@@.@@@@@@@. ................
	;;	@@@@@@@.@@@@.@@. ................
	;;	@@@@@@@.@@@@@.@. ................
	;;	@@@@@@@.@@@@@@.. ................
	;;	@@@@@@@.@.@@@..@ ................
	;;	@@@@.@@.@.@..... ................
	;;	@@@@@......@@@.. ................
	;;	@@@@@@.@......@. ..........@.....
	;;	@.@@@.........@. ........@@@@@...
	;;	@............... ......@@@@@@@@..
	;;	................ ....@@@@....@@@.
	;;	........@....... ...@@@.......@@.
	;;	........@...@... ..@@@.........@@
	;;	........@...@... ..@@..........@@
	;;	....@...@...@... .@@............@
	;;	....@...@...@... .@@............@
	;;	....@...@...@... @@.............@
	;;	....@...@...@.@. @@............@@
	;;	....@...@...@... @@.............@
	;;	....@...@...@... @..............@
	;;	....@...@...@... @..............@
	;;	....@...@...@... @..............@
	;;	....@...@...@... @..............@
	;;	...@@@..@...@... @..@@@.........@
	;;	..@@..@.@...@... @.@@..@........@
	;;	..@...@.@...@... @.@...@........@
	;;	...@@@..@...@.@. @..@@@........@@
	;;	....@...@...@... @..............@
	;;	....@...@...@... @..............@
	;;	....@...@...@... @..............@
	;;	....@...@...@... @..............@
	;;	....@...@...@... @.............@@
	;;	....@...@....... @...........@@..
	;;	....@...@....... @.........@@..@.
	;;	....@..........@ @.......@@..@...
	;;	....@........@@. @.....@@..@.....
	;;	...........@@... @...@@..@.......
	;;	.........@@..... @.@@..@.........
	;;	.......@@....... @@..@...........
	;;	.....@@......... ..@.............
	;;	...@@........... @...............
	;;	.@@............. ................
	;;	@............... ................

img_wall_11:
	DEFB &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &01, &07, &00, &00, &06, &1E
	DEFB &00, &00, &19, &78, &00, &01, &67, &E0, &01, &07, &9F, &80, &06, &1E, &33, &00
	DEFB &19, &78, &AB, &00, &67, &E0, &AB, &00, &9F, &80, &AB, &00, &33, &00, &BB, &00
	DEFB &AB, &00, &A7, &00, &AB, &00, &9E, &00, &AB, &00, &F9, &01, &BB, &00, &E6, &07
	DEFB &A7, &00, &98, &1E, &9E, &00, &61, &78, &F9, &01, &85, &E0, &E6, &07, &1D, &80
	DEFB &98, &1E, &5B, &00, &61, &78, &77, &00, &87, &E0, &C3, &08, &1F, &80, &03, &38
	DEFB &78, &00, &07, &F0, &C0, &06, &0F, &E0, &00, &2F, &2F, &E0, &00, &AF, &CF, &E0
	DEFB &0F, &77, &4F, &E0, &78, &FF, &0F, &E0, &04, &6F, &0F, &A0, &04, &7F, &0F, &E0
	DEFB &04, &7F, &2F, &E0, &45, &7F, &CF, &E0, &3E, &7F, &8F, &E0, &20, &7D, &8F, &E0
	DEFB &20, &7F, &8F, &E0, &20, &7F, &AF, &E0, &61, &7F, &CF, &E0, &3E, &7F, &07, &F0
	DEFB &04, &6F, &31, &F8, &45, &FF, &C2, &F8, &3E, &FF, &01, &E4, &00, &77, &01, &94
	DEFB &00, &AC, &00, &7C, &00, &D3, &01, &78, &00, &F7, &07, &E0, &00, &D7, &1C, &80
	DEFB &00, &76, &73, &00, &81, &10, &CC, &00, &E7, &00, &30, &00, &9C, &00, &C0, &00
	DEFB &73, &00, &00, &00, &CC, &00, &00, &00, &30, &00, &00, &00, &C0, &00, &00, &00
	;;	................ ................
	;;	................ ...............@
	;;	...............@ .............@@@
	;;	.............@@. ...........@@@@.
	;;	...........@@..@ .........@@@@...
	;;	.........@@..@@@ .......@@@@.....
	;;	.......@@..@@@@@ .....@@@@.......
	;;	.....@@...@@..@@ ...@@@@.........
	;;	...@@..@@.@.@.@@ .@@@@...........
	;;	.@@..@@@@.@.@.@@ @@@.............
	;;	@..@@@@@@.@.@.@@ @...............
	;;	..@@..@@@.@@@.@@ ................
	;;	@.@.@.@@@.@..@@@ ................
	;;	@.@.@.@@@..@@@@. ................
	;;	@.@.@.@@@@@@@..@ ...............@
	;;	@.@@@.@@@@@..@@. .............@@@
	;;	@.@..@@@@..@@... ...........@@@@.
	;;	@..@@@@..@@....@ .........@@@@...
	;;	@@@@@..@@....@.@ .......@@@@.....
	;;	@@@..@@....@@@.@ .....@@@@.......
	;;	@..@@....@.@@.@@ ...@@@@.........
	;;	.@@....@.@@@.@@@ .@@@@...........
	;;	@....@@@@@....@@ @@@.........@...
	;;	...@@@@@......@@ @.........@@@...
	;;	.@@@@........@@@ ........@@@@....
	;;	@@..........@@@@ .....@@.@@@.....
	;;	..........@.@@@@ ..@.@@@@@@@.....
	;;	........@@..@@@@ @.@.@@@@@@@.....
	;;	....@@@@.@..@@@@ .@@@.@@@@@@.....
	;;	.@@@@.......@@@@ @@@@@@@@@@@.....
	;;	.....@......@@@@ .@@.@@@@@.@.....
	;;	.....@......@@@@ .@@@@@@@@@@.....
	;;	.....@....@.@@@@ .@@@@@@@@@@.....
	;;	.@...@.@@@..@@@@ .@@@@@@@@@@.....
	;;	..@@@@@.@...@@@@ .@@@@@@@@@@.....
	;;	..@.....@...@@@@ .@@@@@.@@@@.....
	;;	..@.....@...@@@@ .@@@@@@@@@@.....
	;;	..@.....@.@.@@@@ .@@@@@@@@@@.....
	;;	.@@....@@@..@@@@ .@@@@@@@@@@.....
	;;	..@@@@@......@@@ .@@@@@@@@@@@....
	;;	.....@....@@...@ .@@.@@@@@@@@@...
	;;	.@...@.@@@....@. @@@@@@@@@@@@@...
	;;	..@@@@@........@ @@@@@@@@@@@..@..
	;;	...............@ .@@@.@@@@..@.@..
	;;	................ @.@.@@...@@@@@..
	;;	...............@ @@.@..@@.@@@@...
	;;	.............@@@ @@@@.@@@@@@.....
	;;	...........@@@.. @@.@.@@@@.......
	;;	.........@@@..@@ .@@@.@@.........
	;;	@......@@@..@@.. ...@............
	;;	@@@..@@@..@@.... ................
	;;	@..@@@..@@...... ................
	;;	.@@@..@@........ ................
	;;	@@..@@.......... ................
	;;	..@@............ ................
	;;	@@.............. ................

img_wall_12:
	DEFB &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &01, &07, &00, &00, &06, &1E
	DEFB &00, &00, &19, &78, &00, &01, &67, &E0, &01, &07, &9F, &80, &06, &1E, &33, &00
	DEFB &19, &78, &AB, &00, &67, &E0, &AB, &00, &9F, &80, &AB, &00, &33, &00, &BB, &00
	DEFB &AB, &00, &A7, &00, &AB, &00, &9E, &00, &AB, &00, &F9, &01, &BB, &00, &E6, &07
	DEFB &A7, &00, &98, &1E, &9E, &00, &60, &78, &F9, &01, &84, &E0, &E6, &07, &1E, &80
	DEFB &98, &1E, &72, &00, &61, &78, &C2, &08, &87, &E0, &02, &18, &1C, &80, &A2, &A8
	DEFB &73, &03, &62, &68, &CF, &0F, &C2, &C8, &C3, &03, &82, &98, &88, &08, &02, &18
	DEFB &93, &13, &A2, &A8, &AB, &2B, &62, &68, &9F, &1F, &C2, &C8, &87, &07, &82, &98
	DEFB &88, &08, &02, &18, &93, &13, &A2, &A8, &AB, &2B, &62, &68, &9F, &1F, &C2, &C8
	DEFB &83, &03, &82, &98, &88, &08, &02, &18, &93, &13, &A2, &A8, &AB, &2B, &62, &68
	DEFB &9F, &1F, &C2, &C8, &87, &07, &82, &98, &88, &08, &02, &38, &85, &05, &06, &70
	DEFB &87, &07, &0C, &40, &82, &1A, &3B, &00, &80, &3C, &E7, &00, &83, &30, &9C, &00
	DEFB &8E, &00, &73, &00, &F9, &00, &CC, &00, &E7, &00, &30, &00, &1C, &00, &C0, &00
	DEFB &F3, &00, &00, &00, &CC, &00, &00, &00, &30, &00, &00, &00, &C0, &00, &00, &00
	;;	................ ................
	;;	................ ...............@
	;;	...............@ .............@@@
	;;	.............@@. ...........@@@@.
	;;	...........@@..@ .........@@@@...
	;;	.........@@..@@@ .......@@@@.....
	;;	.......@@..@@@@@ .....@@@@.......
	;;	.....@@...@@..@@ ...@@@@.........
	;;	...@@..@@.@.@.@@ .@@@@...........
	;;	.@@..@@@@.@.@.@@ @@@.............
	;;	@..@@@@@@.@.@.@@ @...............
	;;	..@@..@@@.@@@.@@ ................
	;;	@.@.@.@@@.@..@@@ ................
	;;	@.@.@.@@@..@@@@. ................
	;;	@.@.@.@@@@@@@..@ ...............@
	;;	@.@@@.@@@@@..@@. .............@@@
	;;	@.@..@@@@..@@... ...........@@@@.
	;;	@..@@@@..@@..... .........@@@@...
	;;	@@@@@..@@....@.. .......@@@@.....
	;;	@@@..@@....@@@@. .....@@@@.......
	;;	@..@@....@@@..@. ...@@@@.........
	;;	.@@....@@@....@. .@@@@.......@...
	;;	@....@@@......@. @@@........@@...
	;;	...@@@..@.@...@. @.......@.@.@...
	;;	.@@@..@@.@@...@. ......@@.@@.@...
	;;	@@..@@@@@@....@. ....@@@@@@..@...
	;;	@@....@@@.....@. ......@@@..@@...
	;;	@...@.........@. ....@......@@...
	;;	@..@..@@@.@...@. ...@..@@@.@.@...
	;;	@.@.@.@@.@@...@. ..@.@.@@.@@.@...
	;;	@..@@@@@@@....@. ...@@@@@@@..@...
	;;	@....@@@@.....@. .....@@@@..@@...
	;;	@...@.........@. ....@......@@...
	;;	@..@..@@@.@...@. ...@..@@@.@.@...
	;;	@.@.@.@@.@@...@. ..@.@.@@.@@.@...
	;;	@..@@@@@@@....@. ...@@@@@@@..@...
	;;	@.....@@@.....@. ......@@@..@@...
	;;	@...@.........@. ....@......@@...
	;;	@..@..@@@.@...@. ...@..@@@.@.@...
	;;	@.@.@.@@.@@...@. ..@.@.@@.@@.@...
	;;	@..@@@@@@@....@. ...@@@@@@@..@...
	;;	@....@@@@.....@. .....@@@@..@@...
	;;	@...@.........@. ....@.....@@@...
	;;	@....@.@.....@@. .....@.@.@@@....
	;;	@....@@@....@@.. .....@@@.@......
	;;	@.....@...@@@.@@ ...@@.@.........
	;;	@.......@@@..@@@ ..@@@@..........
	;;	@.....@@@..@@@.. ..@@............
	;;	@...@@@..@@@..@@ ................
	;;	@@@@@..@@@..@@.. ................
	;;	@@@..@@@..@@.... ................
	;;	...@@@..@@...... ................
	;;	@@@@..@@........ ................
	;;	@@..@@.......... ................
	;;	..@@............ ................
	;;	@@.............. ................

img_wall_13:
	DEFB &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &01, &07, &00, &00, &06, &1E
	DEFB &00, &00, &19, &78, &00, &01, &67, &E0, &01, &07, &9F, &80, &06, &1E, &33, &00
	DEFB &19, &78, &AB, &00, &67, &E0, &AB, &00, &9F, &80, &AB, &00, &33, &00, &BB, &00
	DEFB &AB, &00, &A7, &00, &AB, &00, &9E, &00, &AB, &00, &F9, &01, &BB, &00, &E6, &07
	DEFB &A7, &00, &98, &1E, &9E, &00, &60, &78, &F9, &01, &80, &E0, &E6, &07, &1C, &80
	DEFB &98, &1E, &3E, &00, &60, &78, &46, &00, &81, &E0, &FA, &00, &17, &80, &FA, &00
	DEFB &6F, &00, &0C, &00, &DC, &00, &04, &70, &BA, &02, &86, &B0, &71, &01, &02, &38
	DEFB &60, &00, &C2, &D8, &E0, &00, &82, &98, &C0, &00, &C2, &D8, &C0, &00, &82, &98
	DEFB &80, &00, &C2, &D8, &80, &00, &82, &98, &80, &00, &C2, &D8, &80, &00, &82, &98
	DEFB &80, &00, &C2, &D8, &80, &00, &82, &98, &80, &00, &C2, &D8, &80, &00, &82, &98
	DEFB &83, &03, &42, &58, &8D, &0D, &02, &28, &B4, &34, &02, &F0, &90, &13, &06, &E0
	DEFB &80, &0F, &1E, &80, &80, &3E, &79, &00, &81, &38, &E7, &00, &87, &20, &9C, &00
	DEFB &9E, &00, &73, &00, &F9, &00, &CC, &00, &E7, &00, &30, &00, &1C, &00, &C0, &00
	DEFB &F3, &00, &00, &00, &CC, &00, &00, &00, &30, &00, &00, &00, &C0, &00, &00, &00
	;;	................ ................
	;;	................ ...............@
	;;	...............@ .............@@@
	;;	.............@@. ...........@@@@.
	;;	...........@@..@ .........@@@@...
	;;	.........@@..@@@ .......@@@@.....
	;;	.......@@..@@@@@ .....@@@@.......
	;;	.....@@...@@..@@ ...@@@@.........
	;;	...@@..@@.@.@.@@ .@@@@...........
	;;	.@@..@@@@.@.@.@@ @@@.............
	;;	@..@@@@@@.@.@.@@ @...............
	;;	..@@..@@@.@@@.@@ ................
	;;	@.@.@.@@@.@..@@@ ................
	;;	@.@.@.@@@..@@@@. ................
	;;	@.@.@.@@@@@@@..@ ...............@
	;;	@.@@@.@@@@@..@@. .............@@@
	;;	@.@..@@@@..@@... ...........@@@@.
	;;	@..@@@@..@@..... .........@@@@...
	;;	@@@@@..@@....... .......@@@@.....
	;;	@@@..@@....@@@.. .....@@@@.......
	;;	@..@@.....@@@@@. ...@@@@.........
	;;	.@@......@...@@. .@@@@...........
	;;	@......@@@@@@.@. @@@.............
	;;	...@.@@@@@@@@.@. @...............
	;;	.@@.@@@@....@@.. ................
	;;	@@.@@@.......@.. .........@@@....
	;;	@.@@@.@.@....@@. ......@.@.@@....
	;;	.@@@...@......@. .......@..@@@...
	;;	.@@.....@@....@. ........@@.@@...
	;;	@@@.....@.....@. ........@..@@...
	;;	@@......@@....@. ........@@.@@...
	;;	@@......@.....@. ........@..@@...
	;;	@.......@@....@. ........@@.@@...
	;;	@.......@.....@. ........@..@@...
	;;	@.......@@....@. ........@@.@@...
	;;	@.......@.....@. ........@..@@...
	;;	@.......@@....@. ........@@.@@...
	;;	@.......@.....@. ........@..@@...
	;;	@.......@@....@. ........@@.@@...
	;;	@.......@.....@. ........@..@@...
	;;	@.....@@.@....@. ......@@.@.@@...
	;;	@...@@.@......@. ....@@.@..@.@...
	;;	@.@@.@........@. ..@@.@..@@@@....
	;;	@..@.........@@. ...@..@@@@@.....
	;;	@..........@@@@. ....@@@@@.......
	;;	@........@@@@..@ ..@@@@@.........
	;;	@......@@@@..@@@ ..@@@...........
	;;	@....@@@@..@@@.. ..@.............
	;;	@..@@@@..@@@..@@ ................
	;;	@@@@@..@@@..@@.. ................
	;;	@@@..@@@..@@.... ................
	;;	...@@@..@@...... ................
	;;	@@@@..@@........ ................
	;;	@@..@@.......... ................
	;;	..@@............ ................
	;;	@@.............. ................

img_wall_14:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &C0, &00, &02, &00, &40
	DEFB &00, &02, &00, &20, &00, &01, &00, &20, &00, &01, &0C, &10, &08, &02, &02, &10
	DEFB &34, &01, &11, &20, &42, &00, &01, &90, &42, &00, &81, &50, &84, &00, &41, &20
	DEFB &80, &00, &01, &00, &80, &00, &02, &00, &80, &00, &01, &00, &98, &00, &49, &00
	DEFB &94, &00, &29, &00, &44, &00, &BB, &00, &3C, &00, &FF, &00, &0C, &00, &E4, &00
	DEFB &3D, &00, &D0, &13, &7F, &00, &C0, &0D, &FF, &00, &00, &34, &E4, &00, &03, &D0
	DEFB &D0, &13, &05, &40, &C0, &0D, &11, &00, &00, &34, &DB, &00, &03, &D0, &18, &00
	DEFB &0F, &40, &ED, &00, &21, &00, &FD, &00, &CA, &00, &7C, &00, &3F, &00, &29, &00
	DEFB &E1, &00, &BB, &00, &8A, &00, &38, &00, &3F, &00, &7D, &00, &E1, &00, &A9, &00
	DEFB &8A, &00, &3B, &00, &3F, &00, &B8, &00, &61, &00, &7D, &00, &CA, &00, &28, &00
	DEFB &BF, &00, &BB, &00, &61, &00, &BB, &00, &CA, &00, &7C, &00, &BF, &00, &A9, &00
	DEFB &3F, &00, &FB, &00, &F0, &00, &F0, &00, &E5, &00, &47, &00, &CF, &00, &8D, &00
	DEFB &DF, &00, &77, &00, &D8, &00, &D8, &00, &37, &00, &70, &00, &8D, &00, &80, &00
	DEFB &77, &00, &00, &00, &D8, &00, &00, &00, &70, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ .......@@@......
	;;	................ ......@..@......
	;;	................ ......@...@.....
	;;	................ .......@..@.....
	;;	............@@.. .......@...@....
	;;	....@.........@. ......@....@....
	;;	..@@.@.....@...@ .......@..@.....
	;;	.@....@........@ ........@..@....
	;;	.@....@.@......@ .........@.@....
	;;	@....@...@.....@ ..........@.....
	;;	@..............@ ................
	;;	@.............@. ................
	;;	@..............@ ................
	;;	@..@@....@..@..@ ................
	;;	@..@.@....@.@..@ ................
	;;	.@...@..@.@@@.@@ ................
	;;	..@@@@..@@@@@@@@ ................
	;;	....@@..@@@..@.. ................
	;;	..@@@@.@@@.@.... ...........@..@@
	;;	.@@@@@@@@@...... ............@@.@
	;;	@@@@@@@@........ ..........@@.@..
	;;	@@@..@........@@ ........@@.@....
	;;	@@.@.........@.@ ...@..@@.@......
	;;	@@.........@...@ ....@@.@........
	;;	........@@.@@.@@ ..@@.@..........
	;;	......@@...@@... @@.@............
	;;	....@@@@@@@.@@.@ .@..............
	;;	..@....@@@@@@@.@ ................
	;;	@@..@.@..@@@@@.. ................
	;;	..@@@@@@..@.@..@ ................
	;;	@@@....@@.@@@.@@ ................
	;;	@...@.@...@@@... ................
	;;	..@@@@@@.@@@@@.@ ................
	;;	@@@....@@.@.@..@ ................
	;;	@...@.@...@@@.@@ ................
	;;	..@@@@@@@.@@@... ................
	;;	.@@....@.@@@@@.@ ................
	;;	@@..@.@...@.@... ................
	;;	@.@@@@@@@.@@@.@@ ................
	;;	.@@....@@.@@@.@@ ................
	;;	@@..@.@..@@@@@.. ................
	;;	@.@@@@@@@.@.@..@ ................
	;;	..@@@@@@@@@@@.@@ ................
	;;	@@@@....@@@@.... ................
	;;	@@@..@.@.@...@@@ ................
	;;	@@..@@@@@...@@.@ ................
	;;	@@.@@@@@.@@@.@@@ ................
	;;	@@.@@...@@.@@... ................
	;;	..@@.@@@.@@@.... ................
	;;	@...@@.@@....... ................
	;;	.@@@.@@@........ ................
	;;	@@.@@........... ................
	;;	.@@@............ ................
	;;	@............... ................

img_wall_15:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &C0, &00, &02, &00, &40
	DEFB &00, &02, &00, &20, &00, &01, &00, &20, &00, &01, &0C, &10, &08, &02, &02, &10
	DEFB &34, &01, &11, &20, &42, &00, &01, &90, &42, &00, &81, &50, &84, &00, &41, &20
	DEFB &80, &00, &01, &00, &80, &00, &02, &00, &80, &00, &01, &00, &98, &00, &49, &00
	DEFB &94, &00, &29, &00, &44, &00, &BB, &00, &3C, &00, &FF, &00, &0C, &00, &E4, &00
	DEFB &3D, &00, &D0, &13, &7F, &00, &C0, &0D, &FF, &00, &00, &34, &E4, &00, &02, &D0
	DEFB &D0, &13, &02, &40, &C0, &0D, &04, &00, &00, &34, &04, &00, &00, &D0, &68, &60
	DEFB &03, &43, &88, &80, &8E, &0E, &70, &70, &5D, &1D, &F8, &F8, &2B, &0B, &FC, &FC
	DEFB &17, &07, &FC, &FC, &27, &27, &5E, &5E, &6F, &6F, &96, &96, &6E, &6E, &7E, &7E
	DEFB &6F, &6F, &6E, &6E, &6E, &6E, &9E, &9E, &6F, &6F, &AC, &AC, &37, &37, &FC, &FC
	DEFB &37, &37, &F8, &F8, &1B, &1B, &F0, &F2, &0C, &0C, &C0, &CE, &03, &03, &00, &30
	DEFB &00, &00, &07, &C0, &38, &3B, &08, &00, &7C, &7C, &77, &00, &58, &58, &8D, &00
	DEFB &37, &30, &77, &00, &08, &00, &D8, &00, &77, &00, &70, &00, &0D, &00, &80, &00
	DEFB &77, &00, &00, &00, &D8, &00, &00, &00, &70, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ .......@@@......
	;;	................ ......@..@......
	;;	................ ......@...@.....
	;;	................ .......@..@.....
	;;	............@@.. .......@...@....
	;;	....@.........@. ......@....@....
	;;	..@@.@.....@...@ .......@..@.....
	;;	.@....@........@ ........@..@....
	;;	.@....@.@......@ .........@.@....
	;;	@....@...@.....@ ..........@.....
	;;	@..............@ ................
	;;	@.............@. ................
	;;	@..............@ ................
	;;	@..@@....@..@..@ ................
	;;	@..@.@....@.@..@ ................
	;;	.@...@..@.@@@.@@ ................
	;;	..@@@@..@@@@@@@@ ................
	;;	....@@..@@@..@.. ................
	;;	..@@@@.@@@.@.... ...........@..@@
	;;	.@@@@@@@@@...... ............@@.@
	;;	@@@@@@@@........ ..........@@.@..
	;;	@@@..@........@. ........@@.@....
	;;	@@.@..........@. ...@..@@.@......
	;;	@@...........@.. ....@@.@........
	;;	.............@.. ..@@.@..........
	;;	.........@@.@... @@.@.....@@.....
	;;	......@@@...@... .@....@@@.......
	;;	@...@@@..@@@.... ....@@@..@@@....
	;;	.@.@@@.@@@@@@... ...@@@.@@@@@@...
	;;	..@.@.@@@@@@@@.. ....@.@@@@@@@@..
	;;	...@.@@@@@@@@@.. .....@@@@@@@@@..
	;;	..@..@@@.@.@@@@. ..@..@@@.@.@@@@.
	;;	.@@.@@@@@..@.@@. .@@.@@@@@..@.@@.
	;;	.@@.@@@..@@@@@@. .@@.@@@..@@@@@@.
	;;	.@@.@@@@.@@.@@@. .@@.@@@@.@@.@@@.
	;;	.@@.@@@.@..@@@@. .@@.@@@.@..@@@@.
	;;	.@@.@@@@@.@.@@.. .@@.@@@@@.@.@@..
	;;	..@@.@@@@@@@@@.. ..@@.@@@@@@@@@..
	;;	..@@.@@@@@@@@... ..@@.@@@@@@@@...
	;;	...@@.@@@@@@.... ...@@.@@@@@@..@.
	;;	....@@..@@...... ....@@..@@..@@@.
	;;	......@@........ ......@@..@@....
	;;	.............@@@ ........@@......
	;;	..@@@.......@... ..@@@.@@........
	;;	.@@@@@...@@@.@@@ .@@@@@..........
	;;	.@.@@...@...@@.@ .@.@@...........
	;;	..@@.@@@.@@@.@@@ ..@@............
	;;	....@...@@.@@... ................
	;;	.@@@.@@@.@@@.... ................
	;;	....@@.@@....... ................
	;;	.@@@.@@@........ ................
	;;	@@.@@........... ................
	;;	.@@@............ ................
	;;	@............... ................

img_wall_16:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &C0, &00, &02, &00, &40
	DEFB &00, &02, &00, &20, &00, &01, &00, &20, &00, &01, &0C, &10, &08, &02, &02, &10
	DEFB &34, &01, &11, &20, &42, &00, &01, &90, &42, &00, &81, &50, &84, &00, &41, &20
	DEFB &80, &00, &01, &00, &80, &00, &02, &00, &80, &00, &01, &00, &98, &00, &49, &00
	DEFB &94, &00, &29, &00, &44, &00, &BB, &00, &3C, &00, &FF, &00, &0C, &00, &E4, &00
	DEFB &3D, &00, &D0, &13, &7F, &00, &C0, &0D, &FF, &00, &00, &34, &E4, &00, &03, &D0
	DEFB &D0, &13, &0E, &40, &C0, &0D, &32, &00, &00, &34, &82, &80, &03, &D3, &E2, &E0
	DEFB &0F, &4F, &F2, &F0, &3F, &3F, &FA, &F8, &BF, &3F, &18, &18, &BC, &3C, &0C, &AC
	DEFB &B8, &3A, &04, &E4, &B8, &39, &06, &16, &B0, &32, &02, &0A, &B0, &36, &22, &2A
	DEFB &B0, &32, &02, &0A, &B0, &36, &02, &0A, &B8, &39, &06, &16, &B8, &3A, &04, &E4
	DEFB &BC, &3C, &0C, &AC, &BF, &3F, &18, &18, &BF, &3F, &FA, &F8, &BF, &3F, &F2, &F0
	DEFB &BF, &3F, &E7, &E0, &BF, &3F, &88, &80, &BC, &3C, &77, &00, &80, &00, &8D, &00
	DEFB &87, &00, &77, &00, &88, &00, &D8, &00, &F7, &00, &70, &00, &8D, &00, &80, &00
	DEFB &77, &00, &00, &00, &D8, &00, &00, &00, &70, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ .......@@@......
	;;	................ ......@..@......
	;;	................ ......@...@.....
	;;	................ .......@..@.....
	;;	............@@.. .......@...@....
	;;	....@.........@. ......@....@....
	;;	..@@.@.....@...@ .......@..@.....
	;;	.@....@........@ ........@..@....
	;;	.@....@.@......@ .........@.@....
	;;	@....@...@.....@ ..........@.....
	;;	@..............@ ................
	;;	@.............@. ................
	;;	@..............@ ................
	;;	@..@@....@..@..@ ................
	;;	@..@.@....@.@..@ ................
	;;	.@...@..@.@@@.@@ ................
	;;	..@@@@..@@@@@@@@ ................
	;;	....@@..@@@..@.. ................
	;;	..@@@@.@@@.@.... ...........@..@@
	;;	.@@@@@@@@@...... ............@@.@
	;;	@@@@@@@@........ ..........@@.@..
	;;	@@@..@........@@ ........@@.@....
	;;	@@.@........@@@. ...@..@@.@......
	;;	@@........@@..@. ....@@.@........
	;;	........@.....@. ..@@.@..@.......
	;;	......@@@@@...@. @@.@..@@@@@.....
	;;	....@@@@@@@@..@. .@..@@@@@@@@....
	;;	..@@@@@@@@@@@.@. ..@@@@@@@@@@@...
	;;	@.@@@@@@...@@... ..@@@@@@...@@...
	;;	@.@@@@......@@.. ..@@@@..@.@.@@..
	;;	@.@@@........@.. ..@@@.@.@@@..@..
	;;	@.@@@........@@. ..@@@..@...@.@@.
	;;	@.@@..........@. ..@@..@.....@.@.
	;;	@.@@......@...@. ..@@.@@...@.@.@.
	;;	@.@@..........@. ..@@..@.....@.@.
	;;	@.@@..........@. ..@@.@@.....@.@.
	;;	@.@@@........@@. ..@@@..@...@.@@.
	;;	@.@@@........@.. ..@@@.@.@@@..@..
	;;	@.@@@@......@@.. ..@@@@..@.@.@@..
	;;	@.@@@@@@...@@... ..@@@@@@...@@...
	;;	@.@@@@@@@@@@@.@. ..@@@@@@@@@@@...
	;;	@.@@@@@@@@@@..@. ..@@@@@@@@@@....
	;;	@.@@@@@@@@@..@@@ ..@@@@@@@@@.....
	;;	@.@@@@@@@...@... ..@@@@@@@.......
	;;	@.@@@@...@@@.@@@ ..@@@@..........
	;;	@.......@...@@.@ ................
	;;	@....@@@.@@@.@@@ ................
	;;	@...@...@@.@@... ................
	;;	@@@@.@@@.@@@.... ................
	;;	@...@@.@@....... ................
	;;	.@@@.@@@........ ................
	;;	@@.@@........... ................
	;;	.@@@............ ................
	;;	@............... ................

img_wall_17:
	DEFB &00, &00, &00, &00, &00, &00, &01, &00, &00, &00, &03, &00, &00, &00, &1A, &00
	DEFB &00, &00, &56, &00, &01, &00, &56, &00, &05, &00, &6D, &00, &17, &00, &6A, &00
	DEFB &52, &00, &6B, &00, &6C, &00, &DB, &00, &2B, &00, &12, &00, &5B, &00, &B5, &00
	DEFB &DB, &00, &66, &00, &B6, &00, &B9, &00, &57, &00, &2D, &00, &55, &00, &4B, &00
	DEFB &B4, &00, &A6, &00, &6B, &00, &FA, &00, &A6, &00, &8A, &00, &B4, &00, &04, &00
	DEFB &48, &00, &A4, &00, &9A, &00, &52, &00, &52, &00, &56, &00, &A5, &00, &A9, &00
	DEFB &65, &00, &B6, &00, &45, &00, &21, &00, &95, &00, &8A, &00, &D4, &00, &52, &00
	DEFB &52, &00, &AA, &00, &91, &00, &AA, &00, &95, &00, &6D, &00, &CD, &00, &56, &00
	DEFB &8D, &00, &22, &00, &D4, &00, &4A, &00, &45, &00, &6A, &00, &AD, &00, &6D, &00
	DEFB &A9, &00, &6D, &00, &A5, &00, &32, &00, &AD, &00, &BB, &00, &8D, &00, &92, &00
	DEFB &AC, &00, &95, &00, &54, &00, &DB, &00, &D6, &00, &9A, &00, &46, &00, &D2, &00
	DEFB &DA, &00, &4B, &00, &AB, &00, &5B, &00, &69, &00, &6D, &00, &45, &00, &AD, &00
	DEFB &B6, &00, &B6, &00, &6A, &00, &A8, &00, &5A, &00, &60, &00, &AB, &00, &80, &00
	DEFB &6C, &00, &00, &00, &58, &00, &00, &00, &60, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	...............@ ................
	;;	..............@@ ................
	;;	...........@@.@. ................
	;;	.........@.@.@@. ................
	;;	.......@.@.@.@@. ................
	;;	.....@.@.@@.@@.@ ................
	;;	...@.@@@.@@.@.@. ................
	;;	.@.@..@..@@.@.@@ ................
	;;	.@@.@@..@@.@@.@@ ................
	;;	..@.@.@@...@..@. ................
	;;	.@.@@.@@@.@@.@.@ ................
	;;	@@.@@.@@.@@..@@. ................
	;;	@.@@.@@.@.@@@..@ ................
	;;	.@.@.@@@..@.@@.@ ................
	;;	.@.@.@.@.@..@.@@ ................
	;;	@.@@.@..@.@..@@. ................
	;;	.@@.@.@@@@@@@.@. ................
	;;	@.@..@@.@...@.@. ................
	;;	@.@@.@.......@.. ................
	;;	.@..@...@.@..@.. ................
	;;	@..@@.@..@.@..@. ................
	;;	.@.@..@..@.@.@@. ................
	;;	@.@..@.@@.@.@..@ ................
	;;	.@@..@.@@.@@.@@. ................
	;;	.@...@.@..@....@ ................
	;;	@..@.@.@@...@.@. ................
	;;	@@.@.@...@.@..@. ................
	;;	.@.@..@.@.@.@.@. ................
	;;	@..@...@@.@.@.@. ................
	;;	@..@.@.@.@@.@@.@ ................
	;;	@@..@@.@.@.@.@@. ................
	;;	@...@@.@..@...@. ................
	;;	@@.@.@...@..@.@. ................
	;;	.@...@.@.@@.@.@. ................
	;;	@.@.@@.@.@@.@@.@ ................
	;;	@.@.@..@.@@.@@.@ ................
	;;	@.@..@.@..@@..@. ................
	;;	@.@.@@.@@.@@@.@@ ................
	;;	@...@@.@@..@..@. ................
	;;	@.@.@@..@..@.@.@ ................
	;;	.@.@.@..@@.@@.@@ ................
	;;	@@.@.@@.@..@@.@. ................
	;;	.@...@@.@@.@..@. ................
	;;	@@.@@.@..@..@.@@ ................
	;;	@.@.@.@@.@.@@.@@ ................
	;;	.@@.@..@.@@.@@.@ ................
	;;	.@...@.@@.@.@@.@ ................
	;;	@.@@.@@.@.@@.@@. ................
	;;	.@@.@.@.@.@.@... ................
	;;	.@.@@.@..@@..... ................
	;;	@.@.@.@@@....... ................
	;;	.@@.@@.......... ................
	;;	.@.@@........... ................
	;;	.@@............. ................
	;;	@............... ................

img_wall_18:
	DEFB &00, &00, &00, &00, &00, &00, &01, &00, &00, &00, &03, &00, &00, &00, &1A, &00
	DEFB &00, &00, &56, &00, &01, &00, &56, &00, &05, &00, &6D, &00, &17, &00, &6A, &00
	DEFB &52, &00, &6B, &00, &6C, &00, &DB, &00, &2B, &00, &12, &00, &5B, &00, &B5, &00
	DEFB &DB, &00, &66, &00, &B6, &00, &B9, &00, &57, &00, &2D, &00, &55, &00, &4B, &00
	DEFB &B4, &00, &A6, &00, &6B, &00, &FA, &00, &A6, &00, &8A, &00, &B4, &00, &05, &00
	DEFB &49, &01, &55, &00, &9B, &03, &12, &00, &53, &03, &56, &00, &A3, &03, &6B, &00
	DEFB &63, &03, &05, &00, &43, &03, &3B, &38, &83, &03, &F4, &F0, &C3, &03, &C3, &C0
	DEFB &4F, &0F, &15, &00, &BF, &3F, &0A, &00, &B3, &33, &17, &00, &83, &03, &04, &00
	DEFB &83, &03, &3B, &38, &C3, &03, &F5, &F0, &43, &03, &C6, &C0, &4F, &0F, &15, &00
	DEFB &3F, &3F, &0D, &00, &B3, &33, &15, &00, &C3, &03, &06, &00, &43, &03, &39, &38
	DEFB &83, &03, &F5, &F0, &43, &03, &CA, &C0, &CF, &0F, &1A, &00, &5F, &1F, &2A, &00
	DEFB &D3, &13, &35, &00, &E3, &03, &54, &00, &A3, &03, &2B, &00, &B3, &03, &69, &00
	DEFB &59, &01, &16, &00, &EC, &00, &78, &00, &6B, &00, &A0, &00, &B1, &00, &80, &00
	DEFB &DE, &00, &00, &00, &50, &00, &00, &00, &60, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	...............@ ................
	;;	..............@@ ................
	;;	...........@@.@. ................
	;;	.........@.@.@@. ................
	;;	.......@.@.@.@@. ................
	;;	.....@.@.@@.@@.@ ................
	;;	...@.@@@.@@.@.@. ................
	;;	.@.@..@..@@.@.@@ ................
	;;	.@@.@@..@@.@@.@@ ................
	;;	..@.@.@@...@..@. ................
	;;	.@.@@.@@@.@@.@.@ ................
	;;	@@.@@.@@.@@..@@. ................
	;;	@.@@.@@.@.@@@..@ ................
	;;	.@.@.@@@..@.@@.@ ................
	;;	.@.@.@.@.@..@.@@ ................
	;;	@.@@.@..@.@..@@. ................
	;;	.@@.@.@@@@@@@.@. ................
	;;	@.@..@@.@...@.@. ................
	;;	@.@@.@.......@.@ ................
	;;	.@..@..@.@.@.@.@ .......@........
	;;	@..@@.@@...@..@. ......@@........
	;;	.@.@..@@.@.@.@@. ......@@........
	;;	@.@...@@.@@.@.@@ ......@@........
	;;	.@@...@@.....@.@ ......@@........
	;;	.@....@@..@@@.@@ ......@@..@@@...
	;;	@.....@@@@@@.@.. ......@@@@@@....
	;;	@@....@@@@....@@ ......@@@@......
	;;	.@..@@@@...@.@.@ ....@@@@........
	;;	@.@@@@@@....@.@. ..@@@@@@........
	;;	@.@@..@@...@.@@@ ..@@..@@........
	;;	@.....@@.....@.. ......@@........
	;;	@.....@@..@@@.@@ ......@@..@@@...
	;;	@@....@@@@@@.@.@ ......@@@@@@....
	;;	.@....@@@@...@@. ......@@@@......
	;;	.@..@@@@...@.@.@ ....@@@@........
	;;	..@@@@@@....@@.@ ..@@@@@@........
	;;	@.@@..@@...@.@.@ ..@@..@@........
	;;	@@....@@.....@@. ......@@........
	;;	.@....@@..@@@..@ ......@@..@@@...
	;;	@.....@@@@@@.@.@ ......@@@@@@....
	;;	.@....@@@@..@.@. ......@@@@......
	;;	@@..@@@@...@@.@. ....@@@@........
	;;	.@.@@@@@..@.@.@. ...@@@@@........
	;;	@@.@..@@..@@.@.@ ...@..@@........
	;;	@@@...@@.@.@.@.. ......@@........
	;;	@.@...@@..@.@.@@ ......@@........
	;;	@.@@..@@.@@.@..@ ......@@........
	;;	.@.@@..@...@.@@. .......@........
	;;	@@@.@@...@@@@... ................
	;;	.@@.@.@@@.@..... ................
	;;	@.@@...@@....... ................
	;;	@@.@@@@......... ................
	;;	.@.@............ ................
	;;	.@@............. ................
	;;	@............... ................

img_wall_19:
	DEFB &00, &00, &00, &00, &00, &00, &81, &80, &03, &03, &CB, &C0, &05, &05, &AB, &A0
	DEFB &04, &04, &6A, &60, &05, &05, &E5, &E0, &05, &05, &E5, &E0, &05, &05, &EB, &E0
	DEFB &45, &05, &E6, &E0, &45, &05, &EA, &E0, &85, &05, &EA, &E0, &A5, &05, &E4, &E0
	DEFB &45, &05, &E4, &E0, &85, &05, &E2, &E0, &45, &05, &E6, &E0, &85, &05, &E9, &E0
	DEFB &45, &05, &E6, &E0, &45, &05, &E1, &E0, &85, &05, &EA, &E0, &C5, &05, &E2, &E0
	DEFB &45, &05, &EA, &E0, &A5, &05, &EA, &E0, &85, &05, &ED, &E0, &C5, &05, &E6, &E0
	DEFB &A5, &05, &E2, &E0, &C5, &05, &EA, &E0, &45, &05, &EA, &E0, &85, &05, &ED, &E0
	DEFB &A5, &05, &ED, &E0, &85, &05, &E2, &E0, &A5, &05, &EB, &E0, &85, &05, &E2, &E0
	DEFB &85, &05, &E5, &E0, &45, &05, &EB, &E0, &C5, &05, &EA, &E0, &45, &05, &E2, &E0
	DEFB &C5, &05, &EB, &E0, &A5, &05, &EB, &E0, &45, &05, &ED, &E0, &45, &05, &ED, &E0
	DEFB &A5, &05, &E6, &E0, &85, &05, &ED, &E0, &45, &05, &E5, &E0, &A5, &05, &ED, &E0
	DEFB &85, &05, &E3, &E0, &65, &05, &E1, &E0, &A5, &05, &E0, &E0, &C5, &05, &E0, &E0
	DEFB &85, &05, &E0, &E0, &C5, &05, &E0, &E0, &44, &04, &A0, &A0, &C6, &06, &60, &60
	DEFB &43, &03, &C0, &C0, &40, &00, &00, &00, &80, &00, &00, &00, &00, &00, &00, &00
	;;	................ ................
	;;	........@......@ ........@.......
	;;	......@@@@..@.@@ ......@@@@......
	;;	.....@.@@.@.@.@@ .....@.@@.@.....
	;;	.....@...@@.@.@. .....@...@@.....
	;;	.....@.@@@@..@.@ .....@.@@@@.....
	;;	.....@.@@@@..@.@ .....@.@@@@.....
	;;	.....@.@@@@.@.@@ .....@.@@@@.....
	;;	.@...@.@@@@..@@. .....@.@@@@.....
	;;	.@...@.@@@@.@.@. .....@.@@@@.....
	;;	@....@.@@@@.@.@. .....@.@@@@.....
	;;	@.@..@.@@@@..@.. .....@.@@@@.....
	;;	.@...@.@@@@..@.. .....@.@@@@.....
	;;	@....@.@@@@...@. .....@.@@@@.....
	;;	.@...@.@@@@..@@. .....@.@@@@.....
	;;	@....@.@@@@.@..@ .....@.@@@@.....
	;;	.@...@.@@@@..@@. .....@.@@@@.....
	;;	.@...@.@@@@....@ .....@.@@@@.....
	;;	@....@.@@@@.@.@. .....@.@@@@.....
	;;	@@...@.@@@@...@. .....@.@@@@.....
	;;	.@...@.@@@@.@.@. .....@.@@@@.....
	;;	@.@..@.@@@@.@.@. .....@.@@@@.....
	;;	@....@.@@@@.@@.@ .....@.@@@@.....
	;;	@@...@.@@@@..@@. .....@.@@@@.....
	;;	@.@..@.@@@@...@. .....@.@@@@.....
	;;	@@...@.@@@@.@.@. .....@.@@@@.....
	;;	.@...@.@@@@.@.@. .....@.@@@@.....
	;;	@....@.@@@@.@@.@ .....@.@@@@.....
	;;	@.@..@.@@@@.@@.@ .....@.@@@@.....
	;;	@....@.@@@@...@. .....@.@@@@.....
	;;	@.@..@.@@@@.@.@@ .....@.@@@@.....
	;;	@....@.@@@@...@. .....@.@@@@.....
	;;	@....@.@@@@..@.@ .....@.@@@@.....
	;;	.@...@.@@@@.@.@@ .....@.@@@@.....
	;;	@@...@.@@@@.@.@. .....@.@@@@.....
	;;	.@...@.@@@@...@. .....@.@@@@.....
	;;	@@...@.@@@@.@.@@ .....@.@@@@.....
	;;	@.@..@.@@@@.@.@@ .....@.@@@@.....
	;;	.@...@.@@@@.@@.@ .....@.@@@@.....
	;;	.@...@.@@@@.@@.@ .....@.@@@@.....
	;;	@.@..@.@@@@..@@. .....@.@@@@.....
	;;	@....@.@@@@.@@.@ .....@.@@@@.....
	;;	.@...@.@@@@..@.@ .....@.@@@@.....
	;;	@.@..@.@@@@.@@.@ .....@.@@@@.....
	;;	@....@.@@@@...@@ .....@.@@@@.....
	;;	.@@..@.@@@@....@ .....@.@@@@.....
	;;	@.@..@.@@@@..... .....@.@@@@.....
	;;	@@...@.@@@@..... .....@.@@@@.....
	;;	@....@.@@@@..... .....@.@@@@.....
	;;	@@...@.@@@@..... .....@.@@@@.....
	;;	.@...@..@.@..... .....@..@.@.....
	;;	@@...@@..@@..... .....@@..@@.....
	;;	.@....@@@@...... ......@@@@......
	;;	.@.............. ................
	;;	@............... ................
	;;	................ ................

img_wall_20:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &01, &00, &00, &00, &1D, &00
	DEFB &00, &00, &73, &00, &01, &00, &CD, &0C, &07, &00, &3E, &3E, &1C, &00, &F2, &F2
	DEFB &33, &03, &C2, &CA, &6F, &0F, &00, &3C, &DC, &1C, &00, &FE, &DC, &1D, &00, &FE
	DEFB &B2, &32, &00, &7E, &41, &0D, &80, &9E, &60, &08, &60, &66, &50, &04, &18, &1A
	DEFB &58, &02, &06, &06, &44, &01, &08, &00, &46, &00, &08, &80, &59, &00, &08, &40
	DEFB &43, &00, &88, &20, &4C, &00, &48, &10, &51, &00, &E8, &00, &46, &00, &38, &00
	DEFB &58, &00, &C4, &04, &43, &00, &3E, &3E, &6C, &00, &E2, &E2, &33, &03, &82, &9A
	DEFB &0E, &0E, &02, &7A, &38, &39, &02, &FA, &E0, &E7, &02, &9A, &80, &9E, &42, &5A
	DEFB &81, &B9, &C2, &DA, &C0, &DC, &C2, &DA, &60, &6E, &42, &5A, &B0, &37, &42, &5A
	DEFB &58, &1B, &02, &9A, &4C, &0D, &02, &DA, &56, &06, &02, &FA, &93, &03, &02, &7A
	DEFB &95, &01, &82, &BA, &A4, &00, &C2, &DA, &25, &00, &62, &6A, &A9, &00, &34, &34
	DEFB &49, &00, &59, &18, &6A, &00, &40, &04, &92, &00, &40, &1C, &1A, &00, &81, &18
	DEFB &64, &00, &86, &18, &86, &00, &98, &30, &19, &00, &60, &00, &61, &00, &80, &00
	DEFB &86, &00, &00, &00, &18, &00, &00, &00, &60, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	...............@ ................
	;;	...........@@@.@ ................
	;;	.........@@@..@@ ................
	;;	.......@@@..@@.@ ............@@..
	;;	.....@@@..@@@@@. ..........@@@@@.
	;;	...@@@..@@@@..@. ........@@@@..@.
	;;	..@@..@@@@....@. ......@@@@..@.@.
	;;	.@@.@@@@........ ....@@@@..@@@@..
	;;	@@.@@@.......... ...@@@..@@@@@@@.
	;;	@@.@@@.......... ...@@@.@@@@@@@@.
	;;	@.@@..@......... ..@@..@..@@@@@@.
	;;	.@.....@@....... ....@@.@@..@@@@.
	;;	.@@......@@..... ....@....@@..@@.
	;;	.@.@.......@@... .....@.....@@.@.
	;;	.@.@@........@@. ......@......@@.
	;;	.@...@......@... .......@........
	;;	.@...@@.....@... ........@.......
	;;	.@.@@..@....@... .........@......
	;;	.@....@@@...@... ..........@.....
	;;	.@..@@...@..@... ...........@....
	;;	.@.@...@@@@.@... ................
	;;	.@...@@...@@@... ................
	;;	.@.@@...@@...@.. .............@..
	;;	.@....@@..@@@@@. ..........@@@@@.
	;;	.@@.@@..@@@...@. ........@@@...@.
	;;	..@@..@@@.....@. ......@@@..@@.@.
	;;	....@@@.......@. ....@@@..@@@@.@.
	;;	..@@@.........@. ..@@@..@@@@@@.@.
	;;	@@@...........@. @@@..@@@@..@@.@.
	;;	@........@....@. @..@@@@..@.@@.@.
	;;	@......@@@....@. @.@@@..@@@.@@.@.
	;;	@@......@@....@. @@.@@@..@@.@@.@.
	;;	.@@......@....@. .@@.@@@..@.@@.@.
	;;	@.@@.....@....@. ..@@.@@@.@.@@.@.
	;;	.@.@@.........@. ...@@.@@@..@@.@.
	;;	.@..@@........@. ....@@.@@@.@@.@.
	;;	.@.@.@@.......@. .....@@.@@@@@.@.
	;;	@..@..@@......@. ......@@.@@@@.@.
	;;	@..@.@.@@.....@. .......@@.@@@.@.
	;;	@.@..@..@@....@. ........@@.@@.@.
	;;	..@..@.@.@@...@. .........@@.@.@.
	;;	@.@.@..@..@@.@.. ..........@@.@..
	;;	.@..@..@.@.@@..@ ...........@@...
	;;	.@@.@.@..@...... .............@..
	;;	@..@..@..@...... ...........@@@..
	;;	...@@.@.@......@ ...........@@...
	;;	.@@..@..@....@@. ...........@@...
	;;	@....@@.@..@@... ..........@@....
	;;	...@@..@.@@..... ................
	;;	.@@....@@....... ................
	;;	@....@@......... ................
	;;	...@@........... ................
	;;	.@@............. ................
	;;	@............... ................

img_wall_21:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &39, &00
	DEFB &00, &00, &E7, &00, &03, &00, &85, &10, &0E, &00, &20, &68, &39, &01, &20, &6C
	DEFB &60, &03, &90, &B4, &DC, &1D, &90, &B4, &82, &1E, &50, &D6, &61, &07, &48, &5A
	DEFB &98, &01, &A8, &AA, &86, &00, &50, &50, &A1, &00, &86, &06, &A8, &00, &6E, &0E
	DEFB &AA, &00, &2E, &0E, &AA, &00, &2C, &0C, &A8, &00, &60, &00, &A1, &00, &80, &00
	DEFB &86, &00, &20, &28, &98, &00, &60, &68, &E3, &03, &20, &68, &88, &0B, &90, &B4
	DEFB &34, &3D, &90, &B4, &C2, &1E, &50, &D4, &E1, &07, &48, &5A, &98, &01, &A8, &AA
	DEFB &86, &00, &50, &50, &A1, &20, &86, &06, &A8, &28, &6E, &0E, &AA, &2A, &2E, &0E
	DEFB &AA, &2A, &2C, &0C, &A8, &28, &60, &00, &A1, &20, &80, &00, &86, &00, &20, &28
	DEFB &98, &00, &60, &68, &E3, &03, &20, &68, &88, &0B, &90, &B4, &34, &3D, &90, &B4
	DEFB &C2, &1E, &50, &D4, &E1, &07, &48, &5A, &98, &01, &A8, &AA, &86, &00, &50, &50
	DEFB &81, &20, &86, &06, &80, &28, &6E, &0E, &80, &2A, &2E, &0E, &80, &2A, &2D, &0C
	DEFB &80, &28, &62, &00, &81, &20, &98, &00, &86, &00, &60, &00, &99, &00, &80, &00
	DEFB &E6, &00, &00, &00, &98, &00, &00, &00, &60, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ ................
	;;	..........@@@..@ ................
	;;	........@@@..@@@ ................
	;;	......@@@....@.@ ...........@....
	;;	....@@@...@..... .........@@.@...
	;;	..@@@..@..@..... .......@.@@.@@..
	;;	.@@.....@..@.... ......@@@.@@.@..
	;;	@@.@@@..@..@.... ...@@@.@@.@@.@..
	;;	@.....@..@.@.... ...@@@@.@@.@.@@.
	;;	.@@....@.@..@... .....@@@.@.@@.@.
	;;	@..@@...@.@.@... .......@@.@.@.@.
	;;	@....@@..@.@.... .........@.@....
	;;	@.@....@@....@@. .............@@.
	;;	@.@.@....@@.@@@. ............@@@.
	;;	@.@.@.@...@.@@@. ............@@@.
	;;	@.@.@.@...@.@@.. ............@@..
	;;	@.@.@....@@..... ................
	;;	@.@....@@....... ................
	;;	@....@@...@..... ..........@.@...
	;;	@..@@....@@..... .........@@.@...
	;;	@@@...@@..@..... ......@@.@@.@...
	;;	@...@...@..@.... ....@.@@@.@@.@..
	;;	..@@.@..@..@.... ..@@@@.@@.@@.@..
	;;	@@....@..@.@.... ...@@@@.@@.@.@..
	;;	@@@....@.@..@... .....@@@.@.@@.@.
	;;	@..@@...@.@.@... .......@@.@.@.@.
	;;	@....@@..@.@.... .........@.@....
	;;	@.@....@@....@@. ..@..........@@.
	;;	@.@.@....@@.@@@. ..@.@.......@@@.
	;;	@.@.@.@...@.@@@. ..@.@.@.....@@@.
	;;	@.@.@.@...@.@@.. ..@.@.@.....@@..
	;;	@.@.@....@@..... ..@.@...........
	;;	@.@....@@....... ..@.............
	;;	@....@@...@..... ..........@.@...
	;;	@..@@....@@..... .........@@.@...
	;;	@@@...@@..@..... ......@@.@@.@...
	;;	@...@...@..@.... ....@.@@@.@@.@..
	;;	..@@.@..@..@.... ..@@@@.@@.@@.@..
	;;	@@....@..@.@.... ...@@@@.@@.@.@..
	;;	@@@....@.@..@... .....@@@.@.@@.@.
	;;	@..@@...@.@.@... .......@@.@.@.@.
	;;	@....@@..@.@.... .........@.@....
	;;	@......@@....@@. ..@..........@@.
	;;	@........@@.@@@. ..@.@.......@@@.
	;;	@.........@.@@@. ..@.@.@.....@@@.
	;;	@.........@.@@.@ ..@.@.@.....@@..
	;;	@........@@...@. ..@.@...........
	;;	@......@@..@@... ..@.............
	;;	@....@@..@@..... ................
	;;	@..@@..@@....... ................
	;;	@@@..@@......... ................
	;;	@..@@........... ................
	;;	.@@............. ................
	;;	@............... ................

img_wall_22:
	DEFB &00, &00, &00, &00, &00, &10, &00, &00, &00, &18, &00, &00, &00, &3A, &00, &00
	DEFB &00, &1B, &00, &00, &00, &5F, &00, &00, &00, &F4, &18, &00, &00, &F4, &34, &00
	DEFB &00, &A8, &34, &00, &00, &18, &38, &00, &04, &18, &14, &04, &38, &00, &38, &38
	DEFB &14, &04, &15, &01, &38, &38, &39, &01, &14, &00, &18, &00, &34, &00, &E0, &E3
	DEFB &35, &01, &C0, &CC, &35, &01, &00, &30, &58, &40, &04, &C0, &E0, &E3, &34, &00
	DEFB &C0, &CC, &34, &00, &00, &30, &38, &00, &04, &C0, &14, &04, &34, &00, &38, &38
	DEFB &34, &00, &14, &00, &34, &00, &34, &00, &34, &00, &34, &00, &34, &00, &34, &00
	DEFB &38, &00, &34, &00, &14, &04, &34, &00, &38, &38, &34, &00, &14, &00, &34, &00
	DEFB &34, &00, &34, &00, &34, &00, &34, &00, &38, &00, &34, &00, &14, &04, &38, &00
	DEFB &38, &38, &14, &04, &14, &00, &38, &38, &34, &00, &14, &00, &34, &00, &34, &00
	DEFB &34, &00, &34, &00, &34, &00, &35, &01, &34, &00, &35, &01, &34, &00, &58, &40
	DEFB &35, &01, &E0, &E3, &35, &01, &C0, &CC, &35, &01, &00, &30, &58, &40, &04, &C0
	DEFB &E0, &E3, &34, &00, &C0, &CC, &34, &00, &00, &30, &18, &00, &00, &C0, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	;;	................ ................
	;;	................ ...@............
	;;	................ ...@@...........
	;;	................ ..@@@.@.........
	;;	................ ...@@.@@........
	;;	................ .@.@@@@@........
	;;	...........@@... @@@@.@..........
	;;	..........@@.@.. @@@@.@..........
	;;	..........@@.@.. @.@.@...........
	;;	..........@@@... ...@@...........
	;;	.....@.....@.@.. ...@@........@..
	;;	..@@@.....@@@... ..........@@@...
	;;	...@.@.....@.@.@ .....@.........@
	;;	..@@@.....@@@..@ ..@@@..........@
	;;	...@.@.....@@... ................
	;;	..@@.@..@@@..... ........@@@...@@
	;;	..@@.@.@@@...... .......@@@..@@..
	;;	..@@.@.@........ .......@..@@....
	;;	.@.@@........@.. .@......@@......
	;;	@@@.......@@.@.. @@@...@@........
	;;	@@........@@.@.. @@..@@..........
	;;	..........@@@... ..@@............
	;;	.....@.....@.@.. @@...........@..
	;;	..@@.@....@@@... ..........@@@...
	;;	..@@.@.....@.@.. ................
	;;	..@@.@....@@.@.. ................
	;;	..@@.@....@@.@.. ................
	;;	..@@.@....@@.@.. ................
	;;	..@@@.....@@.@.. ................
	;;	...@.@....@@.@.. .....@..........
	;;	..@@@.....@@.@.. ..@@@...........
	;;	...@.@....@@.@.. ................
	;;	..@@.@....@@.@.. ................
	;;	..@@.@....@@.@.. ................
	;;	..@@@.....@@.@.. ................
	;;	...@.@....@@@... .....@..........
	;;	..@@@......@.@.. ..@@@........@..
	;;	...@.@....@@@... ..........@@@...
	;;	..@@.@.....@.@.. ................
	;;	..@@.@....@@.@.. ................
	;;	..@@.@....@@.@.. ................
	;;	..@@.@....@@.@.@ ...............@
	;;	..@@.@....@@.@.@ ...............@
	;;	..@@.@...@.@@... .........@......
	;;	..@@.@.@@@@..... .......@@@@...@@
	;;	..@@.@.@@@...... .......@@@..@@..
	;;	..@@.@.@........ .......@..@@....
	;;	.@.@@........@.. .@......@@......
	;;	@@@.......@@.@.. @@@...@@........
	;;	@@........@@.@.. @@..@@..........
	;;	...........@@... ..@@............
	;;	................ @@..............
	;;	................ ................
	;;	................ ................
	;;	................ ................
	;;	................ ................

img_wall_23:
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &10, &00, &00, &00, &18, &00, &00
	DEFB &00, &3A, &00, &00, &00, &1B, &00, &00, &00, &5F, &00, &00, &00, &F4, &00, &18
	DEFB &00, &F4, &00, &34, &00, &A8, &00, &34, &00, &18, &00, &38, &04, &1C, &04, &14
	DEFB &38, &38, &38, &39, &04, &14, &00, &15, &38, &38, &00, &35, &00, &14, &00, &1B
	DEFB &00, &34, &C0, &C4, &00, &35, &63, &68, &00, &35, &37, &B0, &00, &3B, &5B, &18
	DEFB &C0, &C4, &EA, &08, &63, &68, &E9, &09, &37, &B0, &EE, &0E, &5B, &18, &98, &18
	DEFB &EA, &08, &66, &60, &E9, &09, &9E, &80, &EE, &0E, &BE, &80, &98, &18, &BE, &80
	DEFB &66, &60, &B9, &81, &9E, &80, &A6, &86, &BE, &80, &99, &98, &BE, &80, &EB, &E8
	DEFB &B9, &81, &8B, &88, &A6, &86, &6B, &08, &99, &98, &EA, &08, &EB, &E8, &E9, &09
	DEFB &8B, &88, &EE, &0E, &6B, &08, &98, &18, &EA, &08, &66, &60, &E9, &09, &9E, &80
	DEFB &EE, &0E, &BE, &80, &98, &18, &BE, &80, &66, &60, &B9, &81, &9E, &80, &A6, &86
	DEFB &BE, &80, &99, &98, &BE, &80, &EB, &E8, &B9, &81, &8B, &88, &A6, &86, &6B, &08
	DEFB &99, &98, &EA, &08, &EB, &E8, &E8, &08, &8B, &88, &E0, &00, &6B, &08, &80, &00
	DEFB &EA, &08, &00, &00, &E8, &08, &00, &00, &E0, &00, &00, &00, &80, &00, &00, &00
	;;	................ ................
	;;	................ ................
	;;	................ ...@............
	;;	................ ...@@...........
	;;	................ ..@@@.@.........
	;;	................ ...@@.@@........
	;;	................ .@.@@@@@........
	;;	................ @@@@.@.....@@...
	;;	................ @@@@.@....@@.@..
	;;	................ @.@.@.....@@.@..
	;;	................ ...@@.....@@@...
	;;	.....@.......@.. ...@@@.....@.@..
	;;	..@@@.....@@@... ..@@@.....@@@..@
	;;	.....@.......... ...@.@.....@.@.@
	;;	..@@@........... ..@@@.....@@.@.@
	;;	................ ...@.@.....@@.@@
	;;	........@@...... ..@@.@..@@...@..
	;;	.........@@...@@ ..@@.@.@.@@.@...
	;;	..........@@.@@@ ..@@.@.@@.@@....
	;;	.........@.@@.@@ ..@@@.@@...@@...
	;;	@@......@@@.@.@. @@...@......@...
	;;	.@@...@@@@@.@..@ .@@.@.......@..@
	;;	..@@.@@@@@@.@@@. @.@@........@@@.
	;;	.@.@@.@@@..@@... ...@@......@@...
	;;	@@@.@.@..@@..@@. ....@....@@.....
	;;	@@@.@..@@..@@@@. ....@..@@.......
	;;	@@@.@@@.@.@@@@@. ....@@@.@.......
	;;	@..@@...@.@@@@@. ...@@...@.......
	;;	.@@..@@.@.@@@..@ .@@.....@......@
	;;	@..@@@@.@.@..@@. @.......@....@@.
	;;	@.@@@@@.@..@@..@ @.......@..@@...
	;;	@.@@@@@.@@@.@.@@ @.......@@@.@...
	;;	@.@@@..@@...@.@@ @......@@...@...
	;;	@.@..@@..@@.@.@@ @....@@.....@...
	;;	@..@@..@@@@.@.@. @..@@.......@...
	;;	@@@.@.@@@@@.@..@ @@@.@.......@..@
	;;	@...@.@@@@@.@@@. @...@.......@@@.
	;;	.@@.@.@@@..@@... ....@......@@...
	;;	@@@.@.@..@@..@@. ....@....@@.....
	;;	@@@.@..@@..@@@@. ....@..@@.......
	;;	@@@.@@@.@.@@@@@. ....@@@.@.......
	;;	@..@@...@.@@@@@. ...@@...@.......
	;;	.@@..@@.@.@@@..@ .@@.....@......@
	;;	@..@@@@.@.@..@@. @.......@....@@.
	;;	@.@@@@@.@..@@..@ @.......@..@@...
	;;	@.@@@@@.@@@.@.@@ @.......@@@.@...
	;;	@.@@@..@@...@.@@ @......@@...@...
	;;	@.@..@@..@@.@.@@ @....@@.....@...
	;;	@..@@..@@@@.@.@. @..@@.......@...
	;;	@@@.@.@@@@@.@... @@@.@.......@...
	;;	@...@.@@@@@..... @...@...........
	;;	.@@.@.@@@....... ....@...........
	;;	@@@.@.@......... ....@...........
	;;	@@@.@........... ....@...........
	;;	@@@............. ................
	;;	@............... ................

;; -----------------------------------------------------------------------------------------------------------
img_3x56_bin: 						;; Doorways
img_doorway_L_type_0:				;; SPR_DOORL:      EQU &00
	DEFB &00, &00, &7B, &00, &19, &A5, &00, &33, &6E, &00, &22, &4C, &00, &27, &53, &00
	DEFB &36, &5C, &00, &19, &50, &00, &0E, &6E, &00, &74, &A5, &00, &F1, &B9, &01, &EB
	DEFB &3C, &03, &86, &FF, &03, &5C, &E1, &0F, &5B, &80, &06, &33, &78, &1D, &2F, &7B
	DEFB &0A, &E7, &8F, &3A, &DF, &02, &1A, &CC, &00, &79, &BB, &00, &15, &8B, &D8, &75
	DEFB &7B, &F8, &35, &9C, &10, &71, &7C, &00, &2D, &98, &00, &6B, &77, &60, &2B, &97
	DEFB &E0, &6D, &74, &40, &31, &98, &00, &6D, &70, &00, &2B, &AE, &C0, &6B, &6F, &C0
	DEFB &2B, &B4, &80, &6D, &78, &00, &31, &A0, &00, &6D, &5E, &C0, &2B, &9F, &C0, &6B
	DEFB &68, &80, &2B, &B0, &00, &6D, &60, &00, &31, &9D, &80, &6D, &5F, &80, &2B, &A9
	DEFB &00, &6B, &70, &00, &2B, &A0, &00, &6D, &5E, &00, &31, &9F, &80, &6D, &53, &80
	DEFB &2B, &A2, &00, &6B, &70, &00, &2B, &EE, &00, &75, &5F, &00, &3E, &DB, &80, &39
	DEFB &E2, &00, &0F, &80, &00, &00, &00, &00, &FF, &E6, &03, &FF, &D8, &05, &FF, &B0
	DEFB &0E, &FF, &A8, &0C, &FF, &A0, &13, &FF, &B0, &1C, &FF, &D8, &10, &FF, &8E, &0E
	DEFB &FF, &04, &05, &FE, &00, &01, &FC, &00, &00, &F8, &00, &00, &F0, &00, &00, &E0
	DEFB &00, &06, &E0, &00, &78, &C0, &00, &7B, &C0, &00, &0F, &80, &00, &72, &80, &00
	DEFB &FD, &00, &03, &27, &80, &03, &DB, &00, &03, &FB, &80, &00, &17, &00, &01, &EF
	DEFB &80, &00, &9F, &00, &07, &6F, &80, &07, &EF, &00, &04, &5F, &80, &03, &BF, &00
	DEFB &01, &3F, &80, &0E, &DF, &00, &0F, &DF, &80, &04, &BF, &00, &03, &7F, &80, &01
	DEFB &3F, &00, &1E, &DF, &80, &1F, &DF, &00, &08, &BF, &80, &07, &7F, &00, &02, &7F
	DEFB &80, &1D, &BF, &00, &1F, &BF, &80, &09, &7F, &00, &06, &FF, &80, &01, &FF, &00
	DEFB &1E, &7F, &80, &1F, &BF, &00, &13, &BF, &80, &0A, &7F, &00, &01, &FF, &80, &0E
	DEFB &FF, &00, &1F, &7F, &80, &1B, &BF, &80, &02, &7F, &C0, &1D, &FF, &F0, &7F, &FF
	;;	.................@@@@.@@	@@@@@@@@@@@..@@.......@@
	;;	...........@@..@@.@..@.@	@@@@@@@@@@.@@........@.@
	;;	..........@@..@@.@@.@@@.	@@@@@@@@@.@@........@@@.
	;;	..........@...@..@..@@..	@@@@@@@@@.@.@.......@@..
	;;	..........@..@@@.@.@..@@	@@@@@@@@@.@........@..@@
	;;	..........@@.@@..@.@@@..	@@@@@@@@@.@@.......@@@..
	;;	...........@@..@.@.@....	@@@@@@@@@@.@@......@....
	;;	............@@@..@@.@@@.	@@@@@@@@@...@@@.....@@@.
	;;	.........@@@.@..@.@..@.@	@@@@@@@@.....@.......@.@
	;;	........@@@@...@@.@@@..@	@@@@@@@................@
	;;	.......@@@@.@.@@..@@@@..	@@@@@@..................
	;;	......@@@....@@.@@@@@@@@	@@@@@...................
	;;	......@@.@.@@@..@@@....@	@@@@....................
	;;	....@@@@.@.@@.@@@.......	@@@..................@@.
	;;	.....@@...@@..@@.@@@@...	@@@..............@@@@...
	;;	...@@@.@..@.@@@@.@@@@.@@	@@...............@@@@.@@
	;;	....@.@.@@@..@@@@...@@@@	@@..................@@@@
	;;	..@@@.@.@@.@@@@@......@.	@................@@@..@.
	;;	...@@.@.@@..@@..........	@...............@@@@@@.@
	;;	.@@@@..@@.@@@.@@........	..............@@..@..@@@
	;;	...@.@.@@...@.@@@@.@@...	@.............@@@@.@@.@@
	;;	.@@@.@.@.@@@@.@@@@@@@...	..............@@@@@@@.@@
	;;	..@@.@.@@..@@@.....@....	@..................@.@@@
	;;	.@@@...@.@@@@@..........	...............@@@@.@@@@
	;;	..@.@@.@@..@@...........	@...............@..@@@@@
	;;	.@@.@.@@.@@@.@@@.@@.....	.............@@@.@@.@@@@
	;;	..@.@.@@@..@.@@@@@@.....	@............@@@@@@.@@@@
	;;	.@@.@@.@.@@@.@...@......	.............@...@.@@@@@
	;;	..@@...@@..@@...........	@.............@@@.@@@@@@
	;;	.@@.@@.@.@@@............	...............@..@@@@@@
	;;	..@.@.@@@.@.@@@.@@......	@...........@@@.@@.@@@@@
	;;	.@@.@.@@.@@.@@@@@@......	............@@@@@@.@@@@@
	;;	..@.@.@@@.@@.@..@.......	@............@..@.@@@@@@
	;;	.@@.@@.@.@@@@...........	..............@@.@@@@@@@
	;;	..@@...@@.@.............	@..............@..@@@@@@
	;;	.@@.@@.@.@.@@@@.@@......	...........@@@@.@@.@@@@@
	;;	..@.@.@@@..@@@@@@@......	@..........@@@@@@@.@@@@@
	;;	.@@.@.@@.@@.@...@.......	............@...@.@@@@@@
	;;	..@.@.@@@.@@............	@............@@@.@@@@@@@
	;;	.@@.@@.@.@@.............	..............@..@@@@@@@
	;;	..@@...@@..@@@.@@.......	@..........@@@.@@.@@@@@@
	;;	.@@.@@.@.@.@@@@@@.......	...........@@@@@@.@@@@@@
	;;	..@.@.@@@.@.@..@........	@...........@..@.@@@@@@@
	;;	.@@.@.@@.@@@............	.............@@.@@@@@@@@
	;;	..@.@.@@@.@.............	@..............@@@@@@@@@
	;;	.@@.@@.@.@.@@@@.........	...........@@@@..@@@@@@@
	;;	..@@...@@..@@@@@@.......	@..........@@@@@@.@@@@@@
	;;	.@@.@@.@.@.@..@@@.......	...........@..@@@.@@@@@@
	;;	..@.@.@@@.@...@.........	@...........@.@..@@@@@@@
	;;	.@@.@.@@.@@@............	...............@@@@@@@@@
	;;	..@.@.@@@@@.@@@.........	@...........@@@.@@@@@@@@
	;;	.@@@.@.@.@.@@@@@........	...........@@@@@.@@@@@@@
	;;	..@@@@@.@@.@@.@@@.......	@..........@@.@@@.@@@@@@
	;;	..@@@..@@@@...@.........	@.............@..@@@@@@@
	;;	....@@@@@...............	@@.........@@@.@@@@@@@@@
	;;	........................	@@@@.....@@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &00, &03, &00, &00, &05, &38, &00, &64, &0C, &00, &54
	DEFB &04, &00, &17, &04, &00, &1C, &EC, &00, &00, &14, &00, &01, &CA, &00, &00, &A5
	DEFB &80, &00, &65, &40, &00, &15, &70, &00, &34, &A0, &00, &15, &FC, &00, &65, &30
	DEFB &00, &AA, &DE, &00, &88, &E8, &00, &33, &EE, &00, &C7, &5C, &00, &2B, &1E, &00
	DEFB &6C, &AC, &00, &CB, &76, &00, &2B, &F4, &00, &0B, &EE, &00, &ED, &0C, &03, &E8
	DEFB &B6, &03, &4B, &74, &00, &2B, &F6, &00, &0C, &8C, &03, &68, &0E, &03, &EB, &74
	DEFB &00, &8B, &F6, &00, &2D, &0C, &03, &48, &8E, &03, &EB, &74, &00, &AB, &F6, &00
	DEFB &09, &0C, &03, &6C, &0E, &03, &E9, &B4, &01, &2B, &F6, &00, &0D, &B4, &01, &6E
	DEFB &0E, &03, &EE, &F4, &03, &0D, &D6, &00, &2D, &4C, &00, &F6, &96, &01, &D9, &74
	DEFB &01, &46, &EC, &00, &01, &D8, &00, &01, &40, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FC, &FF, &FF, &F8, &47
	DEFB &FF, &90, &3B, &FF, &00, &CD, &FF, &00, &F5, &FF, &80, &15, &FF, &A0, &0D, &FF
	DEFB &00, &05, &FF, &01, &C0, &7F, &FE, &A0, &3F, &FE, &60, &0F, &FE, &10, &07, &FE
	DEFB &30, &03, &FE, &10, &01, &FE, &60, &01, &FE, &A0, &C0, &FE, &80, &E1, &FE, &03
	DEFB &E0, &FE, &07, &41, &FF, &23, &00, &FF, &60, &21, &FE, &C3, &70, &FF, &03, &F1
	DEFB &FF, &03, &E0, &FC, &E1, &01, &FB, &E0, &30, &FB, &43, &71, &FC, &83, &F0, &FC
	DEFB &80, &81, &FB, &60, &00, &FB, &E3, &71, &FC, &83, &F0, &FC, &01, &01, &FB, &40
	DEFB &00, &FB, &E3, &71, &FC, &A3, &F0, &FC, &01, &01, &FB, &60, &00, &FB, &E1, &B1
	DEFB &FD, &23, &F0, &FE, &81, &B1, &FD, &60, &00, &FB, &E0, &F1, &FB, &01, &D0, &FC
	DEFB &21, &41, &FE, &F0, &10, &FD, &D0, &71, &FD, &40, &E1, &FE, &B9, &C3, &FF, &FD
	DEFB &47, &FF, &FE, &BF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@..@@@@@@@@@@@@@@@@
	;;	......@@................	@@@@@....@...@@@@@@@@@@@
	;;	.....@.@..@@@...........	@..@......@@@.@@@@@@@@@@
	;;	.@@..@......@@..........	........@@..@@.@@@@@@@@@
	;;	.@.@.@.......@..........	........@@@@.@.@@@@@@@@@
	;;	...@.@@@.....@..........	@..........@.@.@@@@@@@@@
	;;	...@@@..@@@.@@..........	@.@.........@@.@@@@@@@@@
	;;	...........@.@..........	.............@.@@@@@@@@@
	;;	.......@@@..@.@.........	.......@@@.......@@@@@@@
	;;	........@.@..@.@@.......	@@@@@@@.@.@.......@@@@@@
	;;	.........@@..@.@.@......	@@@@@@@..@@.........@@@@
	;;	...........@.@.@.@@@....	@@@@@@@....@.........@@@
	;;	..........@@.@..@.@.....	@@@@@@@...@@..........@@
	;;	...........@.@.@@@@@@@..	@@@@@@@....@...........@
	;;	.........@@..@.@..@@....	@@@@@@@..@@............@
	;;	........@.@.@.@.@@.@@@@.	@@@@@@@.@.@.....@@......
	;;	........@...@...@@@.@...	@@@@@@@.@.......@@@....@
	;;	..........@@..@@@@@.@@@.	@@@@@@@.......@@@@@.....
	;;	........@@...@@@.@.@@@..	@@@@@@@......@@@.@.....@
	;;	..........@.@.@@...@@@@.	@@@@@@@@..@...@@........
	;;	.........@@.@@..@.@.@@..	@@@@@@@@.@@.......@....@
	;;	........@@..@.@@.@@@.@@.	@@@@@@@.@@....@@.@@@....
	;;	..........@.@.@@@@@@.@..	@@@@@@@@......@@@@@@...@
	;;	............@.@@@@@.@@@.	@@@@@@@@......@@@@@.....
	;;	........@@@.@@.@....@@..	@@@@@@..@@@....@.......@
	;;	......@@@@@.@...@.@@.@@.	@@@@@.@@@@@.......@@....
	;;	......@@.@..@.@@.@@@.@..	@@@@@.@@.@....@@.@@@...@
	;;	..........@.@.@@@@@@.@@.	@@@@@@..@.....@@@@@@....
	;;	............@@..@...@@..	@@@@@@..@.......@......@
	;;	......@@.@@.@.......@@@.	@@@@@.@@.@@.............
	;;	......@@@@@.@.@@.@@@.@..	@@@@@.@@@@@...@@.@@@...@
	;;	........@...@.@@@@@@.@@.	@@@@@@..@.....@@@@@@....
	;;	..........@.@@.@....@@..	@@@@@@.........@.......@
	;;	......@@.@..@...@...@@@.	@@@@@.@@.@..............
	;;	......@@@@@.@.@@.@@@.@..	@@@@@.@@@@@...@@.@@@...@
	;;	........@.@.@.@@@@@@.@@.	@@@@@@..@.@...@@@@@@....
	;;	............@..@....@@..	@@@@@@.........@.......@
	;;	......@@.@@.@@......@@@.	@@@@@.@@.@@.............
	;;	......@@@@@.@..@@.@@.@..	@@@@@.@@@@@....@@.@@...@
	;;	.......@..@.@.@@@@@@.@@.	@@@@@@.@..@...@@@@@@....
	;;	............@@.@@.@@.@..	@@@@@@@.@......@@.@@...@
	;;	.......@.@@.@@@.....@@@.	@@@@@@.@.@@.............
	;;	......@@@@@.@@@.@@@@.@..	@@@@@.@@@@@.....@@@@...@
	;;	......@@....@@.@@@.@.@@.	@@@@@.@@.......@@@.@....
	;;	..........@.@@.@.@..@@..	@@@@@@....@....@.@.....@
	;;	........@@@@.@@.@..@.@@.	@@@@@@@.@@@@.......@....
	;;	.......@@@.@@..@.@@@.@..	@@@@@@.@@@.@.....@@@...@
	;;	.......@.@...@@.@@@.@@..	@@@@@@.@.@......@@@....@
	;;	...............@@@.@@...	@@@@@@@.@.@@@..@@@....@@
	;;	...............@.@......	@@@@@@@@@@@@@@.@.@...@@@
	;;	........................	@@@@@@@@@@@@@@@.@.@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

	DEFB &00, &00, &69, &00, &01, &A6, &00, &02, &9A, &01, &E6, &69, &07, &79, &A5, &0E
	DEFB &7D, &4A, &1D, &7E, &A5, &1E, &BE, &6A, &3F, &5F, &15, &3C, &3F, &22, &3D, &7F
	DEFB &55, &3C, &9F, &26, &1F, &5E, &CB, &1E, &1E, &1C, &0F, &3D, &A8, &17, &F8, &50
	DEFB &29, &E1, &60, &32, &06, &C0, &1C, &D5, &40, &67, &08, &A0, &39, &64, &A0, &4E
	DEFB &2B, &20, &72, &D5, &20, &1C, &A5, &20, &66, &9A, &A0, &39, &6A, &A0, &4E, &92
	DEFB &A0, &72, &AD, &A0, &1C, &B5, &A0, &66, &D5, &A0, &38, &AD, &A0, &4E, &95, &A0
	DEFB &72, &A9, &A0, &1C, &D5, &A0, &66, &A9, &A0, &38, &D5, &A0, &4E, &D9, &A0, &72
	DEFB &AB, &A0, &1D, &DB, &40, &66, &AC, &40, &38, &95, &80, &4E, &E4, &00, &72, &A2
	DEFB &00, &1C, &94, &00, &66, &BA, &00, &39, &C4, &00, &4E, &D4, &00, &72, &AA, &00
	DEFB &1C, &94, &00, &66, &AA, &00, &38, &54, &00, &4E, &26, &00, &72, &D8, &00, &1C
	DEFB &60, &00, &06, &80, &00, &00, &00, &00, &FF, &FE, &69, &FF, &FD, &A6, &FE, &1A
	DEFB &9A, &F8, &06, &69, &F0, &01, &A5, &E0, &01, &4A, &C1, &00, &A5, &C0, &80, &6A
	DEFB &80, &40, &15, &80, &00, &22, &81, &00, &55, &80, &80, &26, &C0, &40, &CB, &C0
	DEFB &00, &1C, &E0, &01, &AB, &D0, &00, &57, &A8, &01, &6F, &B2, &06, &DF, &9C, &D5
	DEFB &5F, &67, &08, &8F, &B9, &64, &8F, &4E, &2B, &0F, &72, &D5, &0F, &9C, &A5, &0F
	DEFB &66, &9A, &0F, &B9, &6A, &0F, &4E, &92, &0F, &72, &AC, &0F, &9C, &B4, &0F, &66
	DEFB &D4, &0F, &B8, &AC, &0F, &4E, &94, &0F, &72, &A8, &0F, &9C, &D4, &0F, &66, &A8
	DEFB &0F, &B8, &D4, &0F, &4E, &D8, &0F, &72, &A8, &0F, &9D, &D8, &1F, &66, &AC, &1F
	DEFB &B8, &94, &3F, &4E, &E4, &7F, &72, &A2, &FF, &9C, &95, &FF, &66, &BA, &FF, &B9
	DEFB &C5, &FF, &4E, &D5, &FF, &72, &AA, &FF, &9C, &95, &FF, &66, &AA, &FF, &B8, &55
	DEFB &FF, &4E, &26, &FF, &72, &D9, &FF, &9C, &67, &FF, &E6, &9F, &FF, &F9, &7F, &FF
	;;	.................@@.@..@	@@@@@@@@@@@@@@@..@@.@..@
	;;	...............@@.@..@@.	@@@@@@@@@@@@@@.@@.@..@@.
	;;	..............@.@..@@.@.	@@@@@@@....@@.@.@..@@.@.
	;;	.......@@@@..@@..@@.@..@	@@@@@........@@..@@.@..@
	;;	.....@@@.@@@@..@@.@..@.@	@@@@...........@@.@..@.@
	;;	....@@@..@@@@@.@.@..@.@.	@@@............@.@..@.@.
	;;	...@@@.@.@@@@@@.@.@..@.@	@@.....@........@.@..@.@
	;;	...@@@@.@.@@@@@..@@.@.@.	@@......@........@@.@.@.
	;;	..@@@@@@.@.@@@@@...@.@.@	@........@.........@.@.@
	;;	..@@@@....@@@@@@..@...@.	@.................@...@.
	;;	..@@@@.@.@@@@@@@.@.@.@.@	@......@.........@.@.@.@
	;;	..@@@@..@..@@@@@..@..@@.	@.......@.........@..@@.
	;;	...@@@@@.@.@@@@.@@..@.@@	@@.......@......@@..@.@@
	;;	...@@@@....@@@@....@@@..	@@.................@@@..
	;;	....@@@@..@@@@.@@.@.@...	@@@............@@.@.@.@@
	;;	...@.@@@@@@@@....@.@....	@@.@.............@.@.@@@
	;;	..@.@..@@@@....@.@@.....	@.@.@..........@.@@.@@@@
	;;	..@@..@......@@.@@......	@.@@..@......@@.@@.@@@@@
	;;	...@@@..@@.@.@.@.@......	@..@@@..@@.@.@.@.@.@@@@@
	;;	.@@..@@@....@...@.@.....	.@@..@@@....@...@...@@@@
	;;	..@@@..@.@@..@..@.@.....	@.@@@..@.@@..@..@...@@@@
	;;	.@..@@@...@.@.@@..@.....	.@..@@@...@.@.@@....@@@@
	;;	.@@@..@.@@.@.@.@..@.....	.@@@..@.@@.@.@.@....@@@@
	;;	...@@@..@.@..@.@..@.....	@..@@@..@.@..@.@....@@@@
	;;	.@@..@@.@..@@.@.@.@.....	.@@..@@.@..@@.@.....@@@@
	;;	..@@@..@.@@.@.@.@.@.....	@.@@@..@.@@.@.@.....@@@@
	;;	.@..@@@.@..@..@.@.@.....	.@..@@@.@..@..@.....@@@@
	;;	.@@@..@.@.@.@@.@@.@.....	.@@@..@.@.@.@@......@@@@
	;;	...@@@..@.@@.@.@@.@.....	@..@@@..@.@@.@......@@@@
	;;	.@@..@@.@@.@.@.@@.@.....	.@@..@@.@@.@.@......@@@@
	;;	..@@@...@.@.@@.@@.@.....	@.@@@...@.@.@@......@@@@
	;;	.@..@@@.@..@.@.@@.@.....	.@..@@@.@..@.@......@@@@
	;;	.@@@..@.@.@.@..@@.@.....	.@@@..@.@.@.@.......@@@@
	;;	...@@@..@@.@.@.@@.@.....	@..@@@..@@.@.@......@@@@
	;;	.@@..@@.@.@.@..@@.@.....	.@@..@@.@.@.@.......@@@@
	;;	..@@@...@@.@.@.@@.@.....	@.@@@...@@.@.@......@@@@
	;;	.@..@@@.@@.@@..@@.@.....	.@..@@@.@@.@@.......@@@@
	;;	.@@@..@.@.@.@.@@@.@.....	.@@@..@.@.@.@.......@@@@
	;;	...@@@.@@@.@@.@@.@......	@..@@@.@@@.@@......@@@@@
	;;	.@@..@@.@.@.@@...@......	.@@..@@.@.@.@@.....@@@@@
	;;	..@@@...@..@.@.@@.......	@.@@@...@..@.@....@@@@@@
	;;	.@..@@@.@@@..@..........	.@..@@@.@@@..@...@@@@@@@
	;;	.@@@..@.@.@...@.........	.@@@..@.@.@...@.@@@@@@@@
	;;	...@@@..@..@.@..........	@..@@@..@..@.@.@@@@@@@@@
	;;	.@@..@@.@.@@@.@.........	.@@..@@.@.@@@.@.@@@@@@@@
	;;	..@@@..@@@...@..........	@.@@@..@@@...@.@@@@@@@@@
	;;	.@..@@@.@@.@.@..........	.@..@@@.@@.@.@.@@@@@@@@@
	;;	.@@@..@.@.@.@.@.........	.@@@..@.@.@.@.@.@@@@@@@@
	;;	...@@@..@..@.@..........	@..@@@..@..@.@.@@@@@@@@@
	;;	.@@..@@.@.@.@.@.........	.@@..@@.@.@.@.@.@@@@@@@@
	;;	..@@@....@.@.@..........	@.@@@....@.@.@.@@@@@@@@@
	;;	.@..@@@...@..@@.........	.@..@@@...@..@@.@@@@@@@@
	;;	.@@@..@.@@.@@...........	.@@@..@.@@.@@..@@@@@@@@@
	;;	...@@@...@@.............	@..@@@...@@..@@@@@@@@@@@
	;;	.....@@.@...............	@@@..@@.@..@@@@@@@@@@@@@
	;;	........................	@@@@@..@.@@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &03, &C0, &00, &0F, &70, &00, &1E, &78, &00, &3D, &7C, &00
	DEFB &3E, &BC, &00, &7F, &5E, &1B, &9C, &3E, &79, &2D, &7E, &86, &D4, &9E, &05, &57
	DEFB &5C, &02, &AA, &1C, &01, &15, &38, &02, &A4, &F4, &01, &4A, &04, &02, &55, &1A
	DEFB &00, &A5, &62, &01, &5A, &54, &00, &A2, &AA, &00, &75, &2C, &00, &8E, &B2, &00
	DEFB &53, &58, &00, &D0, &86, &00, &D2, &74, &00, &D3, &4A, &00, &D3, &48, &00, &D3
	DEFB &56, &00, &D3, &4A, &00, &D3, &14, &00, &D3, &6C, &00, &D3, &4A, &00, &D3, &36
	DEFB &00, &D3, &4A, &00, &D3, &6A, &00, &D3, &54, &00, &D3, &4A, &00, &D3, &6A, &00
	DEFB &D0, &54, &00, &D3, &6A, &00, &D6, &6C, &00, &69, &5A, &00, &77, &62, &00, &3E
	DEFB &5A, &00, &48, &64, &00, &50, &9A, &00, &5E, &A4, &00, &5E, &DA, &00, &5E, &A4
	DEFB &00, &5E, &C8, &00, &66, &B0, &00, &18, &C0, &00, &07, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FC, &3F, &FF, &F0, &0F, &FF, &E0
	DEFB &07, &FF, &C0, &03, &FF, &81, &01, &FF, &80, &81, &E4, &00, &40, &9B, &80, &00
	DEFB &79, &21, &00, &86, &D0, &80, &75, &50, &41, &FA, &A8, &01, &F9, &14, &03, &FA
	DEFB &A4, &05, &F9, &4A, &05, &FA, &55, &1A, &FC, &A5, &62, &FD, &5A, &55, &FE, &A2
	DEFB &AA, &FE, &75, &2D, &FE, &8E, &B2, &FE, &03, &59, &FE, &00, &86, &FE, &02, &75
	DEFB &FE, &01, &4A, &FE, &02, &49, &FE, &01, &56, &FE, &02, &4A, &FE, &01, &15, &FE
	DEFB &02, &6D, &FE, &01, &4A, &FE, &02, &36, &FE, &01, &4A, &FE, &02, &6A, &FE, &01
	DEFB &55, &FE, &02, &4A, &FE, &01, &6A, &FE, &00, &55, &FE, &00, &6A, &FE, &00, &6D
	DEFB &FF, &00, &5A, &FF, &00, &62, &FF, &80, &5A, &FF, &40, &65, &FF, &50, &9A, &FF
	DEFB &4A, &A5, &FF, &54, &DA, &FF, &4A, &A5, &FF, &54, &CB, &FF, &62, &B7, &FF, &98
	DEFB &CF, &FF, &E7, &3F, &FF, &F8, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@....@@@@@@
	;;	..............@@@@......	@@@@@@@@@@@@........@@@@
	;;	............@@@@.@@@....	@@@@@@@@@@@..........@@@
	;;	...........@@@@..@@@@...	@@@@@@@@@@............@@
	;;	..........@@@@.@.@@@@@..	@@@@@@@@@......@.......@
	;;	..........@@@@@.@.@@@@..	@@@@@@@@@.......@......@
	;;	.........@@@@@@@.@.@@@@.	@@@..@...........@......
	;;	...@@.@@@..@@@....@@@@@.	@..@@.@@@...............
	;;	.@@@@..@..@.@@.@.@@@@@@.	.@@@@..@..@....@........
	;;	@....@@.@@.@.@..@..@@@@.	@....@@.@@.@....@.......
	;;	.....@.@.@.@.@@@.@.@@@..	.@@@.@.@.@.@.....@.....@
	;;	......@.@.@.@.@....@@@..	@@@@@.@.@.@.@..........@
	;;	.......@...@.@.@..@@@...	@@@@@..@...@.@........@@
	;;	......@.@.@..@..@@@@.@..	@@@@@.@.@.@..@.......@.@
	;;	.......@.@..@.@......@..	@@@@@..@.@..@.@......@.@
	;;	......@..@.@.@.@...@@.@.	@@@@@.@..@.@.@.@...@@.@.
	;;	........@.@..@.@.@@...@.	@@@@@@..@.@..@.@.@@...@.
	;;	.......@.@.@@.@..@.@.@..	@@@@@@.@.@.@@.@..@.@.@.@
	;;	........@.@...@.@.@.@.@.	@@@@@@@.@.@...@.@.@.@.@.
	;;	.........@@@.@.@..@.@@..	@@@@@@@..@@@.@.@..@.@@.@
	;;	........@...@@@.@.@@..@.	@@@@@@@.@...@@@.@.@@..@.
	;;	.........@.@..@@.@.@@...	@@@@@@@.......@@.@.@@..@
	;;	........@@.@....@....@@.	@@@@@@@.........@....@@.
	;;	........@@.@..@..@@@.@..	@@@@@@@.......@..@@@.@.@
	;;	........@@.@..@@.@..@.@.	@@@@@@@........@.@..@.@.
	;;	........@@.@..@@.@..@...	@@@@@@@.......@..@..@..@
	;;	........@@.@..@@.@.@.@@.	@@@@@@@........@.@.@.@@.
	;;	........@@.@..@@.@..@.@.	@@@@@@@.......@..@..@.@.
	;;	........@@.@..@@...@.@..	@@@@@@@........@...@.@.@
	;;	........@@.@..@@.@@.@@..	@@@@@@@.......@..@@.@@.@
	;;	........@@.@..@@.@..@.@.	@@@@@@@........@.@..@.@.
	;;	........@@.@..@@..@@.@@.	@@@@@@@.......@...@@.@@.
	;;	........@@.@..@@.@..@.@.	@@@@@@@........@.@..@.@.
	;;	........@@.@..@@.@@.@.@.	@@@@@@@.......@..@@.@.@.
	;;	........@@.@..@@.@.@.@..	@@@@@@@........@.@.@.@.@
	;;	........@@.@..@@.@..@.@.	@@@@@@@.......@..@..@.@.
	;;	........@@.@..@@.@@.@.@.	@@@@@@@........@.@@.@.@.
	;;	........@@.@.....@.@.@..	@@@@@@@..........@.@.@.@
	;;	........@@.@..@@.@@.@.@.	@@@@@@@..........@@.@.@.
	;;	........@@.@.@@..@@.@@..	@@@@@@@..........@@.@@.@
	;;	.........@@.@..@.@.@@.@.	@@@@@@@@.........@.@@.@.
	;;	.........@@@.@@@.@@...@.	@@@@@@@@.........@@...@.
	;;	..........@@@@@..@.@@.@.	@@@@@@@@@........@.@@.@.
	;;	.........@..@....@@..@..	@@@@@@@@.@.......@@..@.@
	;;	.........@.@....@..@@.@.	@@@@@@@@.@.@....@..@@.@.
	;;	.........@.@@@@.@.@..@..	@@@@@@@@.@..@.@.@.@..@.@
	;;	.........@.@@@@.@@.@@.@.	@@@@@@@@.@.@.@..@@.@@.@.
	;;	.........@.@@@@.@.@..@..	@@@@@@@@.@..@.@.@.@..@.@
	;;	.........@.@@@@.@@..@...	@@@@@@@@.@.@.@..@@..@.@@
	;;	.........@@..@@.@.@@....	@@@@@@@@.@@...@.@.@@.@@@
	;;	...........@@...@@......	@@@@@@@@@..@@...@@..@@@@
	;;	.............@@@........	@@@@@@@@@@@..@@@..@@@@@@
	;;	........................	@@@@@@@@@@@@@...@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

	DEFB &00, &00, &E3, &00, &01, &97, &00, &23, &4C, &00, &36, &98, &00, &39, &58, &00
	DEFB &3E, &B0, &00, &3E, &50, &00, &3E, &B0, &00, &3E, &A0, &00, &5C, &B0, &00, &E1
	DEFB &30, &01, &1E, &D8, &03, &E7, &DC, &01, &F9, &AE, &06, &3E, &CB, &0F, &CF, &50
	DEFB &01, &F7, &68, &1E, &7B, &60, &1F, &9D, &A0, &21, &ED, &80, &3E, &76, &80, &43
	DEFB &B6, &80, &48, &DB, &00, &58, &6B, &00, &2C, &AD, &00, &2B, &56, &00, &28, &56
	DEFB &00, &58, &5A, &00, &2C, &AC, &00, &2B, &54, &00, &28, &54, &00, &58, &58, &00
	DEFB &2C, &AC, &00, &2B, &54, &00, &28, &54, &00, &58, &58, &00, &2C, &AC, &00, &4B
	DEFB &54, &00, &48, &54, &00, &28, &58, &00, &5C, &AE, &00, &2B, &56, &00, &48, &76
	DEFB &00, &48, &58, &00, &44, &92, &00, &31, &44, &00, &4C, &12, &00, &33, &CC, &00
	DEFB &4C, &32, &00, &73, &CE, &00, &3C, &3C, &00, &4F, &F2, &00, &33, &CC, &00, &0C
	DEFB &30, &00, &03, &C0, &00, &00, &00, &00, &FF, &FE, &00, &FF, &DC, &00, &FF, &A8
	DEFB &00, &FF, &B0, &00, &FF, &B8, &00, &FF, &BE, &00, &FF, &BE, &00, &FF, &BE, &00
	DEFB &FF, &BE, &00, &FF, &1C, &00, &FE, &00, &00, &FC, &00, &00, &F8, &00, &00, &F8
	DEFB &00, &00, &F0, &00, &00, &E0, &00, &04, &E0, &00, &03, &C0, &00, &07, &C0, &00
	DEFB &0F, &80, &00, &1F, &80, &00, &3F, &00, &00, &3F, &08, &00, &7F, &18, &00, &7F
	DEFB &8C, &80, &7F, &8B, &00, &FF, &88, &00, &FF, &18, &00, &FF, &8C, &81, &FF, &8B
	DEFB &01, &FF, &88, &01, &FF, &18, &03, &FF, &8C, &81, &FF, &8B, &01, &FF, &88, &01
	DEFB &FF, &18, &03, &FF, &8C, &81, &FF, &0B, &01, &FF, &08, &01, &FF, &88, &01, &FF
	DEFB &1C, &80, &FF, &8B, &00, &FF, &08, &00, &FF, &08, &01, &FF, &04, &00, &FF, &80
	DEFB &01, &FF, &00, &00, &FF, &80, &01, &FF, &40, &02, &FF, &70, &0E, &FF, &BC, &3D
	DEFB &FF, &0F, &F0, &FF, &83, &C1, &FF, &C0, &03, &FF, &F0, &0F, &FF, &FC, &3F, &FF
	;;	................@@@...@@	@@@@@@@@@@@@@@@.........
	;;	...............@@..@.@@@	@@@@@@@@@@.@@@..........
	;;	..........@...@@.@..@@..	@@@@@@@@@.@.@...........
	;;	..........@@.@@.@..@@...	@@@@@@@@@.@@............
	;;	..........@@@..@.@.@@...	@@@@@@@@@.@@@...........
	;;	..........@@@@@.@.@@....	@@@@@@@@@.@@@@@.........
	;;	..........@@@@@..@.@....	@@@@@@@@@.@@@@@.........
	;;	..........@@@@@.@.@@....	@@@@@@@@@.@@@@@.........
	;;	..........@@@@@.@.@.....	@@@@@@@@@.@@@@@.........
	;;	.........@.@@@..@.@@....	@@@@@@@@...@@@..........
	;;	........@@@....@..@@....	@@@@@@@.................
	;;	.......@...@@@@.@@.@@...	@@@@@@..................
	;;	......@@@@@..@@@@@.@@@..	@@@@@...................
	;;	.......@@@@@@..@@.@.@@@.	@@@@@...................
	;;	.....@@...@@@@@.@@..@.@@	@@@@....................
	;;	....@@@@@@..@@@@.@.@....	@@@..................@..
	;;	.......@@@@@.@@@.@@.@...	@@@...................@@
	;;	...@@@@..@@@@.@@.@@.....	@@...................@@@
	;;	...@@@@@@..@@@.@@.@.....	@@..................@@@@
	;;	..@....@@@@.@@.@@.......	@..................@@@@@
	;;	..@@@@@..@@@.@@.@.......	@.................@@@@@@
	;;	.@....@@@.@@.@@.@.......	..................@@@@@@
	;;	.@..@...@@.@@.@@........	....@............@@@@@@@
	;;	.@.@@....@@.@.@@........	...@@............@@@@@@@
	;;	..@.@@..@.@.@@.@........	@...@@..@........@@@@@@@
	;;	..@.@.@@.@.@.@@.........	@...@.@@........@@@@@@@@
	;;	..@.@....@.@.@@.........	@...@...........@@@@@@@@
	;;	.@.@@....@.@@.@.........	...@@...........@@@@@@@@
	;;	..@.@@..@.@.@@..........	@...@@..@......@@@@@@@@@
	;;	..@.@.@@.@.@.@..........	@...@.@@.......@@@@@@@@@
	;;	..@.@....@.@.@..........	@...@..........@@@@@@@@@
	;;	.@.@@....@.@@...........	...@@.........@@@@@@@@@@
	;;	..@.@@..@.@.@@..........	@...@@..@......@@@@@@@@@
	;;	..@.@.@@.@.@.@..........	@...@.@@.......@@@@@@@@@
	;;	..@.@....@.@.@..........	@...@..........@@@@@@@@@
	;;	.@.@@....@.@@...........	...@@.........@@@@@@@@@@
	;;	..@.@@..@.@.@@..........	@...@@..@......@@@@@@@@@
	;;	.@..@.@@.@.@.@..........	....@.@@.......@@@@@@@@@
	;;	.@..@....@.@.@..........	....@..........@@@@@@@@@
	;;	..@.@....@.@@...........	@...@..........@@@@@@@@@
	;;	.@.@@@..@.@.@@@.........	...@@@..@.......@@@@@@@@
	;;	..@.@.@@.@.@.@@.........	@...@.@@........@@@@@@@@
	;;	.@..@....@@@.@@.........	....@...........@@@@@@@@
	;;	.@..@....@.@@...........	....@..........@@@@@@@@@
	;;	.@...@..@..@..@.........	.....@..........@@@@@@@@
	;;	..@@...@.@...@..........	@..............@@@@@@@@@
	;;	.@..@@.....@..@.........	................@@@@@@@@
	;;	..@@..@@@@..@@..........	@..............@@@@@@@@@
	;;	.@..@@....@@..@.........	.@............@.@@@@@@@@
	;;	.@@@..@@@@..@@@.........	.@@@........@@@.@@@@@@@@
	;;	..@@@@....@@@@..........	@.@@@@....@@@@.@@@@@@@@@
	;;	.@..@@@@@@@@..@.........	....@@@@@@@@....@@@@@@@@
	;;	..@@..@@@@..@@..........	@.....@@@@.....@@@@@@@@@
	;;	....@@....@@............	@@............@@@@@@@@@@
	;;	......@@@@..............	@@@@........@@@@@@@@@@@@
	;;	........................	@@@@@@....@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &08, &00, &00, &0C, &00, &00
	DEFB &1C, &00, &00, &3C, &00, &3E, &7C, &00, &03, &9C, &00, &00, &EC, &00, &00, &35
	DEFB &00, &00, &1B, &40, &00, &8D, &40, &00, &0D, &50, &00, &C5, &50, &00, &05, &50
	DEFB &00, &04, &D4, &00, &05, &B4, &00, &04, &AC, &00, &0D, &68, &00, &0B, &58, &00
	DEFB &B9, &B4, &00, &E2, &AC, &00, &50, &A8, &00, &29, &58, &00, &5A, &B4, &00, &48
	DEFB &AC, &00, &48, &A8, &00, &29, &58, &00, &5A, &B4, &00, &48, &AC, &00, &48, &A8
	DEFB &00, &29, &58, &00, &5A, &B4, &00, &48, &AC, &00, &48, &A8, &00, &29, &98, &00
	DEFB &DB, &74, &00, &91, &6C, &00, &91, &6C, &00, &91, &58, &00, &81, &54, &00, &41
	DEFB &48, &00, &93, &24, &00, &64, &98, &00, &98, &64, &00, &E7, &9C, &00, &78, &78
	DEFB &00, &9F, &E4, &00, &67, &98, &00, &18, &60, &00, &07, &80, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F7
	DEFB &FF, &FF, &EB, &FF, &FF, &ED, &FF, &FF, &DD, &FF, &C1, &BD, &FF, &00, &7D, &FF
	DEFB &00, &1D, &FF, &00, &0C, &FF, &00, &04, &3F, &80, &00, &1F, &E0, &80, &0F, &F8
	DEFB &00, &07, &F8, &C0, &07, &F8, &00, &03, &F8, &00, &01, &F8, &00, &01, &F8, &00
	DEFB &01, &F8, &00, &03, &FC, &00, &03, &FC, &00, &01, &FC, &02, &01, &FC, &10, &03
	DEFB &FF, &88, &03, &FF, &1A, &01, &FF, &08, &01, &FF, &08, &03, &FF, &88, &03, &FF
	DEFB &1A, &01, &FF, &08, &01, &FF, &08, &03, &FF, &88, &03, &FF, &1A, &01, &FF, &08
	DEFB &01, &FF, &08, &03, &FF, &08, &03, &FE, &18, &01, &FE, &10, &01, &FE, &10, &01
	DEFB &FE, &10, &03, &FE, &00, &01, &FF, &00, &03, &FE, &00, &01, &FF, &00, &03, &FE
	DEFB &80, &05, &FE, &E0, &1D, &FF, &78, &7B, &FE, &1F, &E1, &FF, &07, &83, &FF, &80
	DEFB &07, &FF, &E0, &1F, &FF, &F8, &7F, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@.@@@@@@@@@@@
	;;	............@...........	@@@@@@@@@@@.@.@@@@@@@@@@
	;;	............@@..........	@@@@@@@@@@@.@@.@@@@@@@@@
	;;	...........@@@..........	@@@@@@@@@@.@@@.@@@@@@@@@
	;;	..........@@@@..........	@@.....@@.@@@@.@@@@@@@@@
	;;	..@@@@@..@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	......@@@..@@@..........	...........@@@.@@@@@@@@@
	;;	........@@@.@@..........	............@@..@@@@@@@@
	;;	..........@@.@.@........	.............@....@@@@@@
	;;	...........@@.@@.@......	@..................@@@@@
	;;	........@...@@.@.@......	@@@.....@...........@@@@
	;;	............@@.@.@.@....	@@@@@................@@@
	;;	........@@...@.@.@.@....	@@@@@...@@...........@@@
	;;	.............@.@.@.@....	@@@@@.................@@
	;;	.............@..@@.@.@..	@@@@@..................@
	;;	.............@.@@.@@.@..	@@@@@..................@
	;;	.............@..@.@.@@..	@@@@@..................@
	;;	............@@.@.@@.@...	@@@@@.................@@
	;;	............@.@@.@.@@...	@@@@@@................@@
	;;	........@.@@@..@@.@@.@..	@@@@@@.................@
	;;	........@@@...@.@.@.@@..	@@@@@@........@........@
	;;	.........@.@....@.@.@...	@@@@@@.....@..........@@
	;;	..........@.@..@.@.@@...	@@@@@@@@@...@.........@@
	;;	.........@.@@.@.@.@@.@..	@@@@@@@@...@@.@........@
	;;	.........@..@...@.@.@@..	@@@@@@@@....@..........@
	;;	.........@..@...@.@.@...	@@@@@@@@....@.........@@
	;;	..........@.@..@.@.@@...	@@@@@@@@@...@.........@@
	;;	.........@.@@.@.@.@@.@..	@@@@@@@@...@@.@........@
	;;	.........@..@...@.@.@@..	@@@@@@@@....@..........@
	;;	.........@..@...@.@.@...	@@@@@@@@....@.........@@
	;;	..........@.@..@.@.@@...	@@@@@@@@@...@.........@@
	;;	.........@.@@.@.@.@@.@..	@@@@@@@@...@@.@........@
	;;	.........@..@...@.@.@@..	@@@@@@@@....@..........@
	;;	.........@..@...@.@.@...	@@@@@@@@....@.........@@
	;;	..........@.@..@@..@@...	@@@@@@@@....@.........@@
	;;	........@@.@@.@@.@@@.@..	@@@@@@@....@@..........@
	;;	........@..@...@.@@.@@..	@@@@@@@....@...........@
	;;	........@..@...@.@@.@@..	@@@@@@@....@...........@
	;;	........@..@...@.@.@@...	@@@@@@@....@..........@@
	;;	........@......@.@.@.@..	@@@@@@@................@
	;;	.........@.....@.@..@...	@@@@@@@@..............@@
	;;	........@..@..@@..@..@..	@@@@@@@................@
	;;	.........@@..@..@..@@...	@@@@@@@@..............@@
	;;	........@..@@....@@..@..	@@@@@@@.@............@.@
	;;	........@@@..@@@@..@@@..	@@@@@@@.@@@........@@@.@
	;;	.........@@@@....@@@@...	@@@@@@@@.@@@@....@@@@.@@
	;;	........@..@@@@@@@@..@..	@@@@@@@....@@@@@@@@....@
	;;	.........@@..@@@@..@@...	@@@@@@@@.....@@@@.....@@
	;;	...........@@....@@.....	@@@@@@@@@............@@@
	;;	.............@@@@.......	@@@@@@@@@@@........@@@@@
	;;	........................	@@@@@@@@@@@@@....@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &01, &00, &00, &07, &01, &E0, &3C, &07, &FB, &D0, &0F
	DEFB &EC, &10, &1F, &F6, &10, &1F, &F2, &10, &3F, &F3, &13, &3F, &F3, &1E, &3F, &FF
	DEFB &18, &3F, &FF, &60, &1F, &FE, &80, &1F, &FE, &00, &0F, &FC, &00, &07, &F8, &00
	DEFB &01, &E0, &00, &06, &18, &00, &0F, &FC, &00, &17, &FA, &00, &19, &E6, &00, &16
	DEFB &1A, &00, &17, &F2, &00, &14, &9A, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA
	DEFB &00, &16, &DA, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA, &00
	DEFB &16, &DA, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA, &00, &16
	DEFB &DA, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA, &00, &16, &DA
	DEFB &00, &16, &DA, &00, &16, &DA, &00, &1E, &D2, &00, &0C, &DC, &00, &17, &BA, &00
	DEFB &19, &E6, &00, &1E, &1E, &00, &2F, &FD, &00, &33, &F3, &00, &1C, &0E, &00, &0F
	DEFB &FC, &00, &01, &E0, &00, &00, &00, &00, &FF, &FF, &FE, &FF, &FF, &F8, &FE, &1F
	DEFB &C0, &F9, &E0, &00, &F7, &F8, &02, &EF, &EC, &06, &DF, &F6, &C6, &DF, &F2, &C4
	DEFB &BF, &F3, &40, &BF, &F3, &40, &BF, &FF, &01, &BF, &FF, &07, &DF, &FE, &1F, &DF
	DEFB &FE, &7F, &EF, &FD, &FF, &F7, &FB, &FF, &F9, &E7, &FF, &F0, &01, &FF, &E0, &00
	DEFB &FF, &D0, &02, &FF, &D8, &06, &FF, &D6, &1A, &FF, &D7, &F2, &FF, &D4, &9A, &FF
	DEFB &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6
	DEFB &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA
	DEFB &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF
	DEFB &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &D6, &DA, &FF, &DE
	DEFB &D2, &FF, &EC, &DD, &FF, &C7, &B8, &FF, &C1, &E0, &FF, &C0, &00, &FF, &A0, &01
	DEFB &7F, &B0, &03, &7F, &DC, &0E, &FF, &EF, &FD, &FF, &F1, &E3, &FF, &FE, &1F, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@.
	;;	.......................@	@@@@@@@@@@@@@@@@@@@@@...
	;;	.....................@@@	@@@@@@@....@@@@@@@......
	;;	.......@@@@.......@@@@..	@@@@@..@@@@.............
	;;	.....@@@@@@@@.@@@@.@....	@@@@.@@@@@@@@.........@.
	;;	....@@@@@@@.@@.....@....	@@@.@@@@@@@.@@.......@@.
	;;	...@@@@@@@@@.@@....@....	@@.@@@@@@@@@.@@.@@...@@.
	;;	...@@@@@@@@@..@....@....	@@.@@@@@@@@@..@.@@...@..
	;;	..@@@@@@@@@@..@@...@..@@	@.@@@@@@@@@@..@@.@......
	;;	..@@@@@@@@@@..@@...@@@@.	@.@@@@@@@@@@..@@.@......
	;;	..@@@@@@@@@@@@@@...@@...	@.@@@@@@@@@@@@@@.......@
	;;	..@@@@@@@@@@@@@@.@@.....	@.@@@@@@@@@@@@@@.....@@@
	;;	...@@@@@@@@@@@@.@.......	@@.@@@@@@@@@@@@....@@@@@
	;;	...@@@@@@@@@@@@.........	@@.@@@@@@@@@@@@..@@@@@@@
	;;	....@@@@@@@@@@..........	@@@.@@@@@@@@@@.@@@@@@@@@
	;;	.....@@@@@@@@...........	@@@@.@@@@@@@@.@@@@@@@@@@
	;;	.......@@@@.............	@@@@@..@@@@..@@@@@@@@@@@
	;;	.....@@....@@...........	@@@@...........@@@@@@@@@
	;;	....@@@@@@@@@@..........	@@@.............@@@@@@@@
	;;	...@.@@@@@@@@.@.........	@@.@..........@.@@@@@@@@
	;;	...@@..@@@@..@@.........	@@.@@........@@.@@@@@@@@
	;;	...@.@@....@@.@.........	@@.@.@@....@@.@.@@@@@@@@
	;;	...@.@@@@@@@..@.........	@@.@.@@@@@@@..@.@@@@@@@@
	;;	...@.@..@..@@.@.........	@@.@.@..@..@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@.@@.@@.@@.@.........	@@.@.@@.@@.@@.@.@@@@@@@@
	;;	...@@@@.@@.@..@.........	@@.@@@@.@@.@..@.@@@@@@@@
	;;	....@@..@@.@@@..........	@@@.@@..@@.@@@.@@@@@@@@@
	;;	...@.@@@@.@@@.@.........	@@...@@@@.@@@...@@@@@@@@
	;;	...@@..@@@@..@@.........	@@.....@@@@.....@@@@@@@@
	;;	...@@@@....@@@@.........	@@..............@@@@@@@@
	;;	..@.@@@@@@@@@@.@........	@.@............@.@@@@@@@
	;;	..@@..@@@@@@..@@........	@.@@..........@@.@@@@@@@
	;;	...@@@......@@@.........	@@.@@@......@@@.@@@@@@@@
	;;	....@@@@@@@@@@..........	@@@.@@@@@@@@@@.@@@@@@@@@
	;;	.......@@@@.............	@@@@...@@@@...@@@@@@@@@@
	;;	........................	@@@@@@@....@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &03, &C0, &00, &0F, &F0, &00, &1F, &D8, &00, &3F, &EC, &00
	DEFB &27, &E4, &00, &6B, &E6, &00, &17, &E6, &00, &6F, &FE, &00, &9F, &FE, &00, &BF
	DEFB &FC, &00, &BF, &FC, &00, &9F, &F8, &00, &87, &F0, &00, &9B, &C0, &00, &E4, &30
	DEFB &00, &9F, &F8, &00, &2F, &F4, &00, &33, &CC, &00, &2C, &34, &00, &2F, &E4, &00
	DEFB &29, &34, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D
	DEFB &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4
	DEFB &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00
	DEFB &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &2D, &B4, &00, &3D
	DEFB &A4, &00, &19, &B8, &00, &2F, &74, &00, &33, &CC, &00, &3C, &3C, &00, &5F, &FA
	DEFB &00, &67, &E6, &00, &38, &1C, &00, &1F, &F8, &00, &03, &C0, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FC, &3F, &FF, &F3, &CF, &FF, &EF
	DEFB &F7, &FF, &DF, &DB, &FF, &BF, &ED, &FF, &A7, &E5, &FF, &63, &E6, &FF, &07, &E6
	DEFB &FF, &0F, &FE, &FF, &1F, &FE, &FF, &3F, &FD, &FF, &3F, &FD, &FF, &1F, &FB, &FF
	DEFB &27, &F7, &FF, &03, &CF, &FF, &00, &07, &FF, &00, &03, &FF, &20, &05, &FF, &B0
	DEFB &0D, &FF, &AC, &35, &FF, &AF, &E5, &FF, &A9, &35, &FF, &AD, &B5, &FF, &AD, &B5
	DEFB &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF
	DEFB &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD
	DEFB &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5, &FF, &AD, &B5
	DEFB &FF, &AD, &B5, &FF, &AD, &B5, &FF, &BD, &A5, &FF, &D9, &BB, &FF, &8F, &71, &FF
	DEFB &83, &C1, &FF, &80, &01, &FF, &40, &02, &FF, &60, &06, &FF, &B8, &1D, &FF, &DF
	DEFB &FB, &FF, &E3, &C7, &FF, &FC, &3F, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@....@@@@@@
	;;	..............@@@@......	@@@@@@@@@@@@..@@@@..@@@@
	;;	............@@@@@@@@....	@@@@@@@@@@@.@@@@@@@@.@@@
	;;	...........@@@@@@@.@@...	@@@@@@@@@@.@@@@@@@.@@.@@
	;;	..........@@@@@@@@@.@@..	@@@@@@@@@.@@@@@@@@@.@@.@
	;;	..........@..@@@@@@..@..	@@@@@@@@@.@..@@@@@@..@.@
	;;	.........@@.@.@@@@@..@@.	@@@@@@@@.@@...@@@@@..@@.
	;;	...........@.@@@@@@..@@.	@@@@@@@@.....@@@@@@..@@.
	;;	.........@@.@@@@@@@@@@@.	@@@@@@@@....@@@@@@@@@@@.
	;;	........@..@@@@@@@@@@@@.	@@@@@@@@...@@@@@@@@@@@@.
	;;	........@.@@@@@@@@@@@@..	@@@@@@@@..@@@@@@@@@@@@.@
	;;	........@.@@@@@@@@@@@@..	@@@@@@@@..@@@@@@@@@@@@.@
	;;	........@..@@@@@@@@@@...	@@@@@@@@...@@@@@@@@@@.@@
	;;	........@....@@@@@@@....	@@@@@@@@..@..@@@@@@@.@@@
	;;	........@..@@.@@@@......	@@@@@@@@......@@@@..@@@@
	;;	........@@@..@....@@....	@@@@@@@@.............@@@
	;;	........@..@@@@@@@@@@...	@@@@@@@@..............@@
	;;	..........@.@@@@@@@@.@..	@@@@@@@@..@..........@.@
	;;	..........@@..@@@@..@@..	@@@@@@@@@.@@........@@.@
	;;	..........@.@@....@@.@..	@@@@@@@@@.@.@@....@@.@.@
	;;	..........@.@@@@@@@..@..	@@@@@@@@@.@.@@@@@@@..@.@
	;;	..........@.@..@..@@.@..	@@@@@@@@@.@.@..@..@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@.@@.@@.@@.@..	@@@@@@@@@.@.@@.@@.@@.@.@
	;;	..........@@@@.@@.@..@..	@@@@@@@@@.@@@@.@@.@..@.@
	;;	...........@@..@@.@@@...	@@@@@@@@@@.@@..@@.@@@.@@
	;;	..........@.@@@@.@@@.@..	@@@@@@@@@...@@@@.@@@...@
	;;	..........@@..@@@@..@@..	@@@@@@@@@.....@@@@.....@
	;;	..........@@@@....@@@@..	@@@@@@@@@..............@
	;;	.........@.@@@@@@@@@@.@.	@@@@@@@@.@............@.
	;;	.........@@..@@@@@@..@@.	@@@@@@@@.@@..........@@.
	;;	..........@@@......@@@..	@@@@@@@@@.@@@......@@@.@
	;;	...........@@@@@@@@@@...	@@@@@@@@@@.@@@@@@@@@@.@@
	;;	..............@@@@......	@@@@@@@@@@@...@@@@...@@@
	;;	........................	@@@@@@@@@@@@@@....@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &06, &00, &00, &1F, &00, &00, &E6, &00, &01, &F9, &00
	DEFB &06, &66, &00, &0F, &9B, &00, &12, &64, &00, &39, &84, &00, &26, &07, &00, &98
	DEFB &08, &01, &60, &16, &00, &DC, &2F, &02, &A2, &5F, &02, &92, &5F, &04, &8C, &BF
	DEFB &06, &8C, &BF, &0A, &92, &CF, &0C, &91, &80, &0E, &8D, &00, &12, &82, &E0, &1C
	DEFB &85, &F8, &1E, &8B, &F0, &26, &8B, &E0, &38, &8B, &C0, &3E, &8B, &00, &1E, &84
	DEFB &00, &66, &84, &00, &78, &84, &00, &7E, &8B, &00, &3E, &97, &C0, &4E, &AF, &E0
	DEFB &70, &AF, &C0, &7E, &AF, &80, &3E, &97, &00, &4E, &96, &00, &70, &88, &00, &7E
	DEFB &84, &00, &3E, &84, &00, &4E, &84, &00, &70, &8B, &E0, &7E, &97, &C0, &3E, &97
	DEFB &80, &4E, &AF, &80, &70, &AF, &00, &7E, &AF, &00, &3E, &AE, &00, &4E, &94, &00
	DEFB &70, &88, &00, &7E, &84, &00, &3E, &8A, &00, &4E, &92, &00, &70, &A2, &00, &3E
	DEFB &CC, &00, &0E, &B0, &00, &01, &C0, &00, &FF, &FF, &F9, &FF, &FF, &E0, &FF, &FF
	DEFB &00, &FF, &FE, &00, &FF, &F8, &01, &FF, &F0, &06, &FF, &E0, &18, &FF, &C0, &60
	DEFB &FF, &81, &80, &FF, &06, &00, &FE, &18, &00, &FC, &60, &06, &FC, &80, &0F, &F8
	DEFB &80, &1F, &F8, &80, &1F, &F0, &8C, &3F, &F0, &8C, &3F, &E0, &80, &0F, &E0, &80
	DEFB &70, &E0, &80, &1F, &C0, &80, &E7, &C0, &81, &FB, &C0, &83, &F7, &80, &83, &EF
	DEFB &80, &83, &DF, &80, &83, &3F, &80, &80, &FF, &00, &83, &FF, &00, &80, &FF, &00
	DEFB &83, &3F, &80, &87, &DF, &00, &8F, &EF, &00, &8F, &DF, &00, &8F, &BF, &80, &87
	DEFB &7F, &00, &86, &FF, &00, &81, &FF, &00, &83, &FF, &80, &83, &FF, &00, &80, &1F
	DEFB &00, &83, &EF, &00, &87, &DF, &80, &87, &BF, &00, &8F, &BF, &00, &8F, &7F, &00
	DEFB &8F, &7F, &80, &8E, &FF, &00, &85, &FF, &00, &83, &FF, &00, &83, &FF, &80, &83
	DEFB &FF, &00, &83, &FF, &00, &83, &FF, &80, &8F, &FF, &C0, &BF, &FF, &F1, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@..@
	;;	.....................@@.	@@@@@@@@@@@@@@@@@@@.....
	;;	...................@@@@@	@@@@@@@@@@@@@@@@........
	;;	................@@@..@@.	@@@@@@@@@@@@@@@.........
	;;	...............@@@@@@..@	@@@@@@@@@@@@@..........@
	;;	.............@@..@@..@@.	@@@@@@@@@@@@.........@@.
	;;	............@@@@@..@@.@@	@@@@@@@@@@@........@@...
	;;	...........@..@..@@..@..	@@@@@@@@@@.......@@.....
	;;	..........@@@..@@....@..	@@@@@@@@@......@@.......
	;;	..........@..@@......@@@	@@@@@@@@.....@@.........
	;;	........@..@@.......@...	@@@@@@@....@@...........
	;;	.......@.@@........@.@@.	@@@@@@...@@..........@@.
	;;	........@@.@@@....@.@@@@	@@@@@@..@...........@@@@
	;;	......@.@.@...@..@.@@@@@	@@@@@...@..........@@@@@
	;;	......@.@..@..@..@.@@@@@	@@@@@...@..........@@@@@
	;;	.....@..@...@@..@.@@@@@@	@@@@....@...@@....@@@@@@
	;;	.....@@.@...@@..@.@@@@@@	@@@@....@...@@....@@@@@@
	;;	....@.@.@..@..@.@@..@@@@	@@@.....@...........@@@@
	;;	....@@..@..@...@@.......	@@@.....@........@@@....
	;;	....@@@.@...@@.@........	@@@.....@..........@@@@@
	;;	...@..@.@.....@.@@@.....	@@......@.......@@@..@@@
	;;	...@@@..@....@.@@@@@@...	@@......@......@@@@@@.@@
	;;	...@@@@.@...@.@@@@@@....	@@......@.....@@@@@@.@@@
	;;	..@..@@.@...@.@@@@@.....	@.......@.....@@@@@.@@@@
	;;	..@@@...@...@.@@@@......	@.......@.....@@@@.@@@@@
	;;	..@@@@@.@...@.@@........	@.......@.....@@..@@@@@@
	;;	...@@@@.@....@..........	@.......@.......@@@@@@@@
	;;	.@@..@@.@....@..........	........@.....@@@@@@@@@@
	;;	.@@@@...@....@..........	........@.......@@@@@@@@
	;;	.@@@@@@.@...@.@@........	........@.....@@..@@@@@@
	;;	..@@@@@.@..@.@@@@@......	@.......@....@@@@@.@@@@@
	;;	.@..@@@.@.@.@@@@@@@.....	........@...@@@@@@@.@@@@
	;;	.@@@....@.@.@@@@@@......	........@...@@@@@@.@@@@@
	;;	.@@@@@@.@.@.@@@@@.......	........@...@@@@@.@@@@@@
	;;	..@@@@@.@..@.@@@........	@.......@....@@@.@@@@@@@
	;;	.@..@@@.@..@.@@.........	........@....@@.@@@@@@@@
	;;	.@@@....@...@...........	........@......@@@@@@@@@
	;;	.@@@@@@.@....@..........	........@.....@@@@@@@@@@
	;;	..@@@@@.@....@..........	@.......@.....@@@@@@@@@@
	;;	.@..@@@.@....@..........	........@..........@@@@@
	;;	.@@@....@...@.@@@@@.....	........@.....@@@@@.@@@@
	;;	.@@@@@@.@..@.@@@@@......	........@....@@@@@.@@@@@
	;;	..@@@@@.@..@.@@@@.......	@.......@....@@@@.@@@@@@
	;;	.@..@@@.@.@.@@@@@.......	........@...@@@@@.@@@@@@
	;;	.@@@....@.@.@@@@........	........@...@@@@.@@@@@@@
	;;	.@@@@@@.@.@.@@@@........	........@...@@@@.@@@@@@@
	;;	..@@@@@.@.@.@@@.........	@.......@...@@@.@@@@@@@@
	;;	.@..@@@.@..@.@..........	........@....@.@@@@@@@@@
	;;	.@@@....@...@...........	........@.....@@@@@@@@@@
	;;	.@@@@@@.@....@..........	........@.....@@@@@@@@@@
	;;	..@@@@@.@...@.@.........	@.......@.....@@@@@@@@@@
	;;	.@..@@@.@..@..@.........	........@.....@@@@@@@@@@
	;;	.@@@....@.@...@.........	........@.....@@@@@@@@@@
	;;	..@@@@@.@@..@@..........	@.......@...@@@@@@@@@@@@
	;;	....@@@.@.@@............	@@......@.@@@@@@@@@@@@@@
	;;	.......@@@..............	@@@@...@@@@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &07, &00, &00, &19, &00, &00, &61, &00, &01, &8F, &00, &E6, &13, &00, &98
	DEFB &25, &00, &60, &25, &01, &80, &29, &00, &E0, &19, &00, &90, &19, &00, &9F, &15
	DEFB &00, &A0, &A5, &00, &DE, &65, &00, &BF, &69, &01, &3F, &31, &00, &3E, &09, &00
	DEFB &3D, &65, &00, &3A, &F5, &00, &31, &F5, &00, &25, &F5, &00, &1B, &F5, &00, &17
	DEFB &E9, &00, &18, &11, &00, &0F, &A1, &00, &13, &11, &00, &1C, &E9, &00, &1D, &F5
	DEFB &00, &0B, &F5, &00, &17, &F5, &00, &1B, &F5, &00, &1C, &E9, &00, &0F, &11, &00
	DEFB &13, &A1, &00, &1C, &11, &00, &1E, &E9, &00, &0D, &F5, &00, &13, &F5, &00, &17
	DEFB &F5, &00, &19, &F5, &00, &0C, &69, &00, &13, &19, &00, &1C, &25, &00, &1F, &A3
	DEFB &00, &1F, &A1, &00, &07, &A3, &00, &01, &AC, &00, &00, &70, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F9, &FF, &FF, &E1
	DEFB &FF, &1F, &81, &F0, &06, &01, &80, &18, &01, &00, &60, &01, &01, &80, &01, &00
	DEFB &00, &19, &00, &00, &19, &00, &00, &01, &00, &00, &01, &00, &1E, &01, &00, &3F
	DEFB &01, &00, &3F, &01, &00, &3E, &01, &00, &3C, &61, &00, &38, &F1, &18, &31, &F1
	DEFB &F8, &21, &F1, &FE, &43, &F1, &FF, &C7, &E1, &FF, &C0, &01, &FF, &E0, &01, &FF
	DEFB &C0, &01, &FF, &C0, &E1, &FF, &C1, &F1, &FF, &E3, &F1, &FF, &C7, &F1, &FF, &C3
	DEFB &F1, &FF, &C0, &E1, &FF, &E0, &01, &FF, &C0, &01, &FF, &C0, &01, &FF, &C0, &E1
	DEFB &FF, &E1, &F1, &FF, &C3, &F1, &FF, &C7, &F1, &FF, &C1, &F1, &FF, &E0, &61, &FF
	DEFB &C0, &01, &FF, &C0, &01, &FF, &C0, &01, &FF, &C0, &01, &FF, &E0, &03, &FF, &F8
	DEFB &0F, &FF, &FE, &3F, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	.....................@@@	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	...................@@..@	@@@@@@@@@@@@@@@@@@@@@..@
	;;	.................@@....@	@@@@@@@@@@@@@@@@@@@....@
	;;	...............@@...@@@@	@@@@@@@@...@@@@@@......@
	;;	........@@@..@@....@..@@	@@@@.........@@........@
	;;	........@..@@.....@..@.@	@..........@@..........@
	;;	.........@@.......@..@.@	.........@@............@
	;;	.......@@.........@.@..@	.......@@..............@
	;;	........@@@........@@..@	...................@@..@
	;;	........@..@.......@@..@	...................@@..@
	;;	........@..@@@@@...@.@.@	.......................@
	;;	........@.@.....@.@..@.@	.......................@
	;;	........@@.@@@@..@@..@.@	...........@@@@........@
	;;	........@.@@@@@@.@@.@..@	..........@@@@@@.......@
	;;	.......@..@@@@@@..@@...@	..........@@@@@@.......@
	;;	..........@@@@@.....@..@	..........@@@@@........@
	;;	..........@@@@.@.@@..@.@	..........@@@@...@@....@
	;;	..........@@@.@.@@@@.@.@	..........@@@...@@@@...@
	;;	..........@@...@@@@@.@.@	...@@.....@@...@@@@@...@
	;;	..........@..@.@@@@@.@.@	@@@@@.....@....@@@@@...@
	;;	...........@@.@@@@@@.@.@	@@@@@@@..@....@@@@@@...@
	;;	...........@.@@@@@@.@..@	@@@@@@@@@@...@@@@@@....@
	;;	...........@@......@...@	@@@@@@@@@@.............@
	;;	............@@@@@.@....@	@@@@@@@@@@@............@
	;;	...........@..@@...@...@	@@@@@@@@@@.............@
	;;	...........@@@..@@@.@..@	@@@@@@@@@@......@@@....@
	;;	...........@@@.@@@@@.@.@	@@@@@@@@@@.....@@@@@...@
	;;	............@.@@@@@@.@.@	@@@@@@@@@@@...@@@@@@...@
	;;	...........@.@@@@@@@.@.@	@@@@@@@@@@...@@@@@@@...@
	;;	...........@@.@@@@@@.@.@	@@@@@@@@@@....@@@@@@...@
	;;	...........@@@..@@@.@..@	@@@@@@@@@@......@@@....@
	;;	............@@@@...@...@	@@@@@@@@@@@............@
	;;	...........@..@@@.@....@	@@@@@@@@@@.............@
	;;	...........@@@.....@...@	@@@@@@@@@@.............@
	;;	...........@@@@.@@@.@..@	@@@@@@@@@@......@@@....@
	;;	............@@.@@@@@.@.@	@@@@@@@@@@@....@@@@@...@
	;;	...........@..@@@@@@.@.@	@@@@@@@@@@....@@@@@@...@
	;;	...........@.@@@@@@@.@.@	@@@@@@@@@@...@@@@@@@...@
	;;	...........@@..@@@@@.@.@	@@@@@@@@@@.....@@@@@...@
	;;	............@@...@@.@..@	@@@@@@@@@@@......@@....@
	;;	...........@..@@...@@..@	@@@@@@@@@@.............@
	;;	...........@@@....@..@.@	@@@@@@@@@@.............@
	;;	...........@@@@@@.@...@@	@@@@@@@@@@.............@
	;;	...........@@@@@@.@....@	@@@@@@@@@@.............@
	;;	.............@@@@.@...@@	@@@@@@@@@@@...........@@
	;;	...............@@.@.@@..	@@@@@@@@@@@@@.......@@@@
	;;	.................@@@....	@@@@@@@@@@@@@@@...@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;

	DEFB &00, &00, &00, &00, &00, &17, &00, &00, &F8, &00, &02, &8C, &00, &07, &61, &00
	DEFB &02, &85, &00, &0D, &0D, &00, &30, &72, &00, &51, &AA, &00, &86, &D1, &01, &19
	DEFB &75, &00, &66, &29, &02, &19, &AA, &02, &5D, &5A, &00, &25, &68, &06, &53, &A0
	DEFB &03, &7C, &A0, &0C, &1B, &40, &02, &65, &40, &0D, &1D, &40, &12, &66, &80, &1D
	DEFB &56, &80, &06, &13, &00, &39, &4B, &00, &0E, &34, &00, &22, &46, &00, &4D, &38
	DEFB &00, &72, &4C, &00, &0C, &74, &00, &73, &14, &00, &1C, &68, &00, &6B, &5C, &00
	DEFB &18, &54, &00, &66, &50, &00, &38, &5C, &00, &4E, &28, &00, &13, &2C, &00, &64
	DEFB &52, &00, &18, &5C, &00, &26, &2A, &00, &19, &16, &00, &0E, &52, &00, &12, &55
	DEFB &00, &64, &6C, &00, &1B, &21, &00, &76, &56, &00, &08, &65, &00, &6A, &1D, &80
	DEFB &32, &62, &00, &44, &75, &80, &19, &16, &80, &76, &69, &80, &1A, &26, &00, &05
	DEFB &58, &00, &01, &60, &00, &00, &00, &00, &FF, &FF, &E8, &FF, &FF, &00, &FF, &FC
	DEFB &00, &FF, &F8, &00, &FF, &F0, &00, &FF, &F0, &00, &FF, &C0, &00, &FF, &80, &00
	DEFB &FF, &00, &00, &FE, &00, &00, &FC, &00, &00, &FC, &00, &00, &F8, &00, &00, &F8
	DEFB &00, &00, &F8, &00, &01, &F0, &00, &07, &F0, &00, &0F, &E0, &00, &1F, &F0, &00
	DEFB &1F, &E0, &00, &1F, &C0, &00, &3F, &C0, &00, &3F, &C0, &00, &7F, &80, &00, &7F
	DEFB &C0, &00, &FF, &80, &00, &FF, &00, &01, &FF, &00, &01, &FF, &80, &01, &FF, &00
	DEFB &01, &FF, &80, &03, &FF, &00, &01, &FF, &80, &01, &FF, &00, &03, &FF, &80, &01
	DEFB &FF, &00, &03, &FF, &80, &01, &FF, &00, &01, &FF, &80, &01, &FF, &80, &00, &FF
	DEFB &C0, &00, &FF, &E0, &00, &FF, &80, &00, &7F, &00, &00, &FF, &80, &00, &7F, &00
	DEFB &00, &FF, &80, &00, &7F, &00, &00, &3F, &80, &00, &7F, &00, &00, &3F, &80, &00
	DEFB &3F, &00, &00, &3F, &80, &00, &7F, &E0, &01, &FF, &F8, &07, &FF, &FE, &9F, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@.@...
	;;	...................@.@@@	@@@@@@@@@@@@@@@@........
	;;	................@@@@@...	@@@@@@@@@@@@@@..........
	;;	..............@.@...@@..	@@@@@@@@@@@@@...........
	;;	.............@@@.@@....@	@@@@@@@@@@@@............
	;;	..............@.@....@.@	@@@@@@@@@@@@............
	;;	............@@.@....@@.@	@@@@@@@@@@..............
	;;	..........@@.....@@@..@.	@@@@@@@@@...............
	;;	.........@.@...@@.@.@.@.	@@@@@@@@................
	;;	........@....@@.@@.@...@	@@@@@@@.................
	;;	.......@...@@..@.@@@.@.@	@@@@@@..................
	;;	.........@@..@@...@.@..@	@@@@@@..................
	;;	......@....@@..@@.@.@.@.	@@@@@...................
	;;	......@..@.@@@.@.@.@@.@.	@@@@@...................
	;;	..........@..@.@.@@.@...	@@@@@..................@
	;;	.....@@..@.@..@@@.@.....	@@@@.................@@@
	;;	......@@.@@@@@..@.@.....	@@@@................@@@@
	;;	....@@.....@@.@@.@......	@@@................@@@@@
	;;	......@..@@..@.@.@......	@@@@...............@@@@@
	;;	....@@.@...@@@.@.@......	@@@................@@@@@
	;;	...@..@..@@..@@.@.......	@@................@@@@@@
	;;	...@@@.@.@.@.@@.@.......	@@................@@@@@@
	;;	.....@@....@..@@........	@@...............@@@@@@@
	;;	..@@@..@.@..@.@@........	@................@@@@@@@
	;;	....@@@...@@.@..........	@@..............@@@@@@@@
	;;	..@...@..@...@@.........	@...............@@@@@@@@
	;;	.@..@@.@..@@@...........	...............@@@@@@@@@
	;;	.@@@..@..@..@@..........	...............@@@@@@@@@
	;;	....@@...@@@.@..........	@..............@@@@@@@@@
	;;	.@@@..@@...@.@..........	...............@@@@@@@@@
	;;	...@@@...@@.@...........	@.............@@@@@@@@@@
	;;	.@@.@.@@.@.@@@..........	...............@@@@@@@@@
	;;	...@@....@.@.@..........	@..............@@@@@@@@@
	;;	.@@..@@..@.@............	..............@@@@@@@@@@
	;;	..@@@....@.@@@..........	@..............@@@@@@@@@
	;;	.@..@@@...@.@...........	..............@@@@@@@@@@
	;;	...@..@@..@.@@..........	@..............@@@@@@@@@
	;;	.@@..@...@.@..@.........	...............@@@@@@@@@
	;;	...@@....@.@@@..........	@..............@@@@@@@@@
	;;	..@..@@...@.@.@.........	@...............@@@@@@@@
	;;	...@@..@...@.@@.........	@@..............@@@@@@@@
	;;	....@@@..@.@..@.........	@@@.............@@@@@@@@
	;;	...@..@..@.@.@.@........	@................@@@@@@@
	;;	.@@..@...@@.@@..........	................@@@@@@@@
	;;	...@@.@@..@....@........	@................@@@@@@@
	;;	.@@@.@@..@.@.@@.........	................@@@@@@@@
	;;	....@....@@..@.@........	@................@@@@@@@
	;;	.@@.@.@....@@@.@@.......	..................@@@@@@
	;;	..@@..@..@@...@.........	@................@@@@@@@
	;;	.@...@...@@@.@.@@.......	..................@@@@@@
	;;	...@@..@...@.@@.@.......	@.................@@@@@@
	;;	.@@@.@@..@@.@..@@.......	..................@@@@@@
	;;	...@@.@...@..@@.........	@................@@@@@@@
	;;	.....@.@.@.@@...........	@@@............@@@@@@@@@
	;;	.......@.@@.............	@@@@@........@@@@@@@@@@@
	;;	........................	@@@@@@@.@..@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &06, &00, &00, &1A, &00, &00, &66, &00, &01, &A4, &00, &46, &94, &00, &9A
	DEFB &AE, &00, &6B, &2A, &00, &B9, &56, &00, &A2, &34, &00, &4A, &96, &00, &B5, &B4
	DEFB &00, &B5, &AA, &00, &95, &56, &00, &33, &54, &00, &A0, &AC, &00, &8A, &6A, &00
	DEFB &13, &12, &00, &0C, &AC, &00, &11, &16, &00, &0C, &D2, &00, &13, &14, &00, &1C
	DEFB &EA, &00, &13, &16, &00, &0C, &C8, &00, &33, &34, &00, &0C, &D2, &00, &27, &0C
	DEFB &00, &18, &D2, &00, &33, &56, &00, &4C, &AC, &00, &33, &26, &00, &4C, &5A, &00
	DEFB &33, &66, &00, &C4, &9A, &00, &31, &2A, &00, &CC, &96, &01, &32, &D2, &01, &CC
	DEFB &AE, &00, &32, &A8, &00, &CD, &56, &00, &B5, &2A, &01, &48, &AA, &01, &B5, &94
	DEFB &00, &69, &52, &01, &95, &4C, &00, &6A, &30, &00, &1A, &C0, &00, &05, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &F9, &FF, &FF, &E0, &FF, &FF, &80, &FF, &FE, &00
	DEFB &FF, &B8, &01, &F8, &00, &01, &FC, &00, &00, &FE, &00, &00, &FE, &00, &00, &FE
	DEFB &00, &01, &FF, &00, &00, &FE, &00, &01, &FE, &00, &00, &FE, &00, &00, &FE, &00
	DEFB &01, &FE, &00, &01, &FE, &00, &00, &FF, &40, &00, &FF, &E0, &01, &FF, &C0, &00
	DEFB &FF, &E0, &00, &FF, &C0, &01, &FF, &C0, &00, &FF, &C0, &00, &FF, &C0, &01, &FF
	DEFB &80, &01, &FF, &C0, &00, &FF, &80, &01, &FF, &C0, &00, &FF, &80, &00, &FF, &00
	DEFB &01, &FF, &80, &00, &FF, &00, &00, &FF, &00, &00, &FE, &00, &00, &FF, &00, &00
	DEFB &FE, &00, &00, &FC, &00, &00, &FC, &00, &00, &FE, &00, &01, &FE, &00, &00, &FE
	DEFB &00, &00, &FC, &00, &00, &FC, &00, &01, &FE, &00, &00, &FC, &00, &01, &FE, &00
	DEFB &03, &FF, &80, &0F, &FF, &E0, &3F, &FF, &FA, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@..@
	;;	.....................@@.	@@@@@@@@@@@@@@@@@@@.....
	;;	...................@@.@.	@@@@@@@@@@@@@@@@@.......
	;;	.................@@..@@.	@@@@@@@@@@@@@@@.........
	;;	...............@@.@..@..	@@@@@@@@@.@@@..........@
	;;	.........@...@@.@..@.@..	@@@@@..................@
	;;	........@..@@.@.@.@.@@@.	@@@@@@..................
	;;	.........@@.@.@@..@.@.@.	@@@@@@@.................
	;;	........@.@@@..@.@.@.@@.	@@@@@@@.................
	;;	........@.@...@...@@.@..	@@@@@@@................@
	;;	.........@..@.@.@..@.@@.	@@@@@@@@................
	;;	........@.@@.@.@@.@@.@..	@@@@@@@................@
	;;	........@.@@.@.@@.@.@.@.	@@@@@@@.................
	;;	........@..@.@.@.@.@.@@.	@@@@@@@.................
	;;	..........@@..@@.@.@.@..	@@@@@@@................@
	;;	........@.@.....@.@.@@..	@@@@@@@................@
	;;	........@...@.@..@@.@.@.	@@@@@@@.................
	;;	...........@..@@...@..@.	@@@@@@@@.@..............
	;;	............@@..@.@.@@..	@@@@@@@@@@@............@
	;;	...........@...@...@.@@.	@@@@@@@@@@..............
	;;	............@@..@@.@..@.	@@@@@@@@@@@.............
	;;	...........@..@@...@.@..	@@@@@@@@@@.............@
	;;	...........@@@..@@@.@.@.	@@@@@@@@@@..............
	;;	...........@..@@...@.@@.	@@@@@@@@@@..............
	;;	............@@..@@..@...	@@@@@@@@@@.............@
	;;	..........@@..@@..@@.@..	@@@@@@@@@..............@
	;;	............@@..@@.@..@.	@@@@@@@@@@..............
	;;	..........@..@@@....@@..	@@@@@@@@@..............@
	;;	...........@@...@@.@..@.	@@@@@@@@@@..............
	;;	..........@@..@@.@.@.@@.	@@@@@@@@@...............
	;;	.........@..@@..@.@.@@..	@@@@@@@@...............@
	;;	..........@@..@@..@..@@.	@@@@@@@@@...............
	;;	.........@..@@...@.@@.@.	@@@@@@@@................
	;;	..........@@..@@.@@..@@.	@@@@@@@@................
	;;	........@@...@..@..@@.@.	@@@@@@@.................
	;;	..........@@...@..@.@.@.	@@@@@@@@................
	;;	........@@..@@..@..@.@@.	@@@@@@@.................
	;;	.......@..@@..@.@@.@..@.	@@@@@@..................
	;;	.......@@@..@@..@.@.@@@.	@@@@@@..................
	;;	..........@@..@.@.@.@...	@@@@@@@................@
	;;	........@@..@@.@.@.@.@@.	@@@@@@@.................
	;;	........@.@@.@.@..@.@.@.	@@@@@@@.................
	;;	.......@.@..@...@.@.@.@.	@@@@@@..................
	;;	.......@@.@@.@.@@..@.@..	@@@@@@.................@
	;;	.........@@.@..@.@.@..@.	@@@@@@@.................
	;;	.......@@..@.@.@.@..@@..	@@@@@@.................@
	;;	.........@@.@.@...@@....	@@@@@@@...............@@
	;;	...........@@.@.@@......	@@@@@@@@@...........@@@@
	;;	.............@.@........	@@@@@@@@@@@.......@@@@@@
	;;	........................	@@@@@@@@@@@@@.@.@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &1F, &00, &00, &FF, &00, &03, &FF, &00, &07, &FF, &00
	DEFB &01, &FF, &00, &0E, &7C, &00, &0F, &93, &00, &33, &EF, &00, &7C, &D7, &00, &9F
	DEFB &37, &01, &E7, &5B, &01, &F8, &DB, &03, &FD, &6A, &03, &FD, &68, &07, &FB, &A0
	DEFB &07, &FB, &A0, &0F, &F7, &C0, &0F, &F7, &C0, &0F, &EF, &C0, &13, &EF, &80, &1C
	DEFB &DF, &80, &07, &1F, &00, &39, &C7, &00, &0E, &38, &00, &33, &86, &00, &7C, &B8
	DEFB &00, &7F, &44, &00, &7F, &78, &00, &7F, &7C, &00, &7F, &7C, &00, &7F, &7C, &00
	DEFB &7F, &7C, &00, &7F, &7C, &00, &7F, &7C, &00, &7F, &7C, &00, &1F, &7C, &00, &67
	DEFB &70, &00, &19, &4C, &00, &26, &32, &00, &19, &8E, &00, &0E, &5F, &00, &13, &DF
	DEFB &00, &7C, &EF, &80, &1F, &2F, &80, &67, &D7, &80, &79, &E7, &80, &7E, &1F, &80
	DEFB &3F, &7F, &80, &4F, &7F, &80, &73, &BF, &80, &7C, &3F, &00, &1F, &7C, &00, &07
	DEFB &70, &00, &01, &40, &00, &00, &00, &00, &FF, &FF, &E0, &FF, &FF, &00, &FF, &FC
	DEFB &00, &FF, &F8, &00, &FF, &F0, &00, &FF, &F0, &00, &FF, &E0, &00, &FF, &C0, &03
	DEFB &FF, &80, &0F, &FF, &00, &07, &FE, &00, &07, &FC, &00, &03, &FC, &00, &03, &F8
	DEFB &01, &02, &F8, &01, &01, &F0, &03, &87, &F0, &03, &8F, &E0, &07, &CF, &E0, &07
	DEFB &DF, &E0, &0F, &DF, &C0, &0F, &BF, &C0, &1F, &BF, &C0, &1F, &7F, &80, &07, &7F
	DEFB &80, &00, &FF, &80, &00, &FF, &00, &01, &FF, &00, &41, &FF, &00, &79, &FF, &00
	DEFB &7D, &FF, &00, &7D, &FF, &00, &7D, &FF, &00, &7D, &FF, &00, &7D, &FF, &00, &7D
	DEFB &FF, &00, &7D, &FF, &00, &7D, &FF, &00, &71, &FF, &80, &41, &FF, &80, &02, &FF
	DEFB &C0, &0E, &FF, &E0, &1F, &7F, &80, &1F, &7F, &00, &0F, &BF, &00, &0F, &BF, &00
	DEFB &07, &BF, &00, &07, &BF, &00, &1F, &BF, &80, &7F, &BF, &00, &7F, &BF, &00, &3F
	DEFB &BF, &00, &3F, &7F, &80, &7C, &FF, &E0, &73, &FF, &F8, &4F, &FF, &FE, &3F, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@.....
	;;	...................@@@@@	@@@@@@@@@@@@@@@@........
	;;	................@@@@@@@@	@@@@@@@@@@@@@@..........
	;;	..............@@@@@@@@@@	@@@@@@@@@@@@@...........
	;;	.............@@@@@@@@@@@	@@@@@@@@@@@@............
	;;	...............@@@@@@@@@	@@@@@@@@@@@@............
	;;	............@@@..@@@@@..	@@@@@@@@@@@.............
	;;	............@@@@@..@..@@	@@@@@@@@@@............@@
	;;	..........@@..@@@@@.@@@@	@@@@@@@@@...........@@@@
	;;	.........@@@@@..@@.@.@@@	@@@@@@@@.............@@@
	;;	........@..@@@@@..@@.@@@	@@@@@@@..............@@@
	;;	.......@@@@..@@@.@.@@.@@	@@@@@@................@@
	;;	.......@@@@@@...@@.@@.@@	@@@@@@................@@
	;;	......@@@@@@@@.@.@@.@.@.	@@@@@..........@......@.
	;;	......@@@@@@@@.@.@@.@...	@@@@@..........@.......@
	;;	.....@@@@@@@@.@@@.@.....	@@@@..........@@@....@@@
	;;	.....@@@@@@@@.@@@.@.....	@@@@..........@@@...@@@@
	;;	....@@@@@@@@.@@@@@......	@@@..........@@@@@..@@@@
	;;	....@@@@@@@@.@@@@@......	@@@..........@@@@@.@@@@@
	;;	....@@@@@@@.@@@@@@......	@@@.........@@@@@@.@@@@@
	;;	...@..@@@@@.@@@@@.......	@@..........@@@@@.@@@@@@
	;;	...@@@..@@.@@@@@@.......	@@.........@@@@@@.@@@@@@
	;;	.....@@@...@@@@@........	@@.........@@@@@.@@@@@@@
	;;	..@@@..@@@...@@@........	@............@@@.@@@@@@@
	;;	....@@@...@@@...........	@...............@@@@@@@@
	;;	..@@..@@@....@@.........	@...............@@@@@@@@
	;;	.@@@@@..@.@@@...........	...............@@@@@@@@@
	;;	.@@@@@@@.@...@..........	.........@.....@@@@@@@@@
	;;	.@@@@@@@.@@@@...........	.........@@@@..@@@@@@@@@
	;;	.@@@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	.@@@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	.@@@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	.@@@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	.@@@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	.@@@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	.@@@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	...@@@@@.@@@@@..........	.........@@@@@.@@@@@@@@@
	;;	.@@..@@@.@@@............	.........@@@...@@@@@@@@@
	;;	...@@..@.@..@@..........	@........@.....@@@@@@@@@
	;;	..@..@@...@@..@.........	@.............@.@@@@@@@@
	;;	...@@..@@...@@@.........	@@..........@@@.@@@@@@@@
	;;	....@@@..@.@@@@@........	@@@........@@@@@.@@@@@@@
	;;	...@..@@@@.@@@@@........	@..........@@@@@.@@@@@@@
	;;	.@@@@@..@@@.@@@@@.......	............@@@@@.@@@@@@
	;;	...@@@@@..@.@@@@@.......	............@@@@@.@@@@@@
	;;	.@@..@@@@@.@.@@@@.......	.............@@@@.@@@@@@
	;;	.@@@@..@@@@..@@@@.......	.............@@@@.@@@@@@
	;;	.@@@@@@....@@@@@@.......	...........@@@@@@.@@@@@@
	;;	..@@@@@@.@@@@@@@@.......	@........@@@@@@@@.@@@@@@
	;;	.@..@@@@.@@@@@@@@.......	.........@@@@@@@@.@@@@@@
	;;	.@@@..@@@.@@@@@@@.......	..........@@@@@@@.@@@@@@
	;;	.@@@@@....@@@@@@........	..........@@@@@@.@@@@@@@
	;;	...@@@@@.@@@@@..........	@........@@@@@..@@@@@@@@
	;;	.....@@@.@@@............	@@@......@@@..@@@@@@@@@@
	;;	.......@.@..............	@@@@@....@..@@@@@@@@@@@@
	;;	........................	@@@@@@@...@@@@@@@@@@@@@@

	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &03, &20, &00, &01, &CC
	DEFB &00, &00, &F3, &00, &00, &F9, &40, &00, &80, &20, &00, &7A, &80, &00, &F9, &B0
	DEFB &00, &F5, &B8, &00, &F5, &7C, &00, &F3, &7C, &00, &E0, &FE, &00, &8E, &7C, &00
	DEFB &11, &BA, &00, &0E, &24, &00, &11, &9A, &00, &0E, &44, &00, &11, &9A, &00, &1E
	DEFB &06, &00, &1F, &DE, &00, &1F, &DE, &00, &3F, &DE, &00, &3F, &DE, &00, &3F, &BE
	DEFB &00, &3F, &BE, &00, &0F, &BC, &00, &73, &BC, &00, &1C, &60, &00, &67, &1C, &00
	DEFB &79, &60, &00, &FE, &18, &00, &FF, &78, &00, &FE, &F4, &01, &3E, &F2, &01, &CD
	DEFB &FE, &01, &F1, &FE, &01, &FD, &FC, &01, &FD, &FC, &01, &FD, &FE, &01, &FD, &FE
	DEFB &00, &FD, &FE, &00, &3D, &F8, &00, &0D, &E0, &00, &03, &80, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FC, &FF, &FF, &F8, &13, &FF, &FC, &00, &FF, &FE, &00, &3F, &FE, &00, &1F, &FE
	DEFB &00, &0F, &FF, &78, &0F, &FE, &F8, &37, &FE, &F0, &3B, &FE, &F0, &7D, &FE, &F0
	DEFB &7D, &FE, &E0, &FE, &FE, &80, &7C, &FF, &40, &38, &FF, &C0, &20, &FF, &C0, &00
	DEFB &FF, &C0, &00, &FF, &C0, &02, &FF, &C0, &06, &FF, &C0, &1E, &FF, &C0, &1E, &FF
	DEFB &80, &1E, &FF, &80, &1E, &FF, &80, &3E, &FF, &80, &3E, &FF, &80, &3D, &FF, &00
	DEFB &3D, &FF, &80, &61, &FF, &00, &01, &FF, &00, &03, &FE, &00, &1B, &FE, &00, &7B
	DEFB &FE, &00, &F5, &FC, &00, &F2, &FC, &01, &FE, &FC, &01, &FE, &FC, &01, &FD, &FC
	DEFB &01, &FD, &FC, &01, &FE, &FC, &01, &FE, &FE, &01, &FE, &FF, &01, &F9, &FF, &C1
	DEFB &E7, &FF, &F3, &9F, &FF, &FC, &7F, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@..@@@@@@@@@@@@@@@@
	;;	......@@..@.............	@@@@@......@..@@@@@@@@@@
	;;	.......@@@..@@..........	@@@@@@..........@@@@@@@@
	;;	........@@@@..@@........	@@@@@@@...........@@@@@@
	;;	........@@@@@..@.@......	@@@@@@@............@@@@@
	;;	........@.........@.....	@@@@@@@.............@@@@
	;;	.........@@@@.@.@.......	@@@@@@@@.@@@@.......@@@@
	;;	........@@@@@..@@.@@....	@@@@@@@.@@@@@.....@@.@@@
	;;	........@@@@.@.@@.@@@...	@@@@@@@.@@@@......@@@.@@
	;;	........@@@@.@.@.@@@@@..	@@@@@@@.@@@@.....@@@@@.@
	;;	........@@@@..@@.@@@@@..	@@@@@@@.@@@@.....@@@@@.@
	;;	........@@@.....@@@@@@@.	@@@@@@@.@@@.....@@@@@@@.
	;;	........@...@@@..@@@@@..	@@@@@@@.@........@@@@@..
	;;	...........@...@@.@@@.@.	@@@@@@@@.@........@@@...
	;;	............@@@...@..@..	@@@@@@@@@@........@.....
	;;	...........@...@@..@@.@.	@@@@@@@@@@..............
	;;	............@@@..@...@..	@@@@@@@@@@..............
	;;	...........@...@@..@@.@.	@@@@@@@@@@............@.
	;;	...........@@@@......@@.	@@@@@@@@@@...........@@.
	;;	...........@@@@@@@.@@@@.	@@@@@@@@@@.........@@@@.
	;;	...........@@@@@@@.@@@@.	@@@@@@@@@@.........@@@@.
	;;	..........@@@@@@@@.@@@@.	@@@@@@@@@..........@@@@.
	;;	..........@@@@@@@@.@@@@.	@@@@@@@@@..........@@@@.
	;;	..........@@@@@@@.@@@@@.	@@@@@@@@@.........@@@@@.
	;;	..........@@@@@@@.@@@@@.	@@@@@@@@@.........@@@@@.
	;;	............@@@@@.@@@@..	@@@@@@@@@.........@@@@.@
	;;	.........@@@..@@@.@@@@..	@@@@@@@@..........@@@@.@
	;;	...........@@@...@@.....	@@@@@@@@@........@@....@
	;;	.........@@..@@@...@@@..	@@@@@@@@...............@
	;;	.........@@@@..@.@@.....	@@@@@@@@..............@@
	;;	........@@@@@@@....@@...	@@@@@@@............@@.@@
	;;	........@@@@@@@@.@@@@...	@@@@@@@..........@@@@.@@
	;;	........@@@@@@@.@@@@.@..	@@@@@@@.........@@@@.@.@
	;;	.......@..@@@@@.@@@@..@.	@@@@@@..........@@@@..@.
	;;	.......@@@..@@.@@@@@@@@.	@@@@@@.........@@@@@@@@.
	;;	.......@@@@@...@@@@@@@@.	@@@@@@.........@@@@@@@@.
	;;	.......@@@@@@@.@@@@@@@..	@@@@@@.........@@@@@@@.@
	;;	.......@@@@@@@.@@@@@@@..	@@@@@@.........@@@@@@@.@
	;;	.......@@@@@@@.@@@@@@@@.	@@@@@@.........@@@@@@@@.
	;;	.......@@@@@@@.@@@@@@@@.	@@@@@@.........@@@@@@@@.
	;;	........@@@@@@.@@@@@@@@.	@@@@@@@........@@@@@@@@.
	;;	..........@@@@.@@@@@@...	@@@@@@@@.......@@@@@@..@
	;;	............@@.@@@@.....	@@@@@@@@@@.....@@@@..@@@
	;;	..............@@@.......	@@@@@@@@@@@@..@@@..@@@@@
	;;	........................	@@@@@@@@@@@@@@...@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

;; -----------------------------------------------------------------------------------------------------------
SPR_FLIP			EQU		&80			;; bit7 set = sprite flip (eg. SPR_FLIP | SPR_VAPE1)

;; -----------------------------------------------------------------------------------------------------------
SPR_BATMAN_0		EQU		&10
SPR_BATMAN_1		EQU		&11
SPR_BATMAN_2		EQU		&12
SPR_BATMAN_B0		EQU		&13
SPR_BATMAN_B1		EQU		&14
SPR_BATMAN_FLY		EQU		&15
SPR_BATMAN_FLYB		EQU		&16
SPR_BM_STANDING		EQU		&17
SPR_WOLF_0			EQU		&18
SPR_WOLF_1			EQU		&19
SPR_WOLF_2			EQU		&1A
SPR_WOLF_B0			EQU		&1B
SPR_WOLF_B1			EQU		&1C
SPR_WOLF_B2			EQU		&1D
SPR_DEMON			EQU		&1E
SPR_DEMONB			EQU		&1F
SPR_SHARK_0			EQU		&20
SPR_SHARK_1			EQU		&21
SPR_SHARK_B0		EQU		&22
SPR_SHARK_B1		EQU		&23
SPR_DOG_0			EQU		&24
SPR_DOG_1			EQU		&25
SPR_DOG_B0			EQU		&26
SPR_DOG_B1			EQU		&27
SPR_JOKER			EQU		&28
SPR_JOKERB			EQU		&29
SPR_JOKER_B1		EQU		&2A
SPR_RIDDLER			EQU		&2B
SPR_RIDDLERB		EQU		&2C
SPR_1st_3x32_sprite	EQU		SPR_BATMAN_0

;; -----------------------------------------------------------------------------------------------------------
img_3x32_bin:				;; SPR_BATMAN_0 EQU &10
	DEFB &00, &00, &00, &00, &80, &80, &00, &DE, &80, &00, &FF, &80, &00, &EE, &80, &00
	DEFB &F5, &80, &00, &FF, &80, &00, &E6, &80, &00, &D9, &80, &00, &5F, &00, &00, &D9
	DEFB &00, &03, &4E, &80, &04, &B1, &00, &0B, &FF, &C0, &0B, &75, &C0, &16, &E0, &E0
	DEFB &16, &FB, &60, &16, &FF, &40, &34, &7E, &30, &3B, &01, &38, &37, &3E, &50, &3A
	DEFB &59, &60, &3C, &E7, &60, &3F, &6B, &60, &3F, &6B, &60, &3F, &63, &30, &3E, &66
	DEFB &98, &38, &C7, &C0, &3C, &F1, &E0, &18, &78, &60, &00, &18, &00, &00, &00, &00
	DEFB &FF, &7F, &7F, &FE, &20, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE
	DEFB &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &19, &3F, &FF, &1F, &7F, &FC, &19
	DEFB &7F, &F8, &0E, &3F, &F0, &B1, &3F, &E3, &FF, &DF, &E3, &75, &DF, &C6, &E0, &EF
	DEFB &C6, &FB, &6F, &C6, &FF, &4F, &84, &7E, &37, &83, &00, &3B, &87, &00, &17, &82
	DEFB &41, &0F, &80, &E7, &0F, &80, &63, &0F, &80, &63, &0F, &80, &63, &07, &80, &66
	DEFB &83, &80, &C7, &C7, &80, &F1, &EF, &C3, &7A, &6F, &E7, &9B, &9F, &FF, &E7, &FF
	;;	........................	@@@@@@@@.@@@@@@@.@@@@@@@
	;;	........@.......@.......	@@@@@@@...@.......@@@@@@
	;;	........@@.@@@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@@.@@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@@@.@.@@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@@..@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@.@@..@@.......	@@@@@@@....@@..@..@@@@@@
	;;	.........@.@@@@@........	@@@@@@@@...@@@@@.@@@@@@@
	;;	........@@.@@..@........	@@@@@@.....@@..@.@@@@@@@
	;;	......@@.@..@@@.@.......	@@@@@.......@@@...@@@@@@
	;;	.....@..@.@@...@........	@@@@....@.@@...@..@@@@@@
	;;	....@.@@@@@@@@@@@@......	@@@...@@@@@@@@@@@@.@@@@@
	;;	....@.@@.@@@.@.@@@......	@@@...@@.@@@.@.@@@.@@@@@
	;;	...@.@@.@@@.....@@@.....	@@...@@.@@@.....@@@.@@@@
	;;	...@.@@.@@@@@.@@.@@.....	@@...@@.@@@@@.@@.@@.@@@@
	;;	...@.@@.@@@@@@@@.@......	@@...@@.@@@@@@@@.@..@@@@
	;;	..@@.@...@@@@@@...@@....	@....@...@@@@@@...@@.@@@
	;;	..@@@.@@.......@..@@@...	@.....@@..........@@@.@@
	;;	..@@.@@@..@@@@@..@.@....	@....@@@...........@.@@@
	;;	..@@@.@..@.@@..@.@@.....	@.....@..@.....@....@@@@
	;;	..@@@@..@@@..@@@.@@.....	@.......@@@..@@@....@@@@
	;;	..@@@@@@.@@.@.@@.@@.....	@........@@...@@....@@@@
	;;	..@@@@@@.@@.@.@@.@@.....	@........@@...@@....@@@@
	;;	..@@@@@@.@@...@@..@@....	@........@@...@@.....@@@
	;;	..@@@@@..@@..@@.@..@@...	@........@@..@@.@.....@@
	;;	..@@@...@@...@@@@@......	@.......@@...@@@@@...@@@
	;;	..@@@@..@@@@...@@@@.....	@.......@@@@...@@@@.@@@@
	;;	...@@....@@@@....@@.....	@@....@@.@@@@.@..@@.@@@@
	;;	...........@@...........	@@@..@@@@..@@.@@@..@@@@@
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@

				;; SPR_BATMAN_1 EQU &11
	DEFB &00, &00, &00, &00, &80, &80, &00, &DE, &80, &00, &FF, &80, &00, &EE, &80, &00
	DEFB &F5, &80, &00, &FF, &80, &00, &E6, &80, &00, &D9, &80, &00, &5F, &00, &00, &D9
	DEFB &00, &03, &4E, &80, &04, &B1, &00, &0B, &FF, &C0, &0B, &75, &C0, &16, &E0, &E0
	DEFB &16, &FB, &50, &16, &FF, &38, &30, &7E, &D8, &2E, &80, &E0, &2D, &BE, &E0, &31
	DEFB &51, &E0, &3E, &ED, &E0, &3F, &33, &E0, &3F, &5B, &E0, &3F, &58, &B0, &3A, &58
	DEFB &18, &38, &32, &00, &3C, &3C, &00, &18, &1C, &00, &00, &0E, &00, &00, &00, &00
	DEFB &FF, &7F, &7F, &FE, &20, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE
	DEFB &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &19, &3F, &FF, &1F, &7F, &FC, &19
	DEFB &7F, &F8, &0E, &3F, &F0, &B1, &1F, &E3, &FF, &DF, &E3, &75, &CF, &C6, &E0, &EF
	DEFB &C6, &FB, &57, &C6, &FF, &3B, &80, &7E, &1B, &8E, &00, &07, &8C, &00, &0F, &80
	DEFB &40, &0F, &80, &EC, &0F, &80, &30, &0F, &80, &58, &0F, &80, &58, &07, &80, &59
	DEFB &43, &81, &B2, &E7, &81, &BD, &FF, &C3, &DD, &FF, &E7, &EE, &FF, &FF, &F1, &FF
	;;	........................	@@@@@@@@.@@@@@@@.@@@@@@@
	;;	........@.......@.......	@@@@@@@...@.......@@@@@@
	;;	........@@.@@@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@@.@@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@@@.@.@@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@@..@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@.@@..@@.......	@@@@@@@....@@..@..@@@@@@
	;;	.........@.@@@@@........	@@@@@@@@...@@@@@.@@@@@@@
	;;	........@@.@@..@........	@@@@@@.....@@..@.@@@@@@@
	;;	......@@.@..@@@.@.......	@@@@@.......@@@...@@@@@@
	;;	.....@..@.@@...@........	@@@@....@.@@...@...@@@@@
	;;	....@.@@@@@@@@@@@@......	@@@...@@@@@@@@@@@@.@@@@@
	;;	....@.@@.@@@.@.@@@......	@@@...@@.@@@.@.@@@..@@@@
	;;	...@.@@.@@@.....@@@.....	@@...@@.@@@.....@@@.@@@@
	;;	...@.@@.@@@@@.@@.@.@....	@@...@@.@@@@@.@@.@.@.@@@
	;;	...@.@@.@@@@@@@@..@@@...	@@...@@.@@@@@@@@..@@@.@@
	;;	..@@.....@@@@@@.@@.@@...	@........@@@@@@....@@.@@
	;;	..@.@@@.@.......@@@.....	@...@@@..............@@@
	;;	..@.@@.@@.@@@@@.@@@.....	@...@@..............@@@@
	;;	..@@...@.@.@...@@@@.....	@........@..........@@@@
	;;	..@@@@@.@@@.@@.@@@@.....	@.......@@@.@@......@@@@
	;;	..@@@@@@..@@..@@@@@.....	@.........@@........@@@@
	;;	..@@@@@@.@.@@.@@@@@.....	@........@.@@.......@@@@
	;;	..@@@@@@.@.@@...@.@@....	@........@.@@........@@@
	;;	..@@@.@..@.@@......@@...	@........@.@@..@.@....@@
	;;	..@@@.....@@..@.........	@......@@.@@..@.@@@..@@@
	;;	..@@@@....@@@@..........	@......@@.@@@@.@@@@@@@@@
	;;	...@@......@@@..........	@@....@@@@.@@@.@@@@@@@@@
	;;	............@@@.........	@@@..@@@@@@.@@@.@@@@@@@@
	;;	........................	@@@@@@@@@@@@...@@@@@@@@@

				;; SPR_BATMAN_2 EQU &12
	DEFB &00, &00, &00, &00, &80, &80, &00, &DE, &80, &00, &FF, &80, &00, &EE, &80, &00
	DEFB &F5, &80, &00, &FF, &80, &00, &E6, &80, &00, &D9, &80, &00, &5F, &00, &00, &D9
	DEFB &00, &03, &4E, &80, &04, &B1, &00, &0B, &FF, &C0, &17, &75, &C0, &17, &60, &E0
	DEFB &16, &BB, &E0, &1B, &DF, &00, &3D, &AE, &60, &3E, &71, &60, &3F, &6E, &10, &3F
	DEFB &8D, &B0, &3F, &63, &B0, &3E, &ED, &D0, &3E, &D2, &D0, &3D, &81, &B8, &39, &E3
	DEFB &80, &30, &E7, &00, &30, &73, &C0, &18, &01, &C0, &00, &00, &E0, &00, &00, &00
	DEFB &FF, &7F, &7F, &FE, &20, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE
	DEFB &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &19, &3F, &FF, &1F, &7F, &FC, &19
	DEFB &7F, &F8, &0E, &3F, &F0, &B1, &1F, &E3, &FF, &DF, &C7, &75, &DF, &C7, &60, &EF
	DEFB &C6, &BB, &EF, &C3, &DF, &0F, &81, &AE, &67, &80, &70, &67, &80, &60, &07, &80
	DEFB &01, &87, &80, &63, &87, &80, &E1, &C7, &80, &C0, &C7, &81, &8D, &83, &81, &EB
	DEFB &87, &86, &E7, &3F, &87, &73, &DF, &C3, &8D, &DF, &E7, &FE, &EF, &FF, &FF, &1F
	;;	........................	@@@@@@@@.@@@@@@@.@@@@@@@
	;;	........@.......@.......	@@@@@@@...@.......@@@@@@
	;;	........@@.@@@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@@.@@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@@@.@.@@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@@..@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@.@@..@@.......	@@@@@@@....@@..@..@@@@@@
	;;	.........@.@@@@@........	@@@@@@@@...@@@@@.@@@@@@@
	;;	........@@.@@..@........	@@@@@@.....@@..@.@@@@@@@
	;;	......@@.@..@@@.@.......	@@@@@.......@@@...@@@@@@
	;;	.....@..@.@@...@........	@@@@....@.@@...@...@@@@@
	;;	....@.@@@@@@@@@@@@......	@@@...@@@@@@@@@@@@.@@@@@
	;;	...@.@@@.@@@.@.@@@......	@@...@@@.@@@.@.@@@.@@@@@
	;;	...@.@@@.@@.....@@@.....	@@...@@@.@@.....@@@.@@@@
	;;	...@.@@.@.@@@.@@@@@.....	@@...@@.@.@@@.@@@@@.@@@@
	;;	...@@.@@@@.@@@@@........	@@....@@@@.@@@@@....@@@@
	;;	..@@@@.@@.@.@@@..@@.....	@......@@.@.@@@..@@..@@@
	;;	..@@@@@..@@@...@.@@.....	@........@@@.....@@..@@@
	;;	..@@@@@@.@@.@@@....@....	@........@@..........@@@
	;;	..@@@@@@@...@@.@@.@@....	@..............@@....@@@
	;;	..@@@@@@.@@...@@@.@@....	@........@@...@@@....@@@
	;;	..@@@@@.@@@.@@.@@@.@....	@.......@@@....@@@...@@@
	;;	..@@@@@.@@.@..@.@@.@....	@.......@@......@@...@@@
	;;	..@@@@.@@......@@.@@@...	@......@@...@@.@@.....@@
	;;	..@@@..@@@@...@@@.......	@......@@@@.@.@@@....@@@
	;;	..@@....@@@..@@@........	@....@@.@@@..@@@..@@@@@@
	;;	..@@.....@@@..@@@@......	@....@@@.@@@..@@@@.@@@@@
	;;	...@@..........@@@......	@@....@@@...@@.@@@.@@@@@
	;;	................@@@.....	@@@..@@@@@@@@@@.@@@.@@@@
	;;	........................	@@@@@@@@@@@@@@@@...@@@@@

				;; SPR_BATMAN_B0 EQU &13
	DEFB &00, &00, &00, &01, &01, &00, &01, &BE, &00, &01, &FF, &00, &01, &7F, &00, &01
	DEFB &7F, &00, &01, &7F, &00, &01, &7F, &00, &01, &FF, &00, &01, &FF, &00, &00, &F5
	DEFB &80, &01, &7B, &C0, &03, &FF, &E0, &07, &FF, &F0, &0F, &FF, &F0, &2F, &FF, &F0
	DEFB &5F, &FF, &F8, &5F, &FF, &F8, &1F, &FF, &F8, &1F, &FF, &FC, &1F, &FF, &FC, &1F
	DEFB &FF, &FC, &1F, &FF, &FC, &1F, &FF, &FC, &1F, &FF, &FC, &1F, &FF, &FC, &1F, &FF
	DEFB &FC, &3F, &FF, &38, &0C, &C6, &00, &00, &38, &00, &00, &00, &00, &00, &00, &00
	DEFB &FE, &FE, &FF, &FC, &40, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC
	DEFB &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FE, &00
	DEFB &3F, &FC, &00, &1F, &F8, &00, &0F, &F0, &00, &07, &C0, &00, &07, &A0, &00, &07
	DEFB &40, &00, &03, &40, &00, &03, &80, &00, &03, &C0, &00, &01, &C0, &00, &01, &C0
	DEFB &00, &01, &C0, &00, &01, &C0, &00, &01, &C0, &00, &01, &C0, &00, &01, &C0, &00
	DEFB &01, &80, &00, &03, &C0, &00, &C7, &F3, &39, &FF, &FF, &C7, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@.@@@@@@@.@@@@@@@@
	;;	.......@.......@........	@@@@@@...@.......@@@@@@@
	;;	.......@@.@@@@@.........	@@@@@@...........@@@@@@@
	;;	.......@@@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@@@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@@@@@@@@@........	@@@@@@...........@@@@@@@
	;;	........@@@@.@.@@.......	@@@@@@@...........@@@@@@
	;;	.......@.@@@@.@@@@......	@@@@@@.............@@@@@
	;;	......@@@@@@@@@@@@@.....	@@@@@...............@@@@
	;;	.....@@@@@@@@@@@@@@@....	@@@@.................@@@
	;;	....@@@@@@@@@@@@@@@@....	@@...................@@@
	;;	..@.@@@@@@@@@@@@@@@@....	@.@..................@@@
	;;	.@.@@@@@@@@@@@@@@@@@@...	.@....................@@
	;;	.@.@@@@@@@@@@@@@@@@@@...	.@....................@@
	;;	...@@@@@@@@@@@@@@@@@@...	@.....................@@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	..@@@@@@@@@@@@@@..@@@...	@.....................@@
	;;	....@@..@@...@@.........	@@..............@@...@@@
	;;	..........@@@...........	@@@@..@@..@@@..@@@@@@@@@
	;;	........................	@@@@@@@@@@...@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_BATMAN_B1 EQU &14
	DEFB &00, &00, &00, &01, &01, &00, &01, &BE, &00, &01, &FF, &00, &01, &7F, &00, &01
	DEFB &7F, &00, &01, &7F, &00, &01, &7F, &00, &01, &FF, &00, &01, &FF, &00, &00, &F5
	DEFB &80, &01, &7B, &C0, &03, &FF, &E0, &17, &FF, &F0, &2F, &FF, &F0, &2F, &FF, &F0
	DEFB &1F, &FF, &F8, &1F, &FF, &F8, &1F, &FF, &F8, &1F, &FF, &FC, &1F, &FF, &FC, &1F
	DEFB &FF, &FC, &1F, &FF, &FC, &1F, &FF, &FC, &1F, &FF, &FE, &3F, &FF, &FE, &7F, &FF
	DEFB &FE, &3F, &FF, &FC, &0F, &FE, &00, &03, &9C, &70, &00, &00, &00, &00, &00, &00
	DEFB &FE, &FE, &FF, &FC, &40, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC
	DEFB &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FC, &00, &7F, &FE, &00
	DEFB &3F, &FC, &00, &1F, &E8, &00, &0F, &D0, &00, &07, &A0, &00, &07, &A0, &00, &07
	DEFB &C0, &00, &03, &C0, &00, &03, &C0, &00, &03, &C0, &00, &01, &C0, &00, &01, &C0
	DEFB &00, &01, &C0, &00, &01, &C0, &00, &01, &C0, &00, &00, &80, &00, &00, &00, &00
	DEFB &00, &80, &00, &01, &C0, &00, &03, &F0, &01, &77, &FC, &63, &8F, &FF, &FF, &FF
	;;	........................	@@@@@@@.@@@@@@@.@@@@@@@@
	;;	.......@.......@........	@@@@@@...@.......@@@@@@@
	;;	.......@@.@@@@@.........	@@@@@@...........@@@@@@@
	;;	.......@@@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@.@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@@@@@@@@@........	@@@@@@...........@@@@@@@
	;;	.......@@@@@@@@@........	@@@@@@...........@@@@@@@
	;;	........@@@@.@.@@.......	@@@@@@@...........@@@@@@
	;;	.......@.@@@@.@@@@......	@@@@@@.............@@@@@
	;;	......@@@@@@@@@@@@@.....	@@@.@...............@@@@
	;;	...@.@@@@@@@@@@@@@@@....	@@.@.................@@@
	;;	..@.@@@@@@@@@@@@@@@@....	@.@..................@@@
	;;	..@.@@@@@@@@@@@@@@@@....	@.@..................@@@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@..	@@.....................@
	;;	...@@@@@@@@@@@@@@@@@@@@.	@@......................
	;;	..@@@@@@@@@@@@@@@@@@@@@.	@.......................
	;;	.@@@@@@@@@@@@@@@@@@@@@@.	........................
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	....@@@@@@@@@@@.........	@@....................@@
	;;	......@@@..@@@...@@@....	@@@@...........@.@@@.@@@
	;;	........................	@@@@@@...@@...@@@...@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_BATMAN_FLY EQU &15
	DEFB &00, &00, &00, &00, &00, &00, &00, &40, &40, &00, &6F, &40, &00, &7F, &C0, &00
	DEFB &77, &40, &00, &7A, &C0, &00, &7F, &C0, &03, &73, &40, &0F, &6C, &D0, &1F, &AF
	DEFB &F0, &10, &2C, &A8, &2E, &D7, &5C, &1D, &F8, &DC, &3B, &FF, &EC, &3B, &BA, &EC
	DEFB &37, &70, &74, &37, &7D, &B4, &37, &7F, &A8, &1A, &1F, &1C, &1D, &A0, &9C, &0B
	DEFB &9F, &28, &05, &6C, &80, &00, &33, &80, &00, &31, &80, &00, &73, &00, &00, &67
	DEFB &80, &00, &F3, &00, &00, &63, &80, &00, &71, &80, &00, &30, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &BF, &BF, &FF, &10, &1F, &FF, &00, &1F, &FF, &00, &1F, &FF
	DEFB &00, &1F, &FF, &00, &1F, &FC, &00, &1F, &F0, &00, &0F, &E0, &0C, &87, &C0, &0F
	DEFB &83, &C0, &0C, &83, &80, &D7, &41, &81, &F8, &C1, &83, &FF, &E1, &83, &BA, &E1
	DEFB &87, &70, &71, &87, &7D, &B1, &87, &7F, &A9, &C2, &1F, &1D, &C1, &80, &1D, &E3
	DEFB &80, &0B, &F1, &60, &87, &F8, &33, &BF, &FF, &B5, &BF, &FF, &73, &3F, &FF, &67
	DEFB &BF, &FE, &F3, &7F, &FF, &6B, &BF, &FF, &75, &BF, &FF, &B6, &7F, &FF, &CF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@.@@@@@@@.@@@@@@
	;;	.........@.......@......	@@@@@@@@...@.......@@@@@
	;;	.........@@.@@@@.@......	@@@@@@@@...........@@@@@
	;;	.........@@@@@@@@@......	@@@@@@@@...........@@@@@
	;;	.........@@@.@@@.@......	@@@@@@@@...........@@@@@
	;;	.........@@@@.@.@@......	@@@@@@@@...........@@@@@
	;;	.........@@@@@@@@@......	@@@@@@.............@@@@@
	;;	......@@.@@@..@@.@......	@@@@................@@@@
	;;	....@@@@.@@.@@..@@.@....	@@@.........@@..@....@@@
	;;	...@@@@@@.@.@@@@@@@@....	@@..........@@@@@.....@@
	;;	...@......@.@@..@.@.@...	@@..........@@..@.....@@
	;;	..@.@@@.@@.@.@@@.@.@@@..	@.......@@.@.@@@.@.....@
	;;	...@@@.@@@@@@...@@.@@@..	@......@@@@@@...@@.....@
	;;	..@@@.@@@@@@@@@@@@@.@@..	@.....@@@@@@@@@@@@@....@
	;;	..@@@.@@@.@@@.@.@@@.@@..	@.....@@@.@@@.@.@@@....@
	;;	..@@.@@@.@@@.....@@@.@..	@....@@@.@@@.....@@@...@
	;;	..@@.@@@.@@@@@.@@.@@.@..	@....@@@.@@@@@.@@.@@...@
	;;	..@@.@@@.@@@@@@@@.@.@...	@....@@@.@@@@@@@@.@.@..@
	;;	...@@.@....@@@@@...@@@..	@@....@....@@@@@...@@@.@
	;;	...@@@.@@.@.....@..@@@..	@@.....@@..........@@@.@
	;;	....@.@@@..@@@@@..@.@...	@@@...@@@...........@.@@
	;;	.....@.@.@@.@@..@.......	@@@@...@.@@.....@....@@@
	;;	..........@@..@@@.......	@@@@@.....@@..@@@.@@@@@@
	;;	..........@@...@@.......	@@@@@@@@@.@@.@.@@.@@@@@@
	;;	.........@@@..@@........	@@@@@@@@.@@@..@@..@@@@@@
	;;	.........@@..@@@@.......	@@@@@@@@.@@..@@@@.@@@@@@
	;;	........@@@@..@@........	@@@@@@@.@@@@..@@.@@@@@@@
	;;	.........@@...@@@.......	@@@@@@@@.@@.@.@@@.@@@@@@
	;;	.........@@@...@@.......	@@@@@@@@.@@@.@.@@.@@@@@@
	;;	..........@@............	@@@@@@@@@.@@.@@..@@@@@@@
	;;	........................	@@@@@@@@@@..@@@@@@@@@@@@

				;; SPR_BATMAN_FLYB EQU &16
	DEFB &00, &00, &00, &00, &00, &00, &02, &02, &00, &03, &7C, &00, &03, &FE, &00, &02
	DEFB &FE, &00, &02, &FE, &00, &02, &FE, &00, &00, &ED, &C0, &0F, &F3, &F0, &1F, &FF
	DEFB &F8, &1F, &FF, &F8, &3F, &FF, &FC, &3F, &FF, &FC, &3F, &FF, &FC, &3F, &FF, &FC
	DEFB &3F, &FF, &FC, &3F, &FF, &FC, &3F, &FF, &FC, &1F, &FF, &F8, &1F, &FF, &F8, &0F
	DEFB &F1, &F0, &02, &02, &00, &00, &4C, &00, &01, &8C, &00, &01, &98, &00, &03, &1C
	DEFB &00, &03, &BC, &00, &07, &B8, &00, &07, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FD, &FD, &FF, &F8, &80, &FF, &F8, &00, &FF, &F8, &00, &FF, &F8
	DEFB &00, &FF, &F8, &00, &FF, &F8, &00, &3F, &F0, &00, &0F, &E0, &00, &07, &C0, &00
	DEFB &03, &C0, &00, &03, &80, &00, &01, &80, &00, &01, &80, &00, &01, &80, &00, &01
	DEFB &80, &00, &01, &80, &00, &01, &80, &00, &01, &C0, &00, &03, &C0, &00, &03, &E0
	DEFB &00, &07, &F0, &02, &0F, &FC, &4D, &FF, &FD, &AD, &FF, &FD, &9B, &FF, &FB, &5D
	DEFB &FF, &FB, &BD, &FF, &F7, &BB, &FF, &F7, &47, &FF, &F8, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@.@@@@@@@.@@@@@@@@@
	;;	......@.......@.........	@@@@@...@.......@@@@@@@@
	;;	......@@.@@@@@..........	@@@@@...........@@@@@@@@
	;;	......@@@@@@@@@.........	@@@@@...........@@@@@@@@
	;;	......@.@@@@@@@.........	@@@@@...........@@@@@@@@
	;;	......@.@@@@@@@.........	@@@@@...........@@@@@@@@
	;;	......@.@@@@@@@.........	@@@@@.............@@@@@@
	;;	........@@@.@@.@@@......	@@@@................@@@@
	;;	....@@@@@@@@..@@@@@@....	@@@..................@@@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	....@@@@@@@@...@@@@@....	@@@..................@@@
	;;	......@.......@.........	@@@@..........@.....@@@@
	;;	.........@..@@..........	@@@@@@...@..@@.@@@@@@@@@
	;;	.......@@...@@..........	@@@@@@.@@.@.@@.@@@@@@@@@
	;;	.......@@..@@...........	@@@@@@.@@..@@.@@@@@@@@@@
	;;	......@@...@@@..........	@@@@@.@@.@.@@@.@@@@@@@@@
	;;	......@@@.@@@@..........	@@@@@.@@@.@@@@.@@@@@@@@@
	;;	.....@@@@.@@@...........	@@@@.@@@@.@@@.@@@@@@@@@@
	;;	.....@@@................	@@@@.@@@.@...@@@@@@@@@@@
	;;	........................	@@@@@...@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_BM_STANDING EQU &17
img_bm_standing_1:
	DEFB &00, &00, &00, &00, &80, &80, &00, &BE, &80, &00, &FF, &80, &00, &DD, &80, &00
	DEFB &EB, &80, &00, &FF, &80, &00, &CC, &80, &00, &B3, &00, &00, &BF, &00, &01, &B3
	DEFB &00, &02, &5E, &80, &05, &A1, &40, &0B, &FF, &E0, &17, &75, &70, &2E, &E0, &B0
	DEFB &2E, &FB, &70, &2F, &7F, &20, &36, &3E, &40, &39, &80, &E0, &3B, &3E, &00, &3C
	DEFB &59, &60, &3E, &E7, &60, &3F, &6B, &60, &3F, &6B, &60, &3F, &63, &30, &3A, &66
	DEFB &98, &30, &C7, &C0, &30, &F1, &E0, &18, &78, &60, &00, &18, &00, &00, &00, &00
msk_bm_standing_1:
	DEFB &FF, &7F, &7F, &FE, &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE
	DEFB &00, &3F, &FE, &00, &3F, &FE, &00, &3F, &FE, &33, &7F, &FE, &3F, &7F, &FC, &33
	DEFB &7F, &F8, &1E, &3F, &F1, &A1, &5F, &E3, &FF, &EF, &C7, &75, &77, &8E, &E0, &B7
	DEFB &8E, &FB, &77, &8F, &7F, &2F, &86, &3E, &5F, &81, &80, &EF, &83, &00, &0F, &80
	DEFB &41, &0F, &80, &E7, &0F, &80, &63, &0F, &80, &63, &0F, &80, &63, &07, &80, &66
	DEFB &83, &84, &C7, &C7, &86, &F1, &EF, &C3, &7A, &6F, &E7, &9B, &9F, &FF, &E7, &FF
	;;	........................	@@@@@@@@.@@@@@@@.@@@@@@@
	;;	........@.......@.......	@@@@@@@...........@@@@@@
	;;	........@.@@@@@.@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@.@@@.@@.......	@@@@@@@...........@@@@@@
	;;	........@@@.@.@@@.......	@@@@@@@...........@@@@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	........@@..@@..@.......	@@@@@@@...........@@@@@@
	;;	........@.@@..@@........	@@@@@@@...@@..@@.@@@@@@@
	;;	........@.@@@@@@........	@@@@@@@...@@@@@@.@@@@@@@
	;;	.......@@.@@..@@........	@@@@@@....@@..@@.@@@@@@@
	;;	......@..@.@@@@.@.......	@@@@@......@@@@...@@@@@@
	;;	.....@.@@.@....@.@......	@@@@...@@.@....@.@.@@@@@
	;;	....@.@@@@@@@@@@@@@.....	@@@...@@@@@@@@@@@@@.@@@@
	;;	...@.@@@.@@@.@.@.@@@....	@@...@@@.@@@.@.@.@@@.@@@
	;;	..@.@@@.@@@.....@.@@....	@...@@@.@@@.....@.@@.@@@
	;;	..@.@@@.@@@@@.@@.@@@....	@...@@@.@@@@@.@@.@@@.@@@
	;;	..@.@@@@.@@@@@@@..@.....	@...@@@@.@@@@@@@..@.@@@@
	;;	..@@.@@...@@@@@..@......	@....@@...@@@@@..@.@@@@@
	;;	..@@@..@@.......@@@.....	@......@@.......@@@.@@@@
	;;	..@@@.@@..@@@@@.........	@.....@@............@@@@
	;;	..@@@@...@.@@..@.@@.....	@........@.....@....@@@@
	;;	..@@@@@.@@@..@@@.@@.....	@.......@@@..@@@....@@@@
	;;	..@@@@@@.@@.@.@@.@@.....	@........@@...@@....@@@@
	;;	..@@@@@@.@@.@.@@.@@.....	@........@@...@@....@@@@
	;;	..@@@@@@.@@...@@..@@....	@........@@...@@.....@@@
	;;	..@@@.@..@@..@@.@..@@...	@........@@..@@.@.....@@
	;;	..@@....@@...@@@@@......	@....@..@@...@@@@@...@@@
	;;	..@@....@@@@...@@@@.....	@....@@.@@@@...@@@@.@@@@
	;;	...@@....@@@@....@@.....	@@....@@.@@@@.@..@@.@@@@
	;;	...........@@...........	@@@..@@@@..@@.@@@..@@@@@
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@

				;; SPR_WOLF_0 EQU &18
	DEFB &00, &00, &00, &01, &F3, &80, &07, &FB, &C0, &0F, &FD, &E0, &1F, &1F, &D0, &07
	DEFB &8F, &90, &0F, &95, &50, &0F, &C0, &20, &1F, &EF, &40, &03, &7F, &80, &06, &BF
	DEFB &C0, &00, &7D, &40, &00, &3F, &C0, &01, &DC, &40, &03, &E8, &A0, &07, &AA, &A0
	DEFB &0F, &77, &50, &0F, &9F, &C8, &07, &6F, &DC, &00, &ED, &D8, &00, &1F, &C0, &00
	DEFB &FF, &80, &00, &71, &C0, &00, &7B, &C0, &00, &3B, &C0, &00, &7B, &80, &00, &F7
	DEFB &00, &01, &E7, &C0, &00, &FB, &E0, &00, &7D, &80, &00, &34, &00, &00, &00, &00
	DEFB &FE, &0C, &7F, &F9, &F3, &BF, &F7, &FB, &DF, &EF, &FD, &EF, &DF, &1F, &D7, &E7
	DEFB &8F, &97, &EF, &85, &17, &EF, &C0, &2F, &DF, &EF, &5F, &E3, &7F, &BF, &F6, &BF
	DEFB &DF, &F9, &7D, &5F, &FE, &3F, &DF, &FC, &1C, &5F, &F8, &08, &8F, &F0, &08, &8F
	DEFB &E0, &00, &07, &E0, &00, &0B, &F0, &60, &1D, &F8, &E0, &1B, &FF, &00, &07, &FE
	DEFB &00, &3F, &FF, &00, &1F, &FF, &00, &1F, &FF, &80, &1F, &FF, &00, &3F, &FE, &00
	DEFB &3F, &FC, &00, &1F, &FE, &00, &0F, &FF, &00, &1F, &FF, &80, &7F, &FF, &CB, &FF
	;;	........................	@@@@@@@.....@@...@@@@@@@
	;;	.......@@@@@..@@@.......	@@@@@..@@@@@..@@@.@@@@@@
	;;	.....@@@@@@@@.@@@@......	@@@@.@@@@@@@@.@@@@.@@@@@
	;;	....@@@@@@@@@@.@@@@.....	@@@.@@@@@@@@@@.@@@@.@@@@
	;;	...@@@@@...@@@@@@@.@....	@@.@@@@@...@@@@@@@.@.@@@
	;;	.....@@@@...@@@@@..@....	@@@..@@@@...@@@@@..@.@@@
	;;	....@@@@@..@.@.@.@.@....	@@@.@@@@@....@.@...@.@@@
	;;	....@@@@@@........@.....	@@@.@@@@@@........@.@@@@
	;;	...@@@@@@@@.@@@@.@......	@@.@@@@@@@@.@@@@.@.@@@@@
	;;	......@@.@@@@@@@@.......	@@@...@@.@@@@@@@@.@@@@@@
	;;	.....@@.@.@@@@@@@@......	@@@@.@@.@.@@@@@@@@.@@@@@
	;;	.........@@@@@.@.@......	@@@@@..@.@@@@@.@.@.@@@@@
	;;	..........@@@@@@@@......	@@@@@@@...@@@@@@@@.@@@@@
	;;	.......@@@.@@@...@......	@@@@@@.....@@@...@.@@@@@
	;;	......@@@@@.@...@.@.....	@@@@@.......@...@...@@@@
	;;	.....@@@@.@.@.@.@.@.....	@@@@........@...@...@@@@
	;;	....@@@@.@@@.@@@.@.@....	@@@..................@@@
	;;	....@@@@@..@@@@@@@..@...	@@@.................@.@@
	;;	.....@@@.@@.@@@@@@.@@@..	@@@@.....@@........@@@.@
	;;	........@@@.@@.@@@.@@...	@@@@@...@@@........@@.@@
	;;	...........@@@@@@@......	@@@@@@@@.............@@@
	;;	........@@@@@@@@@.......	@@@@@@@...........@@@@@@
	;;	.........@@@...@@@......	@@@@@@@@...........@@@@@
	;;	.........@@@@.@@@@......	@@@@@@@@...........@@@@@
	;;	..........@@@.@@@@......	@@@@@@@@@..........@@@@@
	;;	.........@@@@.@@@.......	@@@@@@@@..........@@@@@@
	;;	........@@@@.@@@........	@@@@@@@...........@@@@@@
	;;	.......@@@@..@@@@@......	@@@@@@.............@@@@@
	;;	........@@@@@.@@@@@.....	@@@@@@@.............@@@@
	;;	.........@@@@@.@@.......	@@@@@@@@...........@@@@@
	;;	..........@@.@..........	@@@@@@@@@........@@@@@@@
	;;	........................	@@@@@@@@@@..@.@@@@@@@@@@

				;; SPR_WOLF_1 EQU &19
	DEFB &00, &00, &00, &01, &F3, &80, &07, &FB, &C0, &0F, &FD, &E0, &1F, &1F, &D0, &07
	DEFB &8F, &90, &0F, &95, &50, &0F, &C0, &20, &1F, &EF, &40, &03, &7F, &80, &06, &BF
	DEFB &C0, &00, &7D, &40, &00, &3F, &C0, &01, &DC, &40, &03, &E8, &A0, &03, &EA, &A0
	DEFB &03, &B7, &60, &03, &DF, &E0, &01, &E7, &F0, &00, &D9, &D8, &00, &3B, &D8, &00
	DEFB &C5, &80, &00, &FB, &C0, &00, &F9, &E0, &01, &F0, &E0, &03, &C0, &E0, &07, &81
	DEFB &C0, &03, &E1, &F0, &01, &F0, &F8, &00, &D0, &7C, &00, &00, &30, &00, &00, &00
	DEFB &FE, &0C, &7F, &F9, &F3, &BF, &F7, &FB, &DF, &EF, &FD, &EF, &DF, &1F, &D7, &E7
	DEFB &8F, &97, &EF, &85, &17, &EF, &C0, &2F, &DF, &EF, &5F, &E3, &7F, &BF, &F6, &BF
	DEFB &DF, &F9, &7D, &5F, &FE, &3F, &DF, &FC, &1C, &5F, &F8, &08, &8F, &F8, &08, &8F
	DEFB &F8, &00, &0F, &F8, &00, &0F, &FC, &00, &07, &FE, &18, &1B, &FF, &38, &1B, &FE
	DEFB &00, &27, &FE, &00, &1F, &FE, &00, &0F, &FC, &06, &0F, &F8, &0E, &0F, &F0, &1C
	DEFB &0F, &F8, &0C, &07, &FC, &06, &03, &FE, &07, &01, &FF, &2F, &83, &FF, &FF, &CF
	;;	........................	@@@@@@@.....@@...@@@@@@@
	;;	.......@@@@@..@@@.......	@@@@@..@@@@@..@@@.@@@@@@
	;;	.....@@@@@@@@.@@@@......	@@@@.@@@@@@@@.@@@@.@@@@@
	;;	....@@@@@@@@@@.@@@@.....	@@@.@@@@@@@@@@.@@@@.@@@@
	;;	...@@@@@...@@@@@@@.@....	@@.@@@@@...@@@@@@@.@.@@@
	;;	.....@@@@...@@@@@..@....	@@@..@@@@...@@@@@..@.@@@
	;;	....@@@@@..@.@.@.@.@....	@@@.@@@@@....@.@...@.@@@
	;;	....@@@@@@........@.....	@@@.@@@@@@........@.@@@@
	;;	...@@@@@@@@.@@@@.@......	@@.@@@@@@@@.@@@@.@.@@@@@
	;;	......@@.@@@@@@@@.......	@@@...@@.@@@@@@@@.@@@@@@
	;;	.....@@.@.@@@@@@@@......	@@@@.@@.@.@@@@@@@@.@@@@@
	;;	.........@@@@@.@.@......	@@@@@..@.@@@@@.@.@.@@@@@
	;;	..........@@@@@@@@......	@@@@@@@...@@@@@@@@.@@@@@
	;;	.......@@@.@@@...@......	@@@@@@.....@@@...@.@@@@@
	;;	......@@@@@.@...@.@.....	@@@@@.......@...@...@@@@
	;;	......@@@@@.@.@.@.@.....	@@@@@.......@...@...@@@@
	;;	......@@@.@@.@@@.@@.....	@@@@@...............@@@@
	;;	......@@@@.@@@@@@@@.....	@@@@@...............@@@@
	;;	.......@@@@..@@@@@@@....	@@@@@@...............@@@
	;;	........@@.@@..@@@.@@...	@@@@@@@....@@......@@.@@
	;;	..........@@@.@@@@.@@...	@@@@@@@@..@@@......@@.@@
	;;	........@@...@.@@.......	@@@@@@@...........@..@@@
	;;	........@@@@@.@@@@......	@@@@@@@............@@@@@
	;;	........@@@@@..@@@@.....	@@@@@@@.............@@@@
	;;	.......@@@@@....@@@.....	@@@@@@.......@@.....@@@@
	;;	......@@@@......@@@.....	@@@@@.......@@@.....@@@@
	;;	.....@@@@......@@@......	@@@@.......@@@......@@@@
	;;	......@@@@@....@@@@@....	@@@@@.......@@.......@@@
	;;	.......@@@@@....@@@@@...	@@@@@@.......@@.......@@
	;;	........@@.@.....@@@@@..	@@@@@@@......@@@.......@
	;;	..................@@....	@@@@@@@@..@.@@@@@.....@@
	;;	........................	@@@@@@@@@@@@@@@@@@..@@@@

				;; SPR_WOLF_2 EQU &1A
	DEFB &00, &00, &00, &01, &F3, &80, &07, &FB, &C0, &0F, &FD, &E0, &1F, &1F, &D0, &07
	DEFB &8F, &90, &0F, &95, &50, &0F, &C0, &20, &1F, &EF, &40, &03, &7F, &80, &06, &BF
	DEFB &C0, &00, &7D, &40, &00, &3F, &C0, &01, &DC, &40, &03, &E8, &A0, &07, &EA, &A0
	DEFB &0F, &77, &70, &0E, &FF, &D8, &07, &1F, &D6, &02, &ED, &D6, &00, &DF, &8C, &00
	DEFB &3B, &00, &00, &7D, &80, &00, &BD, &00, &01, &DC, &00, &00, &B8, &00, &00, &3C
	DEFB &00, &00, &3A, &00, &00, &1F, &00, &00, &0F, &80, &00, &06, &80, &00, &00, &00
	DEFB &FE, &0C, &7F, &F9, &F3, &BF, &F7, &FB, &DF, &EF, &FD, &EF, &DF, &1F, &D7, &E7
	DEFB &8F, &97, &EF, &85, &17, &EF, &C0, &2F, &DF, &EF, &5F, &E3, &7F, &BF, &F6, &BF
	DEFB &DF, &F9, &7D, &5F, &FE, &3F, &DF, &FC, &1C, &5F, &F8, &08, &8F, &F0, &08, &8F
	DEFB &E0, &00, &07, &E0, &00, &01, &F0, &00, &06, &F8, &E0, &06, &FC, &C0, &2D, &FF
	DEFB &00, &73, &FF, &00, &3F, &FE, &00, &7F, &FC, &00, &FF, &FE, &03, &FF, &FF, &01
	DEFB &FF, &FF, &80, &FF, &FF, &C0, &7F, &FF, &E0, &3F, &FF, &F0, &3F, &FF, &F9, &7F
	;;	........................	@@@@@@@.....@@...@@@@@@@
	;;	.......@@@@@..@@@.......	@@@@@..@@@@@..@@@.@@@@@@
	;;	.....@@@@@@@@.@@@@......	@@@@.@@@@@@@@.@@@@.@@@@@
	;;	....@@@@@@@@@@.@@@@.....	@@@.@@@@@@@@@@.@@@@.@@@@
	;;	...@@@@@...@@@@@@@.@....	@@.@@@@@...@@@@@@@.@.@@@
	;;	.....@@@@...@@@@@..@....	@@@..@@@@...@@@@@..@.@@@
	;;	....@@@@@..@.@.@.@.@....	@@@.@@@@@....@.@...@.@@@
	;;	....@@@@@@........@.....	@@@.@@@@@@........@.@@@@
	;;	...@@@@@@@@.@@@@.@......	@@.@@@@@@@@.@@@@.@.@@@@@
	;;	......@@.@@@@@@@@.......	@@@...@@.@@@@@@@@.@@@@@@
	;;	.....@@.@.@@@@@@@@......	@@@@.@@.@.@@@@@@@@.@@@@@
	;;	.........@@@@@.@.@......	@@@@@..@.@@@@@.@.@.@@@@@
	;;	..........@@@@@@@@......	@@@@@@@...@@@@@@@@.@@@@@
	;;	.......@@@.@@@...@......	@@@@@@.....@@@...@.@@@@@
	;;	......@@@@@.@...@.@.....	@@@@@.......@...@...@@@@
	;;	.....@@@@@@.@.@.@.@.....	@@@@........@...@...@@@@
	;;	....@@@@.@@@.@@@.@@@....	@@@..................@@@
	;;	....@@@.@@@@@@@@@@.@@...	@@@....................@
	;;	.....@@@...@@@@@@@.@.@@.	@@@@.................@@.
	;;	......@.@@@.@@.@@@.@.@@.	@@@@@...@@@..........@@.
	;;	........@@.@@@@@@...@@..	@@@@@@..@@........@.@@.@
	;;	..........@@@.@@........	@@@@@@@@.........@@@..@@
	;;	.........@@@@@.@@.......	@@@@@@@@..........@@@@@@
	;;	........@.@@@@.@........	@@@@@@@..........@@@@@@@
	;;	.......@@@.@@@..........	@@@@@@..........@@@@@@@@
	;;	........@.@@@...........	@@@@@@@.......@@@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@.......@@@@@@@@@
	;;	..........@@@.@.........	@@@@@@@@@.......@@@@@@@@
	;;	...........@@@@@........	@@@@@@@@@@.......@@@@@@@
	;;	............@@@@@.......	@@@@@@@@@@@.......@@@@@@
	;;	.............@@.@.......	@@@@@@@@@@@@......@@@@@@
	;;	........................	@@@@@@@@@@@@@..@.@@@@@@@

				;; SPR_WOLF_B0 EQU &1B
	DEFB &00, &00, &00, &01, &CF, &80, &03, &F3, &E0, &07, &F9, &F0, &0F, &EE, &F8, &0F
	DEFB &E1, &A0, &0F, &F7, &B0, &07, &9B, &B0, &0B, &C7, &78, &0D, &BF, &C0, &07, &BF
	DEFB &60, &05, &5F, &00, &01, &7B, &C0, &03, &FF, &E0, &03, &9F, &A0, &03, &BF, &A0
	DEFB &07, &BF, &A0, &17, &7F, &A0, &36, &FF, &40, &19, &FF, &80, &03, &FB, &80, &03
	DEFB &E7, &00, &03, &EF, &00, &03, &CF, &00, &01, &D6, &00, &02, &EF, &00, &07, &EF
	DEFB &00, &07, &EF, &00, &01, &E7, &00, &00, &E0, &00, &00, &00, &00, &00, &00, &00
	DEFB &FE, &30, &7F, &FD, &CF, &9F, &FB, &F3, &EF, &F7, &F8, &F7, &EF, &EE, &7B, &EF
	DEFB &E0, &27, &EF, &F0, &37, &F7, &98, &37, &EB, &C0, &7B, &ED, &80, &C7, &F7, &80
	DEFB &6F, &F5, &00, &1F, &F8, &00, &1F, &F8, &00, &0F, &F8, &00, &0F, &F8, &00, &0F
	DEFB &E0, &00, &0F, &D0, &00, &0F, &B0, &00, &1F, &D8, &00, &3F, &E0, &00, &3F, &F8
	DEFB &00, &7F, &F8, &00, &7F, &F8, &00, &7F, &FC, &00, &FF, &F8, &00, &7F, &F0, &00
	DEFB &7F, &F0, &00, &7F, &F8, &00, &7F, &FE, &08, &FF, &FF, &1F, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@...@@.....@@@@@@@
	;;	.......@@@..@@@@@.......	@@@@@@.@@@..@@@@@..@@@@@
	;;	......@@@@@@..@@@@@.....	@@@@@.@@@@@@..@@@@@.@@@@
	;;	.....@@@@@@@@..@@@@@....	@@@@.@@@@@@@@...@@@@.@@@
	;;	....@@@@@@@.@@@.@@@@@...	@@@.@@@@@@@.@@@..@@@@.@@
	;;	....@@@@@@@....@@.@.....	@@@.@@@@@@@.......@..@@@
	;;	....@@@@@@@@.@@@@.@@....	@@@.@@@@@@@@......@@.@@@
	;;	.....@@@@..@@.@@@.@@....	@@@@.@@@@..@@.....@@.@@@
	;;	....@.@@@@...@@@.@@@@...	@@@.@.@@@@.......@@@@.@@
	;;	....@@.@@.@@@@@@@@......	@@@.@@.@@.......@@...@@@
	;;	.....@@@@.@@@@@@.@@.....	@@@@.@@@@........@@.@@@@
	;;	.....@.@.@.@@@@@........	@@@@.@.@...........@@@@@
	;;	.......@.@@@@.@@@@......	@@@@@..............@@@@@
	;;	......@@@@@@@@@@@@@.....	@@@@@...............@@@@
	;;	......@@@..@@@@@@.@.....	@@@@@...............@@@@
	;;	......@@@.@@@@@@@.@.....	@@@@@...............@@@@
	;;	.....@@@@.@@@@@@@.@.....	@@@.................@@@@
	;;	...@.@@@.@@@@@@@@.@.....	@@.@................@@@@
	;;	..@@.@@.@@@@@@@@.@......	@.@@...............@@@@@
	;;	...@@..@@@@@@@@@@.......	@@.@@.............@@@@@@
	;;	......@@@@@@@.@@@.......	@@@...............@@@@@@
	;;	......@@@@@..@@@........	@@@@@............@@@@@@@
	;;	......@@@@@.@@@@........	@@@@@............@@@@@@@
	;;	......@@@@..@@@@........	@@@@@............@@@@@@@
	;;	.......@@@.@.@@.........	@@@@@@..........@@@@@@@@
	;;	......@.@@@.@@@@........	@@@@@............@@@@@@@
	;;	.....@@@@@@.@@@@........	@@@@.............@@@@@@@
	;;	.....@@@@@@.@@@@........	@@@@.............@@@@@@@
	;;	.......@@@@..@@@........	@@@@@............@@@@@@@
	;;	........@@@.............	@@@@@@@.....@...@@@@@@@@
	;;	........................	@@@@@@@@...@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_WOLF_B1 EQU &1C
	DEFB &00, &00, &00, &01, &CF, &80, &03, &F3, &E0, &07, &F9, &F0, &0F, &EE, &F8, &0F
	DEFB &E1, &A0, &0F, &F7, &B0, &07, &9B, &B0, &0B, &C7, &78, &0D, &BF, &C0, &07, &BF
	DEFB &60, &05, &5E, &00, &01, &7B, &C0, &02, &BF, &E0, &03, &DF, &A0, &01, &EF, &A0
	DEFB &02, &EF, &80, &02, &EF, &80, &02, &9F, &00, &01, &6F, &80, &07, &6F, &80, &0F
	DEFB &97, &00, &0F, &EF, &00, &0E, &1E, &00, &37, &1C, &00, &3E, &0E, &00, &1F, &0F
	DEFB &00, &07, &37, &00, &00, &3E, &00, &00, &0D, &00, &00, &00, &00, &00, &00, &00
	DEFB &FE, &30, &7F, &FD, &CF, &9F, &FB, &F3, &EF, &F7, &F8, &F7, &EF, &EE, &7B, &EF
	DEFB &E0, &27, &EF, &F0, &37, &F7, &98, &37, &EB, &C0, &7B, &ED, &80, &C7, &F7, &80
	DEFB &6F, &F5, &00, &1F, &F9, &00, &1F, &F8, &00, &0F, &F8, &00, &0F, &FC, &00, &0F
	DEFB &F8, &00, &1F, &F8, &00, &3F, &F8, &00, &7F, &F8, &60, &3F, &F0, &60, &3F, &E0
	DEFB &00, &7F, &E0, &00, &7F, &C0, &00, &FF, &80, &41, &FF, &80, &E0, &FF, &C0, &40
	DEFB &7F, &E0, &00, &7F, &F8, &80, &FF, &FF, &C0, &7F, &FF, &F2, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@...@@.....@@@@@@@
	;;	.......@@@..@@@@@.......	@@@@@@.@@@..@@@@@..@@@@@
	;;	......@@@@@@..@@@@@.....	@@@@@.@@@@@@..@@@@@.@@@@
	;;	.....@@@@@@@@..@@@@@....	@@@@.@@@@@@@@...@@@@.@@@
	;;	....@@@@@@@.@@@.@@@@@...	@@@.@@@@@@@.@@@..@@@@.@@
	;;	....@@@@@@@....@@.@.....	@@@.@@@@@@@.......@..@@@
	;;	....@@@@@@@@.@@@@.@@....	@@@.@@@@@@@@......@@.@@@
	;;	.....@@@@..@@.@@@.@@....	@@@@.@@@@..@@.....@@.@@@
	;;	....@.@@@@...@@@.@@@@...	@@@.@.@@@@.......@@@@.@@
	;;	....@@.@@.@@@@@@@@......	@@@.@@.@@.......@@...@@@
	;;	.....@@@@.@@@@@@.@@.....	@@@@.@@@@........@@.@@@@
	;;	.....@.@.@.@@@@.........	@@@@.@.@...........@@@@@
	;;	.......@.@@@@.@@@@......	@@@@@..@...........@@@@@
	;;	......@.@.@@@@@@@@@.....	@@@@@...............@@@@
	;;	......@@@@.@@@@@@.@.....	@@@@@...............@@@@
	;;	.......@@@@.@@@@@.@.....	@@@@@@..............@@@@
	;;	......@.@@@.@@@@@.......	@@@@@..............@@@@@
	;;	......@.@@@.@@@@@.......	@@@@@.............@@@@@@
	;;	......@.@..@@@@@........	@@@@@............@@@@@@@
	;;	.......@.@@.@@@@@.......	@@@@@....@@.......@@@@@@
	;;	.....@@@.@@.@@@@@.......	@@@@.....@@.......@@@@@@
	;;	....@@@@@..@.@@@........	@@@..............@@@@@@@
	;;	....@@@@@@@.@@@@........	@@@..............@@@@@@@
	;;	....@@@....@@@@.........	@@..............@@@@@@@@
	;;	..@@.@@@...@@@..........	@........@.....@@@@@@@@@
	;;	..@@@@@.....@@@.........	@.......@@@.....@@@@@@@@
	;;	...@@@@@....@@@@........	@@.......@.......@@@@@@@
	;;	.....@@@..@@.@@@........	@@@..............@@@@@@@
	;;	..........@@@@@.........	@@@@@...@.......@@@@@@@@
	;;	............@@.@........	@@@@@@@@@@.......@@@@@@@
	;;	........................	@@@@@@@@@@@@..@.@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_WOLF_B2 EQU &1D
	DEFB &00, &00, &00, &01, &CF, &80, &03, &F3, &E0, &07, &F9, &F0, &0F, &EE, &F8, &0F
	DEFB &E1, &A0, &0F, &F7, &B0, &07, &9B, &B0, &0B, &C7, &78, &0D, &BF, &C0, &07, &BF
	DEFB &60, &05, &5F, &00, &00, &7B, &C0, &03, &FF, &E0, &03, &DF, &B0, &07, &DF, &B8
	DEFB &0F, &BF, &B8, &17, &7F, &B8, &34, &FF, &88, &3B, &FF, &B0, &03, &FD, &B0, &03
	DEFB &FB, &00, &01, &E0, &00, &01, &D8, &00, &00, &F0, &00, &03, &7C, &00, &00, &3E
	DEFB &00, &00, &D8, &00, &00, &F6, &00, &00, &34, &00, &00, &00, &00, &00, &00, &00
	DEFB &FE, &30, &7F, &FD, &CF, &9F, &FB, &F3, &EF, &F7, &F8, &F7, &EF, &EE, &7B, &EF
	DEFB &E0, &27, &EF, &F0, &37, &F7, &98, &37, &EB, &C0, &7B, &ED, &80, &C7, &F7, &80
	DEFB &6F, &F5, &00, &1F, &F8, &00, &1F, &F8, &00, &0F, &F8, &00, &07, &F0, &00, &03
	DEFB &E0, &00, &03, &D0, &00, &03, &B0, &00, &03, &B8, &00, &37, &C0, &00, &37, &F8
	DEFB &00, &4F, &FC, &00, &FF, &FC, &03, &FF, &FC, &03, &FF, &F8, &01, &FF, &FC, &00
	DEFB &FF, &FE, &01, &FF, &FE, &00, &FF, &FF, &01, &FF, &FF, &CB, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@...@@.....@@@@@@@
	;;	.......@@@..@@@@@.......	@@@@@@.@@@..@@@@@..@@@@@
	;;	......@@@@@@..@@@@@.....	@@@@@.@@@@@@..@@@@@.@@@@
	;;	.....@@@@@@@@..@@@@@....	@@@@.@@@@@@@@...@@@@.@@@
	;;	....@@@@@@@.@@@.@@@@@...	@@@.@@@@@@@.@@@..@@@@.@@
	;;	....@@@@@@@....@@.@.....	@@@.@@@@@@@.......@..@@@
	;;	....@@@@@@@@.@@@@.@@....	@@@.@@@@@@@@......@@.@@@
	;;	.....@@@@..@@.@@@.@@....	@@@@.@@@@..@@.....@@.@@@
	;;	....@.@@@@...@@@.@@@@...	@@@.@.@@@@.......@@@@.@@
	;;	....@@.@@.@@@@@@@@......	@@@.@@.@@.......@@...@@@
	;;	.....@@@@.@@@@@@.@@.....	@@@@.@@@@........@@.@@@@
	;;	.....@.@.@.@@@@@........	@@@@.@.@...........@@@@@
	;;	.........@@@@.@@@@......	@@@@@..............@@@@@
	;;	......@@@@@@@@@@@@@.....	@@@@@...............@@@@
	;;	......@@@@.@@@@@@.@@....	@@@@@................@@@
	;;	.....@@@@@.@@@@@@.@@@...	@@@@..................@@
	;;	....@@@@@.@@@@@@@.@@@...	@@@...................@@
	;;	...@.@@@.@@@@@@@@.@@@...	@@.@..................@@
	;;	..@@.@..@@@@@@@@@...@...	@.@@..................@@
	;;	..@@@.@@@@@@@@@@@.@@....	@.@@@.............@@.@@@
	;;	......@@@@@@@@.@@.@@....	@@................@@.@@@
	;;	......@@@@@@@.@@........	@@@@@............@..@@@@
	;;	.......@@@@.............	@@@@@@..........@@@@@@@@
	;;	.......@@@.@@...........	@@@@@@........@@@@@@@@@@
	;;	........@@@@............	@@@@@@........@@@@@@@@@@
	;;	......@@.@@@@@..........	@@@@@..........@@@@@@@@@
	;;	..........@@@@@.........	@@@@@@..........@@@@@@@@
	;;	........@@.@@...........	@@@@@@@........@@@@@@@@@
	;;	........@@@@.@@.........	@@@@@@@.........@@@@@@@@
	;;	..........@@.@..........	@@@@@@@@.......@@@@@@@@@
	;;	........................	@@@@@@@@@@..@.@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_DEMON EQU &1E
	DEFB &00, &00, &00, &00, &7F, &40, &01, &FE, &C0, &03, &FD, &C0, &03, &FB, &D0, &07
	DEFB &FB, &D8, &07, &FD, &D8, &07, &FE, &38, &0F, &E3, &E4, &0F, &9D, &CC, &0F, &E2
	DEFB &90, &0F, &C0, &08, &0F, &EE, &DA, &13, &F0, &42, &3F, &FC, &EE, &2F, &F8, &82
	DEFB &37, &F7, &74, &3F, &E7, &FC, &1F, &C6, &FA, &0F, &88, &76, &06, &1F, &8C, &0E
	DEFB &80, &F0, &0F, &C1, &0A, &0F, &E1, &DA, &1F, &D1, &D4, &1E, &EC, &0C, &1E, &F7
	DEFB &FA, &3C, &3F, &10, &3C, &0F, &F0, &30, &03, &E0, &00, &00, &00, &00, &00, &00
	DEFB &FF, &80, &BF, &FE, &00, &5F, &FC, &00, &DF, &F8, &01, &CF, &F8, &03, &C7, &F0
	DEFB &03, &C3, &F0, &01, &C3, &F0, &00, &03, &E0, &00, &01, &E0, &00, &01, &E0, &00
	DEFB &03, &E0, &00, &09, &E0, &0E, &18, &C0, &00, &00, &80, &00, &00, &80, &00, &00
	DEFB &80, &00, &01, &80, &00, &01, &C0, &00, &00, &E0, &00, &00, &F0, &00, &01, &E0
	DEFB &00, &01, &E0, &01, &08, &E0, &01, &D8, &C0, &01, &D1, &C0, &00, &01, &C0, &00
	DEFB &00, &81, &00, &05, &81, &C0, &07, &83, &F0, &0F, &CF, &FC, &1F, &FF, &FF, &FF
	;;	........................	@@@@@@@@@.......@.@@@@@@
	;;	.........@@@@@@@.@......	@@@@@@@..........@.@@@@@
	;;	.......@@@@@@@@.@@......	@@@@@@..........@@.@@@@@
	;;	......@@@@@@@@.@@@......	@@@@@..........@@@..@@@@
	;;	......@@@@@@@.@@@@.@....	@@@@@.........@@@@...@@@
	;;	.....@@@@@@@@.@@@@.@@...	@@@@..........@@@@....@@
	;;	.....@@@@@@@@@.@@@.@@...	@@@@...........@@@....@@
	;;	.....@@@@@@@@@@...@@@...	@@@@..................@@
	;;	....@@@@@@@...@@@@@..@..	@@@....................@
	;;	....@@@@@..@@@.@@@..@@..	@@@....................@
	;;	....@@@@@@@...@.@..@....	@@@...................@@
	;;	....@@@@@@..........@...	@@@.................@..@
	;;	....@@@@@@@.@@@.@@.@@.@.	@@@.........@@@....@@...
	;;	...@..@@@@@@.....@....@.	@@......................
	;;	..@@@@@@@@@@@@..@@@.@@@.	@.......................
	;;	..@.@@@@@@@@@...@.....@.	@.......................
	;;	..@@.@@@@@@@.@@@.@@@.@..	@......................@
	;;	..@@@@@@@@@..@@@@@@@@@..	@......................@
	;;	...@@@@@@@...@@.@@@@@.@.	@@......................
	;;	....@@@@@...@....@@@.@@.	@@@.....................
	;;	.....@@....@@@@@@...@@..	@@@@...................@
	;;	....@@@.@.......@@@@....	@@@....................@
	;;	....@@@@@@.....@....@.@.	@@@............@....@...
	;;	....@@@@@@@....@@@.@@.@.	@@@............@@@.@@...
	;;	...@@@@@@@.@...@@@.@.@..	@@.............@@@.@...@
	;;	...@@@@.@@@.@@......@@..	@@.....................@
	;;	...@@@@.@@@@.@@@@@@@@.@.	@@......................
	;;	..@@@@....@@@@@@...@....	@......@.............@.@
	;;	..@@@@......@@@@@@@@....	@......@@@...........@@@
	;;	..@@..........@@@@@.....	@.....@@@@@@........@@@@
	;;	........................	@@..@@@@@@@@@@.....@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_DEMONB EQU &1F
	DEFB &00, &00, &00, &1C, &FE, &00, &13, &FF, &80, &0F, &F9, &E0, &1F, &FE, &F0, &3F
	DEFB &FF, &F8, &3F, &FF, &F8, &7F, &FF, &FC, &7F, &FF, &F4, &3F, &BF, &1C, &3F, &EA
	DEFB &0A, &31, &FE, &06, &6E, &D4, &06, &7B, &7F, &26, &75, &3F, &C6, &77, &7F, &0E
	DEFB &77, &7E, &1E, &3E, &FE, &7C, &79, &FE, &6C, &73, &FF, &1C, &7B, &FF, &F8, &37
	DEFB &FF, &F8, &17, &FF, &F4, &17, &FF, &D6, &0F, &FE, &2E, &0F, &EF, &40, &0F, &DE
	DEFB &00, &1F, &C0, &00, &1F, &80, &00, &1F, &00, &00, &0C, &00, &00, &00, &00, &00
	DEFB &E3, &01, &FF, &DC, &00, &7F, &D0, &00, &1F, &E0, &00, &0F, &C0, &00, &07, &80
	DEFB &00, &03, &80, &00, &03, &00, &00, &01, &00, &00, &01, &80, &00, &01, &80, &00
	DEFB &00, &80, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &80, &00, &01, &00, &00, &01, &00, &00, &01, &00, &00, &03, &80
	DEFB &00, &03, &C0, &00, &01, &C0, &00, &00, &E0, &00, &00, &E0, &00, &11, &E0, &00
	DEFB &BF, &C0, &01, &FF, &C0, &3F, &FF, &C0, &7F, &FF, &E0, &FF, &FF, &F3, &FF, &FF
	;;	........................	@@@...@@.......@@@@@@@@@
	;;	...@@@..@@@@@@@.........	@@.@@@...........@@@@@@@
	;;	...@..@@@@@@@@@@@.......	@@.@...............@@@@@
	;;	....@@@@@@@@@..@@@@.....	@@@.................@@@@
	;;	...@@@@@@@@@@@@.@@@@....	@@...................@@@
	;;	..@@@@@@@@@@@@@@@@@@@...	@.....................@@
	;;	..@@@@@@@@@@@@@@@@@@@...	@.....................@@
	;;	.@@@@@@@@@@@@@@@@@@@@@..	.......................@
	;;	.@@@@@@@@@@@@@@@@@@@.@..	.......................@
	;;	..@@@@@@@.@@@@@@...@@@..	@......................@
	;;	..@@@@@@@@@.@.@.....@.@.	@.......................
	;;	..@@...@@@@@@@@......@@.	@.......................
	;;	.@@.@@@.@@.@.@.......@@.	........................
	;;	.@@@@.@@.@@@@@@@..@..@@.	........................
	;;	.@@@.@.@..@@@@@@@@...@@.	........................
	;;	.@@@.@@@.@@@@@@@....@@@.	........................
	;;	.@@@.@@@.@@@@@@....@@@@.	........................
	;;	..@@@@@.@@@@@@@..@@@@@..	@......................@
	;;	.@@@@..@@@@@@@@..@@.@@..	.......................@
	;;	.@@@..@@@@@@@@@@...@@@..	.......................@
	;;	.@@@@.@@@@@@@@@@@@@@@...	......................@@
	;;	..@@.@@@@@@@@@@@@@@@@...	@.....................@@
	;;	...@.@@@@@@@@@@@@@@@.@..	@@.....................@
	;;	...@.@@@@@@@@@@@@@.@.@@.	@@......................
	;;	....@@@@@@@@@@@...@.@@@.	@@@.....................
	;;	....@@@@@@@.@@@@.@......	@@@................@...@
	;;	....@@@@@@.@@@@.........	@@@.............@.@@@@@@
	;;	...@@@@@@@..............	@@.............@@@@@@@@@
	;;	...@@@@@@...............	@@........@@@@@@@@@@@@@@
	;;	...@@@@@................	@@.......@@@@@@@@@@@@@@@
	;;	....@@..................	@@@.....@@@@@@@@@@@@@@@@
	;;	........................	@@@@..@@@@@@@@@@@@@@@@@@

				;; SPR_SHARK_0 EQU &20
	DEFB &00, &00, &00, &00, &3E, &00, &01, &C1, &C0, &06, &00, &30, &18, &00, &88, &26
	DEFB &00, &04, &41, &08, &08, &40, &80, &1C, &80, &80, &BC, &90, &41, &C4, &B8, &4B
	DEFB &C0, &A0, &1C, &40, &A4, &7C, &00, &BC, &44, &80, &98, &C1, &80, &81, &C0, &50
	DEFB &82, &07, &30, &86, &39, &90, &8E, &7E, &D4, &90, &FF, &DC, &94, &3F, &D8, &8C
	DEFB &80, &10, &87, &C8, &9C, &41, &FD, &F8, &40, &1F, &C6, &80, &42, &09, &C0, &30
	DEFB &13, &30, &0E, &6C, &0C, &01, &B0, &03, &00, &C0, &00, &C3, &00, &00, &3C, &00
	DEFB &FF, &FF, &FF, &FF, &C1, &FF, &FE, &00, &3F, &F8, &00, &0F, &E0, &00, &07, &C0
	DEFB &00, &03, &80, &00, &03, &80, &00, &09, &00, &00, &1D, &10, &00, &85, &38, &01
	DEFB &DB, &20, &08, &5F, &24, &1C, &3F, &3C, &04, &BF, &18, &40, &2F, &00, &C0, &17
	DEFB &00, &00, &17, &02, &00, &03, &06, &00, &05, &00, &00, &0D, &04, &00, &0B, &04
	DEFB &80, &03, &01, &C8, &8D, &80, &1D, &CB, &80, &00, &01, &00, &00, &00, &00, &00
	DEFB &00, &C0, &00, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	..........@@@@@.........	@@@@@@@@@@.....@@@@@@@@@
	;;	.......@@@.....@@@......	@@@@@@@...........@@@@@@
	;;	.....@@...........@@....	@@@@@...............@@@@
	;;	...@@...........@...@...	@@@..................@@@
	;;	..@..@@..............@..	@@....................@@
	;;	.@.....@....@.......@...	@.....................@@
	;;	.@......@..........@@@..	@...................@..@
	;;	@.......@.......@.@@@@..	...................@@@.@
	;;	@..@.....@.....@@@...@..	...@............@....@.@
	;;	@.@@@....@..@.@@@@......	..@@@..........@@@.@@.@@
	;;	@.@........@@@...@......	..@.........@....@.@@@@@
	;;	@.@..@...@@@@@..........	..@..@.....@@@....@@@@@@
	;;	@.@@@@...@...@..@.......	..@@@@.......@..@.@@@@@@
	;;	@..@@...@@.....@@.......	...@@....@........@.@@@@
	;;	@......@@@.......@.@....	........@@.........@.@@@
	;;	@.....@......@@@..@@....	...................@.@@@
	;;	@....@@...@@@..@@..@....	......@...............@@
	;;	@...@@@..@@@@@@.@@.@.@..	.....@@..............@.@
	;;	@..@....@@@@@@@@@@.@@@..	....................@@.@
	;;	@..@.@....@@@@@@@@.@@...	.....@..............@.@@
	;;	@...@@..@..........@....	.....@..@.............@@
	;;	@....@@@@@..@...@..@@@..	.......@@@..@...@...@@.@
	;;	.@.....@@@@@@@.@@@@@@...	@..........@@@.@@@..@.@@
	;;	.@.........@@@@@@@...@@.	@......................@
	;;	@........@....@.....@..@	........................
	;;	@@........@@.......@..@@	........................
	;;	..@@........@@@..@@.@@..	@@....................@@
	;;	....@@.........@@.@@....	@@@@................@@@@
	;;	......@@........@@......	@@@@@@............@@@@@@
	;;	........@@....@@........	@@@@@@@@........@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@@@....@@@@@@@@@@

				;; SPR_SHARK_1 EQU &21
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &78, &00, &03
	DEFB &87, &00, &0C, &00, &C0, &10, &00, &20, &20, &00, &10, &46, &00, &08, &41, &00
	DEFB &08, &48, &80, &24, &9C, &40, &04, &90, &44, &0C, &92, &20, &78, &9E, &03, &B0
	DEFB &8C, &3D, &90, &81, &EC, &88, &87, &25, &58, &8D, &53, &68, &8C, &AA, &9C, &83
	DEFB &DD, &F4, &80, &3F, &C4, &40, &00, &08, &40, &20, &16, &80, &18, &61, &C0, &07
	DEFB &83, &30, &00, &0C, &0C, &00, &30, &03, &00, &C0, &00, &C3, &00, &00, &3C, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &87, &FF, &FC
	DEFB &00, &FF, &F0, &00, &3F, &E0, &00, &1F, &C0, &00, &0F, &80, &00, &07, &80, &00
	DEFB &07, &88, &00, &03, &1C, &00, &03, &10, &00, &03, &12, &00, &0B, &1E, &00, &37
	DEFB &0C, &01, &97, &00, &2C, &8B, &01, &24, &0B, &01, &00, &03, &00, &88, &8D, &00
	DEFB &1D, &C3, &00, &00, &03, &80, &00, &07, &80, &00, &01, &00, &00, &00, &00, &00
	DEFB &00, &C0, &00, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	.........@@@@...........	@@@@@@@@@....@@@@@@@@@@@
	;;	......@@@....@@@........	@@@@@@..........@@@@@@@@
	;;	....@@..........@@......	@@@@..............@@@@@@
	;;	...@..............@.....	@@@................@@@@@
	;;	..@................@....	@@..................@@@@
	;;	.@...@@.............@...	@....................@@@
	;;	.@.....@............@...	@....................@@@
	;;	.@..@...@.........@..@..	@...@.................@@
	;;	@..@@@...@...........@..	...@@@................@@
	;;	@..@.....@...@......@@..	...@..................@@
	;;	@..@..@...@......@@@@...	...@..@.............@.@@
	;;	@..@@@@.......@@@.@@....	...@@@@...........@@.@@@
	;;	@...@@....@@@@.@@..@....	....@@.........@@..@.@@@
	;;	@......@@@@.@@..@...@...	..........@.@@..@...@.@@
	;;	@....@@@..@..@.@.@.@@...	.......@..@..@......@.@@
	;;	@...@@.@.@.@..@@.@@.@...	.......@..............@@
	;;	@...@@..@.@.@.@.@..@@@..	........@...@...@...@@.@
	;;	@.....@@@@.@@@.@@@@@.@..	...........@@@.@@@....@@
	;;	@.........@@@@@@@@...@..	......................@@
	;;	.@..................@...	@....................@@@
	;;	.@........@........@.@@.	@......................@
	;;	@..........@@....@@....@	........................
	;;	@@...........@@@@.....@@	........................
	;;	..@@................@@..	@@....................@@
	;;	....@@............@@....	@@@@................@@@@
	;;	......@@........@@......	@@@@@@............@@@@@@
	;;	........@@....@@........	@@@@@@@@........@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@@@....@@@@@@@@@@

				;; SPR_SHARK_B0 EQU &22
	DEFB &00, &00, &00, &00, &00, &00, &00, &7E, &00, &03, &81, &C0, &0C, &00, &30, &10
	DEFB &00, &08, &23, &A0, &04, &4C, &08, &02, &50, &04, &02, &60, &00, &01, &60, &C4
	DEFB &01, &51, &20, &01, &31, &20, &01, &39, &E0, &01, &28, &C4, &01, &0C, &04, &01
	DEFB &2C, &00, &01, &32, &04, &01, &2A, &00, &01, &59, &04, &01, &4F, &84, &01, &40
	DEFB &00, &01, &20, &04, &39, &30, &00, &C2, &4C, &09, &02, &80, &10, &01, &C0, &10
	DEFB &03, &30, &00, &0C, &0C, &10, &30, &03, &00, &C0, &00, &C3, &00, &00, &3C, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &81, &FF, &FC, &00, &3F, &F0, &00, &0F, &E0
	DEFB &00, &07, &C0, &00, &03, &80, &00, &01, &00, &00, &01, &40, &00, &00, &40, &C0
	DEFB &00, &41, &20, &00, &A1, &20, &00, &B1, &E0, &00, &A0, &C0, &00, &C8, &00, &00
	DEFB &A8, &00, &00, &B0, &00, &00, &A8, &00, &00, &98, &00, &00, &80, &00, &00, &80
	DEFB &00, &00, &C0, &00, &00, &C0, &00, &01, &80, &00, &01, &00, &00, &00, &00, &00
	DEFB &00, &C0, &00, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	.........@@@@@@.........	@@@@@@@@@......@@@@@@@@@
	;;	......@@@......@@@......	@@@@@@............@@@@@@
	;;	....@@............@@....	@@@@................@@@@
	;;	...@................@...	@@@..................@@@
	;;	..@...@@@.@..........@..	@@....................@@
	;;	.@..@@......@.........@.	@......................@
	;;	.@.@.........@........@.	.......................@
	;;	.@@....................@	.@......................
	;;	.@@.....@@...@.........@	.@......@@..............
	;;	.@.@...@..@............@	.@.....@..@.............
	;;	..@@...@..@............@	@.@....@..@.............
	;;	..@@@..@@@@............@	@.@@...@@@@.............
	;;	..@.@...@@...@.........@	@.@.....@@..............
	;;	....@@.......@.........@	@@..@...................
	;;	..@.@@.................@	@.@.@...................
	;;	..@@..@......@.........@	@.@@....................
	;;	..@.@.@................@	@.@.@...................
	;;	.@.@@..@.....@.........@	@..@@...................
	;;	.@..@@@@@....@.........@	@.......................
	;;	.@.....................@	@.......................
	;;	..@..........@....@@@..@	@@......................
	;;	..@@............@@....@.	@@.....................@
	;;	.@..@@......@..@......@.	@......................@
	;;	@..........@...........@	........................
	;;	@@.........@..........@@	........................
	;;	..@@................@@..	@@....................@@
	;;	....@@.....@......@@....	@@@@................@@@@
	;;	......@@........@@......	@@@@@@............@@@@@@
	;;	........@@....@@........	@@@@@@@@........@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@@@....@@@@@@@@@@

				;; SPR_SHARK_B1 EQU &23
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &3C, &00, &01, &C3, &80, &06
	DEFB &00, &60, &08, &00, &10, &10, &00, &08, &26, &C0, &04, &58, &30, &04, &60, &00
	DEFB &02, &81, &84, &02, &82, &40, &02, &42, &40, &01, &23, &C4, &01, &31, &84, &01
	DEFB &28, &00, &01, &0C, &04, &01, &32, &00, &01, &55, &04, &01, &4F, &04, &01, &43
	DEFB &80, &01, &20, &04, &39, &30, &00, &C2, &4C, &09, &02, &80, &10, &01, &C0, &10
	DEFB &03, &30, &00, &0C, &0C, &10, &30, &03, &00, &C0, &00, &C3, &00, &00, &3C, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &C3, &FF, &FE, &00, &7F, &F8
	DEFB &00, &1F, &F0, &00, &0F, &E0, &00, &07, &C0, &00, &03, &80, &00, &03, &80, &00
	DEFB &01, &01, &80, &01, &02, &40, &01, &82, &40, &00, &83, &C0, &00, &A1, &80, &00
	DEFB &A0, &00, &00, &C8, &00, &00, &90, &00, &00, &84, &00, &00, &80, &00, &00, &80
	DEFB &00, &00, &C0, &00, &00, &C0, &00, &01, &80, &00, &01, &00, &00, &00, &00, &00
	DEFB &00, &C0, &00, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@@@....@@@@@@@@@@
	;;	.......@@@....@@@.......	@@@@@@@..........@@@@@@@
	;;	.....@@..........@@.....	@@@@@..............@@@@@
	;;	....@..............@....	@@@@................@@@@
	;;	...@................@...	@@@..................@@@
	;;	..@..@@.@@...........@..	@@....................@@
	;;	.@.@@.....@@.........@..	@.....................@@
	;;	.@@...................@.	@......................@
	;;	@......@@....@........@.	.......@@..............@
	;;	@.....@..@............@.	......@..@.............@
	;;	.@....@..@.............@	@.....@..@..............
	;;	..@...@@@@...@.........@	@.....@@@@..............
	;;	..@@...@@....@.........@	@.@....@@...............
	;;	..@.@..................@	@.@.....................
	;;	....@@.......@.........@	@@..@...................
	;;	..@@..@................@	@..@....................
	;;	.@.@.@.@.....@.........@	@....@..................
	;;	.@..@@@@.....@.........@	@.......................
	;;	.@....@@@..............@	@.......................
	;;	..@..........@....@@@..@	@@......................
	;;	..@@............@@....@.	@@.....................@
	;;	.@..@@......@..@......@.	@......................@
	;;	@..........@...........@	........................
	;;	@@.........@..........@@	........................
	;;	..@@................@@..	@@....................@@
	;;	....@@.....@......@@....	@@@@................@@@@
	;;	......@@........@@......	@@@@@@............@@@@@@
	;;	........@@....@@........	@@@@@@@@........@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@@@....@@@@@@@@@@

				;; SPR_DOG_0 EQU &24
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &07, &C0, &70, &18, &30, &1B
	DEFB &F8, &88, &16, &19, &44, &0C, &0E, &84, &08, &8F, &C6, &19, &5E, &36, &68, &98
	DEFB &1E, &58, &30, &5A, &7C, &33, &7C, &1C, &33, &C4, &3E, &1E, &06, &7F, &FC, &1A
	DEFB &7E, &78, &6A, &7F, &71, &A2, &3F, &66, &92, &37, &62, &3A, &3B, &B1, &DA, &7B
	DEFB &DB, &FA, &71, &6C, &F4, &70, &76, &78, &78, &7B, &86, &28, &70, &0A, &00, &70
	DEFB &00, &00, &70, &00, &00, &30, &00, &00, &70, &00, &00, &50, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F8, &3F, &8F, &E0, &0F, &04, &00, &07, &80
	DEFB &00, &83, &C0, &01, &41, &E0, &00, &81, &E0, &80, &00, &81, &40, &00, &00, &80
	DEFB &00, &00, &00, &00, &00, &00, &01, &80, &00, &01, &80, &00, &00, &00, &00, &18
	DEFB &00, &00, &68, &00, &01, &A0, &80, &06, &80, &80, &02, &00, &80, &00, &00, &00
	DEFB &00, &00, &04, &00, &01, &06, &00, &03, &03, &00, &01, &83, &04, &00, &D7, &07
	DEFB &E0, &FF, &07, &F5, &FF, &07, &FF, &FF, &07, &FF, &FF, &07, &FF, &FF, &AF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@.....@@@@@@
	;;	.............@@@@@......	@...@@@@@@@.........@@@@
	;;	.@@@.......@@.....@@....	.....@...............@@@
	;;	...@@.@@@@@@@...@...@...	@...............@.....@@
	;;	...@.@@....@@..@.@...@..	@@.............@.@.....@
	;;	....@@......@@@.@....@..	@@@.............@......@
	;;	....@...@...@@@@@@...@@.	@@@.....@...............
	;;	...@@..@.@.@@@@...@@.@@.	@......@.@..............
	;;	.@@.@...@..@@......@@@@.	........@...............
	;;	.@.@@.....@@.....@.@@.@.	........................
	;;	.@@@@@....@@..@@.@@@@@..	.......................@
	;;	...@@@....@@..@@@@...@..	@......................@
	;;	..@@@@@....@@@@......@@.	@.......................
	;;	.@@@@@@@@@@@@@.....@@.@.	...................@@...
	;;	.@@@@@@..@@@@....@@.@.@.	.................@@.@...
	;;	.@@@@@@@.@@@...@@.@...@.	...............@@.@.....
	;;	..@@@@@@.@@..@@.@..@..@.	@............@@.@.......
	;;	..@@.@@@.@@...@...@@@.@.	@.............@.........
	;;	..@@@.@@@.@@...@@@.@@.@.	@.......................
	;;	.@@@@.@@@@.@@.@@@@@@@.@.	........................
	;;	.@@@...@.@@.@@..@@@@.@..	.....@.................@
	;;	.@@@.....@@@.@@..@@@@...	.....@@...............@@
	;;	.@@@@....@@@@.@@@....@@.	......@@...............@
	;;	..@.@....@@@........@.@.	@.....@@.....@..........
	;;	.........@@@............	@@.@.@@@.....@@@@@@.....
	;;	.........@@@............	@@@@@@@@.....@@@@@@@.@.@
	;;	..........@@............	@@@@@@@@.....@@@@@@@@@@@
	;;	.........@@@............	@@@@@@@@.....@@@@@@@@@@@
	;;	.........@.@............	@@@@@@@@.....@@@@@@@@@@@
	;;	........................	@@@@@@@@@.@.@@@@@@@@@@@@

				;; SPR_DOG_1 EQU &25
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &06, &07, &C0, &0C, &18, &30, &0B
	DEFB &F8, &88, &06, &19, &44, &0C, &0E, &84, &08, &8F, &C6, &19, &5E, &36, &68, &98
	DEFB &1E, &58, &30, &5A, &7C, &33, &7C, &1C, &33, &C4, &3E, &1E, &06, &7F, &FC, &1A
	DEFB &7E, &78, &6A, &7F, &71, &A2, &3F, &66, &82, &37, &62, &72, &3B, &B1, &F2, &1B
	DEFB &DB, &F2, &39, &6C, &64, &38, &F6, &18, &31, &DB, &E4, &3D, &C0, &00, &15, &C0
	DEFB &00, &00, &C0, &00, &01, &C0, &00, &01, &40, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &F9, &F8, &3F, &F0, &E0, &0F, &E0, &00, &07, &E0
	DEFB &00, &83, &F0, &01, &41, &E0, &00, &81, &E0, &80, &00, &81, &40, &00, &00, &80
	DEFB &00, &00, &00, &00, &00, &00, &01, &80, &00, &01, &80, &00, &00, &00, &00, &18
	DEFB &00, &00, &68, &00, &01, &A0, &80, &06, &80, &80, &02, &00, &80, &00, &00, &C0
	DEFB &00, &00, &80, &00, &01, &82, &00, &03, &80, &00, &01, &80, &04, &1B, &C0, &1F
	DEFB &FF, &EA, &1F, &FF, &FC, &1F, &FF, &FC, &1F, &FF, &FE, &BF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@..@@@@@@.....@@@@@@
	;;	.....@@......@@@@@......	@@@@....@@@.........@@@@
	;;	....@@.....@@.....@@....	@@@..................@@@
	;;	....@.@@@@@@@...@...@...	@@@.............@.....@@
	;;	.....@@....@@..@.@...@..	@@@@...........@.@.....@
	;;	....@@......@@@.@....@..	@@@.............@......@
	;;	....@...@...@@@@@@...@@.	@@@.....@...............
	;;	...@@..@.@.@@@@...@@.@@.	@......@.@..............
	;;	.@@.@...@..@@......@@@@.	........@...............
	;;	.@.@@.....@@.....@.@@.@.	........................
	;;	.@@@@@....@@..@@.@@@@@..	.......................@
	;;	...@@@....@@..@@@@...@..	@......................@
	;;	..@@@@@....@@@@......@@.	@.......................
	;;	.@@@@@@@@@@@@@.....@@.@.	...................@@...
	;;	.@@@@@@..@@@@....@@.@.@.	.................@@.@...
	;;	.@@@@@@@.@@@...@@.@...@.	...............@@.@.....
	;;	..@@@@@@.@@..@@.@.....@.	@............@@.@.......
	;;	..@@.@@@.@@...@..@@@..@.	@.............@.........
	;;	..@@@.@@@.@@...@@@@@..@.	@.......................
	;;	...@@.@@@@.@@.@@@@@@..@.	@@......................
	;;	..@@@..@.@@.@@...@@..@..	@......................@
	;;	..@@@...@@@@.@@....@@...	@.....@...............@@
	;;	..@@...@@@.@@.@@@@@..@..	@......................@
	;;	..@@@@.@@@..............	@............@.....@@.@@
	;;	...@.@.@@@..............	@@.........@@@@@@@@@@@@@
	;;	........@@..............	@@@.@.@....@@@@@@@@@@@@@
	;;	.......@@@..............	@@@@@@.....@@@@@@@@@@@@@
	;;	.......@.@..............	@@@@@@.....@@@@@@@@@@@@@
	;;	........................	@@@@@@@.@.@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_DOG_B0 EQU &26
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &07, &C0, &00
	DEFB &1F, &F0, &03, &EF, &F0, &07, &FF, &F8, &0F, &FF, &F8, &07, &FF, &F8, &1B, &FE
	DEFB &F0, &3F, &F9, &90, &3F, &FF, &E0, &1F, &FE, &10, &07, &FC, &08, &07, &F8, &06
	DEFB &03, &F8, &0C, &07, &F8, &1A, &07, &FC, &1A, &0E, &FF, &5A, &0D, &FF, &F6, &1C
	DEFB &FF, &FC, &38, &6F, &FC, &70, &1F, &EA, &70, &3D, &C6, &50, &30, &0A, &00, &38
	DEFB &00, &00, &38, &00, &00, &38, &00, &00, &1C, &00, &00, &34, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F8, &3F, &FF, &E0, &0F, &FC
	DEFB &00, &07, &F8, &00, &07, &F0, &00, &03, &E0, &00, &03, &E0, &00, &03, &C0, &00
	DEFB &07, &80, &00, &07, &80, &00, &0F, &C0, &00, &07, &E0, &00, &01, &F0, &00, &00
	DEFB &F8, &00, &01, &F0, &00, &00, &F0, &00, &00, &E0, &00, &00, &E0, &00, &00, &C0
	DEFB &00, &01, &83, &00, &01, &07, &80, &00, &07, &80, &10, &07, &82, &20, &AF, &83
	DEFB &F5, &FF, &83, &FF, &FF, &83, &FF, &FF, &C1, &FF, &FF, &81, &FF, &FF, &CB, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@.....@@@@@@
	;;	.............@@@@@......	@@@@@@@@@@@.........@@@@
	;;	...........@@@@@@@@@....	@@@@@@...............@@@
	;;	......@@@@@.@@@@@@@@....	@@@@@................@@@
	;;	.....@@@@@@@@@@@@@@@@...	@@@@..................@@
	;;	....@@@@@@@@@@@@@@@@@...	@@@...................@@
	;;	.....@@@@@@@@@@@@@@@@...	@@@...................@@
	;;	...@@.@@@@@@@@@.@@@@....	@@...................@@@
	;;	..@@@@@@@@@@@..@@..@....	@....................@@@
	;;	..@@@@@@@@@@@@@@@@@.....	@...................@@@@
	;;	...@@@@@@@@@@@@....@....	@@...................@@@
	;;	.....@@@@@@@@@......@...	@@@....................@
	;;	.....@@@@@@@@........@@.	@@@@....................
	;;	......@@@@@@@.......@@..	@@@@@..................@
	;;	.....@@@@@@@@......@@.@.	@@@@....................
	;;	.....@@@@@@@@@.....@@.@.	@@@@....................
	;;	....@@@.@@@@@@@@.@.@@.@.	@@@.....................
	;;	....@@.@@@@@@@@@@@@@.@@.	@@@.....................
	;;	...@@@..@@@@@@@@@@@@@@..	@@.....................@
	;;	..@@@....@@.@@@@@@@@@@..	@.....@@...............@
	;;	.@@@.......@@@@@@@@.@.@.	.....@@@@...............
	;;	.@@@......@@@@.@@@...@@.	.....@@@@..........@....
	;;	.@.@......@@........@.@.	.....@@@@.....@...@.....
	;;	..........@@@...........	@.@.@@@@@.....@@@@@@.@.@
	;;	..........@@@...........	@@@@@@@@@.....@@@@@@@@@@
	;;	..........@@@...........	@@@@@@@@@.....@@@@@@@@@@
	;;	...........@@@..........	@@@@@@@@@@.....@@@@@@@@@
	;;	..........@@.@..........	@@@@@@@@@......@@@@@@@@@
	;;	........................	@@@@@@@@@@..@.@@@@@@@@@@

				;; SPR_DOG_B1 EQU &27
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &07, &C0, &00
	DEFB &1F, &F0, &03, &EF, &F0, &07, &FF, &F8, &0F, &FF, &F8, &07, &FF, &F8, &1B, &FE
	DEFB &F0, &3F, &F9, &90, &3F, &FF, &E0, &1F, &FE, &10, &07, &FC, &08, &07, &F8, &04
	DEFB &03, &F8, &E4, &07, &F8, &32, &07, &FC, &16, &07, &7F, &5A, &07, &7F, &D2, &07
	DEFB &7F, &FC, &06, &6F, &FC, &0E, &1F, &E8, &0C, &3D, &D4, &0E, &70, &00, &0C, &70
	DEFB &00, &00, &E0, &00, &00, &A0, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F8, &3F, &FF, &E0, &0F, &FC
	DEFB &00, &07, &F8, &00, &07, &F0, &00, &03, &E0, &00, &03, &E0, &00, &03, &C0, &00
	DEFB &07, &80, &00, &07, &80, &00, &0F, &C0, &00, &07, &E0, &00, &03, &F0, &00, &01
	DEFB &F8, &00, &01, &F0, &00, &00, &F0, &00, &00, &F0, &00, &00, &F0, &00, &00, &F0
	DEFB &00, &01, &F0, &00, &01, &E0, &80, &03, &E1, &80, &01, &E0, &02, &2B, &E1, &07
	DEFB &FF, &F2, &0F, &FF, &FE, &0F, &FF, &FF, &5F, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@.....@@@@@@
	;;	.............@@@@@......	@@@@@@@@@@@.........@@@@
	;;	...........@@@@@@@@@....	@@@@@@...............@@@
	;;	......@@@@@.@@@@@@@@....	@@@@@................@@@
	;;	.....@@@@@@@@@@@@@@@@...	@@@@..................@@
	;;	....@@@@@@@@@@@@@@@@@...	@@@...................@@
	;;	.....@@@@@@@@@@@@@@@@...	@@@...................@@
	;;	...@@.@@@@@@@@@.@@@@....	@@...................@@@
	;;	..@@@@@@@@@@@..@@..@....	@....................@@@
	;;	..@@@@@@@@@@@@@@@@@.....	@...................@@@@
	;;	...@@@@@@@@@@@@....@....	@@...................@@@
	;;	.....@@@@@@@@@......@...	@@@...................@@
	;;	.....@@@@@@@@........@..	@@@@...................@
	;;	......@@@@@@@...@@@..@..	@@@@@..................@
	;;	.....@@@@@@@@.....@@..@.	@@@@....................
	;;	.....@@@@@@@@@.....@.@@.	@@@@....................
	;;	.....@@@.@@@@@@@.@.@@.@.	@@@@....................
	;;	.....@@@.@@@@@@@@@.@..@.	@@@@....................
	;;	.....@@@.@@@@@@@@@@@@@..	@@@@...................@
	;;	.....@@..@@.@@@@@@@@@@..	@@@@...................@
	;;	....@@@....@@@@@@@@.@...	@@@.....@.............@@
	;;	....@@....@@@@.@@@.@.@..	@@@....@@..............@
	;;	....@@@..@@@............	@@@...........@...@.@.@@
	;;	....@@...@@@............	@@@....@.....@@@@@@@@@@@
	;;	........@@@.............	@@@@..@.....@@@@@@@@@@@@
	;;	........@.@.............	@@@@@@@.....@@@@@@@@@@@@
	;;	........................	@@@@@@@@.@.@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

				;; SPR_JOKER EQU &28
	DEFB &00, &00, &00, &01, &F7, &80, &07, &FB, &C0, &0F, &9F, &20, &3E, &46, &50, &0D
	DEFB &91, &C0, &1D, &E3, &F0, &23, &3F, &10, &1A, &CC, &B8, &0E, &66, &D8, &12, &8B
	DEFB &14, &17, &F5, &B4, &0F, &C3, &98, &03, &B8, &50, &03, &88, &B0, &05, &E7, &60
	DEFB &08, &F8, &C0, &09, &1F, &28, &09, &20, &5C, &08, &65, &58, &04, &B0, &C0, &05
	DEFB &DF, &80, &01, &B2, &C0, &00, &79, &C0, &00, &3B, &C0, &00, &7B, &00, &00, &63
	DEFB &40, &01, &A8, &E0, &01, &9D, &10, &00, &61, &A0, &00, &76, &00, &00, &00, &00
	DEFB &FE, &08, &7F, &F8, &00, &3F, &F0, &00, &1F, &C0, &00, &0F, &80, &40, &47, &C1
	DEFB &91, &CF, &C1, &E3, &F7, &83, &3F, &17, &DA, &CC, &BB, &EE, &66, &DB, &D2, &8B
	DEFB &15, &D7, &F5, &B5, &EF, &C3, &9B, &F3, &B8, &57, &FB, &88, &B7, &FD, &E7, &6F
	DEFB &F8, &F8, &D7, &F9, &1F, &2B, &F9, &00, &1D, &F8, &05, &1B, &FC, &80, &07, &FD
	DEFB &C0, &3F, &FD, &80, &1F, &FE, &00, &1F, &FF, &80, &1F, &FF, &42, &3F, &FE, &43
	DEFB &5F, &FD, &A8, &EF, &FD, &9D, &17, &FE, &61, &AF, &FF, &76, &5F, &FF, &89, &FF
	;;	........................	@@@@@@@.....@....@@@@@@@
	;;	.......@@@@@.@@@@.......	@@@@@.............@@@@@@
	;;	.....@@@@@@@@.@@@@......	@@@@...............@@@@@
	;;	....@@@@@..@@@@@..@.....	@@..................@@@@
	;;	..@@@@@..@...@@..@.@....	@........@.......@...@@@
	;;	....@@.@@..@...@@@......	@@.....@@..@...@@@..@@@@
	;;	...@@@.@@@@...@@@@@@....	@@.....@@@@...@@@@@@.@@@
	;;	..@...@@..@@@@@@...@....	@.....@@..@@@@@@...@.@@@
	;;	...@@.@.@@..@@..@.@@@...	@@.@@.@.@@..@@..@.@@@.@@
	;;	....@@@..@@..@@.@@.@@...	@@@.@@@..@@..@@.@@.@@.@@
	;;	...@..@.@...@.@@...@.@..	@@.@..@.@...@.@@...@.@.@
	;;	...@.@@@@@@@.@.@@.@@.@..	@@.@.@@@@@@@.@.@@.@@.@.@
	;;	....@@@@@@....@@@..@@...	@@@.@@@@@@....@@@..@@.@@
	;;	......@@@.@@@....@.@....	@@@@..@@@.@@@....@.@.@@@
	;;	......@@@...@...@.@@....	@@@@@.@@@...@...@.@@.@@@
	;;	.....@.@@@@..@@@.@@.....	@@@@@@.@@@@..@@@.@@.@@@@
	;;	....@...@@@@@...@@......	@@@@@...@@@@@...@@.@.@@@
	;;	....@..@...@@@@@..@.@...	@@@@@..@...@@@@@..@.@.@@
	;;	....@..@..@......@.@@@..	@@@@@..@...........@@@.@
	;;	....@....@@..@.@.@.@@...	@@@@@........@.@...@@.@@
	;;	.....@..@.@@....@@......	@@@@@@..@............@@@
	;;	.....@.@@@.@@@@@@.......	@@@@@@.@@@........@@@@@@
	;;	.......@@.@@..@.@@......	@@@@@@.@@..........@@@@@
	;;	.........@@@@..@@@......	@@@@@@@............@@@@@
	;;	..........@@@.@@@@......	@@@@@@@@@..........@@@@@
	;;	.........@@@@.@@........	@@@@@@@@.@....@...@@@@@@
	;;	.........@@...@@.@......	@@@@@@@..@....@@.@.@@@@@
	;;	.......@@.@.@...@@@.....	@@@@@@.@@.@.@...@@@.@@@@
	;;	.......@@..@@@.@...@....	@@@@@@.@@..@@@.@...@.@@@
	;;	.........@@....@@.@.....	@@@@@@@..@@....@@.@.@@@@
	;;	.........@@@.@@.........	@@@@@@@@.@@@.@@..@.@@@@@
	;;	........................	@@@@@@@@@...@..@@@@@@@@@

				;; SPR_JOKERB EQU &29
	DEFB &00, &00, &00, &01, &CF, &80, &03, &F3, &E0, &07, &F9, &70, &0F, &EE, &FC, &0F
	DEFB &E1, &A0, &0F, &F7, &B0, &07, &9B, &B8, &1B, &C7, &44, &18, &1F, &0C, &08, &00
	DEFB &08, &0C, &00, &10, &06, &04, &20, &02, &3E, &C0, &01, &DE, &80, &02, &6D, &40
	DEFB &06, &21, &20, &18, &61, &20, &18, &73, &20, &06, &FF, &20, &01, &FE, &C0, &00
	DEFB &FF, &40, &01, &F7, &00, &01, &EF, &00, &03, &CE, &00, &03, &EF, &00, &05, &E9
	DEFB &00, &0B, &26, &00, &0C, &D5, &00, &02, &AB, &00, &03, &60, &00, &00, &00, &00
	DEFB &FE, &30, &7F, &FC, &00, &1F, &F8, &00, &0F, &F0, &00, &03, &E0, &00, &01, &E0
	DEFB &00, &03, &E0, &00, &07, &E0, &00, &03, &D8, &00, &05, &D8, &00, &0D, &E8, &00
	DEFB &0B, &EC, &00, &1F, &F6, &04, &3F, &FA, &3E, &FF, &FC, &1E, &FF, &FE, &0C, &7F
	DEFB &E6, &00, &3F, &D8, &40, &3F, &D8, &40, &3F, &E6, &80, &3F, &FF, &00, &DF, &FE
	DEFB &00, &5F, &FC, &00, &3F, &FC, &00, &7F, &F8, &00, &FF, &F8, &00, &7F, &F4, &08
	DEFB &7F, &EB, &06, &FF, &EC, &D5, &7F, &F2, &AB, &7F, &FB, &64, &FF, &FC, &9F, &FF
	;;	........................	@@@@@@@...@@.....@@@@@@@
	;;	.......@@@..@@@@@.......	@@@@@@.............@@@@@
	;;	......@@@@@@..@@@@@.....	@@@@@...............@@@@
	;;	.....@@@@@@@@..@.@@@....	@@@@..................@@
	;;	....@@@@@@@.@@@.@@@@@@..	@@@....................@
	;;	....@@@@@@@....@@.@.....	@@@...................@@
	;;	....@@@@@@@@.@@@@.@@....	@@@..................@@@
	;;	.....@@@@..@@.@@@.@@@...	@@@...................@@
	;;	...@@.@@@@...@@@.@...@..	@@.@@................@.@
	;;	...@@......@@@@@....@@..	@@.@@...............@@.@
	;;	....@...............@...	@@@.@...............@.@@
	;;	....@@.............@....	@@@.@@.............@@@@@
	;;	.....@@......@....@.....	@@@@.@@......@....@@@@@@
	;;	......@...@@@@@.@@......	@@@@@.@...@@@@@.@@@@@@@@
	;;	.......@@@.@@@@.@.......	@@@@@@.....@@@@.@@@@@@@@
	;;	......@..@@.@@.@.@......	@@@@@@@.....@@...@@@@@@@
	;;	.....@@...@....@..@.....	@@@..@@...........@@@@@@
	;;	...@@....@@....@..@.....	@@.@@....@........@@@@@@
	;;	...@@....@@@..@@..@.....	@@.@@....@........@@@@@@
	;;	.....@@.@@@@@@@@..@.....	@@@..@@.@.........@@@@@@
	;;	.......@@@@@@@@.@@......	@@@@@@@@........@@.@@@@@
	;;	........@@@@@@@@.@......	@@@@@@@..........@.@@@@@
	;;	.......@@@@@.@@@........	@@@@@@............@@@@@@
	;;	.......@@@@.@@@@........	@@@@@@...........@@@@@@@
	;;	......@@@@..@@@.........	@@@@@...........@@@@@@@@
	;;	......@@@@@.@@@@........	@@@@@............@@@@@@@
	;;	.....@.@@@@.@..@........	@@@@.@......@....@@@@@@@
	;;	....@.@@..@..@@.........	@@@.@.@@.....@@.@@@@@@@@
	;;	....@@..@@.@.@.@........	@@@.@@..@@.@.@.@.@@@@@@@
	;;	......@.@.@.@.@@........	@@@@..@.@.@.@.@@.@@@@@@@
	;;	......@@.@@.............	@@@@@.@@.@@..@..@@@@@@@@
	;;	........................	@@@@@@..@..@@@@@@@@@@@@@

				;; SPR_JOKER_B1 EQU &2A
	DEFB &00, &00, &00, &01, &CF, &80, &03, &F3, &E0, &07, &F9, &70, &0F, &EE, &FC, &0F
	DEFB &E1, &A0, &0F, &F7, &B0, &07, &9B, &B8, &1B, &C7, &44, &18, &1F, &0C, &08, &00
	DEFB &08, &0C, &00, &10, &06, &04, &20, &02, &3E, &C0, &03, &DE, &80, &04, &ED, &40
	DEFB &04, &61, &40, &04, &61, &40, &04, &73, &40, &08, &7E, &80, &04, &FF, &00, &0E
	DEFB &F7, &00, &05, &F6, &00, &01, &E9, &00, &03, &D6, &C0, &03, &D6, &C0, &05, &E9
	DEFB &00, &0B, &29, &00, &0C, &C6, &C0, &02, &A6, &C0, &03, &60, &00, &00, &00, &00
	DEFB &FE, &30, &7F, &FC, &00, &1F, &F8, &00, &0F, &F0, &00, &03, &E0, &00, &01, &E0
	DEFB &00, &03, &E0, &00, &07, &E0, &00, &03, &D8, &00, &05, &D8, &00, &0D, &E8, &00
	DEFB &0B, &EC, &00, &1F, &F6, &04, &3F, &FA, &3E, &FF, &F8, &1E, &FF, &FC, &0C, &7F
	DEFB &FC, &40, &7F, &FC, &40, &7F, &FC, &40, &7F, &F8, &40, &FF, &F4, &80, &7F, &EE
	DEFB &00, &7F, &F4, &00, &FF, &F8, &00, &3F, &F8, &06, &DF, &F8, &06, &DF, &F4, &09
	DEFB &3F, &EB, &09, &3F, &EC, &D6, &DF, &F2, &A6, &DF, &FB, &69, &3F, &FC, &9F, &FF
	;;	........................	@@@@@@@...@@.....@@@@@@@
	;;	.......@@@..@@@@@.......	@@@@@@.............@@@@@
	;;	......@@@@@@..@@@@@.....	@@@@@...............@@@@
	;;	.....@@@@@@@@..@.@@@....	@@@@..................@@
	;;	....@@@@@@@.@@@.@@@@@@..	@@@....................@
	;;	....@@@@@@@....@@.@.....	@@@...................@@
	;;	....@@@@@@@@.@@@@.@@....	@@@..................@@@
	;;	.....@@@@..@@.@@@.@@@...	@@@...................@@
	;;	...@@.@@@@...@@@.@...@..	@@.@@................@.@
	;;	...@@......@@@@@....@@..	@@.@@...............@@.@
	;;	....@...............@...	@@@.@...............@.@@
	;;	....@@.............@....	@@@.@@.............@@@@@
	;;	.....@@......@....@.....	@@@@.@@......@....@@@@@@
	;;	......@...@@@@@.@@......	@@@@@.@...@@@@@.@@@@@@@@
	;;	......@@@@.@@@@.@.......	@@@@@......@@@@.@@@@@@@@
	;;	.....@..@@@.@@.@.@......	@@@@@@......@@...@@@@@@@
	;;	.....@...@@....@.@......	@@@@@@...@.......@@@@@@@
	;;	.....@...@@....@.@......	@@@@@@...@.......@@@@@@@
	;;	.....@...@@@..@@.@......	@@@@@@...@.......@@@@@@@
	;;	....@....@@@@@@.@.......	@@@@@....@......@@@@@@@@
	;;	.....@..@@@@@@@@........	@@@@.@..@........@@@@@@@
	;;	....@@@.@@@@.@@@........	@@@.@@@..........@@@@@@@
	;;	.....@.@@@@@.@@.........	@@@@.@..........@@@@@@@@
	;;	.......@@@@.@..@........	@@@@@.............@@@@@@
	;;	......@@@@.@.@@.@@......	@@@@@........@@.@@.@@@@@
	;;	......@@@@.@.@@.@@......	@@@@@........@@.@@.@@@@@
	;;	.....@.@@@@.@..@........	@@@@.@......@..@..@@@@@@
	;;	....@.@@..@.@..@........	@@@.@.@@....@..@..@@@@@@
	;;	....@@..@@...@@.@@......	@@@.@@..@@.@.@@.@@.@@@@@
	;;	......@.@.@..@@.@@......	@@@@..@.@.@..@@.@@.@@@@@
	;;	......@@.@@.............	@@@@@.@@.@@.@..@..@@@@@@
	;;	........................	@@@@@@..@..@@@@@@@@@@@@@

				;; SPR_RIDDLER EQU &2B
	DEFB &00, &E0, &00, &07, &9E, &00, &18, &69, &80, &20, &14, &40, &20, &0B, &E0, &43
	DEFB &FE, &30, &44, &00, &00, &4F, &F4, &08, &4C, &04, &08, &2D, &0A, &1C, &4B, &4B
	DEFB &7C, &7B, &9B, &AE, &3D, &F7, &CE, &5A, &09, &E6, &7F, &F7, &EE, &39, &F8, &F4
	DEFB &32, &06, &74, &39, &B1, &B4, &3C, &86, &08, &1F, &31, &F8, &07, &C7, &B0, &19
	DEFB &FF, &88, &1E, &7E, &78, &23, &81, &C4, &50, &E7, &0A, &50, &3C, &0A, &4C, &10
	DEFB &32, &23, &10, &C4, &10, &F7, &08, &0C, &18, &30, &03, &91, &C0, &00, &7E, &00
	DEFB &FF, &1F, &FF, &F8, &01, &FF, &E0, &00, &7F, &C0, &00, &1F, &C0, &00, &0F, &80
	DEFB &00, &07, &80, &00, &07, &80, &00, &03, &80, &00, &03, &81, &08, &01, &03, &48
	DEFB &01, &03, &98, &00, &81, &F0, &00, &00, &00, &00, &00, &00, &00, &80, &00, &01
	DEFB &82, &06, &01, &81, &B1, &81, &80, &86, &03, &C0, &30, &03, &E0, &00, &07, &C0
	DEFB &00, &03, &C0, &00, &03, &C0, &00, &03, &80, &00, &01, &80, &00, &01, &80, &00
	DEFB &01, &C0, &00, &03, &E0, &00, &07, &F0, &00, &0F, &FC, &00, &3F, &FF, &81, &FF
	;;	........@@@.............	@@@@@@@@...@@@@@@@@@@@@@
	;;	.....@@@@..@@@@.........	@@@@@..........@@@@@@@@@
	;;	...@@....@@.@..@@.......	@@@..............@@@@@@@
	;;	..@........@.@...@......	@@.................@@@@@
	;;	..@.........@.@@@@@.....	@@..................@@@@
	;;	.@....@@@@@@@@@...@@....	@....................@@@
	;;	.@...@..................	@....................@@@
	;;	.@..@@@@@@@@.@......@...	@.....................@@
	;;	.@..@@.......@......@...	@.....................@@
	;;	..@.@@.@....@.@....@@@..	@......@....@..........@
	;;	.@..@.@@.@..@.@@.@@@@@..	......@@.@..@..........@
	;;	.@@@@.@@@..@@.@@@.@.@@@.	......@@@..@@...........
	;;	..@@@@.@@@@@.@@@@@..@@@.	@......@@@@@............
	;;	.@.@@.@.....@..@@@@..@@.	........................
	;;	.@@@@@@@@@@@.@@@@@@.@@@.	........................
	;;	..@@@..@@@@@@...@@@@.@..	@......................@
	;;	..@@..@......@@..@@@.@..	@.....@......@@........@
	;;	..@@@..@@.@@...@@.@@.@..	@......@@.@@...@@......@
	;;	..@@@@..@....@@.....@...	@.......@....@@.......@@
	;;	...@@@@@..@@...@@@@@@...	@@........@@..........@@
	;;	.....@@@@@...@@@@.@@....	@@@..................@@@
	;;	...@@..@@@@@@@@@@...@...	@@....................@@
	;;	...@@@@..@@@@@@..@@@@...	@@....................@@
	;;	..@...@@@......@@@...@..	@@....................@@
	;;	.@.@....@@@..@@@....@.@.	@......................@
	;;	.@.@......@@@@......@.@.	@......................@
	;;	.@..@@.....@......@@..@.	@......................@
	;;	..@...@@...@....@@...@..	@@....................@@
	;;	...@....@@@@.@@@....@...	@@@..................@@@
	;;	....@@.....@@.....@@....	@@@@................@@@@
	;;	......@@@..@...@@@......	@@@@@@............@@@@@@
	;;	.........@@@@@@.........	@@@@@@@@@......@@@@@@@@@

				;; SPR_RIDDLERB EQU &2C
	DEFB &00, &3C, &00, &00, &43, &E0, &01, &F8, &D8, &02, &06, &24, &07, &01, &14, &0C
	DEFB &00, &92, &08, &00, &52, &10, &00, &52, &10, &00, &52, &30, &00, &52, &30, &00
	DEFB &52, &23, &00, &54, &27, &10, &A2, &19, &0E, &A2, &3B, &00, &52, &3B, &08, &56
	DEFB &3E, &80, &58, &3D, &40, &F4, &1B, &B3, &0C, &1F, &CC, &F8, &0F, &F3, &E0, &11
	DEFB &FF, &98, &1E, &7E, &78, &23, &81, &C4, &50, &E7, &0A, &50, &3C, &0A, &4C, &08
	DEFB &32, &23, &08, &C4, &10, &EF, &08, &0C, &18, &30, &03, &89, &C0, &00, &7E, &00
	DEFB &FF, &C3, &FF, &FF, &80, &1F, &FC, &00, &07, &F8, &00, &03, &F0, &00, &03, &E0
	DEFB &00, &01, &E0, &00, &01, &C0, &00, &01, &C0, &00, &01, &80, &00, &01, &80, &00
	DEFB &01, &80, &00, &03, &80, &00, &01, &C0, &00, &01, &80, &00, &01, &80, &00, &01
	DEFB &80, &00, &03, &80, &00, &01, &C0, &00, &01, &C0, &00, &03, &E0, &00, &07, &C0
	DEFB &00, &03, &C0, &00, &03, &C0, &00, &03, &80, &00, &01, &80, &00, &01, &80, &00
	DEFB &01, &C0, &00, &03, &E0, &00, &07, &F0, &00, &0F, &FC, &00, &3F, &FF, &81, &FF
	;;	..........@@@@..........	@@@@@@@@@@....@@@@@@@@@@
	;;	.........@....@@@@@.....	@@@@@@@@@..........@@@@@
	;;	.......@@@@@@...@@.@@...	@@@@@@...............@@@
	;;	......@......@@...@..@..	@@@@@.................@@
	;;	.....@@@.......@...@.@..	@@@@..................@@
	;;	....@@..........@..@..@.	@@@....................@
	;;	....@............@.@..@.	@@@....................@
	;;	...@.............@.@..@.	@@.....................@
	;;	...@.............@.@..@.	@@.....................@
	;;	..@@.............@.@..@.	@......................@
	;;	..@@.............@.@..@.	@......................@
	;;	..@...@@.........@.@.@..	@.....................@@
	;;	..@..@@@...@....@.@...@.	@......................@
	;;	...@@..@....@@@.@.@...@.	@@.....................@
	;;	..@@@.@@.........@.@..@.	@......................@
	;;	..@@@.@@....@....@.@.@@.	@......................@
	;;	..@@@@@.@........@.@@...	@.....................@@
	;;	..@@@@.@.@......@@@@.@..	@......................@
	;;	...@@.@@@.@@..@@....@@..	@@.....................@
	;;	...@@@@@@@..@@..@@@@@...	@@....................@@
	;;	....@@@@@@@@..@@@@@.....	@@@..................@@@
	;;	...@...@@@@@@@@@@..@@...	@@....................@@
	;;	...@@@@..@@@@@@..@@@@...	@@....................@@
	;;	..@...@@@......@@@...@..	@@....................@@
	;;	.@.@....@@@..@@@....@.@.	@......................@
	;;	.@.@......@@@@......@.@.	@......................@
	;;	.@..@@......@.....@@..@.	@......................@
	;;	..@...@@....@...@@...@..	@@....................@@
	;;	...@....@@@.@@@@....@...	@@@..................@@@
	;;	....@@.....@@.....@@....	@@@@................@@@@
	;;	......@@@...@..@@@......	@@@@@@............@@@@@@
	;;	.........@@@@@@.........	@@@@@@@@@......@@@@@@@@@

;; -----------------------------------------------------------------------------------------------------------
SPR_BATTHRUSTER		EQU		&30
SPR_BATBELT			EQU		&31
SPR_BATBOOTS		EQU		&32
SPR_BATBAG			EQU		&33
SPR_BONUS			EQU		&34
SPR_BATSIGNAL		EQU		&35
SPR_S_CUSHION		EQU		&36
SPR_VAPE_0			EQU		&37
SPR_VAPE_1			EQU		&38
SPR_VAPE_2			EQU		&39
SPR_WORM_0			EQU		&3A
SPR_WORM_1			EQU		&3B
SPR_PRESENT			EQU		&3C
SPR_WELL			EQU		&3D
SPR_PAWDRUM			EQU		&3E
SPR_STOOL			EQU		&3F
SPR_SHROOM			EQU		&40
SPR_SWITCH			EQU		&41
SPR_KETTLE			EQU		&42
SPR_SUGARBOX		EQU		&43
SPR_BATCRAFT_FINS	EQU		&44
SPR_QBALL			EQU		&45
SPR_SALT			EQU		&46
SPR_PILLAR			EQU		&47
SPR_BUNDLE			EQU		&48
SPR_BEACON			EQU		&49
SPR_BUBBLE			EQU		&4A
SPR_BATCRAFT_RBLF	EQU		&4B
SPR_BATCRAFT_RFNT	EQU		&4C
SPR_BATCRAFT_LBCK	EQU		&4D
SPR_BATCRAFT_CKPIT	EQU		&4E
SPR_1st_3x24_sprite	EQU		SPR_BATTHRUSTER

;; -----------------------------------------------------------------------------------------------------------
img_3x24_bin:		;; SPR_BATTHRUSTER EQU &30
	DEFB &00, &00, &00, &00, &3C, &00, &00, &7F, &00, &0F, &86, &C0, &1F, &E3, &20, &38
	DEFB &F4, &D0, &31, &2B, &18, &70, &94, &74, &69, &29, &B4, &88, &AB, &5C, &51, &2B
	DEFB &54, &90, &AB, &D4, &50, &53, &54, &90, &53, &54, &50, &53, &54, &20, &53, &54
	DEFB &00, &53, &54, &00, &53, &5C, &00, &53, &42, &00, &51, &DE, &00, &3A, &28, &00
	DEFB &07, &E0, &00, &01, &80, &00, &00, &00, &FF, &C3, &FF, &FF, &BC, &FF, &F0, &7F
	DEFB &7F, &EF, &86, &FF, &DF, &EB, &1F, &B8, &F4, &07, &B6, &28, &1B, &77, &10, &35
	DEFB &66, &21, &B5, &07, &23, &5D, &8E, &23, &55, &0F, &23, &D5, &8F, &C3, &55, &0F
	DEFB &C3, &55, &8F, &C3, &55, &DF, &C3, &55, &FF, &C3, &55, &FF, &C3, &5D, &FF, &C3
	DEFB &40, &FF, &C1, &C0, &FF, &F0, &01, &FF, &F0, &07, &FF, &F8, &1F, &FF, &FE, &7F
	;;	........................	@@@@@@@@@@....@@@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@@.@@@@..@@@@@@@@
	;;	.........@@@@@@@........	@@@@.....@@@@@@@.@@@@@@@
	;;	....@@@@@....@@.@@......	@@@.@@@@@....@@.@@@@@@@@
	;;	...@@@@@@@@...@@..@.....	@@.@@@@@@@@.@.@@...@@@@@
	;;	..@@@...@@@@.@..@@.@....	@.@@@...@@@@.@.......@@@
	;;	..@@...@..@.@.@@...@@...	@.@@.@@...@.@......@@.@@
	;;	.@@@....@..@.@...@@@.@..	.@@@.@@@...@......@@.@.@
	;;	.@@.@..@..@.@..@@.@@.@..	.@@..@@...@....@@.@@.@.@
	;;	@...@...@.@.@.@@.@.@@@..	.....@@@..@...@@.@.@@@.@
	;;	.@.@...@..@.@.@@.@.@.@..	@...@@@...@...@@.@.@.@.@
	;;	@..@....@.@.@.@@@@.@.@..	....@@@@..@...@@@@.@.@.@
	;;	.@.@.....@.@..@@.@.@.@..	@...@@@@@@....@@.@.@.@.@
	;;	@..@.....@.@..@@.@.@.@..	....@@@@@@....@@.@.@.@.@
	;;	.@.@.....@.@..@@.@.@.@..	@...@@@@@@....@@.@.@.@.@
	;;	..@......@.@..@@.@.@.@..	@@.@@@@@@@....@@.@.@.@.@
	;;	.........@.@..@@.@.@.@..	@@@@@@@@@@....@@.@.@.@.@
	;;	.........@.@..@@.@.@@@..	@@@@@@@@@@....@@.@.@@@.@
	;;	.........@.@..@@.@....@.	@@@@@@@@@@....@@.@......
	;;	.........@.@...@@@.@@@@.	@@@@@@@@@@.....@@@......
	;;	..........@@@.@...@.@...	@@@@@@@@@@@@...........@
	;;	.............@@@@@@.....	@@@@@@@@@@@@.........@@@
	;;	...............@@.......	@@@@@@@@@@@@@......@@@@@
	;;	........................	@@@@@@@@@@@@@@@..@@@@@@@

		;; SPR_BATBELT : EQU &31
	DEFB &00, &00, &00, &00, &00, &00, &00, &0E, &00, &00, &11, &00, &00, &20, &B0, &00
	DEFB &30, &A0, &0E, &28, &58, &11, &B4, &50, &20, &44, &2C, &30, &38, &14, &30, &04
	DEFB &08, &2C, &04, &14, &35, &84, &E4, &2A, &B3, &54, &2D, &55, &14, &2D, &AC, &38
	DEFB &2D, &B0, &74, &2D, &AB, &6C, &15, &B7, &C0, &0A, &B1, &00, &0D, &56, &00, &01
	DEFB &A0, &00, &00, &30, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F1
	DEFB &FF, &FF, &E0, &CF, &FF, &C0, &37, &FF, &80, &27, &F1, &80, &1B, &E0, &00, &13
	DEFB &C0, &00, &0D, &80, &00, &05, &80, &00, &03, &8C, &00, &05, &85, &80, &E5, &88
	DEFB &B3, &55, &8D, &15, &15, &8D, &AC, &33, &8D, &B0, &75, &8D, &AB, &6D, &C5, &B7
	DEFB &D3, &E8, &B1, &3F, &ED, &10, &FF, &F1, &A9, &FF, &FE, &37, &FF, &FF, &CF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	............@@@.........	@@@@@@@@@@@@...@@@@@@@@@
	;;	...........@...@........	@@@@@@@@@@@.....@@..@@@@
	;;	..........@.....@.@@....	@@@@@@@@@@........@@.@@@
	;;	..........@@....@.@.....	@@@@@@@@@.........@..@@@
	;;	....@@@...@.@....@.@@...	@@@@...@@..........@@.@@
	;;	...@...@@.@@.@...@.@....	@@@................@..@@
	;;	..@......@...@....@.@@..	@@..................@@.@
	;;	..@@......@@@......@.@..	@....................@.@
	;;	..@@.........@......@...	@.....................@@
	;;	..@.@@.......@.....@.@..	@...@@...............@.@
	;;	..@@.@.@@....@..@@@..@..	@....@.@@.......@@@..@.@
	;;	..@.@.@.@.@@..@@.@.@.@..	@...@...@.@@..@@.@.@.@.@
	;;	..@.@@.@.@.@.@.@...@.@..	@...@@.@...@.@.@...@.@.@
	;;	..@.@@.@@.@.@@....@@@...	@...@@.@@.@.@@....@@..@@
	;;	..@.@@.@@.@@.....@@@.@..	@...@@.@@.@@.....@@@.@.@
	;;	..@.@@.@@.@.@.@@.@@.@@..	@...@@.@@.@.@.@@.@@.@@.@
	;;	...@.@.@@.@@.@@@@@......	@@...@.@@.@@.@@@@@.@..@@
	;;	....@.@.@.@@...@........	@@@.@...@.@@...@..@@@@@@
	;;	....@@.@.@.@.@@.........	@@@.@@.@...@....@@@@@@@@
	;;	.......@@.@.............	@@@@...@@.@.@..@@@@@@@@@
	;;	..........@@............	@@@@@@@...@@.@@@@@@@@@@@
	;;	........................	@@@@@@@@@@..@@@@@@@@@@@@

		;; SPR_BATBOOTS : EQU &32
	DEFB &00, &00, &00, &00, &C0, &00, &00, &70, &00, &00, &DC, &00, &0C, &67, &00, &07
	DEFB &30, &80, &0D, &CC, &80, &06, &77, &80, &0F, &08, &00, &03, &CB, &00, &06, &7A
	DEFB &00, &07, &87, &00, &07, &F6, &00, &07, &ED, &C0, &0B, &F6, &F0, &0B, &E2, &F8
	DEFB &0D, &DC, &F8, &05, &EF, &70, &09, &EF, &88, &06, &DF, &B0, &01, &3F, &00, &00
	DEFB &C0, &80, &00, &3F, &00, &00, &00, &00, &FF, &3F, &FF, &FE, &CF, &FF, &FF, &73
	DEFB &FF, &F2, &DC, &FF, &EC, &67, &7F, &F7, &30, &BF, &ED, &CC, &BF, &F6, &77, &BF
	DEFB &EB, &08, &7F, &F1, &C8, &7F, &F0, &78, &FF, &F0, &00, &7F, &F0, &00, &3F, &F0
	DEFB &01, &CF, &E8, &00, &F7, &E8, &00, &FB, &EC, &1C, &FB, &F4, &0F, &77, &E0, &0F
	DEFB &83, &F0, &1F, &87, &F8, &3F, &0F, &FE, &00, &3F, &FF, &00, &7F, &FF, &C0, &FF
	;;	........................	@@@@@@@@..@@@@@@@@@@@@@@
	;;	........@@..............	@@@@@@@.@@..@@@@@@@@@@@@
	;;	.........@@@............	@@@@@@@@.@@@..@@@@@@@@@@
	;;	........@@.@@@..........	@@@@..@.@@.@@@..@@@@@@@@
	;;	....@@...@@..@@@........	@@@.@@...@@..@@@.@@@@@@@
	;;	.....@@@..@@....@.......	@@@@.@@@..@@....@.@@@@@@
	;;	....@@.@@@..@@..@.......	@@@.@@.@@@..@@..@.@@@@@@
	;;	.....@@..@@@.@@@@.......	@@@@.@@..@@@.@@@@.@@@@@@
	;;	....@@@@....@...........	@@@.@.@@....@....@@@@@@@
	;;	......@@@@..@.@@........	@@@@...@@@..@....@@@@@@@
	;;	.....@@..@@@@.@.........	@@@@.....@@@@...@@@@@@@@
	;;	.....@@@@....@@@........	@@@@.............@@@@@@@
	;;	.....@@@@@@@.@@.........	@@@@..............@@@@@@
	;;	.....@@@@@@.@@.@@@......	@@@@...........@@@..@@@@
	;;	....@.@@@@@@.@@.@@@@....	@@@.@...........@@@@.@@@
	;;	....@.@@@@@...@.@@@@@...	@@@.@...........@@@@@.@@
	;;	....@@.@@@.@@@..@@@@@...	@@@.@@.....@@@..@@@@@.@@
	;;	.....@.@@@@.@@@@.@@@....	@@@@.@......@@@@.@@@.@@@
	;;	....@..@@@@.@@@@@...@...	@@@.........@@@@@.....@@
	;;	.....@@.@@.@@@@@@.@@....	@@@@.......@@@@@@....@@@
	;;	.......@..@@@@@@........	@@@@@.....@@@@@@....@@@@
	;;	........@@......@.......	@@@@@@@...........@@@@@@
	;;	..........@@@@@@........	@@@@@@@@.........@@@@@@@
	;;	........................	@@@@@@@@@@......@@@@@@@@

		;; SPR_BATBAG EQU &33
	DEFB &00, &00, &00, &00, &F0, &00, &0F, &38, &00, &13, &DD, &80, &39, &E2, &40, &36
	DEFB &95, &40, &28, &2A, &D0, &17, &D5, &48, &30, &7E, &A4, &25, &03, &6C, &4A, &B4
	DEFB &92, &55, &52, &6A, &4A, &95, &22, &55, &52, &8A, &4A, &95, &52, &55, &52, &AA
	DEFB &4A, &95, &52, &55, &52, &AA, &22, &95, &44, &18, &5A, &98, &07, &24, &60, &00
	DEFB &CB, &80, &00, &3C, &00, &00, &00, &00, &FF, &0F, &FF, &F0, &F7, &FF, &EF, &3A
	DEFB &7F, &D3, &DD, &BF, &B9, &E0, &5F, &B6, &80, &4F, &A8, &00, &57, &D7, &80, &4B
	DEFB &B8, &7C, &25, &A0, &03, &65, &40, &30, &92, &40, &10, &62, &40, &10, &22, &40
	DEFB &10, &02, &40, &10, &02, &40, &10, &02, &40, &10, &02, &40, &10, &02, &A0, &10
	DEFB &05, &D8, &18, &1B, &E7, &24, &67, &F8, &CB, &9F, &FF, &3C, &7F, &FF, &C3, &FF
	;;	........................	@@@@@@@@....@@@@@@@@@@@@
	;;	........@@@@............	@@@@....@@@@.@@@@@@@@@@@
	;;	....@@@@..@@@...........	@@@.@@@@..@@@.@..@@@@@@@
	;;	...@..@@@@.@@@.@@.......	@@.@..@@@@.@@@.@@.@@@@@@
	;;	..@@@..@@@@...@..@......	@.@@@..@@@@......@.@@@@@
	;;	..@@.@@.@..@.@.@.@......	@.@@.@@.@........@..@@@@
	;;	..@.@.....@.@.@.@@.@....	@.@.@............@.@.@@@
	;;	...@.@@@@@.@.@.@.@..@...	@@.@.@@@@........@..@.@@
	;;	..@@.....@@@@@@.@.@..@..	@.@@@....@@@@@....@..@.@
	;;	..@..@.@......@@.@@.@@..	@.@...........@@.@@..@.@
	;;	.@..@.@.@.@@.@..@..@..@.	.@........@@....@..@..@.
	;;	.@.@.@.@.@.@..@..@@.@.@.	.@.........@.....@@...@.
	;;	.@..@.@.@..@.@.@..@...@.	.@.........@......@...@.
	;;	.@.@.@.@.@.@..@.@...@.@.	.@.........@..........@.
	;;	.@..@.@.@..@.@.@.@.@..@.	.@.........@..........@.
	;;	.@.@.@.@.@.@..@.@.@.@.@.	.@.........@..........@.
	;;	.@..@.@.@..@.@.@.@.@..@.	.@.........@..........@.
	;;	.@.@.@.@.@.@..@.@.@.@.@.	.@.........@..........@.
	;;	..@...@.@..@.@.@.@...@..	@.@........@.........@.@
	;;	...@@....@.@@.@.@..@@...	@@.@@......@@......@@.@@
	;;	.....@@@..@..@...@@.....	@@@..@@@..@..@...@@..@@@
	;;	........@@..@.@@@.......	@@@@@...@@..@.@@@..@@@@@
	;;	..........@@@@..........	@@@@@@@@..@@@@...@@@@@@@
	;;	........................	@@@@@@@@@@....@@@@@@@@@@

		;; SPR_BONUS EQU &34
	DEFB &00, &00, &00, &00, &81, &00, &01, &7E, &80, &01, &00, &80, &01, &00, &80, &01
	DEFB &12, &80, &01, &00, &80, &01, &32, &80, &01, &3E, &80, &02, &0C, &40, &04, &A1
	DEFB &A0, &05, &FF, &A0, &09, &B1, &50, &09, &BB, &20, &08, &5E, &60, &08, &C0, &10
	DEFB &08, &21, &10, &08, &33, &10, &08, &33, &10, &08, &B6, &48, &09, &63, &B0, &04
	DEFB &B8, &C0, &03, &18, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &7E, &FF, &FE, &00
	DEFB &7F, &FE, &00, &7F, &FE, &00, &7F, &FE, &12, &7F, &FE, &00, &7F, &FE, &32, &7F
	DEFB &FE, &3E, &7F, &FC, &0C, &3F, &F8, &00, &1F, &F8, &00, &1F, &F0, &00, &0F, &F0
	DEFB &21, &2F, &F0, &5A, &6F, &F0, &C0, &0F, &F0, &00, &0F, &F0, &00, &0F, &F0, &00
	DEFB &0F, &F0, &00, &07, &F0, &00, &0F, &F8, &00, &1F, &FC, &C3, &3F, &FF, &E7, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........@......@........	@@@@@@@@.@@@@@@.@@@@@@@@
	;;	.......@.@@@@@@.@.......	@@@@@@@..........@@@@@@@
	;;	.......@........@.......	@@@@@@@..........@@@@@@@
	;;	.......@........@.......	@@@@@@@..........@@@@@@@
	;;	.......@...@..@.@.......	@@@@@@@....@..@..@@@@@@@
	;;	.......@........@.......	@@@@@@@..........@@@@@@@
	;;	.......@..@@..@.@.......	@@@@@@@...@@..@..@@@@@@@
	;;	.......@..@@@@@.@.......	@@@@@@@...@@@@@..@@@@@@@
	;;	......@.....@@...@......	@@@@@@......@@....@@@@@@
	;;	.....@..@.@....@@.@.....	@@@@@..............@@@@@
	;;	.....@.@@@@@@@@@@.@.....	@@@@@..............@@@@@
	;;	....@..@@.@@...@.@.@....	@@@@................@@@@
	;;	....@..@@.@@@.@@..@.....	@@@@......@....@..@.@@@@
	;;	....@....@.@@@@..@@.....	@@@@.....@.@@.@..@@.@@@@
	;;	....@...@@.........@....	@@@@....@@..........@@@@
	;;	....@.....@....@...@....	@@@@................@@@@
	;;	....@.....@@..@@...@....	@@@@................@@@@
	;;	....@.....@@..@@...@....	@@@@................@@@@
	;;	....@...@.@@.@@..@..@...	@@@@.................@@@
	;;	....@..@.@@...@@@.@@....	@@@@................@@@@
	;;	.....@..@.@@@...@@......	@@@@@..............@@@@@
	;;	......@@...@@...........	@@@@@@..@@....@@..@@@@@@
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@

		;; SPR_BATSIGNAL EQU &35
	DEFB &00, &00, &00, &00, &7E, &00, &01, &81, &80, &02, &20, &40, &04, &00, &20, &09
	DEFB &80, &10, &2B, &00, &14, &62, &00, &06, &10, &00, &08, &60, &00, &06, &48, &00
	DEFB &12, &3E, &00, &7C, &6B, &81, &D6, &62, &DB, &46, &30, &E7, &0C, &38, &66, &1C
	DEFB &5B, &66, &DA, &6F, &E7, &F6, &13, &DB, &C8, &04, &3C, &20, &01, &99, &80, &00
	DEFB &66, &00, &00, &18, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &81
	DEFB &FF, &FE, &20, &7F, &FC, &00, &3F, &D9, &80, &1B, &8B, &00, &11, &02, &00, &00
	DEFB &80, &00, &01, &00, &00, &00, &08, &00, &10, &BE, &00, &7D, &6B, &81, &D6, &62
	DEFB &C3, &46, &B0, &E7, &0D, &B8, &66, &1D, &1B, &66, &D8, &0F, &E7, &F0, &83, &C3
	DEFB &C1, &E0, &00, &07, &F8, &00, &1F, &FE, &00, &7F, &FF, &81, &FF, &FF, &E7, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	.........@@@@@@.........	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	.......@@......@@.......	@@@@@@@@@......@@@@@@@@@
	;;	......@...@......@......	@@@@@@@...@......@@@@@@@
	;;	.....@............@.....	@@@@@@............@@@@@@
	;;	....@..@@..........@....	@@.@@..@@..........@@.@@
	;;	..@.@.@@...........@.@..	@...@.@@...........@...@
	;;	.@@...@..............@@.	......@.................
	;;	...@................@...	@......................@
	;;	.@@..................@@.	........................
	;;	.@..@..............@..@.	....@..............@....
	;;	..@@@@@..........@@@@@..	@.@@@@@..........@@@@@.@
	;;	.@@.@.@@@......@@@.@.@@.	.@@.@.@@@......@@@.@.@@.
	;;	.@@...@.@@.@@.@@.@...@@.	.@@...@.@@....@@.@...@@.
	;;	..@@....@@@..@@@....@@..	@.@@....@@@..@@@....@@.@
	;;	..@@@....@@..@@....@@@..	@.@@@....@@..@@....@@@.@
	;;	.@.@@.@@.@@..@@.@@.@@.@.	...@@.@@.@@..@@.@@.@@...
	;;	.@@.@@@@@@@..@@@@@@@.@@.	....@@@@@@@..@@@@@@@....
	;;	...@..@@@@.@@.@@@@..@...	@.....@@@@....@@@@.....@
	;;	.....@....@@@@....@.....	@@@..................@@@
	;;	.......@@..@@..@@.......	@@@@@..............@@@@@
	;;	.........@@..@@.........	@@@@@@@..........@@@@@@@
	;;	...........@@...........	@@@@@@@@@......@@@@@@@@@
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@

		;; SPR_S_CUSHION EQU &36
	DEFB &00, &00, &00, &00, &20, &00, &00, &F8, &00, &03, &F8, &00, &0F, &66, &00, &1E
	DEFB &1F, &C0, &3E, &7F, &F0, &3F, &F9, &F8, &1F, &E1, &F8, &27, &9B, &F4, &38, &7F
	DEFB &CC, &1E, &FC, &38, &24, &3D, &EC, &1E, &D8, &18, &24, &E5, &EC, &1E, &38, &18
	DEFB &24, &CD, &EC, &1E, &38, &18, &06, &CD, &F0, &00, &38, &40, &00, &CC, &00, &00
	DEFB &7C, &00, &00, &18, &00, &00, &00, &00, &FF, &DF, &FF, &FF, &27, &FF, &FC, &FB
	DEFB &FF, &F3, &F9, &FF, &EF, &66, &3F, &DE, &1F, &CF, &BE, &7F, &F7, &BF, &F9, &FB
	DEFB &DF, &E1, &FB, &87, &9B, &F1, &80, &7F, &C1, &C0, &FC, &03, &A0, &3C, &05, &DA
	DEFB &18, &13, &A0, &01, &E5, &DA, &00, &11, &80, &C5, &E1, &C0, &30, &03, &E0, &C4
	DEFB &07, &F8, &32, &0F, &FE, &01, &BF, &FF, &01, &FF, &FF, &83, &FF, &FF, &E7, &FF
	;;	........................	@@@@@@@@@@.@@@@@@@@@@@@@
	;;	..........@.............	@@@@@@@@..@..@@@@@@@@@@@
	;;	........@@@@@...........	@@@@@@..@@@@@.@@@@@@@@@@
	;;	......@@@@@@@...........	@@@@..@@@@@@@..@@@@@@@@@
	;;	....@@@@.@@..@@.........	@@@.@@@@.@@..@@...@@@@@@
	;;	...@@@@....@@@@@@@......	@@.@@@@....@@@@@@@..@@@@
	;;	..@@@@@..@@@@@@@@@@@....	@.@@@@@..@@@@@@@@@@@.@@@
	;;	..@@@@@@@@@@@..@@@@@@...	@.@@@@@@@@@@@..@@@@@@.@@
	;;	...@@@@@@@@....@@@@@@...	@@.@@@@@@@@....@@@@@@.@@
	;;	..@..@@@@..@@.@@@@@@.@..	@....@@@@..@@.@@@@@@...@
	;;	..@@@....@@@@@@@@@..@@..	@........@@@@@@@@@.....@
	;;	...@@@@.@@@@@@....@@@...	@@......@@@@@@........@@
	;;	..@..@....@@@@.@@@@.@@..	@.@.......@@@@.......@.@
	;;	...@@@@.@@.@@......@@...	@@.@@.@....@@......@..@@
	;;	..@..@..@@@..@.@@@@.@@..	@.@............@@@@..@.@
	;;	...@@@@...@@@......@@...	@@.@@.@............@...@
	;;	..@..@..@@..@@.@@@@.@@..	@.......@@...@.@@@@....@
	;;	...@@@@...@@@......@@...	@@........@@..........@@
	;;	.....@@.@@..@@.@@@@@....	@@@.....@@...@.......@@@
	;;	..........@@@....@......	@@@@@.....@@..@.....@@@@
	;;	........@@..@@..........	@@@@@@@........@@.@@@@@@
	;;	.........@@@@@..........	@@@@@@@@.......@@@@@@@@@
	;;	...........@@...........	@@@@@@@@@.....@@@@@@@@@@
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@

		;; SPR_VAPE_0 EQU &37
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &28, &00, &00, &1E, &00, &00, &BC, &00, &00, &67, &80, &06, &D9, &00, &01, &E6
	DEFB &80, &03, &91, &C0, &0D, &FD, &F0, &0A, &D5, &C0, &03, &EB, &60, &00, &5C, &C0
	DEFB &00, &66, &10, &00, &00, &00, &00, &00, &40, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &D7, &FF, &FF, &A9, &FF, &FF, &5E, &FF, &FE, &BC, &7F
	DEFB &F9, &67, &BF, &F6, &D9, &7F, &F9, &E6, &BF, &F3, &91, &CF, &ED, &FD, &F7, &EA
	DEFB &D5, &CF, &F3, &EB, &6F, &FC, &5C, &CF, &FF, &66, &17, &FF, &99, &AF, &FF, &FF
	DEFB &5F, &FF, &FF, &BF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@.@.@@@@@@@@@@@
	;;	..........@.@...........	@@@@@@@@@.@.@..@@@@@@@@@
	;;	...........@@@@.........	@@@@@@@@.@.@@@@.@@@@@@@@
	;;	........@.@@@@..........	@@@@@@@.@.@@@@...@@@@@@@
	;;	.........@@..@@@@.......	@@@@@..@.@@..@@@@.@@@@@@
	;;	.....@@.@@.@@..@........	@@@@.@@.@@.@@..@.@@@@@@@
	;;	.......@@@@..@@.@.......	@@@@@..@@@@..@@.@.@@@@@@
	;;	......@@@..@...@@@......	@@@@..@@@..@...@@@..@@@@
	;;	....@@.@@@@@@@.@@@@@....	@@@.@@.@@@@@@@.@@@@@.@@@
	;;	....@.@.@@.@.@.@@@......	@@@.@.@.@@.@.@.@@@..@@@@
	;;	......@@@@@.@.@@.@@.....	@@@@..@@@@@.@.@@.@@.@@@@
	;;	.........@.@@@..@@......	@@@@@@...@.@@@..@@..@@@@
	;;	.........@@..@@....@....	@@@@@@@@.@@..@@....@.@@@
	;;	........................	@@@@@@@@@..@@..@@.@.@@@@
	;;	.................@......	@@@@@@@@@@@@@@@@.@.@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@.@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_VAPE_1 EQU &38
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &38, &00, &00
	DEFB &D4, &40, &06, &7D, &00, &05, &BF, &00, &03, &E6, &60, &01, &BB, &60, &01, &67
	DEFB &A8, &03, &9D, &D8, &0F, &BF, &A0, &03, &BB, &58, &06, &C7, &E8, &03, &3E, &40
	DEFB &18, &77, &20, &00, &02, &00, &07, &00, &00, &02, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &C7, &FF, &FF, &3B, &BF, &F8, &D4, &5F, &F6, &7D, &3F, &F5, &BF, &1F
	DEFB &FB, &E6, &6F, &FD, &BB, &67, &FD, &67, &AB, &F3, &9D, &DB, &EF, &BF, &A7, &F3
	DEFB &BB, &5B, &F6, &C7, &EB, &E3, &3E, &57, &D8, &77, &2F, &E0, &8A, &DF, &F7, &7D
	DEFB &FF, &FA, &FF, &FF, &FD, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@...@@@@@@@@@@@
	;;	..........@@@...........	@@@@@@@@..@@@.@@@.@@@@@@
	;;	........@@.@.@...@......	@@@@@...@@.@.@...@.@@@@@
	;;	.....@@..@@@@@.@........	@@@@.@@..@@@@@.@..@@@@@@
	;;	.....@.@@.@@@@@@........	@@@@.@.@@.@@@@@@...@@@@@
	;;	......@@@@@..@@..@@.....	@@@@@.@@@@@..@@..@@.@@@@
	;;	.......@@.@@@.@@.@@.....	@@@@@@.@@.@@@.@@.@@..@@@
	;;	.......@.@@..@@@@.@.@...	@@@@@@.@.@@..@@@@.@.@.@@
	;;	......@@@..@@@.@@@.@@...	@@@@..@@@..@@@.@@@.@@.@@
	;;	....@@@@@.@@@@@@@.@.....	@@@.@@@@@.@@@@@@@.@..@@@
	;;	......@@@.@@@.@@.@.@@...	@@@@..@@@.@@@.@@.@.@@.@@
	;;	.....@@.@@...@@@@@@.@...	@@@@.@@.@@...@@@@@@.@.@@
	;;	......@@..@@@@@..@......	@@@...@@..@@@@@..@.@.@@@
	;;	...@@....@@@.@@@..@.....	@@.@@....@@@.@@@..@.@@@@
	;;	..............@.........	@@@.....@...@.@.@@.@@@@@
	;;	.....@@@................	@@@@.@@@.@@@@@.@@@@@@@@@
	;;	......@.................	@@@@@.@.@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@.@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_VAPE_2 EQU &39
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &1C, &00, &02, &5C, &70, &0D
	DEFB &BB, &90, &09, &FE, &60, &06, &FD, &B0, &0F, &E7, &F0, &0F, &DD, &F0, &15, &FE
	DEFB &E0, &1B, &BE, &F8, &05, &FF, &F8, &1F, &DF, &E0, &3F, &E3, &70, &36, &FC, &EC
	DEFB &19, &FF, &DC, &05, &ED, &28, &02, &73, &F0, &00, &01, &F0, &00, &00, &E0, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &E3
	DEFB &FF, &FD, &9D, &8F, &F2, &5C, &77, &ED, &BB, &97, &E9, &FE, &6F, &F6, &FD, &B7
	DEFB &EF, &E7, &F7, &EF, &DD, &F7, &D5, &FE, &E7, &DB, &BE, &FB, &E5, &FF, &FB, &DF
	DEFB &DF, &E7, &BF, &E3, &73, &B6, &FC, &ED, &D9, &FF, &DD, &E5, &ED, &2B, &FA, &73
	DEFB &F7, &FD, &8D, &F7, &FF, &FE, &EF, &FF, &FF, &1F, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@...@@@@@@@@@@
	;;	...........@@@..........	@@@@@@.@@..@@@.@@...@@@@
	;;	......@..@.@@@...@@@....	@@@@..@..@.@@@...@@@.@@@
	;;	....@@.@@.@@@.@@@..@....	@@@.@@.@@.@@@.@@@..@.@@@
	;;	....@..@@@@@@@@..@@.....	@@@.@..@@@@@@@@..@@.@@@@
	;;	.....@@.@@@@@@.@@.@@....	@@@@.@@.@@@@@@.@@.@@.@@@
	;;	....@@@@@@@..@@@@@@@....	@@@.@@@@@@@..@@@@@@@.@@@
	;;	....@@@@@@.@@@.@@@@@....	@@@.@@@@@@.@@@.@@@@@.@@@
	;;	...@.@.@@@@@@@@.@@@.....	@@.@.@.@@@@@@@@.@@@..@@@
	;;	...@@.@@@.@@@@@.@@@@@...	@@.@@.@@@.@@@@@.@@@@@.@@
	;;	.....@.@@@@@@@@@@@@@@...	@@@..@.@@@@@@@@@@@@@@.@@
	;;	...@@@@@@@.@@@@@@@@.....	@@.@@@@@@@.@@@@@@@@..@@@
	;;	..@@@@@@@@@...@@.@@@....	@.@@@@@@@@@...@@.@@@..@@
	;;	..@@.@@.@@@@@@..@@@.@@..	@.@@.@@.@@@@@@..@@@.@@.@
	;;	...@@..@@@@@@@@@@@.@@@..	@@.@@..@@@@@@@@@@@.@@@.@
	;;	.....@.@@@@.@@.@..@.@...	@@@..@.@@@@.@@.@..@.@.@@
	;;	......@..@@@..@@@@@@....	@@@@@.@..@@@..@@@@@@.@@@
	;;	...............@@@@@....	@@@@@@.@@...@@.@@@@@.@@@
	;;	................@@@.....	@@@@@@@@@@@@@@@.@@@.@@@@
	;;	........................	@@@@@@@@@@@@@@@@...@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_WORM_0 EQU &3A
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &1E, &7E, &78, &0D
	DEFB &81, &B0, &0A, &7E, &50, &05, &81, &A0, &05, &00, &A0, &06, &18, &60, &03, &81
	DEFB &C0, &0E, &FF, &70, &1F, &00, &F8, &1C, &FF, &38, &10, &00, &08, &02, &00, &40
	DEFB &0A, &18, &50, &05, &BD, &A0, &02, &7E, &40, &01, &91, &80, &00, &7E, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &E1, &81, &87, &DE, &7E, &7B, &ED, &81, &B7, &EA, &00, &57, &F4, &00, &2F
	DEFB &F4, &66, &2F, &F6, &5A, &6F, &F3, &81, &CF, &EE, &FF, &77, &DF, &00, &FB, &DC
	DEFB &00, &3B, &D0, &00, &0B, &E0, &E7, &07, &E8, &5A, &17, &F4, &3C, &2F, &FA, &7E
	DEFB &5F, &FD, &91, &BF, &FE, &7E, &7F, &FF, &81, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@....@@......@@....@@@
	;;	...@@@@..@@@@@@..@@@@...	@@.@@@@..@@@@@@..@@@@.@@
	;;	....@@.@@......@@.@@....	@@@.@@.@@......@@.@@.@@@
	;;	....@.@..@@@@@@..@.@....	@@@.@.@..........@.@.@@@
	;;	.....@.@@......@@.@.....	@@@@.@............@.@@@@
	;;	.....@.@........@.@.....	@@@@.@...@@..@@...@.@@@@
	;;	.....@@....@@....@@.....	@@@@.@@..@.@@.@..@@.@@@@
	;;	......@@@......@@@......	@@@@..@@@......@@@..@@@@
	;;	....@@@.@@@@@@@@.@@@....	@@@.@@@.@@@@@@@@.@@@.@@@
	;;	...@@@@@........@@@@@...	@@.@@@@@........@@@@@.@@
	;;	...@@@..@@@@@@@@..@@@...	@@.@@@............@@@.@@
	;;	...@................@...	@@.@................@.@@
	;;	......@..........@......	@@@.....@@@..@@@.....@@@
	;;	....@.@....@@....@.@....	@@@.@....@.@@.@....@.@@@
	;;	.....@.@@.@@@@.@@.@.....	@@@@.@....@@@@....@.@@@@
	;;	......@..@@@@@@..@......	@@@@@.@..@@@@@@..@.@@@@@
	;;	.......@@..@...@@.......	@@@@@@.@@..@...@@.@@@@@@
	;;	.........@@@@@@.........	@@@@@@@..@@@@@@..@@@@@@@
	;;	........................	@@@@@@@@@......@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_WORM_1 EQU &3B
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &1E
	DEFB &7E, &78, &0D, &81, &B0, &0A, &7E, &50, &05, &81, &A0, &05, &3C, &A0, &16, &00
	DEFB &68, &13, &81, &C8, &0E, &FF, &70, &1F, &00, &F8, &1C, &E7, &38, &10, &18, &08
	DEFB &05, &BD, &A0, &02, &7E, &40, &01, &91, &80, &00, &7E, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &E1, &81, &87, &DE, &7E, &7B, &ED, &81, &B7, &EA, &00, &57
	DEFB &F4, &00, &2F, &E4, &3C, &27, &D6, &00, &6B, &D3, &81, &CB, &EE, &FF, &77, &DF
	DEFB &00, &FB, &DC, &00, &3B, &D0, &18, &0B, &E4, &3C, &27, &FA, &7E, &5F, &FD, &91
	DEFB &BF, &FE, &7E, &7F, &FF, &81, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@....@@......@@....@@@
	;;	...@@@@..@@@@@@..@@@@...	@@.@@@@..@@@@@@..@@@@.@@
	;;	....@@.@@......@@.@@....	@@@.@@.@@......@@.@@.@@@
	;;	....@.@..@@@@@@..@.@....	@@@.@.@..........@.@.@@@
	;;	.....@.@@......@@.@.....	@@@@.@............@.@@@@
	;;	.....@.@..@@@@..@.@.....	@@@..@....@@@@....@..@@@
	;;	...@.@@..........@@.@...	@@.@.@@..........@@.@.@@
	;;	...@..@@@......@@@..@...	@@.@..@@@......@@@..@.@@
	;;	....@@@.@@@@@@@@.@@@....	@@@.@@@.@@@@@@@@.@@@.@@@
	;;	...@@@@@........@@@@@...	@@.@@@@@........@@@@@.@@
	;;	...@@@..@@@..@@@..@@@...	@@.@@@............@@@.@@
	;;	...@.......@@.......@...	@@.@.......@@.......@.@@
	;;	.....@.@@.@@@@.@@.@.....	@@@..@....@@@@....@..@@@
	;;	......@..@@@@@@..@......	@@@@@.@..@@@@@@..@.@@@@@
	;;	.......@@..@...@@.......	@@@@@@.@@..@...@@.@@@@@@
	;;	.........@@@@@@.........	@@@@@@@..@@@@@@..@@@@@@@
	;;	........................	@@@@@@@@@......@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_PRESENT EQU &3C
	DEFB &00, &00, &00, &07, &1C, &00, &0F, &A3, &00, &09, &C0, &80, &0A, &E1, &E0, &17
	DEFB &52, &18, &61, &B9, &E6, &40, &77, &72, &60, &B4, &36, &5B, &C3, &B2, &47, &00
	DEFB &C2, &46, &81, &22, &46, &66, &64, &46, &18, &62, &26, &00, &62, &46, &18, &64
	DEFB &46, &08, &62, &46, &00, &62, &36, &18, &6C, &0E, &00, &70, &03, &10, &C0, &00
	DEFB &C3, &00, &00, &3C, &00, &00, &00, &00, &F8, &FF, &FF, &F7, &63, &FF, &EF, &80
	DEFB &7F, &E9, &C0, &BF, &EA, &E1, &DF, &E7, &52, &07, &81, &B9, &E1, &80, &77, &71
	DEFB &80, &B4, &31, &83, &C3, &B1, &87, &00, &C1, &86, &00, &21, &86, &00, &63, &86
	DEFB &00, &61, &C6, &00, &61, &86, &00, &63, &86, &00, &61, &86, &00, &61, &C6, &00
	DEFB &63, &F6, &00, &6F, &FA, &00, &5F, &FD, &00, &BF, &FF, &C3, &FF, &FF, &FF, &FF
	;;	........................	@@@@@...@@@@@@@@@@@@@@@@
	;;	.....@@@...@@@..........	@@@@.@@@.@@...@@@@@@@@@@
	;;	....@@@@@.@...@@........	@@@.@@@@@........@@@@@@@
	;;	....@..@@@......@.......	@@@.@..@@@......@.@@@@@@
	;;	....@.@.@@@....@@@@.....	@@@.@.@.@@@....@@@.@@@@@
	;;	...@.@@@.@.@..@....@@...	@@@..@@@.@.@..@......@@@
	;;	.@@....@@.@@@..@@@@..@@.	@......@@.@@@..@@@@....@
	;;	.@.......@@@.@@@.@@@..@.	@........@@@.@@@.@@@...@
	;;	.@@.....@.@@.@....@@.@@.	@.......@.@@.@....@@...@
	;;	.@.@@.@@@@....@@@.@@..@.	@.....@@@@....@@@.@@...@
	;;	.@...@@@........@@....@.	@....@@@........@@.....@
	;;	.@...@@.@......@..@...@.	@....@@...........@....@
	;;	.@...@@..@@..@@..@@..@..	@....@@..........@@...@@
	;;	.@...@@....@@....@@...@.	@....@@..........@@....@
	;;	..@..@@..........@@...@.	@@...@@..........@@....@
	;;	.@...@@....@@....@@..@..	@....@@..........@@...@@
	;;	.@...@@.....@....@@...@.	@....@@..........@@....@
	;;	.@...@@..........@@...@.	@....@@..........@@....@
	;;	..@@.@@....@@....@@.@@..	@@...@@..........@@...@@
	;;	....@@@..........@@@....	@@@@.@@..........@@.@@@@
	;;	......@@...@....@@......	@@@@@.@..........@.@@@@@
	;;	........@@....@@........	@@@@@@.@........@.@@@@@@
	;;	..........@@@@..........	@@@@@@@@@@....@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_WELL EQU &3D
	DEFB &00, &00, &00, &00, &00, &00, &00, &FF, &00, &07, &00, &E0, &18, &6D, &18, &26
	DEFB &DB, &64, &2D, &B6, &D4, &23, &6D, &A4, &18, &DB, &18, &27, &00, &E4, &30, &FF
	DEFB &0C, &37, &00, &EC, &37, &F7, &EC, &37, &F7, &EC, &17, &F7, &E8, &27, &F7, &E4
	DEFB &31, &F7, &8C, &3E, &00, &7C, &3E, &FF, &7C, &3E, &FF, &7C, &1E, &FF, &78, &06
	DEFB &FF, &60, &00, &FF, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &00, &FF, &F8, &00
	DEFB &1F, &E0, &00, &07, &C0, &49, &03, &82, &49, &21, &8D, &B6, &D1, &82, &49, &21
	DEFB &C0, &49, &03, &80, &00, &01, &80, &00, &01, &80, &00, &01, &80, &00, &01, &80
	DEFB &00, &01, &C0, &00, &03, &80, &00, &01, &80, &00, &01, &80, &00, &01, &80, &00
	DEFB &01, &80, &00, &01, &C0, &00, &03, &E0, &00, &07, &F8, &00, &1F, &FF, &00, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@........@@@@@@@@
	;;	........@@@@@@@@........	@@@@@..............@@@@@
	;;	.....@@@........@@@.....	@@@..................@@@
	;;	...@@....@@.@@.@...@@...	@@.......@..@..@......@@
	;;	..@..@@.@@.@@.@@.@@..@..	@.....@..@..@..@..@....@
	;;	..@.@@.@@.@@.@@.@@.@.@..	@...@@.@@.@@.@@.@@.@...@
	;;	..@...@@.@@.@@.@@.@..@..	@.....@..@..@..@..@....@
	;;	...@@...@@.@@.@@...@@...	@@.......@..@..@......@@
	;;	..@..@@@........@@@..@..	@......................@
	;;	..@@....@@@@@@@@....@@..	@......................@
	;;	..@@.@@@........@@@.@@..	@......................@
	;;	..@@.@@@@@@@.@@@@@@.@@..	@......................@
	;;	..@@.@@@@@@@.@@@@@@.@@..	@......................@
	;;	...@.@@@@@@@.@@@@@@.@...	@@....................@@
	;;	..@..@@@@@@@.@@@@@@..@..	@......................@
	;;	..@@...@@@@@.@@@@...@@..	@......................@
	;;	..@@@@@..........@@@@@..	@......................@
	;;	..@@@@@.@@@@@@@@.@@@@@..	@......................@
	;;	..@@@@@.@@@@@@@@.@@@@@..	@......................@
	;;	...@@@@.@@@@@@@@.@@@@...	@@....................@@
	;;	.....@@.@@@@@@@@.@@.....	@@@..................@@@
	;;	........@@@@@@@@........	@@@@@..............@@@@@
	;;	........................	@@@@@@@@........@@@@@@@@

		;; SPR_PAWDRUM EQU &3E
	DEFB &00, &00, &00, &00, &FF, &00, &03, &00, &C0, &0C, &B6, &30, &13, &6D, &88, &16
	DEFB &DB, &68, &2D, &B6, &D4, &33, &6D, &AC, &5A, &DB, &5A, &6C, &36, &36, &7F, &81
	DEFB &FE, &3F, &FF, &FC, &5F, &FF, &FA, &7F, &FF, &FE, &7E, &BD, &7E, &33, &7E, &CC
	DEFB &6D, &E7, &B6, &5E, &DB, &7A, &5F, &3C, &FA, &1F, &7E, &F8, &0F, &7E, &F0, &02
	DEFB &7E, &40, &00, &3C, &00, &00, &00, &00, &FF, &00, &FF, &FC, &00, &3F, &F0, &00
	DEFB &0F, &E0, &24, &07, &C1, &24, &83, &C4, &92, &43, &84, &92, &41, &82, &49, &21
	DEFB &02, &49, &00, &00, &24, &00, &00, &00, &00, &80, &00, &01, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &80, &00, &01, &0C, &00, &30, &1E, &18, &78, &1F, &3C
	DEFB &F8, &9F, &7E, &F9, &EF, &7E, &F7, &F2, &7E, &4F, &FD, &BD, &BF, &FF, &C3, &FF
	;;	........................	@@@@@@@@........@@@@@@@@
	;;	........@@@@@@@@........	@@@@@@............@@@@@@
	;;	......@@........@@......	@@@@................@@@@
	;;	....@@..@.@@.@@...@@....	@@@.......@..@.......@@@
	;;	...@..@@.@@.@@.@@...@...	@@.....@..@..@..@.....@@
	;;	...@.@@.@@.@@.@@.@@.@...	@@...@..@..@..@..@....@@
	;;	..@.@@.@@.@@.@@.@@.@.@..	@....@..@..@..@..@.....@
	;;	..@@..@@.@@.@@.@@.@.@@..	@.....@..@..@..@..@....@
	;;	.@.@@.@.@@.@@.@@.@.@@.@.	......@..@..@..@........
	;;	.@@.@@....@@.@@...@@.@@.	..........@..@..........
	;;	.@@@@@@@@......@@@@@@@@.	........................
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	.@.@@@@@@@@@@@@@@@@@@.@.	........................
	;;	.@@@@@@@@@@@@@@@@@@@@@@.	........................
	;;	.@@@@@@.@.@@@@.@.@@@@@@.	........................
	;;	..@@..@@.@@@@@@.@@..@@..	@......................@
	;;	.@@.@@.@@@@..@@@@.@@.@@.	....@@............@@....
	;;	.@.@@@@.@@.@@.@@.@@@@.@.	...@@@@....@@....@@@@...
	;;	.@.@@@@@..@@@@..@@@@@.@.	...@@@@@..@@@@..@@@@@...
	;;	...@@@@@.@@@@@@.@@@@@...	@..@@@@@.@@@@@@.@@@@@..@
	;;	....@@@@.@@@@@@.@@@@....	@@@.@@@@.@@@@@@.@@@@.@@@
	;;	......@..@@@@@@..@......	@@@@..@..@@@@@@..@..@@@@
	;;	..........@@@@..........	@@@@@@.@@.@@@@.@@.@@@@@@
	;;	........................	@@@@@@@@@@....@@@@@@@@@@

		;; SPR_STOOL EQU &3F
	DEFB &00, &00, &00, &00, &18, &00, &00, &66, &00, &01, &99, &80, &06, &24, &60, &18
	DEFB &34, &18, &64, &34, &26, &18, &34, &18, &66, &34, &66, &19, &91, &98, &26, &66
	DEFB &64, &31, &99, &94, &34, &66, &34, &34, &18, &34, &34, &24, &34, &34, &34, &34
	DEFB &34, &34, &34, &18, &34, &18, &00, &34, &00, &00, &34, &00, &00, &34, &00, &00
	DEFB &34, &00, &00, &18, &00, &00, &00, &00, &FF, &E7, &FF, &FF, &99, &FF, &FE, &66
	DEFB &7F, &F9, &81, &9F, &E6, &20, &67, &99, &B1, &99, &61, &B1, &86, &19, &B1, &98
	DEFB &06, &30, &60, &81, &91, &81, &A0, &66, &01, &B0, &18, &11, &B0, &00, &31, &B1
	DEFB &81, &B1, &B1, &A1, &B1, &B1, &B1, &B1, &B1, &B1, &B1, &DB, &B1, &DB, &E7, &B1
	DEFB &E7, &FF, &B1, &FF, &FF, &B1, &FF, &FF, &B1, &FF, &FF, &DB, &FF, &FF, &E7, &FF
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@
	;;	...........@@...........	@@@@@@@@@..@@..@@@@@@@@@
	;;	.........@@..@@.........	@@@@@@@..@@..@@..@@@@@@@
	;;	.......@@..@@..@@.......	@@@@@..@@......@@..@@@@@
	;;	.....@@...@..@...@@.....	@@@..@@...@......@@..@@@
	;;	...@@.....@@.@.....@@...	@..@@..@@.@@...@@..@@..@
	;;	.@@..@....@@.@....@..@@.	.@@....@@.@@...@@....@@.
	;;	...@@.....@@.@.....@@...	...@@..@@.@@...@@..@@...
	;;	.@@..@@...@@.@...@@..@@.	.....@@...@@.....@@.....
	;;	...@@..@@..@...@@..@@...	@......@@..@...@@......@
	;;	..@..@@..@@..@@..@@..@..	@.@......@@..@@........@
	;;	..@@...@@..@@..@@..@.@..	@.@@.......@@......@...@
	;;	..@@.@...@@..@@...@@.@..	@.@@..............@@...@
	;;	..@@.@.....@@.....@@.@..	@.@@...@@......@@.@@...@
	;;	..@@.@....@..@....@@.@..	@.@@...@@.@....@@.@@...@
	;;	..@@.@....@@.@....@@.@..	@.@@...@@.@@...@@.@@...@
	;;	..@@.@....@@.@....@@.@..	@.@@...@@.@@...@@.@@...@
	;;	...@@.....@@.@.....@@...	@@.@@.@@@.@@...@@@.@@.@@
	;;	..........@@.@..........	@@@..@@@@.@@...@@@@..@@@
	;;	..........@@.@..........	@@@@@@@@@.@@...@@@@@@@@@
	;;	..........@@.@..........	@@@@@@@@@.@@...@@@@@@@@@
	;;	..........@@.@..........	@@@@@@@@@.@@...@@@@@@@@@
	;;	...........@@...........	@@@@@@@@@@.@@.@@@@@@@@@@
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@

		;; SPR_SHROOM EQU &40
	DEFB &00, &00, &00, &00, &3C, &00, &00, &C3, &00, &03, &81, &C0, &06, &C3, &60, &0C
	DEFB &24, &30, &14, &3C, &28, &26, &24, &64, &39, &42, &9C, &50, &C3, &0A, &50, &C3
	DEFB &0A, &49, &24, &92, &36, &18, &6C, &22, &18, &44, &1A, &66, &58, &07, &C3, &E0
	DEFB &00, &FF, &00, &0A, &00, &50, &0A, &DB, &50, &07, &FF, &E0, &01, &BD, &80, &00
	DEFB &34, &00, &00, &00, &00, &00, &00, &00, &FF, &C3, &FF, &FF, &00, &FF, &FC, &00
	DEFB &3F, &F8, &00, &1F, &F0, &00, &0F, &E0, &00, &07, &C0, &00, &03, &80, &00, &01
	DEFB &80, &00, &01, &00, &00, &00, &00, &00, &00, &00, &00, &00, &80, &00, &01, &80
	DEFB &00, &01, &C0, &00, &03, &E0, &00, &07, &F0, &00, &0F, &EA, &00, &57, &EA, &DB
	DEFB &57, &F7, &FF, &EF, &F9, &BD, &9F, &FE, &34, &7F, &FF, &CB, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@....@@@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@........@@@@@@@@
	;;	........@@....@@........	@@@@@@............@@@@@@
	;;	......@@@......@@@......	@@@@@..............@@@@@
	;;	.....@@.@@....@@.@@.....	@@@@................@@@@
	;;	....@@....@..@....@@....	@@@..................@@@
	;;	...@.@....@@@@....@.@...	@@....................@@
	;;	..@..@@...@..@...@@..@..	@......................@
	;;	..@@@..@.@....@.@..@@@..	@......................@
	;;	.@.@....@@....@@....@.@.	........................
	;;	.@.@....@@....@@....@.@.	........................
	;;	.@..@..@..@..@..@..@..@.	........................
	;;	..@@.@@....@@....@@.@@..	@......................@
	;;	..@...@....@@....@...@..	@......................@
	;;	...@@.@..@@..@@..@.@@...	@@....................@@
	;;	.....@@@@@....@@@@@.....	@@@..................@@@
	;;	........@@@@@@@@........	@@@@................@@@@
	;;	....@.@..........@.@....	@@@.@.@..........@.@.@@@
	;;	....@.@.@@.@@.@@.@.@....	@@@.@.@.@@.@@.@@.@.@.@@@
	;;	.....@@@@@@@@@@@@@@.....	@@@@.@@@@@@@@@@@@@@.@@@@
	;;	.......@@.@@@@.@@.......	@@@@@..@@.@@@@.@@..@@@@@
	;;	..........@@.@..........	@@@@@@@...@@.@...@@@@@@@
	;;	........................	@@@@@@@@@@..@.@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_SWITCH EQU &41
	DEFB &00, &00, &00, &00, &7E, &00, &01, &BF, &C0, &0B, &CF, &F0, &1A, &F0, &78, &3A
	DEFB &FF, &BC, &3B, &7F, &BC, &3D, &BF, &BC, &1C, &00, &38, &2F, &FF, &F4, &33, &FF
	DEFB &CC, &3C, &7E, &3C, &5F, &81, &FA, &4F, &FF, &F2, &73, &FF, &CE, &3C, &7E, &3C
	DEFB &4F, &00, &F2, &73, &C3, &CE, &3C, &FF, &3C, &0F, &3C, &F0, &03, &C3, &C0, &00
	DEFB &FF, &00, &00, &3C, &00, &00, &00, &00, &FF, &81, &FF, &FE, &00, &3F, &F5, &80
	DEFB &0F, &E3, &C0, &07, &C2, &F0, &03, &82, &FF, &81, &83, &7F, &81, &81, &BF, &81
	DEFB &C0, &00, &03, &80, &00, &01, &80, &00, &01, &80, &00, &01, &40, &00, &02, &40
	DEFB &00, &02, &70, &00, &0E, &BC, &00, &3D, &0F, &00, &F0, &03, &C3, &C0, &80, &FF
	DEFB &01, &C0, &3C, &03, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF
	;;	........................	@@@@@@@@@......@@@@@@@@@
	;;	.........@@@@@@.........	@@@@@@@...........@@@@@@
	;;	.......@@.@@@@@@@@......	@@@@.@.@@...........@@@@
	;;	....@.@@@@..@@@@@@@@....	@@@...@@@@...........@@@
	;;	...@@.@.@@@@.....@@@@...	@@....@.@@@@..........@@
	;;	..@@@.@.@@@@@@@@@.@@@@..	@.....@.@@@@@@@@@......@
	;;	..@@@.@@.@@@@@@@@.@@@@..	@.....@@.@@@@@@@@......@
	;;	..@@@@.@@.@@@@@@@.@@@@..	@......@@.@@@@@@@......@
	;;	...@@@............@@@...	@@....................@@
	;;	..@.@@@@@@@@@@@@@@@@.@..	@......................@
	;;	..@@..@@@@@@@@@@@@..@@..	@......................@
	;;	..@@@@...@@@@@@...@@@@..	@......................@
	;;	.@.@@@@@@......@@@@@@.@.	.@....................@.
	;;	.@..@@@@@@@@@@@@@@@@..@.	.@....................@.
	;;	.@@@..@@@@@@@@@@@@..@@@.	.@@@................@@@.
	;;	..@@@@...@@@@@@...@@@@..	@.@@@@............@@@@.@
	;;	.@..@@@@........@@@@..@.	....@@@@........@@@@....
	;;	.@@@..@@@@....@@@@..@@@.	......@@@@....@@@@......
	;;	..@@@@..@@@@@@@@..@@@@..	@.......@@@@@@@@.......@
	;;	....@@@@..@@@@..@@@@....	@@........@@@@........@@
	;;	......@@@@....@@@@......	@@@@................@@@@
	;;	........@@@@@@@@........	@@@@@@............@@@@@@
	;;	..........@@@@..........	@@@@@@@@........@@@@@@@@
	;;	........................	@@@@@@@@@@....@@@@@@@@@@

		;; SPR_KETTLE EQU &42
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &3C, &00, &00, &76, &00, &18, &E2, &00
	DEFB &BD, &26, &03, &CB, &C2, &05, &D3, &A6, &3B, &E7, &AC, &5D, &3C, &68, &3E, &C3
	DEFB &90, &0F, &3C, &50, &07, &43, &60, &0F, &9B, &E0, &0F, &BF, &F0, &0F, &BF, &F0
	DEFB &17, &BF, &F8, &11, &7F, &E8, &16, &FF, &68, &08, &DB, &10, &06, &18, &60, &01
	DEFB &C3, &80, &00, &3C, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &C3, &FF, &FF
	DEFB &81, &FF, &E7, &00, &FF, &00, &00, &FC, &81, &00, &FB, &C3, &D0, &C5, &C3, &A0
	DEFB &83, &E7, &A1, &01, &3C, &63, &80, &C3, &97, &C0, &3C, &57, &E0, &43, &6F, &E0
	DEFB &1B, &EF, &E0, &3F, &F7, &E0, &3F, &F7, &D0, &3F, &FB, &D0, &7F, &EB, &D6, &FF
	DEFB &6B, &E8, &DB, &17, &F6, &18, &6F, &F9, &C3, &9F, &FE, &3C, &7F, &FF, &C3, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@....@@
	;;	..................@@@@..	@@@@@@@@@@@@@@@@@......@
	;;	.................@@@.@@.	@@@@@@@@@@@..@@@........
	;;	...........@@...@@@...@.	@@@@@@@@................
	;;	........@.@@@@.@..@..@@.	@@@@@@..@......@........
	;;	......@@@@..@.@@@@....@.	@@@@@.@@@@....@@@@.@....
	;;	.....@.@@@.@..@@@.@..@@.	@@...@.@@@....@@@.@.....
	;;	..@@@.@@@@@..@@@@.@.@@..	@.....@@@@@..@@@@.@....@
	;;	.@.@@@.@..@@@@...@@.@...	.......@..@@@@...@@...@@
	;;	..@@@@@.@@....@@@..@....	@.......@@....@@@..@.@@@
	;;	....@@@@..@@@@...@.@....	@@........@@@@...@.@.@@@
	;;	.....@@@.@....@@.@@.....	@@@......@....@@.@@.@@@@
	;;	....@@@@@..@@.@@@@@.....	@@@........@@.@@@@@.@@@@
	;;	....@@@@@.@@@@@@@@@@....	@@@.......@@@@@@@@@@.@@@
	;;	....@@@@@.@@@@@@@@@@....	@@@.......@@@@@@@@@@.@@@
	;;	...@.@@@@.@@@@@@@@@@@...	@@.@......@@@@@@@@@@@.@@
	;;	...@...@.@@@@@@@@@@.@...	@@.@.....@@@@@@@@@@.@.@@
	;;	...@.@@.@@@@@@@@.@@.@...	@@.@.@@.@@@@@@@@.@@.@.@@
	;;	....@...@@.@@.@@...@....	@@@.@...@@.@@.@@...@.@@@
	;;	.....@@....@@....@@.....	@@@@.@@....@@....@@.@@@@
	;;	.......@@@....@@@.......	@@@@@..@@@....@@@..@@@@@
	;;	..........@@@@..........	@@@@@@@...@@@@...@@@@@@@
	;;	........................	@@@@@@@@@@....@@@@@@@@@@

		;; SPR_SUGARBOX EQU &43
	DEFB &00, &00, &00, &00, &3C, &00, &01, &E7, &80, &07, &DB, &E0, &1F, &BD, &F8, &2F
	DEFB &A5, &F4, &2F, &DB, &F4, &37, &E7, &EC, &19, &FF, &98, &2E, &3C, &72, &35, &C3
	DEFB &CA, &36, &7E, &3A, &3B, &01, &F6, &7D, &8F, &EC, &6E, &E7, &9C, &7F, &38, &72
	DEFB &5F, &CF, &CA, &57, &F0, &2A, &26, &FF, &64, &10, &DB, &08, &0E, &18, &70, &03
	DEFB &C3, &C0, &00, &7E, &00, &00, &00, &00, &FF, &C3, &FF, &FE, &3C, &7F, &F9, &E7
	DEFB &9F, &E7, &C3, &E7, &DF, &81, &FB, &AF, &81, &F5, &AF, &C3, &F5, &B7, &E7, &ED
	DEFB &D9, &FF, &99, &A2, &3C, &70, &B1, &C3, &C8, &B0, &7E, &38, &B8, &01, &F0, &7C
	DEFB &0F, &E1, &6E, &07, &81, &7F, &00, &02, &5F, &C0, &0A, &57, &F0, &2A, &A6, &FF
	DEFB &65, &D0, &DB, &0B, &EE, &18, &77, &F3, &C3, &CF, &FC, &7E, &3F, &FF, &81, &FF
	;;	........................	@@@@@@@@@@....@@@@@@@@@@
	;;	..........@@@@..........	@@@@@@@...@@@@...@@@@@@@
	;;	.......@@@@..@@@@.......	@@@@@..@@@@..@@@@..@@@@@
	;;	.....@@@@@.@@.@@@@@.....	@@@..@@@@@....@@@@@..@@@
	;;	...@@@@@@.@@@@.@@@@@@...	@@.@@@@@@......@@@@@@.@@
	;;	..@.@@@@@.@..@.@@@@@.@..	@.@.@@@@@......@@@@@.@.@
	;;	..@.@@@@@@.@@.@@@@@@.@..	@.@.@@@@@@....@@@@@@.@.@
	;;	..@@.@@@@@@..@@@@@@.@@..	@.@@.@@@@@@..@@@@@@.@@.@
	;;	...@@..@@@@@@@@@@..@@...	@@.@@..@@@@@@@@@@..@@..@
	;;	..@.@@@...@@@@...@@@..@.	@.@...@...@@@@...@@@....
	;;	..@@.@.@@@....@@@@..@.@.	@.@@...@@@....@@@@..@...
	;;	..@@.@@..@@@@@@...@@@.@.	@.@@.....@@@@@@...@@@...
	;;	..@@@.@@.......@@@@@.@@.	@.@@@..........@@@@@....
	;;	.@@@@@.@@...@@@@@@@.@@..	.@@@@@......@@@@@@@....@
	;;	.@@.@@@.@@@..@@@@..@@@..	.@@.@@@......@@@@......@
	;;	.@@@@@@@..@@@....@@@..@.	.@@@@@@@..............@.
	;;	.@.@@@@@@@..@@@@@@..@.@.	.@.@@@@@@@..........@.@.
	;;	.@.@.@@@@@@@......@.@.@.	.@.@.@@@@@@@......@.@.@.
	;;	..@..@@.@@@@@@@@.@@..@..	@.@..@@.@@@@@@@@.@@..@.@
	;;	...@....@@.@@.@@....@...	@@.@....@@.@@.@@....@.@@
	;;	....@@@....@@....@@@....	@@@.@@@....@@....@@@.@@@
	;;	......@@@@....@@@@......	@@@@..@@@@....@@@@..@@@@
	;;	.........@@@@@@.........	@@@@@@...@@@@@@...@@@@@@
	;;	........................	@@@@@@@@@......@@@@@@@@@

		;; SPR_BATCRAFT_FINS EQU &44
	DEFB &00, &00, &00, &00, &60, &00, &00, &70, &00, &00, &38, &00, &00, &3C, &40, &00
	DEFB &3E, &C0, &00, &1F, &40, &00, &1F, &40, &00, &27, &80, &00, &78, &80, &01, &FF
	DEFB &40, &00, &00, &C0, &00, &0F, &C0, &00, &0F, &E0, &00, &0F, &E0, &00, &0D, &E0
	DEFB &00, &09, &70, &00, &0C, &70, &00, &0E, &B0, &00, &07, &F0, &00, &07, &F0, &00
	DEFB &01, &F0, &00, &00, &60, &00, &00, &00, &FF, &9F, &FF, &FF, &0F, &FF, &FF, &07
	DEFB &FF, &FF, &83, &BF, &FF, &81, &5F, &FF, &80, &DF, &FF, &C0, &5F, &FF, &C0, &5F
	DEFB &FF, &A0, &3F, &FE, &78, &3F, &FD, &FF, &1F, &FE, &00, &1F, &FF, &E0, &1F, &FF
	DEFB &E0, &0F, &FF, &E7, &0F, &FF, &ED, &CF, &FF, &E9, &47, &FF, &EC, &67, &FF, &E6
	DEFB &A7, &FF, &F3, &C7, &FF, &F0, &07, &FF, &F8, &07, &FF, &FE, &0F, &FF, &FF, &9F
	;;	........................	@@@@@@@@@..@@@@@@@@@@@@@
	;;	.........@@.............	@@@@@@@@....@@@@@@@@@@@@
	;;	.........@@@............	@@@@@@@@.....@@@@@@@@@@@
	;;	..........@@@...........	@@@@@@@@@.....@@@.@@@@@@
	;;	..........@@@@...@......	@@@@@@@@@......@.@.@@@@@
	;;	..........@@@@@.@@......	@@@@@@@@@.......@@.@@@@@
	;;	...........@@@@@.@......	@@@@@@@@@@.......@.@@@@@
	;;	...........@@@@@.@......	@@@@@@@@@@.......@.@@@@@
	;;	..........@..@@@@.......	@@@@@@@@@.@.......@@@@@@
	;;	.........@@@@...@.......	@@@@@@@..@@@@.....@@@@@@
	;;	.......@@@@@@@@@.@......	@@@@@@.@@@@@@@@@...@@@@@
	;;	................@@......	@@@@@@@............@@@@@
	;;	............@@@@@@......	@@@@@@@@@@@........@@@@@
	;;	............@@@@@@@.....	@@@@@@@@@@@.........@@@@
	;;	............@@@@@@@.....	@@@@@@@@@@@..@@@....@@@@
	;;	............@@.@@@@.....	@@@@@@@@@@@.@@.@@@..@@@@
	;;	............@..@.@@@....	@@@@@@@@@@@.@..@.@...@@@
	;;	............@@...@@@....	@@@@@@@@@@@.@@...@@..@@@
	;;	............@@@.@.@@....	@@@@@@@@@@@..@@.@.@..@@@
	;;	.............@@@@@@@....	@@@@@@@@@@@@..@@@@...@@@
	;;	.............@@@@@@@....	@@@@@@@@@@@@.........@@@
	;;	...............@@@@@....	@@@@@@@@@@@@@........@@@
	;;	.................@@.....	@@@@@@@@@@@@@@@.....@@@@
	;;	........................	@@@@@@@@@@@@@@@@@..@@@@@

		;; SPR_QBALL EQU &45
	DEFB &00, &00, &00, &00, &7E, &00, &01, &81, &80, &06, &00, &60, &08, &1F, &10, &10
	DEFB &71, &C8, &10, &E0, &E8, &20, &CE, &64, &21, &C6, &74, &41, &E6, &72, &41, &FC
	DEFB &F2, &41, &F9, &F2, &40, &F9, &E2, &40, &FF, &E2, &40, &79, &C2, &20, &1F, &04
	DEFB &24, &00, &04, &10, &00, &08, &13, &00, &08, &09, &C0, &10, &06, &00, &60, &01
	DEFB &81, &80, &00, &7E, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &81, &FF, &FE, &00
	DEFB &7F, &F8, &00, &1F, &F0, &1F, &0F, &E0, &71, &C7, &E0, &E0, &E7, &C0, &CE, &63
	DEFB &C1, &C6, &73, &81, &E6, &71, &81, &FC, &F1, &81, &F9, &F1, &80, &F9, &E1, &80
	DEFB &FF, &E1, &80, &79, &C1, &C0, &1F, &03, &C0, &00, &03, &E0, &00, &07, &E0, &00
	DEFB &07, &F0, &00, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &81, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	.........@@@@@@.........	@@@@@@@@@......@@@@@@@@@
	;;	.......@@......@@.......	@@@@@@@..........@@@@@@@
	;;	.....@@..........@@.....	@@@@@..............@@@@@
	;;	....@......@@@@@...@....	@@@@.......@@@@@....@@@@
	;;	...@.....@@@...@@@..@...	@@@......@@@...@@@...@@@
	;;	...@....@@@.....@@@.@...	@@@.....@@@.....@@@..@@@
	;;	..@.....@@..@@@..@@..@..	@@......@@..@@@..@@...@@
	;;	..@....@@@...@@..@@@.@..	@@.....@@@...@@..@@@..@@
	;;	.@.....@@@@..@@..@@@..@.	@......@@@@..@@..@@@...@
	;;	.@.....@@@@@@@..@@@@..@.	@......@@@@@@@..@@@@...@
	;;	.@.....@@@@@@..@@@@@..@.	@......@@@@@@..@@@@@...@
	;;	.@......@@@@@..@@@@...@.	@.......@@@@@..@@@@....@
	;;	.@......@@@@@@@@@@@...@.	@.......@@@@@@@@@@@....@
	;;	.@.......@@@@..@@@....@.	@........@@@@..@@@.....@
	;;	..@........@@@@@.....@..	@@.........@@@@@......@@
	;;	..@..@...............@..	@@....................@@
	;;	...@................@...	@@@..................@@@
	;;	...@..@@............@...	@@@..................@@@
	;;	....@..@@@.........@....	@@@@................@@@@
	;;	.....@@..........@@.....	@@@@@..............@@@@@
	;;	.......@@......@@.......	@@@@@@@..........@@@@@@@
	;;	.........@@@@@@.........	@@@@@@@@@......@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_SALT EQU &46
	DEFB &00, &00, &00, &00, &FF, &00, &03, &81, &C0, &06, &6C, &60, &0E, &12, &70, &0A
	DEFB &00, &50, &17, &81, &E8, &17, &FF, &E8, &28, &BD, &14, &27, &00, &E4, &20, &FF
	DEFB &14, &47, &00, &1A, &57, &0F, &1A, &99, &0F, &65, &B8, &F0, &E5, &58, &F0, &E2
	DEFB &60, &F0, &E6, &78, &F0, &1E, &7F, &00, &FE, &3F, &FF, &FC, &1F, &FF, &F8, &07
	DEFB &FF, &E0, &00, &FF, &00, &00, &00, &00, &FF, &00, &FF, &FC, &FF, &3F, &FB, &81
	DEFB &DF, &F6, &00, &6F, &EE, &00, &77, &EA, &00, &57, &C7, &81, &E3, &C7, &FF, &E3
	DEFB &A0, &BD, &05, &A0, &00, &05, &A0, &00, &15, &47, &00, &1A, &57, &0F, &1A, &99
	DEFB &0F, &65, &B8, &F0, &E5, &18, &F0, &E0, &00, &F0, &E0, &00, &F0, &00, &00, &00
	DEFB &00, &80, &00, &01, &C0, &00, &03, &E0, &00, &07, &F8, &00, &1F, &FF, &00, &FF
	;;	........................	@@@@@@@@........@@@@@@@@
	;;	........@@@@@@@@........	@@@@@@..@@@@@@@@..@@@@@@
	;;	......@@@......@@@......	@@@@@.@@@......@@@.@@@@@
	;;	.....@@..@@.@@...@@.....	@@@@.@@..........@@.@@@@
	;;	....@@@....@..@..@@@....	@@@.@@@..........@@@.@@@
	;;	....@.@..........@.@....	@@@.@.@..........@.@.@@@
	;;	...@.@@@@......@@@@.@...	@@...@@@@......@@@@...@@
	;;	...@.@@@@@@@@@@@@@@.@...	@@...@@@@@@@@@@@@@@...@@
	;;	..@.@...@.@@@@.@...@.@..	@.@.....@.@@@@.@.....@.@
	;;	..@..@@@........@@@..@..	@.@..................@.@
	;;	..@.....@@@@@@@@...@.@..	@.@................@.@.@
	;;	.@...@@@...........@@.@.	.@...@@@...........@@.@.
	;;	.@.@.@@@....@@@@...@@.@.	.@.@.@@@....@@@@...@@.@.
	;;	@..@@..@....@@@@.@@..@.@	@..@@..@....@@@@.@@..@.@
	;;	@.@@@...@@@@....@@@..@.@	@.@@@...@@@@....@@@..@.@
	;;	.@.@@...@@@@....@@@...@.	...@@...@@@@....@@@.....
	;;	.@@.....@@@@....@@@..@@.	........@@@@....@@@.....
	;;	.@@@@...@@@@.......@@@@.	........@@@@............
	;;	.@@@@@@@........@@@@@@@.	........................
	;;	..@@@@@@@@@@@@@@@@@@@@..	@......................@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	.....@@@@@@@@@@@@@@.....	@@@..................@@@
	;;	........@@@@@@@@........	@@@@@..............@@@@@
	;;	........................	@@@@@@@@........@@@@@@@@

		;; SPR_PILLAR EQU &47
	DEFB &00, &00, &00, &00, &00, &00, &00, &FF, &00, &07, &00, &E0, &18, &6D, &18, &36
	DEFB &DB, &6C, &2D, &B6, &D4, &33, &6D, &AC, &18, &DB, &18, &27, &00, &E4, &28, &FF
	DEFB &14, &2E, &00, &B4, &2E, &F7, &B4, &2E, &F7, &B4, &2E, &F7, &B4, &2E, &F7, &B4
	DEFB &2E, &F7, &B4, &2E, &F7, &B4, &2E, &F7, &B4, &0E, &F7, &B0, &06, &F7, &A0, &00
	DEFB &F7, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &00, &FF, &F8, &FF
	DEFB &1F, &E7, &00, &E7, &D8, &24, &1B, &B2, &49, &2D, &A4, &92, &45, &B1, &24, &8D
	DEFB &D8, &49, &1B, &A7, &00, &E5, &A8, &FF, &15, &AE, &00, &B5, &AE, &F7, &B5, &AE
	DEFB &F7, &B5, &AE, &F7, &B5, &AE, &F7, &B5, &AE, &F7, &B5, &AE, &F7, &B5, &AE, &F7
	DEFB &B5, &CE, &F7, &B3, &F6, &F7, &AF, &F8, &F7, &1F, &FF, &08, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@........@@@@@@@@
	;;	........@@@@@@@@........	@@@@@...@@@@@@@@...@@@@@
	;;	.....@@@........@@@.....	@@@..@@@........@@@..@@@
	;;	...@@....@@.@@.@...@@...	@@.@@.....@..@.....@@.@@
	;;	..@@.@@.@@.@@.@@.@@.@@..	@.@@..@..@..@..@..@.@@.@
	;;	..@.@@.@@.@@.@@.@@.@.@..	@.@..@..@..@..@..@...@.@
	;;	..@@..@@.@@.@@.@@.@.@@..	@.@@...@..@..@..@...@@.@
	;;	...@@...@@.@@.@@...@@...	@@.@@....@..@..@...@@.@@
	;;	..@..@@@........@@@..@..	@.@..@@@........@@@..@.@
	;;	..@.@...@@@@@@@@...@.@..	@.@.@...@@@@@@@@...@.@.@
	;;	..@.@@@.........@.@@.@..	@.@.@@@.........@.@@.@.@
	;;	..@.@@@.@@@@.@@@@.@@.@..	@.@.@@@.@@@@.@@@@.@@.@.@
	;;	..@.@@@.@@@@.@@@@.@@.@..	@.@.@@@.@@@@.@@@@.@@.@.@
	;;	..@.@@@.@@@@.@@@@.@@.@..	@.@.@@@.@@@@.@@@@.@@.@.@
	;;	..@.@@@.@@@@.@@@@.@@.@..	@.@.@@@.@@@@.@@@@.@@.@.@
	;;	..@.@@@.@@@@.@@@@.@@.@..	@.@.@@@.@@@@.@@@@.@@.@.@
	;;	..@.@@@.@@@@.@@@@.@@.@..	@.@.@@@.@@@@.@@@@.@@.@.@
	;;	..@.@@@.@@@@.@@@@.@@.@..	@.@.@@@.@@@@.@@@@.@@.@.@
	;;	....@@@.@@@@.@@@@.@@....	@@..@@@.@@@@.@@@@.@@..@@
	;;	.....@@.@@@@.@@@@.@.....	@@@@.@@.@@@@.@@@@.@.@@@@
	;;	........@@@@.@@@........	@@@@@...@@@@.@@@...@@@@@
	;;	........................	@@@@@@@@....@...@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_BUNDLE EQU &48
	DEFB &00, &00, &00, &00, &18, &00, &00, &24, &00, &09, &B5, &90, &1E, &99, &78, &04
	DEFB &3C, &20, &12, &99, &48, &2D, &A5, &B4, &13, &3C, &C8, &35, &7E, &AC, &2E, &5E
	DEFB &74, &4E, &FF, &72, &54, &7F, &2A, &54, &FF, &AA, &5A, &FF, &DA, &56, &FF, &EA
	DEFB &2F, &FE, &F4, &1F, &FF, &F8, &0F, &BF, &F0, &03, &E7, &C0, &00, &7E, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &E7, &FF, &FF, &C3, &FF, &F6, &00
	DEFB &6F, &E9, &81, &97, &DE, &81, &7B, &E4, &00, &27, &D2, &81, &4B, &AD, &81, &B5
	DEFB &D3, &00, &CB, &B5, &00, &AD, &AE, &00, &75, &4E, &00, &72, &54, &00, &2A, &54
	DEFB &00, &2A, &58, &00, &1A, &50, &00, &0A, &A0, &00, &05, &C0, &00, &03, &E0, &00
	DEFB &07, &F0, &00, &0F, &FC, &00, &3F, &FF, &81, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@..@@@@@@@@@@@
	;;	...........@@...........	@@@@@@@@@@....@@@@@@@@@@
	;;	..........@..@..........	@@@@.@@..........@@.@@@@
	;;	....@..@@.@@.@.@@..@....	@@@.@..@@......@@..@.@@@
	;;	...@@@@.@..@@..@.@@@@...	@@.@@@@.@......@.@@@@.@@
	;;	.....@....@@@@....@.....	@@@..@............@..@@@
	;;	...@..@.@..@@..@.@..@...	@@.@..@.@......@.@..@.@@
	;;	..@.@@.@@.@..@.@@.@@.@..	@.@.@@.@@......@@.@@.@.@
	;;	...@..@@..@@@@..@@..@...	@@.@..@@........@@..@.@@
	;;	..@@.@.@.@@@@@@.@.@.@@..	@.@@.@.@........@.@.@@.@
	;;	..@.@@@..@.@@@@..@@@.@..	@.@.@@@..........@@@.@.@
	;;	.@..@@@.@@@@@@@@.@@@..@.	.@..@@@..........@@@..@.
	;;	.@.@.@...@@@@@@@..@.@.@.	.@.@.@............@.@.@.
	;;	.@.@.@..@@@@@@@@@.@.@.@.	.@.@.@............@.@.@.
	;;	.@.@@.@.@@@@@@@@@@.@@.@.	.@.@@..............@@.@.
	;;	.@.@.@@.@@@@@@@@@@@.@.@.	.@.@................@.@.
	;;	..@.@@@@@@@@@@@.@@@@.@..	@.@..................@.@
	;;	...@@@@@@@@@@@@@@@@@@...	@@....................@@
	;;	....@@@@@.@@@@@@@@@@....	@@@..................@@@
	;;	......@@@@@..@@@@@......	@@@@................@@@@
	;;	.........@@@@@@.........	@@@@@@............@@@@@@
	;;	........................	@@@@@@@@@......@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_BEACON EQU &49
	DEFB &00, &00, &00, &00, &00, &00, &00, &3C, &00, &01, &E7, &80, &07, &7E, &E0, &0B
	DEFB &C3, &D0, &16, &99, &68, &17, &C3, &E8, &2B, &7E, &C4, &29, &DB, &A4, &18, &7E
	DEFB &68, &18, &80, &E8, &0C, &F0, &F0, &23, &F1, &C4, &20, &7E, &14, &57, &00, &1A
	DEFB &37, &0F, &14, &3B, &0F, &24, &10, &F0, &E8, &0C, &F0, &F0, &03, &F1, &C0, &00
	DEFB &7E, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &C3, &FF, &FE, &3C
	DEFB &7F, &F9, &E7, &9F, &F7, &7E, &EF, &EB, &C3, &D7, &D6, &81, &6B, &D7, &C3, &EB
	DEFB &AB, &7E, &C5, &A9, &DB, &A5, &D8, &7E, &6B, &D8, &80, &EB, &CC, &F0, &F3, &83
	DEFB &F1, &C1, &80, &7E, &01, &00, &00, &00, &80, &00, &01, &80, &00, &01, &C0, &00
	DEFB &03, &E0, &00, &07, &F0, &00, &0F, &FC, &00, &3F, &FF, &81, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@....@@@@@@@@@@
	;;	..........@@@@..........	@@@@@@@...@@@@...@@@@@@@
	;;	.......@@@@..@@@@.......	@@@@@..@@@@..@@@@..@@@@@
	;;	.....@@@.@@@@@@.@@@.....	@@@@.@@@.@@@@@@.@@@.@@@@
	;;	....@.@@@@....@@@@.@....	@@@.@.@@@@....@@@@.@.@@@
	;;	...@.@@.@..@@..@.@@.@...	@@.@.@@.@......@.@@.@.@@
	;;	...@.@@@@@....@@@@@.@...	@@.@.@@@@@....@@@@@.@.@@
	;;	..@.@.@@.@@@@@@.@@...@..	@.@.@.@@.@@@@@@.@@...@.@
	;;	..@.@..@@@.@@.@@@.@..@..	@.@.@..@@@.@@.@@@.@..@.@
	;;	...@@....@@@@@@..@@.@...	@@.@@....@@@@@@..@@.@.@@
	;;	...@@...@.......@@@.@...	@@.@@...@.......@@@.@.@@
	;;	....@@..@@@@....@@@@....	@@..@@..@@@@....@@@@..@@
	;;	..@...@@@@@@...@@@...@..	@.....@@@@@@...@@@.....@
	;;	..@......@@@@@@....@.@..	@........@@@@@@........@
	;;	.@.@.@@@...........@@.@.	........................
	;;	..@@.@@@....@@@@...@.@..	@......................@
	;;	..@@@.@@....@@@@..@..@..	@......................@
	;;	...@....@@@@....@@@.@...	@@....................@@
	;;	....@@..@@@@....@@@@....	@@@..................@@@
	;;	......@@@@@@...@@@......	@@@@................@@@@
	;;	.........@@@@@@.........	@@@@@@............@@@@@@
	;;	........................	@@@@@@@@@......@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_BUBBLE EQU &4A
	DEFB &00, &00, &00, &00, &7E, &00, &01, &81, &80, &06, &00, &60, &08, &80, &10, &12
	DEFB &00, &08, &16, &00, &08, &24, &00, &04, &20, &00, &04, &40, &00, &02, &40, &00
	DEFB &02, &40, &00, &02, &40, &00, &02, &40, &00, &02, &40, &00, &02, &20, &00, &04
	DEFB &20, &00, &04, &10, &00, &08, &10, &00, &08, &08, &00, &10, &06, &00, &60, &01
	DEFB &81, &80, &00, &7E, &00, &00, &00, &00, &FF, &81, &FF, &FE, &00, &7F, &F8, &00
	DEFB &1F, &F0, &7E, &0F, &E0, &BF, &87, &C2, &7F, &E3, &C6, &FF, &E3, &85, &FF, &F1
	DEFB &8B, &FF, &F1, &1F, &FF, &F8, &1F, &FF, &F8, &1F, &FF, &F8, &1F, &FF, &F8, &1F
	DEFB &FF, &F8, &1F, &FF, &F8, &8F, &FF, &F1, &8F, &FF, &F1, &C7, &FF, &E3, &C7, &FF
	DEFB &E3, &E1, &FF, &87, &F0, &7E, &0F, &F8, &00, &1F, &FE, &00, &7F, &FF, &81, &FF
	;;	........................	@@@@@@@@@......@@@@@@@@@
	;;	.........@@@@@@.........	@@@@@@@..........@@@@@@@
	;;	.......@@......@@.......	@@@@@..............@@@@@
	;;	.....@@..........@@.....	@@@@.....@@@@@@.....@@@@
	;;	....@...@..........@....	@@@.....@.@@@@@@@....@@@
	;;	...@..@.............@...	@@....@..@@@@@@@@@@...@@
	;;	...@.@@.............@...	@@...@@.@@@@@@@@@@@...@@
	;;	..@..@...............@..	@....@.@@@@@@@@@@@@@...@
	;;	..@..................@..	@...@.@@@@@@@@@@@@@@...@
	;;	.@....................@.	...@@@@@@@@@@@@@@@@@@...
	;;	.@....................@.	...@@@@@@@@@@@@@@@@@@...
	;;	.@....................@.	...@@@@@@@@@@@@@@@@@@...
	;;	.@....................@.	...@@@@@@@@@@@@@@@@@@...
	;;	.@....................@.	...@@@@@@@@@@@@@@@@@@...
	;;	.@....................@.	...@@@@@@@@@@@@@@@@@@...
	;;	..@..................@..	@...@@@@@@@@@@@@@@@@...@
	;;	..@..................@..	@...@@@@@@@@@@@@@@@@...@
	;;	...@................@...	@@...@@@@@@@@@@@@@@...@@
	;;	...@................@...	@@...@@@@@@@@@@@@@@...@@
	;;	....@..............@....	@@@....@@@@@@@@@@....@@@
	;;	.....@@..........@@.....	@@@@.....@@@@@@.....@@@@
	;;	.......@@......@@.......	@@@@@..............@@@@@
	;;	.........@@@@@@.........	@@@@@@@..........@@@@@@@
	;;	........................	@@@@@@@@@......@@@@@@@@@

		;; SPR_BATCRAFT_RBLF EQU &4B
	DEFB &00, &18, &00, &00, &66, &00, &01, &81, &80, &03, &00, &60, &07, &00, &18, &08
	DEFB &00, &06, &16, &00, &02, &1E, &00, &02, &3F, &00, &0E, &3C, &00, &32, &3B, &80
	DEFB &CA, &57, &C3, &3A, &4F, &D6, &CA, &6F, &BD, &EA, &33, &BD, &92, &3C, &79, &B2
	DEFB &1F, &3A, &62, &1D, &C7, &92, &0C, &F7, &CC, &07, &FB, &30, &03, &FC, &C0, &00
	DEFB &FF, &00, &00, &38, &00, &00, &00, &00, &FF, &9F, &FF, &FE, &67, &FF, &FD, &81
	DEFB &FF, &FB, &00, &7F, &F7, &00, &1F, &E8, &00, &07, &D6, &00, &02, &DE, &00, &02
	DEFB &BF, &00, &0E, &BC, &00, &30, &BB, &80, &C8, &17, &C3, &38, &0F, &D6, &08, &0F
	DEFB &BC, &08, &83, &BC, &00, &80, &78, &00, &C0, &3A, &00, &C0, &07, &90, &E0, &07
	DEFB &C1, &F0, &03, &03, &F8, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C7, &FF
	;;	...........@@...........	@@@@@@@@@..@@@@@@@@@@@@@
	;;	.........@@..@@.........	@@@@@@@..@@..@@@@@@@@@@@
	;;	.......@@......@@.......	@@@@@@.@@......@@@@@@@@@
	;;	......@@.........@@.....	@@@@@.@@.........@@@@@@@
	;;	.....@@@...........@@...	@@@@.@@@...........@@@@@
	;;	....@................@@.	@@@.@................@@@
	;;	...@.@@...............@.	@@.@.@@...............@.
	;;	...@@@@...............@.	@@.@@@@...............@.
	;;	..@@@@@@............@@@.	@.@@@@@@............@@@.
	;;	..@@@@............@@..@.	@.@@@@............@@....
	;;	..@@@.@@@.......@@..@.@.	@.@@@.@@@.......@@..@...
	;;	.@.@.@@@@@....@@..@@@.@.	...@.@@@@@....@@..@@@...
	;;	.@..@@@@@@.@.@@.@@..@.@.	....@@@@@@.@.@@.....@...
	;;	.@@.@@@@@.@@@@.@@@@.@.@.	....@@@@@.@@@@......@...
	;;	..@@..@@@.@@@@.@@..@..@.	@.....@@@.@@@@..........
	;;	..@@@@...@@@@..@@.@@..@.	@........@@@@...........
	;;	...@@@@@..@@@.@..@@...@.	@@........@@@.@.........
	;;	...@@@.@@@...@@@@..@..@.	@@...........@@@@..@....
	;;	....@@..@@@@.@@@@@..@@..	@@@..........@@@@@.....@
	;;	.....@@@@@@@@.@@..@@....	@@@@..........@@......@@
	;;	......@@@@@@@@..@@......	@@@@@...............@@@@
	;;	........@@@@@@@@........	@@@@@@............@@@@@@
	;;	..........@@@...........	@@@@@@@@........@@@@@@@@
	;;	........................	@@@@@@@@@@...@@@@@@@@@@@

		;; SPR_BATCRAFT_RFNT EQU &4C
	DEFB &00, &00, &00, &00, &3C, &00, &00, &C3, &00, &03, &00, &C0, &0C, &00, &30, &30
	DEFB &00, &0C, &40, &00, &02, &40, &00, &02, &38, &00, &1C, &77, &00, &EE, &6F, &BD
	DEFB &F6, &6F, &7E, &F6, &1F, &7E, &F8, &47, &7E, &E2, &78, &FF, &1E, &7F, &00, &FE
	DEFB &79, &FF, &9E, &3D, &FF, &BC, &0F, &FF, &F0, &00, &FF, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &C3
	DEFB &FF, &FF, &00, &FF, &FC, &00, &3F, &F0, &00, &0F, &C0, &00, &03, &C0, &00, &03
	DEFB &B8, &00, &1D, &77, &00, &EE, &6F, &BD, &F6, &6F, &7E, &F6, &9F, &7E, &F9, &07
	DEFB &7E, &E0, &00, &FF, &00, &00, &00, &00, &00, &00, &00, &80, &00, &01, &C0, &00
	DEFB &03, &F0, &00, &0F, &FF, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	..........@@@@..........	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........@@....@@........	@@@@@@@@@@....@@@@@@@@@@
	;;	......@@........@@......	@@@@@@@@........@@@@@@@@
	;;	....@@............@@....	@@@@@@............@@@@@@
	;;	..@@................@@..	@@@@................@@@@
	;;	.@....................@.	@@....................@@
	;;	.@....................@.	@@....................@@
	;;	..@@@..............@@@..	@.@@@..............@@@.@
	;;	.@@@.@@@........@@@.@@@.	.@@@.@@@........@@@.@@@.
	;;	.@@.@@@@@.@@@@.@@@@@.@@.	.@@.@@@@@.@@@@.@@@@@.@@.
	;;	.@@.@@@@.@@@@@@.@@@@.@@.	.@@.@@@@.@@@@@@.@@@@.@@.
	;;	...@@@@@.@@@@@@.@@@@@...	@..@@@@@.@@@@@@.@@@@@..@
	;;	.@...@@@.@@@@@@.@@@...@.	.....@@@.@@@@@@.@@@.....
	;;	.@@@@...@@@@@@@@...@@@@.	........@@@@@@@@........
	;;	.@@@@@@@........@@@@@@@.	........................
	;;	.@@@@..@@@@@@@@@@..@@@@.	........................
	;;	..@@@@.@@@@@@@@@@.@@@@..	@......................@
	;;	....@@@@@@@@@@@@@@@@....	@@....................@@
	;;	........@@@@@@@@........	@@@@................@@@@
	;;	........................	@@@@@@@@........@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

		;; SPR_BATCRAFT_LBCK EQU &4D
	DEFB &00, &00, &00, &00, &00, &00, &00, &FF, &00, &07, &00, &E0, &38, &00, &1C, &40
	DEFB &00, &02, &40, &00, &02, &30, &00, &0C, &4C, &00, &32, &53, &00, &CA, &58, &C3
	DEFB &1A, &43, &3C, &C2, &4F, &DB, &F2, &53, &DB, &CA, &5B, &18, &DA, &6C, &5A, &36
	DEFB &61, &DB, &86, &37, &DB, &EC, &1B, &DB, &D8, &0C, &DB, &30, &03, &18, &C0, &00
	DEFB &DB, &00, &00, &3C, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &00, &FF, &F8, &00, &1F, &C0, &00, &03, &40, &00, &02, &B0, &00, &0D
	DEFB &4C, &00, &32, &53, &00, &CA, &58, &C3, &1A, &00, &3C, &00, &00, &18, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &42, &00, &01, &C3, &80, &87, &C3, &E1, &C3, &C3
	DEFB &C3, &E0, &C3, &07, &F0, &00, &0F, &FC, &00, &3F, &FF, &00, &FF, &FF, &C3, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........@@@@@@@@........	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	.....@@@........@@@.....	@@@@@@@@........@@@@@@@@
	;;	..@@@..............@@@..	@@@@@..............@@@@@
	;;	.@....................@.	@@....................@@
	;;	.@....................@.	.@....................@.
	;;	..@@................@@..	@.@@................@@.@
	;;	.@..@@............@@..@.	.@..@@............@@..@.
	;;	.@.@..@@........@@..@.@.	.@.@..@@........@@..@.@.
	;;	.@.@@...@@....@@...@@.@.	.@.@@...@@....@@...@@.@.
	;;	.@....@@..@@@@..@@....@.	..........@@@@..........
	;;	.@..@@@@@@.@@.@@@@@@..@.	...........@@...........
	;;	.@.@..@@@@.@@.@@@@..@.@.	........................
	;;	.@.@@.@@...@@...@@.@@.@.	........................
	;;	.@@.@@...@.@@.@...@@.@@.	.........@....@.........
	;;	.@@....@@@.@@.@@@....@@.	.......@@@....@@@.......
	;;	..@@.@@@@@.@@.@@@@@.@@..	@....@@@@@....@@@@@....@
	;;	...@@.@@@@.@@.@@@@.@@...	@@....@@@@....@@@@....@@
	;;	....@@..@@.@@.@@..@@....	@@@.....@@....@@.....@@@
	;;	......@@...@@...@@......	@@@@................@@@@
	;;	........@@.@@.@@........	@@@@@@............@@@@@@
	;;	..........@@@@..........	@@@@@@@@........@@@@@@@@
	;;	........................	@@@@@@@@@@....@@@@@@@@@@

		;; SPR_BATCRAFT_CKPIT EQU &4E
	DEFB &00, &00, &00, &00, &00, &00, &00, &0E, &00, &00, &0B, &00, &00, &04, &80, &00
	DEFB &18, &40, &70, &E4, &20, &4F, &07, &10, &40, &07, &B0, &40, &07, &28, &30, &00
	DEFB &D8, &4E, &07, &3C, &71, &F8, &FC, &7E, &07, &FE, &7F, &FF, &FE, &7F, &FF, &FE
	DEFB &7E, &BF, &FC, &3C, &1F, &FC, &1F, &7F, &F8, &07, &FF, &E0, &01, &FF, &80, &00
	DEFB &3C, &00, &00, &00, &00, &00, &00, &00, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FB, &FF, &FF, &F4, &FF, &FF, &FB, &7F, &FF, &E0, &BF, &CF, &10, &5F
	DEFB &D0, &F0, &37, &CF, &F0, &23, &B1, &F8, &CB, &0E, &07, &09, &01, &F8, &0D, &00
	DEFB &00, &00, &00, &00, &00, &03, &E0, &00, &06, &B0, &01, &84, &10, &01, &C7, &70
	DEFB &03, &E3, &E0, &07, &F8, &00, &1F, &FE, &00, &7F, &FF, &C3, &FF, &FF, &FF, &FF
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	............@@@.........	@@@@@@@@@@@@@@@@@@@@@@@@
	;;	............@.@@........	@@@@@@@@@@@@@.@@@@@@@@@@
	;;	.............@..@.......	@@@@@@@@@@@@.@..@@@@@@@@
	;;	...........@@....@......	@@@@@@@@@@@@@.@@.@@@@@@@
	;;	.@@@....@@@..@....@.....	@@@@@@@@@@@.....@.@@@@@@
	;;	.@..@@@@.....@@@...@....	@@..@@@@...@.....@.@@@@@
	;;	.@...........@@@@.@@....	@@.@....@@@@......@@.@@@
	;;	.@...........@@@..@.@...	@@..@@@@@@@@......@...@@
	;;	..@@............@@.@@...	@.@@...@@@@@@...@@..@.@@
	;;	.@..@@@......@@@..@@@@..	....@@@......@@@....@..@
	;;	.@@@...@@@@@@...@@@@@@..	.......@@@@@@.......@@.@
	;;	.@@@@@@......@@@@@@@@@@.	........................
	;;	.@@@@@@@@@@@@@@@@@@@@@@.	........................
	;;	.@@@@@@@@@@@@@@@@@@@@@@.	......@@@@@.............
	;;	.@@@@@@.@.@@@@@@@@@@@@..	.....@@.@.@@...........@
	;;	..@@@@.....@@@@@@@@@@@..	@....@.....@...........@
	;;	...@@@@@.@@@@@@@@@@@@...	@@...@@@.@@@..........@@
	;;	.....@@@@@@@@@@@@@@.....	@@@...@@@@@..........@@@
	;;	.......@@@@@@@@@@.......	@@@@@..............@@@@@
	;;	..........@@@@..........	@@@@@@@..........@@@@@@@
	;;	........................	@@@@@@@@@@....@@@@@@@@@@
	;;	........................	@@@@@@@@@@@@@@@@@@@@@@@@

;; -----------------------------------------------------------------------------------------------------------
SPR_DOORSTEP		EQU		&50
SPR_SMILEY			EQU		&51
SPR_ROLLER			EQU		&52
SPR_CLEARBOX		EQU		&53
SPR_STEPBOX			EQU		&54
SPR_LAVAPIT			EQU		&55
SPR_COLUMN			EQU		&56
SPR_ECRIN			EQU		&57
SPR_BOX				EQU		&58
SPR_Z_CUSHION		EQU		&59
SPR_TURTLE			EQU		&5A
SPR_TABLE			EQU		&5B
SPR_CRATE			EQU		&5C
SPR_TARBOX			EQU		&5D
SPR_DSPIKES			EQU		&5E
SPR_BRICKW			EQU		&5F
SPR_1st_4x28_sprite	EQU		SPR_DOORSTEP

;; -----------------------------------------------------------------------------------------------------------
img_4x28_bin:			;; SPR_DOORSTEP EQU &50
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0F, &F0, &00, &00, &3F, &FC, &00
	DEFB &00, &FF, &FF, &00, &03, &FF, &FF, &80, &0F, &FF, &F8, &00, &3F, &FF, &FB, &80
	DEFB &3F, &FF, &83, &80, &4F, &FF, &BB, &80, &33, &F8, &3B, &80, &4C, &FB, &BB, &80
	DEFB &33, &03, &B8, &00, &4C, &BB, &B8, &00, &33, &3B, &80, &00, &0C, &BB, &80, &00
	DEFB &03, &38, &00, &00, &00, &B8, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F0, &0F, &FF, &FF, &C0, &03, &FF, &FF, &00, &00, &FF
	DEFB &FC, &00, &00, &3F, &F0, &00, &00, &3F, &C0, &00, &00, &3F, &80, &00, &03, &BF
	DEFB &00, &00, &03, &BF, &00, &00, &3B, &BF, &20, &00, &3B, &BF, &08, &03, &BB, &BF
	DEFB &12, &03, &B8, &7F, &04, &3B, &BB, &FF, &21, &3B, &87, &FF, &C8, &3B, &BF, &FF
	DEFB &F2, &38, &7F, &FF, &FC, &3B, &FF, &FF, &FF, &07, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	............@@@@@@@@............	@@@@@@@@@@............@@@@@@@@@@
	;;	..........@@@@@@@@@@@@..........	@@@@@@@@................@@@@@@@@
	;;	........@@@@@@@@@@@@@@@@........	@@@@@@....................@@@@@@
	;;	......@@@@@@@@@@@@@@@@@@@.......	@@@@......................@@@@@@
	;;	....@@@@@@@@@@@@@@@@@...........	@@........................@@@@@@
	;;	..@@@@@@@@@@@@@@@@@@@.@@@.......	@.....................@@@.@@@@@@
	;;	..@@@@@@@@@@@@@@@.....@@@.......	......................@@@.@@@@@@
	;;	.@..@@@@@@@@@@@@@.@@@.@@@.......	..................@@@.@@@.@@@@@@
	;;	..@@..@@@@@@@.....@@@.@@@.......	..@...............@@@.@@@.@@@@@@
	;;	.@..@@..@@@@@.@@@.@@@.@@@.......	....@.........@@@.@@@.@@@.@@@@@@
	;;	..@@..@@......@@@.@@@...........	...@..@.......@@@.@@@....@@@@@@@
	;;	.@..@@..@.@@@.@@@.@@@...........	.....@....@@@.@@@.@@@.@@@@@@@@@@
	;;	..@@..@@..@@@.@@@...............	..@....@..@@@.@@@....@@@@@@@@@@@
	;;	....@@..@.@@@.@@@...............	@@..@.....@@@.@@@.@@@@@@@@@@@@@@
	;;	......@@..@@@...................	@@@@..@...@@@....@@@@@@@@@@@@@@@
	;;	........@.@@@...................	@@@@@@....@@@.@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@.....@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_SMILEY EQU &51
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &07, &E0, &00
	DEFB &00, &38, &1C, &00, &00, &C7, &E3, &00, &03, &3E, &3C, &C0, &06, &FC, &FF, &60
	DEFB &0D, &C7, &7B, &B0, &1B, &9E, &61, &D8, &3B, &BF, &8D, &DC, &3B, &FE, &39, &DC
	DEFB &2D, &F8, &E3, &B4, &26, &FC, &0F, &64, &2B, &3F, &FC, &D4, &24, &C7, &E3, &24
	DEFB &2B, &38, &1C, &D4, &31, &C7, &E3, &8C, &30, &F9, &9F, &0C, &18, &3D, &BC, &18
	DEFB &1C, &05, &A0, &38, &0E, &01, &80, &70, &07, &81, &81, &E0, &01, &F3, &CF, &80
	DEFB &00, &7F, &FE, &00, &00, &0F, &F0, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F8, &1F, &FF, &FF, &C0, &03, &FF
	DEFB &FF, &00, &00, &FF, &FC, &07, &E0, &3F, &F8, &3E, &3C, &1F, &F0, &FC, &FF, &0F
	DEFB &E1, &C7, &7B, &87, &C3, &9E, &61, &C3, &83, &BF, &8D, &C1, &83, &FE, &39, &C1
	DEFB &81, &F8, &E3, &81, &80, &FC, &0F, &01, &80, &3F, &FC, &01, &80, &07, &E0, &01
	DEFB &83, &00, &00, &C1, &85, &C0, &03, &A1, &86, &78, &1E, &61, &C3, &8C, &31, &C3
	DEFB &C1, &F0, &0F, &83, &E0, &7C, &3E, &07, &F0, &0C, &30, &0F, &F8, &00, &00, &1F
	DEFB &FE, &00, &00, &7F, &FF, &80, &01, &FF, &FF, &F0, &0F, &FF, &FF, &FF, &FF, &FF
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@......@@@@@@@@@@@@@
	;;	.............@@@@@@.............	@@@@@@@@@@............@@@@@@@@@@
	;;	..........@@@......@@@..........	@@@@@@@@................@@@@@@@@
	;;	........@@...@@@@@@...@@........	@@@@@@.......@@@@@@.......@@@@@@
	;;	......@@..@@@@@...@@@@..@@......	@@@@@.....@@@@@...@@@@.....@@@@@
	;;	.....@@.@@@@@@..@@@@@@@@.@@.....	@@@@....@@@@@@..@@@@@@@@....@@@@
	;;	....@@.@@@...@@@.@@@@.@@@.@@....	@@@....@@@...@@@.@@@@.@@@....@@@
	;;	...@@.@@@..@@@@..@@....@@@.@@...	@@....@@@..@@@@..@@....@@@....@@
	;;	..@@@.@@@.@@@@@@@...@@.@@@.@@@..	@.....@@@.@@@@@@@...@@.@@@.....@
	;;	..@@@.@@@@@@@@@...@@@..@@@.@@@..	@.....@@@@@@@@@...@@@..@@@.....@
	;;	..@.@@.@@@@@@...@@@...@@@.@@.@..	@......@@@@@@...@@@...@@@......@
	;;	..@..@@.@@@@@@......@@@@.@@..@..	@.......@@@@@@......@@@@.......@
	;;	..@.@.@@..@@@@@@@@@@@@..@@.@.@..	@.........@@@@@@@@@@@@.........@
	;;	..@..@..@@...@@@@@@...@@..@..@..	@............@@@@@@............@
	;;	..@.@.@@..@@@......@@@..@@.@.@..	@.....@@................@@.....@
	;;	..@@...@@@...@@@@@@...@@@...@@..	@....@.@@@............@@@.@....@
	;;	..@@....@@@@@..@@..@@@@@....@@..	@....@@..@@@@......@@@@..@@....@
	;;	...@@.....@@@@.@@.@@@@.....@@...	@@....@@@...@@....@@...@@@....@@
	;;	...@@@.......@.@@.@.......@@@...	@@.....@@@@@........@@@@@.....@@
	;;	....@@@........@@........@@@....	@@@......@@@@@....@@@@@......@@@
	;;	.....@@@@......@@......@@@@.....	@@@@........@@....@@........@@@@
	;;	.......@@@@@..@@@@..@@@@@.......	@@@@@......................@@@@@
	;;	.........@@@@@@@@@@@@@@.........	@@@@@@@..................@@@@@@@
	;;	............@@@@@@@@............	@@@@@@@@@..............@@@@@@@@@
	;;	................................	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_ROLLER EQU &52
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0C, &70, &00, &00, &3F, &9C, &00
	DEFB &00, &FF, &E7, &00, &03, &FF, &F9, &C0, &07, &FF, &FE, &70, &18, &FF, &FF, &98
	DEFB &0F, &3F, &FF, &EC, &31, &CF, &FF, &F6, &4C, &73, &FF, &F6, &43, &1C, &FF, &BA
	DEFB &50, &C7, &3E, &7A, &4A, &31, &DD, &FA, &4E, &8C, &EF, &FA, &51, &A3, &6F, &FA
	DEFB &50, &68, &B7, &FA, &48, &1A, &B7, &FA, &56, &0C, &B7, &FA, &25, &84, &B7, &F4
	DEFB &29, &64, &B7, &F4, &1A, &5C, &B7, &E0, &06, &90, &B7, &C0, &01, &A4, &B7, &00
	DEFB &00, &69, &6C, &00, &00, &1D, &60, &00, &00, &02, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &CC, &73, &FF, &FF, &3F, &9C, &FF
	DEFB &FC, &FF, &E7, &3F, &FB, &FF, &F9, &CF, &E7, &FF, &FE, &77, &D8, &FF, &FF, &9B
	DEFB &CF, &3F, &FF, &ED, &81, &CF, &FF, &F6, &00, &73, &FF, &F6, &00, &1C, &FF, &BA
	DEFB &10, &07, &3E, &7A, &00, &01, &DD, &FA, &00, &00, &EF, &FA, &00, &00, &6F, &FA
	DEFB &00, &00, &37, &FA, &00, &02, &37, &FA, &10, &00, &37, &FA, &80, &00, &37, &F5
	DEFB &80, &00, &37, &F5, &C0, &00, &37, &E3, &E0, &00, &37, &DF, &F8, &04, &37, &3F
	DEFB &FE, &00, &6C, &FF, &FF, &80, &63, &FF, &FF, &E0, &DF, &FF, &FF, &FD, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	............@@...@@@............	@@@@@@@@@@..@@...@@@..@@@@@@@@@@
	;;	..........@@@@@@@..@@@..........	@@@@@@@@..@@@@@@@..@@@..@@@@@@@@
	;;	........@@@@@@@@@@@..@@@........	@@@@@@..@@@@@@@@@@@..@@@..@@@@@@
	;;	......@@@@@@@@@@@@@@@..@@@......	@@@@@.@@@@@@@@@@@@@@@..@@@..@@@@
	;;	.....@@@@@@@@@@@@@@@@@@..@@@....	@@@..@@@@@@@@@@@@@@@@@@..@@@.@@@
	;;	...@@...@@@@@@@@@@@@@@@@@..@@...	@@.@@...@@@@@@@@@@@@@@@@@..@@.@@
	;;	....@@@@..@@@@@@@@@@@@@@@@@.@@..	@@..@@@@..@@@@@@@@@@@@@@@@@.@@.@
	;;	..@@...@@@..@@@@@@@@@@@@@@@@.@@.	@......@@@..@@@@@@@@@@@@@@@@.@@.
	;;	.@..@@...@@@..@@@@@@@@@@@@@@.@@.	.........@@@..@@@@@@@@@@@@@@.@@.
	;;	.@....@@...@@@..@@@@@@@@@.@@@.@.	...........@@@..@@@@@@@@@.@@@.@.
	;;	.@.@....@@...@@@..@@@@@..@@@@.@.	...@.........@@@..@@@@@..@@@@.@.
	;;	.@..@.@...@@...@@@.@@@.@@@@@@.@.	...............@@@.@@@.@@@@@@.@.
	;;	.@..@@@.@...@@..@@@.@@@@@@@@@.@.	................@@@.@@@@@@@@@.@.
	;;	.@.@...@@.@...@@.@@.@@@@@@@@@.@.	.................@@.@@@@@@@@@.@.
	;;	.@.@.....@@.@...@.@@.@@@@@@@@.@.	..................@@.@@@@@@@@.@.
	;;	.@..@......@@.@.@.@@.@@@@@@@@.@.	..............@...@@.@@@@@@@@.@.
	;;	.@.@.@@.....@@..@.@@.@@@@@@@@.@.	...@..............@@.@@@@@@@@.@.
	;;	..@..@.@@....@..@.@@.@@@@@@@.@..	@.................@@.@@@@@@@.@.@
	;;	..@.@..@.@@..@..@.@@.@@@@@@@.@..	@.................@@.@@@@@@@.@.@
	;;	...@@.@..@.@@@..@.@@.@@@@@@.....	@@................@@.@@@@@@...@@
	;;	.....@@.@..@....@.@@.@@@@@......	@@@...............@@.@@@@@.@@@@@
	;;	.......@@.@..@..@.@@.@@@........	@@@@@........@....@@.@@@..@@@@@@
	;;	.........@@.@..@.@@.@@..........	@@@@@@@..........@@.@@..@@@@@@@@
	;;	...........@@@.@.@@.............	@@@@@@@@@........@@...@@@@@@@@@@
	;;	..............@.@@..............	@@@@@@@@@@@.....@@.@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@.@..@@@@@@@@@@@@@@

			;; SPR_CLEARBOX EQU &53
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0E, &70, &00, &00, &3A, &5C, &00
	DEFB &00, &E6, &67, &00, &03, &9A, &59, &C0, &0E, &62, &46, &70, &39, &82, &41, &9C
	DEFB &78, &02, &40, &1E, &4E, &02, &40, &72, &73, &82, &41, &CE, &5C, &E6, &67, &3A
	DEFB &47, &39, &9C, &E2, &51, &CE, &73, &8A, &50, &73, &CE, &0A, &56, &9C, &38, &6A
	DEFB &59, &C6, &63, &9A, &57, &02, &40, &EA, &4C, &02, &40, &32, &66, &02, &40, &66
	DEFB &39, &82, &41, &9C, &0E, &62, &46, &70, &03, &9A, &59, &C0, &00, &E2, &47, &00
	DEFB &00, &3A, &5C, &00, &00, &0E, &70, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &CE, &73, &FF, &FF, &3A, &5C, &FF
	DEFB &FC, &E6, &67, &3F, &F3, &9A, &59, &CF, &CE, &62, &46, &73, &B9, &9A, &59, &9D
	DEFB &78, &7A, &5E, &1E, &4E, &7A, &5E, &72, &73, &9A, &59, &CE, &5C, &E6, &67, &3A
	DEFB &47, &39, &9C, &E2, &51, &CE, &73, &8A, &50, &73, &CE, &0A, &56, &9C, &38, &6A
	DEFB &59, &C6, &63, &9A, &57, &3A, &5C, &EA, &4C, &FA, &5F, &32, &66, &7A, &5E, &66
	DEFB &B9, &9A, &59, &9D, &CE, &62, &46, &73, &F3, &9A, &59, &CF, &FC, &E2, &47, &3F
	DEFB &FF, &3A, &5C, &FF, &FF, &CE, &73, &FF, &FF, &F3, &CF, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	............@@@..@@@............	@@@@@@@@@@..@@@..@@@..@@@@@@@@@@
	;;	..........@@@.@..@.@@@..........	@@@@@@@@..@@@.@..@.@@@..@@@@@@@@
	;;	........@@@..@@..@@..@@@........	@@@@@@..@@@..@@..@@..@@@..@@@@@@
	;;	......@@@..@@.@..@.@@..@@@......	@@@@..@@@..@@.@..@.@@..@@@..@@@@
	;;	....@@@..@@...@..@...@@..@@@....	@@..@@@..@@...@..@...@@..@@@..@@
	;;	..@@@..@@.....@..@.....@@..@@@..	@.@@@..@@..@@.@..@.@@..@@..@@@.@
	;;	.@@@@.........@..@.........@@@@.	.@@@@....@@@@.@..@.@@@@....@@@@.
	;;	.@..@@@.......@..@.......@@@..@.	.@..@@@..@@@@.@..@.@@@@..@@@..@.
	;;	.@@@..@@@.....@..@.....@@@..@@@.	.@@@..@@@..@@.@..@.@@..@@@..@@@.
	;;	.@.@@@..@@@..@@..@@..@@@..@@@.@.	.@.@@@..@@@..@@..@@..@@@..@@@.@.
	;;	.@...@@@..@@@..@@..@@@..@@@...@.	.@...@@@..@@@..@@..@@@..@@@...@.
	;;	.@.@...@@@..@@@..@@@..@@@...@.@.	.@.@...@@@..@@@..@@@..@@@...@.@.
	;;	.@.@.....@@@..@@@@..@@@.....@.@.	.@.@.....@@@..@@@@..@@@.....@.@.
	;;	.@.@.@@.@..@@@....@@@....@@.@.@.	.@.@.@@.@..@@@....@@@....@@.@.@.
	;;	.@.@@..@@@...@@..@@...@@@..@@.@.	.@.@@..@@@...@@..@@...@@@..@@.@.
	;;	.@.@.@@@......@..@......@@@.@.@.	.@.@.@@@..@@@.@..@.@@@..@@@.@.@.
	;;	.@..@@........@..@........@@..@.	.@..@@..@@@@@.@..@.@@@@@..@@..@.
	;;	.@@..@@.......@..@.......@@..@@.	.@@..@@..@@@@.@..@.@@@@..@@..@@.
	;;	..@@@..@@.....@..@.....@@..@@@..	@.@@@..@@..@@.@..@.@@..@@..@@@.@
	;;	....@@@..@@...@..@...@@..@@@....	@@..@@@..@@...@..@...@@..@@@..@@
	;;	......@@@..@@.@..@.@@..@@@......	@@@@..@@@..@@.@..@.@@..@@@..@@@@
	;;	........@@@...@..@...@@@........	@@@@@@..@@@...@..@...@@@..@@@@@@
	;;	..........@@@.@..@.@@@..........	@@@@@@@@..@@@.@..@.@@@..@@@@@@@@
	;;	............@@@..@@@............	@@@@@@@@@@..@@@..@@@..@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_STEPBOX EQU &54
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0F, &F0, &00, &00, &3F, &FC, &00
	DEFB &00, &FF, &FF, &00, &03, &FF, &FF, &C0, &0F, &FF, &FF, &F0, &3F, &FF, &FF, &FC
	DEFB &7F, &FF, &FF, &FE, &4F, &FF, &FF, &F2, &73, &FF, &FF, &CE, &5C, &FF, &FF, &3A
	DEFB &47, &3F, &FC, &E2, &51, &CF, &F3, &8A, &50, &73, &CE, &0A, &56, &9C, &38, &6A
	DEFB &59, &C6, &63, &9A, &57, &02, &40, &EA, &4C, &02, &40, &32, &66, &02, &40, &66
	DEFB &39, &82, &41, &9C, &0E, &62, &46, &70, &03, &9A, &59, &C0, &00, &E2, &47, &00
	DEFB &00, &3A, &5C, &00, &00, &0E, &70, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &CF, &F3, &FF, &FF, &3F, &FC, &FF
	DEFB &FC, &FF, &FF, &3F, &F3, &FF, &FF, &CF, &CF, &FF, &FF, &F3, &BF, &FF, &FF, &FD
	DEFB &3F, &FF, &FF, &FC, &0F, &FF, &FF, &F0, &03, &FF, &FF, &C0, &00, &FF, &FF, &00
	DEFB &00, &3F, &FC, &00, &00, &0F, &F0, &00, &00, &03, &C0, &00, &06, &00, &00, &60
	DEFB &08, &00, &00, &10, &00, &38, &1C, &00, &0C, &F8, &1F, &30, &06, &78, &1E, &60
	DEFB &81, &98, &19, &81, &C0, &60, &06, &03, &F0, &18, &18, &0F, &FC, &00, &00, &3F
	DEFB &FF, &00, &00, &FF, &FF, &C0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	............@@@@@@@@............	@@@@@@@@@@..@@@@@@@@..@@@@@@@@@@
	;;	..........@@@@@@@@@@@@..........	@@@@@@@@..@@@@@@@@@@@@..@@@@@@@@
	;;	........@@@@@@@@@@@@@@@@........	@@@@@@..@@@@@@@@@@@@@@@@..@@@@@@
	;;	......@@@@@@@@@@@@@@@@@@@@......	@@@@..@@@@@@@@@@@@@@@@@@@@..@@@@
	;;	....@@@@@@@@@@@@@@@@@@@@@@@@....	@@..@@@@@@@@@@@@@@@@@@@@@@@@..@@
	;;	..@@@@@@@@@@@@@@@@@@@@@@@@@@@@..	@.@@@@@@@@@@@@@@@@@@@@@@@@@@@@.@
	;;	.@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.	..@@@@@@@@@@@@@@@@@@@@@@@@@@@@..
	;;	.@..@@@@@@@@@@@@@@@@@@@@@@@@..@.	....@@@@@@@@@@@@@@@@@@@@@@@@....
	;;	.@@@..@@@@@@@@@@@@@@@@@@@@..@@@.	......@@@@@@@@@@@@@@@@@@@@......
	;;	.@.@@@..@@@@@@@@@@@@@@@@..@@@.@.	........@@@@@@@@@@@@@@@@........
	;;	.@...@@@..@@@@@@@@@@@@..@@@...@.	..........@@@@@@@@@@@@..........
	;;	.@.@...@@@..@@@@@@@@..@@@...@.@.	............@@@@@@@@............
	;;	.@.@.....@@@..@@@@..@@@.....@.@.	..............@@@@..............
	;;	.@.@.@@.@..@@@....@@@....@@.@.@.	.....@@..................@@.....
	;;	.@.@@..@@@...@@..@@...@@@..@@.@.	....@......................@....
	;;	.@.@.@@@......@..@......@@@.@.@.	..........@@@......@@@..........
	;;	.@..@@........@..@........@@..@.	....@@..@@@@@......@@@@@..@@....
	;;	.@@..@@.......@..@.......@@..@@.	.....@@..@@@@......@@@@..@@.....
	;;	..@@@..@@.....@..@.....@@..@@@..	@......@@..@@......@@..@@......@
	;;	....@@@..@@...@..@...@@..@@@....	@@.......@@..........@@.......@@
	;;	......@@@..@@.@..@.@@..@@@......	@@@@.......@@......@@.......@@@@
	;;	........@@@...@..@...@@@........	@@@@@@....................@@@@@@
	;;	..........@@@.@..@.@@@..........	@@@@@@@@................@@@@@@@@
	;;	............@@@..@@@............	@@@@@@@@@@............@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_LAVAPIT EQU &55
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &03, &C0, &00, &00, &1C, &38, &00
	DEFB &00, &63, &C6, &00, &01, &9F, &F9, &80, &02, &76, &BE, &40, &0D, &FA, &B7, &B0
	DEFB &13, &DB, &ED, &C8, &2B, &6C, &2A, &D4, &51, &D0, &0B, &9A, &54, &60, &06, &2A
	DEFB &55, &3C, &3C, &AA, &2A, &87, &E2, &D4, &2D, &68, &0D, &54, &55, &56, &B5, &5A
	DEFB &55, &B5, &AB, &AA, &55, &6A, &DA, &AA, &55, &6B, &5A, &B6, &6A, &AD, &5A, &AA
	DEFB &36, &AD, &55, &5C, &0D, &5A, &D5, &B0, &03, &D5, &AB, &C0, &00, &D5, &AB, &00
	DEFB &00, &3A, &AC, &00, &00, &0E, &F0, &00, &00, &03, &40, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FC, &3F, &FF, &FF, &E0, &07, &FF, &FF, &80, &01, &FF
	DEFB &FE, &03, &C0, &7F, &FC, &1F, &F8, &3F, &F0, &76, &BE, &0F, &E1, &FA, &B7, &87
	DEFB &C3, &DB, &ED, &C3, &83, &6C, &2A, &C1, &01, &D0, &0B, &80, &00, &60, &06, &00
	DEFB &00, &3C, &3C, &00, &80, &07, &E0, &01, &80, &00, &00, &01, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &80, &00, &00, &01, &C0, &00, &00, &03, &F0, &00, &00, &0F, &FC, &00, &00, &3F
	DEFB &FF, &00, &00, &FF, &FF, &C0, &03, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@..........@@@@@@@@@@@
	;;	...........@@@....@@@...........	@@@@@@@@@..............@@@@@@@@@
	;;	.........@@...@@@@...@@.........	@@@@@@@.......@@@@.......@@@@@@@
	;;	.......@@..@@@@@@@@@@..@@.......	@@@@@@.....@@@@@@@@@@.....@@@@@@
	;;	......@..@@@.@@.@.@@@@@..@......	@@@@.....@@@.@@.@.@@@@@.....@@@@
	;;	....@@.@@@@@@.@.@.@@.@@@@.@@....	@@@....@@@@@@.@.@.@@.@@@@....@@@
	;;	...@..@@@@.@@.@@@@@.@@.@@@..@...	@@....@@@@.@@.@@@@@.@@.@@@....@@
	;;	..@.@.@@.@@.@@....@.@.@.@@.@.@..	@.....@@.@@.@@....@.@.@.@@.....@
	;;	.@.@...@@@.@........@.@@@..@@.@.	.......@@@.@........@.@@@.......
	;;	.@.@.@...@@..........@@...@.@.@.	.........@@..........@@.........
	;;	.@.@.@.@..@@@@....@@@@..@.@.@.@.	..........@@@@....@@@@..........
	;;	..@.@.@.@....@@@@@@...@.@@.@.@..	@............@@@@@@............@
	;;	..@.@@.@.@@.@.......@@.@.@.@.@..	@..............................@
	;;	.@.@.@.@.@.@.@@.@.@@.@.@.@.@@.@.	................................
	;;	.@.@.@.@@.@@.@.@@.@.@.@@@.@.@.@.	................................
	;;	.@.@.@.@.@@.@.@.@@.@@.@.@.@.@.@.	................................
	;;	.@.@.@.@.@@.@.@@.@.@@.@.@.@@.@@.	................................
	;;	.@@.@.@.@.@.@@.@.@.@@.@.@.@.@.@.	................................
	;;	..@@.@@.@.@.@@.@.@.@.@.@.@.@@@..	@..............................@
	;;	....@@.@.@.@@.@.@@.@.@.@@.@@....	@@............................@@
	;;	......@@@@.@.@.@@.@.@.@@@@......	@@@@........................@@@@
	;;	........@@.@.@.@@.@.@.@@........	@@@@@@....................@@@@@@
	;;	..........@@@.@.@.@.@@..........	@@@@@@@@................@@@@@@@@
	;;	............@@@.@@@@............	@@@@@@@@@@............@@@@@@@@@@
	;;	..............@@.@..............	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_COLUMN EQU &56
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0F, &F0, &00, &00, &3F, &FC, &00
	DEFB &00, &FF, &FF, &00, &03, &FF, &FF, &C0, &0F, &FF, &FF, &F0, &3F, &FF, &FF, &FC
	DEFB &3F, &FF, &FF, &FC, &4F, &FF, &FF, &F2, &33, &FF, &FF, &CC, &1C, &FF, &FF, &38
	DEFB &07, &3F, &FC, &E0, &01, &CF, &F3, &80, &00, &73, &CE, &00, &06, &9C, &39, &60
	DEFB &1C, &E7, &E7, &38, &72, &F9, &9F, &4E, &4E, &FE, &7F, &72, &67, &7F, &FE, &E6
	DEFB &39, &9F, &F9, &9C, &0E, &63, &C6, &70, &03, &9C, &39, &C0, &00, &E7, &E7, &00
	DEFB &00, &39, &9C, &00, &00, &0E, &70, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F0, &0F, &FF, &FF, &C0, &03, &FF, &FF, &00, &00, &FF
	DEFB &FC, &00, &00, &3F, &F0, &00, &00, &0F, &C0, &00, &00, &03, &80, &00, &00, &01
	DEFB &80, &00, &00, &01, &40, &00, &00, &02, &B0, &00, &00, &0D, &DC, &00, &00, &3B
	DEFB &E7, &00, &00, &E7, &F9, &C0, &03, &9F, &F8, &70, &0E, &1F, &E6, &1C, &39, &67
	DEFB &9C, &47, &E5, &39, &70, &51, &95, &0E, &40, &54, &55, &02, &60, &55, &54, &06
	DEFB &B8, &15, &50, &1D, &CE, &01, &40, &73, &F3, &80, &01, &CF, &FC, &E0, &07, &3F
	DEFB &FF, &38, &1C, &FF, &FF, &CE, &73, &FF, &FF, &F3, &CF, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	............@@@@@@@@............	@@@@@@@@@@............@@@@@@@@@@
	;;	..........@@@@@@@@@@@@..........	@@@@@@@@................@@@@@@@@
	;;	........@@@@@@@@@@@@@@@@........	@@@@@@....................@@@@@@
	;;	......@@@@@@@@@@@@@@@@@@@@......	@@@@........................@@@@
	;;	....@@@@@@@@@@@@@@@@@@@@@@@@....	@@............................@@
	;;	..@@@@@@@@@@@@@@@@@@@@@@@@@@@@..	@..............................@
	;;	..@@@@@@@@@@@@@@@@@@@@@@@@@@@@..	@..............................@
	;;	.@..@@@@@@@@@@@@@@@@@@@@@@@@..@.	.@............................@.
	;;	..@@..@@@@@@@@@@@@@@@@@@@@..@@..	@.@@........................@@.@
	;;	...@@@..@@@@@@@@@@@@@@@@..@@@...	@@.@@@....................@@@.@@
	;;	.....@@@..@@@@@@@@@@@@..@@@.....	@@@..@@@................@@@..@@@
	;;	.......@@@..@@@@@@@@..@@@.......	@@@@@..@@@............@@@..@@@@@
	;;	.........@@@..@@@@..@@@.........	@@@@@....@@@........@@@....@@@@@
	;;	.....@@.@..@@@....@@@..@.@@.....	@@@..@@....@@@....@@@..@.@@..@@@
	;;	...@@@..@@@..@@@@@@..@@@..@@@...	@..@@@...@...@@@@@@..@.@..@@@..@
	;;	.@@@..@.@@@@@..@@..@@@@@.@..@@@.	.@@@.....@.@...@@..@.@.@....@@@.
	;;	.@..@@@.@@@@@@@..@@@@@@@.@@@..@.	.@.......@.@.@...@.@.@.@......@.
	;;	.@@..@@@.@@@@@@@@@@@@@@.@@@..@@.	.@@......@.@.@.@.@.@.@.......@@.
	;;	..@@@..@@..@@@@@@@@@@..@@..@@@..	@.@@@......@.@.@.@.@.......@@@.@
	;;	....@@@..@@...@@@@...@@..@@@....	@@..@@@........@.@.......@@@..@@
	;;	......@@@..@@@....@@@..@@@......	@@@@..@@@..............@@@..@@@@
	;;	........@@@..@@@@@@..@@@........	@@@@@@..@@@..........@@@..@@@@@@
	;;	..........@@@..@@..@@@..........	@@@@@@@@..@@@......@@@..@@@@@@@@
	;;	............@@@..@@@............	@@@@@@@@@@..@@@..@@@..@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_ECRIN EQU &57
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &03, &C0, &00, &00, &1C, &38, &00
	DEFB &00, &73, &CE, &00, &01, &CC, &33, &80, &03, &38, &1C, &C0, &0E, &F2, &0F, &70
	DEFB &1F, &38, &1C, &F8, &33, &CE, &73, &CC, &64, &F3, &CF, &26, &44, &3C, &3C, &22
	DEFB &48, &8F, &F0, &12, &29, &83, &C0, &14, &38, &01, &80, &1C, &4E, &01, &80, &72
	DEFB &33, &81, &81, &CC, &4C, &E1, &87, &32, &43, &39, &9C, &C2, &64, &CE, &73, &26
	DEFB &3A, &33, &CC, &5C, &0F, &0C, &30, &F0, &03, &83, &C1, &C0, &00, &E1, &87, &00
	DEFB &00, &3D, &BC, &00, &00, &0D, &B0, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FC, &3F, &FF, &FF, &E3, &C7, &FF, &FF, &9C, &39, &FF
	DEFB &FE, &73, &CE, &7F, &FD, &CC, &33, &BF, &F3, &38, &1C, &CF, &EE, &F0, &0F, &77
	DEFB &DF, &38, &1C, &FB, &B3, &CE, &73, &CD, &60, &F3, &CF, &06, &50, &3C, &3C, &0A
	DEFB &40, &0F, &F0, &02, &A0, &03, &C0, &05, &B8, &01, &80, &1D, &4E, &01, &80, &72
	DEFB &33, &81, &81, &CC, &4C, &E1, &87, &32, &53, &39, &9C, &CA, &60, &CE, &73, &06
	DEFB &B8, &33, &CC, &1D, &CE, &0C, &30, &73, &F3, &83, &C1, &CF, &FC, &E1, &87, &3F
	DEFB &FF, &3D, &BC, &FF, &FF, &CD, &B3, &FF, &FF, &F3, &CF, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@...@@@@...@@@@@@@@@@@
	;;	...........@@@....@@@...........	@@@@@@@@@..@@@....@@@..@@@@@@@@@
	;;	.........@@@..@@@@..@@@.........	@@@@@@@..@@@..@@@@..@@@..@@@@@@@
	;;	.......@@@..@@....@@..@@@.......	@@@@@@.@@@..@@....@@..@@@.@@@@@@
	;;	......@@..@@@......@@@..@@......	@@@@..@@..@@@......@@@..@@..@@@@
	;;	....@@@.@@@@..@.....@@@@.@@@....	@@@.@@@.@@@@........@@@@.@@@.@@@
	;;	...@@@@@..@@@......@@@..@@@@@...	@@.@@@@@..@@@......@@@..@@@@@.@@
	;;	..@@..@@@@..@@@..@@@..@@@@..@@..	@.@@..@@@@..@@@..@@@..@@@@..@@.@
	;;	.@@..@..@@@@..@@@@..@@@@..@..@@.	.@@.....@@@@..@@@@..@@@@.....@@.
	;;	.@...@....@@@@....@@@@....@...@.	.@.@......@@@@....@@@@......@.@.
	;;	.@..@...@...@@@@@@@@.......@..@.	.@..........@@@@@@@@..........@.
	;;	..@.@..@@.....@@@@.........@.@..	@.@...........@@@@...........@.@
	;;	..@@@..........@@..........@@@..	@.@@@..........@@..........@@@.@
	;;	.@..@@@........@@........@@@..@.	.@..@@@........@@........@@@..@.
	;;	..@@..@@@......@@......@@@..@@..	..@@..@@@......@@......@@@..@@..
	;;	.@..@@..@@@....@@....@@@..@@..@.	.@..@@..@@@....@@....@@@..@@..@.
	;;	.@....@@..@@@..@@..@@@..@@....@.	.@.@..@@..@@@..@@..@@@..@@..@.@.
	;;	.@@..@..@@..@@@..@@@..@@..@..@@.	.@@.....@@..@@@..@@@..@@.....@@.
	;;	..@@@.@...@@..@@@@..@@...@.@@@..	@.@@@.....@@..@@@@..@@.....@@@.@
	;;	....@@@@....@@....@@....@@@@....	@@..@@@.....@@....@@.....@@@..@@
	;;	......@@@.....@@@@.....@@@......	@@@@..@@@.....@@@@.....@@@..@@@@
	;;	........@@@....@@....@@@........	@@@@@@..@@@....@@....@@@..@@@@@@
	;;	..........@@@@.@@.@@@@..........	@@@@@@@@..@@@@.@@.@@@@..@@@@@@@@
	;;	............@@.@@.@@............	@@@@@@@@@@..@@.@@.@@..@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_BOX EQU &58
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &02, &40, &00, &00, &0F, &F0, &00
	DEFB &00, &3A, &5C, &00, &00, &E9, &97, &00, &03, &A7, &E5, &C0, &0E, &9F, &F9, &70
	DEFB &3A, &7F, &FE, &5C, &71, &FF, &FF, &8E, &7C, &FF, &FF, &3E, &3F, &3F, &FC, &FC
	DEFB &2F, &CF, &F3, &F4, &13, &F3, &CF, &C8, &14, &FC, &3F, &28, &09, &3E, &7C, &90
	DEFB &0A, &4F, &F2, &50, &0A, &93, &C9, &50, &1A, &A4, &25, &58, &33, &55, &AA, &CC
	DEFB &26, &D5, &AB, &64, &19, &B5, &AD, &98, &06, &6D, &B6, &60, &01, &9B, &D9, &80
	DEFB &00, &66, &66, &00, &00, &19, &98, &00, &00, &06, &60, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FD, &BF, &FF, &FF, &F2, &4F, &FF, &FF, &CF, &F3, &FF
	DEFB &FF, &3A, &5C, &FF, &FC, &E9, &17, &3F, &F3, &A2, &A5, &CF, &CE, &95, &51, &73
	DEFB &BA, &2A, &AA, &5D, &71, &55, &55, &0E, &7C, &AA, &AA, &3E, &BF, &15, &54, &FD
	DEFB &AF, &CA, &A3, &F5, &D3, &F1, &4F, &CB, &D0, &FC, &3F, &0B, &E8, &3E, &7C, &17
	DEFB &E8, &0F, &F0, &17, &E8, &03, &C0, &17, &D8, &00, &00, &1B, &B3, &01, &80, &CD
	DEFB &A6, &C1, &83, &65, &D9, &B1, &8D, &9B, &E6, &6D, &B6, &67, &F9, &9B, &D9, &9F
	DEFB &FE, &66, &66, &7F, &FF, &99, &99, &FF, &FF, &E6, &67, &FF, &FF, &F9, &9F, &FF
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@.@@.@@@@@@@@@@@@@@
	;;	..............@..@..............	@@@@@@@@@@@@..@..@..@@@@@@@@@@@@
	;;	............@@@@@@@@............	@@@@@@@@@@..@@@@@@@@..@@@@@@@@@@
	;;	..........@@@.@..@.@@@..........	@@@@@@@@..@@@.@..@.@@@..@@@@@@@@
	;;	........@@@.@..@@..@.@@@........	@@@@@@..@@@.@..@...@.@@@..@@@@@@
	;;	......@@@.@..@@@@@@..@.@@@......	@@@@..@@@.@...@.@.@..@.@@@..@@@@
	;;	....@@@.@..@@@@@@@@@@..@.@@@....	@@..@@@.@..@.@.@.@.@...@.@@@..@@
	;;	..@@@.@..@@@@@@@@@@@@@@..@.@@@..	@.@@@.@...@.@.@.@.@.@.@..@.@@@.@
	;;	.@@@...@@@@@@@@@@@@@@@@@@...@@@.	.@@@...@.@.@.@.@.@.@.@.@....@@@.
	;;	.@@@@@..@@@@@@@@@@@@@@@@..@@@@@.	.@@@@@..@.@.@.@.@.@.@.@...@@@@@.
	;;	..@@@@@@..@@@@@@@@@@@@..@@@@@@..	@.@@@@@@...@.@.@.@.@.@..@@@@@@.@
	;;	..@.@@@@@@..@@@@@@@@..@@@@@@.@..	@.@.@@@@@@..@.@.@.@...@@@@@@.@.@
	;;	...@..@@@@@@..@@@@..@@@@@@..@...	@@.@..@@@@@@...@.@..@@@@@@..@.@@
	;;	...@.@..@@@@@@....@@@@@@..@.@...	@@.@....@@@@@@....@@@@@@....@.@@
	;;	....@..@..@@@@@..@@@@@..@..@....	@@@.@.....@@@@@..@@@@@.....@.@@@
	;;	....@.@..@..@@@@@@@@..@..@.@....	@@@.@.......@@@@@@@@.......@.@@@
	;;	....@.@.@..@..@@@@..@..@.@.@....	@@@.@.........@@@@.........@.@@@
	;;	...@@.@.@.@..@....@..@.@.@.@@...	@@.@@......................@@.@@
	;;	..@@..@@.@.@.@.@@.@.@.@.@@..@@..	@.@@..@@.......@@.......@@..@@.@
	;;	..@..@@.@@.@.@.@@.@.@.@@.@@..@..	@.@..@@.@@.....@@.....@@.@@..@.@
	;;	...@@..@@.@@.@.@@.@.@@.@@..@@...	@@.@@..@@.@@...@@...@@.@@..@@.@@
	;;	.....@@..@@.@@.@@.@@.@@..@@.....	@@@..@@..@@.@@.@@.@@.@@..@@..@@@
	;;	.......@@..@@.@@@@.@@..@@.......	@@@@@..@@..@@.@@@@.@@..@@..@@@@@
	;;	.........@@..@@..@@..@@.........	@@@@@@@..@@..@@..@@..@@..@@@@@@@
	;;	...........@@..@@..@@...........	@@@@@@@@@..@@..@@..@@..@@@@@@@@@
	;;	.............@@..@@.............	@@@@@@@@@@@..@@..@@..@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@..@@..@@@@@@@@@@@@@

			;; SPR_Z_CUSHION EQU &59
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0F, &F0, &00, &00, &03, &FC, &00
	DEFB &00, &08, &FF, &00, &00, &0A, &3F, &C0, &00, &00, &0F, &F0, &1F, &FF, &FF, &FC
	DEFB &3F, &FF, &FF, &FA, &4F, &F0, &00, &06, &63, &FC, &AA, &A6, &58, &FF, &15, &56
	DEFB &76, &3F, &C5, &56, &6D, &8F, &F2, &A6, &5B, &63, &C9, &56, &76, &D8, &39, &56
	DEFB &6D, &B6, &7A, &A6, &5B, &6E, &79, &56, &76, &DA, &79, &56, &6D, &B6, &7A, &A6
	DEFB &3B, &6E, &79, &54, &0E, &DA, &78, &00, &03, &B6, &78, &00, &00, &EE, &78, &00
	DEFB &00, &3A, &78, &00, &00, &0E, &70, &00, &00, &02, &40, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &EF, &F3, &FF, &FF, &E3, &FC, &FF
	DEFB &FF, &E0, &FF, &3F, &FF, &E0, &3F, &CF, &E0, &00, &0F, &F3, &DF, &FF, &FF, &FC
	DEFB &BF, &FF, &FF, &FA, &0F, &F0, &00, &04, &03, &FC, &00, &02, &00, &FF, &00, &04
	DEFB &00, &3F, &C0, &02, &00, &0F, &F0, &04, &00, &03, &C8, &02, &00, &00, &10, &04
	DEFB &00, &00, &28, &02, &00, &00, &50, &04, &00, &00, &28, &02, &00, &00, &50, &04
	DEFB &80, &00, &28, &01, &C0, &00, &50, &03, &F0, &00, &2B, &FF, &FC, &00, &53, &FF
	DEFB &FF, &00, &2B, &FF, &FF, &C0, &57, &FF, &FF, &F0, &0F, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	............@@@@@@@@............	@@@@@@@@@@@.@@@@@@@@..@@@@@@@@@@
	;;	..............@@@@@@@@..........	@@@@@@@@@@@...@@@@@@@@..@@@@@@@@
	;;	............@...@@@@@@@@........	@@@@@@@@@@@.....@@@@@@@@..@@@@@@
	;;	............@.@...@@@@@@@@......	@@@@@@@@@@@.......@@@@@@@@..@@@@
	;;	....................@@@@@@@@....	@@@.................@@@@@@@@..@@
	;;	...@@@@@@@@@@@@@@@@@@@@@@@@@@@..	@@.@@@@@@@@@@@@@@@@@@@@@@@@@@@..
	;;	..@@@@@@@@@@@@@@@@@@@@@@@@@@@.@.	@.@@@@@@@@@@@@@@@@@@@@@@@@@@@.@.
	;;	.@..@@@@@@@@.................@@.	....@@@@@@@@.................@..
	;;	.@@...@@@@@@@@..@.@.@.@.@.@..@@.	......@@@@@@@@................@.
	;;	.@.@@...@@@@@@@@...@.@.@.@.@.@@.	........@@@@@@@@.............@..
	;;	.@@@.@@...@@@@@@@@...@.@.@.@.@@.	..........@@@@@@@@............@.
	;;	.@@.@@.@@...@@@@@@@@..@.@.@..@@.	............@@@@@@@@.........@..
	;;	.@.@@.@@.@@...@@@@..@..@.@.@.@@.	..............@@@@..@.........@.
	;;	.@@@.@@.@@.@@.....@@@..@.@.@.@@.	...................@.........@..
	;;	.@@.@@.@@.@@.@@..@@@@.@.@.@..@@.	..................@.@.........@.
	;;	.@.@@.@@.@@.@@@..@@@@..@.@.@.@@.	.................@.@.........@..
	;;	.@@@.@@.@@.@@.@..@@@@..@.@.@.@@.	..................@.@.........@.
	;;	.@@.@@.@@.@@.@@..@@@@.@.@.@..@@.	.................@.@.........@..
	;;	..@@@.@@.@@.@@@..@@@@..@.@.@.@..	@.................@.@..........@
	;;	....@@@.@@.@@.@..@@@@...........	@@...............@.@..........@@
	;;	......@@@.@@.@@..@@@@...........	@@@@..............@.@.@@@@@@@@@@
	;;	........@@@.@@@..@@@@...........	@@@@@@...........@.@..@@@@@@@@@@
	;;	..........@@@.@..@@@@...........	@@@@@@@@..........@.@.@@@@@@@@@@
	;;	............@@@..@@@............	@@@@@@@@@@.......@.@.@@@@@@@@@@@
	;;	..............@..@..............	@@@@@@@@@@@@........@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_TURTLE EQU &5A
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &07, &E0, &00, &00, &38, &1C, &00
	DEFB &00, &C3, &C3, &00, &01, &37, &EC, &80, &02, &63, &C6, &40, &05, &9D, &B9, &A0
	DEFB &05, &BC, &3D, &A0, &0B, &BD, &BD, &D0, &09, &5B, &DA, &90, &14, &E3, &C7, &28
	DEFB &2E, &F1, &8F, &74, &5E, &6E, &76, &7A, &69, &9E, &79, &96, &33, &D8, &1B, &CC
	DEFB &18, &D7, &EB, &18, &0E, &0F, &F0, &70, &17, &FC, &3F, &E8, &39, &F3, &CF, &9C
	DEFB &5E, &0F, &F0, &7A, &24, &31, &8C, &24, &08, &25, &A4, &10, &00, &1B, &D8, &00
	DEFB &00, &0F, &F0, &00, &00, &07, &E0, &00, &00, &01, &80, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &F8, &1F, &FF, &FF, &C0, &03, &FF, &FF, &00, &00, &FF
	DEFB &FE, &00, &00, &7F, &FC, &00, &00, &3F, &F8, &00, &00, &1F, &F0, &00, &00, &0F
	DEFB &F0, &00, &00, &0F, &E0, &00, &00, &07, &E0, &00, &00, &07, &C0, &00, &00, &03
	DEFB &80, &00, &00, &01, &00, &00, &00, &00, &00, &00, &00, &00, &80, &00, &00, &01
	DEFB &C0, &00, &00, &03, &E0, &00, &00, &07, &D0, &00, &00, &0B, &B8, &03, &C0, &1D
	DEFB &5E, &0F, &F0, &7A, &A5, &B1, &8D, &A5, &CB, &A1, &85, &D3, &F7, &DB, &DB, &EF
	DEFB &FF, &EF, &F7, &FF, &FF, &F7, &EF, &FF, &FF, &F9, &9F, &FF, &FF, &FE, &7F, &FF
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@......@@@@@@@@@@@@@
	;;	.............@@@@@@.............	@@@@@@@@@@............@@@@@@@@@@
	;;	..........@@@......@@@..........	@@@@@@@@................@@@@@@@@
	;;	........@@....@@@@....@@........	@@@@@@@..................@@@@@@@
	;;	.......@..@@.@@@@@@.@@..@.......	@@@@@@....................@@@@@@
	;;	......@..@@...@@@@...@@..@......	@@@@@......................@@@@@
	;;	.....@.@@..@@@.@@.@@@..@@.@.....	@@@@........................@@@@
	;;	.....@.@@.@@@@....@@@@.@@.@.....	@@@@........................@@@@
	;;	....@.@@@.@@@@.@@.@@@@.@@@.@....	@@@..........................@@@
	;;	....@..@.@.@@.@@@@.@@.@.@..@....	@@@..........................@@@
	;;	...@.@..@@@...@@@@...@@@..@.@...	@@............................@@
	;;	..@.@@@.@@@@...@@...@@@@.@@@.@..	@..............................@
	;;	.@.@@@@..@@.@@@..@@@.@@..@@@@.@.	................................
	;;	.@@.@..@@..@@@@..@@@@..@@..@.@@.	................................
	;;	..@@..@@@@.@@......@@.@@@@..@@..	@..............................@
	;;	...@@...@@.@.@@@@@@.@.@@...@@...	@@............................@@
	;;	....@@@.....@@@@@@@@.....@@@....	@@@..........................@@@
	;;	...@.@@@@@@@@@....@@@@@@@@@.@...	@@.@........................@.@@
	;;	..@@@..@@@@@..@@@@..@@@@@..@@@..	@.@@@.........@@@@.........@@@.@
	;;	.@.@@@@.....@@@@@@@@.....@@@@.@.	.@.@@@@.....@@@@@@@@.....@@@@.@.
	;;	..@..@....@@...@@...@@....@..@..	@.@..@.@@.@@...@@...@@.@@.@..@.@
	;;	....@.....@..@.@@.@..@.....@....	@@..@.@@@.@....@@....@.@@@.@..@@
	;;	...........@@.@@@@.@@...........	@@@@.@@@@@.@@.@@@@.@@.@@@@@.@@@@
	;;	............@@@@@@@@............	@@@@@@@@@@@.@@@@@@@@.@@@@@@@@@@@
	;;	.............@@@@@@.............	@@@@@@@@@@@@.@@@@@@.@@@@@@@@@@@@
	;;	...............@@...............	@@@@@@@@@@@@@..@@..@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@..@@@@@@@@@@@@@@@

			;; SPR_TABLE EQU &5B
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0E, &70, &00, &00, &39, &1C, &00
	DEFB &00, &E2, &A7, &00, &03, &8A, &A9, &C0, &0E, &55, &54, &70, &39, &55, &55, &1C
	DEFB &78, &AA, &AA, &9E, &4E, &2A, &AA, &72, &73, &95, &51, &CE, &1C, &E5, &47, &38
	DEFB &07, &38, &9C, &E0, &01, &CE, &73, &80, &1A, &73, &CE, &58, &37, &9C, &39, &EC
	DEFB &2F, &E7, &E7, &F4, &6F, &D8, &1B, &F6, &6E, &1B, &D8, &76, &70, &06, &60, &0E
	DEFB &00, &05, &A0, &00, &00, &05, &A0, &00, &00, &05, &A0, &00, &00, &03, &C0, &00
	DEFB &00, &03, &C0, &00, &00, &03, &C0, &00, &00, &01, &80, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &CE, &73, &FF, &FF, &38, &1C, &FF
	DEFB &FC, &E0, &07, &3F, &F3, &80, &01, &CF, &CE, &00, &00, &73, &B8, &00, &00, &1D
	DEFB &78, &00, &00, &1E, &4E, &00, &00, &72, &73, &80, &01, &CE, &9C, &E0, &07, &39
	DEFB &E7, &38, &1C, &E7, &E1, &CE, &73, &87, &D8, &73, &CE, &1B, &B0, &1C, &38, &0D
	DEFB &A0, &07, &E0, &05, &60, &00, &00, &06, &60, &00, &00, &06, &71, &E0, &07, &8E
	DEFB &8F, &F1, &8F, &F1, &FF, &F1, &8F, &FF, &FF, &F1, &8F, &FF, &FF, &FB, &DF, &FF
	DEFB &FF, &FB, &DF, &FF, &FF, &FB, &DF, &FF, &FF, &FD, &BF, &FF, &FF, &FE, &7F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	............@@@..@@@............	@@@@@@@@@@..@@@..@@@..@@@@@@@@@@
	;;	..........@@@..@...@@@..........	@@@@@@@@..@@@......@@@..@@@@@@@@
	;;	........@@@...@.@.@..@@@........	@@@@@@..@@@..........@@@..@@@@@@
	;;	......@@@...@.@.@.@.@..@@@......	@@@@..@@@..............@@@..@@@@
	;;	....@@@..@.@.@.@.@.@.@...@@@....	@@..@@@..................@@@..@@
	;;	..@@@..@.@.@.@.@.@.@.@.@...@@@..	@.@@@......................@@@.@
	;;	.@@@@...@.@.@.@.@.@.@.@.@..@@@@.	.@@@@......................@@@@.
	;;	.@..@@@...@.@.@.@.@.@.@..@@@..@.	.@..@@@..................@@@..@.
	;;	.@@@..@@@..@.@.@.@.@...@@@..@@@.	.@@@..@@@..............@@@..@@@.
	;;	...@@@..@@@..@.@.@...@@@..@@@...	@..@@@..@@@..........@@@..@@@..@
	;;	.....@@@..@@@...@..@@@..@@@.....	@@@..@@@..@@@......@@@..@@@..@@@
	;;	.......@@@..@@@..@@@..@@@.......	@@@....@@@..@@@..@@@..@@@....@@@
	;;	...@@.@..@@@..@@@@..@@@..@.@@...	@@.@@....@@@..@@@@..@@@....@@.@@
	;;	..@@.@@@@..@@@....@@@..@@@@.@@..	@.@@.......@@@....@@@.......@@.@
	;;	..@.@@@@@@@..@@@@@@..@@@@@@@.@..	@.@..........@@@@@@..........@.@
	;;	.@@.@@@@@@.@@......@@.@@@@@@.@@.	.@@..........................@@.
	;;	.@@.@@@....@@.@@@@.@@....@@@.@@.	.@@..........................@@.
	;;	.@@@.........@@..@@.........@@@.	.@@@...@@@@..........@@@@...@@@.
	;;	.............@.@@.@.............	@...@@@@@@@@...@@...@@@@@@@@...@
	;;	.............@.@@.@.............	@@@@@@@@@@@@...@@...@@@@@@@@@@@@
	;;	.............@.@@.@.............	@@@@@@@@@@@@...@@...@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@@.@@@@.@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@@.@@@@.@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@@.@@@@.@@@@@@@@@@@@@
	;;	...............@@...............	@@@@@@@@@@@@@@.@@.@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@..@@@@@@@@@@@@@@@

			;; SPR_CRATE EQU &5C
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &0D, &B0, &00, &00, &32, &4C, &00
	DEFB &00, &C5, &1B, &00, &03, &2A, &66, &C0, &0C, &51, &99, &B0, &32, &A6, &66, &0C
	DEFB &55, &19, &99, &5A, &62, &66, &62, &86, &5D, &99, &95, &3A, &4F, &66, &28, &F2
	DEFB &33, &D9, &53, &CC, &4C, &F2, &8F, &32, &63, &3E, &7C, &CA, &48, &CD, &B3, &12
	DEFB &4C, &33, &4C, &AA, &6C, &0F, &71, &52, &4E, &33, &CA, &AA, &67, &B4, &15, &56
	DEFB &31, &F1, &AA, &8C, &0C, &61, &95, &30, &03, &01, &A8, &C0, &00, &C5, &93, &00
	DEFB &00, &33, &4C, &00, &00, &0F, &70, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &F3, &CF, &FF, &FF, &C1, &83, &FF, &FF, &00, &00, &FF
	DEFB &FC, &00, &00, &3F, &F0, &00, &00, &0F, &C0, &00, &00, &03, &B0, &00, &00, &0D
	DEFB &50, &00, &00, &0A, &60, &00, &00, &06, &40, &00, &00, &02, &40, &00, &00, &02
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &08, &01, &80, &00
	DEFB &0C, &03, &40, &00, &0C, &07, &60, &00, &4E, &33, &C0, &02, &67, &B0, &00, &06
	DEFB &81, &F0, &00, &01, &C0, &60, &00, &03, &F0, &00, &00, &0F, &FC, &01, &80, &3F
	DEFB &FF, &03, &40, &FF, &FF, &C7, &63, &FF, &FF, &F3, &CF, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	............@@.@@.@@............	@@@@@@@@@@.....@@.....@@@@@@@@@@
	;;	..........@@..@..@..@@..........	@@@@@@@@................@@@@@@@@
	;;	........@@...@.@...@@.@@........	@@@@@@....................@@@@@@
	;;	......@@..@.@.@..@@..@@.@@......	@@@@........................@@@@
	;;	....@@...@.@...@@..@@..@@.@@....	@@............................@@
	;;	..@@..@.@.@..@@..@@..@@.....@@..	@.@@........................@@.@
	;;	.@.@.@.@...@@..@@..@@..@.@.@@.@.	.@.@........................@.@.
	;;	.@@...@..@@..@@..@@...@.@....@@.	.@@..........................@@.
	;;	.@.@@@.@@..@@..@@..@.@.@..@@@.@.	.@............................@.
	;;	.@..@@@@.@@..@@...@.@...@@@@..@.	.@............................@.
	;;	..@@..@@@@.@@..@.@.@..@@@@..@@..	................................
	;;	.@..@@..@@@@..@.@...@@@@..@@..@.	................................
	;;	.@@...@@..@@@@@..@@@@@..@@..@.@.	................................
	;;	.@..@...@@..@@.@@.@@..@@...@..@.	....@..........@@...............
	;;	.@..@@....@@..@@.@..@@..@.@.@.@.	....@@........@@.@..............
	;;	.@@.@@......@@@@.@@@...@.@.@..@.	....@@.......@@@.@@.............
	;;	.@..@@@...@@..@@@@..@.@.@.@.@.@.	.@..@@@...@@..@@@@............@.
	;;	.@@..@@@@.@@.@.....@.@.@.@.@.@@.	.@@..@@@@.@@.................@@.
	;;	..@@...@@@@@...@@.@.@.@.@...@@..	@......@@@@@...................@
	;;	....@@...@@....@@..@.@.@..@@....	@@.......@@...................@@
	;;	......@@.......@@.@.@...@@......	@@@@........................@@@@
	;;	........@@...@.@@..@..@@........	@@@@@@.........@@.........@@@@@@
	;;	..........@@..@@.@..@@..........	@@@@@@@@......@@.@......@@@@@@@@
	;;	............@@@@.@@@............	@@@@@@@@@@...@@@.@@...@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@..@@@@..@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_TARBOX EQU &5D
	DEFB &00, &00, &00, &00, &00, &03, &C0, &00, &00, &07, &E0, &00, &00, &34, &2C, &00
	DEFB &00, &60, &06, &00, &03, &86, &01, &C0, &07, &10, &00, &E0, &3A, &38, &00, &5C
	DEFB &7C, &60, &00, &3E, &7C, &40, &00, &3E, &7B, &00, &00, &DE, &77, &80, &01, &EE
	DEFB &37, &F0, &0F, &EC, &3B, &FB, &DF, &DC, &38, &77, &EE, &1C, &39, &37, &EC, &9C
	DEFB &39, &07, &E0, &9C, &7D, &83, &C1, &BE, &7C, &83, &81, &3E, &7B, &23, &C4, &DE
	DEFB &37, &83, &C1, &EC, &07, &F3, &CF, &E0, &03, &FB, &DF, &C0, &00, &77, &EE, &00
	DEFB &00, &37, &EC, &00, &00, &07, &E0, &00, &00, &03, &C0, &00, &00, &00, &00, &00
	DEFB &FF, &FC, &3F, &FF, &FF, &FB, &DF, &FF, &FF, &C7, &E3, &FF, &FF, &B4, &2D, &FF
	DEFB &FC, &60, &06, &3F, &FB, &80, &01, &DF, &C7, &00, &00, &E3, &BA, &00, &00, &5D
	DEFB &7C, &00, &00, &3E, &7C, &00, &00, &3E, &7B, &00, &00, &DE, &77, &80, &01, &EE
	DEFB &B7, &F0, &0F, &ED, &BB, &FB, &DF, &DD, &B8, &77, &EE, &1D, &B8, &37, &EC, &1D
	DEFB &B8, &07, &E0, &1D, &7C, &03, &C0, &3E, &7C, &03, &80, &3E, &7B, &03, &C0, &DE
	DEFB &B7, &83, &C1, &ED, &C7, &F3, &CF, &E3, &FB, &FB, &DF, &DF, &FC, &77, &EE, &3F
	DEFB &FF, &B7, &ED, &FF, &FF, &C7, &E3, &FF, &FF, &FB, &DF, &FF, &FF, &FC, &3F, &FF
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@@.@@@@.@@@@@@@@@@@@@
	;;	.............@@@@@@.............	@@@@@@@@@@...@@@@@@...@@@@@@@@@@
	;;	..........@@.@....@.@@..........	@@@@@@@@@.@@.@....@.@@.@@@@@@@@@
	;;	.........@@..........@@.........	@@@@@@...@@..........@@...@@@@@@
	;;	......@@@....@@........@@@......	@@@@@.@@@..............@@@.@@@@@
	;;	.....@@@...@............@@@.....	@@...@@@................@@@...@@
	;;	..@@@.@...@@@............@.@@@..	@.@@@.@..................@.@@@.@
	;;	.@@@@@...@@...............@@@@@.	.@@@@@....................@@@@@.
	;;	.@@@@@...@................@@@@@.	.@@@@@....................@@@@@.
	;;	.@@@@.@@................@@.@@@@.	.@@@@.@@................@@.@@@@.
	;;	.@@@.@@@@..............@@@@.@@@.	.@@@.@@@@..............@@@@.@@@.
	;;	..@@.@@@@@@@........@@@@@@@.@@..	@.@@.@@@@@@@........@@@@@@@.@@.@
	;;	..@@@.@@@@@@@.@@@@.@@@@@@@.@@@..	@.@@@.@@@@@@@.@@@@.@@@@@@@.@@@.@
	;;	..@@@....@@@.@@@@@@.@@@....@@@..	@.@@@....@@@.@@@@@@.@@@....@@@.@
	;;	..@@@..@..@@.@@@@@@.@@..@..@@@..	@.@@@.....@@.@@@@@@.@@.....@@@.@
	;;	..@@@..@.....@@@@@@.....@..@@@..	@.@@@........@@@@@@........@@@.@
	;;	.@@@@@.@@.....@@@@.....@@.@@@@@.	.@@@@@........@@@@........@@@@@.
	;;	.@@@@@..@.....@@@......@..@@@@@.	.@@@@@........@@@.........@@@@@.
	;;	.@@@@.@@..@...@@@@...@..@@.@@@@.	.@@@@.@@......@@@@......@@.@@@@.
	;;	..@@.@@@@.....@@@@.....@@@@.@@..	@.@@.@@@@.....@@@@.....@@@@.@@.@
	;;	.....@@@@@@@..@@@@..@@@@@@@.....	@@...@@@@@@@..@@@@..@@@@@@@...@@
	;;	......@@@@@@@.@@@@.@@@@@@@......	@@@@@.@@@@@@@.@@@@.@@@@@@@.@@@@@
	;;	.........@@@.@@@@@@.@@@.........	@@@@@@...@@@.@@@@@@.@@@...@@@@@@
	;;	..........@@.@@@@@@.@@..........	@@@@@@@@@.@@.@@@@@@.@@.@@@@@@@@@
	;;	.............@@@@@@.............	@@@@@@@@@@...@@@@@@...@@@@@@@@@@
	;;	..............@@@@..............	@@@@@@@@@@@@@.@@@@.@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@....@@@@@@@@@@@@@@

			;; SPR_DSPIKES EQU &5E
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &06, &00
	DEFB &00, &00, &19, &80, &00, &00, &77, &00, &00, &01, &9C, &80, &00, &07, &73, &80
	DEFB &00, &19, &CF, &00, &00, &77, &3C, &00, &01, &9C, &F3, &00, &03, &73, &CB, &00
	DEFB &04, &CF, &37, &00, &05, &3C, &B6, &00, &07, &73, &76, &00, &03, &4B, &6E, &00
	DEFB &00, &37, &64, &00, &01, &B6, &E4, &00, &01, &F6, &40, &00, &00, &EE, &40, &00
	DEFB &00, &E4, &00, &00, &00, &E4, &00, &00, &00, &40, &00, &00, &00, &40, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &F9, &FF, &FF, &FF, &E0, &7F
	DEFB &FF, &FF, &80, &3F, &FF, &FE, &00, &7F, &FF, &F8, &00, &3F, &FF, &E0, &00, &3F
	DEFB &FF, &80, &00, &7F, &FE, &00, &00, &FF, &FC, &00, &03, &7F, &F8, &00, &0B, &7F
	DEFB &F0, &00, &37, &7F, &F0, &00, &B6, &FF, &F0, &03, &76, &FF, &F8, &0B, &6E, &FF
	DEFB &FC, &37, &65, &FF, &FD, &B6, &E5, &FF, &FD, &F6, &5B, &FF, &FE, &EE, &5F, &FF
	DEFB &FE, &E5, &BF, &FF, &FE, &E5, &FF, &FF, &FF, &5B, &FF, &FF, &FF, &5F, &FF, &FF
	DEFB &FF, &BF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@..@@@@@@@@@
	;;	.....................@@.........	@@@@@@@@@@@@@@@@@@@......@@@@@@@
	;;	...................@@..@@.......	@@@@@@@@@@@@@@@@@.........@@@@@@
	;;	.................@@@.@@@........	@@@@@@@@@@@@@@@..........@@@@@@@
	;;	...............@@..@@@..@.......	@@@@@@@@@@@@@.............@@@@@@
	;;	.............@@@.@@@..@@@.......	@@@@@@@@@@@...............@@@@@@
	;;	...........@@..@@@..@@@@........	@@@@@@@@@................@@@@@@@
	;;	.........@@@.@@@..@@@@..........	@@@@@@@.................@@@@@@@@
	;;	.......@@..@@@..@@@@..@@........	@@@@@@................@@.@@@@@@@
	;;	......@@.@@@..@@@@..@.@@........	@@@@@...............@.@@.@@@@@@@
	;;	.....@..@@..@@@@..@@.@@@........	@@@@..............@@.@@@.@@@@@@@
	;;	.....@.@..@@@@..@.@@.@@.........	@@@@............@.@@.@@.@@@@@@@@
	;;	.....@@@.@@@..@@.@@@.@@.........	@@@@..........@@.@@@.@@.@@@@@@@@
	;;	......@@.@..@.@@.@@.@@@.........	@@@@@.......@.@@.@@.@@@.@@@@@@@@
	;;	..........@@.@@@.@@..@..........	@@@@@@....@@.@@@.@@..@.@@@@@@@@@
	;;	.......@@.@@.@@.@@@..@..........	@@@@@@.@@.@@.@@.@@@..@.@@@@@@@@@
	;;	.......@@@@@.@@..@..............	@@@@@@.@@@@@.@@..@.@@.@@@@@@@@@@
	;;	........@@@.@@@..@..............	@@@@@@@.@@@.@@@..@.@@@@@@@@@@@@@
	;;	........@@@..@..................	@@@@@@@.@@@..@.@@.@@@@@@@@@@@@@@
	;;	........@@@..@..................	@@@@@@@.@@@..@.@@@@@@@@@@@@@@@@@
	;;	.........@......................	@@@@@@@@.@.@@.@@@@@@@@@@@@@@@@@@
	;;	.........@......................	@@@@@@@@.@.@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@.@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

			;; SPR_BRICKW EQU &5F
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &1C, &00
	DEFB &00, &00, &7F, &00, &00, &01, &FF, &C0, &00, &03, &FF, &00, &00, &1C, &FC, &C0
	DEFB &00, &7F, &33, &C0, &01, &FF, &CF, &C0, &07, &FF, &1F, &C0, &01, &FC, &DF, &80
	DEFB &06, &73, &DE, &40, &07, &8F, &D9, &C0, &07, &DF, &C5, &C0, &07, &DF, &9D, &C0
	DEFB &01, &DE, &7D, &C0, &06, &59, &FD, &80, &07, &85, &FC, &00, &07, &DD, &F8, &00
	DEFB &07, &DD, &E0, &00, &07, &DD, &80, &00, &01, &DC, &00, &00, &00, &58, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &E3, &FF, &FF, &FF, &80, &FF
	DEFB &FF, &FE, &00, &3F, &FF, &FC, &00, &1F, &FF, &E0, &00, &3F, &FF, &80, &00, &DF
	DEFB &FE, &00, &03, &DF, &F8, &00, &0F, &DF, &F0, &00, &1F, &DF, &F8, &00, &DF, &BF
	DEFB &F6, &03, &DE, &5F, &F7, &8F, &D9, &DF, &F7, &DF, &C5, &DF, &F7, &DF, &9D, &DF
	DEFB &F9, &DE, &7D, &DF, &F6, &59, &FD, &BF, &F7, &85, &FC, &7F, &F7, &DD, &FB, &FF
	DEFB &F7, &DD, &E7, &FF, &F7, &DD, &9F, &FF, &F9, &DC, &7F, &FF, &FE, &5B, &FF, &FF
	DEFB &FF, &A7, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@...@@@@@@@@@@
	;;	...................@@@..........	@@@@@@@@@@@@@@@@@.......@@@@@@@@
	;;	.................@@@@@@@........	@@@@@@@@@@@@@@@...........@@@@@@
	;;	...............@@@@@@@@@@@......	@@@@@@@@@@@@@@.............@@@@@
	;;	..............@@@@@@@@@@........	@@@@@@@@@@@...............@@@@@@
	;;	...........@@@..@@@@@@..@@......	@@@@@@@@@...............@@.@@@@@
	;;	.........@@@@@@@..@@..@@@@......	@@@@@@@...............@@@@.@@@@@
	;;	.......@@@@@@@@@@@..@@@@@@......	@@@@@...............@@@@@@.@@@@@
	;;	.....@@@@@@@@@@@...@@@@@@@......	@@@@...............@@@@@@@.@@@@@
	;;	.......@@@@@@@..@@.@@@@@@.......	@@@@@...........@@.@@@@@@.@@@@@@
	;;	.....@@..@@@..@@@@.@@@@..@......	@@@@.@@.......@@@@.@@@@..@.@@@@@
	;;	.....@@@@...@@@@@@.@@..@@@......	@@@@.@@@@...@@@@@@.@@..@@@.@@@@@
	;;	.....@@@@@.@@@@@@@...@.@@@......	@@@@.@@@@@.@@@@@@@...@.@@@.@@@@@
	;;	.....@@@@@.@@@@@@..@@@.@@@......	@@@@.@@@@@.@@@@@@..@@@.@@@.@@@@@
	;;	.......@@@.@@@@..@@@@@.@@@......	@@@@@..@@@.@@@@..@@@@@.@@@.@@@@@
	;;	.....@@..@.@@..@@@@@@@.@@.......	@@@@.@@..@.@@..@@@@@@@.@@.@@@@@@
	;;	.....@@@@....@.@@@@@@@..........	@@@@.@@@@....@.@@@@@@@...@@@@@@@
	;;	.....@@@@@.@@@.@@@@@@...........	@@@@.@@@@@.@@@.@@@@@@.@@@@@@@@@@
	;;	.....@@@@@.@@@.@@@@.............	@@@@.@@@@@.@@@.@@@@..@@@@@@@@@@@
	;;	.....@@@@@.@@@.@@...............	@@@@.@@@@@.@@@.@@..@@@@@@@@@@@@@
	;;	.......@@@.@@@..................	@@@@@..@@@.@@@...@@@@@@@@@@@@@@@
	;;	.........@.@@...................	@@@@@@@..@.@@.@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@.@..@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
	;;	................................	@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;; -----------------------------------------------------------------------------------------------------------
img_2x24_bin:
floor_tiles
floor_tile_pattern0:				;;
	DEFB &E0, &00, &78, &00, &1E, &00, &07, &80, &01, &E0, &00, &78, &00, &1E, &00, &07
	DEFB &00, &07, &00, &1E, &00, &78, &01, &E0, &07, &80, &1E, &00, &78, &00, &E0, &00
	DEFB &E0, &00, &78, &00, &1E, &00, &07, &80, &01, &E0, &00, &78, &00, &1E, &00, &07
	;;	@@@.............
	;;	.@@@@...........
	;;	...@@@@.........
	;;	.....@@@@.......
	;;	.......@@@@.....
	;;	.........@@@@...
	;;	...........@@@@.
	;;	.............@@@
	;;	.............@@@
	;;	...........@@@@.
	;;	.........@@@@...
	;;	.......@@@@.....
	;;	.....@@@@.......
	;;	...@@@@.........
	;;	.@@@@...........
	;;	@@@.............
	;;	@@@.............
	;;	.@@@@...........
	;;	...@@@@.........
	;;	.....@@@@.......
	;;	.......@@@@.....
	;;	.........@@@@...
	;;	...........@@@@.
	;;	.............@@@

floor_tile_pattern1
	DEFB &3C, &03, &FC, &00, &FE, &00, &1F, &C0, &03, &F8, &00, &7F, &00, &3F, &C0, &3C
	DEFB &C0, &3C, &00, &3F, &00, &7F, &03, &F8, &1F, &C0, &FE, &00, &FC, &00, &3C, &03
	DEFB &3C, &03, &FC, &00, &FE, &00, &1F, &C0, &03, &F8, &00, &7F, &00, &3F, &C0, &3C
	;;	..@@@@........@@
	;;	@@@@@@..........
	;;	@@@@@@@.........
	;;	...@@@@@@@......
	;;	......@@@@@@@...
	;;	.........@@@@@@@
	;;	..........@@@@@@
	;;	@@........@@@@..
	;;	@@........@@@@..
	;;	..........@@@@@@
	;;	.........@@@@@@@
	;;	......@@@@@@@...
	;;	...@@@@@@@......
	;;	@@@@@@@.........
	;;	@@@@@@..........
	;;	..@@@@........@@
	;;	..@@@@........@@
	;;	@@@@@@..........
	;;	@@@@@@@.........
	;;	...@@@@@@@......
	;;	......@@@@@@@...
	;;	.........@@@@@@@
	;;	..........@@@@@@
	;;	@@........@@@@..

floor_tile_pattern2
	DEFB &07, &38, &03, &9F, &01, &C3, &F0, &78, &1E, &0F, &C3, &80, &F9, &C0, &1C, &E0
	DEFB &1C, &E0, &F9, &C0, &C3, &80, &1E, &0F, &F0, &78, &01, &C3, &03, &9F, &07, &38
	DEFB &07, &38, &03, &9F, &01, &C3, &F0, &78, &1E, &0F, &C3, &80, &F9, &C0, &1C, &E0
	;;	.....@@@..@@@...
	;;	......@@@..@@@@@
	;;	.......@@@....@@
	;;	@@@@.....@@@@...
	;;	...@@@@.....@@@@
	;;	@@....@@@.......
	;;	@@@@@..@@@......
	;;	...@@@..@@@.....
	;;	...@@@..@@@.....
	;;	@@@@@..@@@......
	;;	@@....@@@.......
	;;	...@@@@.....@@@@
	;;	@@@@.....@@@@...
	;;	.......@@@....@@
	;;	......@@@..@@@@@
	;;	.....@@@..@@@...
	;;	.....@@@..@@@...
	;;	......@@@..@@@@@
	;;	.......@@@....@@
	;;	@@@@.....@@@@...
	;;	...@@@@.....@@@@
	;;	@@....@@@.......
	;;	@@@@@..@@@......
	;;	...@@@..@@@.....

floor_tile_pattern3
	DEFB &10, &26, &40, &10, &00, &20, &C0, &C4, &26, &30, &18, &8C, &21, &02, &44, &01
	DEFB &30, &02, &88, &1C, &02, &63, &01, &80, &02, &10, &0C, &40, &23, &00, &88, &C1
	DEFB &00, &26, &40, &00, &00, &21, &C1, &C4, &26, &30, &18, &0C, &01, &00, &C4, &01
	;;	...@......@..@@.
	;;	.@.........@....
	;;	..........@.....
	;;	@@......@@...@..
	;;	..@..@@...@@....
	;;	...@@...@...@@..
	;;	..@....@......@.
	;;	.@...@.........@
	;;	..@@..........@.
	;;	@...@......@@@..
	;;	......@..@@...@@
	;;	.......@@.......
	;;	......@....@....
	;;	....@@...@......
	;;	..@...@@........
	;;	@...@...@@.....@
	;;	..........@..@@.
	;;	.@..............
	;;	..........@....@
	;;	@@.....@@@...@..
	;;	..@..@@...@@....
	;;	...@@.......@@..
	;;	.......@........
	;;	@@...@.........@

floor_tile_pattern4
	DEFB &CC, &30, &33, &C0, &CC, &03, &33, &0C, &30, &CC, &C0, &33, &03, &CC, &0C, &33
	DEFB &0C, &33, &03, &CC, &C0, &33, &30, &CC, &33, &0C, &CC, &03, &33, &C0, &CC, &30
	DEFB &CC, &30, &33, &C0, &CC, &03, &33, &0C, &30, &CC, &C0, &33, &03, &CC, &0C, &33
	;;	@@..@@....@@....
	;;	..@@..@@@@......
	;;	@@..@@........@@
	;;	..@@..@@....@@..
	;;	..@@....@@..@@..
	;;	@@........@@..@@
	;;	......@@@@..@@..
	;;	....@@....@@..@@
	;;	....@@....@@..@@
	;;	......@@@@..@@..
	;;	@@........@@..@@
	;;	..@@....@@..@@..
	;;	..@@..@@....@@..
	;;	@@..@@........@@
	;;	..@@..@@@@......
	;;	@@..@@....@@....
	;;	@@..@@....@@....
	;;	..@@..@@@@......
	;;	@@..@@........@@
	;;	..@@..@@....@@..
	;;	..@@....@@..@@..
	;;	@@........@@..@@
	;;	......@@@@..@@..
	;;	....@@....@@..@@

floor_tile_pattern5
	DEFB &00, &00, &45, &02, &00, &00, &00, &00, &01, &01, &04, &84, &02, &00, &00, &00
	DEFB &30, &00, &00, &40, &00, &10, &42, &00, &40, &C0, &01, &00, &00, &10, &40, &00
	DEFB &00, &43, &0C, &21, &00, &80, &00, &00, &21, &00, &00, &00, &0A, &08, &21, &04
	;;	................
	;;	.@...@.@......@.
	;;	................
	;;	................
	;;	.......@.......@
	;;	.....@..@....@..
	;;	......@.........
	;;	................
	;;	..@@............
	;;	.........@......
	;;	...........@....
	;;	.@....@.........
	;;	.@......@@......
	;;	.......@........
	;;	...........@....
	;;	.@..............
	;;	.........@....@@
	;;	....@@....@....@
	;;	........@.......
	;;	................
	;;	..@....@........
	;;	................
	;;	....@.@.....@...
	;;	..@....@.....@..

floor_tile_pattern6
	DEFB &47, &80, &B3, &C0, &8C, &00, &C3, &01, &C0, &C1, &E0, &33, &80, &CC, &00, &C3
	DEFB &01, &E2, &01, &CD, &03, &31, &80, &C3, &83, &03, &CC, &07, &33, &01, &C3, &00
	DEFB &47, &80, &B3, &80, &8C, &C0, &C3, &01, &C0, &C1, &E0, &33, &80, &CC, &00, &C3
	;;	.@...@@@@.......
	;;	@.@@..@@@@......
	;;	@...@@..........
	;;	@@....@@.......@
	;;	@@......@@.....@
	;;	@@@.......@@..@@
	;;	@.......@@..@@..
	;;	........@@....@@
	;;	.......@@@@...@.
	;;	.......@@@..@@.@
	;;	......@@..@@...@
	;;	@.......@@....@@
	;;	@.....@@......@@
	;;	@@..@@.......@@@
	;;	..@@..@@.......@
	;;	@@....@@........
	;;	.@...@@@@.......
	;;	@.@@..@@@.......
	;;	@...@@..@@......
	;;	@@....@@.......@
	;;	@@......@@.....@
	;;	@@@.......@@..@@
	;;	@.......@@..@@..
	;;	........@@....@@

empty_floor_tile:
floor_tile_pattern7: 				;; Empty tile
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00

Char_symbol_data:
	DEFB	&00, &00, &00, &00, &00, &00, &00, &00
	;;	................
	;;	................
	;;	................
	;;	................
	;;	................
	;;	................
	;;	................
	;;	................
	DEFB	&22, &33, &7F, &7F, &7F, &FF, &C9, &80
	;;	....@@......@@..
	;;	....@@@@....@@@@
	;;	..@@@@@@@@@@@@@@
	;;	..@@@@@@@@@@@@@@
	;;	..@@@@@@@@@@@@@@
	;;	@@@@@@@@@@@@@@@@
	;;	@@@@....@@....@@
	;;	@@..............
	DEFB	&44, &CC, &FE, &FE, &FE, &FF, &93, &01
	;;	..@@......@@....
	;;	@@@@....@@@@....
	;;	@@@@@@@@@@@@@@..
	;;	@@@@@@@@@@@@@@..
	;;	@@@@@@@@@@@@@@..
	;;	@@@@@@@@@@@@@@@@
	;;	@@....@@....@@@@
	;;	..............@@
	DEFB	&03, &03, &03, &03, &0F, &07, &03, &01
	;;	............@@@@
	;;	............@@@@
	;;	............@@@@
	;;	............@@@@
	;;	........@@@@@@@@
	;;	..........@@@@@@
	;;	............@@@@
	;;	..............@@
	DEFB	&C0, &C0, &C0, &C0, &F0, &E0, &C0, &80
	;;	@@@@............
	;;	@@@@............
	;;	@@@@............
	;;	@@@@............
	;;	@@@@@@@@........
	;;	@@@@@@..........
	;;	@@@@............
	;;	@@..............
	DEFB	&C0, &70, &3C, &18, &3C, &0E, &03, &00
	;;	@@@@............
	;;	..@@@@@@........
	;;	....@@@@@@@@....
	;;	......@@@@......
	;;	....@@@@@@@@....
	;;	........@@@@@@..
	;;	............@@@@
	;;	................
	DEFB	&06, &03, &3B, &66, &3D, &42, &3C, &00
	;;	..........@@@@..
	;;	............@@@@
	;;	....@@@@@@..@@@@
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@..@@
	;;	..@@........@@..
	;;	....@@@@@@@@....
	;;	................
	DEFB	&FE, &AA, &82, &82, &6C, &38, &10, &00
	;;	@@@@@@@@@@@@@@..
	;;	@@..@@..@@..@@..
	;;	@@..........@@..
	;;	@@..........@@..
	;;	..@@@@..@@@@....
	;;	....@@@@@@......
	;;	......@@........
	;;	................
	DEFB	&00, &00, &00, &00, &18, &18, &08, &10
	;;	................
	;;	................
	;;	................
	;;	................
	;;	......@@@@......
	;;	......@@@@......
	;;	........@@......
	;;	......@@........
	DEFB	&00, &00, &00, &3C, &3C, &00, &00, &00
	;;	................
	;;	................
	;;	................
	;;	....@@@@@@@@....
	;;	....@@@@@@@@....
	;;	................
	;;	................
	;;	................
	DEFB	&00, &00, &00, &00, &00, &00, &18, &18
	;;	................
	;;	................
	;;	................
	;;	................
	;;	................
	;;	................
	;;	......@@@@......
	;;	......@@@@......
	DEFB	&0C, &0C, &18, &18, &30, &30, &60, &60
	;;	........@@@@....
	;;	........@@@@....
	;;	......@@@@......
	;;	......@@@@......
	;;	....@@@@........
	;;	....@@@@........
	;;	..@@@@..........
	;;	..@@@@..........
	DEFB	&3C, &66, &6E, &7E, &76, &66, &66, &3C
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@..@@@@@@..
	;;	..@@@@@@@@@@@@..
	;;	..@@@@@@..@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&18, &38, &18, &18, &18, &18, &3C, &3C
	;;	......@@@@......
	;;	....@@@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	....@@@@@@@@....
	;;	....@@@@@@@@....
	DEFB	&3C, &66, &46, &0C, &18, &30, &7E, &7E
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@......@@@@..
	;;	........@@@@....
	;;	......@@@@......
	;;	....@@@@........
	;;	..@@@@@@@@@@@@..
	;;	..@@@@@@@@@@@@..
	DEFB	&7E, &06, &0C, &1C, &06, &06, &66, &3C
	;;	..@@@@@@@@@@@@..
	;;	..........@@@@..
	;;	........@@@@....
	;;	......@@@@@@....
	;;	..........@@@@..
	;;	..........@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&0C, &1C, &14, &34, &24, &64, &7E, &04
	;;	........@@@@....
	;;	......@@@@@@....
	;;	......@@..@@....
	;;	....@@@@..@@....
	;;	....@@....@@....
	;;	..@@@@....@@....
	;;	..@@@@@@@@@@@@..
	;;	..........@@....
	DEFB	&7E, &60, &60, &7C, &06, &06, &66, &3C
	;;	..@@@@@@@@@@@@..
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@@@@@@@....
	;;	..........@@@@..
	;;	..........@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&1C, &30, &60, &7C, &66, &66, &66, &3C
	;;	......@@@@@@....
	;;	....@@@@........
	;;	..@@@@..........
	;;	..@@@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&7E, &06, &0C, &0C, &18, &18, &30, &30
	;;	..@@@@@@@@@@@@..
	;;	..........@@@@..
	;;	........@@@@....
	;;	........@@@@....
	;;	......@@@@......
	;;	......@@@@......
	;;	....@@@@........
	;;	....@@@@........
	DEFB	&3C, &66, &66, &3C, &7E, &66, &66, &3C
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	;;	..@@@@@@@@@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&3C, &66, &66, &66, &3E, &06, &66, &3C
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@@@..
	;;	..........@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&00, &00, &18, &18, &00, &18, &18, &00
	;;	................
	;;	................
	;;	......@@@@......
	;;	......@@@@......
	;;	................
	;;	......@@@@......
	;;	......@@@@......
	;;	................
	DEFB	&00, &18, &18, &00, &18, &18, &08, &10
	;;	................
	;;	......@@@@......
	;;	......@@@@......
	;;	................
	;;	......@@@@......
	;;	......@@@@......
	;;	........@@......
	;;	......@@........
	DEFB	&00, &7C, &C6, &BA, &AA, &BE, &C0, &7C
	;;	................
	;;	..@@@@@@@@@@....
	;;	@@@@......@@@@..
	;;	@@..@@@@@@..@@..
	;;	@@..@@..@@..@@..
	;;	@@..@@@@@@@@@@..
	;;	@@@@............
	;;	..@@@@@@@@@@....
	DEFB	&3C, &7E, &66, &66, &7E, &7E, &66, &66
	;;	....@@@@@@@@....
	;;	..@@@@@@@@@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@@@..
	;;	..@@@@@@@@@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	DEFB	&7C, &66, &66, &7C, &7C, &66, &66, &7C
	;;	..@@@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@....
	;;	..@@@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@....
	DEFB	&3C, &7E, &66, &60, &60, &66, &7E, &3C
	;;	....@@@@@@@@....
	;;	..@@@@@@@@@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@@@..
	;;	....@@@@@@@@....
	DEFB	&7C, &66, &66, &66, &66, &66, &66, &7C
	;;	..@@@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@....
	DEFB	&7E, &60, &60, &78, &60, &60, &60, &7E
	;;	..@@@@@@@@@@@@..
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@@@@@......
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@@@@@@@@@..
	DEFB	&7E, &60, &60, &78, &60, &60, &60, &60
	;;	..@@@@@@@@@@@@..
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@@@@@......
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	DEFB	&3C, &66, &60, &60, &60, &66, &7E, &3A
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@@@..
	;;	....@@@@@@..@@..
	DEFB	&66, &66, &66, &7E, &66, &66, &66, &66
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	DEFB	&3C, &18, &18, &18, &18, &18, &18, &3C
	;;	....@@@@@@@@....
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	....@@@@@@@@....
	DEFB	&1E, &0C, &0C, &0C, &0C, &0C, &6C, &38
	;;	......@@@@@@@@..
	;;	........@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	..@@@@..@@@@....
	;;	....@@@@@@......
	DEFB	&62, &66, &6C, &78, &78, &6C, &66, &62
	;;	..@@@@......@@..
	;;	..@@@@....@@@@..
	;;	..@@@@..@@@@....
	;;	..@@@@@@@@......
	;;	..@@@@@@@@......
	;;	..@@@@..@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@......@@..
	DEFB	&60, &60, &60, &60, &60, &60, &60, &7E
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@@@@@@@@@..
	DEFB	&C6, &EE, &FE, &D6, &C6, &C6, &C6, &C6
	;;	@@@@......@@@@..
	;;	@@@@@@..@@@@@@..
	;;	@@@@@@@@@@@@@@..
	;;	@@@@..@@..@@@@..
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	DEFB	&C6, &C6, &E6, &F6, &DE, &CE, &C6, &C6
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	;;	@@@@@@....@@@@..
	;;	@@@@@@@@..@@@@..
	;;	@@@@..@@@@@@@@..
	;;	@@@@....@@@@@@..
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	DEFB	&3C, &66, &66, &66, &66, &66, &66, &3C
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&7C, &66, &66, &7C, &60, &60, &60, &60
	;;	..@@@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@....
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	;;	..@@@@..........
	DEFB	&78, &CC, &CC, &CC, &CC, &DC, &CC, &7A
	;;	..@@@@@@@@......
	;;	@@@@....@@@@....
	;;	@@@@....@@@@....
	;;	@@@@....@@@@....
	;;	@@@@....@@@@....
	;;	@@@@..@@@@@@....
	;;	@@@@....@@@@....
	;;	..@@@@@@@@..@@..
	DEFB	&7C, &66, &66, &7C, &6C, &6C, &66, &66
	;;	..@@@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@@@@@@@....
	;;	..@@@@..@@@@....
	;;	..@@@@..@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	DEFB	&3C, &66, &60, &3C, &06, &06, &66, &3C
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@..........
	;;	....@@@@@@@@....
	;;	..........@@@@..
	;;	..........@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&7E, &18, &18, &18, &18, &18, &18, &18
	;;	..@@@@@@@@@@@@..
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	DEFB	&66, &66, &66, &66, &66, &66, &66, &3C
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	DEFB	&66, &66, &66, &66, &3C, &3C, &18, &18
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	;;	....@@@@@@@@....
	;;	......@@@@......
	;;	......@@@@......
	DEFB	&C6, &C6, &C6, &C6, &D6, &FE, &EE, &C6
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	;;	@@@@......@@@@..
	;;	@@@@..@@..@@@@..
	;;	@@@@@@@@@@@@@@..
	;;	@@@@@@..@@@@@@..
	;;	@@@@......@@@@..
	DEFB	&66, &66, &3C, &18, &18, &3C, &66, &66
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	;;	......@@@@......
	;;	......@@@@......
	;;	....@@@@@@@@....
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	DEFB	&66, &66, &3C, &18, &18, &18, &18, &18
	;;	..@@@@....@@@@..
	;;	..@@@@....@@@@..
	;;	....@@@@@@@@....
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	DEFB	&7E, &0E, &0C, &1C, &18, &38, &30, &7E
	;;	..@@@@@@@@@@@@..
	;;	........@@@@@@..
	;;	........@@@@....
	;;	......@@@@@@....
	;;	......@@@@......
	;;	....@@@@@@......
	;;	....@@@@........
	;;	..@@@@@@@@@@@@..
	DEFB	&3C, &30, &30, &30, &30, &30, &30, &3C
	;;	....@@@@@@@@....
	;;	....@@@@........
	;;	....@@@@........
	;;	....@@@@........
	;;	....@@@@........
	;;	....@@@@........
	;;	....@@@@........
	;;	....@@@@@@@@....
	DEFB	&60, &60, &30, &30, &18, &18, &0C, &0C
	;;	..@@@@..........
	;;	..@@@@..........
	;;	....@@@@........
	;;	....@@@@........
	;;	......@@@@......
	;;	......@@@@......
	;;	........@@@@....
	;;	........@@@@....
	DEFB	&3C, &0C, &0C, &0C, &0C, &0C, &0C, &3C
	;;	....@@@@@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	........@@@@....
	;;	....@@@@@@@@....
	DEFB	&18, &3C, &7E, &18, &18, &18, &18, &18
	;;	......@@@@......
	;;	....@@@@@@@@....
	;;	..@@@@@@@@@@@@..
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	DEFB	&18, &18, &18, &18, &18, &7E, &3C, &18
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	......@@@@......
	;;	..@@@@@@@@@@@@..
	;;	....@@@@@@@@....
	;;	......@@@@......
	DEFB	&00, &08, &0C, &FE, &FE, &0C, &08, &00
	;;	................
	;;	........@@......
	;;	........@@@@....
	;;	@@@@@@@@@@@@@@..
	;;	@@@@@@@@@@@@@@..
	;;	........@@@@....
	;;	........@@......
	;;	................
	DEFB	&00, &20, &60, &FE, &FE, &60, &20, &00
	;;	................
	;;	....@@..........
	;;	..@@@@..........
	;;	@@@@@@@@@@@@@@..
	;;	@@@@@@@@@@@@@@..
	;;	..@@@@..........
	;;	....@@..........
	;;	................

;; -----------------------------------------------------------------------------------------------------------
;; These are the pillars sprites that may go under some of the doors (type 4)
.img_pillar_top: 				;; 4x9 *2  Pillar Top
	;; (shown as "msk1+msk2 img1+img2 : result" so it is easier to see the result)
	DEFB &00, &00, &00, &03, &00, &00, &00, &0F, &00, &00, &00, &10, &AE, &FF, &F2, &BF
	DEFB &FF, &03, &00, &F3, &00, &0F, &00, &FC, &00, &3F, &00, &FF, &00, &FF, &00, &FC
	DEFB &00, &FF, &00, &F3, &00, &FF, &00, &CF, &00, &FF, &00, &3E, &00, &FC, &00, &F8
	DEFB &00, &F4, &04, &E4, &00, &CF, &14, &84, &00, &3E, &1A, &02, &01, &78, &2A, &32
	DEFB &05, &64, &0A, &02, &1D, &1C, &9A, &02
;; To have a blit without the glitch, use these values instead (Alt):
;;  B6D0 DEFB &00, &00, &00, &03, &00, &00, &00, &0F, &00, &00, &00, &3F, &00, &00, &00, &CF
;;  B6E0 DEFB &00, &03, &00, &F3, &00, &0F, &00, &FC, &00, &3F, &00, &FF, &00, &FF, &00, &FC
;;  B6F0 DEFB &00, &FF, &00, &F3, &00, &FF, &00, &CF, &00, &FF, &00, &3E, &00, &FC, &00, &F8
;;  B700 DEFB &00, &F3, &04, &E4, &00, &CF, &14, &84, &00, &3E, &1A, &02, &01, &78, &2A, &32
;;	B710 DEFB &05, &64, &0A, &02, &1D, &1C, &9A, &02
	;;	................ ..............@@		;		................ ..............@@
	;;	................ ............@@@@		; Alt:	................ ............@@@@
	;;	................ ...........@....		;		................ ..........@@@@@@
	;;	@.@.@@@.@@@@..@. @@@@@@@@@.@@@@@@		;		................ ........@@..@@@@
	;;	@@@@@@@@........ ......@@@@@@..@@		;		................ ......@@@@@@..@@
	;;	................ ....@@@@@@@@@@..		;		................ ....@@@@@@@@@@..
	;;	................ ..@@@@@@@@@@@@@@		;		................ ..@@@@@@@@@@@@@@
	;;	................ @@@@@@@@@@@@@@..		;		................ @@@@@@@@@@@@@@..
	;;	................ @@@@@@@@@@@@..@@		;		................ @@@@@@@@@@@@..@@
	;;	................ @@@@@@@@@@..@@@@		;		................ @@@@@@@@@@..@@@@
	;;	................ @@@@@@@@..@@@@@.		;		................ @@@@@@@@..@@@@@.
	;;	................ @@@@@@..@@@@@...		;		................ @@@@@@..@@@@@...
	;;	.............@.. @@@@.@..@@@..@..		;		.............@.. @@@@..@@@@@..@..
	;;	...........@.@.. @@..@@@@@....@..		;		...........@.@.. @@..@@@@@....@..
	;;	...........@@.@. ..@@@@@.......@.		;		...........@@.@. ..@@@@@.......@.
	;;	.......@..@.@.@. .@@@@.....@@..@.		;		.......@..@.@.@. .@@@@.....@@..@.
	;;	.....@.@....@.@. .@@..@........@.		;		.....@.@....@.@. .@@..@........@.
	;;	...@@@.@@..@@.@. ...@@@........@.		;		...@@@.@@..@@.@. ...@@@........@.

img_pillar_mid
	DEFB &3E, &BE, &F6, &06, &17, &97, &0C, &0C, &17, &97, &FC, &FC, &0D, &8D, &FA, &F8
	DEFB &23, &83, &E6, &E0, &34, &84, &1A, &18, &2F, &8F, &0C, &0C, &1E, &9E, &F4, &04
	DEFB &1D, &9C, &9A, &02, &3D, &BC, &2A, &32, &3D, &BC, &0A, &02, &3D, &BC, &9A, &02
	;;	..@@@@@.@@@@.@@. @.@@@@@......@@.
	;;	...@.@@@....@@.. @..@.@@@....@@..
	;;	...@.@@@@@@@@@.. @..@.@@@@@@@@@..
	;;	....@@.@@@@@@.@. @...@@.@@@@@@...
	;;	..@...@@@@@..@@. @.....@@@@@.....
	;;	..@@.@.....@@.@. @....@.....@@...
	;;	..@.@@@@....@@.. @...@@@@....@@..
	;;	...@@@@.@@@@.@.. @..@@@@......@..
	;;	...@@@.@@..@@.@. @..@@@........@.
	;;	..@@@@.@..@.@.@. @.@@@@....@@..@.
	;;	..@@@@.@....@.@. @.@@@@........@.
	;;	..@@@@.@@..@@.@. @.@@@@........@.

img_pillar_btm
	DEFB &3E, &BE, &F6, &06, &17, &97, &0C, &0C, &17, &97, &FC, &FC, &0D, &8D, &F8, &F8
	DEFB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
	;;	..@@@@@.@@@@.@@. @.@@@@@......@@.
	;;	...@.@@@....@@.. @..@.@@@....@@..
	;;	...@.@@@@@@@@@.. @..@.@@@@@@@@@..
	;;	....@@.@@@@@@... @...@@.@@@@@@...
	;;	................ ................
	;;	................ ................
	;;	................ ................
	;;	................ ................

end_moved_block

;; -----------------------------------------------------------------------------------------------------------
PILLARBUF_LENGTH	EQU	296
PillarBuf
	DEFS PILLARBUF_LENGTH

DoorwayBuf
DoorwayImgBuf
	DEFS 168	;;
DoorwayMaskBuf
	DEFS 168	;;
