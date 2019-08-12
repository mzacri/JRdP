

#############################################################( À NE PAS CHANGER )########################################################################

#I-Définitions structures de données:

	#1----fonction:créer une liste vide: 

		proc liste_vide { length } {
			set liste "";
			for { set i 0 } { $i < $length } { incr i } { lappend liste "" }
			return $liste
		}

	#2----fonction:créer une liste de dictionnaire: 

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

		set Flags [liste_arrays $nb_t];  				#vecteur association Flags et  Transitions.
		
		set actions_transitions [liste_vide $nb_t]; 			#Init vecteur actions_transitions : contient les actions sur chaque transition

		set Flags_cond [liste_vide $nb_t];				#vecteur formule logique de la transition.

#II-Définition des fonctions internes au joueur:


	#1----fonction Initialisation de marquage d'une place donnée à 1:  


		proc Init_Marquage { place nbr_jeton } {
			#test:
			global nb_p;
			global M;
			if { $place >= $nb_p || $place <0 } { puts "Init_Marquage report: place non valable" }
			#corps:
			vexpr {
				nbr_jeton=nbr_jeton*1.0;
				M[place,0]=nbr_jeton;	 						
			}
		
		}


	#2-----fonctions de gestion de la sensibilisation des transitions par les callbacks des services:

	
		proc Init_MAU_conditions_transition { transition } {
			#test:

			global nb_t;
			if { $transition >= $nb_t || $transition <0 } { puts "Init_conditions report: transition non valable" }
	
			#corps:

	
			global Flags;
			array set l [lindex $Flags $transition];
			set l(CI)  [list "1.0" "" ""];
			lset Flags $transition [array get l];
		}

	
	
	#3----fonction association transition-service: 


		proc associer_service_transition { transition nom_composant nom_service { parametres "" } } {

			global actions_transitions;

			##test:
	
			##corps:
			set act [lindex $actions_transitions $transition]; 

			set request  [join [list "$nom_composant" "_$nom_service" "_t$transition"] ""];
			set commande [join [list "set " "$request" "  \[::$nom_composant" "::$nom_service -s $parametres &\] ;"] ""];
	
			lappend act $commande;
			lset actions_transitions  $transition $act;

	
		}


	#4----fonction association d'un Flag de transition à une Requête de service: 


		proc sensibilise_transition { transition id_req status {exception ""} } {

			global Flags;
			array set l [lindex $Flags $transition];
			set l($id_req)  [list "0.0" "$status" "$exception"];
			lset Flags $transition [array get l];
	
		}

	#4'----fonction inverse de 4: 


		proc supprime_sensibilisation_transition { transition id_req } {

			global Flags;
			array set l [lindex $Flags $transition];
			array unset l $id_req;
			lset Flags $transition [array get l];
	
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



	#9----fonction pour actualiser l'état des services :

		proc ACTUALISATION_FLAGS {} {
			global nb_t;
			global f;
			global Flags;
	
			for { set t 0 } { $t < $nb_t } { incr t } {

				foreach {request lst}  [lindex $Flags $t] { 
					global $request ;
					
					set test [info exists $request];
					set liste $lst;
					if { $test && $request!="CI" } {
						#puts $f "!!!!!report: $request on [ [expr $$request] status]";   #DEBUG

						if { [string first "not" [lindex $lst 1]]!=-1 } {
							set stat [lindex [split [lindex $lst 1] "-"] 1];
							if { ([[expr $$request]  status]!=$stat) && ([[expr $$request]  status]!="none") } { 
						
								lset liste 0 "1.0";
								
							}
							 
						} else {
							if { [ [expr $$request]  status]==[lindex $lst 1] } { 
						
								lset liste 0 "1.0";
								if { [lindex $lst 1]== "error" && [lindex $lst 2]!= "" } {
									catch {$request result} excep;
									if { [lindex $lst 2]!= [dict get $excep ex] } {
										lset liste 0 "0.0";
									}
								}
			
							}
						}

						

					} else {
						lset liste 0 "0.0";
		  			}
					array set l [lindex $Flags $t];
					set l($request) $liste;
					lset Flags $t [array get l];
					array unset l;

				}	
			}

		
		}





	#10---fonction tirage transitions:

		proc FIRE_TRANSITIONS {} {
			global T;
			global nb_t;
			for {set t 0} {$t < $nb_t} { incr t } {
				if { [Generate_Firing_Condition $t] } {
					vexpr {
						#"Marquage" des transitions valides
						T[t,0]=1.0;  #dimension mismatch si 1 au lieu de 1.0
					}	
				}
			}
		}

	

	#11---fonction formulation de la condition à partir des flags associées:

		proc GENERATE_CONDITIONS_TOTALES { } {
	
			global Flags;
			global Flags_cond;
			global Conditions_totales;
			global nb_t;
			for {set t 0} {$t<$nb_t} { incr t } {
				set cond "0.0";
				array set lst_temp [lindex $Flags $t];
				set exprn [lindex $Flags_cond $t]  
				if { [regexp -nocase {[a-z]} $exprn] } {
					set cond [expr $exprn ]
					lset Conditions_totales $t $cond
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

      ##13----fonction affichage info transitions:

		proc info_transitions { } {
			global f;
			global actions_transitions;
			global Flags;
			global nb_t;

			for {set t 0} {$t < $nb_t} { incr t } {
				
			}
			
			
		}

	
