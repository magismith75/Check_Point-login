#!/usr/bin/expect -f

# ===============================
# Global settings
# ===============================
set timeout 30
set success_file "success.log"
set success_count 0

# حذف ملف النجاحات القديم إن وجد
if {[file exists $success_file]} {
    file delete -force $success_file
}

# ===============================
# Arguments
# ===============================
if {$argc != 3} {
    puts "Usage: $argv0 <ips_file> <users_file> <passwords_file>"
    exit 1
}

set ips_file       [lindex $argv 0]
set users_file     [lindex $argv 1]
set passwords_file [lindex $argv 2]

# ===============================
# Read file into list
# ===============================
proc read_file_to_list {filename} {
    if {![file exists $filename]} {
        puts "ERROR: File not found: $filename"
        exit 1
    }

    set fh [open $filename r]
    set data {}

    while {[gets $fh line] != -1} {
        set line [string trim $line]
        if {$line ne ""} {
            lappend data $line
        }
    }

    close $fh
    return $data
}

set ips       [read_file_to_list $ips_file]
set users     [read_file_to_list $users_file]
set passwords [read_file_to_list $passwords_file]

# ===============================
# Validate list sizes
# ===============================
set count_ips       [llength $ips]
set count_users     [llength $users]
set count_passwords [llength $passwords]

if {$count_ips != $count_users || $count_users != $count_passwords} {
    puts "ERROR: Files must have the same number of lines"
    exit 1
}

puts "INFO: Starting VPN login attempts ($count_ips combinations)"

# ===============================
# Main Loop
# ===============================
for {set i 0} {$i < $count_ips} {incr i} {

    set server   [lindex $ips $i]
    set user     [lindex $users $i]
    set password [lindex $passwords $i]

    puts "INFO: Attempt [expr {$i + 1}] -> user=$user server=$server"

    set login_result "fail"

    spawn cp_client -m l -u $user $server

    expect {
        -re "(?i)password" {
            send -- "$password\r"
            exp_continue
        }

        -re "(?i)standard login" {
            exp_continue
        }

        -re "(?i)configuring vna\\." {
            set login_result "success"
        }

        -re "(?i)failed|error|denied" {
            set login_result "fail"
        }

        timeout {
            puts "ERROR: Timeout while connecting to $server"
            set login_result "fail"
        }

        eof {
            # انتهاء الجلسة بدون نجاح صريح
        }
    }

    if {$login_result eq "success"} {
        puts "SUCCESS: user=$user server=$server"
        set fh [open $success_file a]
        puts $fh "$user $server"
        close $fh
        incr success_count
    } else {
        puts "WARNING: Login failed for user=$user server=$server"
    }
}

# ===============================
# Final Result
# ===============================
if {$success_count > 0} {
    puts "INFO: Total successful logins: $success_count"
    exit 0
} else {
    puts "ERROR: No successful VPN logins"
    exit 1
}
