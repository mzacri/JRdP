#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.




namespace eval Pilot {
	exec cp ./source.ndr temp_SG.ndr
	set fd [open "temp_SG.ndr" a]
	puts $fd "#open fifo for reading\nset fifo \[open \"jrdp2nd\" \{RDONLY NONBLOCK\}\]\n# reads a transition on \$fifo and fires it if existing and enabled\nproc step_trans \{fifo\} \{\n# get next line (a transition name t)\nif \{\[gets \$fifo t\] >= 0\} \{\nif \[info exists ::U(\$t)\] \{\n# t exists\nif \{!\[::Petri::enabled \$Stepper::MARKING \$t\]\} \{\n# t is not enabled\nndwarning \"transition \$t not enabled\"\n\} else \{\n# t exists and is enabled, fire it\nStepper::fire_transition_1 \[list \$t\]\nStepper::fire_transition_2 \[list \$t\]\n\}\n\} else \{\n# t is unknown\nndwarning \"transition \$t unknown\"\n\} \n\}\n\}\n# calls step_trans if some data is available on \$fifo\nfileevent \$fifo readable \"step_trans \$fifo\"\n# enter stepper mode\n    proc enter_stepper {} { \n# setting view options (1 = shown, 0 = hidden)\t \nset ::tshow(names) 1\t \nset ::tshow(labels) 0\t \nset ::tshow(notes) 0\t \nset ::tshow(priorities) 0\t \n# commit changes\t \nupdate_shown\t \n# enter stepper mode\t \n::Stepper::netdraw:stepper\t \n# do not record history\t \nset ::Stepper::STEPPER(record) 0\n}\n# enter stepper mode\nafter 100 enter_stepper"
	close $fd
}
