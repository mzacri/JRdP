namespace eval Generate_config {
	puts "Voulez vous générer la configuration du RdP à partir le fichier Source_Graphique.ndr? (1 ou 0):"
	set gen [gets stdin];


	#I----Encapsulation de code ( contexte d'appel important ):

		#Ecriture dans le buffer Config ( Congiguration_RdP ) :

		proc Ecriture_Config { components transitions Script ports places } { 
			puts $JRdP::Generate_config::Config "##### I- Chargement des composants \n\nset handle \[genomix\]; #Lancement deomon genomix , roscore et serveur genomix à l'aide du macro genomix\nset components { $components };  	#Modifiable		#Composant .s à charger\nLoad_components \$handle \$components ; #Chargement des composants (components) sur le deamon genomix (handle)\n\n##### II- Connection des capteurs:\n#---syntax: Connect_port \$port_name \$component1(port in) \$component2(port out)\n\n$ports \n\n##### III- Script_TCL :\n\nnamespace eval Script {\n\t$Script\n\n}\n\n##### V- Structure dynamique du RdP ( association transition service conditions ) :\n\n$transitions \n\n#### VI- actions sur les places:\n\n proc ACTIONS_PLACES {} { \n\tglobal f;\n\tglobal Arret;\n\t$places\n}\n"
			puts $JRdP::Generate_config::Config "###À ne pas modifier:\nset Flags_cond [list $JRdP::Flags_cond]\nset requetes_actions [list $JRdP::Generate_config::requetes_actions]\n"
		}

		#Traitement des scripts contenu dans les conditions:


		proc Traitement_script_dans_conditions { transition scripts conditions components transitions script ports places } { 	

			if { [llength $scripts]>0 } {
				set flag_conditions_script 1;
				#Pour chaque formule dans scripts
				foreach script_untrimmed $scripts {
					set script [string trimright [string trimleft $script_untrimmed " ?"] "?"] 
					if { [regexp -nocase {[a-z0-9]} $conditions] } {
						#Ajout de la fonction nécessaire dans la variable transitions:
						set transitions [join [list $transitions "\t# sensibilise partiellement la transition $transition sur la formule $script \n"] ""] 	
						#Substitition de script_untrimmed par script trimmed dans conditions:
						set conditions [regsub "***=$script_untrimmed" $conditions " $script "];	

					} else {
						puts "Config_ERROR: Configuration de la condition sur la variable $id_var de la transition $transition n'est pas valable ! \n"
						Ecriture_Config $components $transitions $script $ports $places; exit 1;
					}
	

				}

			}

			return [list $conditions $transitions]
		}


		#Traitement des services contenu dans les conditions:

		proc Traitement_services_dans_conditions { transition services conditions components transitions script ports places requetes_conditions } { 

			if { [llength $services]>0 } {
				#Variables:
				set id_request ""; #nom du requete
				set request_splitted ""; #son contenu
				#Pour chaque requete dans services
				foreach service $services {
					set request [string trimright [string trimleft $service " /"] "/"]
					#Séparation sur les espaces:
					set request_splitted [regexp -all -inline {\S+} $request]
					#Premier indice est le nom de la service
					set id_request [lindex $request_splitted 0]
					set id_request_transition [list $id_request "$transition"]
					if {  [lsearch $requetes_conditions $id_request_transition] == "-1" } {
						#variable ERROR Incoherence
						lappend requetes_conditions $id_request_transition
						set len [llength $request_splitted]
						#Detection basique d'erreur de configuration avec la taille len 
						if { $len == 2 } {
							#Ajout de la fonction nécessaire dans la variable transitions:
							set transitions [join [list $transitions "sensibilise_transition_service $transition $id_request [lindex $request_splitted 1]; # sensibilise partiellement transition $transition sur le status [lindex $request_splitted 1] de $id_request \n"] ""] 					
						} elseif { $len == 3 } {
							set transitions [join [list $transitions "sensibilise_transition_service $transition $id_request [lindex $request_splitted 1] [lindex $request_splitted 2]; # sensibilise partiellement transition $transition sur le status [lindex $request_splitted 1] de $id_request à l'exception \n"] ""] 
						} else {
							puts "Config_ERROR: Configuration de la condition sur le service $id_request de la transition $transition n'est pas valable ! \n"
							Ecriture_Config $components $transitions $Script $ports $places; exit 1; 
						}
						#Substitition de /requete/ par id_request dans contenu: 
						set conditions [regsub -all "$service" $conditions "\[lindex \$lst_temp($id_request) 0\]"];  #lst_temp sera défini dans Data.tcl/GENERATE_CONDITIONS_TOTALES 

					} else {
						puts "Config_ERROR: Transitions $transition: Cette version de JRdP ne permet pas d'avoir la même requête $id_request avec différents statuts ( ou exceptions ) comme condition sur la même transition. Merci de faire autrement !! \n"
						Ecriture_Config $components $transitions $script $ports $places; exit 1;

					}
				}
		
			} else {
			}
			return [list $conditions $transitions ]
		}

		#Traitement des services contenu dans les actions:

		proc Traitement_services_dans_actions { transition services components transitions script ports places requetes_actions } { 

			if { [llength $services]>0 } {
				foreach service $services {

					set service [string trimright [string trimleft $service " /"] "/"]
					#Séparation sur les espaces:
					set service [regexp -all -inline {\S+} $service]
					set len [llength $service]

					if { $len == 2 } {
						set transitions [join [list $transitions "associer_service_transition $transition [lindex $service 0] [lindex $service 1] ; #Associer le service [lindex $service 1] du composant [lindex $service 0] à la transition $transition\n"] ""] 
						lappend requetes_actions [list [join [list [lindex $service 0] [lindex $service 1] "t$transition"] "_"] "$transition"]
					} elseif { $len == 3 } {
						set parametres [lindex $service 2];
						set parametres [regsub {\*} $parametres {$Script::}]
						set transitions [join [list $transitions "associer_service_transition $transition [lindex $service 0] [lindex $service 1] $parametres ; #Associer le service [lindex $service 1] du composant [lindex $service 0] à la transition $transition avec [lindex $service 2] comme paramètre\n"] ""]
						lappend requetes_actions [list [join [list [lindex $service 0] [lindex $service 1] "t$transition"] "_"] "$transition"] 
					} else {
						puts "Config_ERROR: Configuration des actions de la transition $transition n'est pas valable ! \n"
						Ecriture_Config $components $transitions $script $ports $places; exit 1;
					}	

				}
			}
			return [list $requetes_actions $transitions]
		}


	#II-------Génération de la configuration:

	if { $gen } {

		#1****Ouverture du buffers:

		puts "REPORT:Génération $JRdP::path/Generated_Tcl/Configuration_RdP.tcl encours ..."
		set fd [open "Source_Graphique.ndr" r]	
		set Config [open "Generated_Tcl/Configuration_RdP.tcl" w+]

		#2***Variables à mettre dans Configuration_Rdp.tcl:

		set components "";#Contenant les composants à charger. 
		set transitions ""; #Contenant la configuration des transitions.
		set Script "";  #Contenant le Script TCL.
		set ports "";  #Contenant la configuration des ports.
		set places "";  #Contenant la configuration des places.
		
		#3***Variables internes:
		set requetes_conditions "";
		set requetes_actions "";
		set report_config "";
		set config_fonctions "";

		#4***Lecture LIGNE PAR LIGNE:.

		while {[gets $fd line] >= 0} {


			#----------------------------------Si la ligne commence par t. Récupération de la config transition. 

			#Exemple:t 35.0 510.0 t2 c 0 w n {Conditions: /demo_Move_t1 "not-sent"/ ; Services: demo Goto 5.0;} ne. Cf .ndr

			#Si la première lettre est bien "t":

	   		if { [string index $line 0]== "t" } {

				#Si on detecte un pettern de type {t (nimporte) (c ou w ou s ou n) }. Récupération numéro de transition:
				regexp {t .* [cwesn] } $line transition
				set transition [string trimleft [lindex [split $transition " "] 3] "t"]
				#Ajout "#transition num_transition" dans la variable transitions: 
				set transitions [ join [list $transitions "\n\n#transition $transition \n\n"] ""]
				#Si on detecte un pettern de type { {Conditions:nimporte; Actions:.*;} }:
				regexp { {([\s]{0,}Conditions:.*;[\s]{0,}Actions:.*;)[\s]{0,}} } $line tout ligne

				#Si le pattern est detecté:
				if { [info exists ligne] } {

					#Récupération des conditions et des actions:
					regexp {Conditions:(.*); Actions:.*;} $ligne tous conditions
					regexp {Conditions:.*; Actions:(.*);} $ligne tous actions 


					if { [regexp -nocase {[a-z\?\!]} $conditions] } {

						#Detecter tous les petterns de type { /(nimporte)/}. Récupération condition sur service:
						set conditions_services [regexp -all -inline {(?: /.*/){1,1}?} $conditions];
						#Detecter tous les petterns de type { /(nimporte)/}. Récupération condition sur script:
						set conditions_scripts [regexp -all -inline {(?: \?.*\?){1,1}?} $conditions];

						#Ajout "#----Formule logique: ..." dans la variable transitions:
						set transitions [join [list $transitions "\t#----Formule logique: $conditions:\n\n"] ""]

						#Traitement des services contenus dans Conditions:

						set resultat [Traitement_services_dans_conditions $transition $conditions_services $conditions $components $transitions $Script $ports $places $requetes_conditions];
						set transitions [lindex $resultat 1]
						set conditions  [lindex $resultat 0]

						#Traitement des scripts contenus dans Conditions:

						set resultat [Traitement_script_dans_conditions $transition $conditions_scripts $conditions $components $transitions $Script $ports $places];
						set transitions [lindex $resultat 1]
						set conditions  [lindex $resultat 0]

						#Gestion d'erreur débile:

						if { [llength $conditions_scripts] == 0 && [llength $conditions_services] == 0 }  { 
							puts "Config_ERROR: Conditions non valables sur la transition $transition. "
							Ecriture_Config $components $transitions $Script $ports $places; exit 1;
						}

						#Substitition de OR par || dans conditions: 
						set conditions [regsub -all "OR" $conditions {||}]
						#Substitition de AND par && dans conditions:
						set conditions [regsub -all "AND" $conditions {\&\&}]
						#Ajout de la formule logique qui sera testé sur chaque tour de boucle du JrdP
						lset JRdP::Flags_cond $transition "namespace eval Script \{ expr $conditions \}"
					
				
					} else { 
						puts "Config_ERROR: Pas de conditions sur la transition $transition. "
						Ecriture_Config $components $transitions $Script $ports $places; exit 1;
					}


					if { [regexp -nocase {[a-z\?\!]} $actions] } {

						#Detecter tous les petterns de type { /(nimporte)/ }. Récupération condition sur service:
						set actions_services [regexp -all -inline {(?: /.*/){1,1}?} $actions];
						#Detecter tous les petterns de type { ?(nimporte)? }. Récupération condition sur variable:
						set actions_scripts [regexp -all -inline {(?: \?.*\?){1,1}?} $actions];
						#Detecter tous les petterns de type { //(nimporte)// }. Récupération condition sur fonction:
						set actions_fonctions [regexp -all -inline {(?: §.*§){1,1}?} $actions];

						#Traitement des services contenus dans actions:

						set resultat [Traitement_services_dans_actions $transition $actions_services  $components $transitions $Script $ports $places $requetes_actions];
						set transitions [lindex $resultat 1]
						set requetes_actions  [lindex $resultat 0]
						
						#Traitement des scripts contenus dans actions:

						if { [llength $actions_scripts]>0 } {
							foreach script $actions_scripts {
								set script [string trimright [string trimleft $script " ?"] "?"]
								set transitions [join [list $transitions "associer_script_transition $transition \{$script\}; #Associer le script $script à l'action sur la transition $transition\n"] ""] 
					
							}
						}
						
						#Traitement des fonctions contenus dans actions (reporté puisque la note qui contient la definitions des notes peut être pas encore traitée):

						if { [llength $actions_fonctions]>0 } {
							foreach fonction $actions_fonctions {
								set fonction [string trimright [string trimleft $fonction " §"] "§"]
								lappend config_fonctions [list "temp_$fonction" $transition]
							} 
						}

						#Gestion d'erreur débile 2:

						if { [llength $actions_services]==0 && [llength $actions_scripts]==0 && [llength $actions_fonctions]==0 } { 
							puts "Config_ERROR: Transition $transition : actions non valables "
							Ecriture_Config $components $transitions $Script $ports $places; exit 1; 
						
						}
					}

				unset ligne  
		 
				} else {
					puts "Config_ERROR: Transition $transition : \n La formule de configuration est la suivante:\nConditions:lesconditions; Actions:lesactions;"
					Ecriture_Config $components $transitions $Script $ports $places; exit 1; 
				}
			






			#-------------------------------------Si la ligne commence par p. Récupération de la config place.

			} elseif { [string index $line 0]== "p" } {

				#Même principe:
				regexp { {.*} } $line ligne
				if { [info exists ligne] } {

					set ligne [string trimright [string trimleft $ligne " {"] "} "];
					regexp "p.* n " $line place
					set place [string trimleft [lindex [split $place " "] 3] "p"]
					set places [ join [list $places "\n\n \t#place $place \n\n"] ""]
					set places [ join [list $places "\t\tif \{ \[marquage_place $place\] \} \{ \n\t\t\t$ligne\n\t\t \}"] ""]
					set report_config [join [list $report_config "\nPlace : $place configurée"]] 
					unset ligne;
				}

			#-----------------------------------Si la ligne commence par n. Récupération de la config Ports,Script TCL ou Components.

			} elseif { [string index $line 0]== "n" || [string index $line 0]== "a" } {

				regexp " \{.*\}" $line ligne
				if { [info exists ligne] } {

					set ligne [string trimright [string trimleft $ligne " {"] "}"];
					#\\n n'est pas detecté par split. Je le substitue par ° puis je splite:
					set ligne [regsub -all -expanded {\\\\n} $ligne "°"]
					set ligne [regsub -all {\\(.)} $ligne {\1}]
					set ligne [split $ligne "°"]
					#Enlever les lignes vides
					set ligne [lsearch -all -inline -not -exact $ligne {}]
					regexp {[na] .* [10] \{} $line note
					#numéro de la note
					set note [string trimleft [lindex [split $note " "] 3] "n"]

					#Ajout Script TCL

					if { [string match -nocase "*Script TCL*" [lindex $ligne 0]] } {			
						set ligne [lrange $ligne 1 end]
						#Tout la note du script, sauf la première ligne: Script TCL, est mise dans fichier Configuration_RdP:
						set Script [ join $ligne "\n\t" ]	
						set report_config [join [list $report_config "\nScript TCL: configurés"]] 

					#Configuration Ports:

					} elseif { [string match -nocase "*Ports*" [lindex $ligne 0]] } {
						set ligne [lrange $ligne 1 end]
						foreach element $ligne {
							if { ![regexp {#} $element] } {
								if { [regexp { \-\> } $element] } { 
									set modules [split $element " \-\> "]
									set modules [lsearch -all -inline -not -exact $modules {}]
									set module1 [lindex $modules 0]
									set module2 [lindex $modules 1]
									set module2_port [lindex [lsearch -all -inline -not -exact [split $module2 "::"] {}] 1];
									set module2_comp [lindex [lsearch -all -inline -not -exact [split $module2 "::"] {}] 0];
									set module1_port [lindex [lsearch -all -inline -not -exact [split $module1 "::"] {}] 1];
									set module1_comp [lindex [lsearch -all -inline -not -exact [split $module1 "::"] {}] 0];
									set ports [ join [list $ports "Connect_port $module2_port $module2_comp $module1_port $module1_comp"] "\n"]
								}
							}
								
						}
						set report_config "$report_config\nPorts: configurés"

					#Configuration Components:

					} elseif { [string match -nocase "*Components*" [lindex $ligne 0]] } {
						set ligne [lrange $ligne 1 end]
						foreach element $ligne {
							if { ![regexp {#} $element] } {
								set components [join [list $components "$element"] " "]	
							}
						}
						set report_config "$report_config\nComponents: configurés"

					#Configuration Fonctions:

					} elseif { [string match -nocase "*Fonctions*" [lindex $ligne 0]] } {
						set ligne [lrange $ligne 1 end]
						set fonctions [join $ligne " "]
						set fonctions [regexp -all -inline {(?:([a-zA-Z0-9_\-]{1,}) \((.*)\)){1,1}?} $fonctions]
						foreach {tout fonction contenu} $fonctions {
							set temp_$fonction $contenu
						}
						set report_config "$report_config\nFonctions: configurés"
					}
					unset ligne;
				}
			}
		}




		#-------------------------------------------------Gestion des fonctions dans les actions des transitions ( à l'extérieur de la boucle à cause de l'absence de l'ordre entre les notes et les transitions dans le .ndr ):

		if { [llength $config_fonctions] > 0 } {

			foreach fonction $config_fonctions {

				set transition [lindex $fonction 1]

				#Ajout "#transition num_transition" dans la variable transitions: 
				set transitions [ join [list $transitions "\n\n#transition $transition (Config à partir des fonctions) \n\n"] ""]

				set actions [lindex $fonction 0]
				set actions [expr $$actions] ; #acces au contenu de la fonction dont le nom est contenu dans $actions

				#Detecter tous les petterns de type { /(nimporte)/ }. Récupération condition sur service:
				set actions_services [regexp -all -inline {(?: /.*/){1,1}?} $actions];
				#Detecter tous les petterns de type { ?(nimporte)? }. Récupération condition sur variable:
				set actions_scripts [regexp -all -inline {(?: \?.*\?){1,1}?} $actions];

				#Traitement des services contenus dans actions:

				set resultat [Traitement_services_dans_actions $transition $actions_services $components $transitions $Script $ports $places $requetes_actions];
				set transitions [lindex $resultat 1]
				set requetes_actions  [lindex $resultat 0]
				
				#Traitement des scripts contenus dans actions:

				if { [llength $actions_scripts]>0 } {
					foreach req $actions_scripts {
						set script [string trimright [string trimleft $req " ?"] "?"]
						set transitions [join [list $transitions "associer_script_transition $transition {$script}; #Associer le script $script à l'action sur la transition $transition\n"] ""] 
			
					}
				}

				#Traitement des erreurs:

				if { [llength $actions_scripts]==0 && [llength $actions_services]==0} { 
							puts "Config_ERROR: Transition $transition : actions de la fonction [string trimleft $contenu {temp_}] non valables "
							Ecriture_Config $components $transitions $Script $ports $places; exit 1; 
						
				}	
			}
		}







		#-----------------------------------------------------------------Gestion d'erreur d'incoherence sur les requetes (si les requetes dans les actions sont les mêmes que les requetes dans les conditions ):

		foreach req $requetes_conditions {
			set t [lindex [regexp -inline {_t([0-9]{1,})} $req] 1]
			if { [lsearch $requetes_actions [list [lindex $req 0] $t] ]== "-1" } {
				puts "Config_ERROR:Incoherence dans les requettes des services. La requete [lindex $req 0] de la condition associée à la transition [lindex $req 1] n'est pas coherente avec les services déclarés dans les transitions"
				Ecriture_Config $components $transitions $Script $ports $places; exit 1;				
			}
		
		}

		set report_config [join [list $report_config "\nTransitions: configurés"]] 
		puts  $report_config

		#Écriture dans Configuration_RdP.tcl:

		Ecriture_Config $components $transitions $Script $ports $places;

		#Report:

		puts "REPORT:$JRdP::path/Generated_Tcl/Configuration_RdP.tcl généré"

		#Fermeture Buffers:

		close $fd
		close $Config

		#Copie de Matrices.tcl dans JRdP_Embadded:

		exec cp $JRdP::path/Generated_Tcl/Configuration_RdP.tcl $JRdP::path/JRdP_Embadded/Generated_Tcl/Configuration_RdP.tcl
	}
}

