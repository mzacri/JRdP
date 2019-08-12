
#Ouverture du buffers:
puts "REPORT:Configuration encours ..."
set fd [open "Source_Graphique.ndr" r]	
set components "";
namespace eval Script {
	set Config_places "";
}
set places "";
#Lecture ligne par ligne du fichier .ndr:
#Dans la detection des patterns, les espaces sont considérés.
while {[gets $fd line] >= 0} {
	#Si la ligne commence par e. Récupération de la config transition. Exemple:t 35.0 510.0 t2 c 0 w n {Conditions: /demo_Move_t1 "not-sent"/ ; Services: demo Goto 5.0;} ne. Cf .ndr
	if { [string index $line 0]== "t" } {
		#Si on detecte un pettern de type {t (nimporte) (c ou w ou s ou n) }. Récupération numéro de transition:
		regexp {t .* [cwesn] } $line transition
		set transition [string trimleft [lindex [split $transition " "] 3] "t"]
		#Si on detecte un pettern de type { {Conditions:nimporte; Actions:.*;} }:
		regexp { {(Conditions:.*; Actions:.*;)} } $line tout ligne
		if { [info exists ligne] } {
			#Récupération des conditions et des actions:
			regexp {Conditions:(.*); Actions:.*;} $ligne tous Conditions
			regexp {Conditions:.*; Actions:(.*);} $ligne tous Actions 
			#Contenu de la condition
			set contenu $Conditions
			if { [regexp -nocase {[a-z0-9]} $contenu] } {
						
				puts "Transition $transition: Sensibilisée sur la formule $contenu \n" 	
				#Ajout de la formule logique qui sera testé sur chaque tour de boucle du JrdP
				lset Flags_cond $transition "$contenu"
				
			} else { 
				puts "Config_ERROR: Pas de conditions valables sur la transition $transition. Vous pouvez la mettre à 1 avec 1_CI"
				exit 1;
			}
			set contenu $Actions
			if { [regexp -nocase {[a-z]} $contenu] } {
				puts "Transition $transition : Associer le script $contenu à l'action sur la transition $transition\n"
				associer_script_transition $transition $contenu; 
				
			} else {
				puts "Transition $transition : pas d'actions sur la transition $transition "
			}
		unset ligne		 
		} else {
			puts "Config_ERROR: Transition $transition : \n La formule de configuration est la suivante:\nConditions:lesconditions; Actions:lesactions;\n(!! Les espaces sont importants!!, surtout entre ; et Actions:) "
			exit 1; 
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
			set Script::Config_places $places
			puts "Place : $place configurée" 
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
				namespace eval Script {
					foreach element $ligne {
						eval "$element"	
					}
				}
				puts "Script TCL: configurés" 
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
							Connect_port $module2_port $module2_comp $module1_port $module1_comp
						}
					}
							
				}
				puts "Ports: configurés"
			#Configuration Components:
			} elseif { [string match -nocase "*Components*" [lindex $ligne 0]] } {
				set ligne [lrange $ligne 1 end]
				foreach element $ligne {
					if { ![regexp {#} $element] } {
						set components [lappend $components $element]	
					}
				}
				set handle [genomix]; #Lancement deomon genomix , roscore et serveur genomix à l'aide du macro genomix
				Load_components $handle $components ; #Chargement des composants (components) sur le deamon genomix (handle)
				puts "Components: configurés"
			#Configuration Fonctions:
			} else { 
				puts "Report: la note $note n'est pas valable pour la configuration. Elle ne sera pas utilisée"
			}
			unset ligne;
		}
	}
}

 	proc ACTIONS_PLACES {} {
		namespace eval Script { 
			eval $Config_places
		}
	
	}


#Fermeture Buffers:
close $fd
puts "Fin configuration"




