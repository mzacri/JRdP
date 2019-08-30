#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.




#############################################################( À NE PAS CHANGER )########################################################################

#I-Définitions structures de données:

	#1----fonction:créer une liste vide: 

		proc liste_vide { length } {
			set liste "";
			for { set i 0 } { $i < $length } { incr i } { lappend liste "" }
			return $liste
		}

	#2----fonction:créer une liste de dictionnaires: 

		proc liste_arrays { length } {
			set liste "";
			for { set i 0 } { $i < $length } { incr i } {
		
				lappend liste [array set l { }]
			}
			return $liste
		}

	#3----Définitions des variables internes: 

		vexpr {
			T=zeros(nb_t,1);					#Vecteur validité transition	
			Conditions_totales=zeros(nb_t); 			#Vecteur condition totale  sur les Transitions. 
		}

		
		set actions_transitions [liste_vide $nb_t]; 			#Init vecteur actions_transitions : contient les actions sur chaque transition

		set Flags_cond [liste_vide $nb_t];				#vecteur formule logique de la transition.


#II-Définition des fonctions internes au joueur:

	#4----fonction association modification_variable-service: 


		proc associer_script_transition { transition script } {

			global actions_transitions;

			##test:
	
			##corps:
			set act [lindex $actions_transitions $transition]; 
			set commande [join [list "namespace eval Script {" "eval \{ $script \}" "}"] ""];
	
			lappend act $commande;
			lset actions_transitions  $transition $act;

	
		}



	#5-----fonction pour charger les composants:

		proc Load_components { handle components } {

			foreach component $components {  #Chargement des composants
				global f;
				exec xterm -hold -e $component-ros & ;
				after 500;
				$handle load $component
				puts $f "::::: $component chargé sur $handle :::::";

			}

		}

	#6----fonction connection port ($component1 : port in ; $component2 : port out):


		proc Connect_port { port_name1 component1  port_name2 component2 } {
			global f;
			eval [join [list "$component1" "::connect_port $port_name1 $component2" "/$port_name2"] ""];
			puts $f "$component1 connecté à $component2 à travers $port_name";

		}



	#7---Lancement du deomon genomix:

		proc genomix {} {
			global f;
			exec gnome-terminal -e roscore & 	;				#chargement de roscore
		
			while {1} {
				set status [catch {exec rostopic list} result];   #attente roscore
				puts "En attente de démarrage de roscore..."
				if { $status == "0" } {
					exec gnome-terminal -e genomixd &;             #chargement de genomixd
					break;
			
				} 
				after 500;
			}
		
			while {1} {
				set status [catch {set handle [genomix::connect] ;} result];   #attente roscore
				puts "En attente de démarrage de Genomixd..."
				if { $status == "0" } {
					break;
				} 
				after 100;
			}
			  
			puts $f "::::: Deamon genomix démarré: $handle ::::: ";			#LOGS

			return $handle;


		}


	#8----fonction génération de la condition de tirage d'une transition:


		proc Generate_Firing_Condition { tr } {
	
			#Générer la condition de tirage de la tranition tr à partir de la Condition_totale et le marquage M: 		
			global f;
			global Pre;
			global Conditions_totales;
			global M; 
			vexpr {	
				#comparaison marquage pre:
				v_comp=(M>Pre[:,tr])||(M==Pre[:,tr]) 				
				comp=1
			}
	
			#puts $f " ///////// $v_comp";									 #debug comparaison marquage pre
			foreach c $v_comp {
				vexpr {comp=comp*c;}
			}
	
			vexpr { cond= comp*Conditions_totales[tr] }  
			#puts $f "*****Transition $tr (valide 1 ou pas 0): $cond "; 					 #debug Sensibilisation des transitions 

	
		return $cond

		}	



	
	#10---fonction tirage transitions:

		proc FIRE_TRANSITIONS {} {
			global T;
			global nb_t;
			global M;
			global Post;
			global Pre;
			for {set t 0} {$t < $nb_t} { incr t } {
				if { [Generate_Firing_Condition $t] } {
					vexpr {
						#"Marquage" des transitions valides
						T[t,0]=1.0;  #dimension mismatch si 1 au lieu de 1.0
					}	
				}
			}
			##Évolution du Rdp:

			vexpr { M=M+Post*T-Pre*T; }
			
			
			##Detection Non déterminisme:
			foreach marquage $M {
				if { [lindex $marquage 0] < 0 } { 
					puts "JRdP_ERROR:Non déterminsme detecté! \nLe marquage négative représente la place sujet de non déterminisme:";				
					affiche_marquage; 
					exit 1;
				}
			} 

		}

	

	#11---fonction formulation de la condition à partir des flags associées:

		proc GENERATE_CONDITIONS_TOTALES { } {
			namespace eval Script {
				for {set t 0} {$t<$::nb_t} { incr t } {
					set cond "0.0";
					set exprn [lindex $::Flags_cond $t]
					set exception "";
					if { !([catch { expr $exprn } exception] && [regexp "no such variable" $exception]) } {
						set cond [expr $exprn ]
					} 
					lset ::Conditions_totales $t $cond

		
				}
			}

		}

	





	#112----fonction marquage place:

		proc marquage_place { place } {
			global M;
			return [lindex $M $place]
		}


	#13----fonction affichage marquage:

		proc affiche_marquage {{out "stdout"}} {
			global nb_p;
			global M;
			set lst "";
			for { set p 0 } { $p < $nb_p } { incr p } {
				set m [lindex $M $p];
				if { $m != 0 } {
				lappend lst " P$p :: $m  "
				}
	
			}
			puts $out $lst

		}

      ##13----fonction de gestion de TIMER:
		proc TIMER { time_ref time_target { precision 0 } } {
			set time_clock [clock seconds]
			set time_clock [expr $time_clock - [join [list "\$Script" "::" $time_ref] ""]]
			if { [expr ($time_target - $time_clock) <= $precision] && [expr ($time_target - $time_clock) >= -1*$precision] } {
				return 1;	
			} else {
				return 0;
			} 	
	
		}



	
