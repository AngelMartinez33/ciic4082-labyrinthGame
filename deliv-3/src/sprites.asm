.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
player_dir: .res 1
player_vertical_dir: .res 1
pad1: .res 1

.exportzp player_x, player_y, pad1

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.import read_controller1

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  ; read controller
  JSR read_controller1

  ; update tiles *after* DMA transfer
  JSR update_player
  JSR draw_player

  LDA #$00
  STA $2005
  STA $2005
  RTI
.endproc

.import reset_handler

.export main
.proc main
  ; write a palette
  LDX PPUSTATUS
  LDX #$3f    ;this number is the address of the first color of the first pallete
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  ;CPX #$04          ;loads first 4 bytes in pallets
  CPX #$20
  BNE load_palettes

  ; write sprite data
;   LDX #$00
; load_sprites:
;   LDA sprites,X
;   STA $0200,X
;   INX
;   ;CPX #$C0
;   CPX #$10
;   BNE load_sprites

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK
forever:
  JMP forever
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
;palettes:
;.byte $29, $19, $09, $0f  
;.byte $0f, $0c, $21, $32
palettes:
.byte $0f, $2d, $10, $37
.byte $0f, $2d, $14, $37
.byte $0f, $0c, $07, $13
.byte $0f, $19, $09, $29

.byte $0f, $2d, $14, $37
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29
.byte $0f, $19, $09, $29

sprites:
;Y, Sprite, Pallet, X
;Front still
;top left
.byte $40, $09, $00, $60
;top right
.byte $40, $0A, $00, $68
;bottom left
.byte $48, $19, $00, $60
;bottom right
.byte $48, $1A, $00, $68

.proc draw_player
  ;save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ;write player tile numbers 
  LDA #$09
  STA $0201
  LDA #$0A
  STA $0205
  LDA #$19
  STA $0209
  LDA #$1A
  STA $020d
  ; write player tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e

  ; store tile locations
  ; top left tile:
  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; top right tile (x + 8):
  LDA player_y
  STA $0204
  LDA player_x
  CLC
  ADC #$08
  STA $0207

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; bottom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  CLC
  ADC #$08
  STA $020f

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

; .proc update_player
;   PHP
;   PHA
;   TXA
;   PHA
;   TYA
;   PHA

;   LDA player_x
;   CMP #$e0
;   BCC not_at_right_edge
;   ; if BCC is not taken, we are greater than $e0
;   LDA #$00
;   STA player_dir    ; start moving left
;   JMP direction_set ; we already chose a direction,
;                     ; so we can skip the left side check
; not_at_right_edge:
;   LDA player_x
;   CMP #$10
;   BCS direction_set
;   ; if BCS not taken, we are less than $10
;   LDA #$01
;   STA player_dir   ; start moving right
; direction_set:
;   ; now, actually update player_x
;   LDA player_dir
;   CMP #$01
;   BEQ move_right
;   ; if player_dir minus $01 is not zero,
;   ; that means player_dir was $00 and
;   ; we need to move left
;   DEC player_x
;   JMP exit_subroutine
; move_right:
;   INC player_x
; exit_subroutine:
;   ; all done, clean up and return

;   LDA player_y
;   CMP #$e0
;   BCC not_at_bottom_edge
;   ; if BCC is not taken, we are greater than $e0
;   LDA #$00
;   STA player_vertical_dir    ; start moving up
;   JMP vertical_direction_set ; we already chose a direction,
;                     ; so we can skip the left side check
; not_at_bottom_edge:
;   LDA player_y
;   CMP #$10
;   BCS vertical_direction_set
;   ; if BCS not taken, we are less than $10
;   LDA #$01
;   STA player_vertical_dir   ; start moving down

; vertical_direction_set:
;   ; now, actually update player_y
;   LDA player_vertical_dir
;   CMP #$01
;   BEQ move_down
;   ; if player_dir minus $01 is not zero,
;   ; that means player_dir was $00 and
;   ; we need to move up
;   DEC player_y
;   JMP exit_subroutine2
; move_down:
;   INC player_y


; exit_subroutine2:
;   ; all done, clean up and return
;   PLA
;   TAY
;   PLA
;   TAX
;   PLA
;   PLP
;   RTS
; .endproc

.proc update_player
  PHP  ; Start by saving registers,
  PHA  ; as usual.
  TXA
  PHA
  TYA
  PHA

  LDA pad1        ; Load button presses
  AND #BTN_LEFT   ; Filter out all but Left
  BEQ check_right ; If result is zero, left not pressed
  DEC player_x  ; If the branch is not taken, move player left
check_right:
  LDA pad1
  AND #BTN_RIGHT
  BEQ check_up
  INC player_x
check_up:
  LDA pad1
  AND #BTN_UP
  BEQ check_down
  DEC player_y
check_down:
  LDA pad1
  AND #BTN_DOWN
  BEQ done_checking
  INC player_y
done_checking:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.segment "CHR"
.incbin "graphics2.chr"