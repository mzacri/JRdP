#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.




#######Init Logs:

#set version "v2.1_test1"
#set path Bureau/Stage_LAAS/REPO/tcl/Joueur_Rdp_$version  ;#Chemin du dossier contenant Joueur_Rdp.tcl, Data.tcl et Callbacks.tcl
#set f [open $path/Logs_$version.txt w+]

set path [pwd];
set f [open $path/Logs.txt w+]



#######Chargement des packages:

puts $f "---------- LOGS :::: Superviseur  "	
package require vectcl;
namespace import vectcl::*;
package require genomix;
namespace import genomix::*;


######Chargement des dépendances:
set config "r";
while { $config=="r" } {

	source $path/Sources_Tcl/Generate_matrices.tcl; #Générer Matrices.tcl
	source $path/Generated_Tcl/Matrices.tcl; #Chargement de l'architecture du Rdp.
	source $path/Sources_Tcl/Data.tcl; #Chargement des données.
	namespace eval Script {
		source $path/Source.tcl; #Chargement script tcl de configuration
	}
	source $path/Sources_Tcl/Configuration.tcl; 

	puts "Voulez vous Commencer le Jeu du RdP,Recommencer la configuration ou Quitter? (resp 1 ou r ou q):"
	set config [gets stdin];
	switch $config {
		"1" { }
		"r" { puts "Configuration recommencée:"; }
		"q" { puts "Terminaison!" ; exit 0;}
		default { puts "Entrée non valide, veuillez recommencez la configuration" ; set config "q" }

	}
}

	source $path/Sources_Tcl/Pilot_ndstepper.tcl ; 

	#Connextion avec nd:
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
	
puts "JRdP démarre...";
puts "Marquage Initial:  "; affiche_marquage;

######Joueur de Rdp:

set dpt 1 ; #variable depart boucle
set cr 0 ; #compteur de tours de boucle
set Arret 0;

#####LOGS:

puts -nonewline $f "------Marquage Initial:  "; affiche_marquage $f;                       
puts $f "\nVecteur actions sur trs dans l'ordre des trs: $actions_transitions\n" ;
puts $f "Nombre de transitions: $nb_t // Nombre de places: $nb_p"
puts $f "Boucle Joueur démarre:"


###### Boucle du joueur:
while {$dpt} {

	#Actualisation des événements:

	update;  

	#Générer les conditions totales à partir des flags de chaque transition :

	GENERATE_CONDITIONS_TOTALES;

	#Conteur de tours:

	incr cr;  

	##Évaluation de la franchissabilité des transitions:

	FIRE_TRANSITIONS ;

	##Actions sur les transitions:

		for {set t 0} {$t < $nb_t} { incr t } {

			#Choix des transitions valides:
			if { [vexpr { T[t,0] != 0 }] } { 
				
				set systemTime [clock seconds]
				#Appel des servies associées à la transition tirée ( dans l'ordre des transtions ):
				foreach commande [lindex $actions_transitions $t] {
					eval $commande;
				}

				puts $f "------Transition t$t tirée à [clock format $systemTime -format %H:%M:%S]"
				puts -nonewline $f "------Evolution Marquage après $cr tour boucle :";affiche_marquage $f;# Logs <--Marquage 
				puts "------Transition t$t tirée à [clock format $systemTime -format %H:%M:%S]"
				puts  "------Evolution Marquage après $cr tour boucle :";affiche_marquage;# Logs <--Marquage	
				set cr 0;

				#Communication avec nd à travers le named pipe fifo:
				puts $fifo "t$t"
				flush $fifo
			
			}	
		

		}

	
	##Actions sur les places:

	ACTIONS_PLACES;
	
	##Réinitialisation vecteur "marquage" des transitions valides:

	vexpr { T=zeros(nb_t,1); } 

	##Condition d'arrêt:
	#puts $f "******: $Conditions_totales";             #debug
	if { $Arret==1} { 
		set dpt 0;
		puts $f "***********************FIN************************"
		close $f;
	}

	
 	
}

puts "Terminé! Vous pouvez vérfier les Logs"

exec pkill roscore 				;	#Fin de roscore 
exec pkill genomixd				;	#Fin de genomixd
exec  rm jrdp2nd;  #suppresion du named pipe
exec rm temp_SG.ndr;  #suppresion du temp

puts "Voulez vous fermer les consoles des composants ? (1 ou 0)"
set terminer [gets stdin];

if { $terminer } {
	
	exec pkill xterm;
	exec kill -9 $nd_pid

}

