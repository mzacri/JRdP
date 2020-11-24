#© 2019 CNRS-LAAS

#Author: M’Barek Zacri

#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#############################################################( À NE PAS CHANGER )########################################################################

## Les procédures déclarées ci-dessous sont des encapsulations de codes plutôt que des procédures portables. Les structures de données déclaré dans ::JRdP sont utilisées parfois dans le scope des procédures. Au lieu d'utiliser Upvar et donc s'obliger à les passer comme paramètres des fonctions (la chose que j'évite), J'utilise directement le namespace JRdP::. Un équivalent intéressant dans C sera d'utiliser le mot clé static dans le scope ::JRdP pour les structures utilisées dans les procédures. uplevel dans les procédures peut marcher, mais j'ai voulu garder l'aspect temporaire des variables locales.
## Toute proposition de développement est la bienvenue: mzacri@gmail.com

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

			Transitions_sensibilisees=zeros(nb_t);		#Vecteur  transitions sensibilisées ( marquage des places prétransition différent de zero ).
			Transitions_valides=zeros(nb_t);		#Vecteur  transitions valides ( tirables )

			Conditions=zeros(nb_t); 			#vecteur conditions sur les Transitions: Transition sensibilisée + condition valide = transition valide ).

		}


		set Flags [liste_arrays $nb_t];  				#vecteur association Flags et  Transitions.
		set Actions_transitions [liste_vide $nb_t]; 			#vecteur Actions_transitions : contient les actions sur chaque transition.

		#pour gérer les transitions non tracés graphiquement:
		proc liste_pas_vide { length } {
			set liste "";
			for { set i 0 } { $i < $length } { incr i } { lappend liste "expr 0" }
			return $liste
		}
		set Flags_cond [liste_pas_vide $nb_t];				#vecteur formule logique de la transition.

