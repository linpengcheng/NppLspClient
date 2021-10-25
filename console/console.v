module console

import os
import winapi as api
import notepadpp
import scintilla as sci

#include "resource.h"

[windows_stdcall]
fn dialog_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	match int(message) {
		C.WM_COMMAND {
		}
		C.WM_INITDIALOG {
			api.set_parent(p.console_window.output_hwnd, hwnd)
			api.show_window(p.console_window.output_hwnd, C.SW_SHOW)
		}
		C.WM_SIZE {
			api.move_window(p.console_window.output_hwnd, 0, 0, api.loword(u64(lparam)), api.hiword(u64(lparam)), true)
		}
		C.WM_DESTROY {
			api.destroy_window(hwnd)
			return 1
		}
		else {}
	}
	return 0
}

pub struct DockableDialog {
pub mut:
	name &u16
	hwnd voidptr
	is_visible bool
	tbdata notepadpp.TbData
	output_hwnd voidptr
	output_editor_func sci.SCI_FN_DIRECT
	output_editor_hwnd voidptr
	old_edit_proc api.WndProc
}

[inline]
fn (mut d DockableDialog) call(msg int, wparam usize, lparam isize) isize {
	return d.output_editor_func(d.output_editor_hwnd, msg, wparam, lparam)
}

pub fn (mut d DockableDialog) clear() {
	d.call(sci.sci_clearall, 0, 0)
}

pub fn (mut d DockableDialog) log(text string, style byte) {
	// write_to_log(text)
	mut text__ := if text.ends_with('\n') { text } else { text + '\n'}
	if style == -1 {
		d.call(sci.sci_appendtext, usize(text__.len), isize(text__.str))
	} else {
		mut buffer := vcalloc(text__.len * 2)
		unsafe {
			for i:=0; i<text__.len; i++ {
				buffer[i*2] = text__.str[i]
				buffer[i*2+1] = style
			}
		}
		d.call(sci.sci_addstyledtext, usize(text__.len * 2), isize(buffer))
	}
	
	line_count := d.call(sci.sci_getlinecount, 0, 0)
	d.call(sci.sci_gotoline, usize(line_count-1), 0)
}



pub fn (mut d DockableDialog) create(npp_hwnd voidptr, plugin_name string) {
	d.output_hwnd = npp.create_scintilla(d.hwnd)
	d.hwnd = voidptr(api.create_dialog_param(dll_instance, api.make_int_resource(C.IDD_CONSOLEDLG), npp_hwnd, api.WndProc(dialog_proc), 0))
	icon := api.load_image(dll_instance, api.make_int_resource(200), u32(C.IMAGE_ICON), 16, 16, 0)
	d.tbdata = notepadpp.TbData {
		client: d.hwnd
		name: d.name
		dlg_id: -1
		mask: notepadpp.dws_df_cont_bottom | notepadpp.dws_icontab
		icon_tab: icon
		add_info: voidptr(0)
		rc_float: api.RECT{}
		prev_cont: -1
		module_name: plugin_name.to_wide()
	}
	npp.register_dialog(d.tbdata)
	d.hide()
	d.output_editor_func = sci.SCI_FN_DIRECT(api.send_message(d.output_hwnd, 2184, 0, 0))
	d.output_editor_hwnd = voidptr(api.send_message(d.output_hwnd, 2185, 0, 0))
}

pub fn (mut d DockableDialog) init_scintilla(fore_color int, back_color int) {
	d.call(sci.sci_stylesetfore, 32, fore_color)
	d.call(sci.sci_stylesetback, 32, back_color)
	d.call(sci.sci_styleclearall, 0, 0)
	d.call(sci.sci_stylesetfore, 0, fore_color) // normal log messages
	d.call(sci.sci_stylesetfore, 1, 0xFFAC59)  	// outgoing LSP messages
	d.call(sci.sci_stylesetfore, 2, 0x7BC399)  	// incomming LSP messages
	d.call(sci.sci_stylesetfore, 3, 0x20C3C9)  	// warning log messages
	d.call(sci.sci_stylesetfore, 4, 0x756CE0)  	// error log messages
	d.call(sci.sci_setmargins, 0, 0)
}

pub fn (mut d DockableDialog) show() {
	npp.show_dialog(d.hwnd)
	d.is_visible = true
}

pub fn (mut d DockableDialog) hide() {
	npp.hide_dialog(d.hwnd)
	d.is_visible = false
}

fn write_to_log(msg string) {
	mut file := os.open_append('D:\\dump.txt') or { return }
	file.write_string(msg) or { 0 }
	file.close()
}