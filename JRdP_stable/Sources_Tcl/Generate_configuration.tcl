namespace eval Generate_config {
	puts "Voulez vous générer la configuration du RdP à partir le fichier Source_Graphique.ndr? (1 ou 0):"
	set gen [gets stdin];

	if { $gen } {
		#Ouverture du buffers:
		puts "REPORT:Génération $JRdP::path/Generated_Tcl/Configuration_RdP.tcl encours ..."
		set fd [open "Source_Graphique.ndr" r]	
		set Config [open "Generated_Tcl/Configuration_RdP.tcl" w+]
		#Variables à mettre dans Configuration_Rdp.tcl:
		set components "";#Contenant les composants à charger. 
		set transitions ""; #Contenant la configuration des transitions.
		set Script "";  #Contenant le Script TCL.
		set ports "";  #Contenant la configuration des ports.
		set places "";  #Contenant la configuration des places.
		#Proc qui permet d'écrire dans Congiguration_RdP
		proc Ecriture { components transitions Script ports places } { 
			puts $JRdP::Generate_config::Config "##### I- Chargement des composants \n\nset handle \[genomix\]; #Lancement deomon genomix , roscore et serveur genomix à l'aide du macro genomix\nset components { $components };  	#Modifiable		#Composant .s à charger\nLoad_components \$handle \$components ; #Chargement des composants (components) sur le deamon genomix (handle)\n\n##### II- Connection des capteurs:\n#---syntax: Connect_port \$port_name \$component1(port in) \$component2(port out)\n\n$ports \n\n##### III- Script_TCL :\n\nnamespace eval Script {\neval \{\t$Script\}\n}\n\n##### V- Structure dynamique du RdP ( association transition service conditions ) :\n\n$transitions \n\n#### VI- actions sur les places:\n\n proc ACTIONS_PLACES {} { \n\tglobal f;\n\tglobal Arret;\n\t$places\n}\n"
			puts $JRdP::Generate_config::Config "###À ne pas modifier:\nset Flags_cond [list $JRdP::Flags_cond]\nset valid_req [list $JRdP::Generate_config::valid_req]\n"
		}
		#Variables internes:
		set test_req "";
		set valid_req "";
		set tr_config "";
		set autre_config "";
		set config_fonctions "";
		#Lecture ligne par ligne du fichier .ndr:
		#Dans la detection des patterns, les espaces sont considérés.
		while {[gets $fd line] >= 0} {
			#Si la ligne commence par e. Récupération de la config transition. Exemple:t 35.0 510.0 t2 c 0 w n {Conditions: /demo_Move_t1 "not-sent"/ ; Services: demo Goto 5.0;} ne. Cf .ndr
	   		if { [string index $line 0]== "t" } {
				#Si on detecte un pettern de type {t (nimporte) (c ou w ou s ou n) }. Récupération numéro de transition:
				regexp {t .* [cwesn] } $line transition
				set transition [string trimleft [lindex [split $transition " "] 3] "t"]
				#Ajout "#transition num_transition" dans la variable transitions: 
				set transitions [ join [list $transitions "\n\n#transition $transition \n\n"] ""]
				#Si on detecte un pettern de type { {Conditions:nimporte; Actions:.*;} }:
				regexp { {([\s]{0,}Conditions:.*;[\s]{0,}Actions:.*;)[\s]{0,}} } $line tout ligne
				if { [info exists ligne] } {
					#Récupération des conditions et des actions:
					regexp {Conditions:(.*); Actions:.*;} $ligne tous Conditions
					regexp {Conditions:.*; Actions:(.*);} $ligne tous Actions 
					#Contenu de la condition
					set contenu $Conditions
					#Si on detecte "*1_CI*". Mise à 1 de la condition de transition.
					if { [regexp -nocase {[a-z\?\!]} $contenu] } {
						#Detecter tous les petterns de type { /(nimporte)/ }. Récupération condition sur service:
						set reqs [regexp -all -inline {(?: /.*/){1,1}?} $contenu];
						#Detecter tous les petterns de type { /(nimporte)/ }. Récupération condition sur variable:
						set reqv [regexp -all -inline {(?: \?.*\?){1,1}?} $contenu];
						#Ajout "#----Formule logique: ..." dans la variable transitions:
						set transitions [join [list $transitions "\t#----Formule logique: $contenu:\n\n"] ""]
						if { [llength $reqs]>0 } {
							#Variables:
							set id_req ""; #nom du requete
							set con_req ""; #son contenu
							#Pour chaque requete dans reqs
							foreach req $reqs {
								set reqq [string trimright [string trimleft $req " /"] "/"]
								#Séparation sur les espaces:
								set con_req [regexp -all -inline {\S+} $reqq]
								#Premier indice est le nom de la req
								set id_req [lindex $con_req 0]
								set id_req_transition [list $id_req "$transition"]
								if {  [lsearch $test_req $id_req_transition] == "-1" } {
									#variable ERROR Incoherence
									lappend test_req $id_req_transition
									set len [llength $con_req]
									#Detection basique d'erreur de configuration avec la taille len 
									if { $len == 2 } {
										#Ajout de la fonction nécessaire dans la variable transitions:
										set transitions [join [list $transitions "sensibilise_transition_service $transition $id_req [lindex $con_req 1]; # sensibilise partiellement transition $transition sur le status [lindex $con_req 1] de $id_req \n"] ""] 					
									} elseif { $len == 3 } {
										set transitions [join [list $transitions "sensibilise_transition_service $transition $id_req [lindex $con_req 1] [lindex $con_req 2]; # sensibilise partiellement transition $transition sur le status [lindex $con_req 1] de $id_req à l'exception \n"] ""] 
									} else {
										puts "Config_ERROR: Configuration de la condition sur le service $id_req de la transition $transition n'est pas valable ! \n"
										Ecriture $components $transitions $Script $ports $places; exit 1; 
									}
									#Substitition de /requete/ par id_req dans contenu: 
									set contenu [regsub -all "$req" $contenu "\[lindex \$lst_temp($id_req) 0\]"];  #lst_temp sera défini dans Data.tcl/GENERATE_CONDITIONS_TOTALES 
		
								} else {
									puts "Config_ERROR: Transitions $transition: Cette version de JRdP ne permet pas d'avoir la même requête $id_req avec différents statuts ( ou exceptions ) comme condition sur la même transition. Merci de faire autrement !! \n"
									Ecriture $components $transitions $Script $ports $places; exit 1;

								}
							}
						
						}
						if { [llength $reqv]>0 } {
							#Variables:
							set id_var ""; #nom du variable
							set con_reqv ""; #formule logique
							#Pour chaque formule dans reqv
							foreach req $reqv {
								set reqq [string trimright [string trimleft $req " ?"] "?"]
								#Detection basique d'erreur de configuration avec la taille len 
								if { [regexp -nocase {[a-z0-9]} $contenu] } {
									#Ajout de la fonction nécessaire dans la variable transitions:
									set transitions [join [list $transitions "\t# sensibilise partiellement la transition $transition sur la formule $reqq \n"] ""] 	
									#Substitition de ?requete? par requete dans contenu:
									set contenu [regsub "***=$req" $contenu " $reqq "];	
			
								} else {
									puts "Config_ERROR: Configuration de la condition sur la variable $id_var de la transition $transition n'est pas valable ! \n"
									Ecriture $components $transitions $Script $ports $places; exit 1;
								}
							
					
							}
					
						}
						if { [llength $reqv]==0 && [llength $reqs]==0 }  { 
							puts "Config_ERROR: Conditions non valables sur la transition $transition. "
							Ecriture $components $transitions $Script $ports $places; exit 1;
						}
						#Substitition de OR par || dans contenu: 
						set contenu [regsub -all "OR" $contenu {||}]
						#Substitition de AND par && dans contenu:
						set contenu [regsub -all "AND" $contenu {\&\&}]
						#Ajout de la formule logique qui sera testé sur chaque tour de boucle du JrdP
						lset JRdP::Flags_cond $transition "namespace eval Script \{ expr $contenu \}"
					
				
					} else { 
						puts "Config_ERROR: Pas de conditions sur la transition $transition. "
						Ecriture $components $transitions $Script $ports $places; exit 1;
					}
					set contenu $Actions
					if { [regexp -nocase {[a-z\?\!]} $contenu] } {
						#Detecter tous les petterns de type { /(nimporte)/ }. Récupération condition sur service:
						set reqs [regexp -all -inline {(?: /.*/){1,1}?} $contenu];
						#Detecter tous les petterns de type { ?(nimporte)? }. Récupération condition sur variable:
						set reqv [regexp -all -inline {(?: \?.*\?){1,1}?} $contenu];
						#Detecter tous les petterns de type { //(nimporte)// }. Récupération condition sur fonction:
						set reqf [regexp -all -inline {(?: §.*§){1,1}?} $contenu];
						#Consigne qui permet de savoir si len_reqv ou len_reqs est différent de 0:
						set consigne 0; 
						if { [llength $reqs]>0 } {
							set consigne 1;
							foreach req $reqs {
								set reqq [string trimright [string trimleft $req " /"] "/"]
								#Séparation sur les espaces:
								set req [regexp -all -inline {\S+} $reqq]
								set len [llength $req]
								if { $len == 2 } {
									set transitions [join [list $transitions "associer_service_transition $transition [lindex $req 0] [lindex $req 1] ; #Associer le service [lindex $req 1] du composant [lindex $req 0] à la transition $transition\n"] ""] 
									lappend valid_req [list [join [list [lindex $req 0] [lindex $req 1] "t$transition"] "_"] "$transition"]
								} elseif { $len == 3 } {
									set parametres [lindex $req 2];
									set parametres [regsub {\*} $parametres {$Script::}]
									set transitions [join [list $transitions "associer_service_transition $transition [lindex $req 0] [lindex $req 1] $parametres ; #Associer le service [lindex $req 1] du composant [lindex $req 0] à la transition $transition avec [lindex $req 2] comme paramètre\n"] ""]
									lappend valid_req [list [join [list [lindex $req 0] [lindex $req 1] "t$transition"] "_"] "$transition"] 
								} else {
									puts "Config_ERROR: Configuration des actions de la transition $transition n'est pas valable ! \n"
									Ecriture $components $transitions $Script $ports $places; exit 1;
								}	
					
							}
						}
						if { [llength $reqv]>0 } {
							set consigne 1;
							foreach req $reqv {
								set script [string trimright [string trimleft $req " ?"] "?"]
								set transitions [join [list $transitions "associer_script_transition $transition \{$script\}; #Associer le script $script à l'action sur la transition $transition\n"] ""] 
					
							}
						}
						if { [llength $reqf]>0 } {
							foreach req $reqf {
								set reqq [string trimright [string trimleft $req " §"] "§"]
								lappend config_fonctions [list "temp_$reqq" $transition $consigne]
							} 
						}
						if { [llength $reqv]==0 && [llength $reqs]==0 && [llength $reqf]==0 } { 
							puts "Config_ERROR: Transition $transition : actions non valables "
							Ecriture $components $transitions $Script $ports $places; exit 1; 
						
						}
					}
				unset ligne		 
				} else {
					puts "Config_ERROR: Transition $transition : \n La formule de configuration est la suivante:\nConditions:lesconditions; Actions:lesactions;"
					Ecriture $components $transitions $Script $ports $places; exit 1; 
				}
			
			#Si la ligne commence par p. Récupération de la config place.
			} elseif { [string index $line 0]== "p" } {
				#Même principe:
				regexp { {.*} } $line ligne
				if { [info exists ligne] } {
					set ligne [string trimright [string trimleft $ligne " {"] "} "];
					regexp "p.* n " $line place
					set place [string trimleft [lindex [split $place " "] 3] "p"]
					set places [ join [list $places "\n\n \t#place $place \n\n"] ""]
					set places [ join [list $places "\t\tif \{ \[marquage_place $place\] \} \{ \n\t\t\t$ligne\n\t\t \}"] ""]
					set autre_config [join [list $autre_config "\nPlace : $place configurée"]] 
					unset ligne;
				}
			#Si la ligne commence par n. Récupération de la config Ports,Script TCL ou Components.
			} elseif { [string index $line 0]== "n" } {

				regexp " \{.*\}" $line ligne
				if { [info exists ligne] } {
					set ligne [string trimright [string trimleft $ligne " {"] "}"];
					#\\n n'est pas detecté par split. Je le substitue par ° puis je splite:
					set ligne [regsub -all -expanded {\\\\n} $ligne "°"]
					set ligne [split $ligne "°"]
					#Enlever les lignes vides
					set ligne [lsearch -all -inline -not -exact $ligne {}]
					regexp {n .* [10] \{} $line note
					#numéro de la note
					set note [string trimleft [lindex [split $note " "] 3] "n"]
					#Ajout Script TCL
					if { [string match -nocase "*Script TCL*" [lindex $ligne 0]] } {			
						set ligne [lrange $ligne 1 end]
						#Tout la note du script, sauf la première ligne: Script TCL, est mise dans fichier Configuration_RdP:
						foreach element $ligne {
							set Script [ join [list $Script "\n$element\n"] "" ]	
						}
						set autre_config [join [list $autre_config "\nScript TCL: configurés"]] 
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
						set autre_config "$autre_config\nPorts: configurés"
					#Configuration Components:
					} elseif { [string match -nocase "*Components*" [lindex $ligne 0]] } {
						set ligne [lrange $ligne 1 end]
						foreach element $ligne {
							if { ![regexp {#} $element] } {
								set components [join [list $components "$element"] " "]	
							}
						}
						set autre_config "$autre_config\nComponents: configurés"
					#Configuration Fonctions:
					} elseif { [string match -nocase "*Fonctions*" [lindex $ligne 0]] } {
						set ligne [lrange $ligne 1 end]
						set fonctions [join $ligne " "]
						set fonctions [regexp -all -inline {(?:([a-zA-Z0-9_\-]{1,}) \((.*)\)){1,1}?} $fonctions]
						foreach {tout fonction contenu} $fonctions {
							set temp_$fonction $contenu
						}
						set autre_config "$autre_config\nFonctions: configurés"
					} else { 
						puts "Report: la note $note n'est pas valable pour la configuration. Elle ne sera pas utilisée"
					}
					unset ligne;
				}
			}
		}
		#Gestion des fonctions dans les conditions des transitions ( à l'extérieur de la boucle à cause de l'absence de l'ordre entre les notes et les transitions dans le .ndr:
		if { [llength $config_fonctions] > 0 } {
			foreach fonction $config_fonctions {
				set transition [lindex $fonction 1]
				set consigne [lindex $fonction 2]
				#Ajout "#transition num_transition" dans la variable transitions: 
				set transitions [ join [list $transitions "\n\n#transition $transition (Config à partir des fonctions) \n\n"] ""]
				set contenu [lindex $fonction 0]
				set contenu [expr $$contenu]
				#Detecter tous les petterns de type { /(nimporte)/ }. Récupération condition sur service:
				set reqs [regexp -all -inline {(?: /.*/){1,1}?} $contenu];
				#Detecter tous les petterns de type { ?(nimporte)? }. Récupération condition sur variable:
				set reqv [regexp -all -inline {(?: \?.*\?){1,1}?} $contenu];
				if { [llength $reqs]>0 } {
					foreach req $reqs {
						set reqq [string trimright [string trimleft $req " /"] "/"]
						#Séparation sur les espaces:
						set req [regexp -all -inline {\S+} $reqq]
						set len [llength $req]
						if { $len == 2 } {
							set transitions [join [list $transitions "associer_service_transition $transition [lindex $req 0] [lindex $req 1] ; #Associer le service [lindex $req 1] du composant [lindex $req 0] à la transition $transition\n"] ""] 
							lappend valid_req [list [join [list [lindex $req 0] [lindex $req 1] "t$transition"] "_"] "$transition"]
						} elseif { $len == 3 } {
							set parametres [lindex $req 2];
							set parametres [regsub {\*} $parametres {$Script::}]
							set transitions [join [list $transitions "associer_service_transition $transition [lindex $req 0] [lindex $req 1] $parametres ; #Associer le service [lindex $req 1] du composant [lindex $req 0] à la transition $transition avec [lindex $req 2] comme paramètre\n"] ""]
							lappend valid_req [list [join [list [lindex $req 0] [lindex $req 1] "t$transition"] "_"] "$transition"] 
						} else {
							puts "Config_ERROR: Configuration des actions de la transition $transition n'est pas valable ! \n"
							Ecriture $components $transitions $Script $ports $places; exit 1;
						}	
			
					}
				}
				if { [llength $reqv]>0 } {
					foreach req $reqv {
						set script [string trimright [string trimleft $req " ?"] "?"]
						set transitions [join [list $transitions "associer_script_transition $transition {$script}; #Associer le script $script à l'action sur la transition $transition\n"] ""] 
			
					}
				}
				if { [llength $reqv]==0 && [llength $reqs]==0 && $consigne==1} { 
							puts "Config_ERROR: Transition $transition : actions de la fonction [string trimleft $contenu {temp_}] non valables "
							Ecriture $components $transitions $Script $ports $places; exit 1; 
						
				} elseif { [llength $reqv]==0 && [llength $reqs]==0 && $consigne==0 } {
							puts "Config_ERROR: Transition $transition : actions non valables ou vides "
							Ecriture $components $transitions $Script $ports $places; exit 1;
				}	
			}
		}
		#Gestion d'erreur d'incoherence sur les requetes:
		foreach req $test_req {
			set t [lindex [regexp -inline {_t([0-9]{1,})} $req] 1]
			if { [lsearch $valid_req [list [lindex $req 0] $t] ]== "-1" } {
				puts "Config_ERROR:Incoherence dans les requettes des services. La requete [lindex $req 0] de la condition associée à la transition [lindex $req 1] n'est pas coherente avec les services déclarés dans les transitions"
				Ecriture $components $transitions $Script $ports $places; exit 1;				
			}
		
		}
		puts -nonewline $tr_config
		puts  $autre_config
		#Écriture dans Configuration_RdP.tcl:
		Ecriture $components $transitions $Script $ports $places;
		#Report:
		puts "REPORT:$JRdP::path/Generated_Tcl/Configuration_RdP.tcl généré"
		#Fermeture Buffers:
		close $fd
		close $Config
		#Copie de Matrices.tcl dans JRdP_Embadded:
		exec cp $JRdP::path/Generated_Tcl/Configuration_RdP.tcl $JRdP::path/JRdP_Embadded/Generated_Tcl/Configuration_RdP.tcl
	}
}

