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


namespace eval JRdP {
	
	#######Init Logs:

	set path [pwd];
	set f [open $path/Logs.txt w+]

	puts $f "---------- LOGS :: [clock format [clock seconds] -format %H:%M:%S] :: Superviseur  "

	######Chargement des dépendances:

	source $path/Generated_Tcl/Matrices.tcl; #Chargement de l'architecture du Rdp.
	source $path/Sources_Tcl/Data.tcl; #Chargement des données.
	source $path/Generated_Tcl/Configuration_RdP.tcl ; #Chargement Configuration 
	
	######Joueur de Rdp:

	set dpt 1 ; #variable depart boucle
	set cr 0 ; #compteur de tours de boucle
	set Arret 0;

	#####LOGS:

	puts -nonewline $f "------Marquage Initial:  "; affiche_marquage $f;                       
	puts $f "******Conditions initials: $Flags";
	puts $f "\nVecteur actions sur trs dans l'ordre des trs: $Actions_transitions\n" ;
	puts $f "Nombre de transitions: $nb_t // Nombre de places: $nb_p"
	puts $f "Boucle Joueur démarre:"


	###### Boucle du joueur:
	while {$dpt} {


		#Actualisation des événements:

		update;
	
		###Actualisation des états des Requetes selon l'état des services // Équivalent acquisition des entrées:
		
		ACTUALISATION_REQUESTS;

		###Actualisation des flags selon l'état des requetes // Équivalent acquisition des entrées:

		ACTUALISATION_FLAGS ;

		#Recherche des transitions sensibilsees:
	
		TRANSITIONS_SENSIBILISEES;  

		#Générer les conditions des transitions sensibilisees à partir des flags:

		GENERATE_CONDITIONS;

		 

		##Évaluation de la franchissabilité des transitions:

		FIRE_TRANSITIONS ;

		##Actions sur les transitions:
		
		ACTIONS_TRANSITIONS;
	
		##Actions sur les places:

		ACTIONS_PLACES;
	

		#Conteur de tours:

		incr cr; 
	

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
	exec pkill xterm				;	#Fin de xterm
}


