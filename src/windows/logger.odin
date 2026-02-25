package windows
import mu "vendor:microui"
import rl "vendor:raylib"

import "core:log"
import "core:strings"
import "core:fmt"
import "core:time"
import "core:path/filepath"
import "core:terminal/ansi"
import "core:terminal"
import "core:c"

//TASK(20260225-132738-406-n6-982): make this use a ring buffer
@private
strs:[dynamic]Text

@private
Text::struct {
    color: mu.Color,
    str: string,
}

logger :: proc(lowest_level:=log.Level.Debug, opts:=log.Default_Console_Logger_Opts) -> log.Logger {
    logger_proc :: proc(_: rawptr, level: log.Level, text: string, options: log.Options, location := #caller_location) {
        sb:=strings.builder_make()
        for opt in options {
            switch opt {
            case .Level:
                switch level {
                case .Debug:
                    fmt.sbprint(&sb,"DEBUG: ")
                case .Info:
                    fmt.sbprint(&sb,"INFO: ")
                case .Warning:
                    fmt.sbprint(&sb,"WARNING: ")
                case .Error:
                    fmt.sbprint(&sb,"ERROR: ")
                case .Fatal:
                    fmt.sbprint(&sb,"FATAL: ")
                }
            case .Date:
                buf:[100]u8
                fmt.sbprint(&sb, time.to_string_dd_mm_yyyy(time.now(), buf[:]), " ", sep=":")
            case .Time:
                buf:[100]u8
                fmt.sbprint(&sb, time.to_string_hms_12(time.now(), buf[:]), " ", sep=":")
            case .Short_File_Path:
                fmt.sbprint(&sb, filepath.base(location.file_path), " ", sep=":")
            case .Long_File_Path:
                fmt.sbprint(&sb, location.file_path, " ", sep=":")
            case .Line:
                fmt.sbprint(&sb, location.line, " ", sep=":")
            case .Procedure:
                fmt.sbprint(&sb, location.procedure, " ", sep=":")
            case .Thread_Id, .Terminal_Color:
            }
        }
        color := ""
        console_color:=mu.Color{255, 255, 255, 255}
        if (.Terminal_Color in options) && terminal.color_enabled{
            switch level {
            case .Debug:
                color=ansi.FG_CYAN
                console_color.r = 0
            case .Info:
                color=ansi.FG_BLUE
                console_color.r = 45
                console_color.g = 157
            case .Warning:
                color=ansi.FG_YELLOW
                console_color.b = 0
            case .Error, .Fatal:
                color=ansi.FG_RED
                console_color.b = 104
                console_color.g = 104
            }
            fmt.print(ansi.CSI, color, ansi.SGR, sep="")
        }
        fmt.sbprint(&sb, text)
        string := strings.to_string(sb) //this needs to be freed later
        append(&strs, Text{
            str = string,
            color = console_color,
        })
        for len(strs) > MAXSTRS {
            delete(strs[0].str)
            ordered_remove(&strs, 0) 
        }
        updated=true
        fmt.println(strings.trim_space(string))
        if (.Terminal_Color in options) && terminal.color_enabled{
            fmt.print(ansi.CSI+ansi.RESET+ansi.SGR)
        }
    }
    return log.Logger {
        lowest_level = lowest_level,
        options = opts,
        procedure = logger_proc,
    }
}

@private
updated:=false

@private
MAXSTRS::1000

log_raw :: proc(args:..any, sep:=" ") {
    sb:=strings.builder_make()
    fmt.sbprint(&sb, ..args, sep=sep)
    string:=strings.to_string(sb)
    fmt.println(strings.trim_space(string))
    updated=true
    append(&strs, Text{
        str=string,
        color=mu.Color{255,255,255,255}
        }) 
    for len(strs) > MAXSTRS {
        delete(strs[0].str)
        ordered_remove(&strs, 0) 
    }
}


log_rawf :: proc(_fmt: string, args:..any) {
    sb:=strings.builder_make()
    fmt.sbprintf(&sb, _fmt, ..args)
    string:=strings.to_string(sb)
    fmt.println(strings.trim_space(string))
    updated=true
    append(&strs, Text{
        str=string,
        color=mu.Color{255,255,255,255}
        }) 
    for len(strs) > MAXSTRS {
        delete(strs[0].str)
        ordered_remove(&strs, 0) 
    }
}

@private
text:[128]u8
@private
text_len: int

CommandProc :: proc(..string)

    @private
    Command:: struct {
        procedure: CommandProc,
        range_start,
        range_end: int,
    }

    @private
    commands: map[string]Command

    add_command :: proc(command: string, procedure: CommandProc, range_start:int=0, range_end:int=max(int)) {
        commands[command] = Command {
            procedure=procedure,
            range_start=range_start,
            range_end=range_end,
        } 
    }

    run_command :: proc(command_name: string, args: ..string) { 
        if !(command_name in commands) {
            log.errorf("command '%s' doesn't exist", command_name)
            return
        } 
        command:=commands[command_name]
        if !(command.range_start <= len(args) && len(args) <= command.range_end) {
            if command.range_start != command.range_end {
                if command.range_end == max(int) {
                    log.errorf(
                        "command '%s' requires at least '%d' %s",
                        command_name,
                        command.range_start,
                        command.range_start == 1? "arg": "args",
                    )
                } else {
                    log.errorf(
                        "command '%s' requires at least '%d' %s, and at most '%d' %s",
                        command_name,
                        command.range_start,
                        command.range_start==1?"arg":"args",
                        command.range_end,
                        command.range_end==1?"arg":"args",
                    )
                }
            } else {
                log.errorf("command '%s' requires '%d' %s",
                    command_name,
                    command.range_start,
                    command.range_start == 1? "arg": "args",
                )
            }
            return
        }
        command.procedure(..args)
    }

    draw_console :: proc(ctx: ^mu.Context, render, has_focus: ^bool) {
        if !render^ {
            return
        }
        window_width:=rl.GetScreenWidth()
        window_height:=rl.GetScreenHeight()
        if mu.window(ctx, "Console", mu.Rect{window_width/2-700/2, window_height/2-500/2, 700, 500}) {
            mu.layout_row(ctx, { -1 }, -25)
            mu.begin_panel(ctx, "Log Output")
            panel := mu.get_current_container(ctx)
            mu.layout_row(ctx, { -1 }, 0)
            for text in strs {
                old :=ctx.style.colors[mu.Color_Type.TEXT]
                ctx.style.colors[mu.Color_Type.TEXT] = text.color
                mu.text(ctx, strings.trim_space(text.str))
                ctx.style.colors[mu.Color_Type.TEXT] = old
            }
            mu.end_panel(ctx)
            if updated {
                panel.scroll.y = panel.content_size.y
                updated = false
            }
            submitted := false
            mu.layout_row(ctx, { -70, -1 }, 0)

            if .SUBMIT in mu.textbox(ctx, text[:], &text_len){
                mu.set_focus(ctx, ctx.last_id)
                submitted = true
            }
            if .SUBMIT in mu.button(ctx, "Submit") {
                submitted = true
            }

            if submitted == true {
                command:= strings.trim_space(string(text[:text_len]))
                text_len = 0
                strs:=strings.fields(command)
                defer delete(strs)
                if len(strs) != 0 {
                    log_raw(">", command)
                    run_command(strs[0], args=strs[1:])
                }
            }
            has_focus^ =ctx.hover_root!=nil||has_focus^
        } else {
            mu.get_container(ctx, "Console").open=true
            render^ = false
        }
    }
