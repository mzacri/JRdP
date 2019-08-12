
puts "Voulez vous générer la définition du RdP à partir du Source_Graphique.ndr? (1 ou 0):"
set gen [gets stdin];

if { $gen } {
	#Ouverture du buffers:
	puts "REPORT:Génération $path/Generated_Tcl/Matrices.tcl encours ..."
	set fd [open "Source_Graphique.ndr" r]	
	set mat [open "Generated_Tcl/Matrices.tcl" w+]
	#Variables:
	set nb_t 0;#nombre de transitions.
	set nb_p 0;#nombre de places.
	set pre ""; #liste contenant des arcs pre  ( arc=liste: "place transition poids" ). Utilisé ensuite pour générer la matrice PRE. 
	set post "";#liste contenant des arcs post ( arc=liste: "place transition poids" ). Utilisé ensuite pour générer la matrice POST.
	set mar "";#liste contenant les marquages initials des places ( marquag=liste: "place marquage" ). 
	#Lecture ligne par ligne du fichier .ndr:
	#Dans la detection des patterns, les espaces sont considérés.
	while {[gets $fd line] >= 0} {
		#Si la ligne commence par e. Récupération des arcs.Exemple:e p5 0.8573883569 108.853112 t5 0.009084688674 35.05709629 1 n. Cf .ndr
		if { [string index $line 0]== "e" } {
			#Si on detecte un pettern pre de type {p(chiffres==place) (nimporte)t(chiffres==transition) (nimporte)(chiffres==poids) n} 
			if { [regexp  { p([0-9]{1,}) .*t([0-9]{1,}) .*([0-9]{1,}) n} $line tout place transition poids] } {
				#Calcul (nb_t-1) : max des transitions: 
				if { $nb_t < $transition } { set nb_t $transition }
				#Calcul (nb_p-1) : max des places:
				if { $nb_p < $place } { set nb_p $place }
				#Ajout d'un arc: 
				lappend pre [list "$place" "$transition" "$poids"]
				
			#Si on detecte un pettern post de type {t(chiffres==transition) (nimporte)p(chiffres==place) (nimporte)(chiffres==poids) n}		
			} elseif { [regexp  { t([0-9]{1,}) .*p([0-9]{1,}) .*([0-9]{1,}) n} $line tout transition place poids]	} {
				if { $nb_t < $transition } { set nb_t $transition }
				if { $nb_p < $place } { set nb_p $place }
				lappend post [list "$place" "$transition" "$poids"]
			#Sinon : ERROR	
			} else { puts "configuration \{ $line \} dans Source_Graphique.ndr n'est pas valide"; exit 1; }
		#Si la ligne commence par p. Récupération du marquage: 
		} elseif { [string index $line 0]== "p" } {
			#Si on detecte un pettern de type {p(chiffres==place) (chiffres==marquage) n}
			if { [regexp { p([0-9]{1,}) ([0-9]{1,}) n} $line tout place marquage] } {
				#Ajout marquage:
				lappend mar [list "$place" "$marquage"] 
			}		
		}
	}
	#nb_t est le nombre de transitions indexées à partir de 0. Il faut ajouter 1:
	set nb_t [expr $nb_t + 1]
	#de meme:
	set nb_p [expr $nb_p + 1]
	#Variables:
	vexpr {

	 	PRE=zeros(nb_p,nb_t);
		POST=zeros(nb_p,nb_t);
		M=zeros(nb_p,1);

	}
	#Chargement de PRE,POST ET M:
	set len_pre [llength $pre]
	set len_post [llength $post]
	set len_mar [llength $mar]
	for { set element 0 } { $element < $len_pre } { incr element } {
		set index_ligne [lindex [lindex $pre $element] 0]
		set index_colonne [lindex [lindex $pre $element] 1]
		set poids [lindex [lindex $pre $element] 2]
		vexpr {
			poids=poids*1.0
			PRE[index_ligne,index_colonne]=poids
		}
	}		

	for { set element 0 } { $element < $len_post } { incr element } {
		set index_ligne [lindex [lindex $post $element] 0]
		set index_colonne [lindex [lindex $post $element] 1]
		set poids [lindex [lindex $post $element] 2]
		vexpr {
			poids=poids*1.0
			POST[index_ligne,index_colonne]=poids
		}		
	} 
	for { set element 0 } { $element < $len_mar } { incr element } {
		set index_place [lindex [lindex $mar $element] 0]
		set marquage [lindex [lindex $mar $element] 1]
		vexpr {
			marquage=marquage*1.0 
			M[index_place,0]=marquage				
		}
	}
	
	#Écriture dans Matrices.tcl:
	puts $mat "##############DEF MATRICIELLE DU RdP########################################"
	puts $mat "vexpr { \n \t Post=create({$POST}); #def Post \n \t Pre=create({$PRE}); #def Pre \n}";
	puts $mat "vexpr { \n \t M=create({$M}) ; #Marquage_Initial \n \t nb_t=$nb_t; #nombre de transitions \n \t nb_p=$nb_p; #nombre de place \n}"
	#Report:
	puts "REPORT:$path/Generated_Tcl/Matrices.tcl généré"
	puts "REPORT:Nombre de transitions: $nb_t \nREPORT:Nombre de Places: $nb_p"
	#Fermeture Buffers:
	close $mat
	close $fd
	#Copie de Matrices.tcl dans JRdP_Embadded:
	exec cp $path/Generated_Tcl/Matrices.tcl $path/JRdP_Embadded/Generated_Tcl/Matrices.tcl
}


