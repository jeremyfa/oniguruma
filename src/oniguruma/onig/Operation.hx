// Ported from Oniguruma 6.9.8: src/regint.h (Operation)
// Original code Copyright (c) 2002-2022 K.Kosako, licensed under BSD-2-Clause.
// Modified: translated to Haxe. The C union of operands is flattened into named fields. See README.md.

package oniguruma.onig;

import haxe.io.Bytes;
import haxe.ds.Vector;

class Operation {

    public var opcode:Int = 0;

    /** exact.s / exact_n.s / exact_len_n.s (own copy of the bytes, starting at 0) */
    public var s:Bytes = null;
    /** exact_n.n, exact_len_n.n (number of chars) */
    public var n:Int = 0;
    /** exact_len_n.len (char byte length), look_behind.len, look_behind_not_start.len */
    public var len:Int = 0;

    /** cclass.bsp, cclass_mix.bsp */
    public var bsp:Vector<Int> = null;
    /** cclass_mb.mb, cclass_mix.mb (code ranges) */
    public var mb:Array<Int> = null;

    /** anychar_star_peek_next.c, push_or_jump_exact1.c, push_if_peek_next.c */
    public var c:Int = 0;

    /** word_boundary.mode */
    public var mode:Int = 0;
    /** text_segment_boundary.type, check_position.type, save_val.type, update_var.type */
    public var type:Int = 0;
    /** text_segment_boundary.not */
    public var not:Int = 0;

    /** backref_general.n1, backref_n.n1 */
    public var n1:Int = 0;
    /** backref_general.ns */
    public var ns:Array<Int> = null;
    /** backref_general.num, memory_start.num, memory_end.num, callout_contents.num, callout_name.num */
    public var num:Int = 0;
    /** backref_general.nest_level */
    public var nestLevel:Int = 0;

    /** jump.addr, push.addr, push_or_jump_exact1.addr, push_if_peek_next.addr, repeat.addr,
        prec_read_not_start.addr, look_behind_not_start.addr, step_back_start.addr, call.addr */
    public var addr:Int = 0;

    /** pop_to_mark.id, repeat.id, repeat_inc.id, cut_to_mark.id, mark.id, save_val.id, update_var.id, callout_name.id */
    public var id:Int = 0;

    /** empty_check_start.mem, empty_check_end.mem */
    public var mem:Int = 0;
    /** empty_check_end.empty_status_mem */
    public var emptyStatusMem:Int = 0;

    /** move.n */
    public var moveN:Int = 0;

    /** step_back_start.initial, step_back_start.remaining */
    public var initial:Int = 0;
    public var remaining:Int = 0;

    /** cut_to_mark.restore_pos, mark.save_pos, update_var.clear */
    public var flagv:Int = 0;

    public function new() {}

}
