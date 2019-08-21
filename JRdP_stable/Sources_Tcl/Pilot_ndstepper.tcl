namespace eval Pilot {
	exec cp ./source.ndr temp_SG.ndr
	set fd [open "temp_SG.ndr" a]
	puts $fd "#open fifo for reading\nset fifo \[open \"jrdp2nd\" \{RDONLY NONBLOCK\}\]\n# reads a transition on \$fifo and fires it if existing and enabled\nproc step_trans \{fifo\} \{\n# get next line (a transition name t)\nif \{\[gets \$fifo t\] >= 0\} \{\nif \[info exists ::U(\$t)\] \{\n# t exists\nif \{!\[::Petri::enabled \$Stepper::MARKING \$t\]\} \{\n# t is not enabled\nndwarning \"transition \$t not enabled\"\n\} else \{\n# t exists and is enabled, fire it\nStepper::fire_transition_1 \[list \$t\]\nStepper::fire_transition_2 \[list \$t\]\n\}\n\} else \{\n# t is unknown\nndwarning \"transition \$t unknown\"\n\} \n\}\n\}\n# calls step_trans if some data is available on \$fifo\nfileevent \$fifo readable \"step_trans \$fifo\"\n# enter stepper mode\nStepper::netdraw:stepper"
	close $fd
}
