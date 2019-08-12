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

puts "Voulez vous fermer les consoles des composants ? (1 ou 0)"
set terminer [gets stdin];

if { $terminer } {
	
	exec pkill xterm;

}

