#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#######Chargement des packages:
package require vectcl;
namespace import vectcl::*;
package require genomix;
namespace import ::genomix::*;

if { $argc != 1 } {
    puts "Invalid syntax. Usage:"
    puts "$argv0 <ndr_input_file>"
    exit 2
}

namespace eval JRdP {

  set ndr_file [lindex $argv 0]

	#######Init Logs:

	set path [pwd];
	set f [open $path/Logs.txt w+]

	puts $f "---------- LOGS :: [clock format [clock seconds] -format { %a/%b/%Y %H:%M:%S }] :: Superviseur  "

	######Chargement des dépendances:

	set config "r";
	while { $config=="r" } {

		source $path/Sources_Tcl/Generate_matrices.tcl; #Générer Matrices.tcl
		source $path/Generated_Tcl/Matrices.tcl; #Chargement de l'architecture du Rdp.
		source $path/Sources_Tcl/Data.tcl; #Chargement des données.
		source $path/Sources_Tcl/Generate_configuration.tcl; #Générer Configuration_RdP.tcl

		puts "Voulez vous Commencer le Jeu du RdP (1), Recommencer la configuration (r) ou Quitter (q)? :"
		set config [gets stdin];
		switch $config {
			"1" { }
			"r" { puts "Configuration recommencée:"; }
			"q" { puts "Terminaison!" ; exit 0;}
			default { puts "Entrée non valide, veuillez recommencez la configuration" ; set config "r" }

		}
	}

	source $path/Generated_Tcl/Configuration_RdP.tcl ; #Chargement Configuration
	source $path/Sources_Tcl/Pilot_ndstepper.tcl ; #Chargement Configuration

	#Vérification des services fournis par les composants:

	foreach req $requetes_actions {
		set service [lindex $req 1]
		set composant [lindex $req 0]
		set transition [lindex $req 2]
		set test [catch {[join [list $composant $service] "::"] -h} exception]
		if { $test } {
			puts "Config_ERROR:Le service $service n'est pas fourni par le composant $composant. Vérifier le nom du composant et le nom de service dans les actions de la transition $transition"
			exec pkill xterm; exec pkill genomixd; exec pkill roscore; exit 1;
		}
	}

	# Connexion avec nd:
	if [catch {exec mkfifo jrdp2nd} ex] {
		exec rm jrdp2nd
		exec mkfifo jrdp2nd
	}
	set nd_pid [exec nd temp_SG.ndr &]


	while 1 {
		set test_open [catch {set fifo [open jrdp2nd {WRONLY NONBLOCK}]} ex ]

		if { !$test_open } {
			break;
		}
		puts "En attente de connexion avec nd...."
		after 1500;
	}



	#Logs:
	puts "\n\nJRdP démarre...";
	puts "Marquage Initial:  "; affiche_marquage;

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

		## Actualisation des événements:

		update;

		## Actualisation des états des Requetes selon l'état des services // Équivalent acquisition des entrées:

		ACTUALISATION_REQUESTS;

		## Recherche des transitions sensibilsees:

		TRANSITIONS_SENSIBILISEES;

		## Actualisation des flags selon l'état des requetes associées aux transitions sensibilisées// Équivalent acquisition des entrées:

		ACTUALISATION_FLAGS ;

		## Générer les conditions des transitions sensibilisees à partir des flags:

		GENERATE_CONDITIONS;

		## Évaluation de la franchissabilité des transitions:

		FIRE_TRANSITIONS ;

		## Actions sur les transitions:

		ACTIONS_TRANSITIONS;

		## Actions sur les places:

		ACTIONS_PLACES;

		# loop count:
		incr cr;


		##Condition d'arrêt:

			#puts $f "******: $Conditions_totales";             #debug

		if { $Arret==1} {
			set dpt 0;
			puts $f "***********************FIN************************"
			close $f;
		}



	}

	#Gestion des consoles à la fin d'exécution:

	puts "Terminé! Vous pouvez vérfier les Logs\n\n"

	exec pkill roscore 				;	#Fin de roscore
	exec pkill genomixd				;	#Fin de genomixd
	exec  rm jrdp2nd;  # suppresion du named pipe
	exec rm temp_SG.ndr;  # suppresion du temp

	puts "Voulez vous fermer les consoles des composants et le stepper nd ? (1 ou 0)"
	set terminer [gets stdin];

	if { $terminer } {
		exec kill -9 $nd_pid
		exec pkill xterm;

	}
}
