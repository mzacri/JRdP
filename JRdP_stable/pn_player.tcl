#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Dependencies
package require vectcl;
namespace import vectcl::*;
package require genomix;
namespace import ::genomix::*;

# ------- Parameters -------------------
# If using the option --with-nd, this directory is used to create the FIFO
# to communicate with nd and the temporary ndr file.
# This can be changed to any directory with write access.
set tmp_dir "/opt/r2t2/tmp"
# Default logfile. Created in the working directory (in which is located the given .ndr file)
set log_file "jrdp_logs.txt"
# ------- End of Parameters ---------------

if { $argc < 1 || $argc > 2 } {
    error "Invalid syntax. Usage:\n
    $argv0 <pn_ndr_file> \[--with-nd\]"
}

# Extract given .ndr file directory and file infos to retrieve
# structure & configuration files attached
set pn_ndr_file [lindex $argv 0]
set working_dir [file dirname $pn_ndr_file]
set ndr_filename [file tail $pn_ndr_file]
set filename_root [file rootname $ndr_filename]
puts "Working directory: $working_dir"
set pn_struct_matrix_tcl_file [file join $working_dir "${filename_root}_struct.tcl"]
set pn_config_tcl_file [file join $working_dir "${filename_root}_config.tcl"]
set nd_fifo_file [file join $tmp_dir "jrdp2nd_fifo"]
set nd_temp_ndr_file [file join $tmp_dir "temp_sg.ndr"]

# Check for structure & configuration files
if {![file exists $pn_struct_matrix_tcl_file]} {
  error "Petri net structure file not exists" "The structure matrix file $pn_struct_matrix_tcl_file expected for
  the given ndr file $ndr_filename does not exists. Check that they belongs to the same directory and/or the ndr
  configuration script have been called first to generated these files."
}
if {![file exists $pn_config_tcl_file]} {
  error "Petri net configuration file not exists" "The configuration file $pn_config_tcl_file expected for
  the given ndr file $ndr_filename does not exists. Check that they belongs to the same directory and/or the ndr
  configuration script have been called first to generated these files."
}

# Parse options
set with_nd 0
if {$argc > 1 } {
  if { [string match [lindex $argv 1] "--with-nd"] } {
    set with_nd 1
  } else {
    puts "Unknown option: [lindex $argv 1]"
    exit 3
  }
}

namespace eval JRdP {
  #######Init Logs:
  set cur_path [pwd];
  set f [open [file join $working_dir $log_file] w+]

  puts $f "---------- LOGS :: [clock format [clock seconds] -format { %a/%b/%Y %H:%M:%S }] :: Superviseur  "

  ###### load configured files
  puts "Loading Petri net structure file..."
  source $pn_struct_matrix_tcl_file;
  puts "Setting up local data..."
  source $cur_path/src/data.tcl;
  puts "Loading Petri net configuration file..."
  source $pn_config_tcl_file;
  puts "Petri net successfully loaded"

  #source $path/Generated_Tcl/Configuration_RdP.tcl ; #Chargement Configuration
  # if { $with_nd } {
  #    source $cur_path/src/pilot_ndstepper.tcl;
  # }

  #Vérification des services fournis par les composants:
  puts "Checking actions services consistency..."
  foreach req $requetes_actions {
    set service [lindex $req 1]
    set composant [lindex $req 0]
    set transition [lindex $req 2]
    set test [catch {[join [list $composant $service] "::"] -h} exception]
    if { $test } {
      error "Configuration error." "The requested service $service is not provided by the component $composant.
       Check requested component / service in actions list of transition $transition"
    }
  }

  #Connextion avec nd:
  # XXX merge with souce nd stepper ?
  if { $with_nd } {
    puts "Connecting with nd stepper..."
    source $cur_path/src/pilot_ndstepper.tcl;

    if [catch {exec mkfifo $nd_fifo_file} ex] {
      exec rm $nd_fifo_file
      exec mkfifo $nd_fifo_file
    }
    set nd_pid [exec nd $nd_temp_ndr_file &]

    while 1 {
      set test_open [catch {set fifo [open $nd_fifo_file {WRONLY NONBLOCK}]} ex ]
      if { !$test_open } {
        break;
      }
      puts "** Waiting for connection with nd..."
      after 1500;
    }
    after 3000;
  }

  #Logs:
  puts "\n\nJRdP is starting...";
  puts "Initial marking:  ";
  affiche_marquage;

  ######Joueur de Rdp:
  set dpt 1 ; #variable depart boucle
  set cr 0 ; #compteur de tours de boucle
  set Arret 0;
  #####LOGS:

  puts $f "Nombre de transitions: $nb_t // Nombre de places: $nb_p"
  puts $f "Boucle Joueur démarre:"
  puts -nonewline $f "------Marquage Initial:  "; affiche_marquage $JRdP::f;

  ###### Boucle du joueur:
  while {$dpt} {

    #Actualisation des événements:
    update;

    ###Actualisation des états des Requetes selon l'état des services // Équivalent acquisition des entrées:
    ACTUALISATION_REQUESTS;

    #Recherche des transitions sensibilsees:
    TRANSITIONS_SENSIBILISEES;

    ###Actualisation des flags selon l'état des requetes associées aux transitions sensibilisées// Équivalent acquisition des entrées:
    ACTUALISATION_FLAGS ;

    #Générer les conditions des transitions sensibilisees à partir des flags:
    GENERATE_CONDITIONS;

    ##Évaluation de la franchissabilité des transitions:
    FIRE_TRANSITIONS ;

    ##Actions sur les transitions:
    ACTIONS_TRANSITIONS $with_nd;

    ##Actions sur les places:
    ACTIONS_PLACES;

    #Conteur de tours:
    incr cr;

    ##Condition d'arrêt:
      #puts $f "******: $Conditions_totales";             #debug

    if { $Arret==1 } {
      set dpt 0;
      puts $f "***********************FIN************************"
      close $f;
    }
  }

  #Gestion des consoles à la fin d'exécution:

  puts "Terminé! Vous pouvez vérfier les Logs\n\n"

  if { $with_nd } {
    exec rm $nd_fifo_file;  # suppresion du named pipe
    exec rm $nd_temp_ndr_file;  #suppresion du temp
  }
}