#II-Définition des fonctions internes au joueur:

	#1-----fonction pour charger les composants:
		proc Load_components { handle components } {
			foreach {component inst_nom} $components {
        # Chargement des composants
				#exec xterm -sl 50000 -hold -e $component-ros -i $inst_nom & ;
				puts "Loading $component to $handle"
				while {1} {
					if ![catch {set status [exec rostopic list | grep -c $inst_nom ]} ex] {
						if { $status !=0 } {
							$handle load $component -i $inst_nom;
							puts $JRdP::f "::::: $component chargé sur $handle :::::";
							break;
						}
					}
					puts "En attente de démarrage de $component as $inst_nom..."
					after 500;
				}
			}
		}

	#2----fonction connection port ($component1 : port in ; $component2 : port out):
		proc Connect_port { port_name1 component1  port_name2 component2 } {
			global f;
			set status [catch {eval [join [list "$component1" "::connect_port $port_name1 $component2" "/$port_name2"] ""]} result];
			if { $status == "0" } {
				puts $JRdP::f "$component1 connecté à $component2 à travers $port_name1/$port_name2";
			} else {
				error "Ports connection" "Cannot connect $component1 to $component2 via $port_name1/$port_name2. Please check if remote components are loaded and port exists."
			}	
		}

	#3---Lancement du deomon genomix:
		proc genomix {hostname_port} {
			puts "Connecting to genomixd demon: $hostname_port ..."
			set status [catch {set handle [genomix::connect $hostname_port] ;} result];   #attente roscore
			if { $status == "1" } {
				puts $result
				error "Genomix connection" "Unable to connect to $hostname_port"
			}
			puts $JRdP::f "::::: Deamon genomix démarré: $handle ::::: ";			#LOGS
			return $handle;
		}

	#4----fonction association transition-service:
		proc associer_service_transition { transition nom_composant nom_service { parametres "" } } {
			set act [lindex $JRdP::Actions_transitions $transition];
			set request  [join [list "$nom_composant" "_$nom_service" "_t$transition"] ""];
			set ::JRdP::inst_$request 1;
			set commande [join [list "incr ::JRdP::inst_$request;set " "::JRdP::$request" "  \[::$nom_composant" "::$nom_service -s $parametres &\] ;"] ""];
			set commande [join [list $commande "set ::JRdP::Requests_status($request) \[list \"zero\" \"result\" \]" ] ";"]
			lappend act $commande;
			lset JRdP::Actions_transitions  $transition $act;
		}

	#5----fonction association script-service:
		proc associer_script_transition { transition script } {
			set act [lindex $JRdP::Actions_transitions $transition];
			set commande [join [list "namespace eval Script {" "eval \{$script\}" "}"] ""];
			lappend act $commande;
			lset JRdP::Actions_transitions  $transition $act;
		}

	#6----fonction association d'un Flag de transition à une Requête de service:
		proc sensibilise_transition_service { transition id_req status {result "default"} } {
			array set l [lindex $JRdP::Flags $transition];
			set l($id_req)  [list "0.0" "$status" "$result" "0"];
			lset JRdP::Flags $transition [array get l];
		}

	#7----fonction marquage place:
		proc marquage_place { place } {
			return [lindex $JRdP::M $place]
		}

	#8----fonction affichage marquage:
		proc affiche_marquage {{out "stdout"}} {
			set lst "";
			for { set p 0 } { $p < $JRdP::nb_p } { incr p } {
				set m [lindex $JRdP::M $p];
				if { $m != 0 } {
				lappend lst " P$p :: $m  "
				}
			}
			puts $out $lst
		}

  	#10----fonction de gestion de TIMER:
		proc TIMER { time_ref time_target { precision 0 } } {
			set time_clock [clock seconds]
			set time_clock [expr $time_clock - [join [list "\$Script" "::" $time_ref] ""]]
			if { [expr ($time_target - $time_clock) <= $precision] && [expr ($time_target - $time_clock) >= -1*$precision] } {
				return 1;
			} else {
				return 0;
			}
		}

	#11----fonction donne les transitions sensibilisés:
		proc TRANSITIONS_SENSIBILISEES { } {
			for { set t 0 } { $t < $JRdP::nb_t } { incr t } {
				#Générer la condition de tirage de la tranition t à partir de la Condition_totale et le marquage M:
				vexpr {
					#comparaison marquage pre:
					v_comp=(JRdP::M>JRdP::Pre[:,t])||(JRdP::M==JRdP::Pre[:,t])
					comp=1
				}
				#puts $JRdP::f " ///////// $v_comp"; #debug comparaison marquage pre
				foreach c $v_comp {
					vexpr {comp=comp*c;}
				}
				lset JRdP::Transitions_sensibilisees $t $comp
			}
		}

	#12----fonction pour actualiser l'état des services :
		proc ACTUALISATION_FLAGS {} {
			for { set t 0 } { $t < $JRdP::nb_t } { incr t } {
				#Pour les transitions sensibilisées:
				if [lindex $JRdP::Transitions_sensibilisees $t] {
					foreach {request lst}  [lindex $JRdP::Flags $t] {
						if {[info exists ::JRdP::Requests_status($request)] } {
							set liste $::JRdP::Requests_status($request);
							set status [lindex $liste 0]
							set exception [lindex $liste 1]
							set req ::JRdP::inst_$request
							#Mise à jour de la valeur du Flag:
							if { $status == [lindex $lst 1] } {
								lset lst 0 "1.0";
								#Remise à 0 si:
								if { ( $status == "error" && [lindex $lst 2] != [dict get $exception ex] && [lindex $lst 2] != "default") || [expr $$req] == [lindex $lst 3] } {
										lset lst 0 "0.0";
								}
							} else {
								lset lst 0 "0.0";
							}
							array set l [lindex $JRdP::Flags $t];
							set l($request) $lst;
							lset JRdP::Flags $t [array get l];
							array unset l;
						}
					}
				}
			}
		}


	#13----fonction actualisation status requetes:

		proc ACTUALISATION_REQUESTS {} {
			foreach {request lst} [array get ::JRdP::Requests_status] {
				set req ::JRdP::$request
        # puts "***** Request: $request"
				if {  [info exists $req] } {
					set status [[expr $$req] status]
          puts "***** Request: $request"
          puts "\tStatus: $status"
					set liste $::JRdP::Requests_status($request);
					set old_status [lindex $liste 0]
					if { $old_status != $status } {
						lset lst 0 $status
						puts $JRdP::f "Report: $request on $status";
						puts  "Report: $request on $status";
						if { $status == "error"  } {
							catch {[expr $$req] result} excep
							lset lst 1 $excep
							puts $JRdP::f "Error $request details: $excep";
							puts  "Error $request details: $excep";
							unset $req
						} elseif { $status == "done" } {
							set result [[expr $$req] result];
							lset lst 1 $result
							puts $JRdP::f "Result $request : $result";
							puts  "Result $request : $result";
							unset $req
						}
						set ::JRdP::Requests_status($request) $lst;
					}
				}
			}
		}

    #13 --- Retrieves the result of a request
    # var_name (optional): name of the variable for which the value must be returned
  	proc result_req { request {var_name ""} } {
  		set liste $::JRdP::Requests_status($request);
  		set result [lindex $liste 1]
      if { $var_name eq ""} {
        # no variable name specified -> the attribute / function must out
        # only one variable that will be automatically returned,
        # otherwise returns error
        if { [dict size $result] != 1 } {
          error "Invalid result_req usage" "The service returns [dict size $result] variables,
          so the name of the returned variable to be evaluated must be given."
        }
        # at this point $result must be only a pair <variable> <value>
        set out [lindex $result 1]
      } else {
        # use specified variable name to retrieve corresponding value
        if { ![dict exists $result $var_name] } {
          error "Invalid result_req variable name" "Given variable name to be evaluated $var_name,
          does not exists in list of result request variables: [dict keys $result]"
        }
        set out [dict get $result $var_name]
      }
      return $out
  	}

	  #14---fonction tirage transitions:
		proc FIRE_TRANSITIONS {} {
			for {set t 0} {$t < $JRdP::nb_t} { incr t } {
				if { [expr [lindex $JRdP::Conditions $t] * [lindex $JRdP::Transitions_sensibilisees $t] ] } {

					lset JRdP::Transitions_valides $t 1.0;
				} else {

					lset JRdP::Transitions_valides $t 0.0;
				}
			}
			##Évolution du Rdp:
			uplevel 1 {
				vectcl::vexpr { M=M+Post*Transitions_valides-Pre*Transitions_valides; }
			}

			##Detection Non déterminisme:
			foreach marquage $JRdP::M {
				if { [lindex $marquage 0] < 0 } {
					puts "JRdP_ERROR:Non déterminsme detecté! \nLe marquage négative représente la place sujet de non déterminisme:";
					affiche_marquage;
					exit 1;
				}
			}
		}

	#15---fonction formulation de la condition à partir des flags associées:
		proc GENERATE_CONDITIONS { } {
			for {set t 0} {$t<$JRdP::nb_t} { incr t } {
				#On génére les conditions des transitions sensibilisées
				if [lindex $JRdP::Transitions_sensibilisees $t] {
					set cond "0.0";
					array set Script::lst_temp [lindex $JRdP::Flags $t];
					set exprn [lindex $JRdP::Flags_cond $t]
					set cond [eval $exprn ]
					lset JRdP::Conditions $t $cond
				} else {
					lset JRdP::Conditions $t 0.0;
				}
			}
		}

	#16----Actions sur les transitions:
		proc ACTIONS_TRANSITIONS {} {
			for {set t 0} {$t < $JRdP::nb_t} { incr t } {
				#Choix des transitions valides:
				if { [lindex $JRdP::Transitions_valides $t] } {
					set systemTime [clock seconds]
					#Appel des servies associées à la transition tirée ( dans l'ordre des transtions ):
					foreach commande [lindex $JRdP::Actions_transitions $t] {
						eval $commande;
					}

					#Marquage local ( au niveau du flag ) , sur tirage de la transition , des requetes qui existent ( lancées ) et dont le statut est différent de "sent".
					foreach {request lst} [lindex $JRdP::Flags $t] {
						set flag [lindex $lst 0]
						set status [lindex $lst 1]
						if {$flag == 1 && $status != "sent" } {
							set req ::JRdP::inst_$request
							lset lst 3 [expr $$req]; #sauvgarde de la dernière requête qui a validé le flag ( en dehors du status "sent" )
							array set l [lindex $JRdP::Flags $t];
							set l($request) $lst;
							lset JRdP::Flags $t [array get l];
							array unset l;
						}
					}

					puts $JRdP::f "------Transition t$t tirée à [clock format $systemTime -format %H:%M:%S]"
					puts -nonewline $JRdP::f "------Evolution Marquage après $JRdP::cr tour boucle :";affiche_marquage $JRdP::f;# Logs <--Marquage
					puts "------Transition t$t tirée à [clock format $systemTime -format %H:%M:%S]"
					puts  "------Evolution Marquage après $JRdP::cr tour boucle :";affiche_marquage;# Logs <--Marquage
					set JRdP::cr 0;

					#Communication avec nd à travers le named pipe fifo:
					uplevel 1 {
						if { $with_nd } {
							puts $JRdP::fifo "t$t"
							flush $JRdP::fifo
						}
					}
				}
			}
		}
