#!/usr/bin/env tclsh

package require Tcl 8.6

set options {
    -sections {}
    -dirhint  include_dir
    -ext      ".conf"
    -marker   "*==============*"
    -comment  "\#"
    -backup   ".bak"
    -dryrun   off
}

proc findDir { fpath } {
    puts stderr "Looking for inclusion directory in $fpath"
    set dir ""
    set fd [open $fpath]
    while {![eof $fd]} {
        set line [string trim [gets $fd]]
        if { $line ne "" } {
            if { [string first [dict get $::options -dirhint] $line] == 0 } {
                set dir [string trim [string range $line [string length [dict get $::options -dirhint]] end]]
            }
        }
    }
    close $fd
    return $dir
}

proc sliceConf { src { dst "" } { dir "" } } {
    set separator "[dict get $::options -comment][dict get $::options -marker]"
    set hdr [list]

    # Open source file and destination file.  When we have no path for the
    # destination, we will only output the location of where the section files
    # would be (dryrun)
    set section_fd ""
    set dst_fd ""
    if { $dst ne "" } {
        set dst_fd [open $dst w]
    }
    set fd [open $src]

    while {![eof $fd]} {
        set line [gets $fd]
        if { [llength $hdr] } {
            if { [string match $separator $line] \
                        || [string index $line 0] ne [dict get $::options -comment]} {
                # End of header section, dump the header lines either in the
                # main output file, or in the section file. Note that sections
                # seems to always end up with the same marker as the one used
                # for starting the sections, but we also cope with lines that
                # are not a comment when detecting the end of the section
                # marker.
                lappend hdr $line
                if { $section_fd ne "" } {
                    foreach l $hdr {
                        puts $section_fd $l
                    }
                } elseif { $dst_fd ne "" } {
                    foreach l $hdr {
                        puts $dst_fd $l
                    }
                }
                set hdr [list];  # Section has ended, remember this!
            } elseif { [string index $line 0] eq [dict get $::options -comment] } {
                # This is a line inside the section header. We try matching
                # against the sections that we want to isolate, opening the
                # section file when appropriate.
                set name [string trim [string range $line 1 end]]
                foreach {ptn section} [dict get $::options -sections] {
                    if { [string match -nocase $ptn $name] } {
                        # Compute path to where to store the sub-section file.
                        # Cope with empty directories, even if this is unlikely
                        # to happen given how we call this procedure.
                        set fpath ${section}.[string trimleft [dict get $::options -ext] .]
                        if { $dir ne "" } {
                            set fpath [file join $dir $fpath]
                        }
                        # Open section file or just dump where it would be located
                        if { $dst_fd eq "" } {
                            puts "$section"
                        } else {
                            puts stderr "Section '$name' starting, creating section file at $fpath"
                            file mkdir [file dirname $fpath]
                            set section_fd [open $fpath w]
                        }
                    }
                }
                # Keep the line in the header
                lappend hdr $line
            }
        } elseif { [string match $separator $line] } {
            # This is the Beginning of a section header. Close previous section
            # if appropriate and start accumulating section header (until the
            # header will be closed, see above in if-statement)
            if { $section_fd ne "" } {
                close $section_fd
                set section_fd ""
            }
            lappend hdr $line;   # Start accumulating, this is our section header marker!
        } else {
            # Regular line, i.e. most lines! Just dump the line to the proper
            # configuration file: main or sub-section
            if { $section_fd ne "" } {
                puts $section_fd $line
            } elseif { $dst_fd ne "" } {
                puts $dst_fd $line
            }
        }
    }
    close $fd
    if { $dst_fd ne "" } {
        close $dst_fd
    }
}


# Separating options and arguments
set i [lsearch -exact $argv --]
if { $i >= 0 } {
    set opts [lrange $argv 0 [expr {$i-1}]]
    set argv [lrange $argv [expr {$i+1}] end]
} else {
    for { set i 0 } { $i < [llength $argv] } { } {
        if { [string index [lindex $argv $i] 0] eq "-" } {
            incr i 2
        } else {
            break
        }
    }
    if { $i > 0 } {
        set opts [lrange $argv 0 [expr {$i-1}]]
    } else {
        set opts [list]
    }
    set argv [lrange $argv $i end]
}

# Quick options parser
foreach {opt val} $opts {
    if { [dict exists $options $opt] } {
        dict set options $opt $val
    } else {
        puts stderr "!! $opt unknown option, should be [join [dict keys $options] ,\ ]"
        exit
    }
}


# Now process all files passed as arguments
foreach fpath $argv {
    set dir [findDir $fpath]
    if { $dir eq "" } {
        puts stderr "!! No inclusion directory specified, keeping $fpath as is"
    } elseif { [dict get $options -dryrun] } {
        puts $dir
        sliceConf $fpath
    } else {
        set backup ${fpath}.[string trimleft [dict get $::options -backup] .]
        puts stderr "Keeping backup at $backup"
        file rename -force -- $fpath $backup
        sliceConf $backup $fpath $dir
    }
}
